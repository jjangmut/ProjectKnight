# ProjectKnight Studio V3 — Game Director Milestone Approval Review
## Task V3-009: Hands-On Combat Tuning & Mobile-Scale UI

- **Role / Evaluator:** PK_GameDirector (Product and Milestone Authority)
- **Task ID:** V3-009
- **Milestone:** Hands-On Combat Tuning & Mobile-Scale UI (Actual Game First)
- **Frozen Target Commit SHA:** `69203e0aa9e465e5368ccbbacc7575b058f0ff08`
- **Working Branch:** `studio/v3-009-combat-mobile-ui`
- **Base Commit:** `1e1b9893d56b0266da5bf1350a469fb5e94b0d0d`
- **Evaluation Date:** 2026-11-09
- **Determination:** **APPROVED**

---

## 1. Executive Summary & Product Vision Evaluation

As the Product and Milestone Authority of ProjectKnight Studio V3, I have conducted the formal, independent Milestone Authority Review for **Milestone V3-009 (Hands-On Combat Tuning & Mobile-Scale UI)** on branch `studio/v3-009-combat-mobile-ui`, evaluated strictly against frozen commit SHA `69203e0aa9e465e5368ccbbacc7575b058f0ff08`.

### 1.1 Gameplay-First Combat & Usability Mandate
Milestone V3-009 was chartered under the strict instruction to prioritize **player-observable combat responsiveness** and **mobile-scale interface usability** over theoretical meta-governance or premature packaging. Following the 5-stage campaign assembly in V3-007 and the initial playability polish in V3-008, actual hands-on gameplay inspections revealed critical moment-to-moment control locks, input drops, and missing virtual controls that hindered player enjoyment and accessibility.

The targeted modifications committed in frozen SHA `69203e0aa9e465e5368ccbbacc7575b058f0ff08` directly eliminate these bottlenecks:
1. **Attack Recovery Cancel into Dash / Guard (P1 Combat Feel):** When the active strike hitbox concludes (`attack_duration_remaining <= 0.14s`), player inputs for Dash or Guard immediately cancel the remaining recovery frames. Players are no longer defenselessly locked into attack animations when boss telegraphs manifest.
2. **Dash Input Buffering (0.16s) & Single-Use Air Dash (P1 Combat Mobility):** A dedicated 160ms Dash input buffer guarantees that evasive maneuvers pressed during hit-stun or recovery are never swallowed. A crisp single-use Air Dash, refreshed upon ground contact, enables vertical dodging of ground shockwaves and low hazards.
3. **Dedicated Mobile Virtual Controls Deck Across Stages 1–5 (P1 Mobile Usability):** `SideQVStageBase` now mounts the interactive `TouchControlsDeck` (`QVMobileControls`) directly into `mobile_controls`, exposing responsive virtual joystick and tactical combat buttons (Strike, Parry, Dash, Leap) across all five campaign stages.
4. **Responsive Dynamic UI Anchoring (P2 UI Legibility):** `QVMobileControls` now dynamically repositions container offsets based on viewport dimensions (`maxf(680.0, vp_size.x - 265.0)`), maintaining the 1280x720 baseline layout while preventing buttons from clipping off-screen on narrower viewports (e.g., 1024x720).
5. **Campaign Loop Full Closure (P2 Campaign Flow):** The complete cycle of Victory Screen $\rightarrow$ Return to Title $\rightarrow$ Second Campaign Start was thoroughly validated in real-input E2E testing with clean scene reloading and zero signal leakage.

All modifications preserve Option C 2D gameplay plane integrity ($Z = 0.0000, v_z = 0.0000$) across 1,323 continuous telemetry samples with zero artificial cheats.

---

## 2. Game Director 10-Category Visual & Gameplay Quality Scorecard

In accordance with ProjectKnight Production Rules (RULE 3: Quality Gate Average $\ge 8.5$, No critical category < 8.0; Vertical Slice target $\ge 9.0$), an independent evaluation was conducted across all 14 captured viewport frames and real-input execution logs:

