# ProjectKnight Studio V3 — Evidence Attestation Closure

Updated: 2026-11-07
Branch: `studio/v3-001-attestation-close`
Baseline: `studio/v3-001-evidence-reconcile@0d99e2b0da5ecd30cff8641348ba4ed3e897423b`

## Confirmed progress
- Godot Stage 1 baseline artifacts: 11 original PNG captures, 14,404 raw physics-tick samples, input and startup logs. `CLIENT/Game/` unchanged by baseline/reconciliation work.
- Benchmark script was recovered: ~60Hz is physics sampling cadence, engine monitor data shows about 240 FPS in steady sectors; combat/boss differential load `NOT_VERIFIED`, Android `NOT_TESTED`.
- Official gameplay defect backlog: 7 unique (3 P1, 2 P2, 2 P3). Option C gameplay Z=0 plan selected **but not implemented**.
- `V3-001-EVIDENCE-RECONCILE` is **internally APPROVED**. External independent review still **FIX_REQUIRED**, specifically because three post-review files were tied to pre-review frozen SHA.

## One remaining evidence problem
- Frozen SHA `c55714745ac15776d5ffa449da6058da3dd777ea` contains 7 pre-review evidence files.
- SHA `0d99e2b0da5ecd30cff8641348ba4ed3e897423b` first adds `QA_ADDENDUM.md`, `DIRECTOR_ADDENDUM.md`, and `FINAL_RECONCILIATION_REPORT.md`.
- The old queue attests all 10 as source evidence at c557; this is inaccurate and requires append-only corrective lineage, not retroactive fake hashes.
- Producer's pasted completion summary also misnamed several canonical gameplay defects; GitHub `GAMEPLAY_ISSUE_BACKLOG.md` is authoritative.
- See `STUDIO_V3/reviews/V3-001-RECONCILE-INDEPENDENT-REVIEW.md`.

## Tasks
- **V3-001-ATTESTATION-CLOSE APPROVED internally:** 2-tier manifests isolated (7 source files in c557, 3 post-review in 0d99); 5/5 negative tests passed; canonical 7 defects verified; new independent QA/Director PASS at 7881e32df31353792f7ab8471c4f61bb75e22ebb; external review requested.
- V3-001-EVIDENCE-RECONCILE **historical internal APPROVED, external FIX_REQUIRED superseded by attestation-close**.
- V3-001 **historical internal APPROVED, external evidence acceptance pending**.
- V3-002-CLOSE **child APPROVED and externally accepted**.
- V3-002 **parent FIX_REQUIRED pending separate formal roll-up**.
- V3-003 **STRICTLY BLOCKED until V3-001 external evidence acceptance AND V3-002 parent formal approval**.

## Rules
No more architecture rebuild or re-benchmark by default. No edit to `CLIENT/Game/`, the prior 11 PNGs, original raw CSV or historical events. Corrected output review files are never falsely attributed to a source SHA that predates them. A correction cannot be treated as an externally accepted audit until independently verified.
