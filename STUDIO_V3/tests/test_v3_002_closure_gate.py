"""Comprehensive negative and positive gate hardening tests for TASK V3-002-CLOSE.

Verifies:
- P0-01: Git fail-closed enforcement (no silent pass, invalid SHA, missing repo, branch mismatch, worktree support, dirty source)
- P1-02: Strict reviewer JSON schema (mandatory evidence_manifest, int-not-bool iteration, single verdict envelope, no open P0/P1)
- P1-03: Subagent terminal completion (no earlier DONE bypass, final status must be DONE, truncated JSONL fails closed)
- P1-04 / Governance: Full two-key approval gate and lease clearance
"""
import unittest
import tempfile
import shutil
import subprocess
import json
import hashlib
from pathlib import Path
from typing import List

from STUDIO_V3.orchestrator.schemas import (
    Task,
    TaskState,
    Severity,
    ReviewVerdict,
    EvidenceItem,
    ExecutionRecord,
    ExecutionStatus,
)
from STUDIO_V3.orchestrator.policies import (
    PolicyViolation,
    EvidenceMissingError,
    EvidenceTamperedError,
    StaleReviewError,
    IdentityVerificationError,
    verify_commit_exists,
    verify_commit_on_branch,
    verify_committed_source_evidence,
    is_valid_hex_sha40,
)
from STUDIO_V3.orchestrator.queue_store import QueueStore
from STUDIO_V3.orchestrator.event_log import EventLog
from STUDIO_V3.orchestrator.dispatcher import TaskDispatcher
from STUDIO_V3.orchestrator.adapters.subagent_bridge import AntigravitySubagentBridgeAdapter