| No. | Visual & Gameplay Evaluation Category | Score (/10) | Game Director Assessment & Quality Notes |
|:---:|---|:---:|---|
| 1 | **2D Character Readability** | **9.5** | High-contrast knight sprite remains instantly legible against all backgrounds (Stages 1–5). Dash ghost trails and attack recovery cancels give the player sharp, unmistakable state feedback. |
| 2 | **3D Environment Quality** | **9.3** | Architectural fidelity across all 5 biomes (Citadel, Beastwood, Crossbow Bastion, Titan Sanctuary, Abyssal Citadel) maintains rich visual depth, stonework texture, and atmospheric lighting. |
| 3 | **2D / 3D Integration** | **9.4** | Contact shadows, particle impacts, and glowing telegraph rings anchor the 2D sprites convincingly into the 3D world space without depth clipping or jitter. |
| 4 | **Grounding & Footing** | **9.4** | Perfect floor adhesion and landing collision. Air Dash cleanly transitions into grounded states upon contact, reliably resetting the air-dash capability flag without floating artifacts. |
| 5 | **Lighting & Value Hierarchy** | **9.3** | Radiant telegraph emission (crimson-gold 4.8x energy) continues to cut through dark violet and obsidian stage geometry. UI overlays maintain high contrast against dynamic stage lights. |
| 6 | **Depth & Atmospheric Fog** | **9.3** | Multi-plane parallax and depth separation keep the combat plane ($Z=0.0$) in clear visual focus while background colonnades and vistas provide expansive scale. |
| 7 | **Gameplay & Combat Readability** | **9.6** | The 0.14s attack recovery cancel fundamentally transforms combat flow: players can aggressively commit to combos while retaining split-second defensive reactions against boss telegraphs. |
| 8 | **Platform & Arena Boundaries** | **9.4** | Option C strict coplanar lock ($Z=0.0000$) verified over 1,323 continuous samples. Arena boundaries, wall collisions, and ceiling caps operate flawlessly during air dashes. |
| 9 | **Composition, Camera & UI Polish** | **9.4** | Dynamic responsive anchoring (`maxf(680.0, vp_size.x - 265.0)`) cleanly positions virtual joystick and action buttons at both 1280x720 and 1024x720, completely eliminating off-screen button clipping. |
| 10 | **Commercial Impression & Combat Juice** | **9.5** | The synergy of 80ms parry hit-stop, attack cancel into dash/guard, dash input buffering, and seamless Title $\rightarrow$ Campaign $\rightarrow$ Victory $\rightarrow$ Title looping achieves AAA indie vertical slice polish. |
| -- | **OVERALL DIRECTOR AVERAGE** | **9.41 / 10.0** | **QUALITY GATE FULLY SATISFIED (Target $\ge 9.0$, Critical $\ge 8.0$)** |

---

## 3. Deep-Dive Mechanical & Usability Verification

### 3.1 Combat Responsiveness & Input Buffering (Issue 1)
- **Problem Diagnosed:**
  - In earlier versions, `State.ATTACK` held absolute priority over player inputs for the entire animation duration (0.28s–0.32s). When an enemy initiated a heavy attack during recovery, players were unable to dodge or guard despite recognizing the telegraph.
  - While jump and attack had 0.16s input buffers, Dash had zero buffering. Inputs tapped 50ms before landing or before attack recovery ended were dropped.
  - Air dash was inadvertently prevented by an unconditional `is_on_floor()` check.
- **Implemented Fix in `side_qv_player.gd`:**
  - **Attack Recovery Cancel:** Added recovery cancel window `if attack_duration_remaining <= 0.14:`. If Dash or Guard is triggered during this window, `slash_visual_3d` is hidden, `is_attacking` is cleared, and `start_dash()` or `start_guard()` is initiated immediately.
  - **Dash Input Buffer:** Introduced `dash_buffer_timer` (`DASH_BUFFER_TIME = 0.16s`), updated in `_update_timers()`. Buffered dash inputs are consumed seamlessly during movement and recovery cancel states.
  - **Single-Use Air Dash:** Introduced `can_air_dash: bool = true`, consumed when dashing in mid-air (`global_position.y > 0.35`), and refreshed in `_on_landed_on_floor()`.
