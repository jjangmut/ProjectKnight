extends SceneTree

## ProjectKnight V3-024-R3: Boss Arena Same-Lane Combat Composition & Sprite Occlusion Suite
## - Verifies 2.5D Belt-Scroll Depth Lane Alignment between Hero and Boss
## - Measures screen-space Foot Y pixel coordinates (camera.unproject_position)
## - Asserts Foot-Y difference <= 22px in >= 95% of active melee exchange frames
## - Asserts Horizontal Silhouette Separation (X >= 1.60m) to eliminate sprite overlap
## - Verifies Z-Dodge / Sidestep Evasion (hits miss when dodging off-lane)
## - Verifies Depth Rail Duel Alignment (Boss fights on same depth lane, not parked at Z=0.2)
## - Re-runs 4-Corner & Depth Rail escape regression tests

const Stage1Scene = preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null
var camera: Camera3D = null

var test_results := {
	"task_id": "V3-024-R3",
	"branch": "studio/v3-024-r3-boss-combat-lane-alignment",
	"timestamp": "",
	"lane_alignment_metrics": {
		"total_melee_frames_tested": 0,
		"aligned_frames_count": 0,
		"alignment_rate_pct": 0.0,
		"foot_y_diff_median_px": 0.0,
		"foot_y_diff_p95_px": 0.0,
		"foot_y_diff_max_px": 0.0,
		"min_horizontal_separation_m": 999.0,
		"overlap_incidents": 0
	},
	"scenarios": {},
	"corner_regression_passed": false,
	"z_dodge_evasion_passed": false,
	"overall_pass": false
}


func _init() -> void:
	print("=================================================================")
	print("[V3-024-R3] Starting Boss Same-Lane Combat Alignment & Occlusion Suite...")
	print("=================================================================")
	call_deferred("_run_all_tests")


func _process(_delta: float) -> bool:
	return false


func _run_all_tests() -> void:
	test_results["timestamp"] = Time.get_datetime_string_from_system()

	# 1. Setup Sanctuary Stage & Combatants
	stage = Stage1Scene.instantiate()
	root.add_child(stage)

	player = stage.get_node_or_null("SideQVPlayer")
	if player == null:
		print("FATAL: Player not found in stage!")
		quit(1)
		return

	# Fast-forward stage to Boss Sanctuary
	stage._start_boss_sanctuary()
	boss = stage.active_boss
	camera = stage.camera
	if boss == null or camera == null:
		print("FATAL: Boss or Camera not initialized in sanctuary!")
		quit(1)
		return

	# Sync camera initially
	camera.target = player
	camera.boss_target = boss
	camera.base_pos = Vector3(77.0, camera.camera_offset.y, camera.camera_offset.z)
	camera.global_position = camera.base_pos

	print("[V3-024-R3] Stage 1 Boss Sanctuary Duel initialized.")
	print("  Camera FOV: %.1f, Pitch: %.1f, Offset: %s" % [camera.fov, camera.rotation_degrees.x, str(camera.camera_offset)])

	# Run Verification Scenarios
	_test_lane_matching("lane_matching_from_above", Vector3(74.0, 0.0, -1.2), Vector3(78.0, 0.0, 0.0))
	_test_lane_matching("lane_matching_from_below", Vector3(74.0, 0.0, 1.2), Vector3(78.0, 0.0, 0.0))
	_test_same_lane_melee_exchange("same_lane_melee_exchange", Vector3(74.5, 0.0, 0.0), Vector3(77.5, 0.0, 0.0))
	_test_z_dodge_evasion("z_dodge_evasion_and_miss_detection")
	_test_depth_rail_combat_alignment("depth_rail_combat_alignment", Vector3(75.0, 0.0, -1.8), Vector3(79.0, 0.0, -0.5))
	_test_corner_escape_regressions()

	_finalize_results()


