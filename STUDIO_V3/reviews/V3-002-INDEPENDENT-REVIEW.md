# V3-002 Independent Code and Evidence Review — 2026-11-04

**Reviewed commit:** `c4a49ad3246f3e5709f833ae095646ddf54c2b44`
**Review scope:** pushed source, test files, saved runtime manifests/transcripts, queue and report. No direct access to the user's Windows runtime; did not run Godot or Antigravity independently.
**Status:** **FIX_REQUIRED — DO NOT APPROVE V3-002**
**Source task:** `STUDIO_V3/tasks/V3-002.md`

## Summary: confirmed / unsupported

- Confirmed: branch is pushed, six `.agents/agents/PK_*.md` are added, SQLite-backed workflow + 17 reported test cases exist, real-looking separate native Antigravity QA/Director transcripts with distinct conversation IDs are stored.
- Confirmed: `agy` CLI is unavailable on host per `runtime_probe/audit_report.md`; `agentapi.bat` was accessible and conversation metadata was created.
- Not established: Python TaskDispatcher automatically launches an actual worker or reviewer, observes their completed execution, parses real output and resolves a real issue via independent agent follow-up.
- Mock-only: the recorded reject/fix/retest fixture. The fixture events explicitly say `provider:"LOCAL"`; tests use `MockAdapter` and in-process Python callables.
- Current queue correctly stays `V3-002: IN_REVIEW`, `V3-001: READY`, `V3-003: BLOCKED`. No actual two-key V3-002 review has been entered.

## BLOCKER 01 — No live adapter use in autonomous loop (P0)

**Files:** `STUDIO_V3/orchestrator/dispatcher.py` (`execute_autonomous_loop`), `STUDIO_V3/tests/test_dispatcher.py`.

The method receives `adapter: AgentAdapter`, but never calls `adapter.probe()`, `adapter.dispatch()`, `adapter.observe()` or `adapter.cancel()`. It invokes `worker_action(task, cycle_idx)` and `reviewer_evaluators[reviewer](task, cycle_idx)` as local Python functions. The passing test writes its own evidence files and returns its own verdicts without invoking any Antigravity agent. This **does not implement autonomous agent dispatch or independent AI review**.

**Fix:** Connect actual `dispatch` + execution confirmation + evidence parsing for the worker, QA reviewer, Director. Persist unique provider invocation IDs, independent sessions and review output in the real audit log. Keep the mock adapter for deterministic tests only. Test a non-mock integration run from a single Producer launch.

## BLOCKER 02 — AgentAPI adapter equates conversation creation with work completion (P0)

**File:** `STUDIO_V3/orchestrator/adapters/antigravity_cli.py`.

When `agy` is unavailable, `dispatch` runs `agentapi.bat new-conversation "[role] prompt"`, checks only `returncode == 0` and returns `SUCCESS` immediately. Conversation **creation** is not proof the agent completed its task; no wait/poll for terminal result, no validated output, no evidence paths, no confirmed commit SHA, no reviewer identity. `observe` and `cancel` rely on `_active_processes` but `dispatch` never populates that dictionary. Hence real running processes cannot be observed or canceled by those methods.

`probe()` also returns `native_subagents_supported=True` unconditionally and does not verify role discovery. In the hypothetical CLI path, `SUCCESS` is based on process return code without checking response JSON status or session ID.

**Fix:** Separate `SESSION_CREATED` from `RUNNING` / `SUCCEEDED`; confirm actual AgentAPI response/completion (or explicitly report unsupported), parse provider status, capture output and provider/session IDs, implement observation/cancellation or mark them unavailable, and validate CLI JSON status if CLI is installed. Fail closed on missing result or capability.

## BLOCKER 03 — Reviewer identity is only a caller-supplied string (P1)

**Files:** `STUDIO_V3/orchestrator/cli.py`, `dispatcher.py`, `policies.py`.

The CLI accepts arbitrary `--actor PK_QALead` / `--actor PK_GameDirector`. `review_task` compares that text with task role strings, not authenticated provider invocation metadata. Anyone able to invoke the CLI can submit PASS under both identities by supplying existing local review files, making two-key approval a **role-name check**, not an independently verified agent approval.