- **Verification Proof:**
  - Automated test `v3_009_combat_and_mobile_verification.gd` confirmed all assertions (`dash_input_buffer_verified = true`, `attack_recovery_dash_cancel_verified = true`, `attack_recovery_guard_cancel_verified = true`, `air_dash_execution_verified = true`, `air_dash_landing_refresh_verified = true`).
  - Viewport captures: `captures/before/before_01_attack_recovery_lock.png` vs `captures/after/after_01_attack_recovery_cancel.png`.

### 3.2 Mobile Virtual Controls Deck Integration (Issue 2)
- **Problem Diagnosed:**
  - `SideQVStageBase` constructed a `CanvasLayer` named `SideQVMobileUI` with player status plates and boss health gauges, but never instantiated the interactive `QVMobileControls` node. Players on touch-enabled interfaces had zero virtual input devices.
- **Implemented Fix in `side_qv_stage_base.gd`:**
  - Instantiated `touch_controls = QVMobileControlsClass.new()` named `TouchControlsDeck` and attached it as a direct child of `mobile_controls` across all 5 stages.
  - Virtual joystick routes analog directional inputs (`move_left`, `move_right`, `move_down`), while tactical buttons expose four essential combat actions: ⚔ STRIKE, 🛡 PARRY, 💨 DASH, ▲ LEAP.
- **Verification Proof:**
  - Verified across all 5 stages in both isolated test and continuous E2E runs.
  - Viewport captures: `captures/before/before_02_mobile_ui_missing_in_stage.png` vs `captures/after/after_02_mobile_touch_deck.png`.

### 3.3 Dynamic Responsive Viewport Layout (Issue 3)
- **Problem Diagnosed:**
  - `QVMobileControls` previously placed its action container at hardcoded absolute coordinates `(1015.0, 535.0)`. On viewports narrower than 1280px (e.g., 1024x720, or tablet aspect ratios), buttons were clipped past the right screen boundary (`1015 + 88 = 1103px`).
- **Implemented Fix in `qv_mobile_controls.gd`:**
  - Implemented `_update_layout()`, connected to `get_viewport().size_changed`.
  - Dynamically calculates container positions based on current viewport geometry:
    - Joystick: `Vector2(145.0, vp_size.y - 185.0)`
    - Action Deck: `Vector2(maxf(680.0, vp_size.x - 265.0), vp_size.y - 185.0)`
    - Toggle Button: `Vector2(maxf(720.0, vp_size.x - 242.0), 14.0)`
  - At 1280x720: Action container resolves to `Vector2(1015.0, 535.0)` (exact baseline preserved).
  - At 1024x720: Action container resolves to `Vector2(759.0, 535.0)` (safely anchored within screen bounds, zero clipping).
- **Verification Proof:**
  - Automated verification verified position at 1280px `(1015.0, 535.0)` and 1024px `(759.0, 535.0)`.
  - Viewport captures: `captures/before/before_03_narrow_viewport_hud.png` vs `captures/after/after_03_narrow_viewport_responsive.png`.

### 3.4 Boss Threat Window & Reaction Time Audit
In compliance with task specifications, threat windows (elapsed duration from warning startup to damage impact) were measured using precise timestamp telemetry:

| Boss / Hazard | Attack Pattern | Warning Startup | Damage Impact | Measured Threat Window | Human Visual Reaction Viability ($\ge 250\text{ms}$) | Observation Provenance |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Abyssal Arbiter** (Stage 5) | Shadow Blink Strike | 0.00s (Crimson aura ring) | +0.30s (Scythe slash arc) | **300 ms** | **PASS** (Viable counterplay) | Natural E2E & Isolated Fixture |
| **Abyssal Arbiter** (Stage 5) | Dark Crescent Wave | 0.00s (Dark charge aura) | +0.32s (Wave release) | **320 ms** | **PASS** (Viable counterplay) | Isolated Polish Fixture |
| **Golem Guardian** (Stage 2) | Ground Slam Shockwave | 0.00s (Arms raised telegraph) | +0.42s (Ground impact) | **420 ms** | **PASS** (Generous jump/air-dash) | Natural E2E & Isolated Fixture |

