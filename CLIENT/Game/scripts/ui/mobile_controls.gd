class_name MobileControls
extends CanvasLayer
## Professional Mobile Virtual Controls HUD for Project Knight.
## Features:
## 1. Fixed 4-Directional D-Pad (Left cluster: Left/Right move, Down drop-through platform, Up)
##    - Touch & hold to move continuously, release to stop.
## 2. Action Cluster (Right cluster: Attack, Jump [replaces Dash], Guard).
##    - Dash has been disabled/superseded by Jump.

static var user_controls_enabled: bool = true
var is_mobile_active: bool = true

# Fixed 4-Direction D-Pad (Left thumb cluster)
var dpad_container: Control
var btn_left: Control
var btn_right: Control
var btn_up: Control
var btn_down: Control

# Action buttons (Right thumb cluster)
var btn_attack: Control
var btn_jump: Control
var btn_guard: Control
var btn_dash: Control = null # Explicitly removed & superseded by btn_jump per user instruction
var btn_toggle: Button

# Compatibility reference
var joystick: Control = null

signal mobile_action_triggered(action_name: String, pressed: bool)

const TexJoypadBase = preload("res://assets/ui/joypad_base.png")
const TexJoypadKnob = preload("res://assets/ui/joypad_knob.png")
const TexBtnAttack = preload("res://assets/ui/btn_attack.png")
const TexBtnDash = preload("res://assets/ui/btn_dash.png")
const TexBtnJump = preload("res://assets/ui/btn_jump.png")
const TexBtnGuard = preload("res://assets/ui/btn_guard.png")


func _ready() -> void:
	layer = 20 # Render above HUD and world
	is_mobile_active = user_controls_enabled
	_build_ui()
	_update_visibility_state()


func _exit_tree() -> void:
	release_all_touches()


