# V3-002 Parent Milestone Roll-up — External Independent Review

**Reviewed branch:** `studio/v3-002-parent-approval`  
**Review output HEAD:** `0c98ee150daeed6a4c1dad45c9ecd3da9c2367c6`  
**Frozen parent review packet:** `a1c954e98acbfec95395be973e5b016339888300`  
**Accepted implementation code:** `214000678186b6ebb42349eeb28336b4dcfe0e42`  
**Decision: FIX_REQUIRED (focused governance/evidence reconciliation, no new implementation).**  
**Scope:** independent GitHub tree/source/evidence audit, blob SHA256 checks, queue/events and reviewer metadata consistency; not a direct replay of private Antigravity session or local SQLite DB.

## Verified substantive progress

1. The implementation branch exists at exactly the reported HEAD. The frozen `a1c954e...` packet is a distinct commit; the new QA/Director output files, provider provenance, queue and report were added in the following evidence-only commit. **No review-future-file SHA attribution** was detected in the **V3-002 parent** evidence manifest.
2. **17/17 infrastructure files** were fetched at `214000678186b6ebb42349eeb28336b4dcfe0e42` and their SHA256 and byte sizes independently checked against `SOURCE_AND_EVIDENCE_MANIFEST.json`: all matched.
3. **7/7 historical evidence files** were independently checked against the packet's Git tree and manifest. The two raw logs and two copied external review Markdown files use CRLF in committed bytes; the GitHub text connector normalizes them to LF. Restoring their original CRLF bytes gives exact SHA256 and size matches. The other three JSON files match directly. Do not misreport text decoding normalization as source tampering.
4. **6/6 frozen parent-input evidence files** were independently checked against `a1c954e...` and the `V3-002` task evidence manifest: all match (two files require the same CRLF restoration during textual retrieval).
5. The supplied Python test stdout/stderr reports **57/57 PASS, exit code 0**; the pre-existing Godot 74/74 test log is an isolated stamina fixture. The reviewer did **not** re-execute tests on the Windows host.
6. The `V3-002` **parent task** now records internal `APPROVED`, iteration 2, frozen packet SHA `a1c954e...`, distinct `PK_QALead` and `PK_GameDirector` PASS sessions and cleared lease. The named session IDs are `3aa4a1d0-4972-4750-852f-04e2675be74f` and `178b4ee7-d8b6-4b9b-8310-4db576501a4b`. GitHub provider-provenance JSON names the same sessions and SHA; private provider transcripts/SQLite invocation records were not directly queried.
7. `events.jsonl` preserves the preceding **31 lines**, appends **5** records for `V3-002`, and leaves `V3-003` BLOCKED. Game client was not modified. The actual game has 3 P1 issues and remains NOT_APPROVED for release.

## Blocking finding P1-01 — Separate wrapper task approved with no two-key evidence

**Reproduce:** Read `STUDIO_V3/queue.json` at `0c98ee...`. For task ID **`V3-002-PARENT-APPROVAL`**, `status="APPROVED"` while **`reviews={}`** and no new event exists for this task ID. Its declared reviewers are `PK_QALead` and `PK_GameDirector`. The actual `V3-002` parent *does* have two distinct recorded PASS reviews. This distinction matters.

The implemented `STUDIO_V3/orchestrator/policies.py::can_approve` explicitly rejects approval when designated reviewers have not submitted PASS for the current task/iteration. A task independently marked APPROVED with an empty review set contradicts the system's own invariant. The status may have been set through an administrative script or snapshot mutation, but a reviewer cannot treat it as a valid guard-mediated approval.

**Required narrow resolution:** Treat `V3-002` parent as the authoritative reviewed milestone; reconcile the secondary `V3-002-PARENT-APPROVAL` administrative task through a documented, append-only authorized correction/migration, or provide its own legitimate two-key review record. Do **not** directly delete history, forge a past verdict or claim the wrapper has the parent task's reviews. Prefer minimal state correction, not a new architecture/feature cycle. Add a queue invariant check: any task APPROVED without own two designated independent PASS reviews must fail validation.

## Blocking finding P1-02 — "12/12 VERIFIED" overstates runtime discoverability evidence

The **original** `STUDIO_V3/tasks/V3-002.md` item #1 specifically requires **six custom agents discoverable by the real Antigravity runtime**. The submitted `PARENT_ACCEPTANCE_MATRIX.md` item #1 proves **six `.agents/agents/PK_*.md` definition files**, which is useful but **not the same as provider runtime discovery of all six**.

