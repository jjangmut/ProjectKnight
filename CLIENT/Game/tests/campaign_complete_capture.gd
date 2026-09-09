extends SceneTree
## Review fixtures; not human playtime or a natural playthrough.
var output: String
var campaign: Node

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func _run() -> void:
	output = OS.get_environment("CAMPAIGN_EVIDENCE")
	campaign = load("res://scenes/stage/Campaign.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	for index in range(5):
		var stage: Node = campaign.stage
		stage.set_physics_process(false)
		await create_timer(0.2).timeout
		stage.player.set_physics_process(false)
		await capture("stage_%d_start" % (index + 1))
		stage.player.position = Vector2(2050, 592)
		stage.player.get_node("Camera2D").reset_smoothing()
		stage.player.get_node("Camera2D").force_update_scroll()
		stage.encounter_index = 1
		stage._start_encounter()
		await create_timer(0.5).timeout
		for actor in stage.enemies:
			actor.set_physics_process(false)
		await capture("stage_%d_arena" % (index + 1))
		for child in stage.get_children():
			if child.is_in_group("enemy") or child.is_in_group("enemy_projectile"):
				child.queue_free()
		stage.completed.fill(true)
		stage.encounter_index = stage.completed.size()
		stage.encounter_active = false
		stage.player.position = Vector2(stage.GOAL_X, 580)
		stage._evaluate_stage()
		await create_timer(1.65).timeout
		await capture("stage_%d_complete" % (index + 1))
		if index == 0:
			campaign.choose_trait("reach")
		elif index < 4:
			campaign.continue_journey()
	# Isolated effects use real controller phase advancement, frozen for capture.
	campaign.restart_journey()
	var stage: Node = campaign.stage
	stage.set_physics_process(false)
	stage.player.position = Vector2(650, 592)
	stage.player.set_physics_process(false)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	for variant in ["TestEnemy", "RangedEnemy", "ChargingBeast", "GroundSlamGolem"]:
		var actor: Node = load("res://scenes/enemy/%s.tscn" % variant).instantiate()
		actor.position = Vector2(800, 590)
		stage.add_child(actor)
		actor.set_physics_process(false)
		await process_frame
		if variant == "RangedEnemy":
			actor._begin_attack()
		else:
			actor._begin_attack(-1.0)
		actor._phase_time_remaining = actor.attack_windup * 0.3
		await capture("vfx_%s_warning" % variant)
		actor._update_attack(actor.attack_windup)
		if variant != "RangedEnemy":
			actor._phase_time_remaining = actor.attack_active * 0.6
		await capture("vfx_%s_active" % variant)
		actor.queue_free()
		for child in stage.get_children():
			if child.is_in_group("enemy_projectile"):
				child.queue_free()
		await process_frame
	campaign.free()
	await process_frame
	print("CAMPAIGN_COMPLETE_CAPTURE PASS; 23 fixtures, not human play")
	quit()