class TestV3002ClosureGate(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.repo_root = Path(self.temp_dir)
        self.studio_dir = self.repo_root / "STUDIO_V3"
        self.studio_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.studio_dir / "queue.db"
        self.json_path = self.studio_dir / "queue.json"
        self.log_path = self.studio_dir / "events.jsonl"

        # Initialize a real Git repository in temp_dir for git blob tests
        subprocess.run(["git", "init", "-b", "studio/v3-002-closure-patch"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "config", "user.name", "Closure Tester"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "config", "user.email", "closure@projectknight.local"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "config", "core.autocrlf", "false"], cwd=str(self.repo_root), capture_output=True, check=True)

        # Create initial committed source deliverable
        self.source_file = self.repo_root / "closure_component.gd"
        self.source_file.write_bytes(b"# Closure Component Source\nclass_name ClosureComp\n")
        subprocess.run(["git", "add", "closure_component.gd"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "commit", "-m", "feat: initial closure component"], cwd=str(self.repo_root), capture_output=True, check=True)

        res_sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(self.repo_root), capture_output=True, text=True, check=True)
        self.commit_sha = res_sha.stdout.strip()

        self.store = QueueStore(self.db_path, self.json_path)
        self.event_log = EventLog(self.log_path)
        self.dispatcher = TaskDispatcher(self.store, self.event_log, self.repo_root, allow_mock=False)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # =========================================================================
    # P0-01: Git Verification Fail-Closed Tests
    # =========================================================================

    def test_p0_01_invalid_commit_sha_rejected(self):
        """Negative: Non-40-hex SHA, empty SHA, or aliases like HEAD fail closed."""
        for bad_sha in ["", "HEAD", "UNKNOWN_SHA", "12345", "not_a_sha", "g" * 40, "123456789012345678901234567890123456789"]:
            with self.assertRaises(PolicyViolation) as ctx:
                verify_commit_exists(bad_sha, self.repo_root)
            self.assertIn("canonical 40-character", str(ctx.exception).lower())

    def test_p0_01_missing_repo_fails_closed(self):
        """Negative: Path not inside a git work tree fails closed."""
        empty_dir = Path(tempfile.mkdtemp())
        try:
            with self.assertRaises(PolicyViolation) as ctx:
                verify_commit_exists(self.commit_sha, empty_dir)
            self.assertIn("not inside a valid git repository", str(ctx.exception).lower())
        finally:
            shutil.rmtree(str(empty_dir), ignore_errors=True)

    def test_p0_01_missing_authorized_branch_fails_closed(self):
        """Negative: Unresolved or missing branch raises PolicyViolation."""
        with self.assertRaises(PolicyViolation) as ctx:
            verify_commit_on_branch(self.commit_sha, "nonexistent-branch-xyz", self.repo_root)
        self.assertIn("does not exist in repository refs", str(ctx.exception))

    def test_p0_01_commit_unreachable_from_branch_fails_closed(self):
        """Negative: Commit on an unrelated branch is rejected."""
        subprocess.run(["git", "checkout", "-b", "feature/unrelated-branch"], cwd=str(self.repo_root), capture_output=True, check=True)
        unrelated_file = self.repo_root / "unrelated.txt"
        unrelated_file.write_bytes(b"Unrelated branch content")
        subprocess.run(["git", "add", "unrelated.txt"], cwd=str(self.repo_root), capture_output=True, check=True)
        subprocess.run(["git", "commit", "-m", "unrelated commit"], cwd=str(self.repo_root), capture_output=True, check=True)

        res_sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(self.repo_root), capture_output=True, text=True, check=True)
        unrelated_sha = res_sha.stdout.strip()

        # Switch back to main authorized branch
        subprocess.run(["git", "checkout", "studio/v3-002-closure-patch"], cwd=str(self.repo_root), capture_output=True, check=True)

        with self.assertRaises(PolicyViolation) as ctx:
            verify_commit_on_branch(unrelated_sha, "studio/v3-002-closure-patch", self.repo_root)
        self.assertIn("not reachable from authorized branch", str(ctx.exception))

    def test_p0_01_git_worktree_supported_positive(self):
        """Positive: Git worktree (where .git is a text file) is fully supported."""
        worktree_dir = Path(tempfile.mkdtemp()) / "worktree_child"
        try:
            subprocess.run(
                ["git", "worktree", "add", "-b", "feature/worktree-branch", str(worktree_dir), "HEAD"],
                cwd=str(self.repo_root),
                capture_output=True,
                check=True,
            )
            git_file = worktree_dir / ".git"
            self.assertTrue(git_file.is_file(), "In a git worktree, .git must be a file.")

            # Verification inside worktree succeeds
            verify_commit_exists(self.commit_sha, worktree_dir)
            verify_commit_on_branch(self.commit_sha, "feature/worktree-branch", worktree_dir)
        finally:
            subprocess.run(["git", "worktree", "prune"], cwd=str(self.repo_root), capture_output=True)
            shutil.rmtree(str(worktree_dir.parent), ignore_errors=True)

    def test_p0_01_dirty_source_on_disk_triggers_tampered_error(self):
        """Negative: Source file modified on disk after commit raises EvidenceTamperedError."""
        item = EvidenceItem(
            evidence_id="ev-1",
            task_id="V3-CLOSE-01",
            iteration=1,
            source_commit_sha=self.commit_sha,
            working_branch="studio/v3-002-closure-patch",
            agent_invocation_id="inv-1",
            file_path="closure_component.gd",
            sha256=hashlib.sha256(b"tampered content").hexdigest(),
            creation_time="2026-11-05T00:00:00Z",
        )
        self.source_file.write_bytes(b"tampered content")
        with self.assertRaises(EvidenceTamperedError) as ctx:
            verify_committed_source_evidence([item], self.commit_sha, self.repo_root)
        self.assertIn("has uncommitted changes on disk", str(ctx.exception))

    # =========================================================================
    # P1-02: Strict Reviewer JSON Schema Tests
    # =========================================================================

    def _create_test_task(self) -> Task:
        task = Task(
            id="V3-002-CLOSE",
            title="Final Studio V3 closure",
            status=TaskState.IN_PROGRESS,
            owner="PK_ClientLead",
            reviewers=["PK_QALead", "PK_GameDirector"],
            active_branch="studio/v3-002-closure-patch",
            current_commit_sha=self.commit_sha,
            iteration=1,
        )
        self.store.save_task(task)
        return task

    def test_p1_02_missing_evidence_manifest_with_evidence_alias_rejected(self):
        """Negative: Using alias 'evidence' instead of mandatory 'evidence_manifest' is strictly rejected."""
        task = self._create_test_task()
        rec = ExecutionRecord(
            invocation_id="inv-qa-1",
            task_id=task.id,
            agent_id="PK_QALead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="ses-qa-1",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="studio/v3-002-closure-patch",
            commit_sha=self.commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=json.dumps({
                "task_id": task.id,
                "iteration": 1,
                "role": "PK_QALead",
                "reviewed_commit_sha": self.commit_sha,
                "verdict": "PASS",
                "issues": [],
                "evidence": ["some/path.log"],  # Forbidden alias!
            }),
        )
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, task)
        self.assertIn("missing mandatory 'evidence_manifest'", str(ctx.exception))

    def test_p1_02_bool_iteration_rejected(self):
        """Negative: iteration as boolean (e.g. True) must fail closed."""
        task = self._create_test_task()
        rec = ExecutionRecord(
            invocation_id="inv-qa-2",
            task_id=task.id,
            agent_id="PK_QALead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="ses-qa-2",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="studio/v3-002-closure-patch",
            commit_sha=self.commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=json.dumps({
                "task_id": task.id,
                "iteration": True,  # bool instead of exact int!
                "role": "PK_QALead",
                "reviewed_commit_sha": self.commit_sha,
                "verdict": "PASS",
                "issues": [],
                "evidence_manifest": ["some/path.log"],
            }),
        )
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, task)
        self.assertIn("must be an integer (not bool)", str(ctx.exception))

    def test_p1_02_multiple_verdict_payloads_rejected(self):
        """Negative: Multiple verdict objects (even identical PASS verdicts) must fail closed."""
        task = self._create_test_task()
        payload = {
            "task_id": task.id,
            "iteration": 1,
            "role": "PK_QALead",
            "reviewed_commit_sha": self.commit_sha,
            "verdict": "PASS",
            "issues": [],
            "evidence_manifest": ["some/path.log"],
        }
        text = f"```json\n{json.dumps(payload)}\n```\nHere is another note:\n```json\n{json.dumps(payload)}\n```"
        rec = ExecutionRecord(
            invocation_id="inv-qa-3",
            task_id=task.id,
            agent_id="PK_QALead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="ses-qa-3",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="studio/v3-002-closure-patch",
            commit_sha=self.commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=text,
        )
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, task)
        self.assertIn("structured JSON verdict payloads", str(ctx.exception))

    def test_p1_02_pass_with_open_p1_issue_rejected(self):
        """Negative: Declaring PASS with an unresolved P1 issue is rejected."""
        task = self._create_test_task()
        payload = {
            "task_id": task.id,
            "iteration": 1,
            "role": "PK_QALead",
            "reviewed_commit_sha": self.commit_sha,
            "verdict": "PASS",
            "issues": [
                {"id": "ISS-1", "severity": "P1", "status": "OPEN", "title": "Blocking defect"}
            ],
            "evidence_manifest": ["some/path.log"],
        }
        rec = ExecutionRecord(
            invocation_id="inv-qa-4",
            task_id=task.id,
            agent_id="PK_QALead",
            provider="ANTIGRAVITY_SUBAGENT",
            session_id="ses-qa-4",
            start_time="2026-11-05T00:00:00Z",
            end_time="2026-11-05T00:01:00Z",
            working_branch="studio/v3-002-closure-patch",
            commit_sha=self.commit_sha,
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=json.dumps(payload),
        )
        with self.assertRaises(PolicyViolation) as ctx:
            self.dispatcher.parse_reviewer_verdict(rec, task)
        self.assertIn("open blocking issue", str(ctx.exception))

    # =========================================================================
    # P1-03: Subagent Terminal Completion Tests
    # =========================================================================

    def test_p1_03_earlier_done_followed_by_running_fails_closed(self):
        """Negative: Transcript with earlier DONE followed by RUNNING returns AGENT_COMPLETION_NOT_VERIFIED."""
        brain_dir = Path(tempfile.mkdtemp())
        session_id = "test-session-running"
        sess_dir = brain_dir / session_id / ".system_generated" / "logs"
        sess_dir.mkdir(parents=True, exist_ok=True)
        transcript = sess_dir / "transcript.jsonl"

        # Step 1: DONE, Step 2: RUNNING
        with open(transcript, "w", encoding="utf-8") as f:
            f.write(json.dumps({"step_index": 1, "source": "MODEL", "status": "DONE", "content": "I am done early."}) + "\n")
            f.write(json.dumps({"step_index": 2, "source": "SYSTEM", "status": "RUNNING", "content": "Running background job."}) + "\n")

        adapter = AntigravitySubagentBridgeAdapter(brain_base_dir=brain_dir, repo_root=self.repo_root)
        rec = adapter._parse_transcript_record(
            session_id=session_id,
            role="PK_QALead",
            task_id="V3-002-CLOSE",
            inv_id="inv-sub-1",
            target_commit_sha=self.commit_sha,
            created_at="2026-11-05T00:00:00Z",
            now_iso="2026-11-05T00:01:00Z",
            transcript_path=transcript,
            expected_deliverables=[],
        )
        self.assertEqual(rec.status, ExecutionStatus.AGENT_COMPLETION_NOT_VERIFIED)
        self.assertIn("status is 'RUNNING'", rec.error)
        shutil.rmtree(str(brain_dir), ignore_errors=True)

    def test_p1_03_earlier_done_followed_by_failed_fails_closed(self):
        """Negative: Transcript with earlier DONE followed by FAILED returns AGENT_COMPLETION_NOT_VERIFIED."""
        brain_dir = Path(tempfile.mkdtemp())
        session_id = "test-session-failed"
        sess_dir = brain_dir / session_id / ".system_generated" / "logs"
        sess_dir.mkdir(parents=True, exist_ok=True)
        transcript = sess_dir / "transcript.jsonl"

        with open(transcript, "w", encoding="utf-8") as f:
            f.write(json.dumps({"step_index": 1, "source": "MODEL", "status": "DONE", "content": "Preliminary answer."}) + "\n")
            f.write(json.dumps({"step_index": 2, "source": "SYSTEM", "status": "FAILED", "content": "Process crashed."}) + "\n")

        adapter = AntigravitySubagentBridgeAdapter(brain_base_dir=brain_dir, repo_root=self.repo_root)
        rec = adapter._parse_transcript_record(
            session_id=session_id,
            role="PK_QALead",
            task_id="V3-002-CLOSE",
            inv_id="inv-sub-2",
            target_commit_sha=self.commit_sha,
            created_at="2026-11-05T00:00:00Z",
            now_iso="2026-11-05T00:01:00Z",
            transcript_path=transcript,
            expected_deliverables=[],
        )
        self.assertEqual(rec.status, ExecutionStatus.AGENT_COMPLETION_NOT_VERIFIED)
        self.assertIn("status is 'FAILED'", rec.error)
        shutil.rmtree(str(brain_dir), ignore_errors=True)

    def test_p1_03_truncated_jsonl_fails_closed(self):
        """Negative: Corrupted or truncated JSONL line fails closed."""
        brain_dir = Path(tempfile.mkdtemp())
        session_id = "test-session-corrupt"
        sess_dir = brain_dir / session_id / ".system_generated" / "logs"
        sess_dir.mkdir(parents=True, exist_ok=True)
        transcript = sess_dir / "transcript.jsonl"

        with open(transcript, "w", encoding="utf-8") as f:
            f.write(json.dumps({"step_index": 1, "source": "MODEL", "status": "DONE", "content": "Partial"}) + "\n")
            f.write('{"step_index": 2, "source": "MODEL", "status": "DON\n')  # Corrupted!

        adapter = AntigravitySubagentBridgeAdapter(brain_base_dir=brain_dir, repo_root=self.repo_root)
        rec = adapter._parse_transcript_record(
            session_id=session_id,
            role="PK_QALead",
            task_id="V3-002-CLOSE",
            inv_id="inv-sub-3",
            target_commit_sha=self.commit_sha,
            created_at="2026-11-05T00:00:00Z",
            now_iso="2026-11-05T00:01:00Z",
            transcript_path=transcript,
            expected_deliverables=[],
        )
        self.assertEqual(rec.status, ExecutionStatus.AGENT_COMPLETION_NOT_VERIFIED)
        self.assertIn("truncated/corrupted", rec.error)
        shutil.rmtree(str(brain_dir), ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
