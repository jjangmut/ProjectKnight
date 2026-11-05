# V3-001 — Independent QA Review Report

**Task ID:** `V3-001`  
**Task Title:** Playable Baseline Audit & Gameplay Plane Decision  
**Reviewer:** `PK_QALead` (Independent QA Lead)  
**Date:** 2026-11-06  
**Audited Source Revision:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Branch:** `studio/v3-001-playable-baseline`  
**QA Verdict:** **QA PASS** (Certifies Audit Completeness & Evidence Integrity)

---

## 1. Executive QA Summary

TASK `V3-001` was executed as a strict read-only playable baseline audit of the Godot 4.7.2 game client (`CLIENT/Game/`), specifically targeting the playable baseline of Stage 1 (`SideQVStage1.tscn` via `SideQVCampaign.tscn`).

As Independent QA Lead, I conducted an exhaustive, multi-layered verification covering:
1. **Scope & Code Integrity:** Confirmed zero modifications were made to `CLIENT/Game/`.
2. **Functional QA:** Verified the full execution flow from `TitleScreen.tscn` to `SideQVStage1.tscn` and validated the execution of Input Matrix ACT-A through ACT-H.
3. **Visual QA:** Verified 11 unedited $1280 \times 720$ windowed screenshot captures, confirming authentic GL Compatibility rasterization, real-time lighting/shadows, and VFX clarity.
4. **Performance QA:** Verified 14,404 raw frame samples across 4 designated test sectors (Idle, Walking, Normal Combat, Boss Combat), validating rock-solid 60 FPS performance on PC and strict adherence to the Android `NOT_TESTED` reporting rule.
5. **Issue Registry:** Verified all 6 identified defects (2 P1, 2 P2, 2 P3) are documented in structured format with reproducible steps, expected vs. actual behavior, and evidence links in `ISSUES.md`.
6. **Gameplay Plane Decision:** Verified Option C (Visual 2.5D with Fixed 2D Gameplay Plane) was formally evaluated and authorized by `PK_GameDirector` in `DESIGN_DECISION.md`.

---

## 2. Scope & Working Directory Integrity Check

| Verification Item | Requirement | Measured / Observed | QA Status |
| :--- | :--- | :--- | :--- |
| **Target Codebase Modifications** | Zero file changes in `CLIENT/Game/` | `git diff --stat` returns 0 changes. `CLIENT/Game/` unmodified. | **PASS** |
| **Commit SHA Alignment** | Must match `a71223615d0b77e36dd85edb24e138fc67ecc140` | Exact commit SHA verified via `git log -n 1`. | **PASS** |
| **Artifact Delivery Directory** | Deliverables located in `STUDIO_V3/evidence/V3-001/` | All 6 primary artifact sets present and complete. | **PASS** |

---

## 3. Functional QA Verification

### 3.1 Transition Flow Audit
- **Default Main Scene:** `res://scenes/ui/TitleScreen.tscn` loaded without fatal crash.
- **Scene Routing:** Win32 click at coordinates $(880, 215)$ correctly invoked `Deploy 3D QV`, transitioning cleanly via `res://scenes/side_quarter_view/SideQVCampaign.tscn` into `res://scenes/side_quarter_view/SideQVStage1.tscn`.
- **Runtime Confirmation:** Verified console output: `>>> [CAMPAIGN] Loaded Stage 1: 성문 외곽 (Citadel Terrace Gate) <<<`.

### 3.2 Input Matrix Audit (ACT-A through ACT-H)
Every test scenario defined in the audit matrix was executed and cross-referenced with `windowed_playtest_raw.log`:

