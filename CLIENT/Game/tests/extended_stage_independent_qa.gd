extends SceneTree
## Independent state/reload fixtures, not human pacing or full manual play evidence.
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func freeze(stage: Node) -> void:
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
func projectile(stage: Node) -> Node:
	var shot = load("res://scenes/projectile/EnemyProjectile.tscn").instantiate()
	shot.position = Vector2(300, 300)
	stage.add_child(shot)
	shot.set_physics_process(false)
	return shot
func prefix(stage: Node, count: int) -> void:
	stage.completed.fill(false)
	for i in range(count):
		stage.completed[i] = true
	stage.encounter_index = count
	stage.encounter_active = false
func clear_optional(stage: Node, index: int) -> void:
	stage.player.position = Vector2(stage.optional_groups[index].x, stage.optional_groups[index].y)
	stage._update_optional_routes()
	for enemy in stage.optional_groups[index].actors:
		enemy.set_physics_process(false)
		while enemy.current_hp > 0:
			enemy.receive_hit()
	stage._update_optional_routes()
func _run() -> void:
	for number in range(1, 6):
		var campaign = load("res://scenes/stage/Campaign.tscn").instantiate()
		root.add_child(campaign)
		current_scene = campaign
		campaign._start_stage(number - 1)
		var stage = campaign.stage
		freeze(stage)
		check(stage.required_count == (6 if number <= 2 else 8), "Approved required anchors Stage%d" % number)
		check(stage.route_clusters.size() == (3 if number <= 2 else 4) and stage.optional_groups.size() == stage.route_clusters.size(), "Approved expanded optional route count")
		check(stage.checkpoint_positions.size() == (2 if number <= 2 else 3), "Approved checkpoint count")
		check(stage.WORLD_WIDTH >= 9900 and stage.WORLD_WIDTH <= 13200 and stage.GOAL_X == stage.WORLD_WIDTH - 300, "Expanded world within approved1.5–2x spatial range")
		for cp in range(stage.checkpoint_positions.size()):
			var need: int = stage.checkpoint_required_counts[cp]
			stage.player.current_hp = 1
			stage.player.position = stage.checkpoint_positions[cp]
			stage._evaluate_stage()
			check(stage.checkpoint_index < cp and stage.player.current_hp == 1, "Checkpoint cannot activate before required prefix")
			prefix(stage, need)
			var shot = projectile(stage)
			stage.player.position = stage.checkpoint_positions[cp]
			stage._evaluate_stage()
			check(stage.checkpoint_index == cp and stage.checkpoint_prefix == need and stage.player.current_hp == 3, "Checkpoint activates correct prefix and restores HP3")
			check(shot.is_queued_for_deletion(), "New checkpoint consumes residual projectile")
			stage.player.current_hp = 1
			clear_optional(stage, cp)
			check(stage.optional_completed[cp] and stage.player.current_hp == 2, "Optional combat after checkpoint rewards once")
			stage._update_optional_routes()
			check(stage.player.current_hp == 2, "Optional repeat evaluation cannot farm healing")
			for old in range(cp + 1):
				stage.player.position = stage.checkpoint_positions[old]
				stage._evaluate_stage()
				check(stage.checkpoint_index == cp and stage.player.current_hp == 2, "Backward/current checkpoint cannot downgrade or re-heal")
			# Advance one anchor after activation. Failure must roll it back, not save it silently.
			prefix(stage, need + 1)
			var snapshot: Dictionary = stage.get_checkpoint_snapshot()
			check(snapshot.completed_prefix == need, "Checkpoint snapshot does not adopt later required progress")
			var old_id: int = stage.get_instance_id()
			var residual = projectile(stage)
			stage.player.current_hp = 0
			stage._evaluate_stage()
			await create_timer(1.65).timeout
			stage = campaign.stage
			freeze(stage)
			check(stage.get_instance_id() != old_id and not is_instance_valid(residual), "Actual campaign failure timer replaces scene and removes shots")
			check(stage.checkpoint_index == cp and stage.checkpoint_prefix == need and stage.encounter_index == need, "Latest checkpoint restores correct required prefix")
			check(stage.completed.slice(0, need).all(func(v): return v) and not stage.completed.slice(need).has(true), "Only checkpoint prefix retained; later encounter resets")
			check(absf(stage.player.position.x - stage.checkpoint_positions[cp].x) < 1 and stage.player.current_hp == 3, "Latest checkpoint respawn position and HP3")
			check(stage.optional_completed[cp] and stage.optional_groups[cp].cleared, "Earned optional completion survives checkpoint retry")
			stage.player.current_hp = 1
			stage.player.position = Vector2(stage.optional_groups[cp].x, stage.optional_groups[cp].y)
			stage._update_optional_routes()
			check(stage.optional_groups[cp].actors.is_empty() and stage.player.current_hp == 1, "Consumed optional reward cannot farm after reload")
		prefix(stage, stage.required_count - 1)
		stage.player.position = Vector2(stage.GOAL_X, 580)
		stage._evaluate_stage()
		check(stage.stage_state == 0, "Goal rejects incomplete expanded required sequence")
		prefix(stage, stage.required_count)
		stage.player.current_hp = 0
		stage._evaluate_stage()
		check(stage.stage_state == 2, "Death wins at Goal with all expanded encounters complete")
		stage._finish(1)
		check(stage.stage_state == 2, "Late clear cannot replace FAILED")
		campaign._start_stage(number - 1)
		stage = campaign.stage
		freeze(stage)
		check(stage.checkpoint_index == -1 and not stage.completed.has(true) and not stage.optional_completed.has(true), "Fresh stage starts without old checkpoint/optional progress")
		clear_optional(stage, 0)
		stage.player.current_hp = 0
		stage._evaluate_stage()
		await create_timer(1.65).timeout
		stage = campaign.stage
		freeze(stage)
		check(stage.checkpoint_index == -1 and stage.encounter_index == 0 and stage.player.position.x == 180, "Failure before first checkpoint returns to starting position")
		check(stage.optional_completed[0] and stage.optional_groups[0].cleared, "Optional reward remains consumed even before first checkpoint")
		campaign._start_stage(number - 1)
		stage = campaign.stage
		freeze(stage)
		prefix(stage, stage.required_count)
		stage.player.position = Vector2(stage.GOAL_X, 580)
		stage._evaluate_stage()
		check(stage.stage_state == 1, "Alive Goal after every required anchor clears without optional completion")
		campaign.free()
		await process_frame
	# Standalone scene must carry the same latest checkpoint, not just Campaign owner.
	var standalone = load("res://scenes/stage/FifthStage.tscn").instantiate()
	root.add_child(standalone)
	current_scene = standalone
	freeze(standalone)
	prefix(standalone, 6)
	standalone.player.position = standalone.checkpoint_positions[2]
	standalone._evaluate_stage()
	check(standalone.checkpoint_index == 2, "Standalone can activate latest qualified checkpoint")
	clear_optional(standalone, 2)
	standalone.player.current_hp = 0
	standalone._evaluate_stage()
	await scene_changed
	await process_frame
	standalone = current_scene
	freeze(standalone)
	check(standalone.stage_number == 5 and standalone.checkpoint_index == 2 and standalone.encounter_index == 6, "Standalone timed reload preserves scene and latest prefix")
	check(standalone.optional_completed[2] and standalone.player.current_hp == 3, "Standalone reload carries consumed optional reward and HP3")
	prefix(standalone, standalone.required_count)
	standalone.player.position = Vector2(standalone.GOAL_X, 580)
	standalone._evaluate_stage()
	await scene_changed
	await process_frame
	standalone = current_scene
	freeze(standalone)
	check(standalone.stage_number == 5 and standalone.checkpoint_index == -1 and not standalone.optional_completed.has(true), "Standalone success restarts fresh without checkpoint carry")
	standalone.free()
	await process_frame
	print("EXTENDED_STAGE_INDEPENDENT_QA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
