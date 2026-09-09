extends SceneTree
## Visual fixtures: not a human playthrough or traversal evidence.
var output: String
var shots := 0

func _initialize() -> void:
	_run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	shots += 1

func _run() -> void:
	output = OS.get_environment("EXPANSION_EVIDENCE")
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
		var ui: Node = stage.get_node("HUD/Presentation")
		ui.touch_visible = true
		ui.intro_remaining = 0
		for point in range(stage.CHECKPOINT_POSITIONS.size()):
			stage.resume_snapshot({"checkpoint_index": point, "completed_prefix": stage.checkpoint_required_counts[point], "optional_completed": stage.optional_completed.duplicate()})
			stage.player.position.y = 592
			stage.player.get_node("Camera2D").force_update_scroll()
			await capture("region_%d_rest_%d" % [index + 1, point + 1])
		var group: Dictionary = stage.optional_groups.back()
		stage.player.position = Vector2(group.x - 20, group.y + 2)
		stage.player.get_node("Camera2D").force_update_scroll()
		await capture("region_%d_final_route" % (index + 1))
		stage.completed.fill(true)
		stage.encounter_index = stage.required_count
		stage.encounter_active = false
		for gate in stage.gates:
			if is_instance_valid(gate) and not gate.is_queued_for_deletion():
				gate.queue_free()
		stage.player.position = Vector2(stage.GOAL_X - 100, 592)
		stage.player.get_node("Camera2D").force_update_scroll()
		await capture("region_%d_goal" % (index + 1))
	root.size = Vector2i(844, 390)
	await capture("wide_mobile_goal")
	campaign.stage.get_node("HUD/Presentation")._toggle_pause(true)
	await capture("wide_mobile_help")
	paused = false
	campaign.free()
	await process_frame
	print("EXTENDED_STAGE_CAPTURE PASS; %d visual fixtures" % shots)
	quit()
