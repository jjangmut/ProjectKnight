"""Tests for permissions, self-approval blocking, cryptographic evidence tampering, and session attestation (V3-002-R1)."""
import unittest
import tempfile
import shutil
from pathlib import Path

from STUDIO_V3.orchestrator.schemas import Task, TaskState, Severity, ReviewVerdict, Issue
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher
from STUDIO_V3.orchestrator.policies import (
    PolicyViolation,
    SelfApprovalBlockedError,
    IdentityVerificationError,
    EvidenceMissingError,
    EvidenceTamperedError,
    StaleEvidenceError,
    StaleReviewError,
    DependencyBlockedError,
    validate_branch_safety,
)


class TestPermissionsAndPolicies(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp())
        self.db_path = self.temp_dir / "queue.db"
        self.log_path = self.temp_dir / "events.jsonl"
        self.queue_store = QueueStore(self.db_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.queue_store, self.event_log, self.temp_dir)

        # Create valid evidence files
        self.evidence1 = self.temp_dir / "evidence_1.md"
        self.evidence1.write_text("# Evidence 1 Content", encoding="utf-8")
        self.evidence_rev = self.temp_dir / "review_evidence.md"
        self.evidence_rev.write_text("# Review Evidence Content", encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_unauthorized_start_blocked(self):
        """Worker cannot start a task owned by someone else."""
        task = Task(
            id="T-001",
            title="Worker Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)

        with self.assertRaises(PolicyViolation):
            self.dispatcher.start_task("T-001", actor="PK_ArtDirector")

    def test_self_approval_blocked(self):
        """Task owner cannot review or approve their own task."""
        task = Task(
            id="T-002",
            title="Self Review Attempt",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_ClientLead", "PK_QALead"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-002", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        t = self.queue_store.get_task("T-002")
        verdict = ReviewVerdict(
            task_id="T-002",
            iteration=t.iteration,
            agent_role="PK_ClientLead",
            provider="LOCAL",
            invocation_id="inv-rev-1",
            session_id="sess-rev-1",
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.evidence_rev)],
        )
        with self.assertRaises(SelfApprovalBlockedError):
            self.dispatcher.review_task("T-002", verdict=verdict)

    def test_reused_worker_session_rejected(self):
        """Reviewer cannot spoof or reuse the worker's session ID."""
        task = Task(
            id="T-003",
            title="Session Spoofing Attempt",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-003", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        t = self.queue_store.get_task("T-003")
        worker_session = "worker-sess-999"
        verdict = ReviewVerdict(
            task_id="T-003",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="LOCAL",
            invocation_id="inv-rev-2",
            session_id=worker_session,  # Reused worker session!
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.evidence_rev)],
        )
        with self.assertRaises(IdentityVerificationError):
            self.dispatcher.review_task("T-003", verdict=verdict, worker_session_id=worker_session)

    def test_empty_session_id_rejected(self):
        """Reviewer without an authenticated session ID is rejected."""
        task = Task(
            id="T-004",
            title="Empty Session Review",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-004", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        t = self.queue_store.get_task("T-004")
        verdict = ReviewVerdict(
            task_id="T-004",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="LOCAL",
            invocation_id="inv-rev-3",
            session_id="",  # Empty session
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.evidence_rev)],
        )
        with self.assertRaises(IdentityVerificationError):
            self.dispatcher.review_task("T-004", verdict=verdict)

    def test_tampered_evidence_rejected(self):
        """If an evidence file is modified on disk after submission, review is rejected."""
        task = Task(
            id="T-005",
            title="Evidence Tamper Check",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-005", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        # Maliciously tamper with the evidence file after submission
        self.evidence1.write_text("# Maliciously Altered Content", encoding="utf-8")

        t = self.queue_store.get_task("T-005")
        from STUDIO_V3.orchestrator.schemas import InvocationRecord
        self.queue_store.register_invocation(InvocationRecord(
            invocation_id="inv-rev-4",
            run_id="test-run",
            task_id="T-005",
            iteration=t.iteration,
            role="PK_QALead",
            provider="SIMULATED_MOCK",
            session_id="qa-sess-unique-4",
            worktree=str(self.temp_dir),
            branch="",
            target_commit_sha=t.current_commit_sha,
            started_at="2026-11-05T00:00:00Z",
            completed_at="2026-11-05T00:01:00Z",
            terminal_status="SUCCEEDED",
        ))

        verdict = ReviewVerdict(
            task_id="T-005",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="SIMULATED_MOCK",
            invocation_id="inv-rev-4",
            session_id="qa-sess-unique-4",
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.evidence_rev)],
        )
        with self.assertRaises(EvidenceTamperedError):
            self.dispatcher.review_task("T-005", verdict=verdict)

    def test_stale_commit_review_rejected(self):
        """Review for a commit SHA that doesn't match current task commit is rejected."""
        task = Task(
            id="T-006",
            title="Stale Commit Review",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-006", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        t = self.queue_store.get_task("T-006")
        verdict = ReviewVerdict(
            task_id="T-006",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="LOCAL",
            invocation_id="inv-rev-5",
            session_id="qa-sess-unique-5",
            reviewed_commit_sha="stale_sha_9999999",  # Wrong commit
            result="PASS",
            evidence_paths=[str(self.evidence_rev)],
        )
        with self.assertRaises(StaleReviewError):
            self.dispatcher.review_task("T-006", verdict=verdict)

    def test_protected_branch_safety(self):
        """Direct commits or branches targeting main/master are forbidden."""
        with self.assertRaises(PolicyViolation):
            validate_branch_safety("main")
        with self.assertRaises(PolicyViolation):
            validate_branch_safety("master")
        with self.assertRaises(PolicyViolation):
            validate_branch_safety("integration")
        validate_branch_safety("studio/v3-002-agent-orchestrator-r1")


if __name__ == "__main__":
    unittest.main()