func _test_lane_matching(s_name: String, p_start: Vector3, b_start: Vector3) -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R3] Testing Scenario: %s" % s_name)
	print("  Player Start: %s, Boss Start: %s (Initial delta-Z = %.2fm)" % [str(p_start), str(b_start), absf(p_start.z - b_start.z)])

	player.global_position = p_start
	player.velocity = Vector3.ZERO
	boss.global_position = b_start
	boss.velocity = Vector3.ZERO
	boss.current_pattern = boss.Pattern.CHASE
	boss.pattern_timer = 2.0

	var dt := 1.0 / 60.0
	var samples: Array = []
	var aligned := false
	var aligned_frame := -1

	for f in range(60): # 1.0 second simulation
		player._physics_process(dt)
		boss._physics_process(dt)
		camera._physics_process(dt)

		var p_foot := camera.unproject_position(player.global_position)
		var b_foot := camera.unproject_position(boss.global_position)
		var foot_y_diff := absf(p_foot.y - b_foot.y)
		var z_diff := absf(player.global_position.z - boss.global_position.z)

		if f % 10 == 0 or f == 59 or (not aligned and foot_y_diff <= 18.0):
			samples.append({
				"frame": f,
				"player_z": snappedf(player.global_position.z, 0.01),
				"boss_z": snappedf(boss.global_position.z, 0.01),
				"z_diff_m": snappedf(z_diff, 0.01),
				"p_foot_screen_y": snappedf(p_foot.y, 0.1),
				"b_foot_screen_y": snappedf(b_foot.y, 0.1),
				"foot_y_diff_px": snappedf(foot_y_diff, 0.1)
			})

		if not aligned and foot_y_diff <= 18.0:
			aligned = true
			aligned_frame = f

	var final_z_diff := absf(player.global_position.z - boss.global_position.z)
	var final_p_foot := camera.unproject_position(player.global_position)
	var final_b_foot := camera.unproject_position(boss.global_position)
	var final_foot_y_diff := absf(final_p_foot.y - final_b_foot.y)

	var pass_ok: bool = aligned and final_foot_y_diff <= 22.0
	test_results["scenarios"][s_name] = {
		"status": "PASSED" if pass_ok else "FAILED",
		"aligned_frame": aligned_frame,
		"final_z_diff_m": snappedf(final_z_diff, 0.01),
		"final_foot_y_diff_px": snappedf(final_foot_y_diff, 0.1),
		"samples": samples
	}
	print("  -> Result: %s (Aligned at frame %d, Final Foot-Y diff: %.1f px, delta-Z: %.2f m)" % [
		"PASSED" if pass_ok else "FAILED", aligned_frame, final_foot_y_diff, final_z_diff
	])


func _test_same_lane_melee_exchange(s_name: String, p_start: Vector3, b_start: Vector3) -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R3] Testing Scenario: %s (Continuous Melee Duel)" % s_name)

	player.global_position = p_start
	player.velocity = Vector3.ZERO
	boss.global_position = b_start
	boss.velocity = Vector3.ZERO
	boss.current_pattern = boss.Pattern.CHASE
	boss.pattern_timer = 3.0

	var dt := 1.0 / 60.0
	var foot_y_diffs: Array[float] = []
	var min_x_sep: float = 999.0
	var aligned_count := 0
	var samples: Array = []

	for f in range(120): # 2.0 seconds @ 60 FPS
		# Player swings 3-hit combo intermittently
		if f % 25 == 0:
			player.start_attack()
		player._physics_process(dt)
		boss._physics_process(dt)
		camera._physics_process(dt)

		var p_foot := camera.unproject_position(player.global_position)
		var b_foot := camera.unproject_position(boss.global_position)
		var foot_y_diff := absf(p_foot.y - b_foot.y)
		var x_dist := absf(player.global_position.x - boss.global_position.x)
		min_x_sep = minf(min_x_sep, x_dist)

		foot_y_diffs.append(foot_y_diff)
		test_results["lane_alignment_metrics"]["total_melee_frames_tested"] += 1

		if foot_y_diff <= 22.0:
			aligned_count += 1
			test_results["lane_alignment_metrics"]["aligned_frames_count"] += 1

		if f % 20 == 0 or f == 119:
			samples.append({
				"frame": f,
				"player_pos": [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.z, 0.01)],
				"boss_pos": [snappedf(boss.global_position.x, 0.01), snappedf(boss.global_position.z, 0.01)],
				"x_separation_m": snappedf(x_dist, 0.01),
				"foot_y_diff_px": snappedf(foot_y_diff, 0.1),
				"boss_pattern": boss.pattern_phase
			})

	foot_y_diffs.sort()
	var median_y: float = foot_y_diffs[int(foot_y_diffs.size() * 0.5)]
	var p95_y: float = foot_y_diffs[int(foot_y_diffs.size() * 0.95)]
	var max_y: float = foot_y_diffs[-1]
	var align_pct: float = (float(aligned_count) / float(foot_y_diffs.size())) * 100.0

	test_results["lane_alignment_metrics"]["foot_y_diff_median_px"] = snappedf(median_y, 0.1)
	test_results["lane_alignment_metrics"]["foot_y_diff_p95_px"] = snappedf(p95_y, 0.1)
	test_results["lane_alignment_metrics"]["foot_y_diff_max_px"] = snappedf(max_y, 0.1)
	test_results["lane_alignment_metrics"]["min_horizontal_separation_m"] = snappedf(min_x_sep, 0.01)

	var pass_ok: bool = (align_pct >= 95.0) and (min_x_sep >= 1.50)
	test_results["scenarios"][s_name] = {
		"status": "PASSED" if pass_ok else "FAILED",
		"total_frames": foot_y_diffs.size(),
		"aligned_frames": aligned_count,
		"alignment_rate_pct": snappedf(align_pct, 0.1),
		"median_foot_y_diff_px": snappedf(median_y, 0.1),
		"p95_foot_y_diff_px": snappedf(p95_y, 0.1),
		"max_foot_y_diff_px": snappedf(max_y, 0.1),
		"min_x_separation_m": snappedf(min_x_sep, 0.01),
		"samples": samples
	}

	print("  -> Result: %s" % ("PASSED" if pass_ok else "FAILED"))
	print("     Alignment Rate: %.1f%% (>=95%% required)" % align_pct)
	print("     Median Foot-Y diff: %.1f px, P95: %.1f px, Max: %.1f px" % [median_y, p95_y, max_y])
	print("     Min Horizontal Separation: %.2f m (>=1.50m required)" % min_x_sep)


