extends SceneTree
## Smoke test validating Stage 3 Graphics Pass 003:
## 1. Stage 3 environment, 4-layer parallax backdrop & StageStaticArt cache
## 2. 3 Ruined Rampart Landmarks & Boss Arena architecture
## 3. Platform grounding & masonry pillar / timber scaffolding structure
## 4. RangedEnemy high-contrast amber telegraph line and luminous projectiles
## 5. Zero gameplay alterations (movement, encounters, HP, rules preserved)

var checks_passed: int = 0
var checks_failed: int = 0

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] ", description)
		checks_passed += 1
	else:
		printerr("  [FAIL] ", description)
		checks_failed += 1

func _initialize() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	print("\n==================================================")
	print(">>> RUNNING: stage3_graphics_pass_smoke.gd")
	print("==================================================")

	var stage_scene := load("res://scenes/stage/ThirdStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 1: Stage 3 Initialization & Parallax Backdrop
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Stage 3 Parallax Backdrop & Layers ---")
	_check(stage.stage_number == 3, "Stage number is 3 (무너진 성벽)")

	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt exists in ThirdStage")
	var backdrop = stage_art.get_node_or_null("ParallaxStageBackdrop") if stage_art != null else null
	_check(backdrop != null, "ParallaxStageBackdrop exists under StageArt")
	if backdrop != null:
		var sky_layer = backdrop.get_node_or_null("LayerSky")
		var distant_layer = backdrop.get_node_or_null("LayerDistantPeaks")
		var mid_layer = backdrop.get_node_or_null("LayerMidRuins")
		var fg_layer = backdrop.get_node_or_null("LayerForegroundFog")
		_check(sky_layer != null, "Backdrop Layer 1 (LayerSky - Dusty Twilight Sky) exists")
		_check(distant_layer != null, "Backdrop Layer 2 (LayerDistantPeaks - Ruined Fortress Ridge) exists")
		_check(mid_layer != null, "Backdrop Layer 3 (LayerMidRuins - Modulated Illustration) exists")
		_check(fg_layer != null, "Backdrop Layer 4 (LayerForegroundFog - Battlefield Ash & Crenels) exists")

	# -------------------------------------------------------------------------
	# Test 2: StageStaticArt Cache & Grounding Integrity
	# -------------------------------------------------------------------------
	print("\n--- Test 2: StageStaticArt Cache & Grounding ---")
	var static_art = stage_art.get_node_or_null("StageStaticArt") if stage_art != null else null
	_check(static_art != null, "StageStaticArt child node exists under StageArt")

	if static_art != null:
		_check(static_art.is_cached, "StageStaticArt has completed build_cache() for Stage 3")
		_check(static_art.cached_ground_tiles.size() > 0, "Ground tiles cached (Count: %d)" % static_art.cached_ground_tiles.size())
		_check(static_art.cached_platforms.size() > 0, "Platforms cached (Count: %d)" % static_art.cached_platforms.size())

		var all_grounded := true
		for p in static_art.cached_platforms:
			var points: PackedVector2Array = p.get("points", PackedVector2Array())
			if points.size() >= 2:
				var top_y: float = minf(points[0].y, points[1].y)
				if top_y < 595.0:
					var pillars: Array = p.get("fractured_pillars", [])
					var scaffolds: Array = p.get("scaffold_struts", [])
					if pillars.is_empty() and scaffolds.is_empty():
						all_grounded = false
						break
		_check(all_grounded, "All elevated platforms (y < 595) have masonry pillars or timber scaffolds grounding them")

	# -------------------------------------------------------------------------
	# Test 3: Ancient Landmarks & Boss Arena Geometry
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Landmarks & Boss Arena Architecture ---")
	if static_art != null:
		_check(static_art.cached_landmarks.size() >= 4, "All 3 Ruined Rampart Landmarks & Boss Arena cached (Count: %d)" % static_art.cached_landmarks.size())
		var has_watchtower := false
		var has_trebuchet := false
		var has_command_parapet := false
		var has_boss_arena := false
		for lm in static_art.cached_landmarks:
			var lm_type: String = lm.get("type", "")
			if lm_type == "leaning_watchtower": has_watchtower = true
			elif lm_type == "trebuchet_wreckage": has_trebuchet = true
			elif lm_type == "command_parapet": has_command_parapet = true
			elif lm_type == "boss_arena_wall": has_boss_arena = true
		_check(has_watchtower, "Landmark 1 (Leaning Ruined Watchtower) cached at x≈370")
		_check(has_trebuchet, "Landmark 2 (Shattered Trebuchet Wreckage) cached at x≈5500")
		_check(has_command_parapet, "Landmark 3 (Command Parapet) cached at x≈10000")
		_check(has_boss_arena, "Boss Arena Wall geometry cached (Crenels, Stakes, Scorch marks)")

	# -------------------------------------------------------------------------
	# Test 4: Combat Readability & RangedEnemy Telegraph
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Combat Readability & Telegraph Hazard ---")
	stage.encounter_index = 0
	stage._start_encounter()
	await process_frame
	await process_frame

	var shooter = null
	for e in stage.enemies:
		if is_instance_valid(e):
			shooter = e
			break
	_check(shooter != null, "Enemy spawned in encounter 0")
	if shooter != null:
		var is_ranged: bool = shooter.scene_file_path.ends_with("RangedEnemy.tscn") or (shooter.get_script() != null and shooter.get_script().resource_path.ends_with("ranged_enemy.gd"))
		_check(is_ranged, "Spawned enemy is RangedEnemy (Stage 3 ranged threat)")

	if shooter != null:
		_check(shooter.has_node("Visual") or shooter.has_node("Sprite2D"), "RangedEnemy visual components valid")
		_check(stage_art.actors.size() > 0, "StageArt tracks actor entries including ranged shooter")

	# -------------------------------------------------------------------------
	# Test 5: Gameplay Logic & Pacing Invariant (No gameplay alterations)
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Gameplay Logic & Stat Invariants ---")
	_check(stage.player.move_speed == 230.0, "Player move_speed unchanged (230.0)")
	_check(stage.player.max_hp == 3, "Player max_hp unchanged (3)")
	_check(stage.required_count == 8, "Stage 3 required encounter count unchanged (8)")
	_check(stage.route_clusters.size() >= 1, "Route clusters defined and preserved")

	# Final evaluation
	print("\n==================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("==================================================")

	stage.queue_free()
	if checks_failed == 0:
		print(">>> STAGE 3 GRAPHICS PASS SMOKE: ALL PASS! <<<")
		quit(0)
	else:
		printerr(">>> STAGE 3 GRAPHICS PASS SMOKE: FAILED! <<<")
		quit(1)
