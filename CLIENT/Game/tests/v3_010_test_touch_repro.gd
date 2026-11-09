extends SceneTree

# Formal verification test for V3-010 Multi-Touch Architecture & Stage 1 Onboarding
var passed_checks: int = 0
var failed_checks: int = 0
var failure_log: Array[String] = []

func _init() -> void:
	print(">>> [V3-010 TEST] Running multi-touch & controls verification... <<<")
	call_deferred("_run_verification_tests")

func _run_verification_tests() -> void:
	var root_node = root
	var mobile_controls = QVMobileControls.new()
	root_node.add_child(mobile_controls)

	# Ensure layout is ready
	await create_timer(0.1).timeout

	print("\n--- TEST 1: Dual Touch (Joystick Move + Skill Button Hold) ---")
	var joy_center = mobile_controls.joystick_center
	var ev_touch0_down = InputEventScreenTouch.new()
	ev_touch0_down.index = 0
	ev_touch0_down.pressed = true
	ev_touch0_down.position = joy_center
	mobile_controls._input(ev_touch0_down)

	var ev_drag0 = InputEventScreenDrag.new()
	ev_drag0.index = 0
	ev_drag0.position = joy_center + Vector2(50.0, 0.0) # Move right
	mobile_controls._input(ev_drag0)

	var move_right_pressed = Input.is_action_pressed("move_right")
	if move_right_pressed:
		_pass("Test 1.1: Joystick drag right activates move_right")
	else:
		_fail("Test 1.1: Joystick drag right failed to activate move_right")

	# Finger 1 on attack button
	var btn_attack = mobile_controls.btn_attack
	var attack_center = btn_attack.get_global_rect().get_center()

	var ev_touch1_down = InputEventScreenTouch.new()
	ev_touch1_down.index = 1
	ev_touch1_down.pressed = true
	ev_touch1_down.position = attack_center
	mobile_controls._input(ev_touch1_down)

	var attack_pressed = Input.is_action_pressed("attack")
	if attack_pressed:
		_pass("Test 1.2: Finger 1 on Attack activates attack")
	else:
		_fail("Test 1.2: Finger 1 on Attack failed to activate attack")

	# Finger 1 releases attack
	var ev_touch1_up = InputEventScreenTouch.new()
	ev_touch1_up.index = 1
	ev_touch1_up.pressed = false
	ev_touch1_up.position = attack_center
	mobile_controls._input(ev_touch1_up)

	var attack_after_up = Input.is_action_pressed("attack")
	var move_right_after_up = Input.is_action_pressed("move_right")
	if not attack_after_up and move_right_after_up:
		_pass("Test 1.3: Releasing Finger 1 releases attack while maintaining move_right (Independent pointers)")
	else:
		_fail("Test 1.3: Releasing Finger 1 corrupted action state (attack=%s, move_right=%s)" % [attack_after_up, move_right_after_up])

	print("\n--- TEST 2: Emulated Mouse Event Immunity while Touch Dragging ---")
	# In mobile emulation or touch screens with mouse emulation on,
	# an InputEventMouseButton arrives while touch 0 is dragging.
	var ev_mouse_move = InputEventMouseButton.new()
	ev_mouse_move.button_index = MOUSE_BUTTON_LEFT
	ev_mouse_move.pressed = true
	ev_mouse_move.position = joy_center + Vector2(50.0, 0.0)
	mobile_controls._input(ev_mouse_move)

	# drag_touch_index must NOT be clobbered to 999 while touch 0 is dragging!
	print("drag_touch_index after mouse event: ", mobile_controls.drag_touch_index)
	if mobile_controls.drag_touch_index == 0:
		_pass("Test 2.1: drag_touch_index retained active touch index 0 against mouse clobbering")
	else:
		_fail("Test 2.1: drag_touch_index clobbered to %s" % mobile_controls.drag_touch_index)

	# Now finger 0 releases!
	var ev_touch0_up = InputEventScreenTouch.new()
	ev_touch0_up.index = 0
	ev_touch0_up.pressed = false
	ev_touch0_up.position = joy_center + Vector2(50.0, 0.0)
	mobile_controls._input(ev_touch0_up)

	var move_right_after_touch0_up = Input.is_action_pressed("move_right")
	if not mobile_controls.is_dragging and not move_right_after_touch0_up:
		_pass("Test 2.2: Touch 0 release cleanly resets joystick and releases move_right")
	else:
		_fail("Test 2.2: Touch 0 release failed! is_dragging=%s, move_right=%s" % [mobile_controls.is_dragging, move_right_after_touch0_up])

	mobile_controls._reset_joystick()
	mobile_controls._release_all_actions()

	print("\n--- TEST 3: Slide / Drag Off Button into Empty Space & Transition to Another Button ---")
	# Finger 2 touches Guard button
	var btn_guard = mobile_controls.btn_guard
	var guard_center = btn_guard.get_global_rect().get_center()

	var ev_touch_guard_down = InputEventScreenTouch.new()
	ev_touch_guard_down.index = 2
	ev_touch_guard_down.pressed = true
	ev_touch_guard_down.position = guard_center
	mobile_controls._input(ev_touch_guard_down)

	if Input.is_action_pressed("guard"):
		_pass("Test 3.1: Guard pressed on touch down")
	else:
		_fail("Test 3.1: Guard not pressed on touch down")

	# Finger 2 drags 200px away into empty space
	var ev_drag_guard = InputEventScreenDrag.new()
	ev_drag_guard.index = 2
	ev_drag_guard.position = guard_center + Vector2(0.0, -200.0)
	mobile_controls._input(ev_drag_guard)

	# Should release guard because it drifted into empty space
	var guard_while_drifted = Input.is_action_pressed("guard")
	if not guard_while_drifted:
		_pass("Test 3.2: Dragging out of Guard button into empty space immediately releases guard action")
	else:
		_fail("Test 3.2: Dragging out of button failed to release guard action!")

	# Now slide directly into Dash button!
	var btn_dash = mobile_controls.btn_dash
	var dash_center = btn_dash.get_global_rect().get_center()
	var ev_drag_to_dash = InputEventScreenDrag.new()
	ev_drag_to_dash.index = 2
	ev_drag_to_dash.position = dash_center
	mobile_controls._input(ev_drag_to_dash)

	var dash_after_slide = Input.is_action_pressed("dash")
	if dash_after_slide:
		_pass("Test 3.3: Sliding pointer 2 into Dash button activates dash action (Slide Transition)")
	else:
		_fail("Test 3.3: Sliding pointer into Dash failed to activate dash!")

	# Release at dash
	var ev_touch_dash_up = InputEventScreenTouch.new()
	ev_touch_dash_up.index = 2
	ev_touch_dash_up.pressed = false
	ev_touch_dash_up.position = dash_center
	mobile_controls._input(ev_touch_dash_up)

	if not Input.is_action_pressed("dash"):
		_pass("Test 3.4: Releasing pointer at Dash button releases dash")
	else:
		_fail("Test 3.4: Releasing at Dash failed to release dash!")

	print("\n--- TEST 4: Window Focus Loss & Pause Notification ---")
	Input.action_press("move_left")
	mobile_controls._pointer_map[99] = { "type": "action", "action": "attack", "btn": btn_attack }
	mobile_controls._action_ref_counts["attack"] = 1
	Input.action_press("attack")
	mobile_controls.is_dragging = true

	mobile_controls.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var left_stuck = Input.is_action_pressed("move_left")
	var attack_stuck = Input.is_action_pressed("attack")
	if not left_stuck and not attack_stuck and not mobile_controls.is_dragging:
		_pass("Test 4: Focus out notification properly clears all virtual actions and joystick")
	else:
		_fail("Test 4: Focus out failed to clear! move_left=%s, attack=%s, is_dragging=%s" % [left_stuck, attack_stuck, mobile_controls.is_dragging])

	print("\n--- TEST 5: Single-Owner Input Architecture (No Redundant Button Signals) ---")
	var has_button_down_conn = mobile_controls.btn_attack.button_down.get_connections().size() > 0
	var mouse_filter_ignored = (mobile_controls.btn_attack.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	if not has_button_down_conn and mouse_filter_ignored:
		_pass("Test 5: Single-owner architecture verified: No redundant button_down signals, mouse_filter=IGNORE")
	else:
		_fail("Test 5: Redundant button signals or wrong mouse filter! conn=%s, filter=%s" % [has_button_down_conn, mobile_controls.btn_attack.mouse_filter])

	print("\n==================================================")
	print("AUDIT SUMMARY: Passed=%d, Failed=%d" % [passed_checks, failed_checks])
	for f in failure_log:
		print("  [FAIL] ", f)
	print("==================================================")

	mobile_controls._release_all_actions()
	mobile_controls.queue_free()
	quit(0 if failed_checks == 0 else 1)

func _pass(msg: String) -> void:
	passed_checks += 1
	print("  [PASS] ", msg)

func _fail(msg: String) -> void:
	failed_checks += 1
	failure_log.append(msg)
	print("  [FAIL] ", msg)
