# TASK V3-002-PARENT-GATE-RECONCILE — 부모 승인 게이트의 최종 정합성 보완

**Status:** READY — 지시서 등록 단계, 보완 작업은 아직 수행되지 않음
**Priority:** P0 — V3-003 게임 개발 착수 전 마지막 외부 검수 지적사항
**Branch:** `studio/v3-002-parent-gate-reconcile`
**Branch base:** `studio/v3-002-parent-approval@0c98ee150daeed6a4c1dad45c9ecd3da9c2367c6`
**Authoritative parent V3-002 implementation SHA:** `214000678186b6ebb42349eeb28336b4dcfe0e42`
**Original parent review packet SHA:** `a1c954e98acbfec95395be973e5b016339888300`
**Original parent review output SHA:** `0c98ee150daeed6a4c1dad45c9ecd3da9c2367c6`
**External review:** `STUDIO_V3/reviews/V3-002-PARENT-INDEPENDENT-REVIEW.md` (FIX_REQUIRED)
**Coordinator:** PK_Producer; **evidence worker:** PK_ClientLead; **independent reviewers:** PK_QALead and PK_GameDirector, new verified native sessions for this correction
**Scope:** one bounded evidence/governance correction, **not** R4/reimplementation and **not** gameplay development.

## Objective and current facts

The original Studio V3 implementation was previously accepted by external review, and `V3-001` baseline audit evidence was accepted. A separate external review of parent `V3-002` verified Git SHA256 for **17 infrastructure files + 7 historical evidence files + 6 frozen parent packet files (30/30)**, and found no new infrastructure code defect. However, it marked the parent roll-up **FIX_REQUIRED** because:

1. `V3-002-PARENT-APPROVAL` (administrative wrapper) is `APPROVED` with **`reviews={}`**, although the separate `V3-002` (authoritative parent milestone) has two actual PASS review records.
2. The original acceptance condition “six custom agents discoverable by actual Antigravity runtime” was marked VERIFIED using only the existence of six `.agents/agents/PK_*.md` files; original `agy agents` CLI probe failed and current repo does not contain a complete native IDE discovery listing of all six named PK roles.
3. The formal approval event chain was batch-ingested after native review completion; the concrete `apply_parent_approval.py` used in the IDE action trace was not committed, and the reviewer invocation IDs differ between queue and provider summary. Timeline, status-mutation method and alias map need reproducible, sanitized evidence.

**Mission: correct these THREE findings. No new tests/graphics/agents/framework just to satisfy a report. Do not change the accepted production code.**

## Gate 0 — inspect exact starting state and protect original records

1. Fetch and checkout the dedicated worktree for `studio/v3-002-parent-gate-reconcile`, record `git status --short`, `git rev-parse HEAD`, origin tracking, Git version.
2. Read `STUDIO_V3/tasks/V3-002-PARENT-APPROVAL.md`, `STUDIO_V3/tasks/V3-002.md`, `STUDIO_V3/PROTOCOL.md`, `STUDIO_V3/reviews/V3-002-PARENT-INDEPENDENT-REVIEW.md`, `STUDIO_V3/evidence/V3-002-parent/` and `STUDIO_V3/orchestrator/{policies,queue_store,dispatcher,event_log,schemas}.py`.
3. Back up local `queue.db` before any state mutation; establish whether the DB or JSON snapshot is authority. Compare both task records, historical reviewer sessions, their iteration/SHA and snapshot version. **Do not import a stale snapshot over valid DB records.**
4. Strict immutable inputs: all `CLIENT/Game/` gameplay/art/scene/project config, 11 prior PNG captures, original 14,404-row CSV, accepted `214000...` code, old `a1c954...` packet, old `0c98ee...` reports and **every existing `events.jsonl` line**.
5. Record only verified facts. Screenshots or provider metadata must be authentic IDE outputs. Do not fabricate terminal output, agent names, file hashes, provider messages or review status.

## P1-01 — fix the wrapper approval inconsistency without counterfeiting history

**Demonstration:**
```text
V3-002:                   status=APPROVED, reviewers=PK_QALead+PK_GameDirector, both PASS
V3-002-PARENT-APPROVAL:   status=APPROVED, reviewers=PK_QALead+PK_GameDirector, reviews={}
```

