"""Tests for independent review gates, issue creation, and two-key signoff."""
import unittest
import tempfile
import shutil
from pathlib import Path

from STUDIO_V3.orchestrator.schemas import Task, TaskState, Severity, ReviewVerdict, Issue
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher


class TestReviewGate(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp())
        self.db_path = self.temp_dir / "queue.db"
        self.log_path = self.temp_dir / "events.jsonl"
        self.queue_store = QueueStore(self.db_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.queue_store, self.event_log, self.temp_dir)

        # Evidence files
        self.work_evidence = self.temp_dir / "work_output.md"
        self.work_evidence.write_text("# Work Output", encoding="utf-8")
        self.qa_evidence = self.temp_dir / "qa_report.md"
        self.qa_evidence.write_text("# QA Report", encoding="utf-8")
        self.dir_evidence = self.temp_dir / "director_review.md"
        self.dir_evidence.write_text("# Director Signoff", encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_single_reviewer_pass_insufficient(self):
        """When 2 reviewers are designated, 1 PASS leaves status in IN_REVIEW."""
        task = Task(
            id="REV-001",
            title="Multi-reviewer Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.start_task("REV-001", actor="PK_ClientLead")
        self.dispatcher.submit_work("REV-001", actor="PK_ClientLead", evidence_paths=[str(self.work_evidence)])

        # QA passes
        verdict = ReviewVerdict(result="PASS", reviewer_id="PK_QALead", evidence_paths=[str(self.qa_evidence)])
        updated = self.dispatcher.review_task("REV-001", reviewer="PK_QALead", verdict=verdict)

        self.assertEqual(updated.status, TaskState.IN_REVIEW)
        self.assertIn("PK_QALead", updated.reviews)
        self.assertEqual(updated.reviews["PK_QALead"]["result"], "PASS")

    def test_both_reviewers_pass_approves(self):
        """When both QA and GameDirector pass, task transitions to APPROVED."""
        task = Task(
            id="REV-002",
            title="Full Approval Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.start_task("REV-002", actor="PK_ClientLead")
        self.dispatcher.submit_work("REV-002", actor="PK_ClientLead", evidence_paths=[str(self.work_evidence)])

        # 1. QA passes
        v_qa = ReviewVerdict(result="PASS", reviewer_id="PK_QALead", evidence_paths=[str(self.qa_evidence)])
        self.dispatcher.review_task("REV-002", reviewer="PK_QALead", verdict=v_qa)

        # 2. Director passes
        v_dir = ReviewVerdict(result="PASS", reviewer_id="PK_GameDirector", evidence_paths=[str(self.dir_evidence)])
        final_task = self.dispatcher.review_task("REV-002", reviewer="PK_GameDirector", verdict=v_dir)

        self.assertEqual(final_task.status, TaskState.APPROVED)

    def test_qa_rejection_creates_issue_and_sets_fix_required(self):
        """When QA rejects with issues, task transitions to FIX_REQUIRED and issues are saved."""
        task = Task(
            id="REV-003",
            title="Defect Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.start_task("REV-003", actor="PK_ClientLead")
        self.dispatcher.submit_work("REV-003", actor="PK_ClientLead", evidence_paths=[str(self.work_evidence)])

        issue = Issue(
            id="ISS-001",
            task_id="REV-003",
            iteration=1,
            severity=Severity.P1,
            title="Collision glitch",
            reproduction_steps="Walk right into wall",
            expected="Player stops",
            actual="Player clips through",
            evidence=[str(self.qa_evidence)],
        )
        verdict = ReviewVerdict(
            result="FIX_REQUIRED",
            reviewer_id="PK_QALead",
            evidence_paths=[str(self.qa_evidence)],
            issues=[issue],
            notes="Collision bug must be fixed.",
        )
        updated = self.dispatcher.review_task("REV-003", reviewer="PK_QALead", verdict=verdict)

        self.assertEqual(updated.status, TaskState.FIX_REQUIRED)
        open_issues = self.queue_store.get_open_issues("REV-003")
        self.assertEqual(len(open_issues), 1)
        self.assertEqual(open_issues[0].id, "ISS-001")


if __name__ == "__main__":
    unittest.main()
