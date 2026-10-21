extends SceneTree

var checks_passed: int = 0
var checks_failed: int = 0

func _initialize() -> void:
	var watchdog := create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[TIMEOUT] Watchdog timer expired in aerial_attack_natural_fall_smoke.gd")
		quit(1)
	)
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		checks_passed += 1
	else:
		printerr("  [FAIL] %s" % message)
		checks_failed += 1

func _advance_frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	print("\n=======================================================")
	print(">>> RUNNING: aerial_attack_natural_fall_smoke.gd <<<")
	print("=======================================================\n")

	var stage_scene := preload("res://scenes/stage/FirstStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage
	await _advance_frames(5)

	var player = stage.player
	check(player != null, "Player node active in stage")

	# -------------------------------------------------------------
	# Test 1: Air Attack triggered while falling maintains continuous downward acceleration
	# -------------------------------------------------------------
	print("\n--- Test 1: Mid-Air Attack Downward Fall Continuity (No Hover/Lift) ---")
	player.position = Vector2(300.0, 300.0) # High up in the air
	player.velocity = Vector2(0.0, 200.0)   # Already falling downward at 200 px/s
	await _advance_frames(2)

	var pre_attack_vy: float = player.velocity.y
	check(pre_attack_vy > 180.0, "Player is falling downward prior to air attack (vel.y = %.1f)" % pre_attack_vy)

	# Trigger air attack
	player._start_air_attack()
	check(player.is_air_attacking, "Air attack is active")
	check(player.velocity.y >= pre_attack_vy, "Downwards velocity NOT reset to 0 upon air attack (vel.y = %.1f >= %.1f)" % [player.velocity.y, pre_attack_vy])
	check(player._air_hang_timer == 0.0, "Air hang timer is 0.0 (no gravity suspension active)")

	# Advance 5 frames while air attacking
	var initial_y: float = player.position.y
	var vy_before_step: float = player.velocity.y
	await _advance_frames(5)

	# Verify gravity was actively applied each frame
	check(player.velocity.y > vy_before_step, "Gravity continuously accelerates downward during air attack (vel.y: %.1f -> %.1f)" % [vy_before_step, player.velocity.y])
	check(player.position.y > initial_y + 15.0, "Player physically drops significantly downward without gliding/hovering (dy = %.1f)" % (player.position.y - initial_y))

	# -------------------------------------------------------------
	# Test 2: Jump + Forward + Attack trajectory comparison (No Gliding / Horizontal Float)
	# -------------------------------------------------------------
	print("\n--- Test 2: Jump + Forward + Air Attack Ballistic Trajectory ---")
	player.position = Vector2(400.0, 580.0)
	player.velocity = Vector2.ZERO
	# Wait until settled on floor
	while not player.is_on_floor():
		await physics_frame
	await _advance_frames(3)

	# Jump forward
	Input.action_press("move_right")
	Input.action_press("jump")
	await _advance_frames(1)
	Input.action_release("jump")
	await _advance_frames(1)
	check(player.velocity.y < -400.0, "Player initiated upward jump (vel.y = %.1f)" % player.velocity.y)

	# Wait until apex of jump (reaching downward falling phase)
	var peak_reached := false
	for f in range(30):
		await physics_frame
		if player.velocity.y >= 0.0:
			peak_reached = true
			break
	check(peak_reached, "Player reached apex of jump and began falling")

	# Attack in mid-air while descending
	var vy_at_apex: float = player.velocity.y
	player._start_air_attack()
	check(player.is_air_attacking, "Air attack triggered at descent")
	check(player.velocity.y >= vy_at_apex, "Descent velocity NOT paused upon attack trigger (vel.y = %.1f)" % player.velocity.y)

	# Advance 10 frames during descending slash
	var fall_y_start: float = player.position.y
	await _advance_frames(10)
	var fall_dy: float = player.position.y - fall_y_start
	check(fall_dy > 20.0, "Player dropped steep parabolic distance during air slash (dy = %.1f > 20.0)" % fall_dy)
	check(player.velocity.y > 150.0, "Downward velocity maintained and accelerating (vel.y = %.1f)" % player.velocity.y)

	Input.action_release("move_right")

	# -------------------------------------------------------------
	# Test 3: Landing terminates air attack cleanly
	# -------------------------------------------------------------
	print("\n--- Test 3: Clean Landing Termination ---")
	var land_wait := 50
	while land_wait > 0 and not player.is_on_floor():
		await physics_frame
		land_wait -= 1

	check(player.is_on_floor(), "Player safely landed on ground floor")
	check(not player.is_air_attacking, "Air attack state terminated upon floor landing")

	# -------------------------------------------------------------
	# Results Summary
	# -------------------------------------------------------------
	print("\n=======================================================")
	print("RESULTS: %d Checks, %d Failures" % [checks_passed, checks_failed])
	print("=======================================================")

	stage.queue_free()
	if checks_failed == 0:
		print("\n>>> ALL AERIAL ATTACK NATURAL FALL CHECKS PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> CHECKS FAILED: %d failures <<<\n" % checks_failed)
		quit(1)