| Action ID | Matrix Test Item | Verified Functionality | Observed Status | Log & Capture Evidence | QA Evaluation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ACT-A** | Horizontal Movement (X) | Run right/left via `D`/`A` keys (`7.5 m/s`); camera smoothly tracks player; Sprite3D frame update active. | **FUNCTIONAL** | `windowed_playtest_raw.log:23-25`<br>[`02_idle_run.png`](captures/originals/02_idle_run.png) | **PASS** |
| **ACT-B** | Z-Depth Movement | Run forward/backward via `W`/`S` keys (`4.8 m/s`); rear balustrade and front curb collision boundaries hold player in $Z \in [-4.4, 4.4]$. | **FUNCTIONAL** (Discrepancy Noted) | `windowed_playtest_raw.log:26-29`<br>[`03_depth_occlusion.png`](captures/originals/03_depth_occlusion.png) | **PASS (Audited)** |
| **ACT-C** | Jump & Airborne Physics | Jump via `Space` (`jump_velocity: 6.8 m/s`); real-time shadow projection on 3D floor geometry; smooth landing. | **FUNCTIONAL** | `windowed_playtest_raw.log:30-32`<br>[`04_jump.png`](captures/originals/04_jump.png) | **PASS** |
| **ACT-D** | Melee Attack 3-Combo | 3-hit combo sequence via `J` key; combo counter updates; `SlashVisual3D` renders spear thrust VFX; enemy hurtbox hit detection active. | **FUNCTIONAL** | `windowed_playtest_raw.log:33-35`<br>[`05_attack_impact.png`](captures/originals/05_attack_impact.png) | **PASS** |
| **ACT-E** | Guard Barrier & Dash | Barrier activation via `K` key (`GuardBarrier3D` cyan torus); Dash evasion via `Shift` key (`14.0 m/s`). | **FUNCTIONAL** | `windowed_playtest_raw.log:36-38`<br>[`06_guard_dash.png`](captures/originals/06_guard_dash.png) | **PASS** |
| **ACT-F** | Minion Combat (Wave 1) | Wave 1 melee minions at $X=2.0, 4.0$; attack hits reduce HP from 4 to 0; enemy death signal emitted. | **FUNCTIONAL** | `windowed_playtest_raw.log:39-42`<br>[`07_enemy_wave.png`](captures/originals/07_enemy_wave.png) | **PASS** |
| **ACT-G** | Boss Wave & Combat | Advance notice triggered; Boss Commander spawns at $X > 8.0$; winged HP bar displays 24 HP; boss attack telegraphs and combat resolution verified. | **FUNCTIONAL** | `windowed_playtest_raw.log:43-51`<br>[`08_boss_telegraph.png`](captures/originals/08_boss_telegraph.png)<br>[`09_boss_combat.png`](captures/originals/09_boss_combat.png)<br>[`10_stage_result.png`](captures/originals/10_stage_result.png) | **PASS** |
| **ACT-H** | Mobile UI Overlays | CanvasLayer HUD elements present (unit plate, progress bar, combo HUD). Virtual D-pad / joystick and touch action buttons absent. | **DEFECT DETECTED** | `windowed_playtest_raw.log:22`<br>[`01_stage_entry.png`](captures/originals/01_stage_entry.png)<br>`ISSUE-V3-001-01` | **FAIL (Tracked as P1)** |

---

## 4. Visual QA Verification

Independent inspection of the captures folder (`STUDIO_V3/evidence/V3-001/captures/originals/`):

1. **Pixel Integrity & Resolution:**
   - All 11 captured images are verified to be exact $1280 \times 720$ resolution.
   - Unique color counts range from 18,295 (Title UI) to 147,857 (Combat with dynamic particles and lighting), confirming authentic GPU-rendered frames and not synthetic mockups.
2. **2D/3D Integration & Grounding:**
   - DirectionalLight3D real-time cast shadows accurately ground the 2D Paladin sprite onto the triplanar 3D flagstone floor.
   - Emissive glow on the central runic seal decal ($2.4 \times$ HDR bloom) blends smoothly into the environment fog without blinding the player.
   - Minor grounding artifact identified under extreme front curb positioning due to fixed-Y billboard perspective tilt; properly captured and registered as `ISSUE-V3-001-04` (P2).
3. **Combat Readability & Telegraphs:**
   - Paladin spear thrust streak (`SlashVisual3D`) and cyan runic shield barrier (`GuardBarrier3D`) provide instantaneous feedback.
   - Boss Commander telegraphs were observed: while crimson aura and groggy states are clear, shield charge windup was deemed slightly abrupt and tracked as `ISSUE-V3-001-05` (P3).
