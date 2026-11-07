# V3-001-EVIDENCE-RECONCILE — External Independent Review

**Reviewed branch / HEAD:** `studio/v3-001-evidence-reconcile@0d99e2b0da5ecd30cff8641348ba4ed3e897423b`  
**Frozen reconciliation SHA claimed:** `c55714745ac15776d5ffa449da6058da3dd777ea`  
**Original game source:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Decision:** **FIX_REQUIRED — one narrow provenance correction; do not rebuild or re-run gameplay solely for this finding.**  
**External review scope:** Actual connected GitHub documents, source scripts, metrics JSON and queue/events, diff of frozen vs final commits, supplied Antigravity final narrative. User's private Windows Godot process and native subagent backend were not re-executed or directly accessed; PNG pixel content not independently rendered through current GitHub text connector.

## Confirmed improvements

1. Actual GitHub HEAD matches submitted final `0d99e2b`. The change from V3-001 original evidence HEAD affects `STUDIO_V3` only, **not `CLIENT/Game/`**; original PNG and raw CSV files are not edited in the comparison.
2. The originally missing `benchmark_stage1_windowed.gd` is now committed. The script samples from `SceneTree._physics_process` using `Time.get_ticks_usec()` for `dt_ms`, while separately collecting `Performance.TIME_FPS`. Therefore the initial 60Hz physics-tick vs ~240 render-FPS ambiguity is **substantially resolved**.
3. Committed `analysis.py` and `analysis_output.json` explain 14,404 recorded samples. A clear `COMBAT_STRESS_DIFFERENTIAL_NOT_VERIFIED` qualification replaces the unsupported proof of higher combat workload. Android remains `NOT_TESTED`.
4. The actual GitHub `GAMEPLAY_ISSUE_BACKLOG.md` preserves original issue meanings and unique IDs: 01 missing touch UI (P1), 02 Z-plane discrepancy (P1, DECIDED/IMPLEMENTATION_PENDING), 03 startup add_child error (P2), 04 Sprite3D contact (P2), 05 boss telegraph (P3), 06 victory screen (P3), 07 boss foreground wall occlusion (P1). **7 unique: 3 P1 + 2 P2 + 2 P3.**
5. A new `CAPTURE_MANIFEST.json` lists 11 original PNG paths, dimensions, byte sizes and SHA256 claims. Actual original image pixels were not independently opened by this reviewer, so pixel-level visual conclusions are not certified here.
6. `queue.json` records two different new native reviewer session IDs for `V3-001-EVIDENCE-RECONCILE` (QA `a915a14e-96a7-434b-8052-4e36c509dc85`, Director `f9aecc75-10a4-4def-b59f-872c280bc4d8`), both against SHA `c557147...`, PASS, cleared lease and audit events. This is evidence of the recorded internal workflow, not independent provider-session authentication.

## P0 — Frozen evidence SHA and attested file set contradict the Git tree

**Directly reproducible with:**
```sh
git diff --name-status c55714745ac15776d5ffa449da6058da3dd777ea 0d99e2b0da5ecd30cff8641348ba4ed3e897423b
git cat-file -e c55714745ac15776d5ffa449da6058da3dd777ea:STUDIO_V3/evidence/V3-001-reconcile/QA_ADDENDUM.md
```
The latter must fail because the QA file was created **after** the frozen commit. The frozen-to-final diff shows these three files are **newly added only in the final evidence commit**:
- `STUDIO_V3/evidence/V3-001-reconcile/QA_ADDENDUM.md`
- `STUDIO_V3/evidence/V3-001-reconcile/DIRECTOR_ADDENDUM.md`
- `STUDIO_V3/evidence/V3-001-reconcile/FINAL_RECONCILIATION_REPORT.md`

However `V3-001-EVIDENCE-RECONCILE` in `STUDIO_V3/queue.json` records all THREE as `evidence_manifest` entries with `source_commit_sha=c557147...`; **both** QA and Director `reviews[*].evidence_hashes` also include hashes of those post-frozen files. The same entries appear in new `events.jsonl` evidence paths, bound to the frozen SHA. This reintroduces the exact **future evidence attestation** flaw that the reconciliation was supposed to fix.

