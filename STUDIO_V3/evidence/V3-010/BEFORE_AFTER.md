# V3-010 — Reliable Multi-Touch Combat & First-Play Readability (Before / After Report)

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-010-touch-combat-onboarding`  
**Engine:** Godot 4.7.2 stable, OpenGL3 Compatibility, Desktop 1280x720 baseline (and 1024x720 narrow audit)  
**Operating Mode:** Option C Strict 2D Combat Plane Lock ($Z = 0.0000, v_z = 0.0000$)  

---

## 1. Executive Summary

Milestone **V3-010** delivers a comprehensive overhaul of **mobile multi-touch input routing**, **first-play tactical onboarding**, and **combat input stability** across ProjectKnight's 5 completed stages. Building directly upon V3-009's combat cancels and responsive virtual deck, V3-010 eliminates double dispatch, adds per-pointer action ownership, protects against mouse emulation clobbering, provides smooth slide transitions across skill buttons, and introduces an elegant, non-blocking tactical action guide in Stage 1.

All improvements were tested on a real rendered window with GL Compatibility on an NVIDIA RTX 5060 GPU, preserving the five completed stages and verified by targeted multi-touch audit fixtures and continuous 5-stage end-to-end automated input suites.

---

## 2. Concrete Player-Facing Issues & Solutions

### Issue 1 (P0 Touch Reliability): Double Dispatch & Emulated Mouse Clobbering in Virtual Controls Deck
- **Location:** `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd`
- **Observed Defect:**
  1. Redundant Signal Dispatch: Action buttons connected both `button_down/up` signals **and** `_input(InputEventScreenTouch)` checked button global rectangles, resulting in duplicate press/release events and race conditions.
  2. Pointer Clobbering: Under touch-from-mouse / mouse-from-touch emulation, an incoming `InputEventMouseButton` overwrote `drag_touch_index` to 999 while touch pointer 0 was dragging the joystick. When finger 0 was released (`0 == 999` false), the joystick failed to reset and character movement was stuck forever.
  3. Lack of Per-Pointer Action Ownership: `_touch_active_actions` was a boolean dictionary rather than tracking per-pointer references. If multiple fingers tapped the same action or overlapping inputs occurred, releasing one pointer could prematurely release another pointer's held action.
  4. Missing Drag/Slide Handling: `InputEventScreenDrag` only processed the joystick. Sliding a thumb off a skill button or into an adjacent skill button did not transition the action cleanly.
  5. Missing Window Focus Cleanup: No `_notification()` handler existed for `NOTIFICATION_APPLICATION_FOCUS_OUT` or `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, leaving actions stuck if the application paused or lost focus.
