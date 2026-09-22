extends SceneTree
## Deterministic frame contracts plus grounded physics setup; GPU review is separate.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	var p = stage.player
	p.position = Vector2(200, 580)
	await create_timer(0.3).timeout
	p.set_physics_process(false)
	var visual = stage.get_node("StageArt")
	visual.set_process(false)
	var sprite = p.get_node("CharacterArt")
	check(p.is_on_floor(), "Real physics establishes grounded locomotion fixture")
	var expected := {"idle": 4, "run": 6, "jump": 3, "attack": 4, "guard": 3, "hurt": 3, "death": 4}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/player_frames/motion_manifest.json"))
	for key in expected:
		check(sprite.motions.has(key), "Required motion loaded: " + key)
		if not sprite.motions.has(key):
			continue
		var spec: Dictionary = sprite.motions[key]
		check(spec.frames.size() == expected[key] and spec.pivots.size() == expected[key], "Complete frames/pivots: " + key)
		var source: Dictionary = manifest[key]
		for index in range(spec.frames.size()):
			var cell: AtlasTexture = spec.frames[index]
			var expected_region: Rect2
			if source.has("regions"):
				var rect: Array = source.regions[index]
				expected_region = Rect2(rect[0], rect[1], rect[2], rect[3])
			else:
				var size := Vector2(cell.atlas.get_width() / float(source.columns), cell.atlas.get_height() / float(source.rows))
				expected_region = Rect2(Vector2(index % int(source.columns), floori(index / float(source.columns))) * size, size)
			check(cell.region == expected_region, "Explicit region or grid contract: %s %d" % [key, index])
			check(Rect2(Vector2.ZERO, cell.atlas.get_size()).encloses(cell.region), "Frame region fits source sheet: " + key)
		for direction in [1, -1]:
			sprite.flip_h = direction < 0
			for index in range(expected[key]):
				sprite._apply_motion(key, (index + 0.1) / expected[key])
				check(sprite.motion_frame_index == index and sprite.texture == spec.frames[index], "Atlas selection: %s %d" % [key, index])
				var pivot: Vector2 = spec.pivots[index]
				var mirrored_x: float = sprite.texture.get_width() - pivot.x if direction < 0 else pivot.x
				check((sprite.offset + Vector2(mirrored_x, pivot.y)).is_zero_approx(), "Mirrored foot pivot remains stationary: " + key)
				check(sprite.rotation == 0 and sprite.scale == Vector2.ONE * float(spec.scale), "No duplicate procedural transform: " + key)
	if failures:
		stage.free()
		print("PLAYER_MOTION checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	p.velocity = Vector2.ZERO
	sprite.idle_time = 0.0
	visual._update_player_pose(0.0)
	check(sprite.motion_name == "idle" and sprite.motion_frame_index == 0, "Grounded rest selects idle")
	visual._update_player_pose(0.41)
	check(sprite.motion_frame_index == 2, "Idle advances by presentation time")
	p.velocity.x = 100
	sprite.run_distance = 0.0
	sprite.previous_position = p.global_position
	p.position.x += 17
	visual._update_player_pose(0.01)
	check(sprite.motion_name == "run" and sprite.motion_frame_index == 1, "Run gait advances by actual ground displacement")
	visual._update_player_pose(1.0)
	check(sprite.motion_frame_index == 1, "Render time without travel cannot slide run gait")
	p.position.x += 300
	visual._update_player_pose(0.01)
	check(sprite.motion_frame_index == 1, "Checkpoint teleport cannot advance gait")
	p.velocity = Vector2.ZERO
	p._start_attack()
	p._update_attack_state(p.attack_duration * 0.55)
	visual._update_player_pose(0.0)
	check(sprite.motion_name == "attack" and sprite.motion_frame_index == 2, "Physics attack timer selects middle frame")
	var remaining: float = p._attack_time_remaining
	visual._update_player_pose(10.0)
	check(sprite.motion_frame_index == 2 and p._attack_time_remaining == remaining, "Rendering cannot consume attack timer")
	p._end_attack()
	visual._update_player_pose()
	check(sprite.motion_name == "idle", "Attack completion restores grounded idle")
	p._cooldown_time_remaining = 0.0
	p.facing_direction = -1
	Input.action_press("guard")
	p._start_guard()
	p.facing_direction = 1
	p._update_guard_state(0.44)
	visual._update_player_pose()
	check(sprite.motion_name == "guard" and sprite.motion_frame_index == 1 and sprite.flip_h, "Guard holds raised sword using locked direction")
	p._guard_block_flash_remaining = 0.14
	visual._update_player_pose()
	check(sprite.motion_name == "guard" and sprite.motion_frame_index == 2, "Blocked hit selects guard contact pose")
	p._guard_block_flash_remaining = 0.0
	p._end_guard()
	Input.action_release("guard")
	p._guard_recovery_remaining = 0.0
	p._start_attack()
	p._hurt_flash_remaining = 0.12
	visual._update_player_pose()
	check(sprite.motion_name == "hurt" and sprite.motion_frame_index == 0, "Hurt overrides ongoing attack")
	p._update_hurt_flash(0.09)
	visual._update_player_pose()
	check(sprite.motion_frame_index == 2, "Hurt recovery follows controller timer")
	p._update_hurt_flash(0.1)
	visual._update_player_pose()
	check(sprite.motion_name == "attack", "Hurt end restores still-active controller attack")
	p._end_attack()
	p.velocity = Vector2.ZERO
	visual._update_player_pose()
	var frozen_frame: int = sprite.motion_frame_index
	var frozen_time: float = sprite.idle_time
	paused = true
	visual._update_player_pose(2.0)
	check(sprite.motion_frame_index == frozen_frame and sprite.idle_time == frozen_time, "Pause freezes idle presentation clock")
	paused = false
	# Leave the floor through real physics, then freeze for deterministic vertical fixtures.
	p.position.y = 300
	p.velocity = Vector2.ZERO
	p.set_physics_process(true)
	await physics_frame
	await physics_frame
	p.set_physics_process(false)
	check(not p.is_on_floor(), "Real physics establishes airborne fixture")
	for fixture in [[-150.0, 0], [0.0, 1], [150.0, 2]]:
		p.velocity.y = fixture[0]
		visual._update_player_pose()
		check(sprite.motion_name == "jump" and sprite.motion_frame_index == fixture[1], "Jump rise/apex/fall selected from velocity")
	p._die()
	visual._update_player_pose()
	check(sprite.motion_name == "death" and sprite.motion_frame_index == 0, "Death starts at first frame")
	visual._update_player_pose(0.25)
	check(sprite.motion_frame_index == 2, "Death advances through sequence")
	paused = true
	visual._update_player_pose(1.0)
	check(sprite.motion_frame_index == 2, "Pause freezes death sequence")
	paused = false
	visual._update_player_pose(1.0)
	check(sprite.motion_frame_index == 3, "Death reaches final frame")
	visual._update_player_pose(10.0)
	check(sprite.motion_frame_index == 3 and p.is_dead, "Death holds final frame without looping or reviving")
	check(p.max_hp == 3 and p.move_speed == 230 and p.attack_duration == 0.18, "Core combat tuning retained")
	stage.free()
	await process_frame
	print("PLAYER_MOTION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