This does **not** prove that the underlying new agent sessions were imaginary. It means the stored **attested file set is not the actual immutable file set at the reviewed SHA**; the claimed proof cannot be accepted as written.

### Required one-pass correction
- Distinguish `REVIEWED_EVIDENCE_SHA=c557147...` containing the **7 actually committed pre-review evidence artifacts** from `REVIEW_REPORT_COMMIT_SHA=0d99e2b...` containing post-review QA/Director addenda and final report. These latter files cannot be asserted to have existed in the frozen source tree.
- Do NOT rewrite `events.jsonl` or retrospectively forge earlier attestations. Append an explicit **CORRECTION/SUPERSEDED_EVIDENCE_MANIFEST** event identifying the 3 invalid SHA-bound entries and the actual Git commit each lives in.
- Reconstruct the authoritative manifest with `git ls-tree` / `git show` for the exact source SHA and verify SHA256 against Git blobs; attach a separate signed `review_output_evidence` manifest for post-review files associated with the final evidence commit.
- If the existing formal guard cannot support immutable corrections without invalidating approval, use a **fresh evidence-only QA and Director attestation** on one frozen corrected SHA or a legitimate audited migration. No mock provider, silent direct JSON edit, or re-use of old sessions as if new.
- Include a negative regression test: an evidence path absent from the claimed `source_commit_sha` must never be accepted as *committed source evidence*, even if that path exists in the current working tree.

## P1 — Pasted producer report mislabels five canonical defects

The user-visible Antigravity completion narrative's P1-B section calls:
- ISSUE-01 "stage boss reward/exit", not missing touch controls.
- ISSUE-03 "jump/dash input buffering", not the documented startup `add_child` error.
- ISSUE-04 "shadow weaker", ISSUE-05 "parry feedback", ISSUE-06 "combo stagger", ISSUE-07 "health gauge alignment" — none match canonical GitHub issue IDs.
The canonical `GAMEPLAY_ISSUE_BACKLOG.md`, `ISSUE_RECONCILIATION.md` and QA/Director addenda in GitHub **do have the correct issue mapping**. This is primarily a **narrative reporting inconsistency**, but could misdirect the next V3-003 development tasks if pasted text is treated as authority.

**Required:** correct the completion report/message from canonical GitHub file with exact 7 IDs/title/severity/status; do not edit or overwrite historical issue definitions to fit the erroneous summary.

## P2 — Measurement claims should remain precisely qualified

- Recomputed `analysis_output.json` gives **overall engine FPS mean 238.34**, median 240; steady-state walking/normal-combat/boss means are around **239.54**. Some prose describes 239.54 as overall mean, which is not exact.
- `Performance.TIME_PROCESS` measures engine process time and is **not independently verified GPU total frame time**. Avoid asserting GPU headroom from this CPU/main-loop metric alone, particularly for mobile.
- The recovered script labels sample calls as `frame` but actually samples every physics tick, NOT every render frame; sector names alone do not prove executed workload, as already conservatively acknowledged.
- `performance.json` lists VSync enabled while prose says "unconstrained" ~240 FPS: ~240FPS could be a 240Hz VSync-limited render stream. Do not claim disabled VSync without a supported runtime setting.

These are **non-blocking to audit evidence coherence if the reports preserve qualifiers** and are not used to certify Android or real boss stress.

## Conclusion / next action

- **V3-001 evidence content:** substantially reconciled and useful. Do not discard genuine baseline work.
- **V3-001-EVIDENCE-RECONCILE official internal queue:** APPROVED in committed state, but **external verification remains FIX_REQUIRED** due to manifest vs frozen-tree mismatch.
- **Game readiness:** NOT_APPROVED; 3 open P1 gameplay defects remain.
- **V3-002 parent:** FIX_REQUIRED pending formal roll-up; child `V3-002-CLOSE` independently accepted.
- **V3-003:** BLOCKED until the prerequisite audit and parent milestones are formally accepted.

Resolve **only** the frozen-vs-post-review evidence binding (plus correct producer summary). After that, external re-review can be confined to exact Git SHA and manifest; do not ask for a new agent system, graphic implementation, new 4-minute benchmarking loop, or needless R4.