- **Implemented Fix:**
  - Architected **Single-Owner Input Routing**: Set action buttons to `mouse_filter = Control.MOUSE_FILTER_IGNORE` and removed `button_down/up` signals. `_input(event)` is now the sole dispatcher for touch and mouse events.
  - Implemented **Per-Pointer Ownership Tracking**: `_pointer_map[pointer_id]` tracks exact pointer types (`action`, `joystick`, `empty`), and `_action_ref_counts[action_name]` manages reference counts so one finger's release cannot cancel another pointer's held action.
  - Added **Emulated Mouse Immunity**: `_handle_mouse_button` checks `if drag_touch_index >= 0: return`, preventing mouse emulation events from clobbering an active touch pointer's joystick control.
  - Added **Slide Transitions**: `_handle_screen_drag` detects when a pointer slides out of a button into another skill button (e.g. Strike to Dash) or into empty space, transitioning or releasing actions cleanly with synchronous visual button state feedback.
  - Added **Focus Loss Cleanup**: Implemented `_notification()` catching `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, and `NOTIFICATION_PAUSED` to cleanly release all virtual actions and reset the joystick.
- **Visual Evidence:**
  - Before: `captures/before/before_03_narrow_viewport_uncentered.png`
  - After: `captures/after/after_01_single_owner_touch_deck.png`

---

### Issue 2 (P1 Stage Architecture): Elimination of Duplicate Deck Instance in Stage 1
- **Location:** `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd`
- **Observed Defect:** `SideQVStage1` overrode `_setup_mobile_ui()`, called `super._setup_mobile_ui()` (which instantiated `TouchControlsDeck`), and then instantiated a **second** `QVMobileControls` named `MobileControlsHUD`. Stage 1 had two identical virtual decks receiving input simultaneously, causing double inputs and desynchronized toggle states.
- **Implemented Fix:**
  - Removed the redundant `_setup_mobile_ui()` override in `side_qv_stage_1.gd`, allowing Stage 1 to cleanly inherit the unified `TouchControlsDeck` instantiated by `SideQVStageBase`.
- **Visual Evidence:**
  - Before: `captures/before/before_01_duplicate_stage1_deck.png` (Duplicate overlapping deck)
  - After: `captures/after/after_01_single_owner_touch_deck.png` (Clean single deck)

---

### Issue 3 (P1 First-Play Experience): Stage 1 Tactical Action Onboarding Guide
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Observed Defect:** First-time players entering Stage 1 had zero on-screen guidance explaining core inputs (Move, Jump, Strike combo, Parry/Guard, Dash evade).
- **Implemented Fix:**
  - Added `_setup_onboarding_guide()` in `side_qv_stage_base.gd` when `stage_index == 1`.
  - Creates a translucent, high-contrast tactical action card (`OnboardingGuideHUD` / `GuidePlate`) at the lower-third center (`Vector2(maxf(160.0, (vp_size.x - 530.0) * 0.5), vp_size.y - 74.0)`).
  - Displays: `[A/D or 스틱] 이동 · [SPACE or ▲] 점프 · [J or ⚔] 공격 · [K or 🛡] 방어 · [SHIFT or 💨] 대시`.
  - **Non-blocking & Zero Occlusion:** `mouse_filter = Control.MOUSE_FILTER_IGNORE` ensures clicks and touches pass right through to combat without interception.
  - **Interactive Auto-Dismiss:** When the player initiates any movement or combat action, or after 7.5 seconds, the guide smoothly fades out (`modulate:a -> 0.0`) via a tween and queues free, keeping combat lanes completely unobstructed.
- **Visual Evidence:**
  - Before: `captures/before/before_02_missing_onboarding_guide.png` (No guidance)
  - After: `captures/after/after_02_stage1_onboarding_guide.png` (Centered tactical guide)
  - Dismissed: `captures/after/after_04_onboarding_dismissed.png` (Combat arena clear)

---

### Issue 4 (P2 Combat Semantics): Death & Retry Buffer Reset
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Observed Defect:** `dash_buffer_timer`, `attack_buffer_timer`, and `jump_buffer_timer` were not cleared when entering `_enter_death_state()`, creating potential stale input bleed into retries.
- **Implemented Fix:**
  - Explicitly reset `dash_buffer_timer = 0.0`, `attack_buffer_timer = 0.0`, `jump_buffer_timer = 0.0`, and reset `can_air_dash = true` upon entering death state.

---

## 3. Summary of Code Modifications

| File | Changes | Description |
| :--- | :--- | :--- |
| `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` | +140 / -80 lines | Single-owner input routing, per-pointer ownership tracking, emulated mouse protection, slide transitions, focus loss cleanup |
| `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd` | -6 lines | Eliminated redundant duplicate `QVMobileControls` instantiation |
| `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` | +83 lines | Implemented Stage 1 non-blocking, dismissible tactical onboarding guide with responsive centering |
| `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` | +4 lines | Explicit buffer timer reset on death state entry |

---

## 4. Verification Results Overview

1. **Targeted Multi-Touch Audit (`v3_010_test_touch_repro.gd`):** **11 / 11 PASS** (Exit Code 0).
   - Independent pointer release verified.
   - Mouse clobbering immunity verified.
   - Slide transition from Guard into Dash verified.
   - Focus loss notification cleanup verified.
   - Single-owner architecture with zero redundant signals verified.
2. **Onboarding & Rendered Capture Audit (`v3_010_capture_and_verify.gd`):** **10 / 10 PASS** (Exit Code 0).
   - Stage 1 Onboarding guide verified at 1280x720 and 1024x720.
   - Auto-dismiss on player attack verified.
   - Duplicate deck elimination verified.
3. **Continuous 5-Stage E2E Campaign Smoke (`v3_010_campaign_smoke.gd`):** **PASS** (Exit Code 0).
   - Pure GUI click Title Deploy $\rightarrow$ Stages 1–5 natural clears $\rightarrow$ Arbiter defeat (HP 38 $\rightarrow$ 0) $\rightarrow$ Victory Panel $\rightarrow$ Return to Title $\rightarrow$ Clean Second Campaign Start.
   - 1,289 continuous actor samples in `ACTOR_Z_PRESENCE.csv`: **0 non-zero Z violations** ($100\%$ Option C adherence).
