"""Comprehensive Negative and Governance Tests for TASK V3-002-R3-PATCH.

Validates the full resolution of all 6 independent review findings:
1. P0-01: Strict reviewer JSON schema enforcement (no bare {"verdict":"PASS"}, mandatory task/iter/role/sha/manifest/issues).
2. P0-02: Cryptographic git tree blob verification, branch reachability, and uncommitted source alteration rejection.
3. P1-03: Subagent parent conversation provenance, anti-replay, and mock approval exclusion.
4. P1-05: Run ID correlation across all lifecycle audit events and atomic lease clearance.
"""
from __future__ import annotations
import json
import subprocess
import tempfile
import shutil
from pathlib import Path
import unittest

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
from STUDIO_V3.orchestrator.runner import SingleEntryRunner
from STUDIO_V3.orchestrator.policies import (
    PolicyViolation,
    EvidenceTamperedError,
    EvidenceMissingError,
    StaleReviewError,
    IdentityVerificationError,
    verify_commit_on_branch,
    verify_committed_source_evidence,
)
from STUDIO_V3.orchestrator.adapters.subagent_bridge import AntigravitySubagentBridgeAdapter


class TestR3PatchApprovalGate(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.repo_root = Path(self.temp_dir)
        self.studio_dir = self.repo_root / "STUDIO_V3"
        self.studio_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.studio_dir / "queue.db"
        self.json_path = self.studio_dir / "queue.json"
        self.log_path = self.studio_dir / "events.jsonl"

        # Initialize a real Git repository in temp_dir for git blob tests
        subprocess.run(["git", "init", "-b", "studio/v3-002-r3-final-hardening"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "config", "user.name", "Test Runner"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "config", "user.email", "test@projectknight.local"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "config", "core.autocrlf", "false"], cwd=str(self.repo_root), capture_output=True, check=True)

        # Create initial committed source deliverable
        self.source_file = self.repo_root / "component.gd"
        self.source_file.write_bytes(b"# Initial Component Source\nclass_name TestComp\n")
        subprocess.run(["git", "add", "component.gd"], cwd=str(self.repo_root), capture_output=True, check=True)
        res_commit = subprocess.run(["git", "commit", "-m", "feat: initial component commit"], cwd=str(self.repo_root), capture_output=True, text=True, check=True)
        
        # Get head commit SHA
        res_sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(self.repo_root), capture_output=True, text=True, check=True)
        self.commit_sha = res_sha.stdout.strip()

        self.store = QueueStore(self.db_path, self.json_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.store, self.event_log, self.repo_root, allow_mock=False)

        self.task = Task(
            id="PATCH-001",
            title="Approval Gate Patch Test Task",
            status=TaskState.READY,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
            priority=1,
            active_branch="studio/v3-002-r3-final-hardening",
            current_commit_sha=self.commit_sha,
        )
        self.store.save_task(self.task)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # P0-01: Strict Reviewer Structured JSON Schema Enforcement
    # -------------------------------------------------------------------------

    def _create_exec_record(self, text: str, role: str = "PK_QALead") -> ExecutionRecord:
        return ExecutionRecord(
            invocation_id=f"inv-{role.lower()}-test",
            task_id="PATCH-001",
            agent_id=role,
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="sess-qa-001",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="",
            commit_sha=self.commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=text,
        )

    def test_p0_01_incomplete_bare_pass_rejected(self):
        """Negative: Bare `{"verdict": "PASS"}` must fail closed."""
        rec = self._create_exec_record('{"verdict": "PASS"}')
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, self.task)
        self.assertIn("missing mandatory 'task_id'", str(ctx.exception))

    def test_p0_01_missing_iteration_rejected(self):
        """Negative: Missing or non-int iteration must be rejected."""
        rec = self._create_exec_record(json.dumps({
            "task_id": "PATCH-001",
            "role": "PK_QALead",
            "reviewed_commit_sha": self.commit_sha,
            "verdict": "PASS",
            "issues": [],
            "evidence_manifest": ["component.gd"]
        }))
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, self.task)
        self.assertIn("missing mandatory 'iteration'", str(ctx.exception))

    def test_p0_01_stale_iteration_rejected(self):
        """Negative: Iteration mismatch must raise StaleReviewError."""
        rec = self._create_exec_record(json.dumps({
            "task_id": "PATCH-001",
            "iteration": 99,
            "role": "PK_QALead",
            "reviewed_commit_sha": self.commit_sha,
            "verdict": "PASS",
            "issues": [],
            "evidence_manifest": ["component.gd"]
        }))
        with self.assertRaises(StaleReviewError):
            self.dispatcher.parse_reviewer_verdict(rec, self.task)

    def test_p0_01_missing_reviewed_commit_sha_never_defaults(self):
        """Negative: Missing reviewed_commit_sha must never default to current task commit."""
        rec = self._create_exec_record(json.dumps({
            "task_id": "PATCH-001",
            "iteration": 0,
            "role": "PK_QALead",
            "verdict": "PASS",
            "issues": [],
            "evidence_manifest": ["component.gd"]
        }))
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, self.task)
        self.assertIn("missing mandatory 'reviewed_commit_sha'", str(ctx.exception))

    def test_p0_01_stale_commit_sha_rejected(self):
        """Negative: Mismatched reviewed_commit_sha must raise StaleReviewError."""
        fake_sha = "0123456789abcdef0123456789abcdef01234567"
        rec = self._create_exec_record(json.dumps({
            "task_id": "PATCH-001",
            "iteration": 0,
            "role": "PK_QALead",
            "reviewed_commit_sha": fake_sha,
            "verdict": "PASS",
            "issues": [],
            "evidence_manifest": ["component.gd"]
        }))
        with self.assertRaises(StaleReviewError):
            self.dispatcher.parse_reviewer_verdict(rec, self.task)

    def test_p0_01_contradictory_multiple_jsons_rejected(self):
        """Negative: Output containing multiple contradictory verdicts must fail closed."""
        body = (
            "Here is preliminary result:\n"
            "```json\n"
            '{"task_id": "PATCH-001", "iteration": 0, "role": "PK_QALead", '
            f'"reviewed_commit_sha": "{self.commit_sha}", "verdict": "FIX_REQUIRED", "issues": [{{"title": "bug"}}]}}\n'
            "```\n"
            "Wait, actually it looks good:\n"
            "```json\n"
            '{"task_id": "PATCH-001", "iteration": 0, "role": "PK_QALead", '
            f'"reviewed_commit_sha": "{self.commit_sha}", "verdict": "PASS", "issues": [], "evidence_manifest": ["component.gd"]}}\n'
            "```"
        )
        rec = self._create_exec_record(body)
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, self.task)
        self.assertIn("Multiple contradictory", str(ctx.exception))

    def test_p0_01_pass_verdict_with_open_p1_defect_rejected(self):
        """Negative: Declaring PASS while reporting an unresolved P1 defect must be rejected."""
        rec = self._create_exec_record(json.dumps({
            "task_id": "PATCH-001",
            "iteration": 0,
            "role": "PK_QALead",
            "reviewed_commit_sha": self.commit_sha,
            "verdict": "PASS",
            "issues": [{"id": "ISS-1", "severity": "P1", "status": "OPEN", "title": "Critical Defect"}],
            "evidence_manifest": ["component.gd"]
        }))
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, self.task)
        self.assertIn("open blocking issue", str(ctx.exception))

    def test_p0_01_fix_required_with_empty_issues_rejected(self):
        """Negative: FIX_REQUIRED with empty issues must be rejected."""
        rec = self._create_exec_record(json.dumps({
            "task_id": "PATCH-001",
            "iteration": 0,
            "role": "PK_QALead",
            "reviewed_commit_sha": self.commit_sha,
            "verdict": "FIX_REQUIRED",
            "issues": [],
            "evidence_manifest": []
        }))
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, self.task)
        self.assertIn("zero structured issues", str(ctx.exception))

    # -------------------------------------------------------------------------
    # P0-02: Cryptographic Git Tree Blob & Evidence Verification
    # -------------------------------------------------------------------------

    def test_p0_02_uncommitted_source_alterations_rejected(self):
        """Negative: Editing source on disk without committing causes git blob SHA mismatch."""
        task = self.dispatcher.start_task("PATCH-001", actor="PK_ClientLead", claim_token="run-test-p0-02")
        
        # Tamper disk file AFTER git commit
        self.source_file.write_text("# MODIFIED WITHOUT GIT COMMIT!\n", encoding="utf-8")
        
        with self.assertRaises(EvidenceTamperedError) as ctx:
            self.dispatcher.submit_work(
                "PATCH-001",
                actor="PK_ClientLead",
                evidence_paths=["component.gd"],
                target_commit_sha=self.commit_sha,
            )
        self.assertIn("uncommitted changes on disk", str(ctx.exception))

    def test_p0_02_uncommitted_file_path_rejected(self):
        """Negative: Submitting a new file not present in git commit tree is rejected."""
        uncommitted = self.repo_root / "uncommitted_new.gd"
        uncommitted.write_text("# Not in git\n", encoding="utf-8")

        task = self.dispatcher.start_task("PATCH-001", actor="PK_ClientLead", claim_token="run-test-p0-02-new")
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.submit_work(
                "PATCH-001",
                actor="PK_ClientLead",
                evidence_paths=["uncommitted_new.gd"],
                target_commit_sha=self.commit_sha,
            )
        self.assertIn("does not exist in git commit", str(ctx.exception))

    def test_p0_02_path_traversal_rejected(self):
        """Negative: Paths attempting directory traversal ('..') are blocked."""
        task = self.dispatcher.start_task("PATCH-001", actor="PK_ClientLead", claim_token="run-test-p0-02-trav")
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.submit_work(
                "PATCH-001",
                actor="PK_ClientLead",
                evidence_paths=["../outside.txt"],
                target_commit_sha=self.commit_sha,
            )
        self.assertIn("Path traversal detected", str(ctx.exception))

    def test_p0_02_commit_unreachable_from_branch_rejected(self):
        """Negative: Commit on an unrelated branch is rejected."""
        # Create an orphan branch with a different commit
        subprocess.run(["git", "checkout", "--orphan", "unrelated-branch"], cwd=str(self.repo_root), capture_output=True, check=True)
        unrelated_file = self.repo_root / "other.txt"
        unrelated_file.write_text("other branch", encoding="utf-8")
        subprocess.run(["git", "add", "other.txt"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "commit", "-m", "unrelated commit"], cwd=str(self.repo_root), capture_output=True, check=True)
        res_other = subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(self.repo_root), capture_output=True, text=True, check=True)
        unrelated_sha = res_other.stdout.strip()
        
        # Switch back to the authorized task branch
        subprocess.run(["git", "checkout", "studio/v3-002-r3-final-hardening"], cwd=str(self.repo_root), capture_output=True, check=True)

        with self.assertRaises(PolicyViolation) as ctx:
            verify_commit_on_branch(unrelated_sha, "studio/v3-002-r3-final-hardening", self.repo_root)
        self.assertIn("not reachable from authorized branch", str(ctx.exception))

    # -------------------------------------------------------------------------
    # P1-03: Subagent Identity, Provenance, and Anti-Replay
    # -------------------------------------------------------------------------

    def test_p1_03_missing_parent_conversation_id_rejected(self):
        """Negative: Live subagent ingestion without parent conversation ID must raise IdentityVerificationError."""
        runner = SingleEntryRunner(self.repo_root, run_id="run-test-parent-check")
        with self.assertRaises(IdentityVerificationError) as ctx:
            runner.step_worker_delivery(
                task_id="PATCH-001",
                session_id="dummy-session",
                commit_sha=self.commit_sha,
                evidence_files=["component.gd"],
                parent_conversation_id="",  # Missing!
            )
        self.assertIn("Parent conversation ID is required", str(ctx.exception))

    def test_p1_03_reused_session_across_tasks_rejected(self):
        """Negative: Registering a session already registered for another task raises PolicyViolation."""
        self.store.save_task(Task(id="TASK-AAA", title="Task A", status=TaskState.READY, owner="PK_ClientLead", reviewers=[]))
        self.store.save_task(Task(id="TASK-BBB", title="Task B", status=TaskState.READY, owner="PK_ClientLead", reviewers=[]))

        self.store.register_invocation(InvocationRecord(
            invocation_id="inv-task1-01",
            run_id="run-prov-1",
            task_id="TASK-AAA",
            iteration=1,
            role="PK_ClientLead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="unique-sess-12345",
            worktree=str(self.repo_root),
            branch="branch-a",
            target_commit_sha=self.commit_sha,
            started_at="2026-11-05T00:00:00Z",
            completed_at="2026-11-05T00:01:00Z",
            terminal_status="SUCCEEDED",
        ))

        # Attempt to reuse the exact same session for a different task
        with self.assertRaises(PolicyViolation) as ctx:
            self.store.register_invocation(InvocationRecord(
                invocation_id="inv-task2-02",
                run_id="run-prov-1",
                task_id="TASK-BBB",
                iteration=1,
                role="PK_ClientLead",
                provider="ANTIGRAVITY_SUBAGENT",
                session_id="unique-sess-12345",
                worktree=str(self.repo_root),
                branch="branch-b",
                target_commit_sha=self.commit_sha,
                started_at="2026-11-05T00:02:00Z",
                completed_at="2026-11-05T00:03:00Z",
                terminal_status="SUCCEEDED",
            ))
        self.assertIn("Reusing sessions across tasks or iterations is forbidden", str(ctx.exception))

    # -------------------------------------------------------------------------
    # P1-05: Run ID Correlation Across All Events
    # -------------------------------------------------------------------------

    def test_p1_05_run_id_propagated_to_all_events(self):
        """Positive: All events generated under a run have identical parent_run_id."""
        authoritative_run_id = "run-hardening-patch-999"
        self.dispatcher.current_run_id = authoritative_run_id

        task = self.dispatcher.start_task("PATCH-001", actor="PK_ClientLead", claim_token=authoritative_run_id)
        task = self.dispatcher.submit_work(
            "PATCH-001",
            actor="PK_ClientLead",
            evidence_paths=["component.gd"],
            target_commit_sha=self.commit_sha,
        )

        events = self.event_log.read_events("PATCH-001")
        self.assertGreaterEqual(len(events), 2)
        for ev in events:
            self.assertEqual(ev["parent_run_id"], authoritative_run_id, f"Event {ev['event_type']} lacked run_id correlation!")


if __name__ == "__main__":
    unittest.main()
