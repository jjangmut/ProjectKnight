"""Phase 0 & R2 Security and Blocker Verification Tests.

Reproduces the vulnerabilities and gaps identified in STUDIO_V3/reviews/V3-002-R1-INDEPENDENT-REVIEW.md:
1. Forged review CLI calls with arbitrary session IDs must NOT approve.
2. Provider SUCCEEDED with reviewer verdict FIX_REQUIRED must NOT approve (must reject).
3. Provider SUCCEEDED without parseable structured verdict must NOT approve (fail-closed).
4. Worker AGENT_COMPLETION_NOT_VERIFIED or UNKNOWN must NOT submit or proceed to review.
5. Task claim by same actor role with different run tokens must reject concurrent run (lease token safety).
"""
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
    EvidenceItem,
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
from STUDIO_V3.orchestrator.adapters.mock import MockAdapter


class TestR2BlockersBaseline(unittest.TestCase):
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
        self.dispatcher = TaskDispatcher(self.store, self.event_log, self.repo_root, allow_mock=True)

        # Create dummy evidence file
        self.ev_file = self.studio_dir / "evidence.txt"
        self.ev_file.write_text("sample content", encoding="utf-8")

        # Create test task
        self.task = Task(
            id="TEST-R2-001",
            title="Test R2 Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
            priority=1,
            current_commit_sha="dummy-commit-sha-12345678901234567890",
        )
        self.store.save_task(self.task)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_forged_cli_reviews_must_not_approve(self):
        """Negative Test 1: Arbitrary unverified session IDs from CLI must NOT approve."""
        task = self.dispatcher.start_task("TEST-R2-001", actor="PK_ClientLead")
        task = self.dispatcher.submit_work(
            "TEST-R2-001",
            actor="PK_ClientLead",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        # Forged Review 1: arbitrary unverified session ID
        forged_qa_verdict = ReviewVerdict(
            task_id=task.id,
            iteration=task.iteration,
            agent_role="PK_QALead",
            provider="OPERATOR_CLI",
            invocation_id="forged-inv-1",
            session_id="arbitrary-fake-qa-session-id",
            reviewed_commit_sha=task.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        # Forged Review 2: distinct arbitrary unverified session ID
        forged_dir_verdict = ReviewVerdict(
            task_id=task.id,
            iteration=task.iteration,
            agent_role="PK_GameDirector",
            provider="OPERATOR_CLI",
            invocation_id="forged-inv-2",
            session_id="arbitrary-fake-director-session-id",
            reviewed_commit_sha=task.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        # Under trusted invocation registry enforcement, submitting an unverified session
        # or attempting to approve from unverified CLI sessions MUST fail!
        with self.assertRaises(IdentityVerificationError):
            self.dispatcher.review_task(task.id, forged_qa_verdict)

    def test_provider_succeeded_with_fix_required_verdict_must_reject(self):
        """Negative Test 2: Process SUCCEEDED but reviewer payload FIX_REQUIRED must reject task."""
        task = self.dispatcher.start_task("TEST-R2-001", actor="PK_ClientLead")
        task = self.dispatcher.submit_work(
            "TEST-R2-001",
            actor="PK_ClientLead",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        # Reviewer output payload declaring FIX_REQUIRED
        qa_output = (
            '{"task_id": "TEST-R2-001", "iteration": 1, "role": "PK_QALead", '
            f'"reviewed_commit_sha": "{task.current_commit_sha}", "verdict": "FIX_REQUIRED", '
            '"issues": [{"id": "ISS-01", "severity": "P1", "title": "Defect", '
            '"reproduction_steps": "step", "expected": "ok", "actual": "bad", "evidence": []}], '
            '"evidence_manifest": []}'
        )

        # Adapter returns SUCCEEDED exit status, but output text specifies FIX_REQUIRED
        rev_record = ExecutionRecord(
            invocation_id="inv-rev-01",
            task_id=task.id,
            agent_id="PK_QALead",
            provider="MOCK",
            session_id="sess-qa-01",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="",
            commit_sha=task.current_commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=qa_output,
        )

        # Register the invocation in the trusted registry
        from STUDIO_V3.orchestrator.schemas import InvocationRecord
        self.store.register_invocation(InvocationRecord(
            invocation_id=rev_record.invocation_id,
            run_id="test-run-123",
            task_id=task.id,
            iteration=task.iteration,
            role="PK_QALead",
            provider=rev_record.provider,
            session_id=rev_record.session_id,
            worktree=str(self.repo_root),
            branch="",
            target_commit_sha=task.current_commit_sha,
            started_at=rev_record.start_time,
            completed_at=rev_record.end_time,
            terminal_status="SUCCEEDED",
        ))

        # Dispatcher parsing must parse the verdict as FIX_REQUIRED, NOT PASS!
        verdict = self.dispatcher.parse_reviewer_verdict(rev_record, task)
        self.assertEqual(verdict.result, "FIX_REQUIRED")
        self.assertEqual(len(verdict.issues), 1)

        task = self.dispatcher.review_task(task.id, verdict)
        self.assertEqual(task.status, TaskState.FIX_REQUIRED)

    def test_provider_succeeded_without_parseable_verdict_must_fail_closed(self):
        """Negative Test 3: Process SUCCEEDED with non-JSON or missing verdict must fail-closed."""
        task = self.dispatcher.start_task("TEST-R2-001", actor="PK_ClientLead")
        task = self.dispatcher.submit_work(
            "TEST-R2-001",
            actor="PK_ClientLead",
            evidence_paths=[str(self.ev_file.relative_to(self.repo_root))],
        )

        rev_record = ExecutionRecord(
            invocation_id="inv-rev-02",
            task_id=task.id,
            agent_id="PK_QALead",
            provider="MOCK",
            session_id="sess-qa-02",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="",
            commit_sha=task.current_commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text="Just some text without structured JSON verdict",
        )

        # Must fail-closed (raise error or mark NOT_VERIFIED, never PASS)
        with self.assertRaises(PolicyViolation):
            self.dispatcher.parse_reviewer_verdict(rev_record, task)

    def test_worker_unverified_status_must_not_submit(self):
        """Negative Test 4: Worker with AGENT_COMPLETION_NOT_VERIFIED or UNKNOWN must halt."""
        task = self.dispatcher.start_task("TEST-R2-001", actor="PK_ClientLead")

        worker_record = ExecutionRecord(
            invocation_id="inv-worker-03",
            task_id=task.id,
            agent_id="PK_ClientLead",
            provider="ANTIGRAVITY_AGENTAPI",
            session_id="sess-worker-03",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="",
            commit_sha="",
            exit_code=0,
            status=ExecutionStatus.AGENT_COMPLETION_NOT_VERIFIED,
            evidence_manifest=[],
            output_text="",
            error="Completion not verified",
        )

        # Loop must stop and NOT submit work deliverables
        self.assertFalse(self.dispatcher.is_worker_execution_acceptable(worker_record))


if __name__ == "__main__":
    unittest.main()
