extends SceneTree
## GPU review fixtures only; traversal and gameplay are tested separately.
var output: String

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func _run() -> void:
	output = OS.get_environment("MOBILE_STAGE_EVIDENCE")
	assert(not output.is_empty())
	var campaign: Node = load("res://scenes/stage/Campaign.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	for index in range(5):
		campaign._start_stage(index)
		var stage: Node = campaign.stage
		stage.set_physics_process(false)
		await create_timer(0.15).timeout
		stage.player.set_physics_process(false)
		var presentation: Node = stage.get_node("HUD/Presentation")
		presentation.touch_visible = true
		stage.player.position = Vector2(1760, 592)
		stage.player.get_node("Camera2D").force_update_scroll()
		await capture("stage_%d_lower" % (index + 1))
		var group: Dictionary = stage.optional_groups[0]
		stage.player.position = Vector2(group.x - 60, group.y + 2)
		stage._update_optional_routes()
		for actor in group.actors:
			actor.set_physics_process(false)
		stage.player.get_node("Camera2D").force_update_scroll()
		await capture("stage_%d_upper" % (index + 1))
		stage.player.position = Vector2(4900, 592)
		stage.player.get_node("Camera2D").force_update_scroll()
		await capture("stage_%d_second_route" % (index + 1))
	root.size = Vector2i(844, 390)
	await process_frame
	await capture("mobile_wide_844x390")
	campaign.stage.get_node("HUD/Presentation")._toggle_pause(true)
	await capture("mobile_help_844x390")
	paused = false
	campaign.free()
	await process_frame
	print("MOBILE_STAGE_CAPTURE PASS; 17 GPU fixtures, not human play")
	quit()