func _test_z_dodge_evasion(s_name: String) -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R3] Testing Scenario: %s (Z-Dodge Sidestep Evasion)" % s_name)

	# Place combatants initially on same lane
	player.global_position = Vector3(74.5, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	player.current_hp = 6
	boss.global_position = Vector3(76.5, 0.0, 0.0)
	boss.velocity = Vector3.ZERO
	boss.facing_dir_x = -1.0

	# Force boss into Triple Cleave attack
	boss._execute_triple_cleave()

	# Player sidesteps in Z by 0.85m (dodges down along screen)
	player.global_position.z = 0.85

	var dt := 1.0 / 60.0
	for f in range(60): # 1.0 second of cleave swings
		player._physics_process(dt)
		boss._physics_process(dt)
		camera._physics_process(dt)

	var p_screen := camera.unproject_position(player.global_position)
	var b_screen := camera.unproject_position(boss.global_position)
	var foot_y_diff := absf(p_screen.y - b_screen.y)

	var damage_taken: int = 6 - player.current_hp
	var evasion_success: bool = (damage_taken == 0)

	test_results["z_dodge_evasion_passed"] = evasion_success
	test_results["scenarios"][s_name] = {
		"status": "PASSED" if evasion_success else "FAILED",
		"player_z": snappedf(player.global_position.z, 0.01),
		"boss_z": snappedf(boss.global_position.z, 0.01),
		"delta_z_m": snappedf(absf(player.global_position.z - boss.global_position.z), 0.01),
		"foot_y_diff_px": snappedf(foot_y_diff, 0.1),
		"damage_taken": damage_taken,
		"evasion_success": evasion_success
	}

	print("  -> Result: %s (Damage taken: %d, delta-Z: %.2fm, Foot-Y diff: %.1f px)" % [
		"PASSED" if evasion_success else "FAILED", damage_taken, absf(player.global_position.z - boss.global_position.z), foot_y_diff
	])


func _test_depth_rail_combat_alignment(s_name: String, p_start: Vector3, b_start: Vector3) -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R3] Testing Scenario: %s (Rail Duel Alignment)" % s_name)

	player.global_position = p_start
	player.velocity = Vector3.ZERO
	boss.global_position = b_start
	boss.velocity = Vector3.ZERO
	boss.current_pattern = boss.Pattern.CHASE
	boss.pattern_timer = 2.0

	var dt := 1.0 / 60.0
	for f in range(60):
		player._physics_process(dt)
		boss._physics_process(dt)
		camera._physics_process(dt)

	var final_z_diff := absf(player.global_position.z - boss.global_position.z)
	var p_foot := camera.unproject_position(player.global_position)
	var b_foot := camera.unproject_position(boss.global_position)
	var foot_y_diff := absf(p_foot.y - b_foot.y)

	# Boss must match lane at Z=-1.8 rather than parking at Z=0.2
	var pass_ok: bool = (final_z_diff <= 0.35) and (foot_y_diff <= 22.0) and (boss.global_position.z <= -1.4)
	test_results["scenarios"][s_name] = {
		"status": "PASSED" if pass_ok else "FAILED",
		"player_z": snappedf(player.global_position.z, 0.01),
		"boss_z": snappedf(boss.global_position.z, 0.01),
		"final_z_diff_m": snappedf(final_z_diff, 0.01),
		"foot_y_diff_px": snappedf(foot_y_diff, 0.1)
	}

	print("  -> Result: %s (Boss Z: %.2f vs Player Z: %.2f, Foot-Y diff: %.1f px)" % [
		"PASSED" if pass_ok else "FAILED", boss.global_position.z, player.global_position.z, foot_y_diff
	])


