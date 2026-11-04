"""Security and governance policies for Studio V3 Orchestrator."""
from pathlib import Path
from typing import List
from .schemas import Task, TaskState, Severity, ReviewVerdict


class PolicyViolation(Exception):
    """Raised when a production governance policy is violated."""
    pass


class EvidenceMissingError(PolicyViolation):
    """Raised when required evidence files are missing on disk."""
    pass


class SelfApprovalBlockedError(PolicyViolation):
    """Raised when an actor attempts to review or approve their own work."""
    pass


class DependencyBlockedError(PolicyViolation):
    """Raised when a task is started before prerequisites are APPROVED."""
    pass


def verify_evidence_files(paths: List[str], repo_root: Path) -> List[str]:
    """Verify that every evidence path exists as a real file on disk."""
    if not paths:
        raise EvidenceMissingError("Evidence list is empty. Real verifiable files required.")
    
    verified = []
    for raw in paths:
        p = Path(raw)
        resolved = p if p.is_absolute() else (repo_root / p).resolve()
        if not resolved.is_file():
            raise EvidenceMissingError(f"Evidence file does not exist on disk: {raw} (resolved to {resolved})")
        # Store relative to repo root if inside repo
        try:
            rel = resolved.relative_to(repo_root)
            verified.append(str(rel).replace("\\", "/"))
        except ValueError:
            verified.append(str(resolved).replace("\\", "/"))
    return verified


def validate_start(task: Task, actor: str, all_tasks: dict[str, Task]) -> None:
    """Validate whether an actor can start work on a task."""
    if actor != task.owner:
        raise PolicyViolation(f"Actor '{actor}' is not the designated owner '{task.owner}' of task {task.id}.")
    
    if task.status not in (TaskState.READY, TaskState.FIX_REQUIRED):
        raise PolicyViolation(f"Task {task.id} is in status '{task.status.value}', cannot start (must be READY or FIX_REQUIRED).")
    
    # Check dependencies
    for dep_id in task.blocked_by:
        dep = all_tasks.get(dep_id)
        if not dep:
            raise DependencyBlockedError(f"Prerequisite task {dep_id} not found in queue.")
        if dep.status != TaskState.APPROVED:
            raise DependencyBlockedError(
                f"Task {task.id} is blocked by {dep_id} which has status '{dep.status.value}' (must be APPROVED)."
            )


def validate_submit(task: Task, actor: str, evidence_paths: List[str], repo_root: Path) -> List[str]:
    """Validate task submission by the worker."""
    if actor != task.owner:
        raise PolicyViolation(f"Actor '{actor}' cannot submit work for task {task.id}; owner is '{task.owner}'.")
    
    if task.status != TaskState.IN_PROGRESS:
        raise PolicyViolation(f"Task {task.id} is not IN_PROGRESS (current: {task.status.value}).")
    
    return verify_evidence_files(evidence_paths, repo_root)


def validate_review(task: Task, reviewer: str, verdict: ReviewVerdict, repo_root: Path) -> List[str]:
    """Validate independent review."""
    if task.status != TaskState.IN_REVIEW:
        raise PolicyViolation(f"Task {task.id} is in status '{task.status.value}', must be IN_REVIEW to conduct review.")
    
    if reviewer == task.owner:
        raise SelfApprovalBlockedError(
            f"Self-approval blocked! Actor '{reviewer}' is the owner of task {task.id} and cannot review it."
        )
    
    if reviewer not in task.reviewers:
        raise PolicyViolation(
            f"Reviewer '{reviewer}' is not in the designated reviewers list {task.reviewers} for task {task.id}."
        )
    
    verified_evidence = verify_evidence_files(verdict.evidence_paths, repo_root)
    return verified_evidence


def can_approve(task: Task) -> tuple[bool, str]:
    """Check if all approval gates are met."""
    if not task.reviewers:
        return False, "No reviewers designated for task."
    
    # Check that every designated reviewer has given PASS
    for r in task.reviewers:
        review_entry = task.reviews.get(r)
        if not review_entry:
            return False, f"Reviewer '{r}' has not yet submitted a review."
        if review_entry.get("result") != "PASS":
            return False, f"Reviewer '{r}' verdict was '{review_entry.get('result')}', not PASS."
    
    # Check that there are no unresolved P0 or P1 issues
    open_blockers = [
        i for i in task.issues
        if i.status == "OPEN" and i.severity in (Severity.P0, Severity.P1)
    ]
    if open_blockers:
        issue_ids = [i.id for i in open_blockers]
        return False, f"Cannot approve: open blocking issues exist: {issue_ids}"
    
    return True, "All independent reviewers passed and no blocking issues remain."


def validate_branch_safety(branch_name: str) -> None:
    """Enforce branch protection rules."""
    forbidden = ["main", "master", "integration"]
    clean_branch = branch_name.strip().lower()
    if clean_branch in forbidden or clean_branch.startswith("origin/main"):
        raise PolicyViolation(f"Direct changes to protected branch '{branch_name}' are strictly forbidden.")
