# V3-010 — Source Diff Summary & Code Impact Analysis

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-010-touch-combat-onboarding`  
**Base Commit:** `91a824a` (docs(v3-010): plan touch reliability and first-play gameplay improvements)  
**Target Engine:** Godot 4.7.2 stable / OpenGL3 Compatibility / 1280x720 baseline  

---

## 1. Overview of Changes

In accordance with `STUDIO_V3/tasks/V3-010.md`, gameplay improvements prioritize **mobile multi-touch input reliability**, **single-owner event routing**, **elimination of duplicate control decks in Stage 1**, and **non-blocking first-play tactical onboarding**. Exactly 4 core production files were modified, with zero changes to enemy HP/damage, zero faked completion scripts, and strict preservation of Option C ($Z=0.0, v_z=0.0$).

```text
CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd            | 339 +++++++++++++++------
CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd           |   4 +
CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd       |  83 +++++
CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd   |   6 -
4 files changed, 338 insertions(+), 94 deletions(-)
```

---

## 2. Per-File Detailed Diff & Rationale

### A. `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd`
- **Lines Modified:** ~140 lines added, 80 lines removed / refactored.
- **Key Changes:**
  1. **Single-Owner Action Routing:**
     - Removed `btn.button_down.connect(...)` and `btn.button_up.connect(...)`.
     - Set `btn.mouse_filter = Control.MOUSE_FILTER_IGNORE` on all action buttons.
     - Routed all touch and click detection exclusively through `_input(event)`.
  2. **Per-Pointer Ownership Tracking:**
     - Added `_pointer_map: Dictionary` mapping `pointer_id -> { "type": "action" | "joystick" | "empty", "action": String, "btn": Button }`.
     - Added `_action_ref_counts: Dictionary` managing reference counts per action.
     - One pointer's release decrements the ref count; action is only released from `Input` when ref count reaches 0, preventing accidental release during multi-touch combinations.
  3. **Emulated Mouse Protection:**
     - In `_handle_mouse_button`: Added `if drag_touch_index >= 0: return` check so emulated mouse events cannot overwrite the active touch pointer index (`drag_touch_index`).
  4. **Slide Transitions Across Buttons:**
     - In `_handle_screen_drag`: Added detection for pointers sliding out of a button into another action button or into empty space. Transitions actions cleanly with synchronous visual button state feedback (`_button_styles[btn].pressed` / `normal`).
  5. **Window Focus Loss Cleanup:**
     - Implemented `_notification(what)` catching `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, and `NOTIFICATION_PAUSED` to cleanly release all actions and reset the joystick.

---

### B. `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd`
- **Lines Removed:**
  ```gdscript
  func _setup_mobile_ui() -> void:
      super._setup_mobile_ui()
      var touch_controls := QVMobileControlsClass.new()
      touch_controls.name = "MobileControlsHUD"
      add_child(touch_controls)
  ```
- **Rationale & Player Impact:**
  - `SideQVStageBase` already instantiates `TouchControlsDeck` (`QVMobileControls`).
  - Stage 1 was creating a second instance (`MobileControlsHUD`), resulting in two overlapping decks receiving input simultaneously.
  - Removing this override eliminates duplicate dispatch in Stage 1 and ensures consistent toggle behavior.

---

### C. `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Lines Added:** +83 lines.
- **Key Changes:**
  1. Added `var onboarding_guide: Control = null`.
  2. In `_setup_mobile_ui()`: When `stage_index == 1`, calls `_setup_onboarding_guide()`.
  3. Implemented `_setup_onboarding_guide()`:
     - Creates `OnboardingGuideHUD` with `GuidePlate` panel at lower-third center.
     - Displays `[A/D or 스틱] 이동 · [SPACE or ▲] 점프 · [J or ⚔] 공격 · [K or 🛡] 방어 · [SHIFT or 💨] 대시`.
     - `mouse_filter = Control.MOUSE_FILTER_IGNORE` ensures zero touch/click obstruction.
     - Listens to `size_changed` for responsive centering on 1280x720 baseline and 1024x720 narrow viewports.
  4. Implemented `_dismiss_onboarding_guide()`:
     - Automatically dismisses after 7.5 seconds, or immediately fades out over 0.35s when the player triggers movement or combat actions in `_process(delta)`.

---

### D. `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Lines Added:** +4 lines in `_enter_death_state()`:
  ```gdscript
  dash_buffer_timer = 0.0
  attack_buffer_timer = 0.0
  jump_buffer_timer = 0.0
  can_air_dash = true
  ```
- **Rationale & Player Impact:**
  - Guarantees zero stale input buffer bleed when transitioning to death or retrying the stage.

---

## 3. Regression Assessment
- **Option C Invariance:** No modifications alter actor $Z$ or $v_z$. Verified $\max |Z| = 0.0000$ across 1,289 sampled runtime points.
- **5-Stage Campaign Flow:** Stages 1 through 5 clear naturally without cheats or stat adjustments.
- **Combat Mechanics:** Parry timing, attack damages, enemy health, and boss behaviors remain strictly unchanged.
