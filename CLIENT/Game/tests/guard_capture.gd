extends SceneTree
## GPU presentation fixtures, not a human playtest.
var output: String
var stage: Node
var player: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)

func _run() -> void:
	output = OS.get_environment("GUARD_EVIDENCE")
	stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	player = stage.player
	player.position = Vector2(650, 580)
	await frames(20)
	Input.action_press("guard")
	await frames(2)
	await capture("guard_raise")
	await frames(8)
	await capture("guard_hold")
	assert(player.receive_attack(player.global_position + Vector2(100,0), true))
	await capture("guard_contact")
	assert(player.current_hp == 3)
	Input.action_release("guard")
	await frames(30)
	player.facing_direction = -1
	player._update_attack_geometry()
	Input.action_press("guard")
	await frames(8)
	await capture("guard_left")
	assert(not player.receive_attack(player.global_position + Vector2(100,0), true))
	await capture("guard_back_hit")
	assert(player.current_hp == 2)
	Input.action_release("guard")
	await frames(40)
	# Reinitialize health only for an isolated heavy-hit presentation fixture.
	player.current_hp = 3
	player.facing_direction = 1
	player._update_attack_geometry()
	var golem: Node = load("res://scenes/enemy/GroundSlamGolem.tscn").instantiate()
	golem.position = player.position + Vector2(100,0)
	stage.add_child(golem)
	golem.set_physics_process(false)
	golem._begin_attack(-1)
	Input.action_press("guard")
	await frames(8)
	await capture("guard_unblockable_warning")
	assert(not player.receive_attack(golem.global_position, false))
	await capture("guard_heavy_hit")
	assert(player.current_hp == 2)
	Input.action_release("guard")
	stage.get_node("HUD/Presentation")._toggle_pause(true)
	await capture("guard_help")
	stage.get_node("HUD/Presentation")._toggle_pause()
	var art: Node = stage.get_node("StageArt")
	assert(art.guard_audio.stream.data.size() > 0)
	assert(art.guard_audio.stream.save_to_wav(output.path_join("guard_clang.wav")) == OK)
	stage.free()
	await process_frame
	print("GUARD_CAPTURE PASS; 8 images and original procedural audio; fixtures only")
	quit()
