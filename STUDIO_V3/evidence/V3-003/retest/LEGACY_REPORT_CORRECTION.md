# V3-003 — Legacy Report Correction & Historical Classification

**Task ID:** `V3-003`  
**Working Branch:** `studio/v3-003-stage1-p1`  
**Date:** 2026-11-08  
**Scope:** Formal rectification of source commit SHA notation and test scope reclassification as required by `V3-003-INDEPENDENT-GAMEPLAY-REVIEW.md` (P1-05, P1-07).

---

## 1. Source Commit SHA Typo Rectification (P1-07)

In the initial iteration report (`FINAL_EXECUTION_REPORT.md` and related review documents at commit `3259e9a`), the Game Source Implementation Commit SHA was erroneously transcribed as:
- **Erroneous Notation:** `48ff5ef4a2e5d71c8db632d4b684cb32d20e7df6` *(Non-existent on GitHub)*
- **Authentic Git Commit SHA:** `48ff5efc68353bb493538924d33f27f364a74606`

### Provenance Verification:
- **Parent Commit:** `eda3ec4388434fdd6c742427cb014e0fb11425df`
- **True Implementation Commit:** `48ff5efc68353bb493538924d33f27f364a74606` (`feat(gameplay): implement Option C plane lock, mobile controls, and boss occlusion fix for Stage 1`)
- **Child Evidence Commit:** `5e785316d0cefc7fc0069278a75d1e4edb27f5b6` (`docs(evidence): freeze V3-003 Stage 1 gameplay before/after captures, telemetry and specifications`)
- **First Review Commit:** `3259e9a6d71522a3967c8b99f61dff307a4e9b24`

In accordance with Studio V3 audit immutability rules, past committed artifacts are preserved append-only without retroactive rebasing. This addendum serves as the authoritative cryptographic record linking the true commit `48ff5efc68353bb493538924d33f27f364a74606` to subsequent production records.

---

## 2. Test Harness Reclassification (P0-01)

The original verification harness (`CLIENT/Game/tests/v3_003_stage1_full_verification.gd`) is formally reclassified:
- **Original Classification Claimed:** `REAL_PLAY_VERIFIED` End-to-End Playthrough.
- **Audited Classification (Corrected):** `SCRIPTED_SCENARIO_SMOKE` (Automated physical position and scene inspection harness).
- **Audit Findings:** While valid for verifying Option C plane clamping ($Z=0.0$) and camera sightlines across static geometry, `v3_003_stage1_full_verification.gd` utilized synthetic position setup and scripted damage calls rather than a continuous, input-only user flow.
- **Replacement E2E Suite:** Fully replaced by `CLIENT/Game/tests/v3_003_real_input_e2e.gd`, which enforces 100% natural controller/keyboard/touch action inputs without teleports, direct HP mutation, or forced scene transitions.

---

## 3. Quantitative Sightline Occlusion Claim Qualification (P1-04)

- **Previous Notation:** Claimed reduction from $38.4\%$ to $0.0\%$ sightline occlusion.
- **Correction:** The values $38.4\%$ and $0.0\%$ represented qualitative design estimates rather than a reproducible algorithmic raycast or pixel-segmentation shader metric.
- **Official Specification:** Henceforth recorded as **`COMBAT_SIGHTLINE_VISUALLY_IMPROVED / QUANTITATIVE_OCCLUSION_NOT_VERIFIED`**.
- The physical relocation of `Pillar_FrontRight` to $(17.0, 0.0, 4.2)$ and lowering of `FrontBalustrade` to $0.42\text{m}$ remain verified in engine transforms, eliminating foreground obstruction across the active combat frustum as confirmed in visual review captures (`04_boss_spawn_full_sightline.png`).
