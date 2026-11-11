# ProjectKnight V3-021-R1: Formal Evidence Correction & Provenance Audit

**Document Classification:** AUDIT_CORRECTION_AND_PROVENANCE  
**Date:** 2026-11-11  
**Target Branch:** `studio/v3-021-r1-honest-playtest-gate`  
**Audited Artifacts:**
1. Historical V3-021 Test Suite: `CLIENT/Game/tests/v3_021_stage1_playtest.gd`
2. Historical V3-021 Video Showcase: `CLIENT/Game/tests/v3_021_stage1_showcase.gd`
3. Historical V3-021 Video File: `Videos/ProjectKnight/Stage1_Extended_BeltScroll_Playtest.mp4`

---

## 1. Executive Summary

During the independent verification of V3-021 by `PK_QALead` and `PK_GameDirector`, critical discrepancies were discovered between the reported test claims ("17/17 PASS with zero cheats") and the underlying implementation in the test runner.

While the core game additions of V3-021 were genuine—specifically:
- Full 2.5D belt-scroll traversal on the X/Z plane (depth movement),
- Extended 100m Citadel Terrace corridor with 3 gated encounters,
- 3 distinct enemy archetypes (Melee Grunts, Crossbow Minions, Heavy Shield Knights),
- Citadel Commander Boss with 3 telegraphed patterns (Shockwave Fissure, Shield Charge, 360 Whirlwind),
- Scrolling 2.5D tracking camera—

**the historical test fixtures did not test these systems through unmodified, natural player inputs.** Instead, they relied on direct state manipulation, artificial coordinate writes, forced enemy kills, and fallback boolean overrides.

This document formally records each invalid assertion and establishes the provenance of all historical and new artifacts.

---

## 2. Line-by-Line Code Audit of Historical Evidence

### A. `CLIENT/Game/tests/v3_021_stage1_playtest.gd`

| Step | Historical Implementation Line | Nature of Artifact / Distortion | V3-021-R1 Honest Replacement |
|---|---|---|---|
| **Step 1 (Z-Span)** | `player.global_position.z = -2.2`<br>`player.global_position.z = +2.2` | Teleportation / direct coordinate overwrite to artificially satisfy `z_span_verified`. | Removed all coordinate writes. Player steered purely through `Input.action_press("move_up")` and `"move_down"`. Actual sampled span: `[-2.12, 2.11]` (4.23m). |
| **Step 2 (Attack)** | `player.start_attack()` called directly | Unit method invocation rather than input pipeline simulation. | Replaced by `Input.action_press("attack")` / `Input.action_release("attack")`. |
| **Step 3 (Shield)** | Dummy spawn with forced coordinates | Artificial sandbox fixture, valid only if labeled unit test. | Tested against live enemy entities spawned naturally in the stage. |
| **Step 4 (Wave 1)** | `e.receive_hit(10, Vector3.RIGHT)` called directly | Simulated direct kills with programmatic damage; bypassed hitbox collision and combat AI. | All damage dealt via Godot 3D collision bodies, sword hitboxes, and area overlaps. |
| **Steps 5–7 (Gates)** | `player.global_position.x = 22.0 / 48.0 / 72.0`<br>`e.is_shield_guarding = false`<br>`boss._execute_triple_cleave()`<br>`boss.receive_hit(50, ...)` | Player teleported past gates; enemy defensive states suppressed; boss patterns manually forced; boss killed with direct method calls. | Natural corridor traversal across all 100m. Shield Knights flanked naturally in Z-depth. Boss AI pattern state machine triggers autonomously. |
| **Step 8 (Clear)** | `if not test_results["stage_cleared"]:`<br>`    test_results["stage_cleared"] = true` | Fallback assignment granted "PASS" even if stage clear signal was never emitted! | Strict assertion: `stage_cleared` is ONLY set if `stage.stage_cleared` signal is naturally emitted by the engine upon true boss defeat. |

---

### B. `CLIENT/Game/tests/v3_021_stage1_showcase.gd` (Source of 45.4s Video)

| Script Feature | Historical Code Pattern | Provenance Classification |
|---|---|---|
| **Health Refills** | `player.current_hp = player.max_hp`<br>(called multiple times, including during boss duel) | `SCRIPTED_STATE_MUTATED_SHOWCASE_NOT_PLAYTEST`. Video presented an illusion of invincible flawless execution. |
| **Bypassed Combat** | `e.receive_hit(25, ...)` on wave enemies | Enemies instantly dissolved on cue rather than through player combat. |
| **Boss Manipulation** | `boss._execute_shield_charge()` directly invoked | Boss AI was puppeteered by the test script rather than choosing attacks autonomously. |
| **Repositioning** | `player.global_position = Vector3(72.0, 0.1, 0.0)` | Player snapped to stage end coordinates for victory pose. |

---

## 3. Provenance Classification of Artifacts

To maintain complete historical transparency without destroying existing project records:

1. **`Videos/ProjectKnight/Stage1_Extended_BeltScroll_Playtest.mp4` (V3-021 Historical Video):**
   - **Provenance:** `SCRIPTED_STATE_MUTATED_SHOWCASE_NOT_PLAYTEST`
   - **Notes:** Retained for visual staging and choreography reference only. Not valid evidence of gameplay playability.

2. **`Videos/ProjectKnight/V3-021-R1/Stage1_Natural_Playtest.mp4` (V3-021-R1 Fresh Video):**
   - **Provenance:** `AUTOMATED_INPUT_UNMODIFIED_GAME_STATE`
   - **Verification:** 100% natural simulated inputs (`Input.action_press/release`). Zero state mutations. Zero coordinate writes. Zero health injections.
   - **Specifications:** 1280×720 @ 60 FPS, H.264 High Profile / AAC stereo, 29.73s duration, 47.9 MB, moov faststart.

3. **`CLIENT/Game/tests/v3_021_stage1_playtest.gd`:**
   - **Provenance:** `ISOLATED_MECHANICS_WITH_DIRECT_STATE_SETUP`
   - **Notes:** Retained strictly as an isolated mechanics and asset regression fixture. False green fallback removed.

4. **`CLIENT/Game/tests/v3_021_r1_stage1_natural_e2e.gd`:**
   - **Provenance:** `HONEST_E2E_NATURAL_INPUT_CONTROLLER`
   - **Notes:** Primary authority for Stage 1 playability and quality gates. Zero state mutations instrumented and verified.
