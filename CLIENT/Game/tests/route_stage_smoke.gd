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

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func walk_to(player: CharacterBody2D, x: float) -> void:
	Input.action_press("move_right")
	for i in range(1400):
		await physics_frame
		if player.position.x >= x:
			break
	Input.action_release("move_right")
	await ticks(2)
	check(player.position.x >= x, "Actual horizontal travel reaches %s" % x)

func _run() -> void:
	for number in range(1, 6):
		var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
		stage.stage_number = number
		root.add_child(stage)
		current_scene = stage
		stage.set_physics_process(false)
		for gate in stage.gates:
			gate.get_child(0).set_deferred("disabled", true)
		await ticks(3)
		# Start at the real spawn and traverse both upper routes without teleporting.
		for branch in range(stage.route_clusters.size()):
			var previous_top := 620.0
			for node in get_nodes_in_group("stage_terrain"):
				if not str(node.name).begins_with("Route%dStep" % branch):
					continue
				var width: float = node.get_child(0).shape.size.x
				var left: float = node.position.x - width / 2.0
				var top: float = node.position.y - 9.0
				await walk_to(stage.player, left - 38.0)
				if top < previous_top:
					Input.action_press("jump")
					await ticks(1)
					Input.action_release("jump")
				await walk_to(stage.player, left + 70.0)
				await ticks(48)
				check(stage.player.is_on_floor() and absf(stage.player.position.y - (top - 28.0)) < 4.0, "Stage%d branch%d lands on %s through physics" % [number, branch, node.name])
				previous_top = top
			await walk_to(stage.player, stage.route_clusters[branch].right + 100.0)
			await ticks(45)
			check(absf(stage.player.position.y - 592.0) < 4.0, "Upper route rejoins safe ground")
		await walk_to(stage.player, stage.GOAL_X)
		# Two waves, at most two actors each, 14 required total.
		var total := 0
		for index in range(stage.completed.size()):
			stage.encounter_index = index
			stage._start_encounter()
			for wave in range(2):
				total += stage.enemies.size()
				check(stage.enemies.size() <= 2, "Required waves never exceed two")
				for enemy in stage.enemies:
					enemy.current_hp = 0
					enemy.queue_free()
				await ticks(2)
				if wave == 0:
					stage.encounter_wave = 1
					stage._spawn_required_wave()
		check(total == 4 * stage.required_count - 2, "Expanded required composition: two waves per anchor")
		# Optional actors never enter the required arrays; rewards are consumed once.
		stage.player.position = Vector2(stage.optional_groups[0].x, stage.optional_groups[0].y)
		stage.player.current_hp = 2
		stage._update_optional_routes()
		check(stage.optional_groups[0].actors.size() == 2, "Branch activates only its local pair")
		for actor in stage.optional_groups[0].actors:
			actor.current_hp = 0
			actor.queue_free()
		await ticks(2)
		stage._update_optional_routes()
		check(stage.player.current_hp == 3 and stage.optional_completed[0], "Optional clear heals once capped at3")
		stage.player.current_hp = 2
		stage._update_optional_routes()
		check(stage.player.current_hp == 2, "Cleared branch cannot farm health")
		stage.player.position = Vector2(stage.optional_groups[1].x, stage.optional_groups[1].y)
		stage._update_optional_routes()
		for actor in stage.optional_groups[1].actors:
			actor.queue_free()
		await ticks(2)
		stage._update_optional_routes()
		check(not stage.optional_completed[1] and stage.player.current_hp == 2, "Deleting live optional actors never rewards or clears")
		stage.restore_optional_routes([true, true])
		check(stage.optional_groups[1].cleared, "Checkpoint carry consumes cleared reward")
		# Exercise the real deferred evaluator's wave and checkpoint contracts.
		stage.encounter_index = 0
		stage.encounter_active = false
		stage.player.position = Vector2(500, 580)
		stage._evaluate_stage()
		for index in range(stage.completed.size()):
			if index > 0:
				stage.player.position = Vector2(stage.ENTRY_X[index], 580)
				stage._evaluate_stage()
			for wave in range(2):
				for actor in stage.enemies:
					actor.current_hp = 0
					actor.queue_free()
				await ticks(2)
				stage._evaluate_stage()
				if wave == 0:
					check(not stage.completed[index], "First wave never completes anchor")
			check(stage.completed[index], "Second wave completes anchor")
			if index == 1:
				stage.player.position = stage.CHECKPOINT_POSITION
				stage._evaluate_stage()
				check(stage.checkpoint_active and stage.player.current_hp == 3, "Checkpoint requires first2anchors and heals")
		check(stage.stage_state == stage.StageState.PLAYING, "Required clears alone never clear stage")
		stage.optional_completed.fill(false)
		stage.player.position = Vector2(stage.GOAL_X, 580)
		stage._evaluate_stage()
		check(stage.stage_state == stage.StageState.CLEARED, "Optional encounters never gate Goal")
		stage.stage_state = stage.StageState.PLAYING
		stage.player.current_hp = 0
		stage._evaluate_stage()
		check(stage.stage_state == stage.StageState.FAILED, "Dead at Goal loses before clear")
		stage.free()
		await ticks(2)
	print("ROUTE CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
