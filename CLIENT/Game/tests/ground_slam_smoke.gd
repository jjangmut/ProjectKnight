extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var p = load("res://scenes/player/Player.tscn").instantiate()
	world.add_child(p)
	p.set_physics_process(false)
	p.position = Vector2(70,-100)
	var g = load("res://scenes/enemy/GroundSlamGolem.tscn").instantiate()
	world.add_child(g)
	g.set_physics_process(false)
	check(g.current_hp == 3 and g.get_meta("ground_slam"), "No HP inflation; distinct slam identity")
	check(g.attack_collision.shape.size == Vector2(220,30), "Ground footprint matches exported visual contract")
	g._begin_attack(-70)
	check(g.attack_area.position == Vector2(0,15), "Centered footprint independent of facing")
	g._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 3, "Windup cannot damage")
	g._update_attack(.84)
	check(not g.is_attack_active, "Full .85s readable warning")
	g._update_attack(.02)
	await physics_frame
	await physics_frame
	check(g.is_attack_active and p.current_hp == 3, "Jump-height player outside ground slam")
	p.position = Vector2(180,0)
	await physics_frame
	await physics_frame
	check(p.current_hp == 3, "Distance evasion clears footprint")
	p.position = Vector2(70,0)
	await physics_frame
	await physics_frame
	check(p.current_hp == 2, "Actual ground area overlap hits once")
	p._hit_invulnerable_until_usec = 0
	g._on_attack_area_entered(p.get_node("HurtArea"))
	check(p.current_hp == 2, "No repeated damage within same slam")
	g._update_attack(.19)
	await process_frame
	check(not g.is_attack_active and g.attack_collision.disabled, "Recovery is non-damaging")
	g._update_attack(1.34)
	check(g.state == 2, "Long recovery allows punish")
	g._update_attack(.02)
	check(g.state == 1, "Recovery returns to chase")
	g.receive_hit()
	g.receive_hit()
	g.receive_hit()
	await process_frame
	check(not is_instance_valid(g), "Three ordinary hits defeat golem")
	world.free()
	print("GROUND SLAM CHECKS: %d; FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
