extends CanvasLayer
class_name QVMobileControls
## Heroes War Concept — Tactical Radar Stick & Skill Deck HUD (Quarter-View Mobile Controls)
## - 좌측 하단: 택티컬 레이더 스틱 (360도 전술 아날로그 조이스틱 + 네온 시안/앰버 링)
## - 우측 하단: 히어로즈 워 스타일 택티컬 스킬 덱 (⚔ STRIKE, 🛡 PARRY, 💨 DASH, ▲ LEAP)
## - 우측 상단: '📱 택티컬 덱 ON/OFF' 스위치
## V3-010: Robust Multi-Touch Single-Owner Architecture, Per-Pointer Action Ownership, & Slide Transitions

var is_controls_visible: bool = true

# Pointer & Action Ownership Architecture
# pointer_id (int) -> Dictionary: { "type": "action" | "joystick" | "empty", "action": String, "btn": Button }
var _pointer_map: Dictionary = {}
var _action_ref_counts: Dictionary = {}
var _button_actions: Dictionary = {} # Button -> String (action_name)
var _button_styles: Dictionary = {}  # Button -> { "normal": StyleBox, "pressed": StyleBox }

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_reset_joystick()
		_release_all_actions()


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
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# 3. Top-Right Tactical Pad Toggle Button (Standard GUI button)
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
	# Single-owner input: do not let Godot GUI intercept touch/mouse events
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_col
	normal_style.border_color = rim_col
	normal_style.set_border_width_all(2)
	normal_style.border_width_bottom = 5
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_top_right = 18
	normal_style.corner_radius_bottom_left = 18
	btn.add_theme_stylebox_override("normal", normal_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
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
	_button_styles[btn] = { "normal": normal_style, "pressed": pressed_style }
	return btn


# ==============================================================================
# Single-Owner Multi-Touch & Pointer Event Handling
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not is_controls_visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var pointer_id: int = event.index
	if event.pressed:
		# Check if touch hit an action button
		var hit_btn := _find_button_at_position(event.position)
		if hit_btn != null:
			var act_name: String = _button_actions[hit_btn]
			_pointer_map[pointer_id] = { "type": "action", "action": act_name, "btn": hit_btn }
			_press_action_for_pointer(act_name, hit_btn)
			return

		# Check if touch hit joystick zone
		if _is_in_joystick_zone(event.position):
			# Real touch always takes precedence over emulated mouse
			is_dragging = true
			drag_touch_index = pointer_id
			_pointer_map[pointer_id] = { "type": "joystick" }
			_update_joystick(event.position)
	else:
		# Pointer released
		if _pointer_map.has(pointer_id):
			var entry: Dictionary = _pointer_map[pointer_id]
			if entry.get("type", "") == "action":
				_release_action_for_pointer(entry.action, entry.btn)
			elif entry.get("type", "") == "joystick":
				if pointer_id == drag_touch_index:
					_reset_joystick()
			_pointer_map.erase(pointer_id)

		if pointer_id == drag_touch_index:
			_reset_joystick()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	var pointer_id: int = event.index
	if _pointer_map.has(pointer_id):
		var entry: Dictionary = _pointer_map[pointer_id]
		var entry_type: String = entry.get("type", "")

		if entry_type == "action":
			var cur_btn: Button = entry.btn
			var cur_act: String = entry.action
			if cur_btn != null and is_instance_valid(cur_btn) and cur_btn.get_global_rect().has_point(event.position):
				# Pointer is still within current button
				return
			else:
				# Pointer drifted out of current button: check if entered another button
				var new_btn := _find_button_at_position(event.position)
				if new_btn != null:
					# Slide Transition into new button
					var new_act: String = _button_actions[new_btn]
					_release_action_for_pointer(cur_act, cur_btn)
					_pointer_map[pointer_id] = { "type": "action", "action": new_act, "btn": new_btn }
					_press_action_for_pointer(new_act, new_btn)
				else:
					# Drifted into empty space: release action, retain pointer tracking
					_release_action_for_pointer(cur_act, cur_btn)
					_pointer_map[pointer_id] = { "type": "empty" }

		elif entry_type == "empty":
			# Pointer drifted into empty space, check if it entered a button
			var target_btn := _find_button_at_position(event.position)
			if target_btn != null:
				var target_act: String = _button_actions[target_btn]
				_pointer_map[pointer_id] = { "type": "action", "action": target_act, "btn": target_btn }
				_press_action_for_pointer(target_act, target_btn)

		elif entry_type == "joystick":
			if pointer_id == drag_touch_index:
				_update_joystick(event.position)

	elif is_dragging and pointer_id == drag_touch_index:
		_update_joystick(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse_pointer_id: int = 999

	if event.pressed:
		# Check if click hit an action button
		var hit_btn := _find_button_at_position(event.position)
		if hit_btn != null:
			var act_name: String = _button_actions[hit_btn]
			_pointer_map[mouse_pointer_id] = { "type": "action", "action": act_name, "btn": hit_btn }
			_press_action_for_pointer(act_name, hit_btn)
			return

		# Check if click hit joystick zone
		if _is_in_joystick_zone(event.position):
			# Do not overwrite drag_touch_index if a real touch finger (>= 0) is already active
			if drag_touch_index >= 0:
				return
			is_dragging = true
			drag_touch_index = mouse_pointer_id
			_pointer_map[mouse_pointer_id] = { "type": "joystick" }
			_update_joystick(event.position)
	else:
		# Mouse button released
		if _pointer_map.has(mouse_pointer_id):
			var entry: Dictionary = _pointer_map[mouse_pointer_id]
			if entry.get("type", "") == "action":
				_release_action_for_pointer(entry.action, entry.btn)
			elif entry.get("type", "") == "joystick":
				if drag_touch_index == mouse_pointer_id:
					_reset_joystick()
			_pointer_map.erase(mouse_pointer_id)

		if drag_touch_index == mouse_pointer_id:
			_reset_joystick()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var mouse_pointer_id: int = 999
	if _pointer_map.has(mouse_pointer_id):
		var entry: Dictionary = _pointer_map[mouse_pointer_id]
		if entry.get("type", "") == "joystick" and drag_touch_index == mouse_pointer_id:
			_update_joystick(event.position)
	elif is_dragging and drag_touch_index == mouse_pointer_id:
		_update_joystick(event.position)


# ==============================================================================
# Helper Methods: Detection, Press & Release
# ==============================================================================

func _find_button_at_position(pos: Vector2) -> Button:
	for btn in _button_actions.keys():
		if btn is Button and is_instance_valid(btn) and btn.is_visible_in_tree():
			if btn.get_global_rect().has_point(pos):
				return btn
	return null


func _is_in_joystick_zone(pos: Vector2) -> bool:
	var joy_container = get_node_or_null("RootHUD/JoystickContainer")
	if joy_container == null:
		return false
	var origin: Vector2 = joy_container.global_position
	# Circular radius check or generous bottom-left bounding box
	if (pos - origin).length() <= joystick_max_radius * 1.6:
		return true
	return pos.x < 550.0 and pos.y > 320.0


func _press_action_for_pointer(act_name: String, btn: Button) -> void:
	var cur_refs: int = _action_ref_counts.get(act_name, 0) + 1
	_action_ref_counts[act_name] = cur_refs
	if cur_refs == 1:
		Input.action_press(act_name)
	if btn != null and is_instance_valid(btn) and _button_styles.has(btn):
		btn.add_theme_stylebox_override("normal", _button_styles[btn].pressed)


func _release_action_for_pointer(act_name: String, btn: Button) -> void:
	if btn != null and is_instance_valid(btn) and _button_styles.has(btn):
		btn.add_theme_stylebox_override("normal", _button_styles[btn].normal)

	var cur_refs: int = _action_ref_counts.get(act_name, 1) - 1
	if cur_refs <= 0:
		_action_ref_counts[act_name] = 0
		if not _is_hardware_action_pressed(act_name):
			Input.action_release(act_name)
	else:
		_action_ref_counts[act_name] = cur_refs


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
	if strength < 0.15:
		_release_all_moves()
		return

	# 2.5D Belt-Scroll: Left / Right (X-axis)
	if dir.x < -0.30:
		_press_virtual_action("move_left")
		_release_virtual_action("move_right")
	elif dir.x > 0.30:
		_press_virtual_action("move_right")
		_release_virtual_action("move_left")
	else:
		_release_virtual_action("move_left")
		_release_virtual_action("move_right")

	# 2.5D Belt-Scroll: Up / Down depth navigation (Z-axis)
	if dir.y < -0.30:
		_press_virtual_action("move_up")
		_release_virtual_action("move_down")
	elif dir.y > 0.30:
		_press_virtual_action("move_down")
		_release_virtual_action("move_up")
	else:
		_release_virtual_action("move_up")
		_release_virtual_action("move_down")


func _press_virtual_action(action: String) -> void:
	var cur_refs: int = _action_ref_counts.get(action, 0)
	if cur_refs == 0:
		Input.action_press(action)
	_action_ref_counts[action] = 1


func _release_virtual_action(action: String) -> void:
	if _action_ref_counts.get(action, 0) > 0:
		_action_ref_counts[action] = 0
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


func _reset_joystick() -> void:
	is_dragging = false
	drag_touch_index = -1
	if joystick_knob != null and is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(-26.0, -26.0)
	_release_all_moves()


func _release_all_moves() -> void:
	_release_virtual_action("move_left")
	_release_virtual_action("move_right")
	_release_virtual_action("move_up")
	_release_virtual_action("move_down")


func _release_all_actions() -> void:
	for entry in _pointer_map.values():
		if entry is Dictionary and entry.get("type", "") == "action":
			var btn: Button = entry.get("btn", null)
			if btn != null and is_instance_valid(btn) and _button_styles.has(btn):
				btn.add_theme_stylebox_override("normal", _button_styles[btn].normal)
	_pointer_map.clear()
	_action_ref_counts.clear()
	_reset_joystick()

	var actions := ["move_left", "move_right", "move_up", "move_down", "attack", "guard", "dash", "jump"]
	for act in actions:
		if not _is_hardware_action_pressed(act):
			Input.action_release(act)


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