func release_all_touches() -> void:
	var actions := ["move_left", "move_right", "move_down", "move_up", "attack", "jump", "guard"]
	for act in actions:
		if InputMap.has_action(act) and Input.is_action_pressed(act):
			Input.action_release(act)
	if btn_left is VirtualButton and (btn_left as VirtualButton).is_pressed:
		(btn_left as VirtualButton)._set_pressed(false)
	if btn_right is VirtualButton and (btn_right as VirtualButton).is_pressed:
		(btn_right as VirtualButton)._set_pressed(false)
	if btn_up is VirtualButton and (btn_up as VirtualButton).is_pressed:
		(btn_up as VirtualButton)._set_pressed(false)
	if btn_down is VirtualButton and (btn_down as VirtualButton).is_pressed:
		(btn_down as VirtualButton)._set_pressed(false)
	if btn_attack is VirtualButton and (btn_attack as VirtualButton).is_pressed:
		(btn_attack as VirtualButton)._set_pressed(false)
	if btn_jump is VirtualButton and (btn_jump as VirtualButton).is_pressed:
		(btn_jump as VirtualButton)._set_pressed(false)
	if btn_guard is VirtualButton and (btn_guard as VirtualButton).is_pressed:
		(btn_guard as VirtualButton)._set_pressed(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all_touches()


func _update_visibility_state() -> void:
	is_mobile_active = user_controls_enabled
	if not is_mobile_active:
		release_all_touches()
	var left_ctrl := get_node_or_null("Root/LeftControls") as Control
	var right_ctrl := get_node_or_null("Root/RightControls") as Control
	if left_ctrl:
		left_ctrl.visible = is_mobile_active
		left_ctrl.process_mode = Node.PROCESS_MODE_INHERIT if is_mobile_active else Node.PROCESS_MODE_DISABLED
	if right_ctrl:
		right_ctrl.visible = is_mobile_active
		right_ctrl.process_mode = Node.PROCESS_MODE_INHERIT if is_mobile_active else Node.PROCESS_MODE_DISABLED
	if btn_toggle:
		btn_toggle.text = "📱 패드 숨기기" if is_mobile_active else "📱 패드 켜기"
		btn_toggle.modulate = Color(1.0, 1.0, 1.0, 0.9 if is_mobile_active else 0.5)


func _build_ui() -> void:
	var root_control := Control.new()
	root_control.name = "Root"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 1. Left Fixed 4-Way D-Pad Container (Without background plate per user instruction)
	var left_zone := Control.new()
	left_zone.name = "LeftControls"
	left_zone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_zone.position = Vector2(40, -280)
	left_zone.size = Vector2(250, 250)
	left_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(left_zone)
	dpad_container = left_zone

	# 4 Clean Directional Buttons (Left, Right, Up, Down) in ergonomic Cross layout (76x76px)
	var btn_sz := Vector2(76, 76)
	btn_left = _create_dpad_button("move_left", "", Vector2(8, 87), btn_sz)
	left_zone.add_child(btn_left)

	btn_right = _create_dpad_button("move_right", "", Vector2(166, 87), btn_sz)
	left_zone.add_child(btn_right)

	btn_up = _create_dpad_button("move_up", "", Vector2(87, 8), btn_sz)
	left_zone.add_child(btn_up)

	btn_down = _create_dpad_button("move_down", "", Vector2(87, 166), btn_sz)
	left_zone.add_child(btn_down)

	# 2. Right Action Cluster Container (Attack, Jump [replaces Dash], Guard)
	var right_container := Control.new()
	right_container.name = "RightControls"
	right_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_container.position = Vector2(-390, -310)
	right_container.size = Vector2(380, 290)
	right_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(right_container)

	# Attack: Main big button (Right corner, primary thumb zone, 128x128)
	btn_attack = _create_touch_button("attack", "공격", Vector2(190, 100), Vector2(128, 128), Color(1.0, 0.65, 0.15, 0.88), TexBtnAttack)
	right_container.add_child(btn_attack)

	# Jump: Dedicated Valkyrie Winged Jump button replacing old Dash! (Bottom-Left of attack, 106x106)
	btn_jump = _create_touch_button("jump", "점프", Vector2(60, 130), Vector2(106, 106), Color(0.2, 0.9, 0.6, 0.88), TexBtnJump)
	right_container.add_child(btn_jump)
	btn_dash = btn_jump # Alias for compatibility

	# Guard: Upward thumb shield stance (Top-Left of attack, 106x106)
	btn_guard = _create_touch_button("guard", "방어", Vector2(115, 12), Vector2(106, 106), Color(0.3, 0.6, 1.0, 0.88), TexBtnGuard)
	right_container.add_child(btn_guard)

	# 3. Top-Right Quick Toggle Button (Always visible so user can toggle back anytime)
	btn_toggle = Button.new()
	btn_toggle.name = "MobileToggle"
	btn_toggle.text = "📱 패드 숨기기" if user_controls_enabled else "📱 패드 켜기"
	btn_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_toggle.position = Vector2(-190, 24)
	btn_toggle.size = Vector2(170, 48)
	btn_toggle.add_theme_font_size_override("font_size", 16)

	# Gothic Translucent Glass HUD Style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.09, 0.14, 0.82)
	style_normal.border_color = Color(0.85, 0.72, 0.42, 0.80)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(8)
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.14, 0.18, 0.24, 0.90)
	style_hover.border_color = Color(1.2, 1.0, 0.6, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(8)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.24, 0.18, 0.08, 0.95)
	style_pressed.border_color = Color(1.5, 1.25, 0.65, 1.0)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(8)

	btn_toggle.add_theme_stylebox_override("normal", style_normal)
	btn_toggle.add_theme_stylebox_override("hover", style_hover)
	btn_toggle.add_theme_stylebox_override("pressed", style_pressed)
	btn_toggle.add_theme_stylebox_override("focus", style_normal)
	btn_toggle.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	btn_toggle.add_theme_color_override("font_hover_color", Color(1.2, 1.1, 0.9))
	btn_toggle.pressed.connect(_on_toggle_pressed)
	root_control.add_child(btn_toggle)


