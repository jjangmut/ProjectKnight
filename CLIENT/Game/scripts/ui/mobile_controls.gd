class_name MobileControls
extends CanvasLayer
## Professional Mobile Virtual Controls HUD for Project Knight.
## Features an 8-Directional Virtual Joypad (Left thumb: Move Left/Right, Jump Up, Platform Drop Down)
## and an Ergonomic 3-Action Triangle Cluster (Right thumb: Attack, Dash, Guard).
## Jump button has been seamlessly integrated into upward joypad direction.

var is_mobile_active: bool = true

# Virtual Joypad (Left thumb cluster)
var joystick: MobileJoypad

# Backward compatibility / legacy references (null indicates removed/superseded by joystick)
var btn_left: Control = null
var btn_right: Control = null
var btn_down: Control = null
var btn_jump: Control = null # Explicitly removed per Director's instruction

# Action buttons (Right thumb cluster: 3-Action Triangle)
var btn_attack: Control
var btn_guard: Control
var btn_dash: Control
var btn_toggle: Button

signal mobile_action_triggered(action_name: String, pressed: bool)


func _ready() -> void:
	layer = 20 # Render above HUD and world
	_check_environment_visibility()
	_build_ui()


func _exit_tree() -> void:
	release_all_touches()


func release_all_touches() -> void:
	if joystick != null:
		joystick.reset_joystick()
	var actions := ["move_left", "move_right", "move_down", "attack", "jump", "dash", "guard"]
	for act in actions:
		if Input.is_action_pressed(act):
			Input.action_release(act)


