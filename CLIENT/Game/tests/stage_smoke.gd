extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh() -> Node:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	return stage

func kill_enemies(stage: Node) -> void:
	for enemy in stage.enemies:
		while is_instance_valid(enemy) and enemy.current_hp > 0:
			enemy.receive_hit()

func _run() -> void:
	var stage = fresh()
	check(stage.enemies.is_empty(), "No future enemies before entry")
	stage.player.position = Vector2(6300, 580)
	stage._evaluate_stage()
	check(stage.stage_state == 0, "Goal cannot clear unfinished encounters")
	stage.free()
	stage = fresh()
	for index in range(4):
		stage.player.position.x = stage.ENTRY_X[index]
		stage._evaluate_stage()
		check(stage.enemies.size() == [1, 1, 2, 3][index], "Approved composition E%d" % (index + 1))
		kill_enemies(stage)
		stage._evaluate_stage()
		check(stage.completed[index], "Encounter completes on combat death")
		check(stage.stage_state == 0, "Encounter death does not clear stage")
		await process_frame
	stage.player.position = Vector2(6300, 580)
	stage._evaluate_stage()
	check(stage.stage_state == 1, "All encounters plus alive plus goal clears")
	stage.player.is_dead = true
	stage._evaluate_stage()
	check(stage.stage_state == 1, "Terminal result cannot change")
	stage._restart_scene()
	stage._restart_scene()
	check(stage.reload_count == 1, "Restart requested once")
	await process_frame
	await process_frame
	stage = current_scene
	check(stage.player.current_hp == 3 and stage.encounter_index == 0 and stage.enemies.is_empty(), "Reload restores initial state")
	stage.free()
	for death_first in [false, true]:
		stage = fresh()
		stage.player.position = Vector2(6300, 580)
		for index in range(3):
			stage.completed[index] = true
		stage.encounter_index = 3
		stage._start_encounter()
		if death_first:
			stage.player.is_dead = true
		kill_enemies(stage)
		stage.player.is_dead = true
		stage._evaluate_stage()
		check(stage.stage_state == 2, "Same tick death wins in either order")
		stage._evaluate_stage()
		check(stage.stage_state == 2, "Failed stays failed")
		stage.free()
	# Noncombat removal must not unlock a gate.
	stage = fresh()
	stage.player.position.x = 400
	stage._evaluate_stage()
	stage.enemies[0].queue_free()
	await process_frame
	stage._evaluate_stage()
	check(not stage.completed[0], "Unexpected removal is not combat completion")
	stage.free()
	# Exercise real movement/collision callbacks, rather than only state methods.
	stage = fresh()
	stage.player.position = Vector2(1300, 580)
	stage.player.set_physics_process(true)
	Input.action_press("move_right")
	for tick in range(90):
		if tick == 20:
			Input.action_press("jump")
		if tick == 21:
			Input.action_release("jump")
		await physics_frame
	Input.action_release("move_right")
	check(stage.player.position.x < 1430 and stage.player.position.x > 1300, "Real movement and jump cannot bypass closed gate")
	check(stage.player.is_on_floor(), "Player returns to floor")
	stage.free()
	print("STAGE CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
