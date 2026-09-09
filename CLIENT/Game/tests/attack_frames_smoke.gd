extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	await process_frame
	await process_frame
	var p = stage.player
	var art = stage.get_node("StageArt")
	var sprite = p.get_node("CharacterArt")
	p.position = Vector2(700,592)
	p.get_node("Camera2D").force_update_scroll()
	stage.get_node("HUD/Presentation").intro_remaining = 0
	for direction in [1,-1]:
		p.facing_direction = direction
		p._update_attack_geometry()
		p._start_attack()
		for index in range(4):
			p._attack_time_remaining = p.attack_duration * (1.0 - (index + 0.2) / 4.0)
			art._update_player_pose()
			check(sprite.attack_frame_index == index, "Frame selected from gameplay timer")
			check(sprite.rotation == 0.0, "No duplicate procedural rotation")
			check(sprite.flip_h == (direction < 0), "Facing mirrored")
			check(sprite.texture.region.size == Vector2(627,627), "Fixed cell size")
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var output := OS.get_environment("ANIMATION_EVIDENCE")
				if not output.is_empty():
					check(root.get_texture().get_image().save_png(output.path_join("attack_%d_%d.png" % [direction,index])) == OK, "Capture saved")
		p._end_attack()
		art._update_player_pose()
		check(sprite.attack_frame_index == -1 and sprite.motion_name == "jump" and sprite.texture == sprite.motions.jump.frames[sprite.motion_frame_index], "Airborne locomotion restored on attack end")
	p._start_attack()
	p.receive_hit()
	art._update_player_pose()
	check(sprite.attack_frame_index == -1, "Hurt overrides attack frames")
	p._update_hurt_flash(1.0)
	p._end_attack()
	p.set_physics_process(true)
	await create_timer(0.4).timeout
	Input.action_press("attack")
	await physics_frame
	await process_frame
	Input.action_release("attack")
	var observed: Array[int] = []
	for tick in range(30):
		await process_frame
		if sprite.attack_frame_index >= 0 and not observed.has(sprite.attack_frame_index):
			observed.append(sprite.attack_frame_index)
		if not p.is_attacking:
			break
	check(observed.size() >= 2, "Live physics advances multiple frames without manual timer edits")
	await create_timer(0.25).timeout
	check(not p.is_attacking and sprite.attack_frame_index == -1, "Live attack ends and restores idle")
	stage.free()
	await process_frame
	print("ATTACK_FRAMES checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
