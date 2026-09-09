extends SceneTree
## State/scene integration fixtures; not human play or duration evidence.
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

func clear_encounter(stage: Node, index: int, count: int) -> void:
	stage.player.position = Vector2(stage.ENTRY_X[index], 580)
	stage._evaluate_stage()
	check(count > 0, "Legacy composition argument retained for caller compatibility")
	var defeated := 0
	for wave in range(2):
		check(stage.enemies.size() == (1 if index < 2 and wave == 0 else 2), "Approved bounded wave composition")
		defeated += stage.enemies.size()
		for enemy in stage.enemies:
			enemy.set_physics_process(false)
			while enemy.current_hp > 0:
				enemy.receive_hit()
		stage._evaluate_stage()
	check(defeated == (3 if index < 2 else 4), "Required encounter total accounts for both waves")
	check(stage.completed[index], "Combat death unlocks E%d" % (index + 1))
	check(stage.stage_state == 0, "Encounter completion alone is not stage clear")
	await process_frame

func finish_stage(stage: Node, counts: Array) -> void:
	for index in range(stage.encounter_index, stage.completed.size()):
		await clear_encounter(stage, index, counts[mini(index, counts.size() - 1)])
	stage.player.position = Vector2(stage.GOAL_X, 580)
	stage._evaluate_stage()
	check(stage.stage_state == 1, "Goal after four encounters clears")
	await create_timer(1.6).timeout

func trait_check(campaign: Node, reach: bool) -> void:
	var player: Node = campaign.stage.player
	check(is_equal_approx(player.attack_range, 90.0 if reach else 72.0), "Trait range exact, no stacking")
	check(is_equal_approx(player.attack_cooldown, 0.40 if reach else 0.32), "Trait cooldown tradeoff exact")
	check(player.current_hp == 3 and player.max_hp == 3, "Trait preserves HP3")

func finish_remaining(campaign: Node, reach: bool) -> void:
	for index in range(2, 5):
		campaign.continue_journey()
		freeze(campaign.stage)
		check(campaign.stage_index == index and campaign.stage.stage_number == index + 1, "Next region enters in order")
		trait_check(campaign, reach)
		await finish_stage(campaign.stage, [1, 2, 2, 3] if index == 2 else [1, 2, 2, 2] if index == 3 else [2, 2, 2, 3])
	check(campaign.cleared == [true,true,true,true,true], "All five regions complete")

