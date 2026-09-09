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

func fresh(number: int):
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	stage.stage_number = number
	stage.campaign_mode = true
	root.add_child(stage)
	stage.set_physics_process(false)
	return stage

func walk_to(player: CharacterBody2D, x: float) -> void:
	Input.action_press("move_right")
	for i in range(2800):
		await physics_frame
		if player.position.x >= x:
			break
	Input.action_release("move_right")
	await ticks(2)
	check(player.position.x >= x, "Actual input reaches x=%s" % x)

func _run() -> void:
	for number in range(1, 6):
		var stage = fresh(number)
		check(stage.WORLD_WIDTH >= 11000 and stage.player.get_node("Camera2D").limit_right == int(stage.WORLD_WIDTH), "Extended world/camera agree")
		check(stage.required_count == (6 if number <= 2 else 8), "Required anchors extended")
		check(stage.checkpoint_positions.size() == (2 if number <= 2 else 3), "Two or three checkpoints")
		for gate in stage.gates:
			gate.get_child(0).set_deferred("disabled", true)
		await ticks(3)
		# Every upper cluster is traversed from the real starting position with real input.
		for branch in range(stage.route_clusters.size()):
			var previous_top := 620.0
			for node in get_nodes_in_group("stage_terrain"):
				if node.get_parent() != stage or not str(node.name).begins_with("Route%dStep" % branch):
					continue
				var width: float = node.get_child(0).shape.size.x
				var left: float = node.position.x - width / 2.0
				var top: float = node.position.y - 9.0
				check(previous_top - top <= 60.0 and width >= 120.0, "Broad landings and at most60px rises")
				await walk_to(stage.player, left - 38.0)
				if top < previous_top:
					Input.action_press("jump")
					await ticks(1)
					Input.action_release("jump")
				await walk_to(stage.player, left + 45.0)
				await ticks(48)
				check(stage.player.is_on_floor() and absf(stage.player.position.y - top + 28.0) < 4.0, "S%d branch%d actual landing %s" % [number, branch, node.name])
				previous_top = top
			await walk_to(stage.player, stage.route_clusters[branch].right + 110.0)
			await ticks(40)
			check(absf(stage.player.position.y - 592.0) < 4.0, "Cluster returns to lower floor before gate")
		await walk_to(stage.player, stage.GOAL_X)
		stage.free()
		await ticks(2)
		# Actual evaluator completes both waves at every anchor, activates each CP.
		stage = fresh(number)
		stage.player.set_physics_process(false)
		var total := 0
		for anchor in range(stage.required_count):
			stage.player.position = Vector2(stage.ENTRY_X[anchor], 580)
			stage._evaluate_stage()
			for wave in range(2):
				check(stage.enemies.size() <= 2, "Wave population stays mobile-friendly")
				total += stage.enemies.size()
				for enemy in stage.enemies:
					enemy.current_hp = 0
					enemy.queue_free()
				await ticks(2)
				stage._evaluate_stage()
			check(stage.completed[anchor], "Anchor completes after second wave")
			var cp: int = stage.checkpoint_required_counts.find(anchor + 1)
			if cp >= 0:
				stage.player.position = stage.checkpoint_positions[cp]
				stage.player.current_hp = 1
				stage._evaluate_stage()
				check(stage.checkpoint_index == cp and stage.player.current_hp == 3, "New CP advances and heals")
				stage.player.current_hp = 2
				stage._evaluate_stage()
				check(stage.player.current_hp == 2, "Standing at CP cannot heal repeatedly")
				stage.optional_completed[0] = true
				var saved: Dictionary = stage.get_checkpoint_snapshot()
				var restored = fresh(number)
				restored.resume_snapshot(saved)
				check(restored.checkpoint_index == cp and restored.encounter_index == anchor + 1 and restored.player.current_hp == 3, "Snapshot restores latest CP and captured prefix")
				check(restored.completed.count(true) == anchor + 1 and restored.optional_completed[0], "Only required prefix and consumed optional reward survive")
				restored.free()
				if cp > 0:
					stage.player.position = stage.checkpoint_positions[0]
					stage._evaluate_stage()
					check(stage.checkpoint_index == cp and stage.player.current_hp == 2, "Backward CP cannot downgrade or heal")
		check(total == stage.required_count * 4 - 2, "Exact required enemy count")
		check(stage.stage_state == stage.StageState.PLAYING, "Completing anchors alone never wins")
		stage.player.position = Vector2(stage.GOAL_X, 580)
		stage.completed[stage.required_count - 1] = false
		stage.encounter_index = stage.required_count
		stage._evaluate_stage()
		check(stage.stage_state == stage.StageState.PLAYING, "Missing required clear blocks Goal")
		stage.completed.fill(true)
		stage.player.current_hp = 0
		stage._evaluate_stage()
		check(stage.stage_state == stage.StageState.FAILED, "Death at Goal takes priority")
		stage.free()
		await ticks(2)
	print("EXTENDED STAGE CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