- Determine exactly why `V3-002-PARENT-APPROVAL` was marked approved without its own signed verdicts. Inspect the **real** previously run `apply_parent_approval.py` (if it still exists locally) and the SQLite state. If it does not exist, say `SCRIPT_MISSING`, do not invent a reconstruction and call it original.
- Explicitly distinguish milestone `V3-002` from the administrative wrapper and from the **new** correction task `V3-002-PARENT-GATE-RECONCILE`. Do not copy the parent's QA/Director records to the wrapper; their `task_id` and iteration differ.
- Preferred policy: preserve the parent's real two-key-approved status **as historical fact**; mark the wrapper's unsupported approval as **SUPERSEDED / INVALID FOR GATING** through a documented append-only audited correction and a legal QueueStore/TaskDispatcher state transition or controlled migration. For existing schema status values, use `FIX_REQUIRED` or `BLOCKED` with an exact reason; avoid unsupported new status enums.
- **Do not edit `queue.json` directly to repair approval**. Use the SQLite-backed authoritative state store with backup, transaction and snapshot export, plus a dedicated corrective audit event referencing old/new values, task ID, actor, source SHA and reason. If existing APIs do not permit safe post-approval state correction, stop at `CORRECTION_NOT_SUPPORTED` and describe a minimal governed migration; do not bypass gates.
- Add a **read-only invariant checker** or regression test: for every `TaskState.APPROVED`, the task's *own* designated independent reviewers must have PASS for its *own* iteration and matching reviewed SHA and distinct verified session IDs. Historical entries with valid correction events may be marked `SUPERSEDED` explicitly by the checker; ordinary empty `reviews={}` must fail.
- Queue state correction must not erase or falsify prior events, provider sessions, version numbers or completion records.
- **New correction task must also pass its own two-key gate**; it cannot be marked APPROVED solely because `V3-002` is.

## P1-02 — evidence for runtime discoverability of all six PK roles, or honest PARTIAL

The six required roles:
`PK_Producer`, `PK_ClientLead`, `PK_QALead`, `PK_GameDirector`, `PK_GameDesign`, `PK_ArtDirector`.

**Accepted proof:** a fresh, real Antigravity IDE-native runtime discovery/agent management listing with **each exact role name visible**; include source of listing (provider-native tool, application UI, provider metadata or a real supported command), actual timestamp, installed IDE version, worktree root, sanitized raw output or an unedited screen capture, and evidence file SHA256. If available, a native tool result that enumerates these roles is better than an assertion in prose.

**Not sufficient alone:** six Markdown files on disk; `agy agents` attempted with exit code 1; “Found 24 subagents” without names; generic statements that roles were loaded; three working reviewer roles extrapolated to the other three.

1. First inspect the **real IDE runtime** for a supported “list/discover agents” operation. Use only supported current commands shown by installed help or available native UI. **Never invent an `agy` command or private API.**
2. Save `AGENT_DISCOVERY.md` and `AGENT_DISCOVERY_EVIDENCE.json` mapping role → definition path → *runtime listed yes/no/unknown* → supporting capture/transcript location and hash.
3. If some roles cannot be discovered, label criterion #1 `PARTIAL` or `NOT_VERIFIED`. Correct the parent acceptance matrix **in a new addendum, without editing the old frozen original**. Avoid repeating “12/12 VERIFIED” when one criterion lacks runtime proof.
4. An explicit deviation from original V3-002 acceptance requirements requires a separate **authorized decision** (with acceptance owner and rationale, scope, risks). Neither Producer nor QA/Director may silently change the original contractual condition just to get a PASS. If no valid authorization and the requirement remains unmet, preserve parent external `FIX_REQUIRED` and do **not** authorize V3-003.
5. Successful IDE-native invocation of some roles remains valid prior evidence; standalone Python headless agent auto-spawning stays `NOT_VERIFIED`.

## P1-03 — preserve exact approval application command/registry/chronology

Recorded native QA and Director sessions for parent `V3-002`:
- QA session `3aa4a1d0-4972-4750-852f-04e2675be74f`
- Director session `178b4ee7-d8b6-4b9b-8310-4db576501a4b`
- Both reviewed parent packet `a1c954e98acbfec95395be973e5b016339888300`.
- Provider recorded QA completion at `2026-11-07T02:44:18Z` and Director at `02:44:53Z`. Five `events.jsonl` events are logged at exactly `02:47:58.488292Z`.

1. Recover the **actual** `apply_parent_approval.py` used during this run, or exact historical terminal commands from immutable local logs, plus stdout/stderr and failing attempts. Redact tokens/paths containing secrets; preserve the distinction between a **recovered original** and any **new illustrative verifier**. Do not forge a script claiming it performed old actions.
2. Capture a sanitized SQLite `invocations` registry export **read-only** for `task_id=V3-002`, `iteration=2`: actual invocation ID, session ID, role, provider, target SHA, parent_conversation_id, run ID, terminal status, started/completed_at, result hash. Do not commit credentials or full private transcripts.
3. Reconcile whether invocation IDs `inv-sub-pk_qalead-3aa4a1d0` vs `inv-sub-pk_qalead-3aa4a1d0-V3-002` and analogous Director strings represent **aliases**, real separate registration IDs, or a mismatch. Only claim verified mapping when source and DB support it.
4. Document the **retrospective ingestion** sequence: native sessions completed first; on-disk queue state transitions and five audit events were applied later. Explain why all five events have same timestamp. Do not state that they were emitted in real time during provider execution if they were not.
5. Verify legal transition via actual `TaskDispatcher` or an explicitly documented controlled recovery. Show the full chain of `FIX_REQUIRED → IN_PROGRESS → IN_REVIEW → APPROVED` with version/iteration, both reviewer registry entries and lease cleanup. If the prior transaction used manual task assignment without `review_task`, identify that exact limitation rather than calling it a standard automated gate.
6. Keep raw logs of the new read-only checks, their exit codes and failures. No need to re-run Godot stamina fixture or earlier game audit.

