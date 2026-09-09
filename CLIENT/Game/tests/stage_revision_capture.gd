extends SceneTree
var stage: Node
func _initialize() -> void:
	run.call_deferred()
func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("STAGE_UI_EVIDENCE").path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
func make_stage(index: int, x: float) -> void:
	if is_instance_valid(stage):
		stage.free()
	stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.player.position = Vector2(x,592)
	stage.encounter_index = index
	for i in range(index):
		stage.completed[i] = true
		stage.gates[i].queue_free()
	await process_frame
	await process_frame
	stage.get_node("HUD/Presentation").intro_remaining = 0
	stage.player.get_node("Camera2D").force_update_scroll()
	stage._start_encounter()
	for enemy in stage.enemies:
		enemy.set_physics_process(false)
		enemy.position.y = 590
func run() -> void:
	await make_stage(0,850)
	stage.player._start_attack()
	stage.player._attack_time_remaining = stage.player.attack_duration * 0.5
	await shot("10_attack")
	await make_stage(2,3470)
	await shot("11_beast")
	await make_stage(3,5000)
	await shot("12_golem")
	await make_stage(2,4470)
	stage.player.position.y = 520
	stage.player.get_node("Camera2D").force_update_scroll()
	await shot("13_terrain")
	stage.free()
	print("REVISION_CAPTURE PASS: 4 scenes")
	quit()
