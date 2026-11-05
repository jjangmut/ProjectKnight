"""End-to-end multi-cycle test for Autonomous Quality Loop using adapter dispatch (V3-002-R1)."""
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
)
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher
from STUDIO_V3.orchestrator.adapters.mock import MockAdapter
from STUDIO_V3.orchestrator.policies import calculate_sha256


class TestDispatcherAutonomousLoop(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp())
        self.db_path = self.temp_dir / "queue.db"
        self.log_path = self.temp_dir / "events.jsonl"
        self.queue_store = QueueStore(self.db_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.queue_store, self.event_log, self.temp_dir, allow_mock=True)
        self.adapter = MockAdapter(self.temp_dir)

        (self.temp_dir / "worker_evidence").mkdir(parents=True, exist_ok=True)
        (self.temp_dir / "qa_evidence").mkdir(parents=True, exist_ok=True)
        (self.temp_dir / "director_evidence").mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_mock_two_iteration_rejection_and_approval_loop(self):
        """
        Verify the autonomous quality loop:
        Iteration 1: Worker executes -> QA finds defect and rejects -> Issue filed -> FIX_REQUIRED.
        Iteration 2: Worker fixes defect -> QA retests PASS -> GameDirector final review PASS -> APPROVED.
        Reported accurately as a 2-iteration rework and approval loop.
        """
        task = Task(
            id="E2E-001",
            title="Stage 1 Lighting Calibration",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
            priority=1,
        )
        self.queue_store.save_task(task)

        # Worker behavior per iteration
        def worker_action(t: Task, cycle: int, adp: MockAdapter):
            fpath = self.temp_dir / "worker_evidence" / f"cycle_{cycle}_work.md"
            if cycle == 1:
                fpath.write_text("# Initial Implementation\nAdded light probe. Known bug: bloom over-saturated.", encoding="utf-8")
            else:
                fpath.write_text(f"# Iteration {cycle} Fix\nReduced bloom intensity to 0.4 and fixed exposure.", encoding="utf-8")
            
            # Dispatch mock worker execution
            rec = adp.dispatch(t.id, t.owner, f"Worker work for cycle {cycle}", str(self.temp_dir))
            return [str(fpath)], rec

        # QA behavior per iteration
        def qa_evaluator(t: Task, cycle: int, adp: MockAdapter, worker_rec: ExecutionRecord) -> ReviewVerdict:
            rev_path = self.temp_dir / "qa_evidence" / f"cycle_{cycle}_qa.md"
            rec = adp.dispatch(t.id, "PK_QALead", f"QA review for cycle {cycle}", str(self.temp_dir))
            if cycle == 1:
                rev_path.write_text("# QA Report Cycle 1\nDefect: Bloom intensity exceeds 1.2, blinding player.", encoding="utf-8")
                issue = Issue(
                    id="ISS-E2E-1",
                    task_id=t.id,
                    iteration=cycle,
                    severity=Severity.P1,
                    title="Excessive Bloom on Stage 1 Platform",
                    reproduction_steps="Observe combat platform at x=120",
                    expected="Bloom <= 0.5",
                    actual="Bloom = 1.25",
                    evidence=[str(rev_path)],
                )
                return ReviewVerdict(
                    task_id=t.id,
                    iteration=t.iteration,
                    agent_role="PK_QALead",
                    provider=rec.provider,
                    invocation_id=rec.invocation_id,
                    session_id=rec.session_id,
                    reviewed_commit_sha=t.current_commit_sha,
                    result="FIX_REQUIRED",
                    evidence_paths=[str(rev_path)],
                    issues=[issue],
                    notes="Visual blinding defect found.",
                )
            else:
                rev_path.write_text(f"# QA Report Cycle {cycle}\nRetest PASS: Bloom measured at 0.4.", encoding="utf-8")
                self.queue_store.resolve_issue("ISS-E2E-1", resolved_by="PK_ClientLead")
                return ReviewVerdict(
                    task_id=t.id,
                    iteration=t.iteration,
                    agent_role="PK_QALead",
                    provider=rec.provider,
                    invocation_id=rec.invocation_id,
                    session_id=rec.session_id,
                    reviewed_commit_sha=t.current_commit_sha,
                    result="PASS",
                    evidence_paths=[str(rev_path)],
                    notes="Verified fix.",
                )

        def director_evaluator(t: Task, cycle: int, adp: MockAdapter, worker_rec: ExecutionRecord) -> ReviewVerdict:
            dir_path = self.temp_dir / "director_evidence" / f"cycle_{cycle}_dir.md"
            dir_path.write_text("# Director Signoff\nVisual contrast and gameplay plane are acceptable.", encoding="utf-8")
            rec = adp.dispatch(t.id, "PK_GameDirector", f"Director review for cycle {cycle}", str(self.temp_dir))
            return ReviewVerdict(
                task_id=t.id,
                iteration=t.iteration,
                agent_role="PK_GameDirector",
                provider=rec.provider,
                invocation_id=rec.invocation_id,
                session_id=rec.session_id,
                reviewed_commit_sha=t.current_commit_sha,
                result="PASS",
                evidence_paths=[str(dir_path)],
                notes="Quality gate met.",
            )

        # Run loop
        result = self.dispatcher.execute_autonomous_loop(
            task_id="E2E-001",
            adapter=self.adapter,
            worker_action=worker_action,
            reviewer_evaluators={
                "PK_QALead": qa_evaluator,
                "PK_GameDirector": director_evaluator,
            },
            max_cycles=3,
        )

        self.assertTrue(result["approved"], "Task must be APPROVED after completing quality rework.")
        self.assertEqual(result["final_status"], "APPROVED")
        self.assertEqual(result["iterations_run"], 2)  # Cycle 1 rejected, Cycle 2 passed both QA & Director
        self.assertEqual(result["execution_mode"], "MOCK")

        final_task = self.queue_store.get_task("E2E-001")
        self.assertEqual(final_task.status, TaskState.APPROVED)
        self.assertEqual(len(final_task.reviews), 2)
        self.assertEqual(final_task.reviews["PK_QALead"]["result"], "PASS")
        self.assertEqual(final_task.reviews["PK_GameDirector"]["result"], "PASS")

        # Verify event log entries
        events = self.event_log.read_events("E2E-001")
        event_types = [e["event_type"] for e in events]
        self.assertIn("TASK_STARTED", event_types)
        self.assertIn("WORK_SUBMITTED", event_types)
        self.assertIn("REVIEW_REJECTED", event_types)
        self.assertIn("TASK_APPROVED", event_types)


if __name__ == "__main__":
    unittest.main()