func _on_toggle_pressed() -> void:
	user_controls_enabled = not user_controls_enabled
	_update_visibility_state()


func _create_dpad_button(action_name: String, label_text: String, pos: Vector2, btn_size: Vector2) -> Control:
	var btn := VirtualButton.new()
	btn.name = "Btn_" + action_name
	btn.action_name = action_name
	btn.label_text = label_text
	btn.position = pos
	btn.custom_minimum_size = btn_size
	btn.size = btn_size
	btn.theme_color = Color(0.18, 0.22, 0.32, 0.85)
	btn.action_triggered.connect(func(act: String, prs: bool): mobile_action_triggered.emit(act, prs))
	return btn


func _create_touch_button(action_name: String, label_text: String, pos: Vector2, btn_size: Vector2, theme_color: Color, tex: Texture2D) -> Control:
	var btn := VirtualButton.new()
	btn.name = "Btn_" + action_name
	btn.action_name = action_name
	btn.label_text = label_text
	btn.position = pos
	btn.custom_minimum_size = btn_size
	btn.size = btn_size
	btn.theme_color = theme_color
	btn.button_texture = tex
	btn.action_triggered.connect(func(act: String, prs: bool): mobile_action_triggered.emit(act, prs))
	return btn


## Ergonomic Virtual Button with Touch-and-Hold functionality
class VirtualButton:
	extends Control

	var action_name: String = ""
	var label_text: String = ""
	var theme_color: Color = Color(0.2, 0.3, 0.45, 0.8)
	var button_texture: Texture2D = null
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

		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if active_touch_index == drag.index:
				var local_rect := Rect2(Vector2.ZERO, size)
				# Slid off button margin
				if not local_rect.has_point(drag.position):
					if is_pressed:
						active_touch_index = -1
						_set_pressed(false)
				accept_event()

		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT:
				if mouse.pressed:
					if not is_pressed:
						active_touch_index = -99
						_set_pressed(true)
						accept_event()
				else:
					if is_pressed and active_touch_index == -99:
						active_touch_index = -1
						_set_pressed(false)
						accept_event()


	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_EXIT:
			if is_pressed and active_touch_index == -99:
				active_touch_index = -1
				_set_pressed(false)


	func _exit_tree() -> void:
		if is_pressed:
			_set_pressed(false)


	func _set_pressed(pressed: bool) -> void:
		if is_pressed == pressed:
			return
		is_pressed = pressed
		queue_redraw()

		if not action_name.is_empty():
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			if pressed:
				Input.action_press(action_name)
			else:
				Input.action_release(action_name)

		action_triggered.emit(action_name, pressed)


	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		var draw_radius := radius * (0.92 if is_pressed else 1.0)

		# 1. Custom Button Texture or Forged Plate
		if button_texture != null:
			var b_dim := Vector2(draw_radius * 2.0, draw_radius * 2.0)
			var b_rect := Rect2(center - b_dim * 0.5, b_dim)
			var b_tint := Color(1.35, 1.25, 1.1, 1.0) if is_pressed else Color(1.0, 1.0, 1.0, 0.95)
			draw_texture_rect(button_texture, b_rect, false, b_tint)
		else:
			# Premium Dark Gothic Knight Rune D-Pad Button Plate
			var pad_inset := 2.5 if is_pressed else 0.0
			var btn_rect := Rect2(Vector2(pad_inset, pad_inset), size - Vector2(pad_inset * 2.0, pad_inset * 2.0))

			# 1. Slate-Iron Metal Base
			var bg_col := Color(0.08, 0.12, 0.18, 0.90) if not is_pressed else Color(0.24, 0.18, 0.08, 0.96)
			draw_rect(btn_rect, bg_col, true)

			# 2. Antique Gold / HDR Sun Gold Rune Border
			var border_col := Color(0.85, 0.72, 0.42, 0.88) if not is_pressed else Color(1.8, 1.45, 0.6, 1.0)
			var border_width := 2.0 if not is_pressed else 3.2
			draw_rect(btn_rect, border_col, false, border_width)

			# 3. Inner Decorative Bevel Accent
			var inner_rect := btn_rect.grow(-4.0)
			var inner_col := Color(0.35, 0.45, 0.55, 0.35) if not is_pressed else Color(1.4, 1.1, 0.4, 0.45)
			draw_rect(inner_rect, inner_col, false, 1.0)

			# 4. Pressed Radiant Core Glow
			if is_pressed:
				draw_circle(center, 18.0, Color(1.6, 1.3, 0.5, 0.3))

			# 5. Sharp Vector Rune Arrow Glyphs
			var asz := 16.0
			var arrow: PackedVector2Array = []
			match action_name:
				"move_up":
					arrow = PackedVector2Array([
						center + Vector2(0, -asz),
						center + Vector2(asz * 0.85, asz * 0.5),
						center + Vector2(0, asz * 0.15),
						center + Vector2(-asz * 0.85, asz * 0.5)
					])
				"move_down":
					arrow = PackedVector2Array([
						center + Vector2(0, asz),
						center + Vector2(asz * 0.85, -asz * 0.5),
						center + Vector2(0, -asz * 0.15),
						center + Vector2(-asz * 0.85, -asz * 0.5)
					])
				"move_left":
					arrow = PackedVector2Array([
						center + Vector2(-asz, 0),
						center + Vector2(asz * 0.5, -asz * 0.85),
						center + Vector2(asz * 0.15, 0),
						center + Vector2(asz * 0.5, asz * 0.85)
					])
				"move_right":
					arrow = PackedVector2Array([
						center + Vector2(asz, 0),
						center + Vector2(-asz * 0.5, -asz * 0.85),
						center + Vector2(-asz * 0.15, 0),
						center + Vector2(-asz * 0.5, asz * 0.85)
					])

			if not arrow.is_empty():
				var arrow_fill := Color(0.92, 0.82, 0.58, 0.95) if not is_pressed else Color(2.4, 2.0, 1.2, 1.0)
				draw_colored_polygon(arrow, arrow_fill)
				var outline := PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]])
				draw_polyline(outline, Color(1.0, 0.95, 0.8, 1.0) if is_pressed else Color(0.65, 0.52, 0.3, 0.8), 1.6, true)

		# 2. Active Touch Radiant Burst Glow for textured buttons
		if is_pressed and button_texture != null:
			draw_circle(center, draw_radius * 0.68, Color(1.0, 0.95, 0.75, 0.35))
			draw_arc(center, draw_radius, 0, TAU, 28, Color(1.5, 1.3, 0.6, 0.95), 3.2, true)

		# 3. Clean gothic sub-caption badge for action buttons (공격, 점프, 방어)
		if not label_text.is_empty():
			var font := ThemeDB.fallback_font
			var font_size := 15
			var str_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := center + Vector2(-str_size.x * 0.5, draw_radius * 0.60)
			# Refined gothic pill panel behind caption to ensure high contrast & elegant HUD look
			var pill_rect := Rect2(text_pos + Vector2(-10, -2), Vector2(str_size.x + 20, font_size + 4))
			draw_rect(pill_rect, Color(0.04, 0.07, 0.12, 0.85), true)
			draw_rect(pill_rect, Color(0.85, 0.72, 0.42, 0.75) if not is_pressed else Color(1.5, 1.25, 0.6, 1.0), false, 1.2)
			draw_string(font, text_pos + Vector2(1, font_size - 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.95))
			draw_string(font, text_pos + Vector2(0, font_size - 2), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.94, 0.82, 0.95))
