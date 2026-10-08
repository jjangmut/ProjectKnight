extends SceneTree

var checks_passed: int = 0
var checks_failed: int = 0

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] %s" % description)
		checks_passed += 1
	else:
		printerr("  [FAIL] %s" % description)
		checks_failed += 1

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n==================================================")
	print(">>> RUNNING: character_shadow_behavior_smoke.gd")
	print("==================================================")

	var stage_scene: PackedScene = load("res://scenes/stage/SecondStage.tscn")
	if stage_scene == null:
		printerr("FATAL: SecondStage.tscn failed to load")
		quit(1)
		return

	var stage = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt exists in SecondStage")
	var player = stage.player
	_check(player != null, "Player exists in SecondStage")

	print("\n--- Test 1: Player Ground Shadow Initialization & Properties ---")
	var hero_shadow = player.get_node_or_null("HeroShadow")
	_check(hero_shadow != null, "HeroShadow node exists on Player")
	_check(hero_shadow is Polygon2D, "HeroShadow is Polygon2D")
	_check(hero_shadow.z_index == 1, "HeroShadow z_index is 1 (above ground, below actors)")
	_check(hero_shadow.z_as_relative == false, "HeroShadow z_as_relative is false (absolute layer 1)")
	var hero_core = hero_shadow.get_node_or_null("Core")
	_check(hero_core != null, "HeroShadow has soft penumbra Core child polygon")

	print("\n--- Test 2: Ground Contact Alignment (Standing) ---")
	# Let player settle on the ground
	for i in range(10):
		await physics_frame
	await process_frame

	_check(player.is_on_floor(), "Player is on the floor")
	var foot_offset: float = stage_art._get_actor_foot_offset(player)
	_check(is_equal_approx(foot_offset, 28.0), "Player foot offset is 28.0px (half height of 56px)")
	var world_shadow_y: float = hero_shadow.global_position.y
	_check(is_equal_approx(world_shadow_y, 620.0), "Player shadow is on ground surface Y=620.0 (Actual: %.1f)" % world_shadow_y)
	_check(is_equal_approx(hero_shadow.scale.x, 1.0), "Player shadow scale is 1.0 when grounded")

	print("\n--- Test 3: Airborne Ground Projection (Jumping) ---")
	# Make player jump 120px into the air
	player.global_position.y = 500.0
	player.velocity = Vector2.ZERO
	await physics_frame
	stage_art._process(0.016)

	_check(player.global_position.y < 590.0, "Player is airborne in the air (Y=%.1f)" % player.global_position.y)
	var airborne_shadow_y: float = hero_shadow.global_position.y
	_check(is_equal_approx(airborne_shadow_y, 620.0), "Airborne player shadow STAYS on ground Y=620.0 while player is at Y=500.0 (Actual: %.1f)" % airborne_shadow_y)
	_check(hero_shadow.scale.x < 0.95, "Shadow scale shrunk with altitude (Scale: %.2f < 0.95)" % hero_shadow.scale.x)
	_check(hero_shadow.color.a < 0.38, "Shadow alpha faded with altitude (Alpha: %.2f < 0.38)" % hero_shadow.color.a)

	print("\n--- Test 4: Boss Ground Shadow & No Duplicate Nodes ---")
	stage._spawn_boss_encounter()
	await process_frame
	await process_frame

	var boss = stage.enemies.back()
	_check(boss != null and boss.is_in_group("boss"), "Boss instantiated in encounter")
	var boss_local_shadow = boss.get_node_or_null("Visuals/GroundShadow")
	_check(boss_local_shadow == null, "Duplicate local GroundShadow in boss Visuals is REMOVED")
	var boss_enemy_shadow = boss.get_node_or_null("EnemyShadow")
	_check(boss_enemy_shadow != null, "Unified EnemyShadow attached to Boss")
	_check(boss_enemy_shadow.z_index == 1, "Boss EnemyShadow z_index is 1")
	_check(boss_enemy_shadow.z_as_relative == false, "Boss EnemyShadow z_as_relative is false")

	print("\n--- Test 5: Boss Facing Direction Flip Stability ---")
	boss.facing_direction = -1.0
	boss.get_node("Visuals").scale.x = -1.0
	stage_art._process(0.016)
	_check(boss_enemy_shadow.scale.x > 0.0, "Boss shadow scale.x remains positive when boss faces left (Actual: %.2f)" % boss_enemy_shadow.scale.x)
	_check(boss_enemy_shadow.position.x == 0.0, "Boss shadow has zero horizontal drift upon facing flip")

	print("\n--- Test 6: Boss Airborne Leap Ground Projection ---")
	boss.global_position.y = 480.0
	stage_art._process(0.016)
	var boss_airborne_shadow_y: float = boss_enemy_shadow.global_position.y
	_check(is_equal_approx(boss_airborne_shadow_y, 620.0), "Airborne boss shadow STAYS on ground Y=620.0 while boss leaps to Y=480.0 (Actual: %.1f)" % boss_airborne_shadow_y)
	_check(boss_enemy_shadow.scale.x < 0.95, "Boss shadow scale shrunk during airborne leap")

	print("\n--- Test 7: Dead Actor Shadow Suppression ---")
	boss.is_dead = true
	stage_art._process(0.016)
	_check(boss_enemy_shadow.visible == false, "Boss shadow is hidden when boss is defeated/dead")

	print("\n==================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("==================================================")

	stage.queue_free()
	if checks_failed == 0:
		print(">>> CHARACTER SHADOW BEHAVIOR SMOKE: ALL PASS! <<<\n")
		quit(0)
	else:
		printerr(">>> CHARACTER SHADOW BEHAVIOR SMOKE: FAILED! <<<\n")
		quit(1)
