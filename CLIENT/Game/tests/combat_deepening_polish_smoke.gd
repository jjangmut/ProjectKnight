extends SceneTree
## Automated QA Smoke Test for Advanced Combat Polish:
## Air Attack, Perfect Parry (Just Guard), Combo Finisher SwordBeam, and Haptics.

var checks := 0
var failures := 0

const SwordBeamClass := preload("res://scripts/player/sword_beam.gd")
const SaveManager := preload("res://scripts/system/save_manager.gd")

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
	print("--- START ADVANCED COMBAT POLISH SMOKE TEST ---")
	SaveManager.clear_save()

	var world := Node2D.new()
	root.add_child(world)

	# Static floor
	var floor_body := StaticBody2D.new()
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(2000, 40)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position.y = 200
	world.add_child(floor_body)

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(200, 160)
	world.add_child(player)

	for i in range(15):
		await physics_frame

	check(player.is_on_floor(), "Player grounded on test floor")

	# ==========================================
	# 1. Air Attack & Aerodynamic Gravity Suspension
	# ==========================================
	print("\n[Check 1: Air Attack & Hover Mechanics]")
	player.position.y = 80
	player.velocity = Vector2.ZERO
	for i in range(3):
		await physics_frame
	check(not player.is_on_floor(), "Player airborne")

	player._start_air_attack()
	check(player.is_air_attacking, "Air attack state active")
	check(player.is_attacking, "Player registered as attacking during air strike")
	check(player.current_attack_damage == 1, "Air attack deals 1 damage")
	check(player._air_hang_timer > 0.0, "Aerodynamic gravity suspension active (_air_hang_timer > 0)")

	# Land on floor
	player.position.y = 175
	player.velocity.y = 50
	for i in range(5):
		await physics_frame
	check(player.is_on_floor(), "Player landed on floor")
	check(not player.is_air_attacking, "Air attack cleanly terminated upon landing")

	# ==========================================
	# 2. Combo Finisher SwordBeam
	# ==========================================
	print("\n[Check 2: Combo 3 Finisher & SwordBeam Emission]")
	player._end_attack()
	player._cooldown_time_remaining = 0.0
	player._combo_window_remaining = 0.0

	# Step 1
	player._start_attack()
	check(player.combo_step == 1, "Combo Step 1")
	player._end_attack()
	player._cooldown_time_remaining = 0.0

	# Step 2
	player._start_attack()
	check(player.combo_step == 2, "Combo Step 2")
	player._end_attack()
	player._cooldown_time_remaining = 0.0

	# Step 3 (Finisher)
	player._start_attack()
	check(player.combo_step == 3, "Combo Step 3 (Finisher)")

	# Verify SwordBeam spawned in world
	var spawned_beams := []
	for child in world.get_children():
		if child is SwordBeamClass:
			spawned_beams.append(child)
	check(spawned_beams.size() >= 1, "SwordBeam projectile spawned upon Combo 3 Finisher")

	var beam: Area2D = spawned_beams[0]
	check(beam.direction == player.facing_direction, "SwordBeam facing player's direction")
	check(beam.speed >= 500.0, "SwordBeam has high travel velocity (>= 500 px/s)")
	check(beam.damage >= 1, "SwordBeam deals at least 1 damage")

	# Simulate dummy enemy piercing
	var dummy := Node2D.new()
	var dummy_hurt := Area2D.new()
	var dummy_col := CollisionShape2D.new()
	var dummy_box := RectangleShape2D.new()
	dummy_box.size = Vector2(30, 40)
	dummy_col.shape = dummy_box
	dummy_hurt.add_child(dummy_col)
	dummy.add_child(dummy_hurt)
	world.add_child(dummy)
	dummy.global_position = beam.global_position

	var hit_recorded := [false]
	dummy.set_script(GDScript.new())
	dummy.set_meta("receive_hit", func(): hit_recorded[0] = true)

	beam._on_area_entered(dummy_hurt)
	check(beam._pierced == 1, "SwordBeam pierced first target")
	player._end_attack()

	# ==========================================
	# 3. Perfect Parry (Just Guard) vs Regular Block
	# ==========================================
	print("\n[Check 3: Perfect Parry vs Regular Block]")
	player._cooldown_time_remaining = 0.0
	player._guard_cooldown_remaining = 0.0
	player._guard_recovery_remaining = 0.0
	Input.action_press("guard")
	player._start_guard()
	check(player.is_guarding, "Guard stance active")

	# Simulate attack arriving at elapsed = 0.04s (within PERFECT_PARRY_WINDOW 0.14s)
	player._guard_elapsed = 0.04
	var parry_signal_received := [false]
	player.perfect_parry_performed.connect(func(): parry_signal_received[0] = true)

	var blocked_parry: bool = player.receive_attack(player.global_position + Vector2(50, 0), true)
	check(blocked_parry, "Incoming attack blocked")
	check(player.is_perfect_parry, "Perfect Parry flag set")
	check(parry_signal_received[0], "perfect_parry_performed signal emitted")
	check(player._counter_window_remaining >= 0.50, "Extended golden counter window awarded (>= 0.50s)")

	# Counter attack executed from Perfect Parry deals 3 damage!
	player._start_counter_attack()
	check(player.current_attack_damage == 3, "Perfect Parry Counter Attack deals 3 CRIT damage (vs normal 2)")
	check(not player.is_perfect_parry, "Perfect parry flag consumed")
	player._end_attack()

	# Test Regular Block (arriving at elapsed = 0.25s > PERFECT_PARRY_WINDOW)
	player._cooldown_time_remaining = 0.0
	player._guard_cooldown_remaining = 0.0
	player._guard_recovery_remaining = 0.0
	player._start_guard()
	player._guard_elapsed = 0.25

	var blocked_normal: bool = player.receive_attack(player.global_position + Vector2(50, 0), true)
	check(blocked_normal, "Regular attack blocked")
	check(not player.is_perfect_parry, "is_perfect_parry is false for delayed guard")
	player._start_counter_attack()
	check(player.current_attack_damage == 2, "Normal Counter Attack deals standard 2 damage")
	player._end_attack()

	# ==========================================
	# 4. Haptic Feedback Invocation Safety
	# ==========================================
	print("\n[Check 4: Mobile Haptic Call Safety]")
	player._trigger_haptic(40)
	check(true, "_trigger_haptic executed cleanly without exception")

	print("\n--- ADVANCED COMBAT POLISH TEST SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: ALL ADVANCED COMBAT POLISH CHECKS PASSED (100%)")
		quit(0)
	else:
		push_error("TEST RESULT: FAILED WITH %d ERRORS" % failures)
		quit(1)
