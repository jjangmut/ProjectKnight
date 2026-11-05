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
    InvocationRecord,
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
    verify_commit_exists,
    verify_commit_on_branch,
    verify_committed_source_evidence,
    PolicyViolation,
    EvidenceMissingError,
    EvidenceTamperedError,
    StaleEvidenceError,
    SelfApprovalBlockedError,
    IdentityVerificationError,
    UntrustedSessionError,
    StaleReviewError,
    DependencyBlockedError,
    TaskLeaseConflictError,
    ConcurrentModificationError,
)
from .adapters.base import AgentAdapter


class TaskDispatcher:
    """Manages task scheduling, agent execution, cryptographic evidence gates, and the autonomous quality rework loop."""

    def __init__(
        self,
        queue_store: QueueStore,
        event_log: EventLog,
        repo_root: Path,
        allow_mock: bool = False,
    ):
        self.queue_store = queue_store
        self.event_log = event_log
        self.repo_root = repo_root.resolve()
        self.allow_mock = allow_mock
        self.current_run_id: str = ""

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

    def start_task(self, task_id: str, actor: str, claim_token: str = "") -> Task:
        """Producer/Worker transition: READY/FIX_REQUIRED -> IN_PROGRESS with lease locking."""
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        # 1. Enforce branch safety if active branch is set
        if task.active_branch:
            validate_branch_safety(task.active_branch)

        # 2. Validate start conditions (status, dependencies, owner) BEFORE claiming lease
        all_tasks = self.queue_store.load_all_tasks()
        validate_start(task, actor, all_tasks)

        # 3. Claim task lease with unique token to prevent duplicate runs
        if claim_token:
            self.current_run_id = claim_token
        lease_token = claim_token or self.current_run_id or f"lease-{actor}-{task.id}"
        if not self.current_run_id:
            self.current_run_id = lease_token

        self.queue_store.claim_task_lease(task_id, actor=actor, claim_token=lease_token)

        # Refresh task from store so in-memory object has the active lease
        refreshed = self.queue_store.get_task(task_id)
        if refreshed:
            task = refreshed

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
            parent_run_id=self.current_run_id,
            commit_sha=sha,
            details={"iteration": task.iteration, "status": task.status.value, "version": task.version, "claim_token": lease_token},
        )
        return task

    def submit_work(
        self,
        task_id: str,
        actor: str,
        evidence_paths: List[str],
        invocation_id: str = "",
        target_commit_sha: Optional[str] = None,
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
        if target_commit_sha and target_commit_sha != current_sha:
            verify_commit_exists(target_commit_sha, self.repo_root)
            if task.active_branch:
                verify_commit_on_branch(target_commit_sha, task.active_branch, self.repo_root)
            current_sha = target_commit_sha
        else:
            verify_commit_exists(current_sha, self.repo_root)
            if task.active_branch:
                verify_commit_on_branch(current_sha, task.active_branch, self.repo_root)
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

        # Verify that committed source evidence exists in current_sha without uncommitted changes
        verify_committed_source_evidence(manifest, current_sha, self.repo_root)

        task.evidence_manifest = manifest
        task.evidence = [m.file_path for m in manifest]
        task.status = TaskState.IN_REVIEW
        self.queue_store.save_task(task)

        self.event_log.record_event(
            event_type="WORK_SUBMITTED",
            task_id=task.id,
            actor=actor,
            parent_run_id=self.current_run_id,
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
        allow_mock: Optional[bool] = None,
    ) -> Task:
        """Reviewer transition: IN_REVIEW -> FIX_REQUIRED or APPROVED with identity attestation."""
        use_mock = self.allow_mock if allow_mock is None else allow_mock
        task = self.queue_store.get_task(task_id)
        if not task:
            raise ValueError(f"Task {task_id} not found.")

        if task.status != TaskState.IN_REVIEW:
            raise PolicyViolation(f"Task {task.id} is in status '{task.status.value}', must be IN_REVIEW to conduct review.")

        # 1. Cryptographic and Session Identity Attestation against Invocation Registry
        verify_reviewer_attestation(
            verdict,
            task,
            worker_session_id=worker_session_id,
            invocation_registry=self.queue_store,
            allow_mock=use_mock,
        )

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
                parent_run_id=self.current_run_id,
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
            can_appr, reason = can_approve(task, invocation_registry=self.queue_store, allow_mock=use_mock)
            if can_appr:
                task.status = TaskState.APPROVED
                # Explicitly clear lease upon approval
                old_lease = task.lease_owner
                task.lease_owner = None
                task.lease_expires_at = None
                self.queue_store.release_task_lease(task.id, actor=task.owner, claim_token=old_lease)
                self.queue_store.save_task(task)
                self.event_log.record_event(
                    event_type="TASK_APPROVED",
                    task_id=task.id,
                    actor=verdict.agent_role,
                    provider=verdict.provider,
                    parent_run_id=self.current_run_id,
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
                    parent_run_id=self.current_run_id,
                    commit_sha=sha,
                    verdict="PASS",
                    evidence_paths=[m.file_path for m in task.evidence_manifest],
                    details={"iteration": task.iteration, "pending_reason": reason, "session_id": verdict.session_id},
                )
        else:
            raise ValueError(f"Invalid review result '{verdict.result}', must be PASS or FIX_REQUIRED.")

        return task

    def is_worker_execution_acceptable(self, worker_record: ExecutionRecord) -> bool:
        """Check whether worker execution finished successfully and produced verified deliverables."""
        return worker_record.status == ExecutionStatus.SUCCEEDED

    def parse_reviewer_verdict(self, rev_record: ExecutionRecord, task: Task) -> ReviewVerdict:
        """Parse and semantically validate structured reviewer output payload into ReviewVerdict."""
        if rev_record.status != ExecutionStatus.SUCCEEDED:
            raise PolicyViolation(
                f"Reviewer '{rev_record.agent_id}' execution did not complete with SUCCEEDED (actual: {rev_record.status.value}): {rev_record.error}"
            )

        text = rev_record.output_text.strip()
        if not text:
            raise PolicyViolation(f"Reviewer '{rev_record.agent_id}' output is empty. Structured JSON required.")

        import json
        import re

        # Extract structured JSON payloads from code blocks
        code_block_matches = re.findall(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
        parsed_payloads = []
        if code_block_matches:
            for cb in code_block_matches:
                try:
                    obj = json.loads(cb)
                    if isinstance(obj, dict) and "verdict" in obj:
                        parsed_payloads.append(obj)
                except Exception:
                    pass

        # If no code block found or no verdict in code blocks, scan text for top-level JSON objects
        if not parsed_payloads:
            decoder = json.JSONDecoder()
            idx = 0
            while idx < len(text):
                pos = text.find("{", idx)
                if pos == -1:
                    break
                try:
                    obj, end_pos = decoder.raw_decode(text[pos:])
                    if isinstance(obj, dict) and "verdict" in obj:
                        parsed_payloads.append(obj)
                    idx = pos + max(1, end_pos)
                except Exception:
                    idx = pos + 1

        if not parsed_payloads:
            raise PolicyViolation(
                f"Reviewer '{rev_record.agent_id}' did not return a parseable structured JSON verdict payload. Raw output: {text[:200]}"
            )

        # Reject multiple contradictory or ambiguous JSON payloads
        if len(parsed_payloads) > 1:
            first_v = parsed_payloads[0].get("verdict")
            first_tid = parsed_payloads[0].get("task_id")
            first_iter = parsed_payloads[0].get("iteration")
            for other in parsed_payloads[1:]:
                if (
                    other.get("verdict") != first_v
                    or other.get("task_id") != first_tid
                    or other.get("iteration") != first_iter
                ):
                    raise PolicyViolation(
                        f"Multiple contradictory structured JSON payloads detected in output from reviewer '{rev_record.agent_id}'."
                    )

        payload = parsed_payloads[-1]  # The definitive final payload

        # 1. MANDATORY: task_id
        if "task_id" not in payload:
            raise PolicyViolation("Reviewer payload missing mandatory 'task_id' field.")
        if payload["task_id"] != task.id:
            raise PolicyViolation(
                f"Reviewer payload task_id '{payload['task_id']}' does not match target task '{task.id}'."
            )

        # 2. MANDATORY: iteration (must be int and match task.iteration)
        if "iteration" not in payload:
            raise PolicyViolation("Reviewer payload missing mandatory 'iteration' field.")
        if not isinstance(payload["iteration"], int):
            raise PolicyViolation(
                f"Reviewer payload iteration must be an integer, got {type(payload['iteration']).__name__}."
            )
        if payload["iteration"] != task.iteration:
            raise StaleReviewError(
                f"Reviewer targeted iteration {payload['iteration']}, but current task iteration is {task.iteration}."
            )

        # 3. MANDATORY: role
        if "role" not in payload:
            raise PolicyViolation("Reviewer payload missing mandatory 'role' field.")
        req_role = payload["role"]
        if req_role != rev_record.agent_id:
            raise PolicyViolation(
                f"Reviewer role mismatch: payload declared '{req_role}', adapter dispatched '{rev_record.agent_id}'."
            )
        if req_role not in task.reviewers:
            raise PolicyViolation(
                f"Reviewer role '{req_role}' is not in designated task reviewers list {task.reviewers}."
            )

        # 4. MANDATORY: reviewed_commit_sha (NEVER default to task.current_commit_sha!)
        if "reviewed_commit_sha" not in payload or not payload["reviewed_commit_sha"]:
            raise PolicyViolation(
                "Reviewer payload missing mandatory 'reviewed_commit_sha'. Automatic fallback is forbidden."
            )
        target_sha = str(payload["reviewed_commit_sha"]).strip()
        if task.current_commit_sha and target_sha.lower() != task.current_commit_sha.lower():
            raise StaleReviewError(
                f"Review targeted commit '{target_sha}', but current task commit is '{task.current_commit_sha}'."
            )

        # 5. MANDATORY: verdict
        if "verdict" not in payload:
            raise PolicyViolation("Reviewer payload missing mandatory 'verdict' field.")
        verdict_str = str(payload["verdict"]).upper().strip()
        if verdict_str not in ("PASS", "FIX_REQUIRED"):
            raise PolicyViolation(
                f"Invalid verdict '{verdict_str}' in reviewer payload; must be 'PASS' or 'FIX_REQUIRED'."
            )

        # 6. MANDATORY: issues (must be list)
        if "issues" not in payload or not isinstance(payload["issues"], list):
            raise PolicyViolation("Reviewer payload missing mandatory 'issues' array.")

        issues: List[Issue] = []
        if verdict_str == "FIX_REQUIRED":
            if not payload["issues"]:
                raise PolicyViolation("Reviewer declared FIX_REQUIRED but provided zero structured issues.")
            for idx, raw_i in enumerate(payload["issues"]):
                if not isinstance(raw_i, dict):
                    raise PolicyViolation(f"Issue item at index {idx} is not a valid dictionary object.")
                iss_id = raw_i.get("id") or f"ISS-{task.id}-{task.iteration}-{idx+1}"
                sev_str = str(raw_i.get("severity", "P1")).upper()
                if sev_str not in Severity._value2member_map_:
                    sev_str = "P1"
                title = raw_i.get("title") or raw_i.get("description") or "Reviewer Reported Defect"
                steps = raw_i.get("reproduction_steps") or raw_i.get("steps") or "See review report"
                expected = raw_i.get("expected") or "Compliant deliverable"
                actual = raw_i.get("actual") or "Defect observed"
                evidence = raw_i.get("evidence") or []
                if isinstance(evidence, str):
                    evidence = [evidence]
                issues.append(Issue(
                    id=iss_id,
                    task_id=task.id,
                    iteration=task.iteration,
                    severity=Severity(sev_str),
                    title=str(title),
                    reproduction_steps=str(steps),
                    expected=str(expected),
                    actual=str(actual),
                    evidence=evidence,
                ))
        elif verdict_str == "PASS":
            # Check that issues list has no unresolved P0 or P1
            for raw_i in payload["issues"]:
                if isinstance(raw_i, dict):
                    sev = str(raw_i.get("severity", "")).upper()
                    if sev in ("P0", "P1") and raw_i.get("status", "OPEN") != "RESOLVED":
                        raise PolicyViolation(
                            f"Reviewer declared PASS but included open blocking issue '{raw_i.get('id', 'unknown')}' ({sev})."
                        )

        # 7. MANDATORY: evidence_manifest (must be list)
        if "evidence_manifest" not in payload and "evidence" not in payload:
            if verdict_str == "PASS":
                raise PolicyViolation("Reviewer payload missing mandatory 'evidence_manifest' array.")

        raw_ev = payload.get("evidence_manifest", payload.get("evidence", []))
        if not isinstance(raw_ev, list):
            raise PolicyViolation("Reviewer payload 'evidence_manifest' must be an array.")

        if verdict_str == "PASS" and not raw_ev and not rev_record.evidence_manifest:
            raise PolicyViolation("Reviewer declared PASS but provided empty evidence_manifest. Evidence required.")

        evidence_paths = [
            e if isinstance(e, str) else e.get("file_path", "")
            for e in raw_ev
            if (isinstance(e, str) and e) or (isinstance(e, dict) and e.get("file_path"))
        ]
        if not evidence_paths:
            evidence_paths = [m.file_path for m in rev_record.evidence_manifest]

        return ReviewVerdict(
            task_id=task.id,
            iteration=task.iteration,
            agent_role=rev_record.agent_id,
            provider=rev_record.provider,
            invocation_id=rev_record.invocation_id,
            session_id=rev_record.session_id,
            reviewed_commit_sha=target_sha,
            result=verdict_str,
            evidence_paths=evidence_paths,
            issues=issues,
            notes=payload.get("notes", ""),
        )


    def execute_autonomous_loop(
        self,
        task_id: str,
        adapter: AgentAdapter,
        worker_action: Optional[Callable[[Task, int, AgentAdapter], Tuple[List[str], ExecutionRecord]]] = None,
        reviewer_evaluators: Optional[Dict[str, Callable[[Task, int, AgentAdapter, ExecutionRecord], ReviewVerdict]]] = None,
        max_cycles: int = 3,
    ) -> Dict[str, Any]:
        """
        Executes the autonomous quality loop using the provided adapter.
        Producer -> Worker (via adapter) -> Submit (with SHA256 manifest) ->
        QA (via adapter) -> (if reject: Issue -> Worker fix -> QA retest) ->
        Director (via adapter) -> Approval.
        """
        audit_history: List[Dict[str, Any]] = []

        # Probe adapter before launch
        probe_res = adapter.probe()
        is_mock = probe_res.get("mock", False)
        execution_tag = "MOCK_TEST_PASS" if is_mock else "REAL_AGENT_INVOKED"

        if (worker_action or reviewer_evaluators) and not is_mock:
            raise PolicyViolation(
                "Direct Python callback injection (worker_action/reviewer_evaluators) is restricted to "
                "isolated mock tests; real autonomous loops must dispatch through real adapters."
            )

        import uuid
        run_id = f"run-{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"

        for cycle_idx in range(1, max_cycles + 1):
            task = self.queue_store.get_task(task_id)
            if not task:
                raise ValueError(f"Task {task_id} not found.")

            if task.status == TaskState.APPROVED:
                break

            # 1. Start task with unique run token lease
            self.start_task(task.id, actor=task.owner, claim_token=run_id)
            cycle_meta = {
                "run_id": run_id,
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

            # Register worker invocation in trusted registry
            self.queue_store.register_invocation(InvocationRecord(
                invocation_id=worker_record.invocation_id,
                run_id=run_id,
                task_id=task.id,
                iteration=task.iteration,
                role=task.owner,
                provider=worker_record.provider,
                session_id=worker_record.session_id,
                worktree=str(self.repo_root),
                branch=task.active_branch,
                target_commit_sha=task.current_commit_sha,
                started_at=worker_record.start_time,
                completed_at=worker_record.end_time,
                terminal_status=worker_record.status.value,
                result_hash=worker_record.evidence_manifest[0].sha256 if worker_record.evidence_manifest else "",
                output_text=worker_record.output_text,
                error=worker_record.error,
            ))

            cycle_meta["worker_execution"] = worker_record.to_dict()

            # Worker acceptability check: only SUCCEEDED is allowed to proceed to submission
            if not self.is_worker_execution_acceptable(worker_record):
                cycle_meta["final_task_status"] = worker_record.status.value
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
                    # Register evaluator invocation in trusted registry for mock testing
                    self.queue_store.register_invocation(InvocationRecord(
                        invocation_id=verdict.invocation_id,
                        run_id=run_id,
                        task_id=task.id,
                        iteration=task.iteration,
                        role=reviewer,
                        provider=verdict.provider,
                        session_id=verdict.session_id,
                        worktree=str(self.repo_root),
                        branch=task.active_branch,
                        target_commit_sha=task.current_commit_sha,
                        started_at=verdict.timestamp,
                        completed_at=verdict.timestamp,
                        terminal_status="SUCCEEDED",
                        result_hash="",
                        output_text="",
                        error=None,
                    ))
                else:
                    # Direct review dispatch
                    rev_prompt = f"Review Task {task.id} (Commit: {task.current_commit_sha})."
                    rev_record = adapter.dispatch(
                        task_id=task.id,
                        role=reviewer,
                        prompt=rev_prompt,
                        worktree=str(self.repo_root),
                    )
                    self.queue_store.register_invocation(InvocationRecord(
                        invocation_id=rev_record.invocation_id,
                        run_id=run_id,
                        task_id=task.id,
                        iteration=task.iteration,
                        role=reviewer,
                        provider=rev_record.provider,
                        session_id=rev_record.session_id,
                        worktree=str(self.repo_root),
                        branch=task.active_branch,
                        target_commit_sha=task.current_commit_sha,
                        started_at=rev_record.start_time,
                        completed_at=rev_record.end_time,
                        terminal_status=rev_record.status.value,
                        result_hash="",
                        output_text=rev_record.output_text,
                        error=rev_record.error,
                    ))
                    # Parse structured verdict
                    verdict = self.parse_reviewer_verdict(rev_record, task)

                task = self.review_task(
                    task.id,
                    verdict=verdict,
                    worker_session_id=worker_record.session_id,
                    allow_mock=is_mock,
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
            "run_id": run_id,
            "task_id": task_id,
            "final_status": final_task.status.value if final_task else "UNKNOWN",
            "iterations_run": len(audit_history),
            "approved": approved,
            "execution_mode": "MOCK" if is_mock else "REAL_AGENT",
            "cycles": audit_history,
        }

