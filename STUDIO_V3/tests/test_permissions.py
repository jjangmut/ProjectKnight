"""Tests for permissions, self-approval blocking, and dependency gates."""
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
    DependencyBlockedError,
    EvidenceMissingError,
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

        # Create dummy evidence files
        self.evidence1 = self.temp_dir / "evidence_1.md"
        self.evidence1.write_text("# Evidence 1", encoding="utf-8")
        self.evidence_rev = self.temp_dir / "review_evidence.md"
        self.evidence_rev.write_text("# Review Evidence", encoding="utf-8")

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

        # Unauthorized actor attempts start
        with self.assertRaises(PolicyViolation):
            self.dispatcher.start_task("T-001", actor="PK_ArtDirector")

    def test_self_approval_blocked(self):
        """Task owner cannot review or approve their own task."""
        task = Task(
            id="T-002",
            title="Self Review Attempt",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_ClientLead", "PK_QALead"],  # Even if misconfigured
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-002", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        verdict = ReviewVerdict(result="PASS", reviewer_id="PK_ClientLead", evidence_paths=[str(self.evidence_rev)])
        with self.assertRaises(SelfApprovalBlockedError):
            self.dispatcher.review_task("T-002", reviewer="PK_ClientLead", verdict=verdict)

    def test_unauthorized_reviewer_blocked(self):
        """Reviewer not in designated reviewers list cannot review."""
        task = Task(
            id="T-003",
            title="Review Gate",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.submit_work("T-003", actor="PK_ClientLead", evidence_paths=[str(self.evidence1)])

        verdict = ReviewVerdict(result="PASS", reviewer_id="PK_GameDesign", evidence_paths=[str(self.evidence_rev)])
        with self.assertRaises(PolicyViolation):
            self.dispatcher.review_task("T-003", reviewer="PK_GameDesign", verdict=verdict)

    def test_dependency_blocking(self):
        """Task with unapproved dependency cannot be started."""
        dep_task = Task(
            id="DEP-001",
            title="Prerequisite",
            status=TaskState.IN_PROGRESS,  # Not APPROVED
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        task = Task(
            id="DEP-002",
            title="Dependent Task",
            status=TaskState.READY,
            owner="PK_ArtDirector",
            reviewers=["PK_QALead"],
            blocked_by=["DEP-001"],
        )
        self.queue_store.save_task(dep_task)
        self.queue_store.save_task(task)

        with self.assertRaises(DependencyBlockedError):
            self.dispatcher.start_task("DEP-002", actor="PK_ArtDirector")

    def test_missing_evidence_rejected(self):
        """Submission with nonexistent evidence files must fail."""
        task = Task(
            id="T-004",
            title="Missing Evidence Task",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)

        fake_path = str(self.temp_dir / "nonexistent_evidence.png")
        with self.assertRaises(EvidenceMissingError):
            self.dispatcher.submit_work("T-004", actor="PK_ClientLead", evidence_paths=[fake_path])

    def test_protected_branch_safety(self):
        """Direct commits or branches targeting main/master are forbidden."""
        with self.assertRaises(PolicyViolation):
            validate_branch_safety("main")
        with self.assertRaises(PolicyViolation):
            validate_branch_safety("master")
        with self.assertRaises(PolicyViolation):
            validate_branch_safety("origin/main")
        # Allowed feature branch
        validate_branch_safety("studio/v3-002-agent-orchestrator")


if __name__ == "__main__":
    unittest.main()
