"""Tests for crash recovery, state persistence, bounded iteration limits, and adapter error handling."""
import unittest
import tempfile
import shutil
import json
from pathlib import Path

from STUDIO_V3.orchestrator.schemas import Task, TaskState, Severity, Issue, ReviewVerdict
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher
from STUDIO_V3.orchestrator.adapters.mock import MockAdapter


class TestRecoveryAndResilience(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp())
        self.db_path = self.temp_dir / "queue.db"
        self.json_snapshot = self.temp_dir / "queue.json"
        self.log_path = self.temp_dir / "events.jsonl"
        self.queue_store = QueueStore(self.db_path, self.json_snapshot)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.queue_store, self.event_log, self.temp_dir)
        self.adapter = MockAdapter(self.temp_dir)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_database_restart_preserves_state_and_issues(self):
        """Simulate runner crash and restart: state, iteration, and issues survive intact."""
        task = Task(
            id="REC-001",
            title="Crash Test Task",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
            iteration=2,
        )
        issue = Issue(
            id="ISS-REC-1",
            task_id="REC-001",
            iteration=1,
            severity=Severity.P0,
            title="Fatal crash on stage load",
            reproduction_steps="Load scene",
            expected="Scene loads",
            actual="Null dereference",
        )
        task.issues.append(issue)
        self.queue_store.save_task(task)

        # "Crash" and re-instantiate QueueStore from existing DB
        restarted_store = QueueStore(self.db_path, self.json_snapshot)
        restarted_task = restarted_store.get_task("REC-001")

        self.assertIsNotNone(restarted_task)
        self.assertEqual(restarted_task.status, TaskState.IN_PROGRESS)
        self.assertEqual(restarted_task.iteration, 2)
        self.assertEqual(len(restarted_task.issues), 1)
        self.assertEqual(restarted_task.issues[0].id, "ISS-REC-1")

    def test_json_snapshot_synchronization(self):
        """Changes to SQLite store export to queue.json snapshot accurately."""
        task = Task(
            id="REC-002",
            title="Snapshot Sync Task",
            status=TaskState.READY,
            owner="PK_Producer",
            reviewers=["PK_GameDirector"],
        )
        self.queue_store.save_task(task)

        self.assertTrue(self.json_snapshot.exists())
        data = json.loads(self.json_snapshot.read_text(encoding="utf-8"))
        task_ids = [t["id"] for t in data["tasks"]]
        self.assertIn("REC-002", task_ids)

    def test_bounded_iterations_prevents_infinite_loop(self):
        """When work is repeatedly rejected, autonomous loop halts at max_cycles and stays FIX_REQUIRED."""
        task = Task(
            id="REC-003",
            title="Failing Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)

        evidence_file = self.temp_dir / "work.md"
        evidence_file.write_text("work", encoding="utf-8")
        rev_evidence = self.temp_dir / "rev.md"
        rev_evidence.write_text("rev", encoding="utf-8")

        def worker_action(t, cycle):
            return [str(evidence_file)]

        def reviewer_eval(t, cycle):
            # Always rejects
            return ReviewVerdict(
                result="FIX_REQUIRED",
                reviewer_id="PK_QALead",
                evidence_paths=[str(rev_evidence)],
                notes=f"Rejection in cycle {cycle}",
            )

        summary = self.dispatcher.execute_autonomous_loop(
            task_id="REC-003",
            adapter=self.adapter,
            worker_action=worker_action,
            reviewer_evaluators={"PK_QALead": reviewer_eval},
            max_cycles=3,
        )

        self.assertEqual(summary["iterations_run"], 3)
        self.assertFalse(summary["approved"])
        self.assertEqual(summary["final_status"], TaskState.FIX_REQUIRED.value)

    def test_adapter_cancellation(self):
        """Mock adapter supports invocation cancellation."""
        rec = self.adapter.dispatch("REC-004", "PK_ClientLead", "test prompt", str(self.temp_dir))
        self.assertTrue(self.adapter.cancel(rec.invocation_id))


if __name__ == "__main__":
    unittest.main()
