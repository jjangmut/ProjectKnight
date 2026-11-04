"""Tests for fine-grained state machine transitions and queue store exports."""
import unittest
import tempfile
import shutil
import json
from pathlib import Path

from STUDIO_V3.orchestrator.schemas import Task, TaskState, ReviewVerdict
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher
from STUDIO_V3.orchestrator.policies import PolicyViolation


class TestStateTransitions(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp())
        self.db_path = self.temp_dir / "queue.db"
        self.json_path = self.temp_dir / "queue.json"
        self.log_path = self.temp_dir / "events.jsonl"
        self.queue_store = QueueStore(self.db_path, self.json_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.queue_store, self.event_log, self.temp_dir)

        self.ev = self.temp_dir / "test_ev.md"
        self.ev.write_text("ev", encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_invalid_start_from_in_review(self):
        """Cannot start a task that is already IN_REVIEW."""
        task = Task(
            id="TR-001",
            title="State Test",
            status=TaskState.IN_REVIEW,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)

        with self.assertRaises(PolicyViolation):
            self.dispatcher.start_task("TR-001", actor="PK_ClientLead")

    def test_invalid_submit_from_ready(self):
        """Cannot submit a task that has not been started (is READY)."""
        task = Task(
            id="TR-002",
            title="Premature Submit",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)

        with self.assertRaises(PolicyViolation):
            self.dispatcher.submit_work("TR-002", actor="PK_ClientLead", evidence_paths=[str(self.ev)])

    def test_task_selection_priority(self):
        """Dispatcher selects highest priority unblocked task."""
        t1 = Task(id="P-001", title="Low Priority", status=TaskState.READY, owner="PK_ClientLead", reviewers=["PK_QALead"], priority=5)
        t2 = Task(id="P-002", title="High Priority", status=TaskState.READY, owner="PK_ArtDirector", reviewers=["PK_QALead"], priority=1)
        t3 = Task(id="P-003", title="Blocked High Priority", status=TaskState.READY, owner="PK_ClientLead", reviewers=["PK_QALead"], priority=0, blocked_by=["P-001"])

        self.queue_store.save_task(t1)
        self.queue_store.save_task(t2)
        self.queue_store.save_task(t3)

        selected = self.dispatcher.select_next_task()
        self.assertIsNotNone(selected)
        self.assertEqual(selected.id, "P-002", "P-002 has highest priority among unblocked tasks")


if __name__ == "__main__":
    unittest.main()
