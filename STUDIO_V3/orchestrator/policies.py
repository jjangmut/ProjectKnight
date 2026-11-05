"""Security, governance, and cryptographic evidence policies for Studio V3 (V3-002-R1)."""
from __future__ import annotations
import hashlib
import subprocess
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


class UntrustedSessionError(IdentityVerificationError):
    """Raised when an unverified or forged session ID is presented without trusted registration."""
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


def is_valid_hex_sha40(sha: str) -> bool:
    """Check if a string is a canonical 40-character hexadecimal SHA."""
    if not isinstance(sha, str) or len(sha) != 40:
        return False
    return all(c in "0123456789abcdefABCDEF" for c in sha)


def verify_commit_exists(commit_sha: str, repo_root: Path, skip_git_check: bool = False) -> None:
    """Verify that a canonical 40-hex Git commit SHA exists in the local repository."""
    if skip_git_check:
        return
    if not is_valid_hex_sha40(commit_sha):
        raise PolicyViolation(
            f"Invalid commit SHA: '{commit_sha}'. Production gates require a canonical 40-character hexadecimal SHA."
        )
    try:
        res_wt = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if res_wt.returncode != 0 or res_wt.stdout.strip() != "true":
            raise PolicyViolation(f"Path '{repo_root}' is not inside a valid Git repository or worktree.")

        res = subprocess.run(
            ["git", "cat-file", "-e", f"{commit_sha}^{{commit}}"],
            cwd=str(repo_root),
            capture_output=True,
            timeout=5,
        )
        if res.returncode != 0:
            raise PolicyViolation(f"Commit '{commit_sha}' does not exist in repository git object database.")
    except (FileNotFoundError, subprocess.SubprocessError) as e:
        if isinstance(e, PolicyViolation):
            raise
        raise PolicyViolation(f"Git execution failed while verifying commit object '{commit_sha}': {e}")


def verify_commit_on_branch(commit_sha: str, branch: str, repo_root: Path, skip_git_check: bool = False) -> None:
    """Verify that commit_sha exists and is reachable from authorized branch ref."""
    if skip_git_check:
        return
    verify_commit_exists(commit_sha, repo_root, skip_git_check=skip_git_check)

    if not branch or branch in ("HEAD", ""):
        raise PolicyViolation("Authorized branch ref is required; cannot be empty or 'HEAD'.")

    try:
        # Check if authorized branch exists in refs
        target_ref = None
        candidates = [
            branch,
            f"refs/heads/{branch}",
            f"refs/remotes/origin/{branch}",
            f"origin/{branch}",
        ]
        for cand in candidates:
            res_chk = subprocess.run(
                ["git", "rev-parse", "--verify", cand],
                cwd=str(repo_root),
                capture_output=True,
                text=True,
                timeout=5,
            )
            if res_chk.returncode == 0:
                target_ref = cand
                break

        if not target_ref:
            raise PolicyViolation(
                f"Authorized branch '{branch}' does not exist in repository refs."
            )

        # Check if commit_sha is ancestor of target_ref (or equal to target_ref)
        res = subprocess.run(
            ["git", "merge-base", "--is-ancestor", commit_sha, target_ref],
            cwd=str(repo_root),
            capture_output=True,
            timeout=5,
        )
        if res.returncode == 0:
            return
        elif res.returncode == 1:
            raise PolicyViolation(
                f"Commit '{commit_sha}' is not reachable from authorized branch '{branch}' (target_ref: '{target_ref}')."
            )
        else:
            err = res.stderr.decode("utf-8", errors="replace").strip()
            raise PolicyViolation(
                f"Git merge-base failed with exit code {res.returncode}: {err}"
            )
    except (FileNotFoundError, subprocess.SubprocessError) as e:
        if isinstance(e, PolicyViolation):
            raise
        raise PolicyViolation(f"Git execution failed while checking branch reachability: {e}")


