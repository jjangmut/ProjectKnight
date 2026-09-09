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

func _run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	var expected_steps := 0
	for cluster in stage.route_clusters:
		expected_steps += cluster.rises.size()
	check(stage.route_clusters.size() == 3 and get_nodes_in_group("stage_terrain").size() == expected_steps, "Stage1 contains every step of all three configured upper routes")
	for gate in stage.gates:
		gate.queue_free()
	# The redesigned lower path is continuous: cross former ridge regions without jumping.
	for interval in [Vector2(1460, 1700), Vector2(3020, 3270), Vector2(4330, 4840)]:
		stage.player.position = Vector2(interval.x, 580)
		stage.player.velocity = Vector2.ZERO
		await settle(12)
		var highest: float = stage.player.position.y
		Input.action_press("move_right")
		for tick in range(130):
			await physics_frame
			highest = minf(highest, stage.player.position.y)
			if stage.player.position.x >= interval.y:
				break
		Input.action_release("move_right")
		check(stage.player.position.x >= interval.y, "Player walks through lower route %s" % interval)
		check(highest >= 580 and stage.player.is_on_floor(), "Lower route stays continuously walkable without forced precision jumps")
	# A single jump enters the second optional route's first one-way terrace.
	stage.player.position = Vector2(stage.route_clusters[1].left + 40, 580)
	stage.player.velocity = Vector2.ZERO
	await settle(12)
	Input.action_press("jump")
	await settle(1)
	Input.action_release("jump")
	await settle(55)
	check(stage.player.is_on_floor() and absf(stage.player.position.y - 532.0) < 3.0, "Actual single jump lands on upper route first 60px terrace")
	# Existing melee AI can follow beneath the upper route in both directions.
	stage.player.set_physics_process(false)
	stage.player.position = Vector2(4840, 592)
	stage._spawn(stage.MELEE, 4340)
	var enemy = stage.enemies[0]
	enemy.state = enemy.State.CHASE
	await settle(260)
	check(enemy.position.x > 4730 and enemy.position.y < 630, "Melee follows lower route toward player")
	stage.player.position = Vector2(4340, 592)
	enemy.state = enemy.State.CHASE
	await settle(260)
	check(enemy.position.x < 4450 and enemy.position.y < 630, "Melee returns along lower route without getting trapped")
	enemy.queue_free()
	stage.player.set_physics_process(true)
	stage.player.position = stage.CHECKPOINT_POSITION
	stage.player.velocity = Vector2.ZERO
	await settle(20)
	check(stage.player.is_on_floor() and absf(stage.player.position.y - 592.0) < 3, "S05 spawn settles on unchanged safe floor")
	stage.player.position = Vector2(stage.GOAL_X - 100, 580)
	stage.player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await settle(18)
	Input.action_release("move_right")
	for index in range(stage.completed.size()):
		stage.completed[index] = true
	stage.encounter_index = stage.completed.size()
	stage._evaluate_stage()
	check(stage.stage_state == stage.StageState.CLEARED, "Walking into Goal after all four encounters still clears")
	stage.free()
	print("TERRAIN CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