func _run() -> void:
	var campaign := Node.new()
	campaign.set_script(load("res://scripts/stage/campaign.gd"))
	root.add_child(campaign)
	current_scene = campaign
	freeze(campaign.stage)
	check(campaign.stage.stage_number == 1, "Campaign begins at Stage1")
	campaign.choose_trait("reach")
	check(campaign.stage_index == 0 and campaign.selected_trait == "basic", "Choice before panel is rejected")
	await finish_stage(campaign.stage, [1, 1, 2, 3])
	check(is_instance_valid(campaign.panel) and campaign.cleared[0], "Stage1 completion shows selection panel")
	campaign.choose_trait("invalid")
	check(campaign.stage_index == 0 and campaign.selected_trait == "basic", "Invalid trait rejected")
	campaign.choose_trait("basic")
	freeze(campaign.stage)
	check(campaign.stage_index == 1 and campaign.stage.stage_number == 2, "Basic choice enters Stage2")
	trait_check(campaign, false)
	campaign.choose_trait("reach")
	check(campaign.selected_trait == "basic", "Duplicate/combat choice rejected")
	# A genuine failed-state timer transition before the checkpoint.
	campaign.stage.player.current_hp = 0
	campaign.stage._evaluate_stage()
	await create_timer(1.6).timeout
	freeze(campaign.stage)
	check(campaign.stage_index == 1 and campaign.stage.encounter_index == 0, "Pre-checkpoint death restarts Stage2")
	trait_check(campaign, false)
	await finish_stage(campaign.stage, [1, 2, 2, 3])
	check(is_instance_valid(campaign.panel) and campaign.cleared == [true, true, false, false, false], "Stage2 completion shows continuation panel")
	campaign.restart_journey()
	check(campaign.stage_index == 1, "Early journey reset rejected")
	await finish_remaining(campaign, false)
	campaign.restart_journey()
	freeze(campaign.stage)
	check(campaign.stage_index == 0 and campaign.cleared == [false, false, false, false, false], "Journey restart resets progress")
	trait_check(campaign, false)
	await finish_stage(campaign.stage, [1, 1, 2, 3])
	campaign.choose_trait("reach")
	freeze(campaign.stage)
	trait_check(campaign, true)
	await clear_encounter(campaign.stage, 0, 1)
	await clear_encounter(campaign.stage, 1, 2)
	var projectile := Node2D.new()
	projectile.add_to_group("enemy_projectile")
	campaign.stage.add_child(projectile)
	campaign.stage.player.current_hp = 1
	campaign.stage.player.position = campaign.stage.CHECKPOINT_POSITION
	campaign.stage._evaluate_stage()
	check(campaign.stage.checkpoint_active and campaign.stage.player.current_hp == 3, "Midpoint activates and heals HP3")
	await process_frame
	check(not is_instance_valid(projectile), "Checkpoint removes residual projectiles")
	await clear_encounter(campaign.stage, 2, 2)
	var old_stage_id: int = campaign.stage.get_instance_id()
	var residual := Node2D.new()
	residual.add_to_group("enemy_projectile")
	campaign.stage.add_child(residual)
	campaign.stage.player.current_hp = 0
	campaign.stage._evaluate_stage()
	await create_timer(1.6).timeout
	freeze(campaign.stage)
	check(campaign.stage.get_instance_id() != old_stage_id, "Checkpoint failure instantiates a fresh stage")
	check(campaign.stage.completed.slice(0, 2) == [true, true] and not campaign.stage.completed.slice(2).has(true) and campaign.stage.encounter_index == 2, "Checkpoint keeps E1/E2, resets E3/E4")
	# Timer wait permits the fresh body to settle onto y620 ground.
	check(absf(campaign.stage.player.position.x - campaign.stage.CHECKPOINT_POSITION.x) < 2.0 and absf(campaign.stage.player.position.y - 580.0) < 20.0, "Checkpoint spawn restored and safely settled")
	check(not is_instance_valid(residual), "Failure removes old projectiles")
	trait_check(campaign, true)
	campaign.choose_trait("basic")
	check(campaign.selected_trait == "reach", "Cannot replace equipped slot during Stage2")
	await finish_stage(campaign.stage, [1, 2, 2, 3])
	await finish_remaining(campaign, true)
	campaign.restart_journey()
	freeze(campaign.stage)
	trait_check(campaign, false)
	campaign.free()
	# Standalone SecondStage path, without campaign ownership.
	for death_first in [false, true]:
		var stage: Node = load("res://scenes/stage/SecondStage.tscn").instantiate()
		root.add_child(stage)
		current_scene = stage
		freeze(stage)
		for index in range(stage.completed.size() - 1):
			stage.completed[index] = true
		stage.encounter_index = stage.completed.size() - 1
		stage.player.position = Vector2(stage.GOAL_X, 580)
		stage._start_encounter()
		if death_first:
			stage.player.current_hp = 0
		for enemy in stage.enemies:
			while enemy.current_hp > 0:
				enemy.receive_hit()
		stage.player.current_hp = 0
		stage._evaluate_stage()
		check(stage.stage_state == 2, "Stage2 same-tick death wins, ordering=%s" % death_first)
		stage._restart_scene()
		await process_frame
		await process_frame
		check(current_scene.stage_number == 2, "Standalone restart preserves SecondStage")
		freeze(current_scene)
		current_scene.free()
	print("CAMPAIGN CHECKS: %d; FAILURES: %d; fixture integration, not human pacing" % [checks, failures])
	quit(1 if failures else 0)
