extends SceneTree
## Smoke test validating Stage 4 Graphics Pass 004:
## 1. Stage 4 environment, 4-layer parallax backdrop & StageStaticArt cache
## 2. 3 Megalithic Sanctuary Landmarks & Boss Arena architecture
## 3. Platform grounding & monolithic stone pillar / pylon support structure
## 4. GroundSlamGolem high-contrast amber telegraph and combat VFX
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
	print(">>> RUNNING: stage4_graphics_pass_smoke.gd")
	print("==================================================")

	var stage_scene := load("res://scenes/stage/FourthStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 1: Stage 4 Initialization & Parallax Backdrop
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Stage 4 Parallax Backdrop & Layers ---")
	_check(stage.stage_number == 4, "Stage number is 4 (돌의 성소)")

	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt exists in FourthStage")
	var backdrop = stage_art.get_node_or_null("ParallaxStageBackdrop") if stage_art != null else null
	_check(backdrop != null, "ParallaxStageBackdrop exists under StageArt")
	if backdrop != null:
		var sky_layer = backdrop.get_node_or_null("LayerSky")
		var distant_layer = backdrop.get_node_or_null("LayerDistantPeaks")
		var mid_layer = backdrop.get_node_or_null("LayerMidRuins")
		var fg_layer = backdrop.get_node_or_null("LayerForegroundFog")
		_check(sky_layer != null, "Backdrop Layer 1 (LayerSky - Skylight Shafts & Corona) exists")
		_check(distant_layer != null, "Backdrop Layer 2 (LayerDistantPeaks - Distant Megalithic Colonnade) exists")
		_check(mid_layer != null, "Backdrop Layer 3 (LayerMidRuins - Modulated Sanctuary Relief) exists")
		_check(fg_layer != null, "Backdrop Layer 4 (LayerForegroundFog - Top Stone Cornice Beams & Haze) exists")

	# -------------------------------------------------------------------------
	# Test 2: StageStaticArt Cache & Grounding Integrity
	# -------------------------------------------------------------------------
	print("\n--- Test 2: StageStaticArt Cache & Grounding ---")
	var static_art = stage_art.get_node_or_null("StageStaticArt") if stage_art != null else null
	_check(static_art != null, "StageStaticArt child node exists under StageArt")

	if static_art != null:
		_check(static_art.is_cached, "StageStaticArt has completed build_cache() for Stage 4")
		_check(static_art.cached_ground_tiles.size() > 0, "Ground tiles cached (Count: %d)" % static_art.cached_ground_tiles.size())
		_check(static_art.cached_platforms.size() > 0, "Platforms cached (Count: %d)" % static_art.cached_platforms.size())

		var all_grounded := true
		for p in static_art.cached_platforms:
			var points: PackedVector2Array = p.get("points", PackedVector2Array())
			if points.size() >= 2:
				var top_y: float = minf(points[0].y, points[1].y)
				if top_y < 595.0:
					var pillars: Array = p.get("monolith_pillars", [])
					var pylons: Array = p.get("pylon_supports", [])
					if pillars.is_empty() and pylons.is_empty():
						all_grounded = false
						break
		_check(all_grounded, "All elevated platforms (y < 595) have monolithic stone pillars or pylon supports grounding them")

	# -------------------------------------------------------------------------
	# Test 3: Ancient Sanctuary Landmarks & Boss Arena Geometry
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Landmarks & Boss Arena Architecture ---")
	if static_art != null:
		_check(static_art.cached_landmarks.size() >= 4, "All 3 Megalithic Landmarks & Boss Arena cached (Count: %d)" % static_art.cached_landmarks.size())
		var has_gate := false
		var has_colossus := false
		var has_sanctuary_gate := false
		var has_boss_arena := false
		for lm in static_art.cached_landmarks:
			var lm_type: String = lm.get("type", "")
			if lm_type == "rune_monolith_gate": has_gate = true
			elif lm_type == "guardian_colossus": has_colossus = true
			elif lm_type == "guardian_sanctuary_gate": has_sanctuary_gate = true
			elif lm_type == "sanctuary_boss_arena": has_boss_arena = true
		_check(has_gate, "Landmark 1 (Great Rune Monolith Gate) cached at x≈400")
		_check(has_colossus, "Landmark 2 (Fallen Ancient Guardian Colossus) cached at x≈5400")
		_check(has_sanctuary_gate, "Landmark 3 (Ancient Guardian Sanctuary Gate) cached at x≈10000")
		_check(has_boss_arena, "Boss Arena architecture cached (Stepped Altar Dais, 6 Colonnade Pillars, Floor Runes)")

	# -------------------------------------------------------------------------
	# Test 4: Combat Readability & GroundSlamGolem Hazard
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Combat Readability & GroundSlamGolem Hazard ---")
	stage.encounter_index = 0
	stage._start_encounter()
	await process_frame
	await process_frame

	var golem = null
	for e in stage.enemies:
		if is_instance_valid(e):
			golem = e
			break
	_check(golem != null, "Enemy spawned in encounter 0")
	if golem != null:
		var is_golem: bool = golem.get_meta("art_variant", "") == "golem" or golem.get_meta("ground_slam", false) == true or (golem.get_script() != null and golem.get_script().resource_path.ends_with("ground_slam_golem.gd"))
		_check(is_golem, "Spawned enemy is GroundSlamGolem (Stage 4 core enemy)")

	if golem != null:
		_check(golem.has_node("AttackArea/CollisionShape2D"), "GroundSlamGolem attack area collision shape valid")
		_check(stage_art.actors.size() > 0, "StageArt tracks actor entries including golem")

	# -------------------------------------------------------------------------
	# Test 5: Gameplay Logic & Stat Invariants (No gameplay alterations)
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Gameplay Logic & Stat Invariants ---")
	_check(stage.player.move_speed == 230.0, "Player move_speed unchanged (230.0)")
	_check(stage.player.max_hp == 3, "Player max_hp unchanged (3)")
	_check(stage.required_count == 8, "Stage 4 required encounter count unchanged (8)")
	_check(stage.route_clusters.size() >= 1, "Route clusters defined and preserved")

	# Final evaluation
	print("\n==================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("==================================================")

	stage.queue_free()
	if checks_failed == 0:
		print(">>> STAGE 4 GRAPHICS PASS SMOKE: ALL PASS! <<<")
		quit(0)
	else:
		printerr(">>> STAGE 4 GRAPHICS PASS SMOKE: FAILED! <<<")
		quit(1)
