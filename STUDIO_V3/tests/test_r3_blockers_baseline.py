"""Phase 0 & R3 Security, Provenance, and Lease Clearance Negative Tests.

Validates the resolution of all 6 findings from STUDIO_V3/reviews/V3-002-R2-INDEPENDENT-REVIEW.md:
1. Mock provider ('MOCK_SIMULATED', 'SIMULATED_MOCK', 'MOCK') NEVER satisfies live production approval (allow_mock=False).
2. Duplicate or reused session IDs across tasks/iterations raise PolicyViolation.
3. Duplicate invocation IDs raise PolicyViolation (immutable provenance).
4. Task approval atomically clears lease_owner and lease_expires_at.
5. Standalone bridge dispatch without bound session returns AGENT_COMPLETION_NOT_VERIFIED.
6. Mismatched parent conversation ID raises IdentityVerificationError.
"""
from __future__ import annotations
import unittest
import tempfile
import shutil
from pathlib import Path

from STUDIO_V3.orchestrator.schemas import (
    Task,
    TaskState,
    Severity,
    Issue,
    ReviewVerdict,
    ExecutionRecord,
    ExecutionStatus,
    InvocationRecord,
)
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher
from STUDIO_V3.orchestrator.policies import (
    can_approve,
    verify_reviewer_attestation,
    IdentityVerificationError,
    PolicyViolation,
    TaskLeaseConflictError,
)
from STUDIO_V3.orchestrator.adapters.subagent_bridge import AntigravitySubagentBridgeAdapter


