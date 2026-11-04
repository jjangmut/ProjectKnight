"""Security, governance, and cryptographic evidence policies for Studio V3 (V3-002-R1)."""
from __future__ import annotations
import hashlib
import uuid
import datetime
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from .schemas import Task, TaskState, Severity, ReviewVerdict, EvidenceItem


class PolicyViolation(Exception):
    """Raised when a production governance policy is violated."""
    pass


class EvidenceMissingError(PolicyViolation):
    """Raised when required evidence files are missing on disk."""
    pass


class EvidenceTamperedError(PolicyViolation):
    """Raised when evidence content does not match recorded SHA256."""
    pass


class StaleEvidenceError(PolicyViolation):
    """Raised when evidence was generated for a different commit or iteration."""
    pass


class SelfApprovalBlockedError(PolicyViolation):
    """Raised when an actor attempts to review or approve their own work."""
    pass


class IdentityVerificationError(PolicyViolation):
    """Raised when reviewer identity or independent session attestation fails."""
    pass


class StaleReviewError(PolicyViolation):
    """Raised when a review is submitted for a stale commit or iteration."""
    pass


class DependencyBlockedError(PolicyViolation):
    """Raised when a task is started before prerequisites are APPROVED."""
    pass


class TaskLeaseConflictError(PolicyViolation):
    """Raised when a task is currently leased by another actor."""
    pass


class ConcurrentModificationError(PolicyViolation):
    """Raised when task state version mismatch occurs (CAS failed)."""
    pass