**Fix:** Bind each reviewer verdict to an authenticated/verified, task-scoped invocation result (provider, unique session, role, task ID, iteration, commit/evidence digest). Reject duplicate sessions and owner/reviewer session reuse; separate manual human approvals explicitly. Preserve CLI as an operator interface but do not treat actor text as identity attestation.

## MAJOR 04 — Evidence gate only checks file existence (P1)

**File:** `STUDIO_V3/orchestrator/policies.py` (`verify_evidence_files`).

It accepts any existing file, including files outside the repository, with no checked-in revision, content hash, provenance, timestamp, task or iteration binding. `review_task` does not compare evidence SHA to the implementation under review. A stale fixture report can therefore satisfy the current gate.

**Fix:** Track manifest with `task_id`, iteration, role, provider invocation, commit_sha, branch, content SHA256, paths and verification method. Validate no stale/changed evidence and reject missing/cross-task data. Actual screenshots/test logs must be produced after the relevant code revision and linked to it.

## MAJOR 05 — "3-cycle live" claim is incorrect (P1)

**Files:** `STUDIO_V3/tests/test_dispatcher.py`, `STUDIO_V3/evidence/V3-002/review_loop/fixture_events.jsonl`.

The fixture has **two worker iterations**, not three: iteration 1 is rejected, iteration 2 is accepted by QA and Director. The test explicitly asserts `iterations_run == 2`. File `cycle_3_director_pass.md` is a third *labelled approval stage*, not a third worker improvement cycle. More importantly, this is **simulated**, not a live Antigravity reject/fix/retest loop.

**Fix:** Rename the test and report to “2-iteration mock rejection and approval”; separately run and evidence the real provider loop. No inflated claims.

## MAJOR 06 — Job/snapshot concurrency guards not wired (P1)

**Files:** `dispatcher.py`, `queue_store.py`, `event_log.py`.

Task state transitions read `get_task` and later write `save_task` without compare-and-swap/version checks across processes. SQLite's individual writes are transactional, but the task decision itself is not atomic. JSON snapshot is overwritten directly outside transaction and event log append has no explicit cross-process locking. `validate_branch_safety` exists but is not called by the dispatch path. These do not provide the promised prevention of concurrent branch writes or duplicate jobs.

**Fix:** Atomic state transition with expected status/version, claim/lease mechanism, isolated worktrees and branch ownership validation in dispatcher; atomic temp-file + rename snapshot with lock; idempotent event keys. Add concurrent-start, duplicate-submit and recovery-after-interruption tests.

## Required R1 demonstration (no game changes)

1. Actual Producer entrypoint launches one real worker on a throwaway fixture through the installed Antigravity runtime; capture provider invocation + completion (not just session created).
2. Real independent QA invocation rejects the deliberately broken fixture and creates a structured issue.
3. Producer dispatches **another** worker invocation; worker commits a concrete fix.
4. Real QA runs again and verifies the new output against expected behavior.
5. Real Director independently reviews the final exact SHA; only then two-key approval.
6. Demonstrate cancellation/timeouts and fail-closed response handling; test no session/role spoofing.
7. Two simultaneous launches of the same task cannot create double writers, double issue or false APPROVED.
8. Run all current unit tests and new integration/negative tests. Preserve raw sanitized logs and reproducible commands.

If agentapi cannot provide a completion signal or custom-agent role attestation, the honest result is `LIVE_AUTONOMOUS_LOOP_NOT_VERIFIED`; use an operator-mediated fallback until an officially supported interface is proven.

## Result and next action

- `V3-002 — IMPLEMENTATION_PRESENT`
- `V3-002 — REPORTED_UNIT_TESTS 17/17 (not independently rerun)`
- `NATIVE_SUBAGENT_SESSION_EVIDENCE — PRESENT`
- `REAL_ORCHESTRATED_WORKER → QA REJECT → FIX → QA + DIRECTOR — NOT VERIFIED`
- `V3-002 — FIX_REQUIRED (independent review)`
- Keep `V3-003 BLOCKED`. V3-001 independent baseline audit may run in parallel.

Implementation branch must incorporate fixes and request fresh review. Do not mark the task APPROVED based on this report.
