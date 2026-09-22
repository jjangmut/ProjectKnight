extends SceneTree
## Automated QA Smoke Test for Combat Deepening (Combo, Counter Advantage, Down Thrust, Audio).

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
	print("--- START COMBAT DEEPENING SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	# Static floor for is_on_floor()
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

	# Wait for physics settlement and ready
	for i in range(15):
		await physics_frame

	check(player.is_on_floor(), "Player landed on test floor")

	# 1. Combo Progression Verification
	print("[Check 1: 3-Hit Combo Progression]")
	player._start_attack()
	check(player.combo_step == 1 and player.current_attack_damage == 1, "Combo Step 1 (Thrust, dmg=1)")

	player._end_attack()
	player._cooldown_time_remaining = 0.0
	player._start_attack()
	check(player.combo_step == 2 and player.current_attack_damage == 1, "Combo Step 2 (Slash, dmg=1)")

	player._end_attack()
	player._cooldown_time_remaining = 0.0
	player._start_attack()
	check(player.combo_step == 3 and player.current_attack_damage == 2, "Combo Step 3 (Smash, dmg=2)")

	# Reset combo after window expiration
	player._end_attack()
	player._cooldown_time_remaining = 0.0
	player._combo_window_remaining = 0.0
	player._start_attack()
	check(player.combo_step == 1, "Combo resets to Step 1 after window timeout")
	player._end_attack()

	# 2. Counter Advantage Verification
	print("[Check 2: Counter Advantage]")
	player._cooldown_time_remaining = 0.0
	player._guard_cooldown_remaining = 0.0
	player._guard_recovery_remaining = 0.0
	Input.action_press("guard")
	player._start_guard()
	check(player.is_guarding, "Ground guard active")

	# Block frontal attack
	var blocked: bool = player.receive_attack(player.global_position + Vector2(60, 0), true)
	check(blocked and player._counter_window_remaining > 0.0, "Frontal attack blocked & Counter Window opened")

	# Execute Counter Attack
	player._start_counter_attack()
	check(player.is_counter_attacking and player.current_attack_damage == 2 and not player.is_guarding, "Counter Attack executed (dmg=2, guard dismissed)")
	player._end_attack()

	# 3. Down Thrust Verification
	print("[Check 3: Down Thrust & Pogo Rebound]")
	# Position in air and run physics to clear is_on_floor
	player.position.y = 60
	player.velocity = Vector2.ZERO
	for i in range(3):
		await physics_frame
	player._start_down_thrust()
	check(player.is_down_thrusting and player.is_attacking, "Down thrust active in air")

	# Simulate dummy enemy contact
	var dummy_area := Area2D.new()
	var dummy_enemy := CharacterBody2D.new()
	dummy_enemy.name = "DummyTarget"
	dummy_enemy.add_child(dummy_area)
	world.add_child(dummy_enemy)
	dummy_enemy.position = player.position + Vector2(0, 32)

	player._on_attack_area_entered(dummy_area)
	check(player.velocity.y < 0.0 and not player.is_down_thrusting, "Pogo jump rebound triggered (velocity.y=%.1f)" % player.velocity.y)

	dummy_enemy.queue_free()
	world.queue_free()

	print("--- COMBAT DEEPENING SMOKE SUMMARY: %d checks, %d failures ---" % [checks, failures])
	if failures == 0:
		print("COMBAT_DEEPENING_SMOKE_PASS")
		quit(0)
	else:
		push_error("COMBAT_DEEPENING_SMOKE_FAIL")
		quit(1)
