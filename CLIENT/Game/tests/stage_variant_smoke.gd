extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle(ticks: int) -> void:
	for tick in range(ticks):
		await physics_frame

func fresh() -> Node:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	return stage

func _run() -> void:
	for index in [2, 3]:
		var stage = fresh()
		if index == 2:
			stage._resume_checkpoint()
		else:
			stage.encounter_index = index
		stage._start_encounter()
		var enemy = stage.enemies[0]
		var expected := Vector2(70, 50) if index == 2 else Vector2(76, 96)
		check(enemy.get_meta("art_variant") == ("beast" if index == 2 else "golem"), "Expected variant after checkpoint / E4 spawn")
		var body: CollisionShape2D = enemy.get_node("CollisionShape2D")
		var hurt: CollisionShape2D = enemy.get_node("HurtArea/CollisionShape2D")
		check(body.shape.size == expected and hurt.shape.size == expected, "Body and hurt bounds match variant")
		check(body.position == hurt.position and is_equal_approx(body.position.y + expected.y * 0.5, 30.0), "Body and hurt share grounded feet")
		var original = stage.MELEE.instantiate()
		check(original.get_node("CollisionShape2D").shape.size == Vector2(44, 60), "Original packed body resource unchanged")
		check(original.get_node("HurtArea/CollisionShape2D").shape.size == Vector2(44, 60), "Original packed hurt resource unchanged")
		original.free()
		if index == 3:
			check(stage.enemies[1].get_node("CollisionShape2D").shape.size == Vector2(44, 60), "Second E4 melee retains original body")
		for other in stage.enemies:
			if other != enemy:
				other.set_physics_process(false)
		stage.player.position = Vector2(enemy.position.x - 250, 580)
		stage.player.velocity = Vector2.ZERO
		var initial_x: float = enemy.position.x
		await settle(145)
		check(enemy.position.x < initial_x - 100, "Variant AI approaches player")
		check(enemy.attack_count > 0 and stage.player.hit_count > 0, "Variant physical attack reaches player")
		enemy.set_physics_process(false)
		enemy.attack_collision.set_deferred("disabled", true)
		stage.player.position.x = enemy.position.x - 72
		stage.player.facing_direction = 1
		stage.player._update_attack_geometry()
		await settle(3)
		var hp_before: int = enemy.current_hp
		Input.action_press("attack")
		await settle(1)
		Input.action_release("attack")
		await settle(12)
		check(enemy.current_hp < hp_before, "Player real attack overlaps variant hurt area")
		stage.free()
	# Large golem retains the ability to cross the terrain beneath one-way perch.
	var stage = fresh()
	for gate in stage.gates:
		gate.queue_free()
	stage.encounter_index = 3
	stage._spawn(stage.MELEE, 4340)
	var golem = stage.enemies[0]
	stage.player.set_physics_process(false)
	stage.player.position = Vector2(4840, 592)
	golem.state = golem.State.CHASE
	await settle(270)
	check(golem.position.x > 4730 and golem.position.y < 630, "Large golem crosses high pass and perch")
	stage.player.position = Vector2(4340, 592)
	golem.state = golem.State.CHASE
	await settle(270)
	check(golem.position.x < 4450 and golem.position.y < 630, "Large golem returns across high pass")
	stage.free()
	print("VARIANT CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