The earlier runtime `agy agents` probe in `STUDIO_V3/evidence/V3-002-R1/runtime_probe/summary.json` returned **exit code 1** because the CLI was not installed. The IDE transcript says "Found 24 subagents" but does not provide a durable listing identifying all **six specific PK roles**. The other evidence confirms live role activity for ClientLead, QALead and GameDirector, not necessarily discovery of all six. If a trusted IDE-native enumeration of all six exists, commit its output or a valid provider metadata capture. If unavailable, change criterion #1 to `PARTIAL / NOT_VERIFIED`, explain the accepted IDE-native limits, and ask QA/Director to assess whether the original milestone may be approved with an explicit documented exception **rather than calling all 12 VERIFIED**. Do not fabricate CLI output or agent IDs.

**Required:** one exact runtime discovery proof for each six role names, or a truthful reduced acceptance matrix with explicit documented exception/decision. No new runtime implementation is required.

## Supporting finding P1-03 — formal approval event chronology not reproducible from repository

The two native review sessions are recorded as completed at **02:44:18Z** and **02:44:53Z**, respectively, but all five official `TASK_STARTED → WORK_SUBMITTED → REVIEW_PASSED ×2 → TASK_APPROVED` event entries have identical timestamp **02:47:58.488292Z**. This suggests that the control-plane transitions were applied **after** native reviews finished, not streamed live in the asserted chronological workflow. Post-completion attestation can be legitimate, but must be labeled as retrospective ingestion and preserve true provider session times.

The uploaded IDE action log refers to repeated failed attempts and a successful `apply_parent_approval.py` but **that script is absent from the Git tree**. The local SQLite `queue.db` and its invocation registry are not available for direct external inspection. Additionally, the recorded reviewer `invocation_id` values in `queue.json` append `-V3-002`, while `PROVIDER_PROVENANCE.json` lists IDs without that suffix. This may be an explicit canonicalization alias, but no mapping is supplied.

**Required narrow resolution:** provide the exact non-secret status transition script or a reproducible command transcript, a sanitized invocation registry export for the parent iteration (including session IDs, effective IDs, role, provider, target SHA, terminal state and parent ID), and an explicit note that event timestamps are retrospective ingestion timestamps. If aliasing invocation IDs, include the deterministic mapping and reference source. This is about authenticity of governance claims, not re-running gameplay or reconstructing an entire agent platform.

## Nonblocking / test-scoping cautions

- The committed `verify_parent.py` writes `invariants.json` with success booleans, **hardcoded 57/57 and 74/74** rather than deriving them and failing the process on every invalid Git/test return code. Its script exit status is not an independent fail-closed invariant gate. The reviewer verified the actual Git hashes separately, and the raw logs can support the reported tests, but do not claim that this verification helper exercises all 12 rules.
- Historical-evidence manifest records paths and hashes but lacks a per-item first-containing or source commit SHA promised in the task spec. Add explicit commit provenance in future evidence maintenance or the focused correction, without rewriting old data.
- Wrapper task approvals must never be silently copied from parent approvals. Keep `V3-003` BLOCKED until official parent acceptance is externally accepted and the V3-003 transition is explicitly authorized.
- This review does not directly attest private Antigravity sessions, Android runtime quality, Stage 1 player visuals or gameplay input and boss performance.

## Resolution path — one focused pass

1. **Keep** `214000...` implementation, `a1c954...` frozen packet and existing parent QA/Director sessions. **No new R4, no gameplay source, no stamina replay.**
2. Reconcile `V3-002-PARENT-APPROVAL` self-inconsistent task state using governed append-only correction, without changing the separately reviewed parent `V3-002` to an unsupported state.
3. Provide actual IDE runtime discovery of all six agents or correct criterion #1 and document the precise governance exception.
4. Commit or otherwise durably preserve the actual parent-approval ingestion script/commands plus sanitized provenance mapping and timeline explanation; do not print private tokens/secrets.
5. External reviewer can then check the **delta only** and decide the parent milestone acceptance. Reviewer sign-off on a corrected packet may require a scoped new QA/Director addendum; do not claim that existing reviews inspected files that did not yet exist.

**Final external decision:** `FIX_REQUIRED` for parent approval evidence/governance coherence. The previously accepted infrastructure code and V3-001 baseline audit remain accepted; `V3-003` stays `BLOCKED`. This is a precise final compliance correction, not a reason for endless agent-system development.
