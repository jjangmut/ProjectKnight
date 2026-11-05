# TASK V3-002-CLOSE — Final Approval Gate Closure (No R4 Rebuild)

**Priority:** P0 — closure only  
**Status:** READY (instruction registered; implementation NOT started)  
**Parent:** V3-002 (still FIX_REQUIRED)  
**Working branch:** `studio/v3-002-closure-patch`  
**Implementation base:** `studio/v3-002-r3-final-hardening@0b5bb54db44f45db17b09ee1435c7e1640c7f4c8`  
**Authoritative independent findings:** `STUDIO_V3/reviews/V3-002-R3-PATCH-INDEPENDENT-REVIEW.md`  
**Coordinator:** PK_Producer in Antigravity IDE  
**Implementation owner:** PK_ClientLead  
**Independent reviewers:** PK_QALead and PK_GameDirector, with external ChatGPT code/evidence check

## Mission — finish, don't redesign

Close **exactly four remaining independent-review findings** and submit the real Studio V3 infrastructure source revision for independent approval. Do **not** start R4, add new agent roles, recreate the stamina fixture, or launch another broad multi-agent platform project. The earlier IDE-native 5-session Worker → QA rejection → Worker fix → QA retest → Director evidence remains valid *for that fixture only*. New review is required for **the infrastructure patch itself**.

We are not trying to prove Python can run Antigravity IDE subagents headlessly. The accepted architecture is an IDE-native Producer calling supported subagents, with Python controlling queue, provenance, tests, and reviews. Standalone Python session ingestion is never called autonomous subagent creation.

## Gate 0 — verify baseline

1. Fetch checkout `studio/v3-002-closure-patch` from remote in a safe worktree. Do not edit `main`, `integration`, or `CLIENT/Game/`.
2. Read `STUDIO_V3/reviews/V3-002-R3-PATCH-INDEPENDENT-REVIEW.md`, `STUDIO_V3/tasks/V3-002-R3-PATCH.md`, `STUDIO_V3/PROTOCOL.md`, and the existing Producer runbook.
3. Run the existing test suite **before editing** with raw stdout, stderr, exit code and interpreter/Godot versions. Preserve prior historic logs unmodified.
4. Back up the local SQLite `queue.db` if present. Reconcile statuses non-destructively and record before/after; never wipe prior issues or sessions to obtain a PASS.
5. Reproduce the four findings with failing negative tests. Record them as baseline.

## P0-01 — production Git verification MUST fail closed

Files: `STUDIO_V3/orchestrator/policies.py`, relevant tests; callers in `dispatcher.py`.

Current issues:
- `verify_commit_on_branch` catches `Exception` and silently `pass` on subprocess errors.
- Missing `.git`, empty `commit_sha`, `UNKNOWN_SHA` or `HEAD` can silently bypass verification.
- The broad `git branch -a --contains` string fallback accepts ambiguous/current branches instead of the authorized exact branch.

Requirements:
- On **live production work submission**, require a real repository (support ordinary checkout and Git worktree where `.git` may be a *file*); use `git rev-parse --is-inside-work-tree` and the validated repository root.
- Require canonical **40-character hexadecimal commit SHA**, valid commit object, and an exact allowed branch ref. No empty/SHA aliases and no automatically substituted caller HEAD.
- Verify authorized branch exists with exact `refs/heads/<branch>` or explicitly approved remote ref. Check `git merge-base --is-ancestor <sha> <exact-ref>`; only return success on exit code 0.
- On Git executable missing, subprocess timeout, exception, exit code other than 0 (or 1 for non-ancestor), invalid SHA, missing branch, bare/malformed repository or wrong worktree, raise `PolicyViolation` or an explicit verification error. Never silently pass.
- Refuse uncommitted source evidence. Require exact byte equality between working evidence, SHA256 manifest and the Git blob at `<commit>:<path>`; runtime logs remain a separately classified, provenance-bound evidence type.
- Keep **mock unit tests** isolated using a documented test-only bypass injected explicitly, not an implicit absence-of-Git bypass in live policy.

Mandatory negative tests: missing Git executable, Git timeout, no repo, invalid/empty SHA, missing branch, current branch differs from assigned branch, unrelated commit, dirty source, wrong Git blob. Include a *positive* test with a real temporary Git worktree (`.git` file).

