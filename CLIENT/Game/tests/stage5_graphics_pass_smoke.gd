extends SceneTree
## Smoke test validating Stage 5 Graphics Pass 005:
## 1. Stage 5 environment, 4-layer parallax backdrop & StageStaticArt cache
## 2. 3 Silent Citadel Landmarks & Abyssal Arbiter Final Judgment Arena
## 3. Platform grounding & void-anchored black stone pillars / royal arch suspensions
## 4. Mixed enemy encounter & Abyssal Arbiter final boss spawn integration
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
	print(">>> RUNNING: stage5_graphics_pass_smoke.gd")
	print("==================================================")

	var stage_scene := load("res://scenes/stage/FifthStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 1: Stage 5 Initialization & Parallax Backdrop
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Stage 5 Parallax Backdrop & Layers ---")
	_check(stage.stage_number == 5, "Stage number is 5 (침묵의 성채)")

	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt exists in FifthStage")
	var backdrop = stage_art.get_node_or_null("ParallaxStageBackdrop") if stage_art != null else null
	_check(backdrop != null, "ParallaxStageBackdrop exists under StageArt")
	if backdrop != null:
		var sky_layer = backdrop.get_node_or_null("LayerSky")
		var distant_layer = backdrop.get_node_or_null("LayerDistantPeaks")
		var mid_layer = backdrop.get_node_or_null("LayerMidRuins")
		var fg_layer = backdrop.get_node_or_null("LayerForegroundFog")
		_check(sky_layer != null, "Backdrop Layer 1 (LayerSky - Void Fissures & Black Eclipse) exists")
		_check(distant_layer != null, "Backdrop Layer 2 (LayerDistantPeaks - Distant Citadel Spires) exists")
		_check(mid_layer != null, "Backdrop Layer 3 (LayerMidRuins - Modulated Citadel Architecture) exists")
		_check(fg_layer != null, "Backdrop Layer 4 (LayerForegroundFog - Top Black Stone Cornice & Chains) exists")

	# -------------------------------------------------------------------------
	# Test 2: StageStaticArt Cache & Grounding Integrity
	# -------------------------------------------------------------------------
	print("\n--- Test 2: StageStaticArt Cache & Grounding ---")
	var static_art = stage_art.get_node_or_null("StageStaticArt") if stage_art != null else null
	_check(static_art != null, "StageStaticArt child node exists under StageArt")

	if static_art != null:
		_check(static_art.is_cached, "StageStaticArt has completed build_cache() for Stage 5")
		_check(static_art.cached_ground_tiles.size() > 0, "Ground tiles cached (Count: %d)" % static_art.cached_ground_tiles.size())
		_check(static_art.cached_platforms.size() > 0, "Platforms cached (Count: %d)" % static_art.cached_platforms.size())

		var all_grounded := true
		for p in static_art.cached_platforms:
			var points: PackedVector2Array = p.get("points", PackedVector2Array())
			if points.size() >= 2:
				var top_y: float = minf(points[0].y, points[1].y)
				if top_y < 595.0:
					var pillars: Array = p.get("void_pillars", [])
					var arches: Array = p.get("royal_arches", [])
					if pillars.is_empty() and arches.is_empty():
						all_grounded = false
						break
		_check(all_grounded, "All elevated platforms (y < 595) have void pillars or royal arch suspensions grounding them")

	# -------------------------------------------------------------------------
	# Test 3: Landmarks & Boss Arena Geometry
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Landmarks & Boss Arena Architecture ---")
	if static_art != null:
		_check(static_art.cached_landmarks.size() >= 3, "All 3 Landmarks & Boss Arena cached (Count: %d)" % static_art.cached_landmarks.size())
		var has_royal_gate := false
		var has_throne_gallery := false
		var has_judgment_hall := false
		for lm in static_art.cached_landmarks:
			var lm_type: String = lm.get("type", "")
			if lm_type == "silent_royal_gate": has_royal_gate = true
			elif lm_type == "submerged_throne_gallery": has_throne_gallery = true
			elif lm_type == "arbiter_judgment_hall": has_judgment_hall = true
		_check(has_royal_gate, "Landmark 1 (침묵의 왕문 - Silent Royal Gate) cached at x≈400")
		_check(has_throne_gallery, "Landmark 2 (심연에 잠긴 왕좌 회랑 - Submerged Throne Gallery) cached at x≈5600")
		_check(has_judgment_hall, "Landmark 3 (Abyssal Arbiter 최종 심판실 - Final Judgment Hall) cached at x≈10800..12200")

	# -------------------------------------------------------------------------
	# Test 4: Combat Readability & Mixed Enemy / Final Boss Integration
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Combat Readability & Boss Integration ---")
	stage.encounter_index = 0
	stage.player.position = Vector2(stage.ENTRY_X[0] + 50.0, 592)
	stage._start_encounter()
	await process_frame
	await process_frame

	_check(stage.enemies.size() > 0, "Enemy spawned in Encounter 0")
	if stage.enemies.size() > 0:
		var e0 = stage.enemies[0]
		_check(is_instance_valid(e0), "Spawned encounter actor is valid")

	# Test Final Boss Encounter
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1 # Encounter 7
	stage.player.position = Vector2(stage.ENTRY_X[7] + 100.0, 592)
	stage._start_encounter()
	await process_frame
	await process_frame

	_check(stage.enemies.size() > 0, "Boss enemy spawned in Encounter 7")
	if stage.enemies.size() > 0:
		var boss = stage.enemies[0]
		_check(boss is AbyssalArbiter, "Encounter 7 spawned AbyssalArbiter (심연의 심판관)")
		var boss_bar = stage.get_node_or_null("HUD/BossHealthBar")
		_check(boss_bar != null, "BossHealthBar attached to HUD")

	# -------------------------------------------------------------------------
	# Test 5: Gameplay Logic & Stat Invariants
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Gameplay Logic & Stat Invariants ---")
	_check(stage.player.move_speed == 230.0, "Player move_speed unchanged (230.0)")
	_check(stage.player.max_hp == 3, "Player max_hp unchanged (3)")
	_check(stage.required_count == 8, "Stage 5 required encounter count unchanged (8)")
	_check(stage.route_clusters.size() > 0, "Route clusters defined and preserved")
	_check(stage.CHECKPOINT_POSITIONS.size() > 0, "Checkpoints defined and preserved")

	# Verify StageStaticArt does not trigger per-frame redraw leaks
	var initial_redraws: int = int(stage_art.get("redraw_request_count"))
	for i in range(10):
		await process_frame
	_check(int(stage_art.get("redraw_request_count")) == initial_redraws, "StageArt has zero redraws during static state (No redraw regression)")

	print("\n==================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("==================================================")

	if checks_failed == 0:
		print(">>> STAGE 5 GRAPHICS PASS SMOKE: ALL PASS! <<<\n")
		quit(0)
	else:
		printerr(">>> STAGE 5 GRAPHICS PASS SMOKE: FAILED! <<<\n")
		quit(1)