All three boss threat windows comfortably exceed the human visual reaction threshold ($200\text{--}250\text{ms}$), providing fair, readable reaction windows for defensive play.

### 3.5 Full Campaign Loop Smoke (Title $\rightarrow$ Stages 1–5 $\rightarrow$ Victory $\rightarrow$ Title $\rightarrow$ Second Run)
A continuous, end-to-end real-input smoke test (`CLIENT/Game/tests/v3_009_campaign_and_loop_smoke.gd`) was executed against the live engine:
1. **Initial Deployment:** Dispatched real `InputEventMouseButton` to the Title Screen Deploy button center `(971.5, 216.0)`. `btn_new_game.pressed` fired cleanly (`title_button_pressed_signal_count = 1`).
2. **5-Stage Natural Clears:**
   - Stage 1 cleared at $t = 7.61\,\text{s}$.
   - Stage 2 cleared at $t = 16.82\,\text{s}$.
   - Stage 3 cleared at $t = 25.53\,\text{s}$.
   - Stage 4 cleared at $t = 35.31\,\text{s}$.
   - Stage 5 entered naturally at $t = 37.13\,\text{s}$.
3. **Stage 5 Natural Combat & Boss Defeat:**
   - Both Elite Knights defeated naturally (`unique_minions_killed_count = 2`, instance IDs `[124033959618, 124319172773]`).
   - Abyssal Arbiter spawned with initial HP 38/38, poised at 18.
   - Arbiter executed Shadow Blink Strike naturally (`stage5_boss_blink_seen_e2e = true`) and Judgment Storm (`stage5_boss_storm_seen_e2e = true`).
   - Phase 2 triggered at HP 17.
   - Boss naturally defeated at $t = 48.93\,\text{s}$ (HP reached -1). Zero cheats, zero damage injection.
4. **Campaign Completion & Victory Panel:**
   - `SideQVCampaign.campaign_completed` signal fired exactly once (`count = 1`).
   - `CampaignVictoryPanel` appeared with functional Replay and Title buttons.
5. **Return to Title Screen:**
   - Dispatched click to `ReturnTitleButton`. `TitleScreen` node instantiated cleanly into root scene tree at $t = 51.12\,\text{s}$ (`11_return_to_title_screen.png`).
6. **Second Campaign Start:**
   - Dispatched click to `btn_new_game` on the fresh Title Screen at $t = 51.19\,\text{s}$.
   - `SideQVCampaign` successfully reloaded and Stage 1 initialized cleanly at $t = 51.22\,\text{s}$ (`12_second_campaign_start.png`).
   - Complete absence of dangling signals, stale timer states, or node memory leaks.

---

## 4. Evidence & Technical Integrity Audit

### 4.1 Telemetry & Option C Z-Lock Conformance
- Inspected `ACTOR_Z_PRESENCE.csv` containing **1,323 continuous runtime telemetry samples** recorded during the real-input E2E run.
- Telemetry evaluation across all participating actors (Player, Elite Knights, Abyssal Arbiter):
  $$\min(pos\_z) = 0.0000, \quad \max(pos\_z) = 0.0000$$
  $$\min(vel\_z) = 0.0000, \quad \max(vel\_z) = 0.0000$$
  - Exactly **0 non-zero Z violations** across all 1,323 samples ($100.0\%$ strict Option C adherence).

### 4.2 Automated Fixture Execution Status
All test suites executed against `Godot Engine v4.7.2.stable.official.ed1daf0bf` with OpenGL3 Compatibility driver on an NVIDIA GeForce RTX 5060 Laptop GPU:

| Test Suite | Command / Fixture | Exit Code | Assertions / Result |
| :--- | :--- | :---: | :---: |
| **Baseline Capture Fixture** | `tests/v3_009_capture_before.gd` | **0** | Captured 3 pre-change frames |
| **Combat & Mobile Verification** | `tests/v3_009_combat_and_mobile_verification.gd` | **0** | All 11 assertions passed |
| **Campaign & Loop Smoke** | `tests/v3_009_campaign_and_loop_smoke.gd` | **0** | Complete 5-stage clear + Title + 2nd start passed |

### 4.3 High-Resolution Viewport Capture Verification
All 14 captured PNG frames in `STUDIO_V3/evidence/V3-009/captures/` verified for pixel dimensions, 32-bit RGBA color mode, and visual composition:
- **Baseline (Before) Captures (3 frames):**
  - `before/before_01_attack_recovery_lock.png` ($1280 \times 720$)
  - `before/before_02_mobile_ui_missing_in_stage.png` ($1280 \times 720$)
  - `before/before_03_narrow_viewport_hud.png` ($1024 \times 720$)
- **Polished (After) Captures (3 frames):**
  - `after/after_01_attack_recovery_cancel.png` ($1280 \times 720$)
  - `after/after_02_mobile_touch_deck.png` ($1280 \times 720$)
  - `after/after_03_narrow_viewport_responsive.png` ($1024 \times 720$)
- **End-to-End Campaign Journey Captures (8 frames):**
  - `captures/01_title_deploy_click.png` ($1280 \times 720$)
  - `captures/01_stage5_natural_entry.png` ($1280 \times 720$)
  - `captures/02_stage5_both_elite_knights.png` ($1280 \times 720$)
  - `captures/03_stage5_boss_spawn.png` ($1280 \times 720$)
  - `captures/09_stage5_boss_natural_defeat.png` ($1280 \times 720$)
  - `captures/10_stage5_clear_campaign_victory.png` ($1280 \times 720$)
  - `captures/11_return_to_title_screen.png` ($1280 \times 720$)
  - `captures/12_second_campaign_start.png` ($1280 \times 720$)

---

## 5. Honest Platform Scope & Operational Disclosures

In strict adherence to ProjectKnight production honesty rules:

1. **Android Physical Hardware Status: `ANDROID_HARDWARE_NOT_TESTED`**
   - The virtual controls deck and responsive layout logic were validated using Godot 4.7.2 GL Compatibility windowed desktop emulation ($1280 \times 720$ and $1024 \times 720$).
   - Physical ARM Android execution, touch-screen hardware digitizer latency, mobile GPU shader quirks (e.g., Mali/Adreno OpenGLES drivers), battery thermal throttling, and hardware display notches/cutouts have **NOT** been evaluated on physical Android devices.
2. **Human Playtest Status: `HUMAN_PLAYTEST_NOT_VERIFIED`**
   - All tests were executed deterministically via Godot engine input injection (`InputEventMouseButton`, `Input.action_press()`). While zero artificial cheats were used, comprehensive tactile playtesting by diverse human players with physical gamepads or touchscreens has not yet been conducted.
