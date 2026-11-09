# ProjectKnight Studio V3 — Game Director Milestone Approval Review
## Task V3-013: Player-Controlled Defeat, Retry & Campaign Recovery

- **Role / Evaluator:** PK_GameDirector (Product and Milestone Authority)
- **Task ID:** V3-013
- **Milestone:** Player-Controlled Defeat, Retry & Campaign Recovery (Game First)
- **Frozen Target Commit SHA:** `f44bdc956b109847796fb26d23ab23838554f047` (short: `f44bdc9`)
- **Working Branch:** `studio/v3-013-failure-retry-gameplay`
- **Base Commit:** `dc26797282b0e8aeebdbfef8d3c50005d5bbd1f9` (docs(v3-013): assign task) / `b11aec0ecd495f9b284073315fb63b40a4dba5c9` (V3-012 review & state HEAD)
- **Repository:** `jjangmut/ProjectKnight`
- **Evaluation Date:** 2026-11-09
- **Determination:** **APPROVED**

---

## 1. Executive Summary & Product Vision Evaluation

As the Product and Milestone Authority of ProjectKnight Studio V3, I have conducted the formal independent milestone quality gate review for **Milestone V3-013 (Player-Controlled Defeat, Retry & Campaign Recovery)** on branch `studio/v3-013-failure-retry-gameplay`, evaluated strictly against frozen implementation commit SHA `f44bdc956b109847796fb26d23ab23838554f047`.

### 1.1 Transition from Prototype Loss to Player-Centric Recovery
Prior to Milestone V3-013, the game's defeat flow was a glaring prototype relic:
1. **Unprompted 2-Second Auto-Reload:** When the player's HP dropped to 0, `side_qv_campaign.gd` printed a console string, waited an arbitrary 2.0 seconds via an unmanaged timer (`await get_tree().create_timer(2.0).timeout`), and forcibly reloaded the stage. The player was given zero agency: no opportunity to pause, evaluate their defeat, choose to retry, or retreat to the main title screen.
2. **Post-Mortem Combat Glitching & Input Confusion:** Upon death, the virtual touch deck remained rendered on screen, virtual action states remained stuck pressed, and active enemies/bosses continued attacking the player's corpse. This resulted in sustained phantom hit sounds, repeated damage triggers, and physics jittering during defeat.
3. **Rigid, Off-Center Dialog Geometry:** Modal dialogs relied on hardcoded pixel coordinates (`position = Vector2(320, 190)`), causing noticeable right-side clipping and layout deformation when rendered on compact or tablet aspect ratios (such as 1024x720).
4. **Transition Deadlocks on Victory:** A subtle state defect (`is_transitioning` remaining true when displaying victory) blocked button clicks on campaign victory, preventing clean replay or return-to-title navigation.

Milestone V3-013 resolves every one of these player-facing defects cleanly and robustly within the production codebase. The unprompted auto-reload is entirely replaced by a crimson-themed, highly readable `StageFailedOverlay`. Combat is immediately neutralized upon death, virtual inputs are released and hidden, campaign progress is rigorously preserved on retry (single-stage reload without wiping `cleared_stages`), and both defeat and victory dialogs are dynamically centered across 1280x720 and 1024x720 viewports using responsive `CenterContainer` architecture.

---

## 2. Game Director 10-Category Visual & Gameplay Quality Scorecard

In accordance with ProjectKnight Production Rules (RULE 3: Quality Gate Average >= 8.5, No critical category < 8.0; Vertical Slice target >= 9.0), an independent evaluation was conducted across all rendered frames, recovery flows, and execution telemetry:

