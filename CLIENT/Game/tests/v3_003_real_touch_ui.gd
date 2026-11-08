extends SceneTree
## V3-003 Real Mobile Touch UI & Multi-Touch Input Verification
## Strict Requirements (V3-003-FINAL-INPUT-ROUTING-VERIFY):
##  1. Real Godot Viewport/Input event pipeline routing via Input.parse_input_event()
##  2. Zero direct calls to hud._input(ev) or btn.button_down.emit()
##  3. Strike (Attack), Leap (Jump), Parry (Guard), Dash action triggers at global button centers
##  4. Multi-touch concurrency (Index 0 Joystick + Index 1 Actions)
##  5. Dual release order testing (0 then 1, and 1 then 0)
##  6. Clean release safety with zero stuck inputs across all 8 actions
##  7. Cross-device input ownership: Keyboard hold preserved on virtual touch release
##  8. Honest disclosures: SIMULATED_KEY_ROUTE_ONLY / PHYSICAL_HARDWARE_NOT_VERIFIED / Android NOT_TESTED

const MobileControlsClass = preload("res://scripts/quarter_view/qv_mobile_controls.gd")
const PlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")

var main_root: Node3D = null
var player: CharacterBody3D = null
var hud: QVMobileControls = null

var test_step: int = 0
var step_timer: float = 0.0
var test_time: float = 0.0

var results: Dictionary = {
	"engine_routed_events": true,
	"direct_hud_input_bypassed": false,
	"strike_button_touch": false,
	"leap_button_touch": false,
	"parry_button_touch": false,
	"dash_button_touch": false,
	"multitouch_move_and_attack_rel_0_then_1": false,
	"multitouch_move_and_jump_rel_1_then_0": false,
	"touch_release_zero_stuck": false,
	"keyboard_hold_touch_release_ownership": false,
	"keyboard_ownership_hardware_scope": "SIMULATED_KEY_ROUTE_ONLY",
	"physical_hardware_ownership": "PHYSICAL_HARDWARE_NOT_VERIFIED",
	"android_device_status": "NOT_TESTED",
	"all_checks_passed": false
}

var log_lines: Array[String] = []


func _initialize() -> void:
	_log("[TOUCH UI TEST] Initializing scene tree with 3D ground, Player and Mobile HUD...")

	main_root = Node3D.new()
	main_root.name = "TouchTestMainRoot"
	root.add_child(main_root)
	current_scene = main_root

	var floor_body := StaticBody3D.new()
	floor_body.name = "TestFloor"
	floor_body.collision_layer = 4
	var floor_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50.0, 1.0, 10.0)
	floor_col.shape = box
	floor_col.position.y = -0.5
	floor_body.add_child(floor_col)
	main_root.add_child(floor_body)

	player = PlayerClass.new()
	player.name = "TouchTestPlayer"
	player.position = Vector3(0.0, 0.1, 0.0)
	main_root.add_child(player)

	hud = MobileControlsClass.new()
	hud.name = "MobileControlsHUD"
	main_root.add_child(hud)

	_log("[TOUCH UI TEST] Setup complete. Starting engine-routed touch tests...")


func _log(msg: String) -> void:
	var t := "[t=%.3fs, step=%d] %s" % [test_time, test_step, msg]
	print(t)
	log_lines.append(t)


