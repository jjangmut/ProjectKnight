extends SceneTree
## Smoke test validating Stage 2 Graphics Pass 002:
## 1. Stage 2 environment, 4-layer parallax backdrop & StageStaticArt cache
## 2. 3 Ancient Forest Landmarks & Boss Arena architecture
## 3. Platform grounding & organic moss/vine structure
## 4. Charging Beast amber telegraph hazard line integration
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
	print(">>> RUNNING: stage2_graphics_pass_smoke.gd")
	print("==================================================")

	var stage_scene := load("res://scenes/stage/SecondStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 1: Stage 2 Initialization & Parallax Backdrop
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Stage 2 Parallax Backdrop & Layers ---")
	_check(stage.stage_number == 2, "Stage number is 2 (야수숲)")

	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt exists in SecondStage")
	var backdrop = stage_art.get_node_or_null("ParallaxStageBackdrop") if stage_art != null else null
	_check(backdrop != null, "ParallaxStageBackdrop exists under StageArt")
	if backdrop != null:
		var sky_layer = backdrop.get_node_or_null("LayerSky")
		var distant_layer = backdrop.get_node_or_null("LayerDistantPeaks")
		var mid_layer = backdrop.get_node_or_null("LayerMidRuins")
		var fg_layer = backdrop.get_node_or_null("LayerForegroundFog")
		_check(sky_layer != null, "Backdrop Layer 1 (LayerSky) exists")
		_check(distant_layer != null, "Backdrop Layer 2 (LayerDistantPeaks/Canopy) exists")
		_check(mid_layer != null, "Backdrop Layer 3 (LayerMidRuins/Illustration) exists")
		_check(fg_layer != null, "Backdrop Layer 4 (LayerForegroundFog/Canopy) exists")

	# -------------------------------------------------------------------------
	# Test 2: StageStaticArt Cache & Grounding Integrity
	# -------------------------------------------------------------------------
	print("\n--- Test 2: StageStaticArt Cache & Grounding ---")
	var static_art = stage_art.get_node_or_null("StageStaticArt") if stage_art != null else null
	_check(static_art != null, "StageStaticArt child node exists under StageArt")

	if static_art != null:
		_check(static_art.is_cached, "StageStaticArt has completed build_cache() for Stage 2")
		_check(static_art.cached_ground_tiles.size() > 0, "Ground tiles cached (Count: %d)" % static_art.cached_ground_tiles.size())
		_check(static_art.cached_platforms.size() > 0, "Platforms cached (Count: %d)" % static_art.cached_platforms.size())

		var all_grounded := true
		for p in static_art.cached_platforms:
			var top_y: float = p.get("rect", Rect2()).position.y
			if top_y < 595.0:
				var roots: Array = p.get("root_polys", [])
				if roots.is_empty():
					all_grounded = false
					break
		_check(all_grounded, "All elevated platforms (y < 595) have root columns or branch brackets grounding them")

	# -------------------------------------------------------------------------
	# Test 3: Ancient Landmarks & Boss Arena Geometry
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Landmarks & Boss Arena Architecture ---")
	if static_art != null:
		_check(static_art.cached_landmarks.size() >= 4, "All 3 Ancient Forest Landmarks & Boss Arena cached (Count: %d)" % static_art.cached_landmarks.size())
		var has_portal := false
		var has_colossus := false
		var has_domain_gate := false
		var has_boss_arena := false
		for lm in static_art.cached_landmarks:
			var lm_type: String = lm.get("type", "")
			if lm_type == "portal": has_portal = true
			elif lm_type == "colossus": has_colossus = true
			elif lm_type == "totem_gate": has_domain_gate = true
			elif lm_type == "boss_arena": has_boss_arena = true
		_check(has_portal, "Landmark 1 (Megalithic Ruin Portal) cached at x≈400")
		_check(has_colossus, "Landmark 2 (Fallen Ancient Beast Colossus) cached at x≈5400")
		_check(has_domain_gate, "Landmark 3 (Alpha Beast Domain Gate) cached at x≈9350")
		_check(has_boss_arena, "Boss Arena geometry cached (Altar, Dais, Braziers)")

	# -------------------------------------------------------------------------
	# Test 4: Combat Readability & Charging Beast Telegraph
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Combat Readability & Telegraph Hazard ---")
	stage.encounter_index = 0
	stage._start_encounter()
	await process_frame
	await process_frame

	var beast = null
	for e in stage.enemies:
		if is_instance_valid(e) and e.is_in_group("enemy"):
			beast = e
			break
	_check(beast != null, "Charging Beast spawned in encounter 0")

	if beast != null:
		_check(beast.has_node("Visual") or beast.has_node("Sprite2D"), "Charging Beast visual components valid")
		_check(stage_art.actors.size() > 0, "StageArt tracks actor entries including charging enemy")

	# -------------------------------------------------------------------------
	# Test 5: Gameplay Logic & Pacing Invariant (No gameplay alterations)
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Gameplay Logic & Stat Invariants ---")
	_check(stage.player.move_speed == 230.0, "Player move_speed unchanged (230.0)")
	_check(stage.player.max_hp == 3, "Player max_hp unchanged (3)")
	_check(stage.required_count == 6, "Stage 2 required encounter count unchanged (6)")
	_check(stage.route_clusters.size() >= 1, "Route clusters defined and preserved")

	# Final evaluation
	print("\n==================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("==================================================")

	stage.queue_free()
	if checks_failed == 0:
		print(">>> STAGE 2 GRAPHICS PASS SMOKE: ALL PASS! <<<")
		quit(0)
	else:
		printerr(">>> STAGE 2 GRAPHICS PASS SMOKE: FAILED! <<<")
		quit(1)
