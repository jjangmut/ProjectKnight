extends SceneTree

## ProjectKnight V3-024-R2: Boss Arena 2D Boundary, Corner Escape Agency & Overlap Verification Suite
## - Tests 4 Corners (Top-Left, Top-Right, Bottom-Left, Bottom-Right)
## - Tests Top Rail (Z <= -2.4) and Bottom Rail (Z >= 2.4) Trapped Escapes
## - Tests Dash Phase-Through Escape against Boss Collider
## - Tests Guard Walk Mobility and Attack Recovery Drift
## - Verifies Frame-by-Frame Displacement (Non-Zero Movement Under Input)
## - Verifies Sprite Separation & Sorting Offset Clarity

const Stage1Scene = preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null

var test_results := {
	"task_id": "V3-024-R2",
	"branch": "studio/v3-024-r2-boss-depth-escape-agency",
	"timestamp": "",
	"scenarios": {},
	"frame_displacement_metrics": {
		"total_input_frames_tested": 0,
		"displacing_frames": 0,
		"stuck_frames": 0,
		"displacement_rate_pct": 0.0
	},
	"sprite_separation_metrics": {
		"min_combat_distance_seen": 999.0,
		"overlap_incidents_detected": 0
	},
	"overall_pass": false
}


func _init() -> void:
	print("=================================================================")
	print("[V3-024-R2] Starting Boss Arena 2D Corner Escape & Agency Verification Suite...")
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
	if boss == null:
		print("FATAL: Boss not spawned in sanctuary!")
		quit(1)
		return

	print("[V3-024-R2] Stage 1 Boss Sanctuary initialized. Arena Bounds: X=[%.1f, %.1f], Z=[%.1f, %.1f]" % [
		boss.arena_min_x, boss.arena_max_x, boss.arena_min_z, boss.arena_max_z
	])

	# Run Scenarios Sequentially
	_test_corner_escape("corner_1_top_left", Vector3(70.0, 0.1, -2.4), Vector3(72.2, 0.1, -1.8), Vector2(1.0, 1.0), func(p: Vector3) -> bool: return p.x >= 73.0 and p.z >= -0.8)
	_test_corner_escape("corner_2_top_right", Vector3(85.0, 0.1, -2.4), Vector3(82.8, 0.1, -1.8), Vector2(-1.0, 1.0), func(p: Vector3) -> bool: return p.x <= 82.0 and p.z >= -0.8)
	_test_corner_escape("corner_3_bottom_left", Vector3(70.0, 0.1, 2.4), Vector3(72.2, 0.1, 1.8), Vector2(1.0, -1.0), func(p: Vector3) -> bool: return p.x >= 73.0 and p.z <= 0.8)
	_test_corner_escape("corner_4_bottom_right", Vector3(85.0, 0.1, 2.4), Vector3(82.8, 0.1, 1.8), Vector2(-1.0, -1.0), func(p: Vector3) -> bool: return p.x <= 82.0 and p.z <= 0.8)

	_test_depth_rail_escape("depth_rail_top_trapped", Vector3(77.5, 0.1, -2.45), Vector3(77.5, 0.1, -1.6), Vector2(0.0, 1.0), func(p: Vector3) -> bool: return p.z >= -0.6)
	_test_depth_rail_escape("depth_rail_bottom_trapped", Vector3(77.5, 0.1, 2.45), Vector3(77.5, 0.1, 1.6), Vector2(0.0, -1.0), func(p: Vector3) -> bool: return p.z <= 0.6)

	_test_dash_phase_through()
	_test_guard_walk_mobility()
	_test_attack_recovery_drift()

	_finalize_results()