4. **UI Visual Hierarchy:**
   - Heroes War tactical HUD layout integrates cleanly into the $1280 \times 720$ landscape viewport, maintaining full combat visibility in the center and mid-ground.

---

## 5. Performance QA Verification

QA verified the performance dataset in `STUDIO_V3/evidence/V3-001/performance/`:
- **Sample Integrity:** `raw_frames.csv` contains 14,404 individual frame timestamps, delta times, process times, physics times, draw calls, and memory measurements across 240 seconds.
- **Benchmark Profile:**
  - **Mean Framerate:** $60.03\text{ FPS}$
  - **1% Low Framerate:** $59.46\text{ FPS}$ (Target $\ge 58.0\text{ FPS}$) $\rightarrow$ **PASS**
  - **P95 Frame Time:** $16.76\text{ ms}$ (Target $\le 17.5\text{ ms}$) $\rightarrow$ **PASS**
  - **P99 Frame Time:** $16.82\text{ ms}$ $\rightarrow$ **PASS**
  - **Draw Calls:** Mean $224.9$, Max $228$ (Target $\le 300$ for mobile/PC baseline) $\rightarrow$ **PASS**
  - **Static Memory:** $81.56\text{ MB}$ (Peak: $87.10\text{ MB}$, well within mobile budget) $\rightarrow$ **PASS**
  - **Stutter Spikes ($>33\text{ms}$):** Exactly 2 spikes observed during initial boot/first scene allocation; 0 spikes during normal or boss combat.
- **Mobile Specification Compliance:**
  - In accordance with RULE 8 / Baseline Protocol, Android status is explicitly and honestly recorded as `NOT_TESTED`.

---

## 6. Defect & Issue Tracking Audit

All 6 identified issues are correctly cataloged in `STUDIO_V3/evidence/V3-001/ISSUES.md`:

| Issue ID | Severity | Component | Summary | Remediation Plan |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-001-01** | **P1 (MAJOR)** | `side_qv_stage_base.gd` | Mobile UI overlay lacks virtual touch joystick and action buttons | Implement mobile touch controls in follow-up task prior to Android build |
| **ISSUE-V3-001-02** | **P1 (MAJOR)** | `SideQVPlayer.gd` / `SideQVCamera.gd` | 2.5D belt-scroll movement causes Z-axis whiffing and mobile friction | Formally decided: Option C selected for implementation in `V3-003` |
| **ISSUE-V3-001-03** | **P2 (MINOR)** | `audio_manager.gd` / `title_screen.gd` | `add_child()` called while node busy during boot | Use `add_child.call_deferred(manager)` |
| **ISSUE-V3-001-04** | **P2 (MINOR)** | `side_qv_player.gd` | Sprite3D fixed-Y billboard tilt causes minor curb penetration | Adjust sprite vertical offset / shader compensation |
| **ISSUE-V3-001-05** | **P3 (POLISH)** | `side_qv_boss.gd` | Boss Commander shield charge windup lacks pre-attack visual cue | Add 0.35s charge windup anticipation pose/flash |
| **ISSUE-V3-001-06** | **P3 (POLISH)** | `side_qv_campaign.gd` | Stage clear automatically transitions without dedicated victory modal | Implement Stage Clear modal summary in campaign loop |

*Note on Gate Policy:* Because TASK `V3-001` is strictly an audit and decision milestone, discovering and cataloging defects is the explicit deliverable of this task. Both P1 issues have documented resolutions and implementation assignments for subsequent tasks (`V3-003` onwards).

---

## 7. QA Recommendation & Next Steps

1. **Task V3-001 Verdict:** **QA PASS**. All acceptance criteria for the playable audit, capture suite, performance profiling, and design decision are completely satisfied.
2. **Milestone Recommendation:** Producer may advance to task closure and proceed with scheduling `V3-003` (2.5D Visual + 2D Horizontal Plane Constraint Implementation) and the Mobile Control Overlay task based on the approved Option C specification.

---

*QA Review executed and certified by PK_QALead on 2026-11-06.*
