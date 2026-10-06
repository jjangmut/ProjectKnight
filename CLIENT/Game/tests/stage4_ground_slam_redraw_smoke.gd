extends SceneTree
## TASK-AR-018: GroundSlamGolem Redraw Blocker Smoke Test
## Validates the 5 mandatory scenarios:
##   TEST 1: Idle - GroundSlamGolem idle does not trigger continuous redraw
##   TEST 2: Windup - Attack windup triggers combat redraw and telegraph path
##   TEST 3: Active Slam - Active ground slam triggers combat redraw and shockwave path
##   TEST 4: Attack End - Transition out of attack triggers exactly one cleanup redraw
##   TEST 5: No Permanent Redraw - Idle frames after cleanup do not trigger continuous redraw

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
	print("\n=======================================================")
	print(">>> RUNNING: stage4_ground_slam_redraw_smoke.gd")
	print("=======================================================")

	var stage_scene: PackedScene = load("res://scenes/stage/FourthStage.tscn")
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage

	# Stop restart timer and disable HUD intro banner
	var rt = stage.get_node_or_null("RestartTimer")
	if rt != null:
		rt.stop()
		for conn in rt.timeout.get_connections():
			rt.timeout.disconnect(conn.callable)

	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null and "intro_remaining" in pres:
		pres.set("intro_remaining", 0.0)

	await process_frame
	await process_frame

	var stage_art = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt node exists in FourthStage")
	if stage_art == null:
		quit(1)
		return

	# Start encounter 0 to spawn GroundSlamGolem
	stage.encounter_index = 0
	stage.player.position = Vector2(500, 592)
	stage._start_encounter()
	await process_frame
	await process_frame

	var golem = null
	for e in stage.enemies:
		if is_instance_valid(e) and (e.get_meta("art_variant", "") == "golem" or e.get_meta("ground_slam", false) == true):
			golem = e
			break

	_check(golem != null, "GroundSlamGolem spawned in encounter 0")
	if golem == null:
		quit(1)
		return

	# Freeze golem autonomous physics for deterministic testing
	golem.set_physics_process(false)
	stage.player.set_physics_process(false)
	stage.player.velocity = Vector2.ZERO

	# Find golem actor entry in StageArt
	var golem_entry: Dictionary = {}
	for entry in stage_art.actors:
		if entry.get("actor") == golem:
			golem_entry = entry
			break
	_check(not golem_entry.is_empty(), "StageArt has tracked actor entry for GroundSlamGolem")
	_check(golem_entry.get("ground_slam", false) == true or golem_entry.get("variant", "") == "golem", "Actor entry identified as ground_slam / golem")

	# Settle any initial frame redraws
	await process_frame
	await process_frame

	# -------------------------------------------------------------------------
	# TEST 1: Idle - GroundSlamGolem idle does not trigger continuous redraw
	# -------------------------------------------------------------------------
	print("\n--- TEST 1: Idle (No Continuous Redraw) ---")
	golem.state = 0 # PATROL
	golem.attack_phase = 2 # RECOVERY
	golem.is_attack_active = false
	await process_frame
	await process_frame # Settle cleanup

	var redraws_before: int = stage_art.redraw_request_count
	for i in range(10):
		await process_frame

	var redraws_during_idle: int = stage_art.redraw_request_count - redraws_before
	_check(stage_art.combat_redraw_active == false, "combat_redraw_active is false during golem idle")
	_check(redraws_during_idle == 0, "Zero redraw requests during 10 idle frames (Actual: %d)" % redraws_during_idle)

	# -------------------------------------------------------------------------
	# TEST 2: Windup - Attack windup triggers combat redraw
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Windup (Telegraph Redraw Active) ---")
	golem.state = 2 # ATTACK
	golem.attack_phase = 0 # WINDUP
	golem.is_attack_active = false
	golem._phase_time_remaining = 0.35

	redraws_before = stage_art.redraw_request_count
	await process_frame
	_check(stage_art.combat_redraw_active == true, "combat_redraw_active is true during windup")
	_check(stage_art.redraw_request_count > redraws_before, "redraw_request_count incremented on windup frame")

	# Multiple frames in windup should continuously redraw (animating telegraph ticks/cracks)
	redraws_before = stage_art.redraw_request_count
	for i in range(5):
		golem._phase_time_remaining = maxf(0.01, golem._phase_time_remaining - 0.02)
		await process_frame

	var windup_redraws: int = stage_art.redraw_request_count - redraws_before
	_check(windup_redraws == 5, "Every windup frame requested redraw for telegraph update (Actual: %d/5)" % windup_redraws)

	# -------------------------------------------------------------------------
	# TEST 3: Active Slam - Active slam triggers combat redraw
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Active Slam (Shockwave Redraw Active) ---")
	golem.state = 2 # ATTACK
	golem.attack_phase = 1 # ACTIVE
	golem.is_attack_active = true
	golem._phase_time_remaining = 0.12

	redraws_before = stage_art.redraw_request_count
	await process_frame
	_check(stage_art.combat_redraw_active == true, "combat_redraw_active is true during active slam")
	_check(stage_art.redraw_request_count > redraws_before, "redraw_request_count incremented on active slam frame")

	# Multiple frames in active slam should continuously redraw (animating expanding ripple & debris)
	redraws_before = stage_art.redraw_request_count
	for i in range(5):
		golem._phase_time_remaining = maxf(0.01, golem._phase_time_remaining - 0.02)
		await process_frame

	var active_redraws: int = stage_art.redraw_request_count - redraws_before
	_check(active_redraws == 5, "Every active slam frame requested redraw for shockwave update (Actual: %d/5)" % active_redraws)

	# -------------------------------------------------------------------------
	# TEST 4: Attack End - Transition out of attack triggers 1 cleanup redraw
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Attack End (1-Time Cleanup Redraw) ---")
	# Golem transitions to recovery
	golem.state = 2 # ATTACK
	golem.attack_phase = 2 # RECOVERY
	golem.is_attack_active = false

	redraws_before = stage_art.redraw_request_count
	await process_frame

	_check(stage_art.combat_redraw_active == false, "combat_redraw_active is false on attack end")
	var cleanup_redraws: int = stage_art.redraw_request_count - redraws_before
	_check(cleanup_redraws == 1, "Exactly 1 cleanup redraw requested to clear residual attack VFX (Actual: %d)" % cleanup_redraws)
	_check(stage_art._had_combat_draw == false, "_had_combat_draw reset to false after cleanup")

	# -------------------------------------------------------------------------
	# TEST 5: No Permanent Redraw - Subsequent frames remain static
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: No Permanent Redraw (Static State Restored) ---")
	golem.state = 0 # PATROL
	redraws_before = stage_art.redraw_request_count
	for i in range(20):
		await process_frame

	var post_cleanup_redraws: int = stage_art.redraw_request_count - redraws_before
	_check(stage_art.combat_redraw_active == false, "combat_redraw_active remains false")
	_check(post_cleanup_redraws == 0, "Zero redraw requests across 20 subsequent idle frames (Actual: %d)" % post_cleanup_redraws)

	# -------------------------------------------------------------------------
	# Final summary
	# -------------------------------------------------------------------------
	print("\n=======================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("=======================================================")

	stage.queue_free()
	if checks_failed == 0:
		print(">>> STAGE 4 GROUND SLAM REDRAW SMOKE: ALL PASS! <<<")
		quit(0)
	else:
		printerr(">>> STAGE 4 GROUND SLAM REDRAW SMOKE: FAILED! <<<")
		quit(1)
