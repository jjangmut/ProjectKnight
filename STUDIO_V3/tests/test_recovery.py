"""Tests for crash recovery, leasing, optimistic locking (CAS), and adapter error handling (V3-002-R1)."""
import unittest
import tempfile
import shutil
import json
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
from STUDIO_V3.orchestrator.policies import TaskLeaseConflictError, ConcurrentModificationError


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
        """Simulate runner crash and restart: state, iteration, version, and issues survive intact."""
        task = Task(
            id="REC-001",
            title="Crash Test Task",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
            iteration=2,
            version=3,
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

        # Re-instantiate QueueStore from existing DB
        restarted_store = QueueStore(self.db_path, self.json_snapshot)
        restarted_task = restarted_store.get_task("REC-001")

        self.assertIsNotNone(restarted_task)
        self.assertEqual(restarted_task.status, TaskState.IN_PROGRESS)
        self.assertEqual(restarted_task.iteration, 2)
        self.assertEqual(restarted_task.version, 3)
        # Verify subsequent save increments version
        restarted_task.iteration += 1
        restarted_store.save_task(restarted_task)
        self.assertEqual(restarted_task.version, 4)
        self.assertEqual(len(restarted_task.issues), 1)
        self.assertEqual(restarted_task.issues[0].id, "ISS-REC-1")

    def test_json_snapshot_synchronization(self):
        """Changes to SQLite store export to queue.json snapshot accurately and atomically."""
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

    def test_task_lease_prevents_concurrent_runs(self):
        """A task actively leased by one actor cannot be started by another actor concurrently."""
        task = Task(
            id="REC-003",
            title="Concurrent Lease Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
        )
        self.queue_store.save_task(task)

        # Producer 1 starts task -> claims lease
        self.dispatcher.start_task("REC-003", actor="PK_ClientLead")

        # Producer 2 attempts to claim lease on same task concurrently
        with self.assertRaises(TaskLeaseConflictError):
            self.queue_store.claim_task_lease("REC-003", actor="Other_Producer_Process")

    def test_optimistic_locking_prevents_concurrent_modification(self):
        """Stale in-memory task cannot overwrite concurrent DB updates (CAS)."""
        task = Task(
            id="REC-004",
            title="CAS Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead"],
            version=1,
        )
        self.queue_store.save_task(task)

        # Worker A reads task at version 1
        worker_a_task = self.queue_store.get_task("REC-004")
        # Worker B reads task at version 1
        worker_b_task = self.queue_store.get_task("REC-004")

        # Worker A saves changes -> bumps version to 2
        worker_a_task.status = TaskState.IN_PROGRESS
        self.queue_store.save_task(worker_a_task)

        # Worker B tries to save stale version 1 -> ConcurrentModificationError
        worker_b_task.status = TaskState.BLOCKED
        with self.assertRaises(ConcurrentModificationError):
            self.queue_store.save_task(worker_b_task)

    def test_adapter_timeout_handling(self):
        """Mock adapter supports simulated timeout returning TIMED_OUT status."""
        def timeout_hook(task_id, role, prompt, timeout_sec):
            return ExecutionRecord(
                invocation_id="inv-timeout",
                task_id=task_id,
                agent_id=role,
                provider="SIMULATED_MOCK",
                session_id="",
                start_time="2026-11-04T12:00:00Z",
                end_time="2026-11-04T12:02:00Z",
                working_branch="test",
                commit_sha="000",
                exit_code=124,
                status=ExecutionStatus.TIMED_OUT,
                error="Simulated timeout",
            )
        self.adapter.behavior_hook = timeout_hook
        rec = self.adapter.dispatch("REC-005", "PK_ClientLead", "do something", str(self.temp_dir))
        self.assertEqual(rec.status, ExecutionStatus.TIMED_OUT)
        self.assertEqual(rec.exit_code, 124)


if __name__ == "__main__":
    unittest.main()
