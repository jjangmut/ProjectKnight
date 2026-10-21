extends SceneTree

var checks_passed: int = 0
var checks_failed: int = 0

func _initialize() -> void:
	var watchdog := create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[TIMEOUT] Watchdog timer expired in leadership_audit_and_polish_smoke.gd")
		quit(1)
	)
	_run_tests.call_deferred()

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

func _run_tests() -> void:
	print("\n=======================================================")
	print(">>> RUNNING: leadership_audit_and_polish_smoke.gd <<<")
	print("=======================================================\n")

	var stage_scene := preload("res://scenes/stage/FirstStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage
	await _advance_frames(5)

	var player = stage.player
	var controls = stage.mobile_controls
	check(player != null, "Player node active in stage")
	check(controls != null, "MobileControls CanvasLayer active in stage")

	# -------------------------------------------------------------
	# 1. ART & UI AUDIT: Dedicated Jump Button & HUD Integration
	# -------------------------------------------------------------
	print("\n--- 1. Art & UI Lead Audit: Action Buttons & Mobile HUD ---")
	check(controls.btn_jump != null, "Jump button exists in MobileControls")
	check(controls.btn_jump.button_texture != null, "Jump button has custom icon texture")
	check(controls.btn_jump.button_texture.resource_path.ends_with("btn_jump.png"), 
		"Jump button uses dedicated 'btn_jump.png' (NOT old 'btn_dash.png')")
	check(controls.btn_jump.label_text == "점프", "Jump button label is clean Korean '점프' (no emojis)")
	check(controls.btn_attack.label_text == "공격", "Attack button label is clean Korean '공격'")
	check(controls.btn_guard.label_text == "방어", "Guard button label is clean Korean '방어'")

	# Check custom StyleBoxFlat on mobile toggle
	check(controls.btn_toggle != null, "Mobile toggle button exists")
	var normal_sb = controls.btn_toggle.get_theme_stylebox("normal")
	check(normal_sb is StyleBoxFlat, "Mobile toggle uses custom StyleBoxFlat (translucent gothic glass)")
	if normal_sb is StyleBoxFlat:
		check((normal_sb as StyleBoxFlat).corner_radius_top_left == 8, "Toggle button has 8px rounded corners")

	# -------------------------------------------------------------
	# 2. COMBAT LEAD AUDIT: Air-to-Ground Combo Fluidity
	# -------------------------------------------------------------
	print("\n--- 2. Combat Lead Audit: Air-to-Ground Combo Chaining ---")
	player.position = Vector2(300.0, 560.0) # Slightly above floor (floor is y=592)
	player.velocity = Vector2(0.0, 150.0)   # Descending toward floor
	await _advance_frames(2)

	# Trigger air attack right before landing
	player._start_air_attack()
	check(player.is_air_attacking, "Air attack triggered before touchdown")

	# Buffer attack right before landing
	player._attack_buffer_remaining = 0.14

	# Advance until landed on floor
	while not player.is_on_floor():
		await physics_frame

	check(player.is_on_floor(), "Player landed on ground floor")
	check(not player.is_air_attacking, "Air attack cleanly terminated upon landing")
	check(player.is_attacking or player._cooldown_time_remaining == 0.0, 
		"Landing triggered ground attack combo instantly (is_attacking=%s, combo_step=%d)" % [player.is_attacking, player.combo_step])
	await _advance_frames(2)
	check(player.is_attacking, "Ground combo attack active and swinging without landing input lag")

	# Wait for ground attack to finish
	while player.is_attacking:
		await physics_frame
	await _advance_frames(5)

	# -------------------------------------------------------------
	# 3. GAMEPLAY QUALITY AUDIT: Knockback Landing Instant Recovery
	# -------------------------------------------------------------
	print("\n--- 3. Gameplay Lead Audit: Knockback Instant Zero-Delay Recovery ---")
	player.position = Vector2(400.0, 580.0)
	player.velocity = Vector2.ZERO
	while not player.is_on_floor():
		await physics_frame
	await _advance_frames(3)

	# Trigger contact knockback away from monster at X=480
	player.receive_contact_damage(Vector2(480.0, 580.0))
	check(player.is_contact_knockback_airborne, "Contact knockback airborne state active")
	check(player.velocity.x == -320.0, "Knocked backward horizontally: vel.x = -320.0")

	# User holds D-Pad right during mid-air knockback
	Input.action_press("move_right")
	# Advance frames while airborne: input must be locked
	await _advance_frames(5)
	check(player.velocity.x < 0.0, "Mid-air backward momentum preserved (vel.x = %.1f < 0)" % player.velocity.x)

	# Wait until landing frame
	while not player.is_on_floor():
		await physics_frame

	# On landing frame: is_contact_knockback_airborne clears and move_direction immediately becomes +1.0
	check(not player.is_contact_knockback_airborne, "Knockback airborne lock cleared upon landing")
	check(player.move_speed > 200.0, "Move speed configured")
	await _advance_frames(2)
	check(player.velocity.x > 0.0, "Player immediately resumes forward running on landing (vel.x = %.1f > 0)" % player.velocity.x)
	Input.action_release("move_right")

	# -------------------------------------------------------------
	# 4. LEVEL & ENCOUNTER LEAD AUDIT: Upper Perch & Boss Alignment
	# -------------------------------------------------------------
	print("\n--- 4. Level & Encounter Lead Audit: Stage Integrity ---")
	# Check boss shockwave geometry
	var shockwave_class = preload("res://scripts/enemy/boss_shockwave.gd")
	var sw = shockwave_class.new()
	sw.direction = 1.0
	stage.add_child(sw)
	await _advance_frames(2)
	check(sw.direction == 1.0, "Boss shockwave direction set to +1.0 (Right)")
	check(sw.scale.x == 1.0, "Boss shockwave scale is +1.0 (points right '>')")
	sw.queue_free()

	# -------------------------------------------------------------
	# Results Summary
	# -------------------------------------------------------------
	print("\n=======================================================")
	print("RESULTS: %d Checks, %d Failures" % [checks_passed, checks_failed])
	print("=======================================================")

	stage.queue_free()
	if checks_failed == 0:
		print("\n>>> ALL LEADERSHIP AUDIT & POLISH CHECKS PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> CHECKS FAILED: %d failures <<<\n" % checks_failed)
		quit(1)
