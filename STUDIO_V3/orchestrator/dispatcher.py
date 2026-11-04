"""Multi-agent Task Dispatcher and autonomous quality loop coordinator."""
from __future__ import annotations
import subprocess
import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional, Callable
from .schemas import Task, TaskState, Severity, Issue, ReviewVerdict, ExecutionRecord
from .queue_store import QueueStore
from .event_log import EventLog
from .policies import (
    validate_start,
    validate_submit,
    validate_review,
    can_approve,
    PolicyViolation,
    EvidenceMissingError,
    SelfApprovalBlockedError,
    DependencyBlockedError,
)
from .adapters.base import AgentAdapter


class TaskDispatcher:
    """Manages task scheduling, real agent execution, and the autonomous quality review loop."""

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
                # Verify dependencies
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
        # Sort by priority ascending, then iteration ascending
        candidates.sort(key=lambda x: (x.priority, x.iteration, x.id))
        return candidates[0]

    def start_task(self, task_id: str, actor: str) -> Task:
        """Producer/Worker transition: READY/FIX_REQUIRED -> IN_PROGRESS."""
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")
        
        all_tasks = self.queue_store.load_all_tasks()
        validate_start(task, actor, all_tasks)

        task.status = TaskState.IN_PROGRESS
        task.iteration += 1
        task.reviews = {}  # Reset reviews for the fresh iteration
        self.queue_store.save_task(task)

        sha = self.get_current_commit_sha()
        self.event_log.record_event(
            event_type="TASK_STARTED",
            task_id=task.id,
            actor=actor,
            commit_sha=sha,
            details={"iteration": task.iteration, "status": task.status.value},
        )
        return task

    def submit_work(self, task_id: str, actor: str, evidence_paths: List[str]) -> Task:
        """Worker transition: IN_PROGRESS -> IN_REVIEW."""
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        verified_evidence = validate_submit(task, actor, evidence_paths, self.repo_root)
        task.evidence = verified_evidence
        task.status = TaskState.IN_REVIEW
        self.queue_store.save_task(task)

        sha = self.get_current_commit_sha()
        self.event_log.record_event(
            event_type="WORK_SUBMITTED",
            task_id=task.id,
            actor=actor,
            commit_sha=sha,
            evidence_paths=verified_evidence,
            details={"iteration": task.iteration, "status": task.status.value},
        )
        return task

    def review_task(self, task_id: str, reviewer: str, verdict: ReviewVerdict) -> Task:
        """Reviewer transition: IN_REVIEW -> FIX_REQUIRED or APPROVED (or still IN_REVIEW)."""
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        verified_evidence = validate_review(task, reviewer, verdict, self.repo_root)
        verdict.evidence_paths = verified_evidence

        # Record review in task reviews dict
        task.reviews[reviewer] = verdict.to_dict()

        sha = self.get_current_commit_sha()

        if verdict.result == "FIX_REQUIRED":
            task.status = TaskState.FIX_REQUIRED
            # Register newly reported issues
            for issue in verdict.issues:
                self.queue_store.create_issue(issue)
                # Keep local list updated
                if not any(i.id == issue.id for i in task.issues):
                    task.issues.append(issue)
            
            self.queue_store.save_task(task)
            self.event_log.record_event(
                event_type="REVIEW_REJECTED",
                task_id=task.id,
                actor=reviewer,
                commit_sha=sha,
                verdict=verdict.result,
                evidence_paths=verified_evidence,
                details={
                    "iteration": task.iteration,
                    "status": task.status.value,
                    "issues_filed": [i.id for i in verdict.issues],
                    "notes": verdict.notes,
                },
            )
        elif verdict.result == "PASS":
            # Check if all reviewers have passed
            can_appr, reason = can_approve(task)
            if can_appr:
                task.status = TaskState.APPROVED
                self.queue_store.save_task(task)
                self.event_log.record_event(
                    event_type="TASK_APPROVED",
                    task_id=task.id,
                    actor=reviewer,
                    commit_sha=sha,
                    verdict="APPROVED",
                    evidence_paths=verified_evidence,
                    details={"iteration": task.iteration, "reason": reason},
                )
            else:
                self.queue_store.save_task(task)
                self.event_log.record_event(
                    event_type="REVIEW_PASSED",
                    task_id=task.id,
                    actor=reviewer,
                    commit_sha=sha,
                    verdict="PASS",
                    evidence_paths=verified_evidence,
                    details={"iteration": task.iteration, "pending_reason": reason},
                )
        else:
            raise ValueError(f"Invalid review result '{verdict.result}', must be PASS or FIX_REQUIRED.")

        return task

    def execute_autonomous_loop(
        self,
        task_id: str,
        adapter: AgentAdapter,
        worker_action: Callable[[Task, int], List[str]],
        reviewer_evaluators: Dict[str, Callable[[Task, int], ReviewVerdict]],
        max_cycles: int = 3,
    ) -> Dict[str, Any]:
        """
        Executes the mandatory autonomous cycle:
        Producer -> Worker -> QA -> (if fail: issue -> Producer reassign -> Worker -> QA) -> Director -> Approved.
        """
        audit_history: List[Dict[str, Any]] = []

        for cycle_idx in range(1, max_cycles + 1):
            task = self.queue_store.get_task(task_id)
            if not task:
                raise ValueError(f"Task {task_id} not found.")

            if task.status == TaskState.APPROVED:
                break

            # 1. Start task for current cycle
            self.start_task(task.id, actor=task.owner)
            cycle_meta = {
                "cycle": cycle_idx,
                "iteration": task.iteration + 1,
                "worker": task.owner,
                "timestamp_start": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            }

            # 2. Worker executes implementation
            evidence_paths = worker_action(task, cycle_idx)
            # Submit evidence
            task = self.submit_work(task.id, actor=task.owner, evidence_paths=evidence_paths)
            cycle_meta["evidence"] = evidence_paths

            # 3. Independent Reviews
            cycle_rejected = False
            for reviewer in task.reviewers:
                evaluator = reviewer_evaluators.get(reviewer)
                if not evaluator:
                    raise RuntimeError(f"No evaluator provided for reviewer {reviewer}")
                verdict = evaluator(task, cycle_idx)
                task = self.review_task(task.id, reviewer=reviewer, verdict=verdict)
                cycle_meta[f"review_{reviewer}"] = verdict.to_dict()

                if verdict.result == "FIX_REQUIRED":
                    cycle_rejected = True
                    break  # Rework required immediately

            cycle_meta["final_task_status"] = task.status.value
            audit_history.append(cycle_meta)

            if task.status == TaskState.APPROVED:
                break

        final_task = self.queue_store.get_task(task_id)
        return {
            "task_id": task_id,
            "final_status": final_task.status.value if final_task else "UNKNOWN",
            "iterations_run": len(audit_history),
            "approved": final_task.status == TaskState.APPROVED if final_task else False,
            "cycles": audit_history,
        }
