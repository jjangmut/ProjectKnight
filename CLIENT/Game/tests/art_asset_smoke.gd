extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.player.position = Vector2(2810, 580)
	var sprite = scene._checkpoint_visual.get_node("S05Art")
	if not sprite is Sprite2D or sprite.texture == null or absf(sprite.texture.get_width() * sprite.scale.x - 128.0) > 0.1:
		push_error("S05 sprite load/scale failure")
		quit(1)
		return
	if sprite.z_index >= scene.player.z_index:
		push_error("Checkpoint art must not obscure Player")
		quit(1)
		return
	var camera: Camera2D = scene.player.get_node("Camera2D")
	camera.force_update_scroll()
	var args = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1] + "-inactive.png")
	scene._resume_checkpoint()
	if not scene.checkpoint_active or not scene.completed[0] or scene.player.current_hp != 3:
		push_error("S05 activation regression")
		quit(1)
		return
	if args.size() == 2 and args[0] == "--capture":
		scene.player.position.x = 2810
		camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1] + "-active.png")
	print("ASSET VISUAL NODE CHECK: PASS")
	scene.free()
	quit(0)
