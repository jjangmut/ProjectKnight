# V3-003 — Playability Retest Result Matrix

**Task ID:** `V3-003`  
**Working Branch:** `studio/v3-003-stage1-p1`  
**Date:** 2026-11-08  
**Audit Standard:** `STUDIO_V3/reviews/V3-003-INDEPENDENT-GAMEPLAY-REVIEW.md` & `STUDIO_V3/tasks/V3-003-PLAYABILITY-RETEST.md`  

---

## 1. Defect Remediation & Verification Matrix

| Issue ID | External Review Finding | Retest Resolution & Code Implementation | Verification Method & Observed Metric | Retest Verdict |
| :--- | :--- | :--- | :--- | :---: |
| **P0-01** | Scripted test used player teleport, forced boss HP mutation, direct `receive_hit()`, and lacked assert gates for genuine E2E clear. | Developed `v3_003_real_input_e2e.gd`: 100% natural controller inputs. Title deploy button click $\rightarrow$ Wave 1 natural kills $\rightarrow$ Boss HP 24 $\rightarrow$ 0 through melee/parry $\rightarrow$ Stage 1 clear signal $\rightarrow$ Stage 2 load. | Executed in 1280×720 OpenGL Compatibility mode. Full run completed in $10.28\text{s}$ ($617$ ticks). Exit code 0. Zero teleports, zero direct HP sets, zero `receive_hit` calls. | **RESOLVED (PASS)** |
| **P1-02** | Touch test only sent joystick press on index 0. Four action buttons and multi-touch concurrency unverified; potential cross-device action ownership conflict. | Implemented virtual action tracking and hardware-press checking in `qv_mobile_controls.gd`. Enhanced `_input()` to map multi-touch coordinates to action buttons. Created `v3_003_real_touch_ui.gd`. | Real `InputEventScreenTouch` dispatched to button hit rects. Multi-touch index 0 (joystick) + index 1 (Strike/Leap) confirmed. Zero stuck inputs upon release. Keyboard hold preserved during virtual touch release. Exit code 0. | **RESOLVED (PASS)** |
| **P1-03** | Boss shield charge state machine moved and dealt damage during the 0.42s telegraph before windup timer elapsed. | Separated state machine in `side_qv_boss.gd` into `CHARGE_WINDUP` and `CHARGE_ACTIVE`. In windup: $v_x = 0$, $v_z = 0$, hitbox monitoring off, $0.42\text{s}$ duration. Rush motion and hitbox only engage in `CHARGE_ACTIVE`. Stun/parry cleanly cancels charge. | Executed `v3_003_boss_charge_timing.gd`. Measured windup duration: $0.4333\text{s}$ ($\ge 0.42\text{s}$). Measured windup displacement: $0.000000\text{m}$. Parry stun cancellation verified. Exit code 0. Logged in `BOSS_WINDUP_TIMELINE.csv`. | **RESOLVED (PASS)** |
| **P1-04** | Quantitative sightline occlusion reduction ($38.4\% \rightarrow 0.0\%$) was declared without reproducible pixel segmentation or raycast algorithm. | Rectified claim in `LEGACY_REPORT_CORRECTION.md` to `COMBAT_SIGHTLINE_VISUALLY_IMPROVED / QUANTITATIVE_OCCLUSION_NOT_VERIFIED`. Authored `BOSS_SIGHTLINE_VISUAL_REVIEW.md` evaluating real in-combat captures. | Screenshots `04_boss_spawn_full_sightline.png` and `05_boss_combat_parry_strike.png` confirm hero and boss silhouettes remain $100\%$ unoccluded in active combat zone. Flanking pillars at $X = \pm 17.0$ and lowered balustrade ($0.42\text{m}$) visually verified. | **RESOLVED (PASS)** |
| **P1-05** | Telemetry logged $Z = 0.0$ even when enemies/boss were absent, creating false presence data. Z-clamp bypassed on early-return state paths. | Clamped $Z=0.0$ and $v_z=0.0$ on all early-return paths (stunned, attacking, dead, groggy) in `side_qv_boss.gd`, `side_qv_enemy.gd`, and `side_qv_player.gd`. Updated telemetry to log `NA` when actors are absent. | `Z_PLANE_ACTOR_PRESENCE.csv` correctly logs `NA` prior to spawn and after defeat. During active presence across all 212 recorded samples, max $|Z|$ drift = $0.0000\text{m}$ and max $|v_z|$ drift = $0.0000\text{m/s}$. | **RESOLVED (PASS)** |
| **P1-07** | Game Source Implementation commit SHA in prior execution report contained a typo (`...48cb...` instead of true Git SHA `...64a7...`). | Formally documented and corrected in `LEGACY_REPORT_CORRECTION.md` and `SOURCES_AND_HASHES.json`. Authentic source commit confirmed as `48ff5efc68353bb493538924d33f27f364a74606`. | Verified in Git object database: commit `48ff5efc68353bb493538924d33f27f364a74606` exists on branch and contains the exact Option C, mobile HUD, and level geometry modifications. | **RESOLVED (PASS)** |

---

## 2. Test Execution Summary

| Test Suite File | Engine & Target | Execution Mode | Duration / Samples | Exit Code | Result Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `v3_003_boss_charge_timing.gd` | Godot 4.7.2 Console | Headless | 18 ticks ($0.52\text{s}$) | `0` | **ALL CHECKS PASSED** |
| `v3_003_real_touch_ui.gd` | Godot 4.7.2 Console | Headless | 15 steps ($2.85\text{s}$) | `0` | **ALL CHECKS PASSED** |
| `v3_003_real_input_e2e.gd` | Godot 4.7.2 Console | Windowed 1280×720 OpenGL | 617 ticks ($10.28\text{s}$) | `0` | **ALL CHECKS PASSED** |
