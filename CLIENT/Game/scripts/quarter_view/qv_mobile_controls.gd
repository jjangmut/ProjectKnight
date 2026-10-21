extends CanvasLayer
class_name QVMobileControls
## 쿼터뷰 전용 360도 가상 아날로그 조이스틱 및 액션 HUD (Quarter-View Mobile Controls)
## - 좌측: 360도 아날로그 가상 조이스틱 (드래그 방향/거리 기반 8방향 액션 에뮬레이션)
## - 우측: 공격, 회피(대시), 방어, 점프 4대 고대 룬 버튼
## - 상단: '📱 패드 숨기기/켜기' 다크 글래스 토글 버튼

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

	# 1. Joystick Container (Bottom-Left)
	var joy_container := Control.new()
	joy_container.name = "JoystickContainer"
	joy_container.position = Vector2(160.0, 540.0)
	joy_container.size = Vector2(140.0, 140.0)
	root_control.add_child(joy_container)

	# Joystick Base Panel
	joystick_base = Panel.new()
	joystick_base.name = "JoystickBase"
	joystick_base.size = Vector2(130.0, 130.0)
	joystick_base.position = Vector2(-65.0, -65.0)
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.05, 0.08, 0.14, 0.5)
	base_style.border_color = Color(0.8, 0.65, 0.25, 0.6) # Gold Rune Rim
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(65)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_PASS
	joy_container.add_child(joystick_base)

	# Joystick Knob (Stick)
	joystick_knob = Panel.new()
	joystick_knob.name = "JoystickKnob"
	joystick_knob.size = Vector2(52.0, 52.0)
	joystick_knob.position = Vector2(-26.0, -26.0)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.85, 0.72, 0.35, 0.85) # Golden core
	knob_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(26)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_container.add_child(joystick_knob)

	joystick_center = joy_container.global_position

	# 2. Action Buttons Container (Bottom-Right)
	var action_container := Control.new()
	action_container.name = "ActionContainer"
	action_container.position = Vector2(1100.0, 540.0)
	root_control.add_child(action_container)

	btn_attack = _create_action_button("공격", Vector2(0.0, -20.0), Color(0.9, 0.25, 0.25, 0.85), "attack")
	btn_guard = _create_action_button("방어", Vector2(-80.0, -50.0), Color(0.2, 0.6, 0.9, 0.85), "guard")
	btn_dash = _create_action_button("회피", Vector2(-60.0, 40.0), Color(0.2, 0.8, 0.4, 0.85), "dash")
	btn_jump = _create_action_button("점프", Vector2(70.0, -40.0), Color(0.8, 0.5, 0.9, 0.85), "jump")

	action_container.add_child(btn_attack)
	action_container.add_child(btn_guard)
	action_container.add_child(btn_dash)
	action_container.add_child(btn_jump)

	# 3. Top Pad Toggle Button
	btn_toggle = Button.new()
	btn_toggle.name = "PadToggle"
	btn_toggle.text = "📱 쿼터뷰 패드 숨기기"
	btn_toggle.position = Vector2(24.0, 24.0)
	btn_toggle.size = Vector2(170.0, 38.0)
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.04, 0.06, 0.1, 0.75)
	toggle_style.border_color = Color(0.8, 0.65, 0.25, 0.8)
	toggle_style.set_border_width_all(1)
	toggle_style.set_corner_radius_all(8)
	btn_toggle.add_theme_stylebox_override("normal", toggle_style)
	btn_toggle.pressed.connect(_on_toggle_pressed)
	root_control.add_child(btn_toggle)


func _create_action_button(label_text: String, local_pos: Vector2, color: Color, action_name: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size = Vector2(68.0, 68.0)
	btn.position = local_pos - Vector2(34.0, 34.0)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 1.0, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(34)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)

	btn.button_down.connect(func(): Input.action_press(action_name))
	btn.button_up.connect(func(): Input.action_release(action_name))
	return btn


func _input(event: InputEvent) -> void:
	if not is_controls_visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# Check if touched in left half of screen
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

	# Emulate directional actions
	_emulate_direction(dir, dist / joystick_max_radius)


func _emulate_direction(dir: Vector2, strength: float) -> void:
	if strength < 0.2:
		_release_all_moves()
		return

	# X axis
	if dir.x < -0.38:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif dir.x > 0.38:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	# Y axis
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
	btn_toggle.text = "📱 쿼터뷰 패드 켜기" if not is_controls_visible else "📱 쿼터뷰 패드 숨기기"
