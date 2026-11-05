# TASK V3-002-R3-PATCH — Production Approval Gate Hardening

**Priority:** P0 | **Status:** READY, not executed
**Parent task:** V3-002 (FIX_REQUIRED) | **Source:** V3-002-R3 implementation (FIX_REQUIRED / independent review)
**Base SHA:** `e298c4d8ed0c7d4ff77bc86b6e096a9e3fd1ab6d`
**Implementation branch:** `studio/v3-002-r3-final-hardening`
**Independent review:** `STUDIO_V3/reviews/V3-002-R3-INDEPENDENT-REVIEW.md`
**Owner:** PK_ClientLead (implementation) under PK_Producer (coordination)
**Reviewers:** independently invoked PK_QALead and PK_GameDirector, then ChatGPT independent code/evidence review

## Purpose and strict scope
Do NOT launch a new R4 architecture, rewrite the dispatcher or reproduce another long fake-score loop. R3 has useful IDE-native Producer → Worker → QA reject → Worker fix → QA retest → Director session evidence. **Keep it.** This task only closes the six independent review findings so the production approval policy can be trusted. Preserve real game scenes, art, balances, `main`, `integration` and historic event data.

R3 fixture `FIXTURE-V3-LIVE-003` being APPROVED does NOT approve the Studio V3 infrastructure itself. After this patch, request a distinct QA+Director review of the **latest infrastructure code SHA**, not the stamina fixture SHA.

## Mandatory setup (first)
1. Fetch and checkout the exact branch; use an isolated worktree, record HEAD, branch, clean/dirty status, Python version, and Godot version.
2. Read `STUDIO_V3/reviews/V3-002-R3-INDEPENDENT-REVIEW.md` and R3 source: `dispatcher.py`, `policies.py`, `queue_store.py`, `runner.py`, `subagent_bridge.py`, `event_log.py`, `schemas.py`, `tests/`.
3. Back up the existing local `STUDIO_V3/queue.db` before migrations. Reconcile `queue.json` without deleting in-flight tasks, reviews, fixture history or issue history. Do not reset the database to force PASS.
4. Run current Python regression suite with raw exit code/stdout/stderr. Save **new** logs, do not cite old 29/29 as a newly executed test.

## Blocker P0-01 — Strict structured reviewer result
**Current bug:** `parse_reviewer_verdict` accepts missing `role`, defaults missing `reviewed_commit_sha` to the current task SHA, and does not require/compare `task_id` and `iteration`.

**Implement:**
- Parse a single exact final JSON object from documented provider result envelope. Do not pick arbitrary text between the first `{` and last `}`; do not accept nested/intermediate or multiple contradictory outputs.
- Required fields: `task_id`, `iteration` (integer), `role`, `reviewed_commit_sha` (40-hex), `verdict` (`PASS|FIX_REQUIRED`), `issues` (array), `evidence_manifest` (array/list per agreed schema).
- Compare task/iteration/role/SHA against the attested session and currently submitted task revision. Never fill missing fields from task state.
- For `FIX_REQUIRED`, require issue ID (or controlled server-side ID), severity, description, reproduction, expected/actual, evidence. For `PASS`, require explicit supporting evidence and no undisclosed P0/P1.
- Fail closed to `REVIEW_INVALID` / `FIX_REQUIRED` on missing, type mismatch, stale target, malformed JSON, contradictory outputs or absent validated final terminal record. Agent process `SUCCEEDED` does NOT mean reviewer `PASS`.

**Negative tests:** `{"verdict":"PASS"}`, missing task_id, wrong iteration, missing role, missing SHA, stale SHA, multiple JSONs, successful process with FIX_REQUIRED, unavailable final result must all be denied.

## Blocker P0-02 — SHA-bound, actually committed artifact verification
**Current bug:** `submit_work(target_commit_sha)` checks object existence but does not verify the working evidence bytes exist in that Git commit.

**Implement:**
- Require explicit full worker-produced commit SHA for live submissions. Verify commit exists, is reachable from the authorized task worktree/branch, and files are within allowed task scope. Reject wrong branch/commit or untrusted caller HEAD.
- For each mandatory committed source evidence: compare repository-relative path + SHA256 against bytes retrieved from exact `git show <sha>:<path>` (or equivalent Git tree blob) and current manifest; reject uncommitted changed contents, different tree blob, nonexistent or out-of-workspace paths.
- Runtime logs/screenshots produced after commit are valid **separate generated evidence**, with generation time/run/session/source SHA and content hash; do NOT falsely require post-run artifacts to exist in a preceding code commit. Require upload/check-in of these artifacts to an evidence commit with explicit linkage to the source SHA.
- Bound worker invocation, task ID, iteration, implementation branch, source commit, evidence commit and both reviewers' verdicts to a single immutable manifest. Reject mismatches and replay.

**Negative tests:** non-existing SHA, valid SHA on unrelated branch, uncommitted source alteration, source path absent from commit, path traversal, old iteration evidence, reviewer on different SHA.

## Blocker P1-03 — Native subagent provenance and anti-replay
- At live dispatch, record `run_id, task_id, iteration, role, verified parent_conversation_id, provider session_id, launch time, target SHA`.
- In `runner.py` and `subagent_bridge.py`, do not allow empty parent to silently skip identity verification in production. Obtain and compare authoritative provider metadata. If the documented runtime cannot provide necessary data, mark `IDENTITY_NOT_VERIFIED` and block live approval; do not invent APIs.
- Never mistake any earlier transcript step marked `DONE` for final task completion. Confirm documented terminal completion and final structured output.
- Registry insert must be immutable; deny a second registration of the *same session*, even for the same task+iteration, except for a separately designed idempotent retry with an identical immutable event key. Do not allow `if get_invocation: skip` to bypass mismatch detection.
- Worker, QA and Director must have distinct verified sessions. Manual/Operator and `MOCK_SIMULATED` must not satisfy production approval.

