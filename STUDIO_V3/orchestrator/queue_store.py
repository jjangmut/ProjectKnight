"""Atomic state store with SQLite WAL transactions, optimistic locking, task leasing, and atomic JSON snapshots."""
from __future__ import annotations
import json
import os
import sqlite3
import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from filelock import FileLock
from .schemas import Task, TaskState, Issue, Severity, EvidenceItem, InvocationRecord
from .policies import TaskLeaseConflictError, ConcurrentModificationError, PolicyViolation


class QueueStore:
    def __init__(self, db_path: Path, json_snapshot_path: Optional[Path] = None):
        self.db_path = db_path
        self.json_snapshot_path = json_snapshot_path
        self.lock_path = self.db_path.with_suffix(".lock")
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()
        if self.json_snapshot_path and self.json_snapshot_path.exists():
            if self._count_tasks() == 0:
                self.import_snapshot(self.json_snapshot_path)

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _init_db(self) -> None:
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS meta (
                        key TEXT PRIMARY KEY,
                        value TEXT NOT NULL
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS tasks (
                        id TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        status TEXT NOT NULL,
                        owner TEXT NOT NULL,
                        reviewers_json TEXT NOT NULL,
                        blocked_by_json TEXT NOT NULL,
                        evidence_json TEXT NOT NULL,
                        evidence_manifest_json TEXT NOT NULL DEFAULT '[]',
                        reviews_json TEXT NOT NULL,
                        iteration INTEGER NOT NULL DEFAULT 0,
                        priority INTEGER NOT NULL DEFAULT 0,
                        active_branch TEXT NOT NULL DEFAULT '',
                        current_commit_sha TEXT NOT NULL DEFAULT '',
                        version INTEGER NOT NULL DEFAULT 1,
                        lease_owner TEXT,
                        lease_expires_at TEXT,
                        notes TEXT NOT NULL DEFAULT ''
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS issues (
                        id TEXT PRIMARY KEY,
                        task_id TEXT NOT NULL,
                        iteration INTEGER NOT NULL,
                        severity TEXT NOT NULL,
                        title TEXT NOT NULL,
                        reproduction_steps TEXT NOT NULL,
                        expected TEXT NOT NULL,
                        actual TEXT NOT NULL,
                        evidence_json TEXT NOT NULL,
                        status TEXT NOT NULL,
                        resolved_by TEXT,
                        created_at TEXT NOT NULL,
                        resolved_at TEXT,
                        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS invocations (
                        invocation_id TEXT PRIMARY KEY,
                        run_id TEXT NOT NULL,
                        task_id TEXT NOT NULL,
                        iteration INTEGER NOT NULL,
                        role TEXT NOT NULL,
                        provider TEXT NOT NULL,
                        session_id TEXT NOT NULL,
                        worktree TEXT NOT NULL,
                        branch TEXT NOT NULL,
                        target_commit_sha TEXT NOT NULL,
                        started_at TEXT NOT NULL,
                        completed_at TEXT,
                        terminal_status TEXT NOT NULL,
                        result_hash TEXT NOT NULL DEFAULT '',
                        output_text TEXT NOT NULL DEFAULT '',
                        error TEXT,
                        parent_conversation_id TEXT NOT NULL DEFAULT '',
                        created_at TEXT NOT NULL,
                        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
                    )
                """)
                # Check for parent_conversation_id column migration
                inv_cols = [c["name"] for c in conn.execute("PRAGMA table_info(invocations)").fetchall()]
                if "parent_conversation_id" not in inv_cols:
                    conn.execute("ALTER TABLE invocations ADD COLUMN parent_conversation_id TEXT NOT NULL DEFAULT ''")
                conn.execute("CREATE INDEX IF NOT EXISTS idx_invocations_lookup ON invocations (task_id, iteration, role, session_id)")
                conn.execute("CREATE INDEX IF NOT EXISTS idx_invocations_run ON invocations (run_id)")
                conn.execute("INSERT OR IGNORE INTO meta (key, value) VALUES ('agent_dispatch', 'NOT_CONNECTED')")
                conn.execute("INSERT OR IGNORE INTO meta (key, value) VALUES ('version', '3')")
                conn.execute("INSERT OR IGNORE INTO meta (key, value) VALUES ('branch', 'studio/v3-002-agent-orchestrator-r1')")

    def _count_tasks(self) -> int:
        with self._get_connection() as conn:
            row = conn.execute("SELECT COUNT(*) as c FROM tasks").fetchone()
            return row["c"] if row else 0

    def get_meta(self, key: str, default: str = "") -> str:
        with self._get_connection() as conn:
            row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
            return row["value"] if row else default

    def set_meta(self, key: str, value: str) -> None:
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                conn.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", (key, value))

    def claim_task_lease(
        self,
        task_id: str,
        actor: str,
        lease_duration_sec: int = 300,
        claim_token: Optional[str] = None,
    ) -> None:
        """Atomically claim or renew exclusive lease on a task using a unique claim token."""
        claim_id = claim_token or actor
        now = datetime.datetime.now(datetime.timezone.utc)
        expires_at = (now + datetime.timedelta(seconds=lease_duration_sec)).isoformat()
        now_iso = now.isoformat()

        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                row = conn.execute("SELECT lease_owner, lease_expires_at FROM tasks WHERE id = ?", (task_id,)).fetchone()
                if not row:
                    raise ValueError(f"Task {task_id} not found.")

                curr_owner = row["lease_owner"]
                curr_expiry = row["lease_expires_at"]

                # If leased to someone else and not expired, raise conflict
                if curr_owner and curr_owner != claim_id and curr_expiry and curr_expiry > now_iso:
                    raise TaskLeaseConflictError(
                        f"Task {task_id} is currently leased by '{curr_owner}' until {curr_expiry}."
                    )

                conn.execute(
                    "UPDATE tasks SET lease_owner = ?, lease_expires_at = ? WHERE id = ?",
                    (claim_id, expires_at, task_id),
                )

    def release_task_lease(self, task_id: str, actor: str, claim_token: Optional[str] = None) -> None:
        """Release an active lease on a task."""
        claim_id = claim_token or actor
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                conn.execute(
                    "UPDATE tasks SET lease_owner = NULL, lease_expires_at = NULL WHERE id = ? AND (lease_owner = ? OR lease_owner = ?)",
                    (task_id, claim_id, actor),
                )

    # ---------------------------------------------------------
    # Trusted Invocation Registry
    # ---------------------------------------------------------

    def register_invocation(self, record: InvocationRecord) -> None:
        """Register an agent invocation in the trusted provider registry (immutable provenance)."""
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                existing_inv = conn.execute("SELECT invocation_id FROM invocations WHERE invocation_id = ?", (record.invocation_id,)).fetchone()
                if existing_inv:
                    raise PolicyViolation(f"Invocation ID '{record.invocation_id}' already registered. Overwriting provenance is forbidden.")

                # Reusing a session across different tasks or iterations is strictly forbidden
                existing_sess = conn.execute(
                    "SELECT invocation_id, task_id, iteration, role FROM invocations WHERE session_id = ? AND (task_id != ? OR iteration != ?)",
                    (record.session_id, record.task_id, record.iteration),
                ).fetchone()
                if existing_sess:
                    raise PolicyViolation(
                        f"Session '{record.session_id}' already registered under invocation '{existing_sess['invocation_id']}' "
                        f"for task '{existing_sess['task_id']}' iteration {existing_sess['iteration']}. Reusing sessions across tasks or iterations is forbidden."
                    )

                conn.execute("""
                    INSERT INTO invocations (
                        invocation_id, run_id, task_id, iteration, role, provider,
                        session_id, worktree, branch, target_commit_sha, started_at,
                        completed_at, terminal_status, result_hash, output_text, error,
                        parent_conversation_id, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    record.invocation_id,
                    record.run_id,
                    record.task_id,
                    record.iteration,
                    record.role,
                    record.provider,
                    record.session_id,
                    record.worktree,
                    record.branch,
                    record.target_commit_sha,
                    record.started_at,
                    record.completed_at,
                    record.terminal_status,
                    record.result_hash,
                    record.output_text,
                    record.error,
                    record.parent_conversation_id,
                    record.created_at or datetime.datetime.now(datetime.timezone.utc).isoformat(),
                ))

    def update_invocation_completion(
        self,
        invocation_id: str,
        terminal_status: str,
        completed_at: str,
        result_hash: str = "",
        output_text: str = "",
        error: Optional[str] = None,
    ) -> None:
        """Update terminal status and completion payload for a registered invocation."""
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                conn.execute("""
                    UPDATE invocations SET
                        terminal_status = ?,
                        completed_at = ?,
                        result_hash = ?,
                        output_text = ?,
                        error = ?
                    WHERE invocation_id = ?
                """, (terminal_status, completed_at, result_hash, output_text, error, invocation_id))

    def get_invocation(self, invocation_id: str) -> Optional[InvocationRecord]:
        """Fetch an invocation record by unique invocation ID."""
        with self._get_connection() as conn:
            row = conn.execute("SELECT * FROM invocations WHERE invocation_id = ?", (invocation_id,)).fetchone()
            if not row:
                return None
            return InvocationRecord(
                invocation_id=row["invocation_id"],
                run_id=row["run_id"],
                task_id=row["task_id"],
                iteration=row["iteration"],
                role=row["role"],
                provider=row["provider"],
                session_id=row["session_id"],
                worktree=row["worktree"],
                branch=row["branch"],
                target_commit_sha=row["target_commit_sha"],
                started_at=row["started_at"],
                completed_at=row["completed_at"],
                terminal_status=row["terminal_status"],
                result_hash=row["result_hash"],
                output_text=row["output_text"],
                error=row["error"],
                parent_conversation_id=row["parent_conversation_id"] if "parent_conversation_id" in row.keys() else "",
                created_at=row["created_at"],
            )

    def find_invocation_by_session(
        self,
        task_id: str,
        iteration: int,
        role: str,
        session_id: str,
    ) -> Optional[InvocationRecord]:
        """Look up verified provider invocation by task, iteration, role, and session."""
        with self._get_connection() as conn:
            row = conn.execute("""
                SELECT * FROM invocations
                WHERE task_id = ? AND iteration = ? AND role = ? AND session_id = ?
                ORDER BY started_at DESC LIMIT 1
            """, (task_id, iteration, role, session_id)).fetchone()
            if not row:
                return None
            return InvocationRecord(
                invocation_id=row["invocation_id"],
                run_id=row["run_id"],
                task_id=row["task_id"],
                iteration=row["iteration"],
                role=row["role"],
                provider=row["provider"],
                session_id=row["session_id"],
                worktree=row["worktree"],
                branch=row["branch"],
                target_commit_sha=row["target_commit_sha"],
                started_at=row["started_at"],
                completed_at=row["completed_at"],
                terminal_status=row["terminal_status"],
                result_hash=row["result_hash"],
                output_text=row["output_text"],
                error=row["error"],
                parent_conversation_id=row["parent_conversation_id"] if "parent_conversation_id" in row.keys() else "",
                created_at=row["created_at"],
            )

    def list_invocations_for_task(self, task_id: str) -> List[InvocationRecord]:
        """List all registered invocations for a task."""
        with self._get_connection() as conn:
            rows = conn.execute("SELECT * FROM invocations WHERE task_id = ? ORDER BY started_at ASC", (task_id,)).fetchall()
            return [
                InvocationRecord(
                    invocation_id=r["invocation_id"],
                    run_id=r["run_id"],
                    task_id=r["task_id"],
                    iteration=r["iteration"],
                    role=r["role"],
                    provider=r["provider"],
                    session_id=r["session_id"],
                    worktree=r["worktree"],
                    branch=r["branch"],
                    target_commit_sha=r["target_commit_sha"],
                    started_at=r["started_at"],
                    completed_at=r["completed_at"],
                    terminal_status=r["terminal_status"],
                    result_hash=r["result_hash"],
                    output_text=r["output_text"],
                    error=r["error"],
                    parent_conversation_id=r["parent_conversation_id"] if "parent_conversation_id" in r.keys() else "",
                    created_at=r["created_at"],
                )
                for r in rows
            ]

    def list_invocations_for_run(self, run_id: str) -> List[InvocationRecord]:
        """List all registered invocations for an execution run."""
        with self._get_connection() as conn:
            rows = conn.execute("SELECT * FROM invocations WHERE run_id = ? ORDER BY started_at ASC", (run_id,)).fetchall()
            return [
                InvocationRecord(
                    invocation_id=r["invocation_id"],
                    run_id=r["run_id"],
                    task_id=r["task_id"],
                    iteration=r["iteration"],
                    role=r["role"],
                    provider=r["provider"],
                    session_id=r["session_id"],
                    worktree=r["worktree"],
                    branch=r["branch"],
                    target_commit_sha=r["target_commit_sha"],
                    started_at=r["started_at"],
                    completed_at=r["completed_at"],
                    terminal_status=r["terminal_status"],
                    result_hash=r["result_hash"],
                    output_text=r["output_text"],
                    error=r["error"],
                    parent_conversation_id=r["parent_conversation_id"] if "parent_conversation_id" in r.keys() else "",
                    created_at=r["created_at"],
                )
                for r in rows
            ]

    def reconcile_snapshot(self, json_path: Path) -> Dict[str, Any]:
        """Non-destructive synchronization from queue.json snapshot preserving in-flight DB state."""
        if not json_path.exists():
            return {"status": "SNAPSHOT_NOT_FOUND", "imported": [], "updated": []}

        data = json.loads(json_path.read_text(encoding="utf-8"))
        snapshot_tasks = data.get("tasks", [])
        imported = []
        updated = []

        existing_tasks = self.load_all_tasks()
        for t_dict in snapshot_tasks:
            tid = t_dict.get("id")
            if not tid:
                continue
            if tid not in existing_tasks:
                # New task from snapshot: import directly
                new_task = Task.from_dict(t_dict)
                self.save_task(new_task)
                imported.append(tid)
            else:
                # Task exists: merge metadata non-destructively
                db_task = existing_tasks[tid]
                modified = False
                # Update non-state fields if changed in snapshot
                if t_dict.get("title") and db_task.title != t_dict["title"]:
                    db_task.title = t_dict["title"]
                    modified = True
                if t_dict.get("notes") and db_task.notes != t_dict["notes"]:
                    db_task.notes = t_dict["notes"]
                    modified = True
                if "priority" in t_dict and db_task.priority != t_dict["priority"]:
                    db_task.priority = t_dict["priority"]
                    modified = True
                if t_dict.get("blocked_by") is not None and db_task.blocked_by != t_dict["blocked_by"]:
                    db_task.blocked_by = t_dict["blocked_by"]
                    modified = True
                if t_dict.get("active_branch") and db_task.active_branch != t_dict["active_branch"]:
                    db_task.active_branch = t_dict["active_branch"]
                    modified = True

                if modified:
                    self.save_task(db_task)
                    updated.append(tid)

        if self.json_snapshot_path:
            self.export_snapshot(self.json_snapshot_path)

        return {"status": "RECONCILED", "imported": imported, "updated": updated}


    def get_task(self, task_id: str) -> Optional[Task]:
        with self._get_connection() as conn:
            row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
            if not row:
                return None
            issues_rows = conn.execute("SELECT * FROM issues WHERE task_id = ? ORDER BY created_at ASC", (task_id,)).fetchall()
            issues = []
            for ir in issues_rows:
                issues.append(Issue(
                    id=ir["id"],
                    task_id=ir["task_id"],
                    iteration=ir["iteration"],
                    severity=Severity(ir["severity"]),
                    title=ir["title"],
                    reproduction_steps=ir["reproduction_steps"],
                    expected=ir["expected"],
                    actual=ir["actual"],
                    evidence=json.loads(ir["evidence_json"]),
                    status=ir["status"],
                    resolved_by=ir["resolved_by"],
                    created_at=ir["created_at"],
                    resolved_at=ir["resolved_at"],
                ))
            
            ev_manifest_raw = row["evidence_manifest_json"] if "evidence_manifest_json" in row.keys() else "[]"
            manifest = [EvidenceItem.from_dict(m) for m in json.loads(ev_manifest_raw)]

            return Task(
                id=row["id"],
                title=row["title"],
                status=TaskState(row["status"]),
                owner=row["owner"],
                reviewers=json.loads(row["reviewers_json"]),
                blocked_by=json.loads(row["blocked_by_json"]),
                evidence=json.loads(row["evidence_json"]),
                evidence_manifest=manifest,
                reviews=json.loads(row["reviews_json"]),
                iteration=row["iteration"],
                priority=row["priority"],
                active_branch=row["active_branch"],
                current_commit_sha=row["current_commit_sha"] if "current_commit_sha" in row.keys() else "",
                version=row["version"] if "version" in row.keys() else 1,
                lease_owner=row["lease_owner"] if "lease_owner" in row.keys() else None,
                lease_expires_at=row["lease_expires_at"] if "lease_expires_at" in row.keys() else None,
                issues=issues,
                notes=row["notes"],
            )

    def load_all_tasks(self) -> Dict[str, Task]:
        with self._get_connection() as conn:
            rows = conn.execute("SELECT id FROM tasks ORDER BY priority ASC, id ASC").fetchall()
            tasks = {}
            for r in rows:
                t = self.get_task(r["id"])
                if t:
                    tasks[t.id] = t
            return tasks

    def save_task(self, task: Task) -> None:
        """Save task with optimistic locking check (CAS) and atomic JSON snapshot."""
        if task.status == TaskState.APPROVED:
            task.lease_owner = None
            task.lease_expires_at = None

        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                existing = conn.execute("SELECT version FROM tasks WHERE id = ?", (task.id,)).fetchone()
                if existing:
                    current_db_version = existing["version"]
                    if task.version != current_db_version:
                        raise ConcurrentModificationError(
                            f"Task {task.id} version mismatch! In-memory version {task.version} != DB version {current_db_version}. Concurrent edit detected."
                        )
                    new_version = task.version + 1
                    cursor = conn.execute("""
                        UPDATE tasks SET
                            title = ?, status = ?, owner = ?, reviewers_json = ?, blocked_by_json = ?,
                            evidence_json = ?, evidence_manifest_json = ?, reviews_json = ?,
                            iteration = ?, priority = ?, active_branch = ?, current_commit_sha = ?,
                            version = ?, lease_owner = ?, lease_expires_at = ?, notes = ?
                        WHERE id = ? AND version = ?
                    """, (
                        task.title,
                        task.status.value,
                        task.owner,
                        json.dumps(task.reviewers),
                        json.dumps(task.blocked_by),
                        json.dumps(task.evidence),
                        json.dumps([m.to_dict() for m in task.evidence_manifest]),
                        json.dumps(task.reviews),
                        task.iteration,
                        task.priority,
                        task.active_branch,
                        task.current_commit_sha,
                        new_version,
                        task.lease_owner,
                        task.lease_expires_at,
                        task.notes,
                        task.id,
                        task.version,
                    ))
                    if cursor.rowcount == 0:
                        raise ConcurrentModificationError(f"Task {task.id} update conflicted with concurrent writer.")
                    task.version = new_version
                else:
                    # New task insert
                    if not task.version:
                        task.version = 1
                    conn.execute("""
                        INSERT INTO tasks (
                            id, title, status, owner, reviewers_json, blocked_by_json,
                            evidence_json, evidence_manifest_json, reviews_json, iteration,
                            priority, active_branch, current_commit_sha, version, lease_owner,
                            lease_expires_at, notes
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        task.id,
                        task.title,
                        task.status.value,
                        task.owner,
                        json.dumps(task.reviewers),
                        json.dumps(task.blocked_by),
                        json.dumps(task.evidence),
                        json.dumps([m.to_dict() for m in task.evidence_manifest]),
                        json.dumps(task.reviews),
                        task.iteration,
                        task.priority,
                        task.active_branch,
                        task.current_commit_sha,
                        task.version,
                        task.lease_owner,
                        task.lease_expires_at,
                        task.notes,
                    ))

                # Sync issues
                for issue in task.issues:
                    conn.execute("""
                        INSERT OR REPLACE INTO issues (
                            id, task_id, iteration, severity, title, reproduction_steps,
                            expected, actual, evidence_json, status, resolved_by, created_at, resolved_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        issue.id,
                        issue.task_id,
                        issue.iteration,
                        issue.severity.value,
                        issue.title,
                        issue.reproduction_steps,
                        issue.expected,
                        issue.actual,
                        json.dumps(issue.evidence),
                        issue.status,
                        issue.resolved_by,
                        issue.created_at,
                        issue.resolved_at,
                    ))

        if self.json_snapshot_path:
            self.export_snapshot(self.json_snapshot_path)

    def create_issue(self, issue: Issue) -> None:
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                conn.execute("""
                    INSERT OR REPLACE INTO issues (
                        id, task_id, iteration, severity, title, reproduction_steps,
                        expected, actual, evidence_json, status, resolved_by, created_at, resolved_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    issue.id,
                    issue.task_id,
                    issue.iteration,
                    issue.severity.value,
                    issue.title,
                    issue.reproduction_steps,
                    issue.expected,
                    issue.actual,
                    json.dumps(issue.evidence),
                    issue.status,
                    issue.resolved_by,
                    issue.created_at,
                    issue.resolved_at,
                ))
        if self.json_snapshot_path:
            self.export_snapshot(self.json_snapshot_path)

    def resolve_issue(self, issue_id: str, resolved_by: str) -> None:
        now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with FileLock(str(self.lock_path), timeout=10):
            with self._get_connection() as conn:
                conn.execute("""
                    UPDATE issues SET status = 'RESOLVED', resolved_by = ?, resolved_at = ?
                    WHERE id = ?
                """, (resolved_by, now_iso, issue_id))
        if self.json_snapshot_path:
            self.export_snapshot(self.json_snapshot_path)

    def get_open_issues(self, task_id: Optional[str] = None) -> List[Issue]:
        with self._get_connection() as conn:
            if task_id:
                rows = conn.execute("SELECT * FROM issues WHERE task_id = ? AND status = 'OPEN' ORDER BY severity ASC", (task_id,)).fetchall()
            else:
                rows = conn.execute("SELECT * FROM issues WHERE status = 'OPEN' ORDER BY severity ASC").fetchall()
            issues = []
            for ir in rows:
                issues.append(Issue(
                    id=ir["id"],
                    task_id=ir["task_id"],
                    iteration=ir["iteration"],
                    severity=Severity(ir["severity"]),
                    title=ir["title"],
                    reproduction_steps=ir["reproduction_steps"],
                    expected=ir["expected"],
                    actual=ir["actual"],
                    evidence=json.loads(ir["evidence_json"]),
                    status=ir["status"],
                    resolved_by=ir["resolved_by"],
                    created_at=ir["created_at"],
                    resolved_at=ir["resolved_at"],
                ))
            return issues

    def export_snapshot(self, target_json_path: Path) -> None:
        """Atomic write via temporary file and atomic replace under filelock."""
        target_json_path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = target_json_path.with_suffix(".tmp")
        tasks = self.load_all_tasks()
        data = {
            "version": int(self.get_meta("version", "3")),
            "branch": self.get_meta("branch", "studio/production-v3-cleanroom"),
            "agent_dispatch": self.get_meta("agent_dispatch", "NOT_CONNECTED"),
            "tasks": [t.to_dict() for t in tasks.values()],
        }
        with FileLock(str(self.lock_path), timeout=10):
            tmp_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            os.replace(tmp_path, target_json_path)

    def import_snapshot(self, json_path: Path) -> None:
        if not json_path.exists():
            return
        data = json.loads(json_path.read_text(encoding="utf-8"))
        self.set_meta("version", str(data.get("version", 3)))
        self.set_meta("branch", str(data.get("branch", "")))
        self.set_meta("agent_dispatch", str(data.get("agent_dispatch", "NOT_CONNECTED")))
        for t_dict in data.get("tasks", []):
            task = Task.from_dict(t_dict)
            self.save_task(task)