| No. | Visual & Gameplay Evaluation Category | Score (/10) | Game Director Assessment & Quality Notes |
|:---:|---|:---:|---|
| 1 | **Defeat Presentation & Visual Hierarchy** | **9.6** | The defeat modal commands immediate visual authority. Stylized crimson border (`Color(0.95, 0.25, 0.25, 0.9)`), deep charcoal background (`Color(0.08, 0.04, 0.05, 0.94)`), 8px rounded corners, and clear typographic hierarchy (`DefeatTitleLabel` at 34pt, `DefeatSubtitleLabel` at 18pt displaying stage number and stage title) clearly communicate defeat without visual clutter. |
| 2 | **UI Layout & Viewport Responsiveness (1280x720 & 1024x720)** | **9.7** | Replacing hardcoded absolute positions with `CenterContainer` (`PRESET_FULL_RECT`) delivers mathematical centering. Measured in native captures: center X is 639.5 (target 640.0) at 1280x720, and 511.5 (target 512.0) at 1024x720. Zero edge clipping, zero label wrapping, generous 32px padding, and compliant 48px touch targets. |
| 3 | **Player Agency & Recovery Flow** | **9.7** | Replaces prototype 2.0s forced reload with complete player sovereignty. The player decides when to retry or exit. Tapping '다시 도전 (Retry Stage)' instantiates a fresh stage instance; tapping '타이틀로 (Return to Title)' cleans up campaign state and navigates back to the main title screen. Double-tap guards prevent accidental duplicate instantiations. |
| 4 | **Input Handling & Neutralization Safety** | **9.6** | Virtual touch controls are immediately released via `touch_controls._release_all_actions()` and hidden upon player death. Minion and boss attack collision monitoring (`attack_area_3d`) and physics processing are immediately halted. Zero phantom hits, zero corpse-bumping, and zero stuck touch buttons. |
| 5 | **Audio-Visual Feedback Integration** | **9.5** | Player defeat synchronously triggers `AudioManager.play("player_hurt")`. SFX audio is cleanly stopped on retry (`AudioManager.stop_sfx()`) and completely reset on title exit (`AudioManager.reset_all()`). No orphan looping sounds or audio bus leaks across retries. |
| 6 | **State Integrity & Progression Safety** | **9.8** | Atomic `is_defeat_active` flag prevents duplicate defeat triggers or defeat-cleared race conditions. Retrying the current stage preserves earlier stage completion in `cleared_stages`, ensuring no loss of campaign momentum. Fresh stage instantiation leaves zero leftover actor nodes or stray timers. |
| 7 | **Option C Plane Lock & Technical Cleanliness** | **9.9** | Zero global pauses (`get_tree().paused` remains false), avoiding UI event deadlocks. All UI nodes exist cleanly within `ui_layer: CanvasLayer`. Option C telemetry across 1,341 continuous samples verifies 100% adherence: exactly 0 violations of $Z=0.0000$ and $v_z=0.0000$. |
| 8 | **Campaign Continuity & End-to-End Stability** | **9.7** | Verified via full 5-stage continuous E2E smoke (`v3_013_campaign_smoke.gd`): Title Deploy -> Stages 1-5 natural clears -> Campaign Victory Panel -> Return to Title -> Second Campaign Deploy. In addition, real GUI click failure/retry smoke (`v3_013_failure_retry_smoke.gd`) verifies post-retry Stage 1 clear and Stage 2 progression. |
| 9 | **Regression Protection** | **9.7** | 100% pass across all existing test suites: V3-011 procedural combat audio (31/31 checks), V3-010 multi-touch input (11/11 checks), and V3-012 encounter combat readability (29/29 checks). Zero regressions detected in combat feel, telegraphs, or touch handling. |
| 10 | **Overall Commercial Impression & Playability Polish** | **9.5** | Elevates ProjectKnight from a prototype tech demo to a cohesive, player-respecting commercial indie action title. The failure loop feels deliberate, communicative, and fair. Victory and defeat dialogs share unified responsive styling. |
| -- | **OVERALL DIRECTOR AVERAGE** | **9.67 / 10.0** | **QUALITY GATE FULLY SATISFIED (Target >= 9.0, Critical >= 8.0)** |

---

## 3. Deep-Dive Code Modification & Architectural Inspection

The implementation frozen at commit SHA `f44bdc9` was audited across the modified core scripts:

