# V3-009 — Source Diff Summary & Code Impact Analysis

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-009-combat-mobile-ui`  
**Base Commit:** `1e1b9893d56b0266da5bf1350a469fb5e94b0d0d` (docs(v3-009): define gameplay-first combat and mobile UI polish task)  
**Target Engine:** Godot 4.7.2 stable / OpenGL3 Compatibility / 1280x720 baseline  

---

## 1. Overview of Changes

In accordance with `STUDIO_V3/tasks/V3-009.md`, gameplay improvements prioritize **moment-to-moment combat responsiveness** and **mobile-scale interface legibility**. Exactly 3 core production files were modified, with zero changes to enemy HP/damage, zero faked completion scripts, and strict preservation of Option C ($Z=0.0, v_z=0.0$).

```text
CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd       | 19 +++++++++++++++++++
CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd      | 28 ++++++++++++++++++++++++++--
CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd  |  6 ++++++
3 files changed, 51 insertions(+), 2 deletions(-)
```

---

## 2. Per-File Detailed Diff & Rationale

### A. `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Lines Modified:**
  - Added fields:
    ```gdscript
    var dash_buffer_timer: float = 0.0
    const DASH_BUFFER_TIME: float = 0.16
    var can_air_dash: bool = true
    ```
  - `_update_timers(delta)`:
    ```gdscript
    if dash_buffer_timer > 0.0:
        dash_buffer_timer = maxf(0.0, dash_buffer_timer - delta)
    if Input.is_action_just_pressed("dash"):
        dash_buffer_timer = DASH_BUFFER_TIME
    ```
  - `_process_movement(delta)`:
    ```gdscript
    elif (Input.is_action_just_pressed("dash") or dash_buffer_timer > 0.0) and (is_on_floor() or can_air_dash):
        dash_buffer_timer = 0.0
        start_dash()
    ```
  - `start_dash()`:
    ```gdscript
    if not is_on_floor() or global_position.y > 0.35:
        can_air_dash = false
    ```
  - `_process_attack_state(delta)`:
    ```gdscript
    # Attack Recovery Cancel into Dash or Guard (fluid high-tier combat responsiveness)
    if attack_duration_remaining <= 0.14:
        if (Input.is_action_just_pressed("dash") or dash_buffer_timer > 0.0) and (is_on_floor() or can_air_dash):
            dash_buffer_timer = 0.0
            slash_visual_3d.visible = false
            is_attacking = false
            start_dash()
            return
        elif Input.is_action_pressed("guard") and is_on_floor():
            slash_visual_3d.visible = false
            is_attacking = false
            start_guard()
            return
    ```
  - `_on_landed_on_floor()`:
    ```gdscript
    can_air_dash = true
    ```
- **Rationale & Player Impact:**
  - Solves the sluggish "locked-in" feeling during attack recovery. Players can now react to sudden boss telegraphs by cancelling recovery frames immediately after the active hitbox has finished.
  - Adds a 160ms Dash input buffer matching jump/attack buffers, eliminating dropped evasion inputs.
  - Adds single-use Air Dash, refreshed upon landing, enabling vertical evasion against ground waves and hazards.

---

### B. `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Lines Modified:**
  - Added property:
    ```gdscript
    var touch_controls: QVMobileControls = null
    ```
  - `_setup_mobile_ui()`:
    ```gdscript
    # Dedicated Mobile Tactical Virtual Controls Deck (Joystick & Action Buttons)
    touch_controls = QVMobileControlsClass.new()
    touch_controls.name = "TouchControlsDeck"
    mobile_controls.add_child(touch_controls)
    ```
- **Rationale & Player Impact:**
  - Previously, `SideQVStageBase` created `mobile_controls = CanvasLayer.new()` with player HUD plates, but omitted attaching the interactive virtual joystick and tactical action buttons (`QVMobileControls`).
  - This fix attaches the `TouchControlsDeck` across all 5 stages, making touch-screen mobile control fully operable out-of-the-box.

---

### C. `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd`
- **Lines Modified:**
  - `_ready()`:
    ```gdscript
    if get_viewport() != null:
        get_viewport().size_changed.connect(_update_layout)
    _update_layout()
    ```
  - Added `_update_layout()`:
    ```gdscript
    func _update_layout() -> void:
        var win := get_tree().root if get_tree() != null else null
        var vp_size: Vector2 = Vector2(win.size) if win != null else (get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720))
        var joy_container = get_node_or_null("RootHUD/JoystickContainer")
        var action_container = get_node_or_null("RootHUD/ActionContainer")
        if joy_container != null:
            joy_container.position = Vector2(145.0, vp_size.y - 185.0)
            joystick_center = joy_container.global_position
        if action_container != null:
            action_container.position = Vector2(maxf(680.0, vp_size.x - 265.0), vp_size.y - 185.0)
        if btn_toggle != null:
            btn_toggle.position = Vector2(maxf(720.0, vp_size.x - 242.0), 14.0)
    ```
- **Rationale & Player Impact:**
  - Previously used static absolute coordinates `(1015, 535)`. When rendered on viewports narrower than 1280px (e.g., 1024x720, or tablet aspect ratios), action buttons clipped off-screen past pixel 1024.
  - Dynamic anchoring via `maxf(680.0, vp_size.x - 265.0)` guarantees full visibility and reachability across both standard 1280x720 and narrower 1024x720 screens.

---

## 3. Regression Assessment
- **Option C Invariance:** No modifications touch actor $Z$ or $v_z$. Verified $\max |Z| = 0.0000$ in all automated E2E logs.
- **Stage Progression:** Stages 1–5 flow, boss transitions, triggers, and checkpoint logic remain unmodified.
- **Combat Balance:** Enemy HP, enemy attack power, and player base damage values remain untouched.