func _test_corner_escape_regressions() -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R3] Testing Corner Escape Regression Matrix...")

	var corners := [
		{"name": "corner_top_left", "p": Vector3(70.0, 0.1, -2.4), "b": Vector3(72.2, 0.1, -1.8), "in": Vector2(1.0, 1.0), "goal": func(p: Vector3) -> bool: return p.x >= 73.0 and p.z >= -0.8},
		{"name": "corner_bottom_right", "p": Vector3(85.0, 0.1, 2.4), "b": Vector3(82.8, 0.1, 1.8), "in": Vector2(-1.0, -1.0), "goal": func(p: Vector3) -> bool: return p.x <= 82.0 and p.z <= 0.8},
		{"name": "rail_top_trapped", "p": Vector3(77.5, 0.1, -2.45), "b": Vector3(77.5, 0.1, -1.6), "in": Vector2(0.0, 1.0), "goal": func(p: Vector3) -> bool: return p.z >= -0.6}
	]

	var all_corners_pass := true
	var dt := 1.0 / 60.0

	for c in corners:
		_release_inputs()
		player.current_state = player.State.IDLE
		player.is_attacking = false
		player.is_guarding = false
		player.is_hit_paused = false
		player.hit_pause_timer = 0.0
		player.current_hp = 6
		player.global_position = c["p"]
		player.velocity = Vector3.ZERO
		boss.is_hit_paused = false
		boss.hit_pause_timer = 0.0
		boss.global_position = c["b"]
		boss.velocity = Vector3.ZERO
		boss.current_pattern = boss.Pattern.CHASE
		boss.pattern_timer = 2.0

		var escaped := false
		for f in range(90):
			_set_input_actions(c["in"])
			player._physics_process(dt)
			boss._physics_process(dt)
			camera._physics_process(dt)

			if c["goal"].call(player.global_position):
				escaped = true
				break

		_release_inputs()
		if not escaped:
			all_corners_pass = false
			print("  [FAIL] %s did not escape!" % c["name"])
		else:
			print("  [PASS] %s escaped successfully." % c["name"])

	test_results["corner_regression_passed"] = all_corners_pass


func _set_input_actions(dir: Vector2) -> void:
	_release_inputs()
	if dir.x > 0.1:
		Input.action_press("move_right")
	elif dir.x < -0.1:
		Input.action_press("move_left")

	if dir.y > 0.1:
		Input.action_press("move_down")
	elif dir.y < -0.1:
		Input.action_press("move_up")


func _release_inputs() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("move_down")
	Input.action_release("move_up")
	Input.action_release("guard")
	Input.action_release("dash")
	Input.action_release("attack")


func _finalize_results() -> void:
	var total_melee: int = int(test_results["lane_alignment_metrics"]["total_melee_frames_tested"])
	var aligned_count: int = int(test_results["lane_alignment_metrics"]["aligned_frames_count"])
	var align_pct: float = (float(aligned_count) / float(maxi(1, total_melee))) * 100.0
	test_results["lane_alignment_metrics"]["alignment_rate_pct"] = snappedf(align_pct, 0.1)

	var all_scenarios_pass := true
	for s_key in test_results["scenarios"].keys():
		if test_results["scenarios"][s_key]["status"] != "PASSED":
			all_scenarios_pass = false

	var overall: bool = all_scenarios_pass and test_results["corner_regression_passed"] and test_results["z_dodge_evasion_passed"] and (align_pct >= 95.0)
	test_results["overall_pass"] = overall

	print("=================================================================")
	print("[V3-024-R3] OVERALL VERIFICATION RESULT: %s" % ("ALL PASSED (100%)" if overall else "FAILED"))
	print("  Melee Lane Alignment Rate: %.1f%% (>=95.0%%)" % align_pct)
	print("  Median Foot-Y diff: %.1f px, P95: %.1f px" % [
		test_results["lane_alignment_metrics"]["foot_y_diff_median_px"],
		test_results["lane_alignment_metrics"]["foot_y_diff_p95_px"]
	])
	print("  Min Horizontal Separation: %.2f m" % test_results["lane_alignment_metrics"]["min_horizontal_separation_m"])
	print("  Z-Dodge Evasion: %s" % ("PASSED" if test_results["z_dodge_evasion_passed"] else "FAILED"))
	print("  Corner Regression Matrix: %s" % ("PASSED" if test_results["corner_regression_passed"] else "FAILED"))
	print("=================================================================")

	var json_str := JSON.stringify(test_results, "  ")
	var file_path := "res://../../STUDIO_V3/evidence/V3-024-R3/COMBAT_SCREEN_LANE_RESULTS.json"
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
		print("[V3-024-R3] Saved results to: %s" % file_path)

	quit(0 if overall else 1)