### 3.1 Defeat Modal Architecture & Campaign Recovery
- **File:** `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd`
- **Architectural Findings:**
  1. **Atomic Defeat State Machine:** Added `is_defeat_active: bool = false` and `failure_overlay: Control = null`. In `_on_stage_failed()`, early exit guards `if is_transitioning or is_defeat_active: return` ensure that multiple death events cannot instantiate duplicate modals. Similarly, `_on_stage_cleared()` guards with `if is_transitioning or is_defeat_active: return`, preventing defeat-clear race conditions if a boss and player trade lethal blows on the same frame.
  2. **Responsive Defeat Modal (`_show_stage_failed()`):**
     - Emits `AudioManager.play("player_hurt")`.
     - Wraps `StageFailedPanel` (`Vector2(620, 320)`) in a root `Control` and `CenterContainer` configured with `PRESET_FULL_RECT`.
     - Overrides panel styling with a dark crimson aesthetic: background `Color(0.08, 0.04, 0.05, 0.94)`, 2px border `Color(0.95, 0.25, 0.25, 0.9)`, 8px corner radii, and generous content margins (32px horizontal, 24px vertical).
     - Renders header `DefeatTitleLabel` ('☠ STAGE FAILED ☠', 34pt font, crimson) and contextual `DefeatSubtitleLabel` ('STAGE %d — %s\nThe Paladin has fallen in combat.', 18pt font).
  3. **Action Button Controls & Double-Tap Immunity:**
     - `RetryStageButton` (220x48, `FOCUS_ALL`, '⚔ RETRY STAGE'):
       - Sets `is_transitioning = true` immediately upon press to reject subsequent clicks.
       - Invokes `AudioManager.stop_sfx()`.
       - Queues free the defeat overlay and resets `is_defeat_active = false`.
       - Calls `load_stage(current_stage_index)`: reloads strictly the failed stage as a pristine instance while preserving `cleared_stages` untouched.
     - `ReturnTitleButton` (220x48, `FOCUS_ALL`, '⮌ RETURN TO TITLE'):
       - Sets `is_transitioning = true` immediately upon press.
       - Invokes `AudioManager.reset_all()`.
       - Cleans up overlay, resets state, and calls `get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")`.
  4. **Victory Dialog Centering & Input Fix:**
     - Wrapped `CampaignVictoryPanel` in `CenterContainer` with `PRESET_FULL_RECT`, eliminating hardcoded offset `Vector2(320, 190)`.
     - Explicitly resets `is_transitioning = false` when displaying victory panel so that replay and title buttons are interactive.
     - Added double-click guards `if is_transitioning: return; is_transitioning = true` to both `ReplayCampaignButton` and `ReturnTitleButton`.

