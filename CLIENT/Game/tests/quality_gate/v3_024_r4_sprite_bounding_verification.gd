extends SceneTree
## ProjectKnight V3-024-R4: Sprite Bounding Box & Silhouette Visibility Suite
## Directly measures full 2D projected screen bounds of Player and Boss,
## tracking horizontal separation, bounding box intersection, and silhouette visibility.

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null
var camera: Camera3D = null

var trace_samples: Array = []
var critical_overlaps: int = 0
var min_horizontal_sep_m: float = 999.0
var min_bounding_box_gap_px: float = 999.0

var results := {
	"test_name": "V3-024-R4 Sprite Bounding Box & Silhouette Visibility",
	"total_frames_analyzed": 0,
	"critical_overlaps": 0,
	"min_horizontal_sep_m": 0.0,
	"min_bounding_box_gap_px": 0.0,
	"avg_hero_silhouette_visibility_pct": 100.0,
	"min_hero_silhouette_visibility_pct": 100.0,
	"all_scenarios_passed": false,
	"scenarios": {},
	"samples": []
}

func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_start_suite")

func _start_suite() -> void:
	print("=================================================================")
	print("[V3-024-R4] Starting Sprite Bounding Box & Visibility Suite...")
	print("=================================================================")

	var packed := load(Stage1ScenePath) as PackedScene
	if packed == null:
		printerr("[SPRITE_BOUNDS] Failed to load Stage 1 scene")
		quit(1)
		return

	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	stage._start_boss_sanctuary()
	player = stage.get_node_or_null("SideQVPlayer")
	boss = stage.active_boss
	camera = root.get_camera_3d()

	if player == null or boss == null or camera == null:
		printerr("[SPRITE_BOUNDS] Failed to resolve combatants or camera!")
		quit(1)
		return

	await _run_scenarios()

func _get_actor_screen_rect(actor: CharacterBody3D, is_boss_actor: bool) -> Rect2:
	# Bounding box in world coordinates
	# Player: ~1.23m wide, 1.85m tall; Boss: ~1.80m wide, 2.45m tall
	var half_w: float = 0.90 if is_boss_actor else 0.62
	var height: float = 2.45 if is_boss_actor else 1.85
	var center := actor.global_position

	var p_foot := camera.unproject_position(center)
	var p_head := camera.unproject_position(center + Vector3(0.0, height, 0.0))
	var p_left := camera.unproject_position(center + Vector3(-half_w, height * 0.5, 0.0))
	var p_right := camera.unproject_position(center + Vector3(half_w, height * 0.5, 0.0))

	var min_x := minf(minf(p_foot.x, p_head.x), minf(p_left.x, p_right.x))
	var max_x := maxf(maxf(p_foot.x, p_head.x), maxf(p_left.x, p_right.x))
	var min_y := minf(minf(p_foot.y, p_head.y), minf(p_left.y, p_right.y))
	var max_y := maxf(maxf(p_foot.y, p_head.y), maxf(p_left.y, p_right.y))

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _run_scenarios() -> void:
	# Scenario 1: Top Rail Duel (Z = -1.6m) — Reproduction scenario of V3-024-R3 5~7s
	print("-----------------------------------------------------------------")
	print("[V3-024-R4] Testing Scenario 1: top_rail_cleave_duel (Z = -1.6m)...")
	await _test_scenario("top_rail_cleave_duel", Vector3(73.5, 0.0, -1.6), Vector3(76.5, 0.0, -1.6), true)

	# Scenario 2: Center Lane Melee Duel (Z = 0.0m)
	print("-----------------------------------------------------------------")
	print("[V3-024-R4] Testing Scenario 2: center_lane_duel (Z = 0.0m)...")
	await _test_scenario("center_lane_duel", Vector3(74.0, 0.0, 0.0), Vector3(77.0, 0.0, 0.0), false)

	# Scenario 3: Bottom Rail Cleave Duel (Z = 1.4m)
	print("-----------------------------------------------------------------")
	print("[V3-024-R4] Testing Scenario 3: bottom_rail_cleave_duel (Z = 1.4m)...")
	await _test_scenario("bottom_rail_cleave_duel", Vector3(73.5, 0.0, 1.4), Vector3(76.5, 0.0, 1.4), true)

	_finish_suite()

