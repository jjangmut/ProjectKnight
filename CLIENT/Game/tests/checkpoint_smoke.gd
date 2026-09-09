extends SceneTree

const STAGE = preload("res://scenes/stage/FirstStage.tscn")
const PROJECTILE = preload("res://scenes/projectile/EnemyProjectile.tscn")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func fresh() -> Node:
	var stage = STAGE.instantiate()
	root.add_child(stage)
	current_scene = stage
	pause_actor_physics(stage)
	return stage


func pause_actor_physics(stage: Node) -> void:
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)


func clear_encounter(stage: Node) -> void:
	stage.player.position.x = stage.ENTRY_X[stage.encounter_index]
	stage._evaluate_stage()
	for wave in range(2):
		for enemy in stage.enemies:
			while enemy.current_hp > 0:
				enemy.receive_hit()
		stage._evaluate_stage()


func shoot(stage: Node) -> Node:
	var projectile = PROJECTILE.instantiate()
	projectile.position = Vector2(3100, 300)
	stage.add_child(projectile)
	return projectile


func _run() -> void:
	# Entering the location without cleared encounters is not sufficient.
	var stage = fresh()
	stage.player.position = stage.CHECKPOINT_POSITION
	stage.player.current_hp = 1
	stage._evaluate_stage()
	check(not stage.checkpoint_active and stage.player.current_hp == 1, "E1/E2 required")
	stage.player._die()
	stage._evaluate_stage()
	stage._restart_scene()
	await scene_changed
	await process_frame
	stage = current_scene
	pause_actor_physics(stage)
	check(not stage.checkpoint_active and stage.encounter_index == 0, "Failure before S05 starts over")
	check(stage.player.current_hp == 3 and stage.player.position.x == 180, "Initial spawn HP3")
	stage.free()

	# Clear real encounter instances, then walk into S05 through physics input.
	stage = fresh()
	clear_encounter(stage)
	await process_frame
	clear_encounter(stage)
	await process_frame
	check(stage.encounter_index == 2 and not stage.checkpoint_active, "E2 completion does not auto activate")
	stage.player.position = stage.CHECKPOINT_POSITION - Vector2(150, 0)
	stage.player.current_hp = 1
	stage.player.set_physics_process(true)
	stage.set_physics_process(true)
	Input.action_press("move_right")
	for tick in range(28):
		await physics_frame
	Input.action_release("move_right")
	await process_frame
	pause_actor_physics(stage)
	check(stage.checkpoint_active and stage.player.current_hp == 3, "Walking into S05 activates and heals")
	check(stage.status_label.text.contains("CP1"), "First checkpoint visible in HUD")
	stage.player.current_hp = 1
	stage.player.position.x = 3100
	stage._evaluate_stage()
	stage.player.position = stage.CHECKPOINT_POSITION
	stage._evaluate_stage()
	check(stage.player.current_hp == 1, "Revisit does not heal")

	# Real Timer timeout, entire scene replacement and repeated failure.
	for iteration in range(2):
		clear_encounter(stage)
		await process_frame
		stage.player.position.x = stage.ENTRY_X[3]
		stage._evaluate_stage()
		stage.enemies[0].receive_hit()
		check(stage.enemies[0].current_hp == 2, "E4 enemy damaged before reset")
		var old_player_id: int = stage.player.get_instance_id()
		var projectile = shoot(stage)
		var projectile_id: int = projectile.get_instance_id()
		stage.player._die()
		stage._evaluate_stage()
		check(stage.stage_state == 2 and stage.restart_timer.time_left > 0, "Failure starts timer")
		check(stage.status_label.text.contains("CP1"), "Failure names first checkpoint restart")
		if iteration == 0:
			var started: int = Time.get_ticks_msec()
			await scene_changed
			await process_frame
			check(Time.get_ticks_msec() - started >= 1300, "Restart waits for 1.5s timer")
		else:
			stage._restart_scene()
			stage._restart_scene()
			check(stage.reload_count == 1, "Duplicate restart blocked")
			await scene_changed
			await process_frame
		stage = current_scene
		pause_actor_physics(stage)
		check(stage.checkpoint_active and stage.player.position.x == stage.CHECKPOINT_POSITION.x, "Checkpoint spawn restored")
		check(stage.player.current_hp == 3 and not stage.player.is_dead, "Fresh alive player HP3")
		check(stage.player.get_instance_id() != old_player_id, "Player replaced, not individually reset")
		check(not is_instance_id_valid(projectile_id), "Old projectile destroyed")
		check(get_nodes_in_group("enemy_projectile").is_empty(), "No residual projectiles")
		check(stage.completed.slice(0, 2) == [true, true] and not stage.completed.slice(2).has(true), "Only E1/E2 retained")
		check(stage.encounter_index == 2 and not stage.encounter_active and stage.enemies.is_empty(), "E3/E4 wait for entry")
		check(not is_instance_valid(stage.gates[0]) or stage.gates[0].is_queued_for_deletion(), "E1 gate open")
		check(not is_instance_valid(stage.gates[1]) or stage.gates[1].is_queued_for_deletion(), "E2 gate open")
		check(is_instance_valid(stage.gates[2]) and is_instance_valid(stage.gates[3]), "E3/E4 gates closed")
		stage.player.current_hp = 2
		stage._evaluate_stage()
		check(stage.player.current_hp == 2, "Respawn does not create repeat healing")

	# Full success still starts a fresh run, not the saved checkpoint.
	clear_encounter(stage)
	await process_frame
	stage.player.position.x = stage.ENTRY_X[3]
	stage._evaluate_stage()
	check(stage.enemies.size() == 2 and stage.enemies[0].current_hp == 3, "E4 composition and HP restored")
	for wave in range(2):
		for enemy in stage.enemies:
			while enemy.current_hp > 0:
				enemy.receive_hit()
		stage._evaluate_stage()
	while stage.encounter_index < stage.completed.size():
		clear_encounter(stage)
	stage.player.position = Vector2(stage.GOAL_X, 580)
	stage._evaluate_stage()
	check(stage.stage_state == 1, "Goal success after checkpoint retry")
	stage._restart_scene()
	await scene_changed
	await process_frame
	stage = current_scene
	pause_actor_physics(stage)
	check(not stage.checkpoint_active and not stage.completed.has(true), "Success clears checkpoint for new run")
	check(stage.player.position.x == 180 and stage.player.current_hp == 3, "Success starts at initial spawn")
	stage.free()

	# Death on first arrival cannot be turned into resurrection by healing.
	stage = fresh()
	clear_encounter(stage)
	await process_frame
	clear_encounter(stage)
	await process_frame
	stage.player.position = stage.CHECKPOINT_POSITION
	stage.player._die()
	stage._evaluate_stage()
	check(stage.stage_state == 2 and not stage.checkpoint_active, "Death wins over checkpoint activation")
	stage.free()

	# Clear the final E2 projectile on first arrival into the safe rest area.
	stage = fresh()
	clear_encounter(stage)
	await process_frame
	clear_encounter(stage)
	await process_frame
	var stray = shoot(stage)
	stage.player.position = stage.CHECKPOINT_POSITION
	stage._evaluate_stage()
	check(stray.is_queued_for_deletion(), "Checkpoint arrival removes remaining shot")
	await process_frame
	check(get_nodes_in_group("enemy_projectile").is_empty(), "Arrival projectile removal completed")
	stage.free()
	print("CHECKPOINT CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