### 3.2 Combat Neutralization & Input Teardown
- **File:** `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Architectural Findings:**
  1. **Virtual Touch Deck Neutralization:**
     - In `_on_player_died()`: calls `touch_controls._release_all_actions()` to flush all virtual input actions, followed by `touch_controls.visible = false`. This guarantees no lingering touch state or visual obstruction during defeat.
  2. **Enemy & Boss Combat Neutralization:**
     - Iterates through active `enemies`:
       - Disables attack area collision monitoring: `enemy.attack_area_3d.set_deferred("monitoring", false)` and `set_deferred("monitorable", false)`.
       - Resets `enemy.is_attacking = false`.
       - Halts physics process: `enemy.set_physics_process(false)`.
     - Neutralizes `active_boss`:
       - Disables `active_boss.attack_area_3d` monitoring and monitorable via deferred calls.
       - Halts `active_boss.set_physics_process(false)`.
  3. **Zero Global Pause Safety:**
     - Avoids using `get_tree().paused = true`, ensuring that UI tweening, button click handling, and audio callbacks operate smoothly without pause-mode dependency complications.

---

## 4. Verification Evidence & Telemetry Audit

### 4.1 Programmatic Verification Suite
- **Script:** `CLIENT/Game/tests/v3_013_failure_retry_verification.gd`
- **Artifact:** `STUDIO_V3/evidence/V3-013/FAILURE_RETRY_VERIFICATION_RESULT.json`
- **Result:** **27 / 27 Checks Passed (100% PASS, Exit Code 0)**
- **Key Assertions Audited:**
  - `StageFailedOverlay` properly parented to `UILayer` with `CenterContainer`.
  - Panel dimensions: `custom_minimum_size` is (620, 320).
  - Title and subtitle labels contain expected localized stage strings.
  - Action buttons configured with 220x48 min size and `FOCUS_ALL`.
  - Virtual touch controls hidden immediately upon player death.
  - **Absence of auto-reload confirmed:** Overlay remains active and player corpse awaits input after 2.2 seconds (past legacy 2.0s timeout).
  - Double-tap guard rejects second button event while transitioning.
  - Single-stage retry frees overlay, resets `is_defeat_active`, loads fresh stage instance with full 8/8 HP, and preserves prior cleared stages in `cleared_stages`.
  - Responsive centering mathematically confirmed at 1024x720 compact resolution with zero boundary clipping.
  - Return to title successfully instantiates `TitleScreen` in scene root.
  - Zero global tree pause confirmed (`get_tree().paused == false`).

### 4.2 Before vs After Capture Inspection
- **Script:** `CLIENT/Game/tests/v3_013_capture_and_verify.gd`
- **Artifacts:** `STUDIO_V3/evidence/V3-013/BEFORE_AFTER.md`, `captures/before/`, `captures/after/`
- **Capture Set Audit:**
  - `before_01_uncontrolled_auto_reload_defeat.png` (1280x720): Player corpse on ground, touch controls still overlaid, enemies attacking corpse, no UI modal.
  - `after_01_stage_failed_overlay_1280x720.png` (1280x720): Clean defeat overlay, dark crimson panel centered at $X=639.5, Y=355.0$, touch controls hidden, prominent Retry and Title buttons.
  - `after_02_stage_failed_overlay_1024x720.png` (1024x720): Viewport resized to 1024x720, panel centered at $X=511.5, Y=359.5$, zero edge clipping, intact typography and button targets.
  - `after_03_retry_fresh_stage_respawn.png` (1280x720): Fresh Stage 1 respawn, player at $X=-8.00, Z=0.00$ with full 8/8 HP, overlay cleared, touch deck restored.
  - `after_04_return_to_title_screen.png` (1280x720): Clean return to `TitleScreen.tscn` with interactive Deploy button.

### 4.3 Real Input Failure & Retry E2E Smoke Test
- **Script:** `CLIENT/Game/tests/v3_013_failure_retry_smoke.gd`
- **Artifact:** `STUDIO_V3/evidence/V3-013/FAILURE_RETRY_SMOKE_RESULT.json`
- **Result:** **All Checks Passed (100% PASS, Exit Code 0)**
- **Execution Flow Audited:**
  - TitleScreen Deploy clicked via simulated real GUI mouse event (`InputEventMouseButton`).
  - Stage 1 loaded; player takes lethal damage.
  - `StageFailedOverlay` rendered; real GUI mouse click dispatched to center of `RetryStageButton`.
  - Fresh Stage 1 instance reloaded; player verified at full 8/8 HP at $X=-8.00, Z=0.00$.
  - Natural combat executed with real input sequences: Wave 1 minions defeated, Boss Commander defeated with slashes and parries.
  - Stage 1 cleared and smooth transition to Stage 2 verified.

### 4.4 Continuous 5-Stage Campaign E2E Playthrough
- **Script:** `CLIENT/Game/tests/v3_013_campaign_smoke.gd`
- **Artifacts:** `STAGE5_REAL_INPUT_E2E_RESULT.json`, `STAGE5_REAL_INPUT_E2E_LOG.txt`, `ACTOR_Z_PRESENCE.csv`
- **Result:** **All Checks Passed (100% PASS, Exit Code 0)**
- **Audit Highlights:**
  - Continuous progression through all 5 stages from Title deploy.
  - Stage 5 Abyssal Arbiter defeated naturally (HP 38 -> 0), phase 2 Judgment Storm triggered at 17 HP.
  - Campaign completed signal received; responsive `CampaignVictoryPanel` rendered.
  - Real GUI click on `ReturnTitleButton` successfully returns to `TitleScreen`.
  - Second campaign deploy verified from title screen.
  - **Option C Plane Lock:** 1,341 telemetry samples in `ACTOR_Z_PRESENCE.csv` audited:
    - $\max(|pos_z|) = 0.0000$ m
    - $\max(|vel_z|) = 0.0000$ m/s
    - Exactly 0 Option C violations across all actors.

### 4.5 Targeted Regression Suite
- **Procedural Combat Audio:** `v3_011_audio_verification.gd` -> **31 / 31 Checks Passed (Exit Code 0)**.
- **Multi-Touch Input:** `v3_010_test_touch_repro.gd` -> **11 / 11 Checks Passed (Exit Code 0)**.
- **Encounter Combat Readability:** `v3_012_encounter_readability_verification.gd` -> **29 / 29 Checks Passed (Exit Code 0)**.

---

## 5. Issue Tracking & Milestone Disposition

### 5.1 Milestone Resolved Issues
- **ISSUE-V3-013-001 (P1 - HIGH):** Uncontrolled 2-second automatic stage reload on player death -> **RESOLVED & VERIFIED**.
- **ISSUE-V3-013-002 (P1 - HIGH):** Virtual touch deck and enemy attacks lingering post-defeat -> **RESOLVED & VERIFIED**.
- **ISSUE-V3-013-003 (P2 - MEDIUM):** Hardcoded dialog positioning causing clipping on compact viewports -> **RESOLVED & VERIFIED**.
- **ISSUE-V3-013-004 (P1 - HIGH):** `is_transitioning` flag blocking action buttons on Campaign Victory -> **RESOLVED & VERIFIED**.

### 5.2 Backlog Polish Items (Non-Blocking)
- **POLISH-V3-014-001 (P2 - MINOR):** Defeat screen chromatic aberration / slow desaturation transition tween -> Backlog polish.
- **POLISH-V3-014-002 (P3 - POLISH):** Defeat stats readout (e.g. damage dealt to boss, run time) on `StageFailedPanel` -> Post-V3 Polish backlog.

---

## 6. Game Director Formal Milestone Determination

Milestone **V3-013: Player-Controlled Defeat, Retry & Campaign Recovery** fulfills every requirement defined by the milestone directive and ProjectKnight Quality Rules:
- **Quality Score Average:** **9.67 / 10.0** (Threshold: >= 8.5, Target: >= 9.0).
- **Critical Minimum:** No category below **9.5** (Threshold: >= 8.0).
- **Reproducible Evidence:** 27/27 unit checks, 100% green failure/retry smoke with real GUI button input, full 5-stage continuous campaign clear, 4 verified after-captures, 1 before-capture, 1,341 Option C telemetry records (0 violations), and 71/71 regression checks.
- **Player Experience Elevation:** Complete elimination of unprompted reloads, complete preservation of campaign momentum, and seamless multi-resolution modal responsiveness.

**FINAL STATUS:** **APPROVED**

### Mandatory Disclosures
1. **`ANDROID_NOT_TESTED`**: All automated runs, viewport captures, and regression tests were executed on Windows PC (Godot 4.7.2 stable, OpenGL3 Compatibility renderer, NVIDIA GeForce RTX 5060 Laptop GPU). Physical Android device deployment, touch latency, and thermal behavior have not been verified.
2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**: Verification was performed via automated programmatic harnesses and simulated real GUI mouse input events. Ergonomic touch comfort and human psychological reaction to defeat pacing require dedicated physical playtesting sessions.
3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**: Milestone V3-013 completes core stage defeat, retry, and campaign recovery loops. Full commercial distribution requires additional audio mastering, localization passes, and comprehensive mobile platform certification.

---

**PK_GameDirector (Product and Milestone Authority)**  
*ProjectKnight Studio V3 — jjangmut/ProjectKnight*
