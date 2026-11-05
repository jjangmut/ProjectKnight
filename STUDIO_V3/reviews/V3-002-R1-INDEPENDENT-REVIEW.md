# V3-002-R1 Independent Review — FIX_REQUIRED

Reviewed implementation: `studio/v3-002-agent-orchestrator-r1@67e60384c920c03e9b7d9dc730bd939a56b77f21`.
Basis: GitHub source, V3-002-R1 saved transcripts/manifest/reports. No independent access to user's Windows machine or rerun of local tests.

## Confirmed progress
- Implementation branch exists, containing added code and 5 separate reported native subagent session transcripts.
- Submitted records describe a health-component defect, QA rejection, remediation, QA 9/9 PASS and Director signoff.
- Source now includes SHA256 file manifests, SQLite CAS versions, FileLock/leases and an adapter-dispatch code path.
- 20/20 is **reported**, not rerun independently.

## BLOCKER A — Native live agent sequence is not wired to Producer's Python dispatcher (P0)
`dispatcher.py::execute_autonomous_loop` supports real `adapter.dispatch` but the recorded 5-session workflow appears to have been orchestrated manually inside Antigravity. The provided evidence does not show one Producer entrypoint invoking those 5 agents via the implemented TaskDispatcher and recording real ExecutionRecords through it.

The Python adapter's installed fallback is `agentapi.bat new-conversation`, which explicitly returns `AGENT_COMPLETION_NOT_VERIFIED` with no submitted evidence. No native-subagent bridge is present in the Python `AgentAdapter` classes. An IDE subagent transcript alone proves invocation, not that the new dispatcher automatically controls it.

**Required:** A single supported Producer entrypoint drives and records real worker/reviewer invocations, completion, issue/rework state transitions, commits, and two-key approval; demonstrate exported queue/event records from that exact run. If native IDE tool cannot be called from Python, implement a supported IDE-hosted bridge or declare operator-mediated orchestration and keep live autonomous gate NOT VERIFIED.

## BLOCKER B — CLI permits forged independent approval (P0)
`orchestrator/cli.py` accepts `--actor`, `--session-id`, `--invocation-id` from any caller and even invents random operator session IDs when omitted; it then submits a verdict with `provider="OPERATOR_CLI"`.

`policies.py::verify_reviewer_attestation` checks role string, nonempty session, reviewed commit/iteration; it does **not** check session against trusted provider invocation registry. `can_approve` accepts any two distinct nonempty session strings; `review_task` defaults `worker_session_id=None`. Thus two CLI calls carrying role labels and dummy distinct session IDs can still approve if valid files exist, despite claim of authenticated identity.

**Required:** Actual provider-origin attestations keyed to run ID/task/role/SHA, immutable registry of invocation sessions and shared worker session exclusion; interactive/manual approval must be a separate explicit mode and must not count as AI independent signoff. Add a negative test that performs two forged CLI approvals and asserts they do not approve.

## BLOCKER C — Autonomous loop treats successful process as review PASS (P0)
`dispatcher.py` builds `ReviewVerdict(result="PASS" if rev_record.status == ExecutionStatus.SUCCEEDED else "FIX_REQUIRED")`. SUCCEEDED means invocation finished, NOT that reviewer found acceptable quality. There is no parser validating reviewer-declared PASS/FIX_REQUIRED, issue details, evidence manifest or reviewed SHA. A worker completion with no evidence also fails at submission, and unknown/unverified completion is not explicitly rejected in the worker failure condition (only FAILED/TIMED_OUT).

**Required:** Parse structured signed/attested reviewer verdicts and defect reports, verify actual work SHA, require SUCCEEDED + manifest + validated reviewer verdict, reject UNKNOWN/SESSION_CREATED/AGENT_COMPLETION_NOT_VERIFIED/CANCELLED/no-evidence. Any malformed or absent verdict must remain NOT VERIFIED rather than implied PASS.

## MAJOR D — Concurrency/evidence provenance incomplete (P1)
- `queue_store.claim_task_lease` permits a second claimant using the same actor role while lease is live; actor string is not a unique run claim token.
- `start_task` claims lease before validating dependencies/branch and does not release the lease on validation errors.
- Evidence manifest is hashed locally at submission but `submit_work` supplies current checkout SHA, not a verified worker-produced commit; local evidence can be uncommitted.
- `queue.json` still says `V3-002 IN_REVIEW`, `V3-001 READY`, `V3-003 BLOCKED`, which is correct; fixture Director APPROVED is not V3-002 approval.

**Required:** unique lease token/owner process ID, safe rollback/release on failure, verified worktree and task-specific immutable submitted SHA, check Git object existence and file membership, transactional CAS at dispatch, two-process race test.

## MAJOR E — Hygiene and reporting (P2)
New `__pycache__/*.pyc` binaries are committed in R1; delete tracked caches, update ignore rules. Report "2 worker iterations + Director final review", rather than "three improvement cycles" where relevant.

## Decision
- Real distinct native subagent sessions **EVIDENCE PRESENT**, not independently reenacted.
- Fixture functional QA report **PRESENT**; full command/run provenance not independently reproduced.
- Real Python-driven autonomous quality loop **NOT VERIFIED**.
- Genuine identity-backed two-key policy **FAIL**.
- Reviewer verdict semantic handling **FAIL**.
- Overall **V3-002-R1 FIX_REQUIRED**. Keep `V3-003 BLOCKED`; `V3-001` can continue independently.

Request an R2 with these blockers resolved and separate raw evidence from a single entrypoint.