## P1-02 — exactly one authoritative final review JSON

File: `STUDIO_V3/orchestrator/dispatcher.py::parse_reviewer_verdict`, adapter return contract and tests.

- Required fields MUST be present with correct types: `task_id` string, `iteration` exact integer (reject bool), `role` string, full `reviewed_commit_sha`, `verdict` PASS/FIX_REQUIRED, `issues` list, **`evidence_manifest` list**. The alias `evidence` is NOT an acceptable substitute for missing `evidence_manifest` in live mode.
- Match task, iteration, provider-verified role and submitted source SHA; no fallback to task SHA or inferred role.
- Parse a single validated **final** provider result. Intermediate example JSON embedded in thought/narrative must not count. If provider contract cannot identify an authoritative final JSON envelope, require one unambiguous final JSON object; reject two or more verdict objects even if their PASS values match.
- Reject `PASS` with unresolved P0/P1, missing/malformed/empty supporting evidence, stale SHA, contradictory response, duplicate review objects, or missing terminal result.
- Keep existing `FIX_REQUIRED` issue routing and two-key policy.

Mandatory negative tests: `{"verdict":"PASS"}`, missing evidence_manifest with only evidence alias, bool iteration, two identical PASS objects, two conflicting objects, previous-agent-message PASS with final failure, missing final verdict, successful process but structured FIX_REQUIRED.

## P1-03 — verify terminal Antigravity subagent completion, not intermediate steps

File: `STUDIO_V3/orchestrator/adapters/subagent_bridge.py` and tests.

- Remove logic equivalent to `any(s.get("status") == "DONE" for s in steps)`.
- Identify and validate the provider's documented **final terminal completion** for the current session/job; verify final model result corresponds to that completion and current task. If format is ambiguous, return `AGENT_COMPLETION_NOT_VERIFIED`; do not infer success.
- Verify parent conversation, provider role, task/run/iteration binding and terminal status before recording trustable review. Do not generate/invent session IDs.
- Harden against partially written JSONL, old DONE followed by RUNNING, old DONE followed by FAILED, valid model JSON followed by canceled state, last line truncated and stale replay. All must fail closed.
- Preserve support for real IDE-native `invoke_subagent`; don't invent private APIs.

## P1-04 — actually register independent review of the infrastructure patch

**Crucial distinction:** prior stamina fixture has two-key approval. `V3-002-R3-PATCH` in committed `queue.json` is still `IN_PROGRESS`, `iteration:0`, `reviews:{}`, and no committed source SHA. A pasted PASS statement does not update the trusted queue.

Required action:
1. PK_ClientLead completes code changes and commits the **frozen infrastructure source SHA**, e.g. `SRC_SHA`. Test code and any required source/test changes must be included. Use exactly that SHA for validation.
2. Produce final test logs against `SRC_SHA`; verify branch and source artifact SHA256, then create a **separate evidence-only commit** after tests if needed. Record `source_sha` and `evidence_commit_sha` separately to avoid an infinite self-referential hash cycle.
3. Update actual local SQLite queue through safe workflow transitions (not direct JSON status edits), submit infrastructure task **`V3-002-R3-PATCH`** against `SRC_SHA` with immutable evidence. Correct any stuck `IN_PROGRESS/iteration:0` state through documented migration / audited repair; no hidden resets.
4. Invoke **two new distinct native subagent sessions**, one `PK_QALead`, one `PK_GameDirector`, to review **`SRC_SHA`**, not the older stamina fixture SHA or evidence-only commit. Have them submit exact schema-compliant final JSON, terminal completion, session and parent IDs, own evidence paths and explicit verdicts.
5. Ingest through trusted `SingleEntryRunner` / TaskDispatcher, validate QA and Director both review same `SRC_SHA`, persist invocation registry + `queue.json` + `events.jsonl` with one run ID and independent statuses. Only safe gate can approve.
6. Confirm **task `APPROVED` => lease_owner/lease_expires_at NULL**. Do not bypass by directly editing the JSON snapshot. If any review rejects, keep FIX_REQUIRED with a precise issue and stop for bounded fix.
7. Parent `V3-002` is a **separate milestone**. Even if `V3-002-R3-PATCH` is approved, propose final parent acceptance with its own reviewed SHA / evidence; do NOT automatically mark parent APPROVED or unblock V3-003.