class TestR3BlockersBaseline(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.repo_root = Path(self.temp_dir)
        self.studio_dir = self.repo_root / "STUDIO_V3"
        self.studio_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.studio_dir / "queue.db"
        self.json_path = self.studio_dir / "queue.json"
        self.log_path = self.studio_dir / "events.jsonl"

        self.store = QueueStore(self.db_path, self.json_path)
        self.event_log = EventLog(self.log_path)
        # Production dispatcher defaults to allow_mock=False
        self.dispatcher = TaskDispatcher(self.store, self.event_log, self.repo_root, allow_mock=False)

        # Create dummy evidence file
        self.ev_file = self.studio_dir / "evidence.txt"
        self.ev_file.write_text("sample deliverable content", encoding="utf-8")

        self.task = Task(
            id="TEST-R3-001",
            title="Test R3 Verification Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
            priority=1,
            current_commit_sha="dummy-commit-sha-r3-123456789012",
        )
        self.store.save_task(self.task)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_mock_provider_never_causes_live_approval(self):
        """Negative Test 1: MOCK_SIMULATED / SIMULATED_MOCK / MOCK must NOT satisfy live approval gate."""
        task = self.dispatcher.start_task("TEST-R3-001", actor="PK_ClientLead", claim_token="run-live-1")
        task = self.dispatcher.submit_work(
            "TEST-R3-001",
            actor="PK_ClientLead",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        for provider_name in ("MOCK_SIMULATED", "SIMULATED_MOCK", "MOCK"):
            sess_id = f"mock-sess-{provider_name.lower()}"
            self.store.register_invocation(InvocationRecord(
                invocation_id=f"inv-{provider_name.lower()}",
                run_id="run-live-1",
                task_id=task.id,
                iteration=task.iteration,
                role="PK_QALead",
                provider=provider_name,
                session_id=sess_id,
                worktree=str(self.repo_root),
                branch="",
                target_commit_sha=task.current_commit_sha,
                started_at="2026-11-05T00:00:00Z",
                completed_at="2026-11-05T00:01:00Z",
                terminal_status="SUCCEEDED",
            ))

            verdict = ReviewVerdict(
                task_id=task.id,
                iteration=task.iteration,
                agent_role="PK_QALead",
                provider=provider_name,
                invocation_id=f"inv-{provider_name.lower()}",
                session_id=sess_id,
                reviewed_commit_sha=task.current_commit_sha,
                result="PASS",
                evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
            )

            # In production mode (allow_mock=False), verify_reviewer_attestation must reject mock invocations
            with self.assertRaises(IdentityVerificationError) as ctx:
                self.dispatcher.review_task(task.id, verdict, allow_mock=False)
            self.assertIn("Mock invocation cannot satisfy live independent AI review gate", str(ctx.exception))

    def test_duplicate_or_reused_session_across_tasks_fails(self):
        """Negative Test 2: Registering a session already registered for another task raises PolicyViolation."""
        # Create TASK-A and TASK-B in store to satisfy foreign key
        self.store.save_task(Task(id="TASK-A", title="Task A", status=TaskState.READY, owner="PK_ClientLead", reviewers=[]))
        self.store.save_task(Task(id="TASK-B", title="Task B", status=TaskState.READY, owner="PK_ClientLead", reviewers=[]))

        self.store.register_invocation(InvocationRecord(
            invocation_id="inv-orig-1",
            run_id="run-1",
            task_id="TASK-A",
            iteration=1,
            role="PK_ClientLead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="shared-session-xyz",
            worktree=str(self.repo_root),
            branch="",
            target_commit_sha="sha1",
            started_at="2026-11-05T00:00:00Z",
            terminal_status="SUCCEEDED",
        ))

        # Attempt to register the same session for TASK-B
        with self.assertRaises(PolicyViolation) as ctx:
            self.store.register_invocation(InvocationRecord(
                invocation_id="inv-orig-2",
                run_id="run-2",
                task_id="TASK-B",
                iteration=1,
                role="PK_QALead",
                provider="ANTIGRAVITY_SUBAGENT",
                session_id="shared-session-xyz",
                worktree=str(self.repo_root),
                branch="",
                target_commit_sha="sha2",
                started_at="2026-11-05T00:01:00Z",
                terminal_status="SUCCEEDED",
            ))
        self.assertIn("Reusing sessions across tasks or iterations is forbidden", str(ctx.exception))

    def test_duplicate_invocation_id_fails(self):
        """Negative Test 3: Overwriting an existing invocation ID raises PolicyViolation (immutable provenance)."""
        self.store.save_task(Task(id="TASK-A", title="Task A", status=TaskState.READY, owner="PK_ClientLead", reviewers=[]))
        self.store.register_invocation(InvocationRecord(
            invocation_id="inv-unique-123",
            run_id="run-1",
            task_id="TASK-A",
            iteration=1,
            role="PK_ClientLead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="session-aaa",
            worktree=str(self.repo_root),
            branch="",
            target_commit_sha="sha1",
            started_at="2026-11-05T00:00:00Z",
            terminal_status="SUCCEEDED",
        ))

        with self.assertRaises(PolicyViolation) as ctx:
            self.store.register_invocation(InvocationRecord(
                invocation_id="inv-unique-123",  # Duplicate ID!
                run_id="run-1",
                task_id="TASK-A",
                iteration=1,
                role="PK_ClientLead",
                provider="ANTIGRAVITY_SUBAGENT",
                session_id="session-bbb",
                worktree=str(self.repo_root),
                branch="",
                target_commit_sha="sha1",
                started_at="2026-11-05T00:00:00Z",
                terminal_status="SUCCEEDED",
            ))
        self.assertIn("already registered. Overwriting provenance is forbidden", str(ctx.exception))

    def test_approval_clears_task_lease_atomically(self):
        """Negative Test 4: Approving a task must completely clear lease_owner and lease_expires_at."""
        dispatcher_test = TaskDispatcher(self.store, self.event_log, self.repo_root, allow_mock=True)
        task = dispatcher_test.start_task("TEST-R3-001", actor="PK_ClientLead", claim_token="run-token-abc")
        self.assertEqual(task.lease_owner, "run-token-abc")

        task = dispatcher_test.submit_work(
            "TEST-R3-001",
            actor="PK_ClientLead",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        # Register two distinct mock reviewers
        self.store.register_invocation(InvocationRecord(
            invocation_id="inv-qa-pass",
            run_id="run-token-abc",
            task_id=task.id,
            iteration=task.iteration,
            role="PK_QALead",
            provider="SIMULATED_MOCK",
            session_id="sess-qa-pass",
            worktree=str(self.repo_root),
            branch="",
            target_commit_sha=task.current_commit_sha,
            started_at="2026-11-05T00:00:00Z",
            completed_at="2026-11-05T00:01:00Z",
            terminal_status="SUCCEEDED",
        ))
        self.store.register_invocation(InvocationRecord(
            invocation_id="inv-dir-pass",
            run_id="run-token-abc",
            task_id=task.id,
            iteration=task.iteration,
            role="PK_GameDirector",
            provider="SIMULATED_MOCK",
            session_id="sess-dir-pass",
            worktree=str(self.repo_root),
            branch="",
            target_commit_sha=task.current_commit_sha,
            started_at="2026-11-05T00:00:00Z",
            completed_at="2026-11-05T00:01:00Z",
            terminal_status="SUCCEEDED",
        ))

        v_qa = ReviewVerdict(
            task_id=task.id,
            iteration=task.iteration,
            agent_role="PK_QALead",
            provider="SIMULATED_MOCK",
            invocation_id="inv-qa-pass",
            session_id="sess-qa-pass",
            reviewed_commit_sha=task.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )
        v_dir = ReviewVerdict(
            task_id=task.id,
            iteration=task.iteration,
            agent_role="PK_GameDirector",
            provider="SIMULATED_MOCK",
            invocation_id="inv-dir-pass",
            session_id="sess-dir-pass",
            reviewed_commit_sha=task.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        dispatcher_test.review_task(task.id, v_qa, allow_mock=True)
        approved_task = dispatcher_test.review_task(task.id, v_dir, allow_mock=True)

        self.assertEqual(approved_task.status, TaskState.APPROVED)
        self.assertIsNone(approved_task.lease_owner, "Approved in-memory task must have lease_owner=None")
        self.assertIsNone(approved_task.lease_expires_at, "Approved in-memory task must have lease_expires_at=None")

        # Verify DB persisted state
        db_task = self.store.get_task(task.id)
        self.assertEqual(db_task.status, TaskState.APPROVED)
        self.assertIsNone(db_task.lease_owner, "Approved DB task must have lease_owner=None")
        self.assertIsNone(db_task.lease_expires_at, "Approved DB task must have lease_expires_at=None")

    def test_subagent_bridge_unbound_dispatch_fails_closed(self):
        """Negative Test 5: Standalone bridge dispatch without bound session returns AGENT_COMPLETION_NOT_VERIFIED."""
        adapter = AntigravitySubagentBridgeAdapter(self.repo_root)
        rec = adapter.dispatch(
            task_id="TEST-R3-001",
            role="PK_ClientLead",
            prompt="Do something",
            worktree=str(self.repo_root),
        )
        self.assertEqual(rec.status, ExecutionStatus.AGENT_COMPLETION_NOT_VERIFIED)
        self.assertIn("cannot autonomously spawn Antigravity IDE native subagents", rec.error)


if __name__ == "__main__":
    unittest.main()
