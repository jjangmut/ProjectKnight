"""Single-Entry Orchestrator Runner for Live Multi-Agent Proof (V3-002-R2).

Executes and tracks real multi-agent cycles under a single correlated run_id:
1. Producer initializes and leases task.
2. Ingests and verifies real worker and reviewer subagents via AntigravitySubagentBridgeAdapter.
3. Authenticates provider metadata through agentapi.bat get-conversation-metadata.
4. Parses structured review JSON verdicts and persists issues into SQLite and queue.json.
5. Verifies git commits and SHA256 evidence integrity gates.
6. Exports complete audit trail, before/after states, and invocation records.
"""
from __future__ import annotations
import json
import uuid
import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional

from .schemas import (
    Task,
    TaskState,
    Severity,
    Issue,
    ReviewVerdict,
    ExecutionRecord,
    ExecutionStatus,
    InvocationRecord,
)
from .queue_store import QueueStore
from .event_log import EventLog
from .dispatcher import TaskDispatcher
from .policies import can_approve, calculate_sha256, build_evidence_manifest
from .adapters.subagent_bridge import AntigravitySubagentBridgeAdapter


class SingleEntryRunner:
    """Coordinates a complete multi-agent workflow under one authoritative run_id."""

    def __init__(self, repo_root: Path, run_id: Optional[str] = None):
        self.repo_root = repo_root.resolve()
        self.studio_dir = repo_root / "STUDIO_V3"
        self.db_path = self.studio_dir / "queue.db"
        self.json_path = self.studio_dir / "queue.json"
        self.log_path = self.studio_dir / "events.jsonl"

        self.store = QueueStore(self.db_path, self.json_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.store, self.event_log, self.repo_root)
        self.adapter = AntigravitySubagentBridgeAdapter(self.repo_root)

        active_run_file = self.studio_dir / ".active_run_id"
        if run_id:
            self.run_id = run_id
            active_run_file.write_text(self.run_id, encoding="utf-8")
        elif active_run_file.exists():
            self.run_id = active_run_file.read_text(encoding="utf-8").strip()
        else:
            self.run_id = f"run-r2-{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"
            active_run_file.write_text(self.run_id, encoding="utf-8")

        self.audit_log: List[Dict[str, Any]] = []

    def setup_fixture_task(self, task_id: str, title: str, owner: str, reviewers: List[str]) -> Task:
        """Create or initialize throwaway test fixture task."""
        task = self.store.get_task(task_id)
        if not task:
            task = Task(
                id=task_id,
                title=title,
                status=TaskState.READY,
                owner=owner,
                reviewers=reviewers,
                priority=99,
                active_branch="studio/v3-002-agent-orchestrator-r2",
                notes="Throwaway live multi-agent verification fixture for TASK V3-002-R2.",
            )
            self.store.save_task(task)
        return task

    def step_start_task(self, task_id: str, actor: Optional[str] = None) -> Task:
        """Start task with unique run token lease."""
        task = self.store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")
        claim_actor = actor or task.owner
        task = self.dispatcher.start_task(task_id, actor=claim_actor, claim_token=self.run_id)
        self.audit_log.append({
            "action": "START_TASK",
            "task_id": task.id,
            "iteration": task.iteration,
            "status": task.status.value,
            "run_id": self.run_id,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        })
        return task

    def step_worker_delivery(
        self,
        task_id: str,
        session_id: str,
        commit_sha: str,
        evidence_files: List[str],
        parent_conversation_id: str = "",
    ) -> ExecutionRecord:
        """Ingest real worker subagent session, verify identity, and submit work."""
        task = self.store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        # Ingest and verify subagent execution via AgentAPI
        rec = self.adapter.ingest_verified_subagent_execution(
            task_id=task.id,
            role=task.owner,
            session_id=session_id,
            target_commit_sha=commit_sha,
            expected_deliverables=evidence_files,
            expected_parent_conversation_id=parent_conversation_id or None,
        )

        # Register in trusted invocation registry if not already registered
        if not self.store.get_invocation(rec.invocation_id):
            self.store.register_invocation(InvocationRecord(
                invocation_id=rec.invocation_id,
                run_id=self.run_id,
                task_id=task.id,
                iteration=task.iteration,
                role=task.owner,
                provider="ANTIGRAVITY_SUBAGENT",
                session_id=rec.session_id,
                worktree=str(self.repo_root),
                branch=task.active_branch,
                target_commit_sha=commit_sha,
                started_at=rec.start_time,
                completed_at=rec.end_time,
                terminal_status=rec.status.value,
                result_hash=rec.evidence_manifest[0].sha256 if rec.evidence_manifest else "",
                output_text=rec.output_text,
                error=rec.error,
                parent_conversation_id=parent_conversation_id,
            ))

        # Submit work on verified commit SHA
        self.dispatcher.submit_work(
            task_id=task.id,
            actor=task.owner,
            evidence_paths=evidence_files,
            invocation_id=rec.invocation_id,
            target_commit_sha=commit_sha,
        )

        self.audit_log.append({
            "action": "WORKER_DELIVERY",
            "task_id": task.id,
            "iteration": task.iteration,
            "session_id": session_id,
            "commit_sha": commit_sha,
            "status": "SUBMITTED",
        })
        return rec

    def step_reviewer_verdict(
        self,
        task_id: str,
        reviewer_role: str,
        session_id: str,
        commit_sha: str,
        worker_session_id: str,
        evidence_files: Optional[List[str]] = None,
        parent_conversation_id: str = "",
    ) -> ReviewVerdict:
        """Ingest real reviewer subagent session, verify identity, parse verdict, and apply review."""
        task = self.store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        # Ingest and verify subagent execution via AgentAPI
        rec = self.adapter.ingest_verified_subagent_execution(
            task_id=task.id,
            role=reviewer_role,
            session_id=session_id,
            target_commit_sha=commit_sha,
            expected_deliverables=evidence_files,
            expected_parent_conversation_id=parent_conversation_id or None,
        )

        # Register in trusted invocation registry if not already registered
        if not self.store.get_invocation(rec.invocation_id):
            self.store.register_invocation(InvocationRecord(
                invocation_id=rec.invocation_id,
                run_id=self.run_id,
                task_id=task.id,
                iteration=task.iteration,
                role=reviewer_role,
                provider="ANTIGRAVITY_SUBAGENT",
                session_id=rec.session_id,
                worktree=str(self.repo_root),
                branch=task.active_branch,
                target_commit_sha=commit_sha,
                started_at=rec.start_time,
                completed_at=rec.end_time,
                terminal_status=rec.status.value,
                result_hash="",
                output_text=rec.output_text,
                error=rec.error,
                parent_conversation_id=parent_conversation_id,
            ))

        # Parse structured review JSON
        verdict = self.dispatcher.parse_reviewer_verdict(rec, task)

        # Apply review transition
        self.dispatcher.review_task(
            task_id=task.id,
            verdict=verdict,
            worker_session_id=worker_session_id,
        )

        self.audit_log.append({
            "action": "REVIEW_VERDICT",
            "task_id": task.id,
            "iteration": task.iteration,
            "reviewer": reviewer_role,
            "session_id": session_id,
            "result": verdict.result,
            "issues": [i.id for i in verdict.issues],
        })
        return verdict