Evidence requirement: real provider session IDs, parent ID, start/completion timestamps, terminal JSON, reviewer diff/test evidence, submitted source SHA, manifest hash, exact command outputs, SQLite snapshots and synchronized queue export. Old fixture sessions cannot be reused as proof of new infrastructure reviews.

## No endless rework / stop conditions

- Maximum 2 corrective coding iterations for this closure task. Beyond that, stop with `BLOCKED` and a small list of exact residual failures; do not create a new framework or an automatic R4.
- Only one complete native Producer integration recheck if necessary; prior 5-session fixture may be referenced as historical evidence, not needlessly replayed.
- If provider lacks trusted terminal status or identity proof, mark `NOT_VERIFIED` and stop; require an explicit operator decision rather than fake green checks.
- Do not modify Godot runtime, gameplay, art, scenes, saved games, unrelated QA scores or history. Do not force push or merge to main.

## Exact negative checks
1. Missing/nonexistent repository or missing Git binary/timeout -> verification **FAIL**.
2. Missing or invalid full SHA, branch unresolved, unrelated SHA -> **FAIL**.
3. Git worktree (`.git` file) with valid SHA/authorized branch -> **PASS**.
4. Dirty file or file absent from commit -> **FAIL**.
5. Missing evidence_manifest, bool iteration, duplicated PASS JSON -> **FAIL**.
6. Earlier DONE + later RUNNING/FAILED / incomplete JSONL -> **AGENT_COMPLETION_NOT_VERIFIED**.
7. A reviewer returns structured FIX_REQUIRED despite process success -> **FIX_REQUIRED**, not APPROVED.
8. Forge QA/Director names or reuse prior fixture sessions -> **FAIL**.
9. Reviewers review different source SHAs -> **FAIL**.
10. Both independent live reviewers PASS same source SHA, evidence matches, no P0/P1 -> approve **infrastructure patch task only** and clear lease.

## Deliverables
```
STUDIO_V3/tasks/V3-002-CLOSE.md
STUDIO_V3/reviews/V3-002-R3-PATCH-INDEPENDENT-REVIEW.md
STUDIO_V3/orchestrator/{policies,dispatcher,adapters/subagent_bridge,runner,...}.py
STUDIO_V3/tests/test_v3_002_closure_*.py
STUDIO_V3/evidence/V3-002-CLOSE/
  baseline_failures/
  test_logs/python_tests_raw.log
  test_logs/godot_tests_raw.log
  infrastructure_review/qa_*.json
  infrastructure_review/director_*.json
  infrastructure_review/provider_provenance.json
  source_evidence_manifest.json
  FINAL_EXECUTION_REPORT.md
STUDIO_V3/queue.json
STATE.md
```
Evidence file paths are illustrative: use actual generated files; never create fake transcripts.

## Report and final status
```text
TASK: V3-002-CLOSE
Branch: studio/v3-002-closure-patch
Source SHA: ...
Evidence commit SHA: ...
Python tests: N/N PASS/FAIL, exit code ..., raw log ...
Godot tests: N/N PASS/FAIL, exit code ..., raw log ...
Git fail-closed gate: PASS / FAIL
Strict final JSON: PASS / FAIL
Provider terminal proof: VERIFIED / NOT_VERIFIED
Native IDE subagent execution: VERIFIED / NOT_VERIFIED
Infrastructure QA / Director: VERIFIED / NOT_VERIFIED (two NEW sessions)
Infrastructure patch status: APPROVED / IN_REVIEW / FIX_REQUIRED
Parent V3-002: FIX_REQUIRED / IN_REVIEW / independently APPROVED
V3-001: READY / ...
V3-003: BLOCKED
Open P0/P1: ...
Review evidence links: ...
Status: INDEPENDENT_REVIEW_REQUESTED / FIX_REQUIRED / BLOCKED
```

**No self-approval in prose.** When implementation is complete, push the branch and review evidence and request external verification of code and official queue state.

## Start now (Producer handoff)

Fetch `studio/v3-002-closure-patch`. First read this task and R3-PATCH independent review. Ask `PK_ClientLead` to fix the specific three code defects. Run negative tests, freeze a source SHA, collect raw logs, then **newly invoke QA and Director against that infrastructure SHA** and persist their verdicts through the real control-plane approval gate. Do not modify game source. No new R4 design.
