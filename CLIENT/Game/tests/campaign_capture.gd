extends SceneTree
## Workflow fixtures for review, not a human playtime benchmark.
var campaign: Node
var output: String
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	output = OS.get_environment("CAMPAIGN_EVIDENCE")
	campaign = load("res://scenes/stage/Campaign.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await create_timer(0.4).timeout
	await capture("01_stage1")
	await complete_stage()
	await capture("02_trait_selection")
	campaign.choose_trait("reach")
	await create_timer(0.4).timeout
	await capture("03_stage2")
	var stage = campaign.stage
	stage.player.position = Vector2(770,580)
	await create_timer(0.25).timeout
	await capture("04_charge_warning")
	Input.action_press("jump")
	await create_timer(0.1).timeout
	Input.action_release("jump")
	await capture("05_jump_evade")
	await create_timer(0.5).timeout
	await capture("06_recovery")
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.completed.assign([true,true,false,false])
	stage.encounter_index = 2
	stage.encounter_active = false
	stage.player.position = stage.CHECKPOINT_POSITION
	stage._evaluate_stage()
	await capture("07_checkpoint")
	stage.player._die()
	stage._evaluate_stage()
	await create_timer(0.6).timeout
	await capture("08_failed")
	await create_timer(1.1).timeout
	await capture("09_checkpoint_resume")
	await complete_stage()
	await capture("10_two_stage_complete")
	print("CAMPAIGN_CAPTURE PASS; workflow fixtures, not human play")
	campaign.free()
	await process_frame
	quit()
func complete_stage() -> void:
	var stage = campaign.stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	for child in stage.get_children():
		if child.is_in_group("enemy") or child.is_in_group("enemy_projectile"):
			child.queue_free()
	stage.completed.fill(true)
	stage.encounter_index = stage.completed.size()
	stage.player.position = Vector2(stage.GOAL_X,580)
	stage._evaluate_stage()
	await create_timer(1.65).timeout
func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(label+".png"))
	assert(result == OK)
