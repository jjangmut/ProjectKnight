extends CanvasLayer
class_name QVMobileControls
## Heroes War Concept — Tactical Radar Stick & Skill Deck HUD (Quarter-View Mobile Controls)
## - 좌측 하단: 택티컬 레이더 스틱 (360도 전술 아날로그 조이스틱 + 네온 시안/앰버 링)
## - 우측 하단: 히어로즈 워 스타일 택티컬 스킬 덱 (⚔ STRIKE, 🛡 PARRY, 💨 DASH, ▲ LEAP)
## - 우측 상단: '📱 택티컬 덱 ON/OFF' 스위치

var is_controls_visible: bool = true
var _button_actions: Dictionary = {}
var _touch_to_action: Dictionary = {}
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
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_layout)
	_update_layout()


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

	btn_attack = _create_tactical_skill_button("⚔ STRIKE\n공격", Vector2(65.0, 35.0), Vector2(88.0, 88.0), Color("38141c"), Color("ff3b5c"), "attack", "S1 · COMBO")
	btn_guard = _create_tactical_skill_button("🛡 PARRY\n방어", Vector2(-95.0, -15.0), Vector2(74.0, 74.0), Color("102638"), Color("00e5ff"), "guard", "S2 · 0.14s")
	btn_dash = _create_tactical_skill_button("💨 DASH\n회피", Vector2(-85.0, 65.0), Vector2(74.0, 74.0), Color("0e2a24"), Color("34d399"), "dash", "S3 · EVADE")
	btn_jump = _create_tactical_skill_button("▲ LEAP\n점프", Vector2(-5.0, -55.0), Vector2(74.0, 74.0), Color("261c0c"), Color("ffb800"), "jump", "MOBILITY")

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

	_button_actions[btn] = action_name
	btn.button_down.connect(func(): _press_virtual_action(action_name))
	btn.button_up.connect(func(): _release_virtual_action(action_name))
	return btn


func _input(event: InputEvent) -> void:
	if not is_controls_visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var hit_btn := false
			for btn in _button_actions.keys():
				if btn is Button and is_instance_valid(btn) and btn.is_visible_in_tree():
					if btn.get_global_rect().has_point(event.position):
						var act_name: String = _button_actions[btn]
						_touch_to_action[event.index] = act_name
						_press_virtual_action(act_name)
						hit_btn = true
						break
			if not hit_btn:
				if event.position.x < 550.0 and event.position.y > 320.0:
					is_dragging = true
					drag_touch_index = event.index
					_update_joystick(event.position)
		else:
			if _touch_to_action.has(event.index):
				var act_name: String = _touch_to_action[event.index]
				_touch_to_action.erase(event.index)
				_release_virtual_action(act_name)
			if event.index == drag_touch_index:
				_reset_joystick()

	elif event is InputEventScreenDrag:
		if is_dragging and event.index == drag_touch_index:
			_update_joystick(event.position)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.x < 550.0 and event.position.y > 320.0:
					is_dragging = true
					drag_touch_index = 999
					_update_joystick(event.position)
			else:
				if drag_touch_index == 999:
					_reset_joystick()

	elif event is InputEventMouseMotion:
		if is_dragging and drag_touch_index == 999:
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


var _touch_active_actions: Dictionary = {}

func _press_virtual_action(action: String) -> void:
	_touch_active_actions[action] = true
	Input.action_press(action)

func _release_virtual_action(action: String) -> void:
	if _touch_active_actions.get(action, false):
		_touch_active_actions[action] = false
		if not _is_hardware_action_pressed(action):
			Input.action_release(action)

func _is_hardware_action_pressed(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var key_ev := ev as InputEventKey
			if key_ev.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(key_ev.physical_keycode):
				return true
			if key_ev.keycode != KEY_NONE and Input.is_key_pressed(key_ev.keycode):
				return true
		elif ev is InputEventMouseButton:
			var mb_ev := ev as InputEventMouseButton
			if Input.is_mouse_button_pressed(mb_ev.button_index):
				return true
		elif ev is InputEventJoypadButton:
			var jb_ev := ev as InputEventJoypadButton
			if Input.is_joy_button_pressed(0, jb_ev.button_index):
				return true
	return false

func _emulate_direction(dir: Vector2, strength: float) -> void:
	if strength < 0.15:
		_release_all_moves()
		return

	# Option C: Left / Right horizontal control
	if dir.x < -0.35:
		_press_virtual_action("move_left")
		_release_virtual_action("move_right")
	elif dir.x > 0.35:
		_press_virtual_action("move_right")
		_release_virtual_action("move_left")
	else:
		_release_virtual_action("move_left")
		_release_virtual_action("move_right")

	# Option C: Downward threshold enables airborne Dive Slam, zero ground Z drift
	if dir.y > 0.50:
		_press_virtual_action("move_down")
	else:
		_release_virtual_action("move_down")
	_release_virtual_action("move_up")


func _reset_joystick() -> void:
	is_dragging = false
	drag_touch_index = -1
	joystick_knob.position = Vector2(-26.0, -26.0)
	_release_all_moves()


func _release_all_moves() -> void:
	_release_virtual_action("move_left")
	_release_virtual_action("move_right")
	_release_virtual_action("move_up")
	_release_virtual_action("move_down")


func _release_all_actions() -> void:
	_touch_to_action.clear()
	_release_all_moves()
	_release_virtual_action("attack")
	_release_virtual_action("guard")
	_release_virtual_action("dash")
	_release_virtual_action("jump")


func _exit_tree() -> void:
	_release_all_actions()


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
		_release_all_actions()
	btn_toggle.text = "📱 패드 ON" if not is_controls_visible else "📱 패드 OFF"