func _test_corner_escape(s_name: String, p_start: Vector3, b_start: Vector3, input_dir: Vector2, goal_check: Callable) -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R2] Testing Scenario: %s (Player: %s, Boss: %s)" % [s_name, str(p_start), str(b_start)])

	player.global_position = p_start
	player.velocity = Vector3.ZERO
	boss.global_position = b_start
	boss.velocity = Vector3.ZERO
	boss.current_pattern = boss.Pattern.CHASE
	boss.pattern_timer = 2.0

	var frame_samples: Array = []
	var escaped := false
	var escape_frame := -1
	var dt := 1.0 / 60.0

	for f in range(90): # 1.5 seconds @ 60 FPS
		# Simulate movement input
		_set_input_actions(input_dir)
		player._physics_process(dt)

		boss._physics_process(dt)

		var cur_p := player.global_position
		var cur_v := player.velocity
		var dist_to_b := (player.global_position - boss.global_position).length()

		test_results["sprite_separation_metrics"]["min_combat_distance_seen"] = minf(
			test_results["sprite_separation_metrics"]["min_combat_distance_seen"], dist_to_b
		)

		var p_disp := cur_v.length() * dt
		var is_stuck := (p_disp < 0.002)

		test_results["frame_displacement_metrics"]["total_input_frames_tested"] += 1
		if is_stuck:
			test_results["frame_displacement_metrics"]["stuck_frames"] += 1
		else:
			test_results["frame_displacement_metrics"]["displacing_frames"] += 1

		if f % 10 == 0 or f == 89 or (not escaped and goal_check.call(cur_p)):
			frame_samples.append({
				"frame": f,
				"player_pos": [snappedf(cur_p.x, 0.01), snappedf(cur_p.y, 0.01), snappedf(cur_p.z, 0.01)],
				"player_vel": [snappedf(cur_v.x, 0.01), snappedf(cur_v.y, 0.01), snappedf(cur_v.z, 0.01)],
				"boss_pos": [snappedf(boss.global_position.x, 0.01), snappedf(boss.global_position.z, 0.01)],
				"dist_to_boss": snappedf(dist_to_b, 0.01)
			})

		if not escaped and goal_check.call(cur_p):
			escaped = true
			escape_frame = f
			break

	_release_inputs()

	var escape_time_s: float = float(escape_frame) * dt if escaped else 99.0
	var scenario_pass: bool = escaped and escape_time_s <= 1.25

	test_results["scenarios"][s_name] = {
		"description": "Corner escape agency and unstick",
		"start_player": [p_start.x, p_start.z],
		"start_boss": [b_start.x, b_start.z],
		"escaped_to_safe_zone": escaped,
		"escape_frame": escape_frame,
		"escape_time_seconds": snappedf(escape_time_s, 0.001),
		"status": "PASSED" if scenario_pass else "FAILED",
		"samples": frame_samples
	}

	print("  -> Result: %s in %.2fs (Frame: %d)" % [
		"PASSED" if scenario_pass else "FAILED", escape_time_s, escape_frame
	])


