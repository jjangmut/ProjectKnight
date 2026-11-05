"""Tests for independent review gates, issue creation, and two-key signoff (V3-002-R1)."""
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
        self.dispatcher = TaskDispatcher(self.queue_store, self.event_log, self.temp_dir, allow_mock=True)

        # Evidence files
        self.work_evidence = self.temp_dir / "work_output.md"
        self.work_evidence.write_text("# Work Output", encoding="utf-8")
        self.qa_evidence = self.temp_dir / "qa_report.md"
        self.qa_evidence.write_text("# QA Report", encoding="utf-8")
        self.dir_evidence = self.temp_dir / "director_review.md"
        self.dir_evidence.write_text("# Director Signoff", encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _register_mock_invocation(self, task_id: str, iteration: int, role: str, session_id: str, commit_sha: str = ""):
        from STUDIO_V3.orchestrator.schemas import InvocationRecord
        self.queue_store.register_invocation(InvocationRecord(
            invocation_id=f"inv-{role}-{session_id}",
            run_id="test-run",
            task_id=task_id,
            iteration=iteration,
            role=role,
            provider="SIMULATED_MOCK",
            session_id=session_id,
            worktree=str(self.temp_dir),
            branch="",
            target_commit_sha=commit_sha,
            started_at="2026-11-05T00:00:00Z",
            completed_at="2026-11-05T00:01:00Z",
            terminal_status="SUCCEEDED",
        ))

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

        t = self.queue_store.get_task("REV-001")
        self._register_mock_invocation("REV-001", t.iteration, "PK_QALead", "qa-sess-distinct-1", t.current_commit_sha)
        verdict = ReviewVerdict(
            task_id="REV-001",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="SIMULATED_MOCK",
            invocation_id="inv-qa-1",
            session_id="qa-sess-distinct-1",
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.qa_evidence)],
        )
        updated = self.dispatcher.review_task("REV-001", verdict=verdict)

        self.assertEqual(updated.status, TaskState.IN_REVIEW)
        self.assertIn("PK_QALead", updated.reviews)
        self.assertEqual(updated.reviews["PK_QALead"]["result"], "PASS")

    def test_both_reviewers_pass_approves(self):
        """When both QA and GameDirector pass with distinct sessions, task transitions to APPROVED."""
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

        t = self.queue_store.get_task("REV-002")

        # 1. QA passes with distinct session
        self._register_mock_invocation("REV-002", t.iteration, "PK_QALead", "qa-sess-distinct-2", t.current_commit_sha)
        v_qa = ReviewVerdict(
            task_id="REV-002",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="SIMULATED_MOCK",
            invocation_id="inv-qa-2",
            session_id="qa-sess-distinct-2",
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.qa_evidence)],
        )
        self.dispatcher.review_task("REV-002", verdict=v_qa)

        # 2. Director passes with distinct session
        self._register_mock_invocation("REV-002", t.iteration, "PK_GameDirector", "dir-sess-distinct-2", t.current_commit_sha)
        v_dir = ReviewVerdict(
            task_id="REV-002",
            iteration=t.iteration,
            agent_role="PK_GameDirector",
            provider="SIMULATED_MOCK",
            invocation_id="inv-dir-2",
            session_id="dir-sess-distinct-2",
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.dir_evidence)],
        )
        final_task = self.dispatcher.review_task("REV-002", verdict=v_dir)

        self.assertEqual(final_task.status, TaskState.APPROVED)

    def test_duplicate_reviewer_sessions_rejected(self):
        """When QA and Director attempt to use the same session ID, approval is blocked."""
        task = Task(
            id="REV-003",
            title="Duplicate Session Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.start_task("REV-003", actor="PK_ClientLead")
        self.dispatcher.submit_work("REV-003", actor="PK_ClientLead", evidence_paths=[str(self.work_evidence)])

        t = self.queue_store.get_task("REV-003")
        shared_session = "shared-spoofed-sess-99"
        self._register_mock_invocation("REV-003", t.iteration, "PK_QALead", shared_session, t.current_commit_sha)
        self._register_mock_invocation("REV-003", t.iteration, "PK_GameDirector", shared_session, t.current_commit_sha)

        v_qa = ReviewVerdict(
            task_id="REV-003",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="SIMULATED_MOCK",
            invocation_id="inv-qa-3",
            session_id=shared_session,
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.qa_evidence)],
        )
        self.dispatcher.review_task("REV-003", verdict=v_qa)

        v_dir = ReviewVerdict(
            task_id="REV-003",
            iteration=t.iteration,
            agent_role="PK_GameDirector",
            provider="SIMULATED_MOCK",
            invocation_id="inv-dir-3",
            session_id=shared_session,  # Identical to QA session!
            reviewed_commit_sha=t.current_commit_sha,
            result="PASS",
            evidence_paths=[str(self.dir_evidence)],
        )
        res_task = self.dispatcher.review_task("REV-003", verdict=v_dir)

        # Should remain IN_REVIEW because independent agents were not established
        self.assertEqual(res_task.status, TaskState.IN_REVIEW)

    def test_qa_rejection_creates_issue_and_sets_fix_required(self):
        """When QA rejects with issues, task transitions to FIX_REQUIRED and issues are saved."""
        task = Task(
            id="REV-004",
            title="Defect Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
        )
        self.queue_store.save_task(task)
        self.dispatcher.start_task("REV-004", actor="PK_ClientLead")
        self.dispatcher.submit_work("REV-004", actor="PK_ClientLead", evidence_paths=[str(self.work_evidence)])

        t = self.queue_store.get_task("REV-004")
        self._register_mock_invocation("REV-004", t.iteration, "PK_QALead", "qa-sess-distinct-4", t.current_commit_sha)
        issue = Issue(
            id="ISS-001",
            task_id="REV-004",
            iteration=1,
            severity=Severity.P1,
            title="Collision glitch",
            reproduction_steps="Walk right into wall",
            expected="Player stops",
            actual="Player clips through",
            evidence=[str(self.qa_evidence)],
        )
        verdict = ReviewVerdict(
            task_id="REV-004",
            iteration=t.iteration,
            agent_role="PK_QALead",
            provider="SIMULATED_MOCK",
            invocation_id="inv-qa-4",
            session_id="qa-sess-distinct-4",
            reviewed_commit_sha=t.current_commit_sha,
            result="FIX_REQUIRED",
            evidence_paths=[str(self.qa_evidence)],
            issues=[issue],
            notes="Collision bug must be fixed.",
        )
        updated = self.dispatcher.review_task("REV-004", verdict=verdict)

        self.assertEqual(updated.status, TaskState.FIX_REQUIRED)
        open_issues = self.queue_store.get_open_issues("REV-004")
        self.assertEqual(len(open_issues), 1)
        self.assertEqual(open_issues[0].id, "ISS-001")


if __name__ == "__main__":
    unittest.main()
