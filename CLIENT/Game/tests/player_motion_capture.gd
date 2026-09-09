extends SceneTree
## GPU evidence: atlas fixtures followed by a normal-speed controller-driven sequence.
var observed: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	var p = stage.player
	p.position = Vector2(700, 580)
	await create_timer(0.3).timeout
	var visual = stage.get_node("StageArt")
	var sprite = p.get_node("CharacterArt")
	stage.get_node("HUD/Presentation").intro_remaining = 0
	var output := OS.get_environment("ANIMATION_EVIDENCE")
	if OS.get_environment("MOTION_FIXTURES") == "1":
		p.set_physics_process(false)
		visual.set_process(false)
		for key in ["idle", "run", "jump", "attack", "guard", "hurt", "death"]:
			var count: int = sprite.motions[key].frames.size()
			for index in range(count):
				sprite.flip_h = false
				sprite._apply_motion(key, (index + 0.1) / count)
				await process_frame
				await RenderingServer.frame_post_draw
				var error := root.get_texture().get_image().save_png(output.path_join("%s_%d.png" % [key, index]))
				if error != OK:
					push_error("Capture failed")
					quit(1)
					return
		p.set_physics_process(true)
		visual.set_process(true)
	await process_frame
	await process_frame
	observed.clear()
	await _observe(sprite, 0.9)
	Input.action_press("move_right")
	await _observe(sprite, 0.6)
	Input.action_release("move_right")
	Input.action_press("jump")
	await _observe(sprite, 0.05)
	Input.action_release("jump")
	await _observe(sprite, 0.9)
	Input.action_press("attack")
	await _observe(sprite, 0.05)
	Input.action_release("attack")
	await _observe(sprite, 0.4)
	Input.action_press("guard")
	await _observe(sprite, 0.4)
	p.receive_attack(p.global_position + Vector2(p.facing_direction * 60.0, 0.0))
	await _observe(sprite, 0.1)
	Input.action_release("guard")
	await _observe(sprite, 0.45)
	p.receive_hit()
	await _observe(sprite, 0.6)
	p._die()
	await _observe(sprite, 0.7)
	var complete := true
	for key in ["idle", "run", "jump", "attack", "guard", "hurt", "death"]:
		complete = complete and observed.has(key) and observed[key].size() >= 2
	print("MOTION_LIVE observed=", JSON.stringify(observed), " all_states_multiple_frames=", complete)
	stage.free()
	await process_frame
	quit(0 if complete else 1)

func _observe(sprite: Sprite2D, seconds: float) -> void:
	# At fixed 60 FPS this samples exactly the normal controller/display cadence.
	for tick in range(int(ceil(seconds * 60.0))):
		await process_frame
		var key: String = sprite.motion_name
		if not observed.has(key):
			observed[key] = []
		if not observed[key].has(sprite.motion_frame_index):
			observed[key].append(sprite.motion_frame_index)