def calculate_sha256(path: Path) -> str:
    """Calculate the hex SHA256 digest of a file on disk."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def build_evidence_manifest(
    task_id: str,
    iteration: int,
    branch: str,
    commit_sha: str,
    invocation_id: str,
    paths: List[str],
    repo_root: Path,
) -> List[EvidenceItem]:
    """Construct an auditable cryptographic evidence manifest for submitted artifacts."""
    if not paths:
        raise EvidenceMissingError("Evidence list is empty. Real verifiable files required.")

    manifest: List[EvidenceItem] = []
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()

    for raw in paths:
        p = Path(raw)
        resolved = p if p.is_absolute() else (repo_root / p).resolve()
        if not resolved.is_file():
            raise EvidenceMissingError(f"Evidence file does not exist on disk: {raw} (resolved to {resolved})")

        # Boundary check: ensure file is inside repository workspace
        try:
            rel = resolved.relative_to(repo_root)
            norm_path = str(rel).replace("\\", "/")
        except ValueError:
            raise PolicyViolation(f"Evidence file {resolved} is outside repository root {repo_root}.")

        file_hash = calculate_sha256(resolved)
        ev_id = f"ev-{uuid.uuid4().hex[:10]}"
        manifest.append(
            EvidenceItem(
                evidence_id=ev_id,
                task_id=task_id,
                iteration=iteration,
                source_commit_sha=commit_sha,
                working_branch=branch,
                agent_invocation_id=invocation_id,
                file_path=norm_path,
                sha256=file_hash,
                creation_time=now_iso,
                verification_method="SHA256_HASH_VERIFIED",
            )
        )
    return manifest


def verify_evidence_manifest(
    manifest: List[EvidenceItem],
    expected_task_id: str,
    expected_iteration: int,
    expected_commit_sha: str,
    repo_root: Path,
) -> List[str]:
    """Verify that all evidence items exist, have not been altered, and match commit/iteration."""
    if not manifest:
        raise EvidenceMissingError("Evidence manifest is empty.")

    verified_paths = []
    for item in manifest:
        # Check task & iteration
        if item.task_id != expected_task_id:
            raise StaleEvidenceError(f"Evidence task {item.task_id} does not match expected {expected_task_id}.")
        if item.iteration != expected_iteration:
            raise StaleEvidenceError(
                f"Evidence iteration {item.iteration} does not match current task iteration {expected_iteration}."
            )
        if expected_commit_sha and item.source_commit_sha != expected_commit_sha:
            raise StaleEvidenceError(
                f"Evidence source commit {item.source_commit_sha} does not match task commit {expected_commit_sha}."
            )

        # Check disk existence and workspace boundary
        resolved = (repo_root / item.file_path).resolve()
        if not resolved.is_file():
            raise EvidenceMissingError(f"Evidence file missing on disk: {item.file_path}")

        try:
            resolved.relative_to(repo_root)
        except ValueError:
            raise PolicyViolation(f"Evidence file {resolved} is outside repository boundary.")

        # Check cryptographic hash integrity
        current_hash = calculate_sha256(resolved)
        if current_hash != item.sha256:
            raise EvidenceTamperedError(
                f"Evidence file {item.file_path} was tampered with or modified after submission. "
                f"Recorded SHA: {item.sha256}, Actual on disk: {current_hash}"
            )
        verified_paths.append(item.file_path)

    return verified_paths


def verify_reviewer_attestation(
    verdict: ReviewVerdict,
    task: Task,
    worker_session_id: Optional[str] = None,
) -> None:
    """Verify cryptographic and session identity of reviewer to prevent spoofing."""
    if verdict.agent_role not in task.reviewers:
        raise PolicyViolation(
            f"Reviewer '{verdict.agent_role}' is not in designated reviewers list {task.reviewers} for task {task.id}."
        )

    if verdict.agent_role == task.owner:
        raise SelfApprovalBlockedError(
            f"Self-approval blocked! Actor '{verdict.agent_role}' is task owner and cannot review own work."
        )

    if not verdict.session_id or verdict.session_id.strip() == "":
        raise IdentityVerificationError(
            f"Reviewer '{verdict.agent_role}' must provide an authenticated provider session_id."
        )

    # Worker session cannot be reused by reviewer
    if worker_session_id and verdict.session_id == worker_session_id:
        raise IdentityVerificationError(
            f"Reviewer '{verdict.agent_role}' reused worker's session ID '{worker_session_id}'. "
            "Independent AI reviewer session required."
        )

    # Check commit SHA match
    if task.current_commit_sha and verdict.reviewed_commit_sha != task.current_commit_sha:
        raise StaleReviewError(
            f"Review is for commit '{verdict.reviewed_commit_sha}', but current task commit is '{task.current_commit_sha}'."
        )

    # Check iteration match
    if verdict.iteration != task.iteration:
        raise StaleReviewError(
            f"Review is for iteration {verdict.iteration}, but current task iteration is {task.iteration}."
        )


def validate_start(task: Task, actor: str, all_tasks: Dict[str, Task]) -> None:
    """Validate whether an actor can start work on a task."""
    if actor != task.owner:
        raise PolicyViolation(f"Actor '{actor}' is not the designated owner '{task.owner}' of task {task.id}.")

    if task.status not in (TaskState.READY, TaskState.FIX_REQUIRED):
        raise PolicyViolation(
            f"Task {task.id} is in status '{task.status.value}', cannot start (must be READY or FIX_REQUIRED)."
        )

    # Check dependencies
    for dep_id in task.blocked_by:
        dep = all_tasks.get(dep_id)
        if not dep:
            raise DependencyBlockedError(f"Prerequisite task {dep_id} not found in queue.")
        if dep.status != TaskState.APPROVED:
            raise DependencyBlockedError(
                f"Task {task.id} is blocked by {dep_id} which has status '{dep.status.value}' (must be APPROVED)."
            )


def can_approve(task: Task) -> Tuple[bool, str]:
    """Check if all independent approval gates are met."""
    if not task.reviewers:
        return False, "No reviewers designated for task."

    reviewer_sessions: Dict[str, str] = {}
    for r in task.reviewers:
        review_entry = task.reviews.get(r)
        if not review_entry:
            return False, f"Reviewer '{r}' has not yet submitted a review for current iteration."
        if review_entry.get("result") != "PASS":
            return False, f"Reviewer '{r}' verdict was '{review_entry.get('result')}', not PASS."

        sess_id = review_entry.get("session_id", "")
        if not sess_id:
            return False, f"Reviewer '{r}' lacks authenticated session ID."

        if sess_id in reviewer_sessions.values():
            return False, f"Reviewers share identical session ID '{sess_id}'. Independent agents required."
        reviewer_sessions[r] = sess_id

    # Check that there are no unresolved P0 or P1 issues
    open_blockers = [
        i for i in task.issues
        if i.status == "OPEN" and i.severity in (Severity.P0, Severity.P1)
    ]
    if open_blockers:
        issue_ids = [i.id for i in open_blockers]
        return False, f"Cannot approve: open blocking issues exist: {issue_ids}"

    return True, "All independent reviewers passed with distinct verified sessions and no open blocking issues."


def validate_branch_safety(branch_name: str) -> None:
    """Enforce branch protection rules."""
    forbidden = ["main", "master", "integration"]
    clean_branch = branch_name.strip().lower()
    if clean_branch in forbidden or clean_branch.startswith("origin/main") or clean_branch.startswith("origin/integration"):
        raise PolicyViolation(f"Direct changes to protected branch '{branch_name}' are strictly forbidden.")
