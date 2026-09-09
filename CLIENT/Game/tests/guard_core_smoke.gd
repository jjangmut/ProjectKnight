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
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 40)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = 120
	world.add_child(floor_body)
	var p = load("res://scenes/player/Player.tscn").instantiate()
	world.add_child(p)
	for index in range(35):
		await physics_frame
	check(p.is_on_floor(), "Real physics ground contact")
	p.set_physics_process(false)
	check(InputMap.has_action("guard") and not InputMap.has_action("dodge"), "Guard replaces dodge input")
	Input.action_press("guard")
	p._start_guard()
	check(p.is_guarding and p.guard_count == 1 and p._guard_elapsed == 0.0, "Ground guard starts with zero elapsed time")
	p._start_attack()
	check(not p.is_attacking, "Guard cannot attack")
	check(p.receive_attack(p.global_position + Vector2(50,0)), "Frontal ordinary attack blocks")
	check(p.current_hp == 3 and p.hit_count == 0 and p.guard_block_count == 1, "Block consumes no HP and records feedback")
	p._update_guard_state(0.81)
	check(p.is_guarding and p._guard_elapsed >= 0.8, "Held guard continues beyond old maximum")
	p._update_guard_state(0.36)
	check(p.is_guarding and p.guard_count == 1, "Holding maintains same guard without cycling")
	Input.action_release("guard")
	p._update_guard_state(0.01)
	check(not p.is_guarding and p._guard_recovery_remaining == 0.12 and p._guard_cooldown_remaining == 0.2, "Release applies approved recovery and cooldown")
	p._update_guard_state(0.21)
	check(p._can_start_guard(), "Guard becomes legal after cooldown without release latch")
	Input.action_press("guard")
	p._start_guard()
	check(not p.receive_attack(p.global_position - Vector2(50,0)), "Rear ordinary attack cannot block")
	check(p.current_hp == 2 and not p.is_guarding, "Rear damage interrupts guard")
	p.receive_attack(p.global_position, false)
	check(p.current_hp == 2, "Post-hit 0.5-second immunity is preserved")
	p._update_guard_state(0.4)
	Input.action_release("guard")
	p._update_guard_state(0.01)
	Input.action_press("guard")
	p._start_guard()
	p._hit_invulnerable_until_usec = 0
	check(not p.receive_attack(p.global_position + Vector2(50,0), false) and p.current_hp == 1, "Frontal unblockable attack damages guard")
	p._update_guard_state(0.4)
	Input.action_release("guard")
	p._update_guard_state(0.01)
	p._cooldown_time_remaining = 0.1
	check(not p._can_start_guard(), "Guard cannot cancel attack cooldown")
	p._cooldown_time_remaining = 0
	Input.action_press("guard")
	p._start_guard()
	Input.action_release("guard")
	p._update_guard_state(0.01)
	check(not p.is_guarding and p._guard_recovery_remaining > 0, "Release immediately ends defense with recovery")
	p._start_attack()
	check(not p.is_attacking, "Recovery cannot attack")
	p._update_guard_state(0.13)
	p._start_attack()
	check(p.is_attacking, "Attack can counter after 0.12-second recovery")
	p._end_attack()
	p._cooldown_time_remaining = 0
	p._update_guard_state(0.2)
	Input.action_press("guard")
	p._start_guard()
	var projectile = load("res://scenes/projectile/EnemyProjectile.tscn").instantiate()
	world.add_child(projectile)
	projectile.configure(-1)
	projectile.global_position = p.global_position - Vector2(10,0)
	projectile._on_area_entered(p.get_node("HurtArea"))
	check(projectile.is_queued_for_deletion() and p.current_hp == 1, "Incoming frontal projectile blocks even after center overshoot and is consumed")
	var count: int = p.guard_block_count
	projectile._on_area_entered(p.get_node("HurtArea"))
	check(p.guard_block_count == count, "Consumed projectile cannot register duplicate block")
	p._die()
	check(not p.is_guarding and not p._can_start_guard(), "Death ends and prevents guard")
	Input.action_release("guard")
	world.free()
	print("GUARD_CORE_SMOKE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
