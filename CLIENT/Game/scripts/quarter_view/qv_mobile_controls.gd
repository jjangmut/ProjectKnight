extends CanvasLayer
class_name QVMobileControls
## Heroes War Concept — Tactical Radar Stick & Skill Deck HUD (Quarter-View Mobile Controls)
## - 좌측 하단: 택티컬 레이더 스틱 (360도 전술 아날로그 조이스틱 + 네온 시안/앰버 링)
## - 우측 하단: 히어로즈 워 스타일 택티컬 스킬 덱 (⚔ STRIKE, 🛡 PARRY, 💨 DASH, ▲ LEAP)
## - 우측 상단: '📱 택티컬 덱 ON/OFF' 스위치

var is_controls_visible: bool = true
var joystick_base: Panel
var joystick_knob: Panel
var is_dragging: bool = false
var drag_touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_max_radius: float = 65.0

# Action Buttons
var btn_attack: Button
var btn_guard: Button
var btn_dash: Button
var btn_jump: Button
var btn_toggle: Button


func _ready() -> void:
	layer = 100
	_build_ui()


func _build_ui() -> void:
	var root_control := Control.new()
	root_control.name = "RootHUD"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 1. Tactical Radar Joystick Container (Bottom-Left)
	var joy_container := Control.new()
	joy_container.name = "JoystickContainer"
	joy_container.position = Vector2(145.0, 535.0)
	joy_container.size = Vector2(140.0, 140.0)
	root_control.add_child(joy_container)

	# Joystick Base Panel (Tactical Gunmetal + Cyan Radar Ring)
	joystick_base = Panel.new()
	joystick_base.name = "JoystickBase"
	joystick_base.size = Vector2(132.0, 132.0)
	joystick_base.position = Vector2(-66.0, -66.0)
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.04, 0.08, 0.14, 0.72)
	base_style.border_color = Color("00e5ff")
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(24) # Octagonal / Chamfered tactical feel
	joystick_base.add_theme_stylebox_override("panel", base_style)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_PASS
	joy_container.add_child(joystick_base)

	var radar_tag := Label.new()
	radar_tag.text = "TACTICAL MOVE"
	radar_tag.position = Vector2(-46.0, 70.0)
	radar_tag.add_theme_font_size_override("font_size", 10)
	radar_tag.add_theme_color_override("font_color", Color("00e5ff"))
	joy_container.add_child(radar_tag)

	# Joystick Knob (Stick - Amber Tactical Core)
	joystick_knob = Panel.new()
	joystick_knob.name = "JoystickKnob"
	joystick_knob.size = Vector2(52.0, 52.0)
	joystick_knob.position = Vector2(-26.0, -26.0)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color("ffb800")
	knob_style.border_color = Color("ffffff")
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(12)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_container.add_child(joystick_knob)

	joystick_center = joy_container.global_position

	# 2. Heroes War Tactical Skill Deck Container (Bottom-Right)
	var action_container := Control.new()
	action_container.name = "ActionContainer"
	action_container.position = Vector2(1015.0, 535.0)
	root_control.add_child(action_container)

	btn_attack = _create_tactical_skill_button("⚔ STRIKE\n공격", Vector2(12.0, 8.0), Vector2(82.0, 82.0), Color("38141c"), Color("ff3b5c"), "attack", "S1 · COMBO")
	btn_guard = _create_tactical_skill_button("🛡 PARRY\n방어", Vector2(-82.0, -34.0), Vector2(70.0, 70.0), Color("102638"), Color("00e5ff"), "guard", "S2 · 0.14s")
	btn_dash = _create_tactical_skill_button("💨 DASH\n회피", Vector2(-74.0, 48.0), Vector2(70.0, 70.0), Color("0e2a24"), Color("34d399"), "dash", "S3 · EVADE")
	btn_jump = _create_tactical_skill_button("▲ LEAP\n점프", Vector2(18.0, -76.0), Vector2(68.0, 68.0), Color("261c0c"), Color("ffb800"), "jump", "MOBILITY")

	action_container.add_child(btn_attack)
	action_container.add_child(btn_guard)
	action_container.add_child(btn_dash)
	action_container.add_child(btn_jump)

	# 3. Top-Right Tactical Pad Toggle Button
	btn_toggle = Button.new()
	btn_toggle.name = "PadToggle"
	btn_toggle.text = "📱 패드 OFF"
	btn_toggle.position = Vector2(1038.0, 14.0)
	btn_toggle.size = Vector2(98.0, 34.0)
	btn_toggle.add_theme_font_size_override("font_size", 12)
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = Color("0d1622")
	toggle_style.border_color = Color("ffb800")
	toggle_style.set_border_width_all(1)
	toggle_style.border_width_left = 4
	toggle_style.corner_radius_top_right = 6
	toggle_style.corner_radius_bottom_left = 6
	btn_toggle.add_theme_stylebox_override("normal", toggle_style)
	btn_toggle.pressed.connect(_on_toggle_pressed)
	root_control.add_child(btn_toggle)