func _input(event: InputEvent) -> void:
	if not is_mobile_active or joystick == null or not joystick.is_touch_down:
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if joystick.active_touch_index == drag.index:
			joystick.process_touch_world(drag.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and joystick.active_touch_index == touch.index:
			joystick.reset_joystick()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if joystick.active_touch_index == -99:
			joystick.process_touch_world(motion.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and joystick.active_touch_index == -99:
			joystick.reset_joystick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all_touches()


func _check_environment_visibility() -> void:
	# Show on mobile platforms by default, or if touch is supported, or in PC test mode
	var has_touch := DisplayServer.is_touchscreen_available()
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	is_mobile_active = is_mobile or has_touch or true # Active by default for full mobile readiness
	visible = is_mobile_active


func _build_ui() -> void:
	var root_control := Control.new()
	root_control.name = "Root"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 1. Left Floating Joypad Touch Zone (Left 65% of screen for generous thumb reach)
	var left_zone := Control.new()
	left_zone.name = "LeftControls"
	left_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_zone.anchor_right = 0.65 # Expanded to 65% width to prevent boundary drop
	left_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(left_zone)

	joystick = MobileJoypad.new()
	joystick.name = "VirtualJoystick"
	joystick.size = Vector2(240, 240)
	joystick.custom_minimum_size = Vector2(240, 240)
	joystick.position = Vector2(50, 430) # Default resting position
	joystick.action_triggered.connect(func(act: String, prs: bool): mobile_action_triggered.emit(act, prs))
	left_zone.add_child(joystick)

	# Connect left touch zone input to float joystick dynamically to touch position
	left_zone.gui_input.connect(func(event: InputEvent):
		if not is_mobile_active:
			return
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and (joystick.active_touch_index == -1 or joystick.active_touch_index == touch.index):
				joystick.float_to(touch.position)
				joystick._begin_touch(touch.index, touch.position)
				left_zone.accept_event()
			elif not touch.pressed and joystick.active_touch_index == touch.index:
				joystick.reset_joystick()
				left_zone.accept_event()
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if joystick.active_touch_index == drag.index:
				joystick.process_touch_world(drag.position)
				left_zone.accept_event()
		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT:
				if mouse.pressed and joystick.active_touch_index == -1:
					joystick.float_to(mouse.position)
					joystick._begin_touch(-99, mouse.position)
					left_zone.accept_event()
				elif not mouse.pressed and joystick.active_touch_index == -99:
					joystick.reset_joystick()
					left_zone.accept_event()
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if joystick.is_touch_down and joystick.active_touch_index == -99:
				joystick.process_touch_world(motion.position)
				left_zone.accept_event()
	)

	# 2. Right Action Cluster Container (Responsive Anchor Bottom-Right)
	# Ergonomic 3-Button Triangle: Attack (Main 130px), Dash (Bottom-Left 110px), Guard (Top-Left 110px)
	var right_container := Control.new()
	right_container.name = "RightControls"
	right_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_container.position = Vector2(-390, -310)
	right_container.size = Vector2(380, 290)
	right_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(right_container)

	# Attack: Main big button (Right corner, primary thumb resting zone, 128x128)
	btn_attack = _create_touch_button("attack", "⚔\n공격", Vector2(190, 100), Vector2(128, 128), Color(1.0, 0.65, 0.15, 0.88))
	right_container.add_child(btn_attack)

	# Dash: Immediate thumb slide evasion (Bottom-Left of attack, 106x106)
	btn_dash = _create_touch_button("dash", "💨\n대시", Vector2(60, 130), Vector2(106, 106), Color(0.1, 0.9, 0.9, 0.88))
	right_container.add_child(btn_dash)

	# Guard: Upward thumb slide shield stance (Top-Left of attack, 106x106)
	btn_guard = _create_touch_button("guard", "🛡\n방패", Vector2(115, 12), Vector2(106, 106), Color(0.3, 0.6, 1.0, 0.88))
	right_container.add_child(btn_guard)

	# 3. Top-Right Quick Toggle Button for testing (Responsive Anchor Top-Right)
	btn_toggle = Button.new()
	btn_toggle.name = "MobileToggle"
	btn_toggle.text = "📱 모바일패드"
	btn_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_toggle.position = Vector2(-180, 24)
	btn_toggle.size = Vector2(160, 52)
	btn_toggle.add_theme_font_size_override("font_size", 20)
	btn_toggle.modulate = Color(1.0, 1.0, 1.0, 0.88)
	btn_toggle.pressed.connect(_on_toggle_pressed)
	root_control.add_child(btn_toggle)


func _on_toggle_pressed() -> void:
	is_mobile_active = not is_mobile_active
	var root_ctrl := get_node_or_null("Root/LeftControls")
	var right_ctrl := get_node_or_null("Root/RightControls")
	if root_ctrl:
		root_ctrl.visible = is_mobile_active
	if right_ctrl:
		right_ctrl.visible = is_mobile_active
	btn_toggle.modulate = Color(1.0, 1.0, 1.0, 0.8 if is_mobile_active else 0.4)


func _create_touch_button(action_name: String, label_text: String, pos: Vector2, btn_size: Vector2, theme_color: Color) -> Control:
	var btn := VirtualButton.new()
	btn.name = "Btn_" + action_name
	btn.action_name = action_name
	btn.label_text = label_text
	btn.position = pos
	btn.custom_minimum_size = btn_size
	btn.size = btn_size
	btn.theme_color = theme_color
	btn.action_triggered.connect(func(act: String, prs: bool): mobile_action_triggered.emit(act, prs))
	return btn


## 8-Directional Virtual Analog Joypad
class MobileJoypad:
	extends Control


	var base_radius: float = 76.0
	var knob_radius: float = 34.0
	var max_drag_radius: float = 62.0
	var deadzone: float = 16.0
	var follow_finger: bool = true

	var knob_offset: Vector2 = Vector2.ZERO
	var active_touch_index: int = -1
	var is_touch_down: bool = false

	var current_direction: Vector2 = Vector2.ZERO
	var active_actions: Dictionary = {
		"move_left": false,
		"move_right": false,
		"jump": false,
		"move_down": false
	}

	signal action_triggered(action_name: String, pressed: bool)


	var default_resting_pos := Vector2(50, 430)

	func float_to(touch_world_pos: Vector2) -> void:
		var half_size := size * 0.5
		var target := touch_world_pos - half_size
		if get_parent() is Control:
			var p_size: Vector2 = (get_parent() as Control).size
			target.x = clampf(target.x, 0.0, maxf(0.0, p_size.x - size.x))
			target.y = clampf(target.y, 0.0, maxf(0.0, p_size.y - size.y))
		position = target
		queue_redraw()

	func _begin_touch(touch_idx: int, touch_pos: Vector2) -> void:
		active_touch_index = touch_idx
		is_touch_down = true
		process_touch_world(touch_pos)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = size


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				if active_touch_index == -1 or active_touch_index == touch.index:
					active_touch_index = touch.index
					is_touch_down = true
					_process_touch_pos(touch.position)
					accept_event()
			else:
				if active_touch_index == touch.index:
					reset_joystick()
					accept_event()

		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if active_touch_index == drag.index:
				_process_touch_pos(drag.position)
				accept_event()

		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT:
				if mouse.pressed:
					active_touch_index = -99
					is_touch_down = true
					_process_touch_pos(mouse.position)
					accept_event()
				else:
					if active_touch_index == -99:
						reset_joystick()
						accept_event()

		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if is_touch_down and active_touch_index == -99:
				_process_touch_pos(motion.position)
				accept_event()


	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_EXIT:
			if is_touch_down and active_touch_index == -99:
				reset_joystick()


	func _exit_tree() -> void:
		reset_joystick()


	func reset_joystick() -> void:
		is_touch_down = false
		active_touch_index = -1
		knob_offset = Vector2.ZERO
		current_direction = Vector2.ZERO
		_update_actions(false, false, false, false)
		queue_redraw()


	## Manual simulation interface for automated tests
	func simulate_drag(offset: Vector2) -> void:
		is_touch_down = true
		active_touch_index = 0
		var center := size * 0.5
		_process_touch_pos(center + offset)


	func process_touch_world(world_pos: Vector2) -> void:
		var center := position + (size * 0.5)
		var delta := world_pos - center
		var length := delta.length()

		if length > max_drag_radius:
			if follow_finger:
				var excess := length - max_drag_radius
				var move_delta := delta.normalized() * excess
				position += move_delta
				if get_parent() is Control:
					var p_size: Vector2 = (get_parent() as Control).size
					position.x = clampf(position.x, 0.0, maxf(0.0, p_size.x - size.x))
					position.y = clampf(position.y, 0.0, maxf(0.0, p_size.y - size.y))
				center = position + (size * 0.5)
				delta = world_pos - center
			knob_offset = delta.normalized() * max_drag_radius
		else:
			knob_offset = delta

		var final_length := delta.length()
		if final_length < deadzone:
			current_direction = Vector2.ZERO
			_update_actions(false, false, false, false)
		else:
			var dir := delta.normalized()
			current_direction = dir
			# 8-Directional discretization using 22.5-degree thresholds (cos(67.5°) ≈ 0.38)
			var want_left := dir.x < -0.38
			var want_right := dir.x > 0.38
			var want_up := dir.y < -0.38    # Up = Jump (-Y in 2D)
			var want_down := dir.y > 0.38  # Down = Drop down / Move down (+Y in 2D)
			_update_actions(want_left, want_right, want_up, want_down)

		queue_redraw()


	func _process_touch_pos(pos: Vector2) -> void:
		process_touch_world(position + pos)


	func _update_actions(want_left: bool, want_right: bool, want_up: bool, want_down: bool) -> void:
		_set_action_state("move_left", want_left)
		_set_action_state("move_right", want_right)
		_set_action_state("jump", want_up)
		_set_action_state("move_down", want_down)


	func _set_action_state(act: String, should_press: bool) -> void:
		if active_actions[act] == should_press:
			return
		active_actions[act] = should_press

		if should_press:
			Input.action_press(act)
		else:
			Input.action_release(act)

		action_triggered.emit(act, should_press)


	func _draw() -> void:
		var center := size * 0.5

		# 1. Outer Dark Base Disk
		draw_circle(center, base_radius, Color(0.06, 0.10, 0.18, 0.60))

		# 2. Base Glowing Ring
		var base_ring_color := Color(0.25, 0.65, 0.95, 0.80) if is_touch_down else Color(0.20, 0.45, 0.70, 0.50)
		draw_arc(center, base_radius, 0, TAU, 48, base_ring_color, 3.5, true)

		# 3. 8-Direction Rune Tick Marks
		for i in range(8):
			var angle := i * (TAU / 8.0)
			var dir_vec := Vector2(cos(angle), sin(angle))
			var p1 := center + dir_vec * (base_radius - 12.0)
			var p2 := center + dir_vec * (base_radius - 2.0)

			# Check if this sector is currently active
			var is_sector_active := false
			if is_touch_down and current_direction != Vector2.ZERO:
				if current_direction.dot(dir_vec) > 0.75:
					is_sector_active = true

			var tick_col := Color(1.0, 0.85, 0.30, 0.95) if is_sector_active else Color(0.35, 0.55, 0.75, 0.45)
			var line_width := 4.0 if is_sector_active else 2.0
			draw_line(p1, p2, tick_col, line_width, true)

		# 4. Guide Direction Labels (Jump Up ▲, Drop Down ▼, ◀, ▶)
		var font := ThemeDB.fallback_font
		var jump_col := Color(1.0, 0.85, 0.30, 0.95) if active_actions["jump"] else Color(0.6, 0.85, 1.0, 0.65)
		var drop_col := Color(1.0, 0.85, 0.30, 0.95) if active_actions["move_down"] else Color(0.6, 0.85, 1.0, 0.65)
		var left_col := Color(1.0, 0.85, 0.30, 0.95) if active_actions["move_left"] else Color(0.6, 0.85, 1.0, 0.65)
		var right_col := Color(1.0, 0.85, 0.30, 0.95) if active_actions["move_right"] else Color(0.6, 0.85, 1.0, 0.65)

		draw_string(font, center + Vector2(-18, -base_radius + 24), "▲점프", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, jump_col)
		draw_string(font, center + Vector2(-18, base_radius - 12), "▼하강", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, drop_col)
		draw_string(font, center + Vector2(-base_radius + 10, 6), "◀", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, left_col)
		draw_string(font, center + Vector2(base_radius - 24, 6), "▶", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, right_col)

		# 5. Connected Vector Line while dragging
		if is_touch_down and knob_offset.length() > deadzone:
			var link_color := Color(0.35, 0.85, 1.0, 0.45)
			draw_line(center, center + knob_offset, link_color, 3.0, true)

		# 6. Knob (Thumb Thumbstick)
		var knob_pos := center + knob_offset
		var knob_bg_color := Color(0.12, 0.22, 0.36, 0.90) if is_touch_down else Color(0.10, 0.16, 0.25, 0.75)
		draw_circle(knob_pos, knob_radius, knob_bg_color)

		var knob_ring_col := Color(0.40, 0.95, 1.0, 0.95) if is_touch_down else Color(0.50, 0.75, 0.95, 0.70)
		draw_arc(knob_pos, knob_radius, 0, TAU, 32, knob_ring_col, 3.5, true)

		# Knob center core
		var core_col := Color(1.0, 0.9, 0.4, 0.90) if is_touch_down else Color(0.3, 0.6, 0.9, 0.5)
		draw_circle(knob_pos, 8.0, core_col)


## Ergonomic Virtual Button for Action Cluster
class VirtualButton:
	extends Control

	var action_name: String = ""
	var label_text: String = ""
	var theme_color: Color = Color(0.3, 0.5, 0.8, 0.6)
	var is_pressed: bool = false
	var active_touch_index: int = -1

	signal action_triggered(act: String, prs: bool)


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = size


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				if not is_pressed and (active_touch_index == -1 or active_touch_index == touch.index):
					active_touch_index = touch.index
					_set_pressed(true)
					accept_event()
			else:
				if is_pressed and active_touch_index == touch.index:
					active_touch_index = -1
					_set_pressed(false)
					accept_event()

		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT:
				if mouse.pressed:
					if not is_pressed:
						_set_pressed(true)
						accept_event()
				else:
					if is_pressed:
						_set_pressed(false)
						accept_event()


	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_EXIT:
			if is_pressed and active_touch_index == -1:
				_set_pressed(false)


	func _exit_tree() -> void:
		if is_pressed:
			_set_pressed(false)


	func _set_pressed(pressed: bool) -> void:
		if is_pressed == pressed:
			return
		is_pressed = pressed
		queue_redraw()

		if pressed:
			Input.action_press(action_name)
		else:
			Input.action_release(action_name)

		action_triggered.emit(action_name, pressed)


	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		var draw_radius := radius * (0.92 if is_pressed else 1.0)

		# Outer glowing ring
		var ring_color := theme_color
		ring_color.a = 0.95 if is_pressed else 0.75
		draw_arc(center, draw_radius, 0, TAU, 32, ring_color, 4.0, true)

		# Semi-transparent background disc
		var bg_color := theme_color
		bg_color.a = 0.55 if is_pressed else 0.28
		draw_circle(center, draw_radius - 2.0, bg_color)

		# Inner active burst
		if is_pressed:
			var burst_color := Color.WHITE
			burst_color.a = 0.38
			draw_circle(center, draw_radius * 0.7, burst_color)

		# Center text / icon label (2x Scale)
		var font := ThemeDB.fallback_font
		if "\n" in label_text:
			var parts := label_text.split("\n")
			var top_text := parts[0]
			var bot_text := parts[1]
			var top_size := font.get_string_size(top_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 38)
			var bot_size := font.get_string_size(bot_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
			draw_string(font, center + Vector2(-top_size.x * 0.5, -6), top_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 38, Color.WHITE)
			draw_string(font, center + Vector2(-bot_size.x * 0.5, 26), bot_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(0.95, 0.95, 0.95, 0.95))
		else:
			var string_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34)
			draw_string(font, center + Vector2(-string_size.x * 0.5, string_size.y * 0.35), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34, Color.WHITE)

