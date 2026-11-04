"""Atomic state store using SQLite with synchronized JSON snapshot export."""
from __future__ import annotations
import json
import sqlite3
from pathlib import Path
from typing import Dict, List, Optional, Any
from .schemas import Task, TaskState, Issue, Severity


class QueueStore:
    def __init__(self, db_path: Path, json_snapshot_path: Optional[Path] = None):
        self.db_path = db_path
        self.json_snapshot_path = json_snapshot_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()
        if self.json_snapshot_path and self.json_snapshot_path.exists():
            # If DB is empty, bootstrap from JSON
            if self._count_tasks() == 0:
                self.import_snapshot(self.json_snapshot_path)

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _init_db(self) -> None:
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
                    reviews_json TEXT NOT NULL,
                    iteration INTEGER NOT NULL DEFAULT 0,
                    priority INTEGER NOT NULL DEFAULT 0,
                    active_branch TEXT NOT NULL DEFAULT '',
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
            # Initialize metadata if missing
            conn.execute("INSERT OR IGNORE INTO meta (key, value) VALUES ('agent_dispatch', 'NOT_CONNECTED')")
            conn.execute("INSERT OR IGNORE INTO meta (key, value) VALUES ('version', '3')")
            conn.execute("INSERT OR IGNORE INTO meta (key, value) VALUES ('branch', 'studio/v3-002-agent-orchestrator')")

    def _count_tasks(self) -> int:
        with self._get_connection() as conn:
            row = conn.execute("SELECT COUNT(*) as c FROM tasks").fetchone()
            return row["c"] if row else 0

    def get_meta(self, key: str, default: str = "") -> str:
        with self._get_connection() as conn:
            row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
            return row["value"] if row else default

    def set_meta(self, key: str, value: str) -> None:
        with self._get_connection() as conn:
            conn.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", (key, value))

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
            return Task(
                id=row["id"],
                title=row["title"],
                status=TaskState(row["status"]),
                owner=row["owner"],
                reviewers=json.loads(row["reviewers_json"]),
                blocked_by=json.loads(row["blocked_by_json"]),
                evidence=json.loads(row["evidence_json"]),
                reviews=json.loads(row["reviews_json"]),
                iteration=row["iteration"],
                priority=row["priority"],
                active_branch=row["active_branch"],
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
        with self._get_connection() as conn:
            conn.execute("""
                INSERT OR REPLACE INTO tasks (
                    id, title, status, owner, reviewers_json, blocked_by_json,
                    evidence_json, reviews_json, iteration, priority, active_branch, notes
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                task.id,
                task.title,
                task.status.value,
                task.owner,
                json.dumps(task.reviewers),
                json.dumps(task.blocked_by),
                json.dumps(task.evidence),
                json.dumps(task.reviews),
                task.iteration,
                task.priority,
                task.active_branch,
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
        import datetime
        with self._get_connection() as conn:
            conn.execute("""
                UPDATE issues SET status = 'RESOLVED', resolved_by = ?, resolved_at = ?
                WHERE id = ?
            """, (resolved_by, datetime.datetime.now(datetime.timezone.utc).isoformat(), issue_id))
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
        tasks = self.load_all_tasks()
        data = {
            "version": int(self.get_meta("version", "3")),
            "branch": self.get_meta("branch", "studio/production-v3-cleanroom"),
            "agent_dispatch": self.get_meta("agent_dispatch", "NOT_CONNECTED"),
            "tasks": [t.to_dict() for t in tasks.values()],
        }
        target_json_path.parent.mkdir(parents=True, exist_ok=True)
        target_json_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

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