## Blocker P1-04 — Reproducible test raw logs
- Commit `STUDIO_V3/evidence/V3-002-R3-PATCH/test_logs/python_tests_raw.log` and `godot_tests_raw.log`, plus runner commands, interpreter/engine versions and actual exit codes.
- Confirm actual Python test total from the current run, not the previous report. Re-run Godot fixture and keep its separate exit code.
- Add regression tests for each P0/P1 issue, including an explicit live gate rejection test for `MOCK_SIMULATED` and missing JSON fields.
- Update `source_manifest.json` for the **new actual files** and verify checksums. Do not edit historic raw logs to make counts align.

## Blocker P1-05 — Fully correlated run events
- Propagate one `run_id` to each `TASK_STARTED`, `WORK_SUBMITTED`, `REVIEW_REJECTED`, `TASK_STARTED(rework)`, `REVIEW_PASSED`, `TASK_APPROVED` event for a run; include invocation/session, task/iteration and implementation SHA where applicable.
- Do not rewrite existing append-only `events.jsonl`. Add new events or an explicit correction record referencing any legacy events with empty `parent_run_id`.
- Reject approval if final run's evidence/QA/Director links are inconsistent.

## Blocker P2-06 — Queue, historical status and Producer runbook
- Truthfully correct `V3-002-R2` and `V3-002-R3` statuses on the new patch branch; use a documented correction/migration event, never erase historic evidence.
- Preserve the prior APPROVED fixture history but tag the old R2 fixture's stale lease as historical and reconcile the current queue invariant without changing prior raw logs.
- Ensure `.agents/agents/PK_Producer.md` tells Producer to read `STUDIO_V3/docs/NATIVE_PRODUCER_RUNBOOK.md` and enforce this patch's gates.
- Keep `V3-001` READY (independent baseline task) and `V3-003` BLOCKED until both `V3-001` and parent `V3-002` are APPROVED.
- Do not use fixture approval as proof that the orchestration infrastructure is approved.

## End-to-end demonstration (bounded, no game modifications)
1. Run strict-schema/commit-provenance/anti-replay/concurrency negative tests.
2. Use a harmless fixture for **one** supported Antigravity IDE-native Producer sequence. Reuse existing verified mechanics if safe; do not create an elaborate new project/feature.
3. From one initial Producer task, launch worker, QA, worker fix, QA retest and Director using documented native IDE calls; ensure trace records **launch**, not merely session import.
4. Store provider attestation and exact SHA evidence. Deliberately challenge the gate with one incomplete PASS JSON and one dirty/uncommitted source file; both must be rejected.
5. Validate exact committed SHA with independent QA and Director. Confirm APPROVED clears lease, and no unresolved P0/P1 remains **for the fixture**.
6. Submit the infrastructure patch's final Git commit separately for independent QA+Director and ChatGPT review, without self-approval.

## Acceptance checklist
- [ ] Incomplete `{"verdict":"PASS"}` is rejected.
- [ ] Task/iteration/role/review SHA and explicit final verdict mandatory.
- [ ] Git-committed code bytes match submitted SHA256/manifest.
- [ ] Post-commit runtime logs have explicit provenance and evidence-commit association.
- [ ] Real verified parent/session provenance; duplicate/replay denied.
- [ ] Mock/manual results cannot authorize production `APPROVED`.
- [ ] R3-PATCH test scripts + **raw logs** available on remote GitHub and reproducible.
- [ ] Every new run event has same run_id; approved task has no lease.
- [ ] `V3-002-R3-PATCH` reviewed independently against **its actual latest SHA**.
- [ ] No `CLIENT/Game/`, main or integration changes.

## Deliverables
```
STUDIO_V3/tasks/V3-002-R3-PATCH.md
STUDIO_V3/reviews/V3-002-R3-INDEPENDENT-REVIEW.md
STUDIO_V3/orchestrator/{dispatcher,policies,queue_store,runner,event_log,...}.py
STUDIO_V3/tests/test_r3_patch_*.py
STUDIO_V3/evidence/V3-002-R3-PATCH/
  test_logs/{python_tests_raw,godot_tests_raw}.log
  live_native_run/
  evidence_manifest.json
  FINAL_EXECUTION_REPORT.md
STUDIO_V3/queue.json
STATE.md
.agents/agents/PK_Producer.md
```

## Final report (no self-approval)
```
TASK: V3-002-R3-PATCH
Implementation branch / HEAD: ...
Python tests: N/N; raw log + exit code ...
Godot tests: N/N; raw log + exit code ...
Strict JSON rejection: PASS/FAIL
SHA-committed evidence: PASS/FAIL
Parent/session/role verification: PASS/FAIL/NOT VERIFIED
Mock/manual production approval exclusion: PASS/FAIL
Run-wide event linkage: PASS/FAIL
Live native IDE Producer chain: VERIFIED/NOT VERIFIED (not Python standalone)
Fixture independent QA/Director: VERIFIED/NOT VERIFIED
Infrastructure independent QA/Director: REQUESTED/VERIFIED/NOT VERIFIED
Open P0/P1: ...
Status: INDEPENDENT_REVIEW_REQUESTED / FIX_REQUIRED
```

**Do not automatically merge or mark V3-002 APPROVED.** Stop after bounded cycles if verification is not possible; report blockers honestly.

## Execute now
PK_Producer: fetch `studio/v3-002-r3-final-hardening`, read this task + independent R3 review, assign the scoped changes to PK_ClientLead, run the real independent QA/Director sequence, commit/push source and actual evidence, then submit the implementation SHA for review. Keep `V3-003` blocked.
