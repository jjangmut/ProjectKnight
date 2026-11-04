"""Multi-agent Task Dispatcher and autonomous quality loop coordinator (V3-002-R1)."""
from __future__ import annotations
import subprocess
import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional, Callable
from .schemas import (
    Task,
    TaskState,
    Severity,
    Issue,
    ReviewVerdict,
    ExecutionRecord,
    ExecutionStatus,
    EvidenceItem,
)
from .queue_store import QueueStore
from .event_log import EventLog
from .policies import (
    validate_start,
    verify_evidence_manifest,
    build_evidence_manifest,
    verify_reviewer_attestation,
    can_approve,
    validate_branch_safety,
    calculate_sha256,
    PolicyViolation,
    EvidenceMissingError,
    EvidenceTamperedError,
    StaleEvidenceError,
    SelfApprovalBlockedError,
    IdentityVerificationError,
    StaleReviewError,
    DependencyBlockedError,
    TaskLeaseConflictError,
    ConcurrentModificationError,
)
from .adapters.base import AgentAdapter


class TaskDispatcher:
    """Manages task scheduling, agent execution, cryptographic evidence gates, and the autonomous quality rework loop."""

    def __init__(self, queue_store: QueueStore, event_log: EventLog, repo_root: Path):
        self.queue_store = queue_store
        self.event_log = event_log
        self.repo_root = repo_root

    def get_current_commit_sha(self) -> str:
        try:
            res = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=str(self.repo_root),
                capture_output=True,
                text=True,
                timeout=5,
            )
            return res.stdout.strip() if res.returncode == 0 else "UNKNOWN_SHA"
        except Exception:
            return "UNKNOWN_SHA"

    def select_next_task(self) -> Optional[Task]:
        """Producer logic: select highest priority unblocked task ready for execution."""
        all_tasks = self.queue_store.load_all_tasks()
        candidates = []
        for t in all_tasks.values():
            if t.status in (TaskState.READY, TaskState.FIX_REQUIRED):
                blocked = False
                for dep_id in t.blocked_by:
                    dep = all_tasks.get(dep_id)
                    if not dep or dep.status != TaskState.APPROVED:
                        blocked = True
                        break
                if not blocked:
                    candidates.append(t)

        if not candidates:
            return None
        candidates.sort(key=lambda x: (x.priority, x.iteration, x.id))
        return candidates[0]

    def start_task(self, task_id: str, actor: str) -> Task:
        """Producer/Worker transition: READY/FIX_REQUIRED -> IN_PROGRESS with lease locking."""
        # 1. Claim task lease to prevent duplicate runs
        self.queue_store.claim_task_lease(task_id, actor=actor)

        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        # 2. Enforce branch safety if active branch is set
        if task.active_branch:
            validate_branch_safety(task.active_branch)

        all_tasks = self.queue_store.load_all_tasks()
        validate_start(task, actor, all_tasks)

        task.status = TaskState.IN_PROGRESS
        task.iteration += 1
        task.reviews = {}  # Reset reviews for the fresh iteration
        task.current_commit_sha = self.get_current_commit_sha()
        self.queue_store.save_task(task)

        sha = task.current_commit_sha
        self.event_log.record_event(
            event_type="TASK_STARTED",
            task_id=task.id,
            actor=actor,
            commit_sha=sha,
            details={"iteration": task.iteration, "status": task.status.value, "version": task.version},
        )
        return task

    def submit_work(
        self,
        task_id: str,
        actor: str,
        evidence_paths: List[str],
        invocation_id: str = "",
    ) -> Task:
        """Worker transition: IN_PROGRESS -> IN_REVIEW with cryptographic evidence manifest."""
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        if actor != task.owner:
            raise PolicyViolation(f"Actor '{actor}' cannot submit work for task {task.id}; owner is '{task.owner}'.")

        if task.status != TaskState.IN_PROGRESS:
            raise PolicyViolation(f"Task {task.id} is not IN_PROGRESS (current: {task.status.value}).")

        current_sha = self.get_current_commit_sha()
        task.current_commit_sha = current_sha

        # Build cryptographic manifest with SHA256 of every file
        manifest = build_evidence_manifest(
            task_id=task.id,
            iteration=task.iteration,
            branch=task.active_branch or "HEAD",
            commit_sha=current_sha,
            invocation_id=invocation_id or f"sub-{task.id}-{task.iteration}",
            paths=evidence_paths,
            repo_root=self.repo_root,
        )

        task.evidence_manifest = manifest
        task.evidence = [m.file_path for m in manifest]
        task.status = TaskState.IN_REVIEW
        self.queue_store.save_task(task)

        self.event_log.record_event(
            event_type="WORK_SUBMITTED",
            task_id=task.id,
            actor=actor,
            commit_sha=current_sha,
            evidence_paths=task.evidence,
            details={
                "iteration": task.iteration,
                "status": task.status.value,
                "evidence_manifest": [m.to_dict() for m in manifest],
            },
        )
        return task

    def review_task(
        self,
        task_id: str,
        verdict: ReviewVerdict,
        worker_session_id: Optional[str] = None,
    ) -> Task:
        """Reviewer transition: IN_REVIEW -> FIX_REQUIRED or APPROVED with identity attestation."""
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        if task.status != TaskState.IN_REVIEW:
            raise PolicyViolation(f"Task {task.id} is in status '{task.status.value}', must be IN_REVIEW to conduct review.")

        # 1. Cryptographic and Session Identity Attestation
        verify_reviewer_attestation(verdict, task, worker_session_id=worker_session_id)

        # 2. Cryptographic Evidence Integrity Check on submitted artifacts
        verify_evidence_manifest(
            task.evidence_manifest,
            expected_task_id=task.id,
            expected_iteration=task.iteration,
            expected_commit_sha=task.current_commit_sha,
            repo_root=self.repo_root,
        )

        # 3. Verify reviewer's own report files
        if verdict.evidence_paths:
            rev_manifest = build_evidence_manifest(
                task_id=task.id,
                iteration=task.iteration,
                branch=task.active_branch or "HEAD",
                commit_sha=task.current_commit_sha,
                invocation_id=verdict.invocation_id,
                paths=verdict.evidence_paths,
                repo_root=self.repo_root,
            )
            verdict.evidence_hashes = {m.file_path: m.sha256 for m in rev_manifest}

        # Store review in task dict
        task.reviews[verdict.agent_role] = verdict.to_dict()
        sha = task.current_commit_sha

        if verdict.result == "FIX_REQUIRED":
            task.status = TaskState.FIX_REQUIRED
            # Register newly reported issues
            for issue in verdict.issues:
                self.queue_store.create_issue(issue)
                if not any(i.id == issue.id for i in task.issues):
                    task.issues.append(issue)

            self.queue_store.save_task(task)
            self.event_log.record_event(
                event_type="REVIEW_REJECTED",
                task_id=task.id,
                actor=verdict.agent_role,
                provider=verdict.provider,
                commit_sha=sha,
                verdict=verdict.result,
                evidence_paths=[m.file_path for m in task.evidence_manifest],
                details={
                    "iteration": task.iteration,
                    "session_id": verdict.session_id,
                    "issues_filed": [i.id for i in verdict.issues],
                    "notes": verdict.notes,
                },
            )
        elif verdict.result == "PASS":
            can_appr, reason = can_approve(task)
            if can_appr:
                task.status = TaskState.APPROVED
                # Release lease upon approval
                self.queue_store.release_task_lease(task.id, actor=task.owner)
                self.queue_store.save_task(task)
                self.event_log.record_event(
                    event_type="TASK_APPROVED",
                    task_id=task.id,
                    actor=verdict.agent_role,
                    provider=verdict.provider,
                    commit_sha=sha,
                    verdict="APPROVED",
                    evidence_paths=[m.file_path for m in task.evidence_manifest],
                    details={"iteration": task.iteration, "reason": reason, "session_id": verdict.session_id},
                )
            else:
                self.queue_store.save_task(task)
                self.event_log.record_event(
                    event_type="REVIEW_PASSED",
                    task_id=task.id,
                    actor=verdict.agent_role,
                    provider=verdict.provider,
                    commit_sha=sha,
                    verdict="PASS",
                    evidence_paths=[m.file_path for m in task.evidence_manifest],
                    details={"iteration": task.iteration, "pending_reason": reason, "session_id": verdict.session_id},
                )
        else:
            raise ValueError(f"Invalid review result '{verdict.result}', must be PASS or FIX_REQUIRED.")

        return task

    def execute_autonomous_loop(
        self,
        task_id: str,
        adapter: AgentAdapter,
        worker_action: Optional[Callable[[Task, int, AgentAdapter], Tuple[List[str], ExecutionRecord]]] = None,
        reviewer_evaluators: Optional[Dict[str, Callable[[Task, int, AgentAdapter, ExecutionRecord], ReviewVerdict]]] = None,
        max_cycles: int = 3,
    ) -> Dict[str, Any]:
        """
        BLOCKER 01 FIX: Executes the autonomous quality loop using the provided adapter.
        Producer -> Worker (via adapter) -> Submit (with SHA256 manifest) ->
        QA (via adapter) -> (if reject: Issue -> Worker fix -> QA retest) ->
        Director (via adapter) -> Approval.
        """
        audit_history: List[Dict[str, Any]] = []

        # Probe adapter before launch
        probe_res = adapter.probe()
        is_mock = probe_res.get("mock", False)
        execution_tag = "MOCK_TEST_PASS" if is_mock else "REAL_AGENT_INVOKED"

        for cycle_idx in range(1, max_cycles + 1):
            task = self.queue_store.get_task(task_id)
            if not task:
                raise ValueError(f"Task {task_id} not found.")

            if task.status == TaskState.APPROVED:
                break

            # 1. Start task
            self.start_task(task.id, actor=task.owner)
            cycle_meta = {
                "cycle": cycle_idx,
                "iteration": task.iteration,
                "worker": task.owner,
                "execution_tag": execution_tag,
                "timestamp_start": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            }

            # 2. Dispatch Worker through adapter
            open_issues = self.queue_store.get_open_issues(task.id)
            issue_prompt = ""
            if open_issues:
                issue_prompt = f" Previous issues to resolve: {[i.title for i in open_issues]}."

            worker_prompt = f"Task: {task.id} - {task.title}. Iteration {task.iteration}.{issue_prompt}"

            if worker_action:
                evidence_paths, worker_record = worker_action(task, cycle_idx, adapter)
            else:
                # Direct adapter dispatch
                worker_record = adapter.dispatch(
                    task_id=task.id,
                    role=task.owner,
                    prompt=worker_prompt,
                    worktree=str(self.repo_root),
                )
                evidence_paths = [m.file_path for m in worker_record.evidence_manifest]

            cycle_meta["worker_execution"] = worker_record.to_dict()

            # If worker failed or timed out, halt cycle safely
            if worker_record.status in (ExecutionStatus.FAILED, ExecutionStatus.TIMED_OUT):
                cycle_meta["final_task_status"] = "WORKER_FAILED"
                audit_history.append(cycle_meta)
                break

            # 3. Submit work deliverables
            task = self.submit_work(
                task.id,
                actor=task.owner,
                evidence_paths=evidence_paths,
                invocation_id=worker_record.invocation_id,
            )
            cycle_meta["submitted_commit_sha"] = task.current_commit_sha
            cycle_meta["evidence_count"] = len(task.evidence_manifest)

            # 4. Review Phase: Dispatch reviewers through adapter
            cycle_rejected = False
            for reviewer in task.reviewers:
                if reviewer_evaluators and reviewer in reviewer_evaluators:
                    verdict = reviewer_evaluators[reviewer](task, cycle_idx, adapter, worker_record)
                else:
                    # Direct review dispatch
                    rev_prompt = f"Review Task {task.id} (Commit: {task.current_commit_sha})."
                    rev_record = adapter.dispatch(
                        task_id=task.id,
                        role=reviewer,
                        prompt=rev_prompt,
                        worktree=str(self.repo_root),
                    )
                    # Parse verdict from adapter record
                    verdict = ReviewVerdict(
                        task_id=task.id,
                        iteration=task.iteration,
                        agent_role=reviewer,
                        provider=rev_record.provider,
                        invocation_id=rev_record.invocation_id,
                        session_id=rev_record.session_id,
                        reviewed_commit_sha=task.current_commit_sha,
                        result="PASS" if rev_record.status == ExecutionStatus.SUCCEEDED else "FIX_REQUIRED",
                        evidence_paths=[m.file_path for m in rev_record.evidence_manifest],
                    )

                task = self.review_task(
                    task.id,
                    verdict=verdict,
                    worker_session_id=worker_record.session_id,
                )
                cycle_meta[f"review_{reviewer}"] = verdict.to_dict()

                if verdict.result == "FIX_REQUIRED":
                    cycle_rejected = True
                    break  # Early rework required

            cycle_meta["final_task_status"] = task.status.value
            audit_history.append(cycle_meta)

            if task.status == TaskState.APPROVED:
                break

        final_task = self.queue_store.get_task(task_id)
        approved = final_task.status == TaskState.APPROVED if final_task else False
        return {
            "task_id": task_id,
            "final_status": final_task.status.value if final_task else "UNKNOWN",
            "iterations_run": len(audit_history),
            "approved": approved,
            "execution_mode": "MOCK" if is_mock else "REAL_AGENT",
            "cycles": audit_history,
        }