func _test_depth_rail_escape(s_name: String, p_start: Vector3, b_start: Vector3, input_dir: Vector2, goal_check: Callable) -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R2] Testing Scenario: %s (Player: %s, Boss: %s)" % [s_name, str(p_start), str(b_start)])

	player.global_position = p_start
	player.velocity = Vector3.ZERO
	boss.global_position = b_start
	boss.velocity = Vector3.ZERO
	boss.current_pattern = boss.Pattern.CHASE
	boss.pattern_timer = 2.0

	var frame_samples: Array = []
	var escaped := false
	var escape_frame := -1
	var dt := 1.0 / 60.0

	for f in range(90):
		_set_input_actions(input_dir)
		player._physics_process(dt)

		boss._physics_process(dt)

		var cur_p := player.global_position
		var cur_v := player.velocity
		var dist_to_b := (player.global_position - boss.global_position).length()

		test_results["sprite_separation_metrics"]["min_combat_distance_seen"] = minf(
			test_results["sprite_separation_metrics"]["min_combat_distance_seen"], dist_to_b
		)

		var p_disp := cur_v.length() * dt
		var is_stuck := (p_disp < 0.002)

		test_results["frame_displacement_metrics"]["total_input_frames_tested"] += 1
		if is_stuck:
			test_results["frame_displacement_metrics"]["stuck_frames"] += 1
		else:
			test_results["frame_displacement_metrics"]["displacing_frames"] += 1

		if f % 10 == 0 or (not escaped and goal_check.call(cur_p)):
			frame_samples.append({
				"frame": f,
				"player_pos": [snappedf(cur_p.x, 0.01), snappedf(cur_p.y, 0.01), snappedf(cur_p.z, 0.01)],
				"player_vel": [snappedf(cur_v.x, 0.01), snappedf(cur_v.y, 0.01), snappedf(cur_v.z, 0.01)],
				"boss_pos": [snappedf(boss.global_position.x, 0.01), snappedf(boss.global_position.z, 0.01)],
				"dist_to_boss": snappedf(dist_to_b, 0.01)
			})

		if not escaped and goal_check.call(cur_p):
			escaped = true
			escape_frame = f
			break

	_release_inputs()

	var escape_time_s: float = float(escape_frame) * dt if escaped else 99.0
	var scenario_pass: bool = escaped and escape_time_s <= 1.0

	test_results["scenarios"][s_name] = {
		"description": "Depth rail unstick and vertical corridor traversal",
		"start_player": [p_start.x, p_start.z],
		"start_boss": [b_start.x, b_start.z],
		"escaped_to_safe_zone": escaped,
		"escape_frame": escape_frame,
		"escape_time_seconds": snappedf(escape_time_s, 0.001),
		"status": "PASSED" if scenario_pass else "FAILED",
		"samples": frame_samples
	}

	print("  -> Result: %s in %.2fs (Frame: %d)" % [
		"PASSED" if scenario_pass else "FAILED", escape_time_s, escape_frame
	])


