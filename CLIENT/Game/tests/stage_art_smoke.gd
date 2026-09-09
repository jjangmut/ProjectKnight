extends SceneTree
## Deterministic graphics integration checks, not a substitute for human play review.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var directory := OS.get_environment("STAGE_ART_EVIDENCE")
	if not directory.is_empty():
		check(image.save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)

func _run() -> void:
	var stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	await process_frame
	await process_frame
	var art = stage.get_node("StageArt")
	check(art.installed, "Adapter installed")
	check(art.textures.size() == 8 and art.textures.has("beast") and art.textures.has("golem"), "Eight textures including body variants loaded")
	check(stage.player.has_node("CharacterArt"), "Existing knight retained")
	check(art.get_node("GoalArt").texture != null, "Goal image installed")
	check(stage.get_node("Ground").get_child(0).shape.size == Vector2(stage.WORLD_WIDTH, 80), "Ground collision spans configured expanded world")
	stage.player.position = Vector2(650, 592)
	stage._spawn(stage.MELEE, 820)
	stage._spawn(stage.RANGED, 990)
	for enemy in stage.enemies:
		enemy.set_physics_process(false)
	await process_frame
	await process_frame
	var melee = stage.enemies[0]
	var ranged = stage.enemies[1]
	melee.set_physics_process(false)
	ranged.set_physics_process(false)
	melee.position.y = 590
	ranged.position.y = 590
	check(melee.has_node("BatchArt") and ranged.has_node("BatchArt"), "Both spawned actors decorated")
	check(not melee.visual.visible and not ranged.visual.visible, "Fallback polygons hidden")
	check(melee.get_node("CollisionShape2D").shape.size == Vector2(44, 60), "Melee collider unchanged")
	check(ranged.get_node("CollisionShape2D").shape.size == Vector2(44, 60), "Ranged collider unchanged")
	for actor in [melee, ranged]:
		var sprite: Sprite2D = actor.get_node("BatchArt")
		var key := "melee" if actor == melee else "ranged"
		var spec: Dictionary = art.enemy_motions[key]
		check(sprite.texture == spec.frames[0] and sprite.scale == Vector2.ONE * float(spec.scale), key + " idle frame and display scale match manifest")
		check(sprite.position + (sprite.offset + Vector2(spec.pivots[0][0], spec.pivots[0][1])) * sprite.scale == Vector2(0, 30), key + " idle foot remains at controller baseline")
	melee.velocity.x = -30
	await process_frame
	await process_frame
	check(melee.get_node("BatchArt").flip_h, "Melee turns left")
	melee.velocity.x = 30
	await process_frame
	await process_frame
	check(not melee.get_node("BatchArt").flip_h, "Melee turns right")
	await _capture("combat_idle")
	melee._begin_attack(-1)
	ranged._begin_attack()
	await process_frame
	await process_frame
	check(melee.get_node("ArtFeedback").text == "!", "Melee windup symbol visible")
	check(ranged.get_node("ArtFeedback").text == "!", "Ranged windup symbol visible")
	await _capture("combat_windup")
	melee._update_attack(melee.attack_windup + 0.01)
	await process_frame
	await process_frame
	check(melee.is_attack_active and melee.get_node("ArtFeedback").text == "!", "Active attack symbol visible")
	var hp: int = melee.current_hp
	melee.receive_hit()
	await process_frame
	await process_frame
	check(melee.current_hp == hp - 1, "Existing damage retained")
	check(melee.get_node("BatchArt").self_modulate.is_equal_approx(Color.WHITE), "Hit flash remains visible without debug text")
	await _capture("combat_hit")
	var shot = load("res://scenes/projectile/EnemyProjectile.tscn").instantiate()
	stage.add_child(shot)
	shot.position = Vector2(740, 590)
	shot.configure(-1)
	shot.set_physics_process(false)
	await process_frame
	await process_frame
	check(shot.has_node("BatchArt"), "Projectile decorated")
	check(shot.get_node("BatchArt").flip_h, "Projectile left direction")
	shot.configure(1)
	await process_frame
	await process_frame
	check(not shot.get_node("BatchArt").flip_h, "Projectile right direction")
	check(shot.get_node("CollisionShape2D").shape.size == Vector2(28, 12), "Projectile collider unchanged")
	await _capture("projectile")
	shot.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(shot), "Projectile visual freed with actor")
	stage.player.position = Vector2(2950, 592)
	stage.player.get_node("Camera2D").reset_smoothing()
	await process_frame
	await _capture("checkpoint")
	stage.player.position = Vector2(6200, 592)
	stage.player.get_node("Camera2D").reset_smoothing()
	await process_frame
	await _capture("goal")
	# Visual state poses read existing controller state; snapshots must not mutate it.
	stage.player.position = Vector2(650, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	var player = stage.player
	var original_collision: Vector2 = player.get_node("CollisionShape2D").shape.size
	var original_speed: float = player.move_speed
	player._start_attack()
	await process_frame
	await process_frame
	check(art.player_pose == "attack", "Player attack pose follows controller")
	check(player.is_attacking and player.attack_visual.visible, "Attack state/visibility retained")
	check(is_zero_approx(player.attack_visual.self_modulate.a), "Opaque attack placeholder replaced visually")
	await _capture("player_attack")
	player._end_attack()
	# Explicit visual fixture; actual ground/input guard legality tested separately.
	player.is_guarding = true
	player._guard_direction = -1.0
	player._guard_elapsed = 0.4
	await process_frame
	await process_frame
	check(art.player_pose == "guard", "Player guard pose follows controller")
	check(player.get_node("CharacterArt").motion_name == "guard" and player.get_node("CharacterArt").rotation == 0.0, "Guard uses drawn frames without procedural deformation")
	check(player.get_node("CollisionShape2D").shape.size == original_collision, "Guard pose cannot change collider")
	await _capture("player_guard")
	player._end_guard()
	player._guard_recovery_remaining = 0.0
	player.receive_hit()
	await process_frame
	await process_frame
	check(art.player_pose == "hit", "Hit differs from guard")
	await _capture("player_hit")
	player._update_hurt_flash(1.0)
	player.velocity.y = -100.0
	await process_frame
	await process_frame
	check(art.player_pose == "rise", "Rising pose read-only")
	player.velocity.y = 100.0
	await process_frame
	await process_frame
	check(art.player_pose == "fall", "Falling pose read-only")
	check(player.get_node("CharacterArt").motion_name == "jump" and player.get_node("CharacterArt").scale == Vector2.ONE * float(player.get_node("CharacterArt").motions.jump.scale), "Jump restores its contracted scale after guard")
	player._die()
	await process_frame
	await process_frame
	check(art.player_pose == "dead", "Death has precedence over other poses")
	check(player.move_speed == original_speed, "Controller tuning untouched")
	await _capture("player_dead")
	stage.free()
	await process_frame
	print("STAGE_ART_SMOKE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