def verify_committed_source_evidence(
    manifest: List[EvidenceItem],
    commit_sha: str,
    repo_root: Path,
    skip_git_check: bool = False,
) -> None:
    """
    Verify that all source code deliverables exist in git commit commit_sha and match disk bytes exactly.
    Uncommitted changes on disk or paths not found in commit_sha are strictly rejected.
    Post-commit generated runtime logs (under STUDIO_V3/evidence/) are verified for hash integrity.
    """
    if skip_git_check:
        return
    verify_commit_exists(commit_sha, repo_root, skip_git_check=skip_git_check)

    for item in manifest:
        p = Path(item.file_path)
        if ".." in item.file_path.replace("\\", "/").split("/"):
            raise PolicyViolation(f"Path traversal detected: '{item.file_path}' contains parent directory references.")

        if p.is_absolute():
            resolved = p.resolve()
        else:
            resolved = (repo_root / p).resolve()

        try:
            rel = resolved.relative_to(repo_root)
            norm_path = str(rel).replace("\\", "/")
        except ValueError:
            raise PolicyViolation(f"Path traversal detected: '{item.file_path}' is outside repository root.")

        if not resolved.is_file():
            raise EvidenceMissingError(f"Evidence file missing on disk: {norm_path}")

        disk_sha = calculate_sha256(resolved)
        if disk_sha != item.sha256:
            raise EvidenceTamperedError(
                f"Evidence file '{norm_path}' on disk (SHA: {disk_sha}) does not match manifest SHA: {item.sha256}."
            )

        # Distinguish runtime generated evidence vs committed source deliverables
        is_runtime_artifact = norm_path.startswith("STUDIO_V3/evidence/") and (
            norm_path.endswith(".log")
            or norm_path.endswith(".json")
            or "live_run" in norm_path
            or "test_logs" in norm_path
            or "cycle_" in norm_path
        )

        try:
            # Check git commit object database for this path
            res_cat = subprocess.run(
                ["git", "cat-file", "-e", f"{commit_sha}:{norm_path}"],
                cwd=str(repo_root),
                capture_output=True,
                timeout=5,
            )
            if res_cat.returncode != 0:
                if is_runtime_artifact:
                    # Post-commit runtime logs are valid separate generated evidence
                    continue
                else:
                    raise PolicyViolation(
                        f"Source deliverable '{norm_path}' does not exist in git commit '{commit_sha}'. "
                        "Uncommitted source files cannot be accepted as committed deliverables."
                    )

            # Retrieve git blob content
            res_show = subprocess.run(
                ["git", "show", f"{commit_sha}:{norm_path}"],
                cwd=str(repo_root),
                capture_output=True,
                timeout=10,
            )
            if res_show.returncode != 0:
                raise PolicyViolation(f"Failed to read git blob for '{norm_path}' at commit '{commit_sha}'.")

            committed_sha = hashlib.sha256(res_show.stdout).hexdigest()
            if disk_sha != committed_sha:
                raise EvidenceTamperedError(
                    f"Evidence file '{norm_path}' has uncommitted changes on disk! "
                    f"Disk SHA256: {disk_sha}, Git commit {commit_sha} blob SHA256: {committed_sha}."
                )
            if item.sha256 != committed_sha:
                raise EvidenceTamperedError(
                    f"Evidence manifest recorded SHA256 for '{norm_path}' does not match git commit {commit_sha} blob SHA256."
                )
        except (FileNotFoundError, subprocess.SubprocessError) as e:
            if isinstance(e, PolicyViolation):
                raise
            raise PolicyViolation(f"Git execution failed while checking evidence '{norm_path}': {e}")


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
        if ".." in raw.replace("\\", "/").split("/"):
            raise PolicyViolation(f"Path traversal detected in evidence path: {raw}")

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
    skip_git_check: bool = False,
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

        if ".." in item.file_path.replace("\\", "/").split("/"):
            raise PolicyViolation(f"Path traversal detected in evidence path: {item.file_path}")

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

    # In addition, verify committed source evidence against the git commit blob
    verify_committed_source_evidence(manifest, expected_commit_sha, repo_root, skip_git_check=skip_git_check)

    return verified_paths


def verify_reviewer_attestation(
    verdict: ReviewVerdict,
    task: Task,
    worker_session_id: Optional[str] = None,
    invocation_registry: Optional[Any] = None,
    allow_mock: bool = False,
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

    # Check trusted invocation registry
    if invocation_registry is not None:
        if verdict.provider in ("OPERATOR_CLI", "OPERATOR_MANUAL"):
            raise IdentityVerificationError(
                f"Reviewer '{verdict.agent_role}' submitted verdict with provider '{verdict.provider}'. "
                "Autonomous AI review gate requires a registered provider invocation."
            )

        inv = invocation_registry.find_invocation_by_session(
            task.id, verdict.iteration, verdict.agent_role, verdict.session_id
        )
        if not inv:
            raise IdentityVerificationError(
                f"Reviewer session '{verdict.session_id}' for role '{verdict.agent_role}' is not found "
                f"in trusted invocation registry for task {task.id} iteration {task.iteration}."
            )

        if inv.terminal_status != "SUCCEEDED":
            raise IdentityVerificationError(
                f"Reviewer invocation '{inv.invocation_id}' did not complete with SUCCEEDED (actual: {inv.terminal_status})."
            )

        if task.current_commit_sha and inv.target_commit_sha != task.current_commit_sha:
            raise IdentityVerificationError(
                f"Reviewer invocation targeted commit '{inv.target_commit_sha}', but current task commit is '{task.current_commit_sha}'."
            )

        if not allow_mock and inv.provider in ("MOCK", "SIMULATED_MOCK", "MOCK_SIMULATED"):
            raise IdentityVerificationError("Mock invocation cannot satisfy live independent AI review gate.")


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


def can_approve(
    task: Task,
    invocation_registry: Optional[Any] = None,
    allow_mock: bool = False,
) -> Tuple[bool, str]:
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

        # Verify against registry if available
        if invocation_registry is not None:
            provider = review_entry.get("provider", "")
            if provider in ("OPERATOR_CLI", "OPERATOR_MANUAL"):
                return False, f"Reviewer '{r}' used '{provider}'. Independent AI review required."
            inv = invocation_registry.find_invocation_by_session(task.id, task.iteration, r, sess_id)
            if not inv:
                return False, f"Reviewer '{r}' session '{sess_id}' is not verified in trusted invocation registry."
            if inv.terminal_status != "SUCCEEDED":
                return False, f"Reviewer '{r}' invocation '{inv.invocation_id}' terminal status is '{inv.terminal_status}', not SUCCEEDED."
            if not allow_mock and inv.provider in ("MOCK", "SIMULATED_MOCK", "MOCK_SIMULATED"):
                return False, f"Reviewer '{r}' used mock provider; live AI verification required."

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
