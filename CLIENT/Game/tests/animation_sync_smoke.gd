extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func capture(label: String) -> void:
	# Fixed controller-time fixtures, not real-time playback evidence.
	var directory := OS.get_environment("ANIMATION_EVIDENCE")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Saved fixture " + label)

func _run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	stage.set_physics_process(false)
	var player = stage.player
	player.set_physics_process(false)
	await process_frame
	await process_frame
	var art = stage.get_node("StageArt")
	var sprite = player.get_node("CharacterArt")
	player.position = Vector2(650, 592)
	player.get_node("Camera2D").force_update_scroll()
	check(not sprite.is_processing(), "Stage owns a single facing/tint/pose presentation pass")
	player._start_attack()
	await process_frame
	art._update_player_pose()
	var first: int = sprite.attack_frame_index
	await capture("fixture_attack_phase_00")
	player._attack_time_remaining = player.attack_duration * 0.5
	art._update_player_pose()
	check(sprite.attack_frame_index != first and sprite.attack_frame_index == 2, "Attack advances actual pose frames")
	art.queue_redraw()
	await capture("fixture_attack_phase_50")
	var middle: int = sprite.motion_frame_index
	art._process(0.0001)
	art._process(0.5)
	check(sprite.motion_frame_index == middle, "Render delta does not advance controller-owned attack frame")
	check(is_equal_approx(player._attack_time_remaining, player.attack_duration * 0.5), "Presentation cannot consume attack timer")
	player._attack_time_remaining = player.attack_duration * 0.1
	art._update_player_pose()
	art.queue_redraw()
	await capture("fixture_attack_phase_90")
	player._end_attack()
	# Visual-only guard fixture; actual controller legality is covered independently.
	player.is_guarding = true
	player._guard_direction = -1
	player.facing_direction = 1
	player._guard_elapsed = 0.4
	art._update_player_pose()
	check(sprite.motion_name == "guard" and sprite.motion_frame_index == 1 and sprite.flip_h, "Guard holds sword in controller-locked direction")
	art.queue_redraw()
	await capture("fixture_guard_hold")
	player._guard_block_flash_remaining = 0.14
	art._update_player_pose()
	check(sprite.motion_name == "guard" and sprite.motion_frame_index == 2, "Block contact uses separate impact frame")
	player._guard_block_flash_remaining = 0.0
	player._end_guard()
	player._guard_recovery_remaining = 0.0
	player.receive_hit()
	art._update_player_pose()
	var recoil: int = sprite.motion_frame_index
	player._hurt_flash_remaining = 0.03
	art._update_player_pose()
	check(sprite.motion_name == "hurt" and sprite.motion_frame_index > recoil, "Hurt frames recover from actual hurt timer")
	player._update_hurt_flash(1)
	art._update_player_pose()
	check(sprite.motion_name == "jump" and sprite.scale == Vector2.ONE * float(sprite.motions.jump.scale) and sprite.rotation == 0.0, "Recovery selects airborne frames without residual deformation")
	stage.free()
	await process_frame
	print("ANIMATION_SYNC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
