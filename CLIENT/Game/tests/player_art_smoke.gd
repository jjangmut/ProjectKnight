extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	var player = stage.player
	player.set_physics_process(false)
	var art = player.get_node("CharacterArt")
	check(art.texture != null, "Character texture loaded")
	check(not player.get_node("Visual").visible and not player.get_node("FacingMark").visible, "Fallback hidden")
	check(player.get_node("CollisionShape2D").shape.size == Vector2(40, 56), "Collision unchanged")
	check(player.get_node("HurtArea/CollisionShape2D").shape.size == Vector2(40, 56), "Hurt box unchanged")
	check(player.get_node("AttackArea/CollisionShape2D").shape.size == Vector2(72, 52), "Attack box unchanged")
	check(art.motions.has(art.motion_name) and art.scale == Vector2.ONE * float(art.motions[art.motion_name].scale), "Frame uses contracted game-size scale")
	check(art.offset.y == -art.motions[art.motion_name].pivots[art.motion_frame_index].y, "Frame foot pivot cancels local image offset")
	check(absf(art.position.y - 28.0) < 0.01, "Feet aligned to body bottom")
	player.facing_direction = -1
	art._update_visual()
	check(art.flip_h, "Left facing")
	player.facing_direction = 1
	art._update_visual()
	check(not art.flip_h, "Right facing")
	player.receive_hit()
	art._update_visual()
	check(player.current_hp == 2, "Existing damage works")
	check(art.material.get_shader_parameter("hurt_flash") == 1.0, "White hurt flash")
	player._update_hurt_flash(1.0)
	art._update_visual()
	check(art.material.get_shader_parameter("hurt_flash") == 0.0, "Flash clears")
	# Presentation-only guarded fixture (controller legality has a separate suite).
	player.is_guarding = true
	player._guard_direction = -1
	player._guard_elapsed = 0.4
	art._update_visual()
	check(art.flip_h and art.self_modulate.a == 1.0 and art.motion_name == "guard", "Guard faces locked direction with opaque knight pose")
	player._end_guard()
	player._guard_recovery_remaining = 0.0
	art._update_visual()
	check(art.self_modulate == Color.WHITE, "Normal art color restored")
	player._start_attack()
	check(player.is_attacking and player.get_node("AttackArea/AttackVisual").visible, "Existing attack effect intact")
	player._end_attack()
	# Render the actual game-size sprite beside the approved checkpoint.
	stage._resume_checkpoint()
	player.position = Vector2(2810, 592)
	player.current_hp = 3
	player.facing_direction = 1
	art._update_visual()
	stage._update_hud()
	player.get_node("Camera2D").force_update_scroll()
	var args = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1] + "-right.png")
		player.facing_direction = -1
		art._update_visual()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1] + "-left.png")
	player._die()
	art._update_visual()
	check(player.is_dead and art.material.get_shader_parameter("hurt_flash") == 0.0, "Death retains controller behavior")
	print("PLAYER ART CHECKS: %d; FAILURES: %d" % [checks, failures])
	stage.free()
	quit(1 if failures else 0)