## Gate 4 — freeze correction packet, then distinct NEW QA + Director attestation

Before invoking reviewers, build and commit only the **review input** files:

```text
STUDIO_V3/evidence/V3-002-parent-gate/
  WRAPPER_STATUS_CORRECTION.md
  PARENT_APPROVAL_CHRONOLOGY.md
  APPROVAL_INVOCATION_REGISTRY_SANITIZED.json
  AGENT_DISCOVERY.md
  AGENT_DISCOVERY_EVIDENCE.json
  ACCEPTANCE_MATRIX_ADDENDUM.md
  GATE_INVARIANT_CHECK.md
  verification/commands_and_raw_output.txt
  verification/negative_tests.txt
```

Do not invent files whose data was not actually obtained. For absent provenance use a clearly labeled `NOT_AVAILABLE` section and verdict `NOT_VERIFIED`.

1. Commit the above and freeze **`GATE_CORRECTION_REVIEWED_SHA`**. Ensure the tree includes the actual evidence paths and hashes before claiming verification.
2. Invoke two distinct **NEW** Antigravity-native `PK_QALead` and `PK_GameDirector` sessions to independently review the *same* correction SHA, not the old `a1c954...` SHA (that remains historical parent review). Worker/Producer and each reviewer must be independent.
3. Reviewers must inspect both the corrected administrative status/registry claims **and** the six-role runtime discovery result. If criterion remains NOT_VERIFIED without properly authorized exception, reviewer must report `FIX_REQUIRED`, not `PASS`.
4. Run guarded `TaskDispatcher.start_task/submit_work/review_task` on **`V3-002-PARENT-GATE-RECONCILE` only**; do not reapprove the already historically approved parent by copying old sessions. Strict source SHA, manifest and provider terminal checks; no mock/self-review.
5. Only after new QA and Director have completed, commit `QA_GATE_REVIEW.json`, `DIRECTOR_GATE_REVIEW.json`, `PROVIDER_GATE_PROVENANCE.json`, `FINAL_GATE_RECONCILIATION_REPORT.md`, exported `queue.json`, append-only `events.jsonl` and state update in a distinct **`GATE_REVIEW_OUTPUT_SHA`**.
6. **Never include post-review files in the frozen review source SHA** or retroactively hash them as earlier input. Preserve all prior audit log bytes and record corrective events as append-only.
7. Keep V3-003 BLOCKED pending this task's **external independent acceptance** and explicit authorization of a new V3-003 branch. Stage 1 game still has 3 open P1 issues.

## Output format & stop rule

```text
TASK: V3-002-PARENT-GATE-RECONCILE
Branch: studio/v3-002-parent-gate-reconcile
Immutable infra source: 214000678186b6ebb42349eeb28336b4dcfe0e42
Original parent packet: a1c954e98acbfec95395be973e5b016339888300
Historical parent status: APPROVED (two independent recorded PASS)
Historical wrapper: INVALID_APPROVAL / CORRECTED / NOT_VERIFIED
Wrapper invariant: PASS / FAIL
Six PK roles runtime-discoverable: 6/6 VERIFIED / N/6 / NOT_VERIFIED
Original acceptance matrix: 12/12 VERIFIED / N VERIFIED + M PARTIAL / ...
Recovered approval script or commands: EXACT ORIGINAL / UNAVAILABLE
Invocation ID alias mapping: VERIFIED / NOT_VERIFIED
Approval events retrospective timing explained: VERIFIED / NOT_VERIFIED
Original events preserved byte-for-byte: YES / NO
Gate correction reviewed SHA: ...
Gate reviewer-output SHA: ...
New QA session / verdict: ...
New Director session / verdict: ...
Corrected task status: APPROVED / FIX_REQUIRED
External parent rollup status: REVIEW_REQUESTED / FIX_REQUIRED
Game client release: NOT_APPROVED (P1 3 open)
V3-003: BLOCKED
Commit URLs and actual artifacts: ...
```

**Bounded scope:** one focused evidence/governance pass. If the six-role runtime listing or authorized exception cannot be verified, **stop with FIX_REQUIRED and exact missing evidence**. Do not initiate another R4/R5 rebuild, fabricate PASS, rewrite the history or change gameplay to force progress.

## Immediate producer execution

Fetch `studio/v3-002-parent-gate-reconcile` and read this task plus `STUDIO_V3/reviews/V3-002-PARENT-INDEPENDENT-REVIEW.md`. Audit the wrapper's missing reviews, obtain genuine six-role runtime listing or report partial, recover actual parent approval script/registry and explain retrospective event timestamps. Freeze only pre-review evidence; seek two new independent QA/Director reviews; write output in a later commit and request external ChatGPT delta review. **No implementation changes to `CLIENT/Game/` and no premature unblock of `V3-003`.**
