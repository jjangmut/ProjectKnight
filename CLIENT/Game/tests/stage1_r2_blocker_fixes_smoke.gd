extends SceneTree
## Smoke test validating R2 blocker fixes:
## 1. StageStaticArt cache & static/dynamic render separation
## 2. Optional encounter gameplay state preservation on boss encounter spawn
## 3. Boss telegraph calibrated HDR values

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
	print(">>> RUNNING: stage1_r2_blocker_fixes_smoke.gd")
	print("==================================================")

	var stage_scene := load("res://scenes/stage/FirstStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# Test 1: StageStaticArt Cache & Static/Dynamic Render Separation
	# -------------------------------------------------------------------------
	print("\n--- Test 1: StageStaticArt Cache & Render Separation ---")
	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt exists in FirstStage")

	var static_art = stage_art.get_node_or_null("StageStaticArt") if stage_art != null else null
	_check(static_art != null, "StageStaticArt child node exists under StageArt")

	if static_art != null:
		_check(static_art.is_cached, "StageStaticArt has completed build_cache()")
		_check(static_art.cached_ground_tiles.size() > 0, "Ground tiles precomputed in cache (Count: %d)" % static_art.cached_ground_tiles.size())
		_check(static_art.cached_platforms.size() > 0, "Platform geometries & corbels precomputed in cache (Count: %d)" % static_art.cached_platforms.size())
		_check(static_art.cached_route_signs.size() > 0, "Route choice plaques precomputed in cache (Count: %d)" % static_art.cached_route_signs.size())
		_check(not static_art.has_method("_process") or not static_art.is_processing(), "StageStaticArt does not run per-frame _process()")

	# -------------------------------------------------------------------------
	# Test 2: Optional Encounter Gameplay State Preservation on Boss Spawn
	# -------------------------------------------------------------------------
	print("\n--- Test 2: Optional Encounter Gameplay State Preservation ---")
	_check(stage.optional_groups.size() > 0, "Optional groups initialized in FirstStage (Count: %d)" % stage.optional_groups.size())

	# Check group 0 before boss spawn
	var group0: Dictionary = stage.optional_groups[0]
	var initial_actors_count: int = group0.actors.size()
	_check(group0.cleared == false, "Optional group initially NOT cleared")
	_check(stage.optional_completed[0] == false, "stage.optional_completed[0] initially false")
	_check(initial_actors_count > 0, "Optional group has active actors spawned (Count: %d)" % initial_actors_count)

	var initial_hp: int = stage.player.current_hp

	# Trigger Boss Encounter spawn
	stage.encounter_index = stage.required_count - 1
	stage.call("_spawn_boss_encounter")
	await process_frame
	await process_frame

	# Verify gameplay state was NOT mutated
	_check(group0.cleared == false, "group0.cleared remains false after _spawn_boss_encounter (no gameplay cheat)")
	_check(stage.optional_completed[0] == false, "stage.optional_completed[0] remains false (progress meaning preserved)")
	_check(group0.actors.size() == initial_actors_count, "group0.actors array is NOT cleared (retains %d actors)" % initial_actors_count)
	_check(stage.player.current_hp == initial_hp, "Player did not receive unearned optional reward HP (Current HP: %d)" % stage.player.current_hp)

	# Verify presentation-only suppression for arena-adjacent actors
	var last_group: Dictionary = stage.optional_groups.back()
	for actor in last_group.actors:
		if is_instance_valid(actor) and actor.position.x >= stage.ENTRY_X[stage.encounter_index] - 200.0:
			_check(actor.visible == false, "Arena-adjacent optional actor is visually hidden during boss duel")
			_check(actor.is_physics_processing() == false, "Arena-adjacent optional actor physics process suspended")

	# -------------------------------------------------------------------------
	# Test 3: Boss Telegraph Calibrated HDR Values
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Boss Telegraph Calibrated HDR Values ---")
	var boss = null
	for e in stage.enemies:
		if is_instance_valid(e) and e.is_in_group("boss"):
			boss = e
			break
	_check(boss != null, "BossCommander spawned in encounter")

	if boss != null:
		var attack_visual: Polygon2D = boss.attack_visual if "attack_visual" in boss else boss.get_node_or_null("AttackArea/AttackVisual")
		_check(attack_visual != null, "AttackVisual exists on boss")
		if attack_visual != null:
			var rim: Line2D = attack_visual.get_node_or_null("AttackRim")
			_check(rim != null, "AttackRim Line2D exists on boss AttackVisual")
			if rim != null:
				_check(rim.width <= 3.6, "AttackRim width calibrated to <= 3.6px for crisp outline (Current: %.1f)" % rim.width)
				_check(rim.width >= 2.8, "AttackRim width has sufficient presence >= 2.8px (Current: %.1f)" % rim.width)

		# Trigger attack windup to inspect calibrated colors
		if boss.has_method("_start_attack"):
			boss.call("_start_attack", 1, 0.5, 0.25, true) # Blockable shield bash
			_check(boss.attack_visual.color.a <= 0.26, "Blockable telegraph fill alpha <= 0.26 to keep shield visible (Current: %.2f)" % boss.attack_visual.color.a)
			var rim_node: Line2D = boss.attack_visual.get_node_or_null("AttackRim")
			if rim_node != null:
				_check(rim_node.default_color.r <= 3.2, "Blockable rim HDR intensity <= 3.2 to prevent bloom blowout (Current: %.2f)" % rim_node.default_color.r)
				_check(rim_node.default_color.r >= 1.5, "Blockable rim maintains HDR bloom >= 1.5 (Current: %.2f)" % rim_node.default_color.r)

	print("\n==================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [checks_passed, checks_failed])
	print("==================================================")
	if checks_failed == 0:
		print("ALL R2 BLOCKER CHECKS PASSED (100%)\n")
		stage.free()
		quit(0)
	else:
		printerr("R2 BLOCKER CHECKS FAILED!\n")
		stage.free()
		quit(1)
