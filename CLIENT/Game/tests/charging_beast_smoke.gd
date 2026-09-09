extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var p = load("res://scenes/player/Player.tscn").instantiate()
	world.add_child(p)
	p.position = Vector2(300, 0)
	p.set_physics_process(false)
	var beast = load("res://scenes/enemy/ChargingBeast.tscn").instantiate()
	world.add_child(beast)
	beast.set_physics_process(false)
	check(beast.current_hp == 3 and beast.is_in_group("enemy"), "HP3 and enemy group contract")
	check(beast.get_node("HurtArea").collision_layer == 2 and beast.attack_area.collision_mask == 4, "Existing hurt/attack collision layer contract")
	check(beast.get_node("CollisionShape2D").shape.size == Vector2(70,50), "Low beast body collider")
	check(beast.attack_collision.shape.size == Vector2(44,40), "Nose hitbox is short rather than a full charge-range attack")
	check(beast.attack_windup == 0.65 and beast.attack_active == 0.62 and beast.attack_cooldown == 1.1 and beast.charge_speed == 420, "Approved readable charge tuning")
	beast._begin_attack(200)
	check(beast.state == 2 and beast.attack_phase == 0 and beast.is_attacking and not beast.is_attack_active, "Windup state matches presentation contract")
	check(beast.attack_area.position == Vector2(45,5), "Right nose hitbox")
	beast._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 3, "Windup cannot damage")
	p.position.x = -200
	beast._update_attack(0.64)
	check(not beast.is_attack_active and beast.velocity.x == 0, "Windup holds for full telegraph")
	beast._update_attack(0.02)
	await process_frame
	check(beast.is_attack_active and beast.attack_phase == 1 and beast.velocity.x == 420 and beast._attack_direction == 1, "Charge commits to original direction despite player crossing")
	check(not beast.attack_collision.disabled, "Active phase enables hitbox")
	beast._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 2, "Active charge deals one hit")
	p._hit_invulnerable_until_usec = 0
	beast._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 2, "Re-entry cannot hit twice even after player invulnerability expires")
	beast._update_attack(0.63)
	await process_frame
	check(beast.attack_phase == 2 and not beast.is_attack_active and beast.velocity.x == 0 and beast.attack_collision.disabled, "Charge ends in stationary safe recovery")
	beast._update_attack(1.09)
	check(beast.state == 2, "Recovery preserves minimum punish window")
	beast._update_attack(0.02)
	check(beast.state == 1 and not beast.is_attacking, "Recovery returns to chase")
	beast._begin_attack(-200)
	check(beast.attack_area.position.x == -45, "Left nose hitbox mirrors")
	beast._update_attack(0.66)
	p._hit_invulnerable_until_usec = Time.get_ticks_usec() + 500000
	beast._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 2, "Player-owned post-hit immunity is preserved")
	beast._begin_recovery()
	beast._begin_attack(-200)
	beast._update_attack(0.66)
	p._hit_invulnerable_until_usec = 0
	# Synthetic guarded-state fixture: actual grounded guard is tested independently.
	p.is_guarding = true
	p._guard_direction = -1
	beast._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 1 and not p.is_guarding, "Heavy charge damages and interrupts guard")
	p._guard_recovery_remaining = 0.0
	# Actual area broadphase: a nose overlap hits; distant or high jump positions do not.
	p.current_hp = 3
	p.position = Vector2(100, 0)
	p._hit_invulnerable_until_usec = 0
	beast._begin_attack(200)
	beast._update_attack(0.66)
	await physics_frame
	await physics_frame
	check(p.current_hp == 3, "Player beyond nose hitbox is not hit by charge trigger range")
	p.position = Vector2(60, -100)
	await physics_frame
	await physics_frame
	check(p.current_hp == 3, "Jump height clears the low nose hitbox")
	p.position = Vector2(60, 0)
	await physics_frame
	await physics_frame
	check(p.current_hp == 2, "Real HurtArea overlap invokes charge damage")
	p.position = Vector2(120,0)
	await physics_frame
	await physics_frame
	p._hit_invulnerable_until_usec = 0
	p.position = Vector2(60,0)
	await physics_frame
	await physics_frame
	check(p.current_hp == 2, "Real exit and re-entry still allow only one charge hit")
	p.position = Vector2(-200,0)
	# Real physics wall contact stops the charge and opens recovery.
	var wall := StaticBody2D.new()
	wall.position = Vector2(100, 0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,400)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	beast.position = Vector2.ZERO
	beast.gravity = 0
	beast._begin_attack(200)
	beast._update_attack(0.66)
	beast.set_physics_process(true)
	for tick in range(20):
		await physics_frame
		if beast.attack_phase == 2:
			break
	beast.set_physics_process(false)
	check(beast.position.x <= 55.1 and beast.attack_phase == 2 and not beast.is_attack_active, "Real wall collision stops body and cancels active charge")
	check(beast._phase_time_remaining > 1.0, "Wall interruption grants fresh recovery window")
	beast.receive_hit()
	beast.receive_hit()
	check(beast.current_hp == 1, "Existing receive_hit damage interface")
	beast.receive_hit()
	check(beast.current_hp == 0 and beast.is_queued_for_deletion() and not beast.is_attack_active, "Third hit kills and disables attack")
	world.queue_free()
	await process_frame
	for escape in ["jump", "retreat"]:
		for reach in [false, true]:
			await _counterattack_trial(escape, reach)
	for reach in [false, true]:
		await _trait_edge_trial(reach)
	print("CHARGING_BEAST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _counterattack_trial(escape: String, reach: bool) -> void:
	# Real floor, controller movement/jump and Input attacks; no damage callback fixtures.
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body := StaticBody2D.new()
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(3000, 80)
	floor_collision.shape = floor_shape
	floor_body.position = Vector2(500, 660)
	floor_body.add_child(floor_collision)
	arena.add_child(floor_body)
	var p = load("res://scenes/player/Player.tscn").instantiate()
	p.position = Vector2(140,592)
	arena.add_child(p)
	if reach:
		p.attack_range = 90.0
		p.attack_cooldown = 0.40
		p._update_attack_geometry()
	var beast = load("res://scenes/enemy/ChargingBeast.tscn").instantiate()
	beast.position = Vector2(0,590)
	arena.add_child(beast)
	beast.set_physics_process(false)
	for tick in range(5):
		await physics_frame
	check(p.is_on_floor(), "Counterattack trial starts grounded")
	check(p.attack_collision.shape.size.x == (90.0 if reach else 72.0) and is_equal_approx(p.attack_cooldown, 0.40 if reach else 0.32), "Actual attack geometry/cooldown matches selected trait")
	beast._begin_attack(140)
	beast.set_physics_process(true)
	var attack_requested := false
	var landed_during_recovery := false
	var avoided := false
	var jump_seen := false
	var max_x: float = p.position.x
	for tick in range(150):
		if tick == 30:
			Input.action_press("jump" if escape == "jump" else "move_right")
		if tick == 32:
			Input.action_release("jump")
		if tick == 72:
			Input.action_release("move_right")
		await physics_frame
		jump_seen = jump_seen or not p.is_on_floor()
		max_x = maxf(max_x, p.position.x)
		if beast.attack_phase == 2 and beast.state == 2:
			avoided = p.current_hp == 3
			if not attack_requested and p.is_on_floor():
				# Face the stopped beast through the existing movement input.
				var action := "move_right" if beast.position.x > p.position.x else "move_left"
				Input.action_press(action)
				await physics_frame
				Input.action_release(action)
				Input.action_press("attack")
				attack_requested = true
		if beast.current_hp < 3:
			landed_during_recovery = beast.attack_phase == 2 and beast.state == 2
			break
	Input.action_release("attack")
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	var label := "%s/%s" % [escape, "reach" if reach else "basic"]
	check(jump_seen if escape == "jump" else max_x > 300.0, "Controller executes actual escape: " + label)
	check(avoided and p.current_hp == 3, "Escape avoids charge without immunity fixture: " + label)
	check(attack_requested and p.attack_count == 1 and landed_during_recovery and beast.current_hp == 2, "Input attack lands once inside recovery window: " + label)
	arena.queue_free()
	await process_frame

func _trait_edge_trial(reach: bool) -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var p = load("res://scenes/player/Player.tscn").instantiate()
	arena.add_child(p)
	p.gravity = 0.0
	p.attack_range = 90.0 if reach else 72.0
	p.attack_cooldown = 0.40 if reach else 0.32
	p._update_attack_geometry()
	var beast = load("res://scenes/enemy/ChargingBeast.tscn").instantiate()
	beast.position = Vector2(140,0)
	arena.add_child(beast)
	beast.set_physics_process(false)
	await physics_frame
	await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	for tick in range(19):
		await physics_frame
	check(beast.current_hp == (2 if reach else 3), "140px target: long blade reaches where basic misses")
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	check(p.attack_count == (1 if reach else 2), "Second input around 0.35s: basic ready, long blade still cooling down")
	arena.queue_free()
	await process_frame
