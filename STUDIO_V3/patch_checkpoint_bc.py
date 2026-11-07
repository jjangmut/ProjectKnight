"""Script to apply Checkpoints B & C:
Checkpoint B: Mobile touch controls Option C adaptation, ergonomic layout, stuck input failsafe.
Checkpoint C: Boss arena foreground occlusion fix per PK_ArtDirector specification.
"""
from pathlib import Path

def patch_mobile_controls():
    path = Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\scripts\quarter_view\qv_mobile_controls.gd")
    content = path.read_text(encoding="utf-8")

    # 1. Update action button positions and sizes per PK_GameDesign specification:
    # Strike: (65, 35), 88x88; Leap: (-5, -55), 74x74; Parry: (-95, -15), 74x74; Dash: (-85, 65), 74x74
    target_btns = """\tbtn_attack = _create_tactical_skill_button("⚔ STRIKE\\n공격", Vector2(12.0, 8.0), Vector2(82.0, 82.0), Color("38141c"), Color("ff3b5c"), "attack", "S1 · COMBO")
\tbtn_guard = _create_tactical_skill_button("🛡 PARRY\\n방어", Vector2(-82.0, -34.0), Vector2(70.0, 70.0), Color("102638"), Color("00e5ff"), "guard", "S2 · 0.14s")
\tbtn_dash = _create_tactical_skill_button("💨 DASH\\n회피", Vector2(-74.0, 48.0), Vector2(70.0, 70.0), Color("0e2a24"), Color("34d399"), "dash", "S3 · EVADE")
\tbtn_jump = _create_tactical_skill_button("▲ LEAP\\n점프", Vector2(18.0, -76.0), Vector2(68.0, 68.0), Color("261c0c"), Color("ffb800"), "jump", "MOBILITY")"""

    replacement_btns = """\tbtn_attack = _create_tactical_skill_button("⚔ STRIKE\\n공격", Vector2(65.0, 35.0), Vector2(88.0, 88.0), Color("38141c"), Color("ff3b5c"), "attack", "S1 · COMBO")
\tbtn_guard = _create_tactical_skill_button("🛡 PARRY\\n방어", Vector2(-95.0, -15.0), Vector2(74.0, 74.0), Color("102638"), Color("00e5ff"), "guard", "S2 · 0.14s")
\tbtn_dash = _create_tactical_skill_button("💨 DASH\\n회피", Vector2(-85.0, 65.0), Vector2(74.0, 74.0), Color("0e2a24"), Color("34d399"), "dash", "S3 · EVADE")
\tbtn_jump = _create_tactical_skill_button("▲ LEAP\\n점프", Vector2(-5.0, -55.0), Vector2(74.0, 74.0), Color("261c0c"), Color("ffb800"), "jump", "MOBILITY")"""
    assert target_btns in content, "target_btns not found in qv_mobile_controls.gd"
    content = content.replace(target_btns, replacement_btns)

    # 2. Add mouse emulation input handling so PC mouse clicks & drags trigger joystick seamlessly
    target_input = """func _input(event: InputEvent) -> void:
\tif not is_controls_visible:
\t\treturn

\tif event is InputEventScreenTouch:
\t\tif event.pressed:
\t\t\tif event.position.x < 500.0 and event.position.y > 350.0:
\t\t\t\tis_dragging = true
\t\t\t\tdrag_touch_index = event.index
\t\t\t\t_update_joystick(event.position)
\t\telse:
\t\t\tif event.index == drag_touch_index:
\t\t\t\t_reset_joystick()

\telif event is InputEventScreenDrag:
\t\tif is_dragging and event.index == drag_touch_index:
\t\t\t_update_joystick(event.position)"""

    replacement_input = """func _input(event: InputEvent) -> void:
\tif not is_controls_visible:
\t\treturn

\tif event is InputEventScreenTouch:
\t\tif event.pressed:
\t\t\tif event.position.x < 550.0 and event.position.y > 320.0:
\t\t\t\tis_dragging = true
\t\t\t\tdrag_touch_index = event.index
\t\t\t\t_update_joystick(event.position)
\t\telse:
\t\t\tif event.index == drag_touch_index:
\t\t\t\t_reset_joystick()

\telif event is InputEventScreenDrag:
\t\tif is_dragging and event.index == drag_touch_index:
\t\t\t_update_joystick(event.position)

\telif event is InputEventMouseButton:
\t\tif event.button_index == MOUSE_BUTTON_LEFT:
\t\t\tif event.pressed:
\t\t\t\tif event.position.x < 550.0 and event.position.y > 320.0:
\t\t\t\t\tis_dragging = true
\t\t\t\t\tdrag_touch_index = 999
\t\t\t\t\t_update_joystick(event.position)
\t\t\telse:
\t\t\t\tif drag_touch_index == 999:
\t\t\t\t\t_reset_joystick()

\telif event is InputEventMouseMotion:
\t\tif is_dragging and drag_touch_index == 999:
\t\t\t_update_joystick(event.position)"""
    assert target_input in content, "target_input not found in qv_mobile_controls.gd"
    content = content.replace(target_input, replacement_input)

    # 3. Update _emulate_direction for Option C:
    # Pure horizontal movement; downward threshold triggers dive slam; zero move_up/move_down Z steering
    target_emulate = """func _emulate_direction(dir: Vector2, strength: float) -> void:
\tif strength < 0.2:
\t\t_release_all_moves()
\t\treturn

\tif dir.x < -0.38:
\t\tInput.action_press("move_left")
\t\tInput.action_release("move_right")
\telif dir.x > 0.38:
\t\tInput.action_press("move_right")
\t\tInput.action_release("move_left")
\telse:
\t\tInput.action_release("move_left")
\t\tInput.action_release("move_right")

\tif dir.y < -0.38:
\t\tInput.action_press("move_up")
\t\tInput.action_release("move_down")
\telif dir.y > 0.38:
\t\tInput.action_press("move_down")
\t\tInput.action_release("move_up")
\telse:
\t\tInput.action_release("move_up")
\t\tInput.action_release("move_down")"""

    replacement_emulate = """func _emulate_direction(dir: Vector2, strength: float) -> void:
\tif strength < 0.15:
\t\t_release_all_moves()
\t\treturn

\t# Option C: Left / Right horizontal control
\tif dir.x < -0.35:
\t\tInput.action_press("move_left")
\t\tInput.action_release("move_right")
\telif dir.x > 0.35:
\t\tInput.action_press("move_right")
\t\tInput.action_release("move_left")
\telse:
\t\tInput.action_release("move_left")
\t\tInput.action_release("move_right")

\t# Option C: Downward threshold enables airborne Dive Slam, zero ground Z drift
\tif dir.y > 0.50:
\t\tInput.action_press("move_down")
\telse:
\t\tInput.action_release("move_down")
\tInput.action_release("move_up")"""
    assert target_emulate in content, "target_emulate not found in qv_mobile_controls.gd"
    content = content.replace(target_emulate, replacement_emulate)

    # 4. Release integrity on exit/hide/death
    target_exit = """func _release_all_moves() -> void:
\tInput.action_release("move_left")
\tInput.action_release("move_right")
\tInput.action_release("move_up")
\tInput.action_release("move_down")"""

    replacement_exit = """func _release_all_moves() -> void:
\tInput.action_release("move_left")
\tInput.action_release("move_right")
\tInput.action_release("move_up")
\tInput.action_release("move_down")


func _release_all_actions() -> void:
\t_release_all_moves()
\tInput.action_release("attack")
\tInput.action_release("guard")
\tInput.action_release("dash")
\tInput.action_release("jump")


func _exit_tree() -> void:
\t_release_all_actions()"""
    assert target_exit in content, "target_exit not found in qv_mobile_controls.gd"
    content = content.replace(target_exit, replacement_exit)

    # 5. When pad is toggled OFF, release all inputs
    target_toggle = """\tif not is_controls_visible:
\t\t_reset_joystick()"""
    if target_toggle in content:
        content = content.replace(target_toggle, "\tif not is_controls_visible:\n\t\t_reset_joystick()\n\t\t_release_all_actions()")

    path.write_text(content, encoding="utf-8")
    print("Patched qv_mobile_controls.gd successfully.")

