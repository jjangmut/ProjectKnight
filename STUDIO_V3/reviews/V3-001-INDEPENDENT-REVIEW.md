# V3-001 — Independent Game Baseline Audit Review

**Reviewed implementation branch:** `studio/v3-001-playable-baseline@5c25a98084ba6885e1b9b4e2bac40a9c74568473`  
**Audited game source:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Review scope:** GitHub repository tree, committed Markdown audit/QA/Director documents, gameplay input log, screenshot index and available blobs, performance JSON and all 14,404 CSV sample records, queue and event log, plus supplied Antigravity execution trace.  
**Independent run limitation:** I did not operate Godot on the user's Windows machine, inspect native Antigravity private sessions, or decode/view the PNG pixel contents through the available GitHub text interface.  
**Decision: FIX_REQUIRED — audit evidence reconciliation only. Do not rework the agent orchestration architecture or gameplay in this audit.**

## Meaningful confirmed progress

1. The exact remote implementation branch exists at `5c25a980...` and contains 11 distinct PNG screenshot **files**, `capture_index.json`, `BASELINE.md`, `DESIGN_DECISION.md`, `ISSUES.md`, raw startup/windowed logs, `performance.json`, `raw_frames.csv` with 14,404 rows, and QA/Director reports.
2. The Git diff from audited source `a7122361...` to evidence commit `5c25a980...` changes only `STUDIO_V3` documentation/evidence/queue/events; there are no `CLIENT/Game/` tracked changes.
3. The windowed log records Godot 4.7.2 GL Compatibility launch, a Win32 title-button click, Stage 1 load, named keyboard input steps, a real startup `add_child` error, and a Stage 1 cleared console line. This is substantially stronger evidence than historical headless stamina fixture tests.
4. Two distinct native reviewer session IDs are recorded, their `ReviewVerdict` entries both target `a7122361...`, and `queue.json` is internally `APPROVED` with cleared lease.
5. PK_GameDirector's **Option C — 2.5D rendering with fixed 2D gameplay plane / Z=0** is an explicit design decision; its implementation remains pending. Android performance correctly says `NOT_TESTED`.

## P1-A — The submitted four-sector performance figures are not sufficiently attributable to actual play

**Evidence:** `STUDIO_V3/evidence/V3-001/performance/raw_frames.csv` (14,404 data records), `performance.json`.

The CSV has separate columns `dt_ms` and `fps`. In walking, normal_combat and boss_combat, the recorded **fps column is 239–240**, with median 240; the recorded `dt_ms` median is ~16.7 ms (equivalent to ~60 sampled intervals per second). The report presents mean 60.03 FPS and 1% low 59.46 derived from `dt_ms`, but does not reconcile this **4× disagreement** with the engine's recorded FPS monitor. This may reflect a 60-Hz sampling loop running inside a ~240-FPS renderer, rather than actual per-render-frame sampling. The source of the newly created `benchmark_stage1_windowed.gd` / its invocation method is **not committed** to the reviewed Git tree.

The dataset labels `walking`, `normal_combat`, `boss_combat` with 3,601 samples each, but **draw calls remain exactly 225 and nodes exactly 155 in all three sectors**. This alone does not prove that they are inactive, but without a benchmark source or runtime interaction/event trace, it does **not establish the claimed 60 seconds of actual walking/combat/boss stress**. Median FPS 240 and median frame interval 16.698 ms are not equivalent quantities.

**Required narrowly scoped correction:**
- Commit the exact capture/benchmark script and invocation commands used, with session scene, actual input/stage/boss state and sample type documented. If the script collected periodic snapshots rather than every rendered frame, rename the metric and do not claim continuous raw render-frame capture.
- Explain, with actual engine instrumentation, why the FPS field reports 239–240 while `dt_ms` reports ~16.7 ms. Recompute or qualify mean FPS, 1% low and P95 using a defensible method, preserve original CSV unchanged.
- Provide event/frame evidence that each named sector represents its claimed workload. If not possible, mark combat/boss sector performance `NOT_VERIFIED` and separately report the general windowed performance baseline. Do not infer Android performance.

## P1-B — Critical issue ledger is internally inconsistent and not governed

**Evidence:** `STUDIO_V3/evidence/V3-001/{BASELINE.md,QA_REVIEW.md,DIRECTOR_REVIEW.md,ISSUES.md,FINAL_EXECUTION_REPORT.md}`; `STUDIO_V3/queue.json`.