func _test_scenario(scenario_name: String, p_pos: Vector3, b_pos: Vector3, trigger_cleave: bool) -> void:
	player.global_position = p_pos
	player.velocity = Vector3.ZERO
	player.current_state = player.State.IDLE
	player.current_hp = 9

	boss.global_position = b_pos
	boss.velocity = Vector3.ZERO
	boss.facing_dir_x = -1.0
	boss.current_pattern = boss.Pattern.CHASE

	await physics_frame
	if trigger_cleave:
		boss._execute_triple_cleave()

	var dt := 1.0 / 60.0
	var scenario_overlaps: int = 0
	var scenario_min_sep: float = 999.0
	var scenario_min_gap_px: float = 999.0
	var vis_pcts: Array[float] = []

	# Run for 75 frames (1.25 seconds covering tell, active swing, recovery)
	for f in range(75):
		player._physics_process(dt)
		boss._physics_process(dt)
		await physics_frame

		var p_rect := _get_actor_screen_rect(player, false)
		var b_rect := _get_actor_screen_rect(boss, true)

		var h_sep := absf(player.global_position.x - boss.global_position.x)
		scenario_min_sep = minf(scenario_min_sep, h_sep)
		min_horizontal_sep_m = minf(min_horizontal_sep_m, h_sep)

		# Screen horizontal gap between rects
		var gap_px: float = 0.0
		if p_rect.end.x < b_rect.position.x:
			gap_px = b_rect.position.x - p_rect.end.x
		elif b_rect.end.x < p_rect.position.x:
			gap_px = p_rect.position.x - b_rect.end.x
		else:
			gap_px = -(minf(p_rect.end.x, b_rect.end.x) - maxf(p_rect.position.x, b_rect.position.x))

		scenario_min_gap_px = minf(scenario_min_gap_px, gap_px)
		min_bounding_box_gap_px = minf(min_bounding_box_gap_px, gap_px)

		var intersects := p_rect.intersects(b_rect)
		var overlap_area: float = 0.0
		if intersects:
			var inter := p_rect.intersection(b_rect)
			overlap_area = inter.size.x * inter.size.y

		var p_area := p_rect.size.x * p_rect.size.y
		var vis_pct: float = 100.0 if not intersects else maxf(0.0, 100.0 * (1.0 - (overlap_area / p_area)))
		vis_pcts.append(vis_pct)

		if intersects and overlap_area > (p_area * 0.10):
			critical_overlaps += 1
			scenario_overlaps += 1

		if f % 15 == 0 or (intersects and f % 5 == 0):
			var sample := {
				"scenario": scenario_name,
				"frame": f,
				"player_pos": [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.z, 0.01)],
				"boss_pos": [snappedf(boss.global_position.x, 0.01), snappedf(boss.global_position.z, 0.01)],
				"horizontal_sep_m": snappedf(h_sep, 0.02),
				"screen_gap_px": snappedf(gap_px, 0.1),
				"intersects": intersects,
				"overlap_area_px2": snappedf(overlap_area, 0.1),
				"hero_vis_pct": snappedf(vis_pct, 0.1),
				"boss_pattern": boss.current_pattern,
				"boss_phase": boss.get("pattern_phase")
			}
			trace_samples.append(sample)
			results["samples"].append(sample)

	var avg_vis: float = 0.0
	for v in vis_pcts:
		avg_vis += v
	avg_vis = avg_vis / maxf(1.0, float(vis_pcts.size()))

	var scenario_pass: bool = (scenario_overlaps == 0) and (scenario_min_sep >= 1.95) and (avg_vis >= 95.0)
	print("  -> Scenario '%s': %s (Min Sep: %.2fm, Min Gap: %.1fpx, Avg Vis: %.1f%%, Critical Overlaps: %d)" % [
		scenario_name, "PASSED" if scenario_pass else "FAILED", scenario_min_sep, scenario_min_gap_px, avg_vis, scenario_overlaps
	])

	results["scenarios"][scenario_name] = {
		"passed": scenario_pass,
		"min_horizontal_sep_m": snappedf(scenario_min_sep, 0.02),
		"min_bounding_box_gap_px": snappedf(scenario_min_gap_px, 0.1),
		"avg_hero_silhouette_visibility_pct": snappedf(avg_vis, 0.1),
		"critical_overlaps": scenario_overlaps
	}

func _finish_suite() -> void:
	results["total_frames_analyzed"] = results["scenarios"].size() * 75
	results["critical_overlaps"] = critical_overlaps
	results["min_horizontal_sep_m"] = snappedf(min_horizontal_sep_m, 0.02)
	results["min_bounding_box_gap_px"] = snappedf(min_bounding_box_gap_px, 0.1)

	var all_pass := (critical_overlaps == 0) and (min_horizontal_sep_m >= 1.95)
	for s in results["scenarios"].values():
		if not s["passed"]:
			all_pass = false
	results["all_scenarios_passed"] = all_pass

	var ev_dir := "res://../../STUDIO_V3/evidence/V3-024-R4"
	var f := FileAccess.open(ev_dir + "/SPRITE_VISIBILITY_TRACE.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("[SPRITE_BOUNDS] Saved trace to: ", ev_dir + "/SPRITE_VISIBILITY_TRACE.json")

	if all_pass:
		print("=================================================================")
		print("[V3-024-R4] SPRITE BOUNDS & VISIBILITY SUITE: ALL PASSED (100%)")
		print("=================================================================")
		quit(0)
	else:
		printerr("[V3-024-R4] SPRITE BOUNDS & VISIBILITY SUITE: FAILED!")
		quit(1)