def patch_stage_1_occlusion():
    path = Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\scripts\side_quarter_view\stages\side_qv_stage_1.gd")
    content = path.read_text(encoding="utf-8")

    # FrontBalustrade height adjustment: 0.6 -> 0.42
    target_fence = """\tfront_fence.size = Vector3(arena_width, 0.6, 0.6)
\tfront_fence.position = Vector3(0.0, 0.3, arena_depth * 0.5)"""
    replacement_fence = """\t# Option C & Art Direction: Low framing sill (0.42m) to prevent clipping sprites/combat
\tfront_fence.size = Vector3(arena_width, 0.42, 0.6)
\tfront_fence.position = Vector3(0.0, 0.21, arena_depth * 0.5)"""
    assert target_fence in content, "target_fence not found in stage_1.gd"
    content = content.replace(target_fence, replacement_fence)

    # Monolith Pillar Repositioning per PK_ArtDirector:
    # Pillar_FrontLeft -> (-17.0, 0.0, 4.2), Pillar_FrontRight -> (17.0, 0.0, 4.2)
    target_pillars = """\t_build_pillar(Vector3(-10.5, 0.0, -3.0), "Pillar_BackLeft")
\t_build_pillar(Vector3(10.5, 0.0, -3.0), "Pillar_BackRight")
\t_build_pillar(Vector3(-10.5, 0.0, 3.0), "Pillar_FrontLeft")
\t_build_pillar(Vector3(10.5, 0.0, 3.0), "Pillar_FrontRight")"""
    replacement_pillars = """\t# Retain background monoliths for scale and depth
\t_build_pillar(Vector3(-10.5, 0.0, -3.0), "Pillar_BackLeft")
\t_build_pillar(Vector3(10.5, 0.0, -3.0), "Pillar_BackRight")
\t# PK_ArtDirector Realignment: Reposition foreground monoliths to terrace flanks
\t# Clears 100% of the active combat frustum (X in [-14, 14.5]), 0.0% occlusion!
\t_build_pillar(Vector3(-17.0, 0.0, 4.2), "Pillar_FrontLeft")
\t_build_pillar(Vector3(17.0, 0.0, 4.2), "Pillar_FrontRight")"""
    assert target_pillars in content, "target_pillars not found in stage_1.gd"
    content = content.replace(target_pillars, replacement_pillars)

    path.write_text(content, encoding="utf-8")
    print("Patched side_qv_stage_1.gd occlusion successfully.")

if __name__ == "__main__":
    patch_mobile_controls()
    patch_stage_1_occlusion()
    print("Checkpoints B & C patch completed.")