3. **Commercial Release Scope: `COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**
   - ProjectKnight is currently an approved 5-stage vertical slice demonstrating Option C 2.5D mechanics, responsive melee combat, and progressive difficulty.
   - Release features such as full audio mixing/SFX polish, localization, cloud save integration, graphics settings menus, and Google Play Store packaging remain scheduled for future production phases.
4. **Boss Threat Window Observation Provenance:**
   - In continuous E2E runs, Abyssal Arbiter Shadow Blink Strike, Judgment Storm, and Melee Cleave occurred naturally (`stage5_boss_blink_seen_e2e = true`, `stage5_boss_storm_seen_e2e = true`).
   - Abyssal Arbiter Dark Crescent Wave and Golem Guardian Ground Slam threat windows were separately verified under isolated test fixtures.

---

## 6. Issue Tracking & Resolution

All issues targeted for Milestone V3-009 have been conclusively resolved:

| Issue ID | Severity | Category | Summary | Status | Resolution File |
| :--- | :---: | :---: | :--- | :---: | :--- |
| **V3-009-ISSUE-01** | **P1 (MAJOR)** | Combat Feel | Attack animation recovery locked player for full duration, ignoring dodge/guard. Dash input buffer was missing. Air dash was blocked. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` |
| **V3-009-ISSUE-02** | **P1 (MAJOR)** | Mobile Usability | `SideQVStageBase` omitted instantiating `QVMobileControls`, leaving Stages 1–5 without on-screen virtual touch controls. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` |
| **V3-009-ISSUE-03** | **P2 (MINOR)** | UI Responsiveness | Absolute coordinates `(1015, 535)` caused skill buttons to clip past the right border on narrower viewports (1024x720). | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-009-ISSUE-04** | **P2 (MINOR)** | Campaign Flow | Return-to-Title route and subsequent second campaign restart lacked continuous smoke test validation. | **RESOLVED** | `CLIENT/Game/tests/v3_009_campaign_and_loop_smoke.gd` |

- **Active P0 / P1 Issues Remaining:** **0**
- **Non-blocking Polish Backlog:**
  - `BACKLOG-V3-010-01` (P2): Virtual joystick floating/dynamic touch anchor option for thumb ergonomics.
  - `BACKLOG-V3-010-02` (P2): Distinct audio feedback on air-dash consumption vs grounded dash.
  - `BACKLOG-V3-010-03` (P3): Haptic vibration trigger on mobile virtual button tap.

---

## 7. Milestone Authority Determination & Formal Sign-Off

### 7.1 Review Summary
Milestone V3-009 delivers meaningful, player-centric enhancements to moment-to-moment combat responsiveness, mobility options, and mobile-scale interface usability. The implementation of attack recovery cancels into dash and guard, paired with the 160ms dash buffer and air dash, fundamentally elevates combat responsiveness to commercial standards. The integration of `TouchControlsDeck` across Stages 1–5 and its dynamic responsive anchoring resolve long-standing mobile usability gaps. The end-to-end Title $\rightarrow$ Campaign $\rightarrow$ Victory $\rightarrow$ Title $\rightarrow$ Second Campaign loop is clean, stable, and completely leak-free.

### 7.2 Formal Gate Decision
- **Scorecard Quality Average:** **9.41 / 10.0** (Quality Gate: $\ge 8.5$, Vertical Slice Target: $\ge 9.0$) $\rightarrow$ **PASS**
- **Critical Category Thresholds:** All categories $\ge 9.3$ (Gate: $\ge 8.0$) $\rightarrow$ **PASS**
- **Option C Planar Adherence:** 1,323 / 1,323 samples with $Z = 0.0000, v_z = 0.0000$ $\rightarrow$ **PASS**
- **Boss Threat Windows:** Arbiter Blink 300ms, Crescent 320ms, Golem Slam 420ms (All $\ge 250\text{ms}$) $\rightarrow$ **PASS**
- **Campaign Loop Closure:** Full Title $\rightarrow$ Stages 1–5 $\rightarrow$ Victory $\rightarrow$ Title $\rightarrow$ Second Start validated $\rightarrow$ **PASS**
- **Zero Cheats / Clean Telemetry:** Zero damage injection, natural clears verified $\rightarrow$ **PASS**
- **Unresolved P0 / P1 Issues:** Exactly 0 remaining $\rightarrow$ **PASS**

### 7.3 Final Determination
$$\mathbf{DETERMINATION: \; APPROVED}$$

Milestone **V3-009 (Hands-On Combat Tuning & Mobile-Scale UI)** is hereby formally **APPROVED** by the Game Director as the Product and Milestone Authority.

---

*Signed,*  
**PK_GameDirector**  
Product and Milestone Authority, ProjectKnight Studio V3  
Evaluation Commit: `69203e0aa9e465e5368ccbbacc7575b058f0ff08`