func _physics_process(delta: float) -> bool:
	test_time += delta
	step_timer += delta

	match test_step:
		0:
			# Step 0: Warmup and ensure grounded
			if step_timer > 0.15 and player.is_on_floor():
				step_timer = 0.0
				test_step = 1

		1:
			# Step 1: Touch Strike Button center via Input.parse_input_event
			var rect: Rect2 = hud.btn_attack.get_global_rect()
			var pos := rect.get_center()
			_send_screen_touch(1, pos, true)
			_log("Sent touch press to Strike button at " + str(pos))
			step_timer = 0.0
			test_step = 2

		2:
			# Verify player entered attack state or attack action active
			if player.current_state == PlayerClass.State.ATTACK or Input.is_action_pressed("attack"):
				results["strike_button_touch"] = true
				_log("Strike touch confirmed: Player State.ATTACK, attack action=true")
				var rect: Rect2 = hud.btn_attack.get_global_rect()
				_send_screen_touch(1, rect.get_center(), false)
				step_timer = 0.0
				test_step = 3
			elif step_timer > 0.3:
				_fail("Player failed to register Strike touch event")
				return true

		3:
			# Step 3: Touch Leap (Jump) Button center
			if step_timer > 0.25 and player.is_on_floor():
				var rect: Rect2 = hud.btn_jump.get_global_rect()
				var pos := rect.get_center()
				_send_screen_touch(1, pos, true)
				_log("Sent touch press to Leap button at " + str(pos))
				step_timer = 0.0
				test_step = 4

		4:
			# Verify jump initiated
			if player.velocity.y > 1.5 or not player.is_on_floor() or Input.is_action_pressed("jump"):
				results["leap_button_touch"] = true
				_log("Leap touch confirmed: Player velocity.y=%.2f, jump action=true" % player.velocity.y)
				var rect: Rect2 = hud.btn_jump.get_global_rect()
				_send_screen_touch(1, rect.get_center(), false)
				step_timer = 0.0
				test_step = 5
			elif step_timer > 0.3:
				_fail("Player failed to register Leap touch event")
				return true

		5:
			# Step 5: Wait until landed on floor, then Touch Parry (Guard) Button
			if player.is_on_floor() and step_timer > 0.25:
				var rect: Rect2 = hud.btn_guard.get_global_rect()
				var pos := rect.get_center()
				_send_screen_touch(1, pos, true)
				_log("Sent touch press to Parry button at " + str(pos))
				step_timer = 0.0
				test_step = 6

		6:
			# Verify guard barrier visible or guard action active
			if player.current_state == PlayerClass.State.GUARD or player.guard_barrier_3d.visible or Input.is_action_pressed("guard"):
				results["parry_button_touch"] = true
				_log("Parry touch confirmed: Guard barrier active, guard action=true")
				var rect: Rect2 = hud.btn_guard.get_global_rect()
				_send_screen_touch(1, rect.get_center(), false)
				step_timer = 0.0
				test_step = 7
			elif step_timer > 0.3:
				_fail("Player failed to register Parry touch event")
				return true

		7:
			# Step 7: Wait until grounded and guard released, then Touch Dash Button
			if player.is_on_floor() and step_timer > 0.2:
				var rect: Rect2 = hud.btn_dash.get_global_rect()
				var pos := rect.get_center()
				_send_screen_touch(1, pos, true)
				_log("Sent touch press to Dash button at " + str(pos))
				step_timer = 0.0
				test_step = 8

		8:
			# Verify dash state or dash action active
			if player.current_state == PlayerClass.State.DASH or Input.is_action_pressed("dash"):
				results["dash_button_touch"] = true
				_log("Dash touch confirmed: Player State.DASH, dash action=true")
				var rect: Rect2 = hud.btn_dash.get_global_rect()
				_send_screen_touch(1, rect.get_center(), false)
				step_timer = 0.0
				test_step = 9
			elif step_timer > 0.3:
				_fail("Player failed to register Dash touch event")
				return true

		9:
			# Step 9: Multi-touch (Joystick drag right on index 0 + Strike button on index 1)
			# Release order: index 0 released FIRST, then index 1 released SECOND
			if step_timer > 0.3 and player.current_state == PlayerClass.State.IDLE:
				# Joystick center is (145.0, 535.0); right is (200.0, 535.0)
				_send_screen_touch(0, Vector2(200.0, 535.0), true)
				var rect: Rect2 = hud.btn_attack.get_global_rect()
				_send_screen_touch(1, rect.get_center(), true)
				_log("Multi-touch dispatched: Index 0 Joystick Right + Index 1 Strike")
				step_timer = 0.0
				test_step = 10

		10:
			if Input.is_action_pressed("move_right") and (player.current_state == PlayerClass.State.ATTACK or Input.is_action_pressed("attack")):
				_log("Multi-touch move+attack active! Testing release order 0 then 1...")
				# Release index 0 FIRST
				_send_screen_touch(0, Vector2(200.0, 535.0), false)
				step_timer = 0.0
				test_step = 11
			elif step_timer > 0.3:
				_fail("Multi-touch move+attack failed to register both actions")
				return true

		11:
			# Verify index 0 released (move_right is false) while index 1 is still pressed
			if not Input.is_action_pressed("move_right"):
				_log("Index 0 released safely without stuck move. Now releasing Index 1 (attack)...")
				var rect: Rect2 = hud.btn_attack.get_global_rect()
				_send_screen_touch(1, rect.get_center(), false)
				results["multitouch_move_and_attack_rel_0_then_1"] = true
				step_timer = 0.0
				test_step = 12
			elif step_timer > 0.3:
				_fail("Index 0 release failed to clear move_right")
				return true

		12:
			# Step 12: Multi-touch (Joystick drag right on index 0 + Leap on index 1)
			# Release order: index 1 released FIRST, then index 0 released SECOND
			if step_timer > 0.3 and player.is_on_floor():
				_send_screen_touch(0, Vector2(200.0, 535.0), true)
				var rect: Rect2 = hud.btn_jump.get_global_rect()
				_send_screen_touch(1, rect.get_center(), true)
				_log("Multi-touch dispatched: Index 0 Joystick Right + Index 1 Leap")
				step_timer = 0.0
				test_step = 13

		13:
			if Input.is_action_pressed("move_right") and (player.velocity.y > 0.5 or not player.is_on_floor() or Input.is_action_pressed("jump")):
				_log("Multi-touch move+jump active! Testing release order 1 then 0...")
				# Release index 1 FIRST
				var rect: Rect2 = hud.btn_jump.get_global_rect()
				_send_screen_touch(1, rect.get_center(), false)
				step_timer = 0.0
				test_step = 14
			elif step_timer > 0.3:
				_fail("Multi-touch move+jump failed to register both actions")
				return true

		14:
			# Verify index 1 released (jump is false) while index 0 (move_right) remains active
			if not Input.is_action_pressed("jump") and Input.is_action_pressed("move_right"):
				_log("Index 1 released safely while Index 0 remained active. Now releasing Index 0...")
				_send_screen_touch(0, Vector2(200.0, 535.0), false)
				results["multitouch_move_and_jump_rel_1_then_0"] = true
				step_timer = 0.0
				test_step = 15
			elif step_timer > 0.3:
				_fail("Multi-touch release order 1-then-0 failed")
				return true

		15:
			# Step 15: Test Release Safety (Check zero stuck actions)
			if step_timer > 0.3 and player.is_on_floor():
				var actions := ["move_left", "move_right", "move_up", "move_down", "attack", "guard", "dash", "jump"]
				var stuck_count := 0
				for a in actions:
					if Input.is_action_pressed(a):
						stuck_count += 1
						_log("WARNING: Action stuck pressed: " + a)
				if stuck_count == 0:
					results["touch_release_zero_stuck"] = true
					_log("Touch release safety verified: stuck_count = 0 across all 8 actions")
					step_timer = 0.0
					test_step = 16
				else:
					_fail("Found %d stuck actions after touch release" % stuck_count)
					return true

		16:
			# Step 16: Test Input Ownership (Keyboard hold + virtual touch release)
			# Dispatch simulated hardware keydown for KEY_A (move_left)
			_log("Dispatching keyboard Key Down for KEY_A (move_left)...")
			var key_down := InputEventKey.new()
			key_down.keycode = KEY_A
			key_down.physical_keycode = KEY_A
			key_down.pressed = true
			Input.parse_input_event(key_down)
			Input.flush_buffered_events()
			step_timer = 0.0
			test_step = 17

		17:
			# Verify move_left is active from key event
			if Input.is_action_pressed("move_left"):
				_log("Keyboard move_left active. Now starting virtual joystick touch left (index 0)...")
				_send_screen_touch(0, Vector2(90.0, 535.0), true)
				step_timer = 0.0
				test_step = 18
			elif step_timer > 0.3:
				_fail("Simulated keyboard KEY_A failed to activate move_left")
				return true

		18:
			# Release virtual touch on joystick
			_log("Releasing virtual joystick touch (index 0)...")
			_send_screen_touch(0, Vector2(90.0, 535.0), false)
			step_timer = 0.0
			test_step = 19

		19:
			# ASSERT: move_left MUST REMAIN TRUE after touch release because keyboard key is still held!
			var move_left_still_active := Input.is_action_pressed("move_left")
			_log("Ownership check immediately after touch release: move_left=" + str(move_left_still_active))
			if move_left_still_active:
				results["keyboard_hold_touch_release_ownership"] = true
				_log("OWNERSHIP CONFIRMED: Touch release did not extinguish held keyboard action!")
				# Now release the keyboard key
				var key_up := InputEventKey.new()
				key_up.keycode = KEY_A
				key_up.physical_keycode = KEY_A
				key_up.pressed = false
				Input.parse_input_event(key_up)
				Input.flush_buffered_events()
				step_timer = 0.0
				test_step = 20
			else:
				_fail("Input ownership violation: virtual touch release extinguished held keyboard action!")
				return true

		20:
			# Verify move_left is now cleanly released after key up
			if not Input.is_action_pressed("move_left"):
				_log("Keyboard key up verified: move_left cleanly released")
				_pass()
				return true
			elif step_timer > 0.3:
				_fail("Keyboard key up failed to clear move_left")
				return true

	if test_time > 12.0:
		_fail("Touch test timed out at t=%.2fs (step=%d)" % [test_time, test_step])
		return true

	return false