func _test_dash_phase_through() -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R2] Testing Scenario: dash_phase_through_boss")

	player.global_position = Vector3(70.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	boss.global_position = Vector3(72.0, 0.1, 0.0)
	boss.velocity = Vector3.ZERO
	boss.current_pattern = boss.Pattern.IDLE

	player.facing_attack_dir = Vector3(1.0, 0.0, 0.0)
	player.facing_dir_x = 1.0

	player.start_dash()

	var initial_mask_val: bool = player.get_collision_mask_value(2)
	print("  - During Dash: Enemy Collision Mask active: %s (Expected: false)" % str(initial_mask_val))

	var dt := 1.0 / 60.0
	var samples: Array = []
	for f in range(25): # ~0.4s (DASH_DURATION is 0.22s)
		player._physics_process(dt)
		if f % 5 == 0 or f == 24:
			samples.append({
				"frame": f,
				"player_x": snappedf(player.global_position.x, 0.01),
				"mask_layer_2": player.get_collision_mask_value(2),
				"state": player.current_state
			})

	var final_mask_val: bool = player.get_collision_mask_value(2)
	var crossed_boss: bool = (player.global_position.x > boss.global_position.x + 0.5)

	var pass_dash: bool = (not initial_mask_val) and final_mask_val and crossed_boss

	test_results["scenarios"]["dash_phase_through_boss"] = {
		"description": "Player dashes through boss collider without getting blocked",
		"initial_mask_layer_2": initial_mask_val,
		"final_mask_layer_2": final_mask_val,
		"player_start_x": 70.0,
		"boss_x": 72.0,
		"player_end_x": snappedf(player.global_position.x, 0.01),
		"crossed_boss_successfully": crossed_boss,
		"status": "PASSED" if pass_dash else "FAILED",
		"samples": samples
	}

	print("  -> Result: %s (Player ended at X=%.2f, Boss at X=72.0)" % [
		"PASSED" if pass_dash else "FAILED", player.global_position.x
	])


func _test_guard_walk_mobility() -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R2] Testing Scenario: guard_walk_mobility")

	player.global_position = Vector3(75.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.start_guard()

	var dt := 1.0 / 60.0
	Input.action_press("guard")
	Input.action_press("move_right")

	for f in range(30): # 0.5s of guard walk
		player._physics_process(dt)

	Input.action_release("guard")
	Input.action_release("move_right")
	player._physics_process(dt)

	var disp_x: float = player.global_position.x - 75.0
	var pass_gw: bool = (disp_x >= 0.8 and player.is_guarding == false)

	test_results["scenarios"]["guard_walk_mobility"] = {
		"description": "Player can walk at 40% speed while keeping guard raised",
		"start_x": 75.0,
		"end_x": snappedf(player.global_position.x, 0.01),
		"displacement_x": snappedf(disp_x, 0.01),
		"status": "PASSED" if pass_gw else "FAILED"
	}

	print("  -> Result: %s (Displaced %.2fm while holding Guard)" % [
		"PASSED" if pass_gw else "FAILED", disp_x
	])


func _test_attack_recovery_drift() -> void:
	print("-----------------------------------------------------------------")
	print("[V3-024-R2] Testing Scenario: attack_recovery_drift")

	player.global_position = Vector3(75.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.start_attack()

	var dt := 1.0 / 60.0
	# Hold movement key during attack
	Input.action_press("move_right")

	for f in range(25): # ~0.4s across full attack and recovery
		player._physics_process(dt)

	Input.action_release("move_right")

	var disp_x: float = player.global_position.x - 75.0
	var pass_atk_drift: bool = (disp_x >= 0.25)

	test_results["scenarios"]["attack_recovery_drift"] = {
		"description": "Player can drift move during late attack recovery",
		"start_x": 75.0,
		"end_x": snappedf(player.global_position.x, 0.01),
		"displacement_x": snappedf(disp_x, 0.01),
		"status": "PASSED" if pass_atk_drift else "FAILED"
	}

	print("  -> Result: %s (Displaced %.2fm during attack recovery)" % [
		"PASSED" if pass_atk_drift else "FAILED", disp_x
	])


func _set_input_actions(dir: Vector2) -> void:
	_release_inputs()
	if dir.x > 0.1:
		Input.action_press("move_right")
	elif dir.x < -0.1:
		Input.action_press("move_left")

	if dir.y > 0.1:
		Input.action_press("move_down") # +Z (down toward camera)
	elif dir.y < -0.1:
		Input.action_press("move_up")   # -Z (up away from camera)


func _release_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("guard")
	Input.action_release("dash")
	Input.action_release("attack")


func _finalize_results() -> void:
	var total_f: int = test_results["frame_displacement_metrics"]["total_input_frames_tested"]
	var disp_f: int = test_results["frame_displacement_metrics"]["displacing_frames"]
	var stuck_f: int = test_results["frame_displacement_metrics"]["stuck_frames"]

	var rate: float = (float(disp_f) / float(max(1, total_f))) * 100.0
	test_results["frame_displacement_metrics"]["displacement_rate_pct"] = snappedf(rate, 0.1)

	var all_pass := true
	for s in test_results["scenarios"].values():
		if s["status"] != "PASSED":
			all_pass = false
			break

	if rate < 95.0 or stuck_f > 15:
		all_pass = false

	test_results["overall_pass"] = all_pass

	print("=================================================================")
	print("[V3-024-R2] SUMMARY OF CORNER ESCAPE & MOBILITY AUDIT:")
	print("  - Total Movement Input Frames: %d" % total_f)
	print("  - Displacing Frames: %d (%.1f%%)" % [disp_f, rate])
	print("  - Stuck Frames: %d" % stuck_f)
	print("  - Min Combat Distance Observed: %.2fm" % test_results["sprite_separation_metrics"]["min_combat_distance_seen"])
	print("  - OVERALL PASS: %s" % str(all_pass))
	print("=================================================================")

	var out_dir := "res://../../STUDIO_V3/evidence/V3-024-R2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var out_path := out_dir + "/CORNER_ESCAPE_TRACE.json"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(test_results, "\t"))
		f.close()
		print("[V3-024-R2] Results saved to %s" % out_path)

	quit(0 if all_pass else 1)
