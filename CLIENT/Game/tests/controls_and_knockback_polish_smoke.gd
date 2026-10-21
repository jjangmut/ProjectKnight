extends SceneTree
## Verification smoke test for:
## 1. D-Pad base plate removal (only 4 directional buttons remain)
## 2. Dark gothic knight rune button styling & chevron glyphs
## 3. Persistent Mobile Toggle (No recurring pop-in after hiding)
## 4. Pure ballistic contact knockback: Movement input strictly BLOCKED while airborne in mid-air
##    and only allowed AFTER safely landing on the floor.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var watchdog := create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] controls_and_knockback_polish_smoke.gd exceeded 15s.")
		quit(1)
	)
	_run_tests.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [PASS] " + msg)
	else:
		failures += 1
		printerr("  [FAIL] " + msg)


func _run_tests() -> void:
	print("\n=======================================================")
	print(">>> RUNNING: controls_and_knockback_polish_smoke.gd <<<")
	print("=======================================================\n")

	var MobileControlsClass = preload("res://scripts/ui/mobile_controls.gd")
	var PlayerClass = preload("res://scripts/player/player.gd")
	var stage_scene := preload("res://scenes/stage/FirstStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage

	for i in range(10):
		await physics_frame

	var player = stage.player
	var controls = stage.mobile_controls

	check(player != null, "Player node active in stage")
	check(controls != null, "MobileControls active in stage")

	# -------------------------------------------------------------
	# Test 1: D-Pad Background Plate Removal & 4 Buttons Only
	# -------------------------------------------------------------
	print("\n--- Test 1: D-Pad Background Plate Removal & 4 Buttons Only ---")
	var left_zone = controls.dpad_container
	check(left_zone != null, "Left D-Pad container exists")
	check(left_zone.get_node_or_null("DPadBasePlate") == null, "DPadBasePlate permanently removed (no bulky joypad plate)")

	check(controls.btn_left != null, "Button Left exists")
	check(controls.btn_right != null, "Button Right exists")
	check(controls.btn_up != null, "Button Up exists")
	check(controls.btn_down != null, "Button Down exists")

	# Check button layout and clean glyph mode (empty text, vector chevrons)
	check(controls.btn_left.size == Vector2(76, 76), "D-Pad Left button is compact 76x76")
	check(controls.btn_left.label_text == "", "D-Pad Left has empty label text (replaced by vector chevron rune)")

	# -------------------------------------------------------------
	# Test 2: Persistent Mobile Toggle (No recurring pop-in)
	# -------------------------------------------------------------
	print("\n--- Test 2: Persistent Mobile Toggle (No Recurring Pop-In) ---")
	var btn_toggle: Button = controls.btn_toggle
	check(btn_toggle != null, "Mobile toggle button exists")
	check(MobileControlsClass.user_controls_enabled, "Controls enabled by default")
	check(btn_toggle.text == "📱 패드 숨기기", "Toggle button displays '📱 패드 숨기기'")

	var left_ctrl: Control = controls.get_node("Root/LeftControls")
	var right_ctrl: Control = controls.get_node("Root/RightControls")
	check(left_ctrl.visible and right_ctrl.visible, "Controls initially visible")

	# Click Toggle -> Hide Controls
	controls._on_toggle_pressed()
	check(not MobileControlsClass.user_controls_enabled, "user_controls_enabled set to false globally")
	check(not left_ctrl.visible and not right_ctrl.visible, "Controls hidden upon toggle press")
	check(btn_toggle.text == "📱 패드 켜기", "Toggle button updated to '📱 패드 켜기'")

	# Simulate stage transition / visibility check while hidden
	controls._update_visibility_state()
	check(not left_ctrl.visible and not right_ctrl.visible, "Controls REMAIN hidden across updates (No recurring pop-in!)")

	# Restore controls for following tests
	controls._on_toggle_pressed()
	check(MobileControlsClass.user_controls_enabled, "Controls restored to visible")
	check(left_ctrl.visible and right_ctrl.visible, "Controls visible again")

	# -------------------------------------------------------------
	# Test 3: Ballistic Contact Knockback & Mid-Air Input Blocking
	# -------------------------------------------------------------
	print("\n--- Test 3: Ballistic Contact Knockback & Mid-Air Input Blocking ---")
	player.position = Vector2(300.0, 580.0)
	player.velocity = Vector2.ZERO
	player.is_contact_knockback_airborne = false
	for i in range(15):
		await physics_frame
	check(player.is_on_floor(), "Player placed on ground floor")

	# Player is actively pressing move_right toward monster
	Input.action_press("move_right")
	for i in range(8):
		await physics_frame
	check(player.velocity.x > 0.0, "Player moving rightward into monster: vel.x = %.1f" % player.velocity.x)

	# Monster contact occurs at player's right side (x = 360)
	player._contact_knockback_until_usec = 0
	player.receive_contact_knockback(Vector2(player.global_position.x + 60.0, player.global_position.y))

	check(player.is_contact_knockback_airborne, "is_contact_knockback_airborne flag set to true")
	check(player.velocity.x == -320.0, "Knocked backwards to the left: vel.x = %.1f" % player.velocity.x)
	check(player.velocity.y == -200.0, "Popped upward into the air: vel.y = %.1f" % player.velocity.y)

	# While airborne in mid-air: Player KEEPS holding 'move_right'
	# Movement input MUST BE BLOCKED so player does NOT stop mid-air!
	var verified_airborne_backward := false
	for i in range(12):
		await physics_frame
		if not player.is_on_floor():
			check(player.velocity.x < 0.0, "Mid-air knockback preserved backward (vel.x = %.1f < 0) despite holding move_right" % player.velocity.x)
			verified_airborne_backward = true
			break
	check(verified_airborne_backward, "Player was verified flying airborne backward")

	# Wait until player safely lands on the floor
	var max_wait := 50
	while max_wait > 0:
		await physics_frame
		max_wait -= 1
		if player.is_on_floor() and not player.is_contact_knockback_airborne:
			break

	check(player.is_on_floor(), "Player safely landed on the floor after knockback arc")
	check(not player.is_contact_knockback_airborne, "is_contact_knockback_airborne cleared upon landing")

	# Now on floor, holding move_right should resume moving rightward
	for i in range(8):
		await physics_frame
	check(player.velocity.x > 0.0, "Player resumes forward movement AFTER landing: vel.x = %.1f > 0" % player.velocity.x)

	Input.action_release("move_right")
	await physics_frame

	print("\n=======================================================")
	print("RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("=======================================================\n")

	if failures == 0:
		print(">>> ALL CONTROLS & KNOCKBACK POLISH CHECKS PASSED (100% SUCCESS) <<<")
		quit(0)
	else:
		printerr(">>> FAILURES DETECTED: %d <<<" % failures)
		quit(1)