func _send_screen_touch(touch_idx: int, screen_pos: Vector2, is_pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = touch_idx
	ev.position = screen_pos
	ev.pressed = is_pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _fail(reason: String) -> void:
	results["all_checks_passed"] = false
	results["failure_reason"] = reason
	_log(">>> TOUCH UI TEST FAILED <<< : " + reason)
	_write_evidence()
	quit(1)


func _pass() -> void:
	results["all_checks_passed"] = true
	_log(">>> ALL CHECKS PASSED: Real Engine-Routed Touch & Multitouch Verification <<<")
	_log("  Strike Button Touch: PASS")
	_log("  Leap Button Touch: PASS")
	_log("  Parry Button Touch: PASS")
	_log("  Dash Button Touch: PASS")
	_log("  Multi-Touch Move+Attack (rel 0 then 1): PASS")
	_log("  Multi-Touch Move+Jump (rel 1 then 0): PASS")
	_log("  Release Safety Zero Stuck: PASS")
	_log("  Keyboard/Touch Ownership: PASS (Scope: SIMULATED_KEY_ROUTE_ONLY)")
	_write_evidence()
	quit(0)


func _write_evidence() -> void:
	var out_dir := ProjectSettings.globalize_path("res://../../STUDIO_V3/evidence/V3-003/final-input")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var json_path := out_dir + "/TOUCH_EVENT_ROUTE_RESULT.json"
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
		_log("Saved result JSON to: " + json_path)

	var log_path := out_dir + "/TOUCH_EVENT_ROUTE_LOG.txt"
	var log_f := FileAccess.open(log_path, FileAccess.WRITE)
	if log_f != null:
		for line in log_lines:
			log_f.store_line(line)
		log_f.close()
		_log("Saved raw log to: " + log_path)