func _create_tactical_skill_button(label_text: String, local_pos: Vector2, btn_size: Vector2, bg_col: Color, rim_col: Color, action_name: String, tag_str: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size = btn_size
	btn.position = local_pos - (btn_size * 0.5)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color("f8fafc"))

	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = rim_col
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	btn.add_theme_stylebox_override("normal", style)

	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = bg_col.lightened(0.22)
	pressed_style.border_color = Color("ffb800")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("hover", pressed_style)

	var sub_tag := Label.new()
	sub_tag.text = tag_str
	sub_tag.position = Vector2(4, -15)
	sub_tag.add_theme_font_size_override("font_size", 9)
	sub_tag.add_theme_color_override("font_color", rim_col)
	btn.add_child(sub_tag)

	btn.button_down.connect(func(): Input.action_press(action_name))
	btn.button_up.connect(func(): Input.action_release(action_name))
	return btn


func _input(event: InputEvent) -> void:
	if not is_controls_visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < 500.0 and event.position.y > 350.0:
				is_dragging = true
				drag_touch_index = event.index
				_update_joystick(event.position)
		else:
			if event.index == drag_touch_index:
				_reset_joystick()

	elif event is InputEventScreenDrag:
		if is_dragging and event.index == drag_touch_index:
			_update_joystick(event.position)


func _update_joystick(touch_pos: Vector2) -> void:
	var joy_container = get_node_or_null("RootHUD/JoystickContainer")
	if joy_container == null:
		return
	var origin: Vector2 = joy_container.global_position
	var diff := touch_pos - origin
	var dist := diff.length()
	var dir := diff.normalized()

	var knob_offset := dir * minf(dist, joystick_max_radius)
	joystick_knob.position = knob_offset - Vector2(26.0, 26.0)

	_emulate_direction(dir, dist / joystick_max_radius)


func _emulate_direction(dir: Vector2, strength: float) -> void:
	if strength < 0.2:
		_release_all_moves()
		return

	if dir.x < -0.38:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif dir.x > 0.38:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if dir.y < -0.38:
		Input.action_press("move_up")
		Input.action_release("move_down")
	elif dir.y > 0.38:
		Input.action_press("move_down")
		Input.action_release("move_up")
	else:
		Input.action_release("move_up")
		Input.action_release("move_down")


func _reset_joystick() -> void:
	is_dragging = false
	drag_touch_index = -1
	joystick_knob.position = Vector2(-26.0, -26.0)
	_release_all_moves()


func _release_all_moves() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _on_toggle_pressed() -> void:
	is_controls_visible = not is_controls_visible
	var joy = get_node_or_null("RootHUD/JoystickContainer")
	var act = get_node_or_null("RootHUD/ActionContainer")
	if joy != null:
		joy.visible = is_controls_visible
	if act != null:
		act.visible = is_controls_visible
	if not is_controls_visible:
		_reset_joystick()
	btn_toggle.text = "📱 패드 ON" if not is_controls_visible else "📱 패드 OFF"