- `ISSUES.md` summary table contains **9 rows for only 7 unique issue IDs** because `ISSUE-V3-001-07` appears three times.
- `BASELINE.md` and `QA_REVIEW.md` say **6 issues: P1=2, P2=2, P3=2**, while the final report and Director review correctly include issue `-07` and say **7 unique issues: P1=3, P2=2, P3=2**.
- `ISSUE-V3-001-02` is labeled `RESOLVED (Decision: Option C)`, but the Z-axis code has **not** been changed. A design decision resolves the architecture question, not the reported gameplay discrepancy. Mark implementation `OPEN` or `DECIDED / IMPLEMENTATION_PENDING` and only resolve after play retest.
- `queue.json` has `V3-001.status=APPROVED`, `reviews` PASS but **`issues: []`**, while the attached game issue tracker contains multiple open P1 gameplay problems. The audit task can logically be accepted for **completeness of observation even when game defects exist**, but this distinction needs explicit recorded governance and a durable separate gameplay issue backlog; it must not be described as zero open game blockers.

**Required:** deduplicate issue summary, reconcile all reports to 7 unique issues/3 P1 until a verifiable fix, maintain a canonical game issue backlog with owner, status and evidence, and state plainly that `V3-001` audit acceptance is not Stage 1 functional/game-quality release acceptance. Do not erase the historic 6-issue QA text; append corrected addendum and exact new review.

## P1-C — Reviewer attestations are attached to later evidence content

**Evidence:** `STUDIO_V3/queue.json`, reported QA/Director timestamps and the document change sequence.

`PK_QALead` verdict is timestamped 2026-11-05T18:13:47Z; `PK_GameDirector` verdict is timestamped 18:18:26Z and **adds issue -07**. The recorded QA attestation includes SHA256 entries for final `ISSUES.md`, `DIRECTOR_REVIEW.md`, and `FINAL_EXECUTION_REPORT.md`, which incorporate later review or final packaging. The QA report itself still says six issues and does not inspect -07. This is not a dependable demonstration that the QA agent actually independently inspected the **exact final evidence version** to which its recorded hashes refer.

**Required:** freeze a final evidence SHA, obtain fresh independent QA verification of the final issue ledger, Director decision and performance-method correction, and record new reviewer completion metadata/attestations for that frozen evidence. Do not fabricate or backdate prior reviewer hashes.

## P2-D — Actual screenshot pixel review is not independently established here

The 11 PNG paths and binary blobs exist in GitHub, but the connected GitHub text/file tool cannot expose the decoded PNG content to this reviewer. Thus the external reviewer **cannot honestly certify** exact on-screen visual layout, scene occlusion or synthetic-vs-window authenticity from the filename, color count and textual assertions alone.

For auditable next submission, add unedited screenshot **SHA256/dimensions** to `capture_index.json` and, if necessary, attach a contact sheet or a small set of actual PNG files to the ChatGPT conversation for direct visual inspection. No replacement screenshots should be fabricated, and no fresh gameplay run is required merely because this interface did not decode repository PNGs.

## Acceptance path: ONE evidence-only correction pass

1. Do not alter any `CLIENT/Game/` code in V3-001. Keep the genuine 11 captures and raw CSV as immutable records.
2. Correct the audit's contradictory issue counts and status, and publish a canonical game backlog for V3-003.
3. Commit reproducible performance instrumentation source or downgrade claims with honest method/sector limits. No new 4-minute benchmark unless necessary to validate the claimed combat/boss load; do not invent 60FPS stress-test PASS.
4. Freeze the corrected evidence commit and have independent QA and Director review the same final artifacts, not retroactively hash their future contents.
5. Keep `V3-002` parent `FIX_REQUIRED` until separately rolled up through real governance. `V3-003` remains `BLOCKED` until both prerequisites are approved.
6. External reviewer will inspect only the corrected evidence and decision, not require another Studio V3 rebuild.

## Distinction between audit and game quality

- **Source-based gameplay route:** supported by code and run logs; external runtime not independently reproduced.
- **Screenshot presence:** VERIFIED; pixel-level content NOT DIRECTLY REVIEWED by this external reviewer.
- **Input and boss sequence:** supported by timestamped submission logs; not personally replayed.
- **PC 60FPS and boss stress:** DATA EXISTS, METHODOLOGY INCONSISTENT / NOT VERIFIED AS CLAIMED.
- **Option C design decision:** DOCUMENTED; gameplay Z-lock NOT IMPLEMENTED and is still an open implementation issue.
- **Game issue count:** **7 unique**, of which **3 P1**, 2 P2 and 2 P3; one P1 is implementation-pending rather than code-resolved.
- **V3-001 external audit decision:** **FIX_REQUIRED (evidence coherence only)**, even though its internal queue is already APPROVED.
- **V3-003:** BLOCKED by the parent V3-002 and pending external V3-001 evidence acceptance.

**Conclusion:** The audit collected credible new real-game evidence and established a useful design direction. The remaining work is to correct evidence semantics and governance, not to restart gameplay development or agent orchestration.
