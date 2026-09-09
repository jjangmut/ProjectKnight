extends SceneTree
## Fixed state fixtures; PNGs do not establish real-time animation quality.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func capture(label: String) -> void:
	var output := OS.get_environment("CAMPAIGN_EVIDENCE")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("enemy_fixture_" + label + ".png")) == OK, "Saved " + label)

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemy_frames/enemy_motion_manifest.json"))
	var stage = load("res://scenes/stage/SecondStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.player.position = Vector2(650, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await process_frame
	var art = stage.get_node("StageArt")
	check(art.enemy_motions.size() == 4, "All four enemy sheets loaded")
	check(art.background.texture.resource_path == "res://assets/stage_two/background_v1.png", "Stage two background selected")
	for variant in ["melee", "ranged", "beast", "golem"]:
		var path := "res://scenes/enemy/RangedEnemy.tscn" if variant == "ranged" else "res://scenes/enemy/ChargingBeast.tscn" if variant == "beast" else "res://scenes/enemy/TestEnemy.tscn"
		var actor = load(path).instantiate()
		actor.set_meta("art_variant", variant)
		stage.add_child(actor)
		actor.position = Vector2(800, 590)
		actor.set_physics_process(false)
		await process_frame
		await process_frame
		var entry: Dictionary = {}
		for candidate in art.actors:
			if candidate.actor == actor:
				entry = candidate
		check(not entry.is_empty(), variant + " attached")
		if entry.is_empty():
			actor.free()
			continue
		for index in range(6):
			if index < 3:
				actor.state = 0
				actor.velocity.x = 0 if index == 0 else 30
				entry.distance = 0.0 if index < 2 else 18.0
				entry.last_x = actor.global_position.x
			elif index == 3:
				if variant == "ranged":
					actor._begin_attack()
				else:
					actor._begin_attack(1)
			elif index == 4:
				actor._update_attack(actor.attack_windup + 0.001)
			else:
				actor._update_attack(0.13 if variant == "ranged" else actor.attack_active + 0.001)
			art._update_actor(entry)
			check(entry.frame_index == index, "%s AI frame %d" % [variant, index])
			var sprite: Sprite2D = entry.sprite
			var spec: Dictionary = manifest[variant]
			var pivot := Vector2(spec.pivots[index][0], spec.pivots[index][1])
			var visual_pivot := Vector2(sprite.texture.get_width() - pivot.x if sprite.flip_h else pivot.x, pivot.y)
			check(sprite.position + (sprite.offset + visual_pivot) * sprite.scale == Vector2(0, 30), "%s frame %d foot anchor" % [variant, index])
			check(is_equal_approx(sprite.scale.x, float(spec.scale)) and sprite.rotation == 0, "%s frame scale and no duplicate rotation" % variant)
			check(sprite.texture.get_height() * sprite.scale.y >= float(entry.height) * 0.9 and sprite.texture.get_height() * sprite.scale.y < float(entry.height) * 1.9, "%s padded frame height within display envelope" % variant)
			if spec.has("regions"):
				var region: Array = spec.regions[index]
				check(sprite.texture.region == Rect2(region[0], region[1], region[2], region[3]), variant + " explicit region respected")
			art.queue_redraw()
			await capture("%s_%d" % [variant, index])
		# Facing reversal must keep the same foot point in actor coordinates.
		actor.state = 0
		actor.velocity.x = -30
		art._update_actor(entry)
		var sprite: Sprite2D = entry.sprite
		var pivot_data: Array = manifest[variant].pivots[entry.frame_index]
		var mirrored := Vector2(sprite.texture.get_width() - pivot_data[0], pivot_data[1])
		check(sprite.flip_h and sprite.position + (sprite.offset + mirrored) * sprite.scale == Vector2(0, 30), variant + " mirrored foot anchor")
		var previous: float = entry.distance
		paused = true
		await process_frame
		await process_frame
		check(is_equal_approx(entry.distance, previous), variant + " gait pauses")
		paused = false
		if variant == "beast":
			actor._begin_attack(-1)
			art._update_actor(entry)
			check(entry.charging and actor._attack_direction == -1 and entry.sprite.flip_h and entry.frame_index == 3, "Charge cue uses committed windup direction")
			check(actor.charge_speed * actor.attack_active > 0 and not actor.is_attack_active, "Charge preview distance does not activate damage")
		actor.free()
		await process_frame
	stage.free()
	await process_frame
	print("ENEMY_MOTION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
