extends SceneTree
## Automated QA Smoke Test for Mobile Virtual Controls UI & Multi-touch Emulation.
## Verifies that:
## 1. MobileControls UI features 8-Direction Virtual Joypad & Ergonomic 3 Action buttons (Attack, Dash, Guard).
## 2. Jump button has been eliminated and integrated into Joypad Up/Diagonals.
## 3. Joypad 8 directions (Up, Down, Left, Right, 4 Diagonals) cleanly emulate mapped actions.
## 4. Multi-touch (Joypad drag + Right thumb attack/dash/guard) functions concurrently.
## 5. Mobile toggle button toggles control overlay visibility.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func _run() -> void:
	print("\n--- START MOBILE VIRTUAL JOYPAD & CONTROLS SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	var controls_scene := load("res://scenes/ui/MobileControls.tscn") as PackedScene
	var mobile_controls: MobileControls = controls_scene.instantiate()
	world.add_child(mobile_controls)

	await process_frame
	await process_frame

	print("\n[Check 1: MobileControls UI Hierarchy & Joypad Binding]")
	check(mobile_controls != null, "MobileControls CanvasLayer instantiated")
	check(mobile_controls.joystick != null, "Virtual Joystick joypad instantiated")
	check(mobile_controls.btn_attack != null, "Attack action button exists")
	check(mobile_controls.btn_dash != null, "Dash action button exists")
	check(mobile_controls.btn_guard != null, "Guard action button exists")
	check(mobile_controls.btn_jump == null, "Jump button successfully removed (integrated into joypad)")
	check(mobile_controls.btn_toggle != null, "Mobile toggle button exists")

	var joy = mobile_controls.joystick

	print("\n[Check 2: 8-Directional Joypad Input Discretization]")
	# 1. UP: Jump
	joy.simulate_drag(Vector2(0, -50))
	check(Input.is_action_pressed("jump"), "Joypad UP triggers 'jump'")
	check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "Joypad UP has neutral horizontal axis")

	# 2. UP-RIGHT: Jump + Move Right (Diagonal Jump Right)
	joy.simulate_drag(Vector2(45, -45))
	check(Input.is_action_pressed("jump"), "Joypad UP-RIGHT maintains 'jump'")
	check(Input.is_action_pressed("move_right"), "Joypad UP-RIGHT triggers 'move_right' concurrently")
	check(not Input.is_action_pressed("move_left"), "Joypad UP-RIGHT does not trigger 'move_left'")

	# 3. RIGHT: Move Right
	joy.simulate_drag(Vector2(50, 0))
	check(Input.is_action_pressed("move_right"), "Joypad RIGHT triggers 'move_right'")
	check(not Input.is_action_pressed("jump"), "Joypad RIGHT releases 'jump'")
	check(not Input.is_action_pressed("move_down"), "Joypad RIGHT does not trigger 'move_down'")

	# 4. DOWN-RIGHT: Move Down + Move Right (Diagonal Drop Right)
	joy.simulate_drag(Vector2(45, 45))
	check(Input.is_action_pressed("move_down"), "Joypad DOWN-RIGHT triggers 'move_down'")
	check(Input.is_action_pressed("move_right"), "Joypad DOWN-RIGHT maintains 'move_right'")

	# 5. DOWN: Move Down / Platform Drop
	joy.simulate_drag(Vector2(0, 50))
	check(Input.is_action_pressed("move_down"), "Joypad DOWN triggers 'move_down'")
	check(not Input.is_action_pressed("move_right"), "Joypad DOWN releases 'move_right'")

	# 6. DOWN-LEFT: Move Down + Move Left (Diagonal Drop Left)
	joy.simulate_drag(Vector2(-45, 45))
	check(Input.is_action_pressed("move_down"), "Joypad DOWN-LEFT maintains 'move_down'")
	check(Input.is_action_pressed("move_left"), "Joypad DOWN-LEFT triggers 'move_left'")

	# 7. LEFT: Move Left
	joy.simulate_drag(Vector2(-50, 0))
	check(Input.is_action_pressed("move_left"), "Joypad LEFT triggers 'move_left'")
	check(not Input.is_action_pressed("move_down"), "Joypad LEFT releases 'move_down'")

	# 8. UP-LEFT: Jump + Move Left (Diagonal Jump Left)
	joy.simulate_drag(Vector2(-45, -45))
	check(Input.is_action_pressed("jump"), "Joypad UP-LEFT triggers 'jump'")
	check(Input.is_action_pressed("move_left"), "Joypad UP-LEFT maintains 'move_left'")

	# 9. Deadzone check (< 16px)
	joy.simulate_drag(Vector2(6, -6))
	check(not Input.is_action_pressed("jump"), "Deadzone releases 'jump'")
	check(not Input.is_action_pressed("move_left"), "Deadzone releases 'move_left'")
	check(not Input.is_action_pressed("move_right"), "Deadzone releases 'move_right'")
	check(not Input.is_action_pressed("move_down"), "Deadzone releases 'move_down'")

	# 10. Joypad Release / Neutral
	joy.reset_joystick()
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_down") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "Joypad reset releases all joypad actions")

	print("\n[Check 3: Action Buttons (Attack, Dash, Guard) Emulation]")
	# Attack Button
	var btn_attack = mobile_controls.btn_attack
	var attack_down := InputEventScreenTouch.new()
	attack_down.index = 1
	attack_down.pressed = true
	btn_attack._gui_input(attack_down)
	check(Input.is_action_pressed("attack"), "Input action 'attack' active upon touch down")
	var attack_up := InputEventScreenTouch.new()
	attack_up.index = 1
	attack_up.pressed = false
	btn_attack._gui_input(attack_up)
	check(not Input.is_action_pressed("attack"), "Input action 'attack' released")

	# Dash Button
	var btn_dash = mobile_controls.btn_dash
	var dash_down := InputEventScreenTouch.new()
	dash_down.index = 1
	dash_down.pressed = true
	btn_dash._gui_input(dash_down)
	check(Input.is_action_pressed("dash"), "Input action 'dash' active upon touch down")
	var dash_up := InputEventScreenTouch.new()
	dash_up.index = 1
	dash_up.pressed = false
	btn_dash._gui_input(dash_up)
	check(not Input.is_action_pressed("dash"), "Input action 'dash' released")

	# Guard Button
	var btn_guard = mobile_controls.btn_guard
	var guard_down := InputEventScreenTouch.new()
	guard_down.index = 1
	guard_down.pressed = true
	btn_guard._gui_input(guard_down)
	check(Input.is_action_pressed("guard"), "Input action 'guard' active upon touch down")
	var guard_up := InputEventScreenTouch.new()
	guard_up.index = 1
	guard_up.pressed = false
	btn_guard._gui_input(guard_up)
	check(not Input.is_action_pressed("guard"), "Input action 'guard' released")

	print("\n[Check 4: Multi-Touch Simultaneous Input Handling]")
	# Left thumb holding joypad in Up-Right diagonal (Jump + Right)
	joy.simulate_drag(Vector2(45, -45))
	check(Input.is_action_pressed("move_right"), "Multi-touch: Joypad move_right active")
	check(Input.is_action_pressed("jump"), "Multi-touch: Joypad jump active")

	# Right thumb tapping attack
	btn_attack._gui_input(attack_down)
	check(Input.is_action_pressed("attack"), "Multi-touch: Attack button concurrently active with Joypad")
	check(Input.is_action_pressed("move_right"), "Multi-touch: move_right remains active during attack")
	check(Input.is_action_pressed("jump"), "Multi-touch: jump remains active during attack")

	# Release attack
	btn_attack._gui_input(attack_up)
	check(not Input.is_action_pressed("attack"), "Multi-touch: Attack cleanly released")
	check(Input.is_action_pressed("move_right"), "Multi-touch: move_right still held by Joypad")
	check(Input.is_action_pressed("jump"), "Multi-touch: jump still held by Joypad")

	# Release joypad
	joy.reset_joystick()
	check(not Input.is_action_pressed("move_right"), "Joypad release clears move_right")
	check(not Input.is_action_pressed("jump"), "Joypad release clears jump")

	print("\n[Check 5: Mobile Controls Toggle Visibility]")
	var initial_vis := mobile_controls.is_mobile_active
	mobile_controls._on_toggle_pressed()
	check(mobile_controls.is_mobile_active != initial_vis, "Toggle inverted mobile active state")
	mobile_controls._on_toggle_pressed()
	check(mobile_controls.is_mobile_active == initial_vis, "Toggle restored mobile active state")

	print("\n--- MOBILE CONTROLS SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: ALL MOBILE CONTROLS CHECKS PASSED (100%)\n")
		quit(0)
	else:
		push_error("TEST RESULT: MOBILE CONTROLS TEST FAILED")
		quit(1)

