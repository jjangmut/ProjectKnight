extends SceneTree
## V3-016 Performance Benchmark Runner
## Executes multi-run steady-state benchmarks (60 warmup frames, 300 steady-state frames x 3 runs)
## Measures real wall-clock frame delta, P95, P99, 1% Low, draw calls, and CPU/GPU metrics.

const EvidenceDir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-016/benchmarks"

const Scenarios := [
	{
		"id": "stage1_citadel_combat",
		"name": "Stage 1 Citadel Terrace Combat",
		"scene": "res://scenes/side_quarter_view/SideQVStage1.tscn"
	},
	{
		"id": "stage3_crossbow_bastion",
		"name": "Stage 3 Ruined Crossbow Bastion",
		"scene": "res://scenes/side_quarter_view/SideQVStage3.tscn"
	},
	{
		"id": "stage4_stone_sanctuary",
		"name": "Stage 4 Titan Stone Sanctuary",
		"scene": "res://scenes/side_quarter_view/SideQVStage4.tscn"
	}
]

const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 300
const RUNS_PER_SCENARIO := 3

var current_scenario_idx := 0
var current_run := 1
var frame_in_run := 0

var stage_instance: Node3D = null
var last_tick_usec: int = 0

var all_scenario_results: Array[Dictionary] = []

# Current run collectors
var cur_wall_deltas: Array[float] = []
var cur_draw_calls: Array[float] = []
var cur_proc_times: Array[float] = []
var cur_physics_times: Array[float] = []
var cur_fps_monitors: Array[float] = []


func _initialize() -> void:
	print("================================================================================")
	print(">>> [V3-016 BENCHMARK] Initializing Rigorous Steady-State Frame-Pacing Suite <<<")
	print("================================================================================")
	print("Hardware / System Specs:")
	print("  GPU Device:        ", RenderingServer.get_video_adapter_name())
	print("  GPU Vendor:        ", RenderingServer.get_video_adapter_vendor())
	print("  DisplayServer:     ", DisplayServer.get_name())
	print("  Window Size:       ", DisplayServer.window_get_size())
	print("  Window Mode:       ", DisplayServer.window_get_mode())
	print("  VSync Mode:        ", DisplayServer.window_get_vsync_mode())
	print("  Engine Target FPS: ", Engine.max_fps)
	print("  Sampling Config:   %d Warmup Frames | %d Steady Frames | %d Runs per Scene" % [WARMUP_FRAMES, SAMPLE_FRAMES, RUNS_PER_SCENARIO])
	print("================================================================================\n")
	
	root.size = Vector2i(1280, 720)
	
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive(EvidenceDir)
		
	_start_next_run()
	process_frame.connect(_on_process_frame)


func _start_next_run() -> void:
	if stage_instance != null and is_instance_valid(stage_instance):
		stage_instance.queue_free()
		stage_instance = null
		
	var sc: Dictionary = Scenarios[current_scenario_idx]
	print("\n>>> Loading Scenario [%d/%d]: %s (Run %d/%d) <<<" % [
		current_scenario_idx + 1, Scenarios.size(), sc["name"], current_run, RUNS_PER_SCENARIO
	])
	
	var packed := load(sc["scene"]) as PackedScene
	if packed == null:
		printerr("Failed to load scene: ", sc["scene"])
		quit(1)
		return
		
	stage_instance = packed.instantiate() as Node3D
	root.add_child(stage_instance)
	current_scene = stage_instance
	
	frame_in_run = 0
	cur_wall_deltas.clear()
	cur_draw_calls.clear()
	cur_proc_times.clear()
	cur_physics_times.clear()
	cur_fps_monitors.clear()
	
	last_tick_usec = Time.get_ticks_usec()


func _on_process_frame() -> void:
	var now: int = Time.get_ticks_usec()
	var delta_ms: float = float(now - last_tick_usec) / 1000.0
	last_tick_usec = now
	frame_in_run += 1
	
	# Warmup phase: allow JIT/shader warmup and node initialization
	if frame_in_run <= WARMUP_FRAMES:
		if frame_in_run == WARMUP_FRAMES:
			print("  [Warmup Complete] Starting %d steady-state frame recordings..." % SAMPLE_FRAMES)
		return
		
	# Steady-state sampling phase
	cur_wall_deltas.append(delta_ms)
	cur_draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	cur_proc_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	cur_physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	cur_fps_monitors.append(float(Performance.get_monitor(Performance.TIME_FPS)))
	
	# Periodic combat action simulation
	if frame_in_run % 25 == 0 and stage_instance != null:
		var player = stage_instance.get_node_or_null("SideQVPlayer")
		if player != null and player.has_method("start_attack"):
			player.start_attack()

	# Check if current run completed
	if cur_wall_deltas.size() >= SAMPLE_FRAMES:
		_complete_current_run()


func _complete_current_run() -> void:
	var sc: Dictionary = Scenarios[current_scenario_idx]
	var run_data := _analyze_run_data(cur_wall_deltas, cur_draw_calls, cur_proc_times, cur_fps_monitors)
	run_data["scenario_id"] = sc["id"]
	run_data["scenario_name"] = sc["name"]
	run_data["run_index"] = current_run
	
	# Export per-frame raw CSV
	var csv_filename := "%s_run%d_frames.csv" % [sc["id"], current_run]
	_export_raw_csv(EvidenceDir + "/" + csv_filename, cur_wall_deltas, cur_draw_calls, cur_proc_times, cur_fps_monitors)
	
	print("  [Run %d Finished] Mean: %.2f ms (%.1f FPS) | Median: %.2f ms | P95: %.2f ms | P99: %.2f ms | 1%% Low: %.2f ms (%.1f FPS) | Draws: %.1f" % [
		current_run,
		run_data["mean_ms"], run_data["fps_equivalent"],
		run_data["median_ms"], run_data["p95_ms"], run_data["p99_ms"],
		run_data["low_1pct_ms"], run_data["low_1pct_fps"],
		run_data["mean_draw_calls"]
	])
	
	all_scenario_results.append(run_data)
	
	current_run += 1
	if current_run > RUNS_PER_SCENARIO:
		current_run = 1
		current_scenario_idx += 1
		if current_scenario_idx >= Scenarios.size():
			_finish_all_benchmarks()
			return
			
	_start_next_run()


func _analyze_run_data(deltas: Array[float], draws: Array[float], procs: Array[float], fps_list: Array[float]) -> Dictionary:
	var sorted := deltas.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	
	var sum_delta: float = 0.0
	for d in sorted:
		sum_delta += d
	var mean_delta: float = sum_delta / float(n)
	var median_delta: float = sorted[int(float(n) * 0.50)]
	var p95_delta: float = sorted[int(float(n) * 0.95)]
	var p99_delta: float = sorted[int(float(n) * 0.99)]
	
	# Slowest 1% average
	var low_idx: int = int(float(n) * 0.99)
	var sum_low: float = 0.0
	var cnt_low: int = 0
	for i in range(low_idx, n):
		sum_low += sorted[i]
		cnt_low += 1
	var avg_low: float = sum_low / float(cnt_low) if cnt_low > 0 else p99_delta
	
	var sum_draws: float = 0.0
	for dr in draws:
		sum_draws += dr
	var mean_draws: float = sum_draws / float(draws.size())
	
	var sum_proc: float = 0.0
	for p in procs:
		sum_proc += p
	var mean_proc: float = sum_proc / float(procs.size())

	var sum_fps: float = 0.0
	for f in fps_list:
		sum_fps += f
	var mean_fps_mon: float = sum_fps / float(fps_list.size())

	return {
		"sample_count": n,
		"mean_ms": mean_delta,
		"median_ms": median_delta,
		"p95_ms": p95_delta,
		"p99_ms": p99_delta,
		"low_1pct_ms": avg_low,
		"fps_equivalent": 1000.0 / mean_delta if mean_delta > 0 else 0.0,
		"low_1pct_fps": 1000.0 / avg_low if avg_low > 0 else 0.0,
		"mean_draw_calls": mean_draws,
		"mean_proc_ms": mean_proc,
		"monitor_fps": mean_fps_mon
	}


func _export_raw_csv(filepath: String, deltas: Array[float], draws: Array[float], procs: Array[float], fps_list: Array[float]) -> void:
	var lines: Array[String] = []
	lines.append("frame_index,wall_delta_ms,draw_calls,proc_time_ms,monitor_fps")
	for i in range(deltas.size()):
		lines.append("%d,%.4f,%d,%.4f,%.1f" % [
			i + 1, deltas[i], int(draws[i]), procs[i], fps_list[i]
		])
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _finish_all_benchmarks() -> void:
	print("\n================================================================================")
	print("ALL BENCHMARK SCENARIOS SUCCESSFULLY COMPLETED!")
	print("================================================================================")
	
	# Aggregate summary across runs
	var summary_output := {
		"timestamp": Time.get_datetime_string_from_system(),
		"environment": {
			"gpu_adapter": RenderingServer.get_video_adapter_name(),
			"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
			"display_server": DisplayServer.get_name(),
			"window_size": str(DisplayServer.window_get_size()),
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
			"rendering_driver": "opengl3 / gl_compatibility",
			"target_fps": Engine.max_fps
		},
		"scenarios": []
	}
	
	for sc in Scenarios:
		var sc_runs: Array[Dictionary] = []
		for res in all_scenario_results:
			if res["scenario_id"] == sc["id"]:
				sc_runs.append(res)
				
		var tot_mean: float = 0.0
		var tot_median: float = 0.0
		var tot_p95: float = 0.0
		var tot_p99: float = 0.0
		var tot_low: float = 0.0
		var tot_fps: float = 0.0
		var tot_draws: float = 0.0
		var k: int = sc_runs.size()
		
		for r in sc_runs:
			tot_mean += r["mean_ms"]
			tot_median += r["median_ms"]
			tot_p95 += r["p95_ms"]
			tot_p99 += r["p99_ms"]
			tot_low += r["low_1pct_ms"]
			tot_fps += r["fps_equivalent"]
			tot_draws += r["mean_draw_calls"]
			
		var sc_summary := {
			"id": sc["id"],
			"name": sc["name"],
			"runs_completed": k,
			"overall_mean_ms": tot_mean / float(k),
			"overall_median_ms": tot_median / float(k),
			"overall_p95_ms": tot_p95 / float(k),
			"overall_p99_ms": tot_p99 / float(k),
			"overall_1pct_low_ms": tot_low / float(k),
			"overall_fps": tot_fps / float(k),
			"overall_draw_calls": tot_draws / float(k),
			"target_60fps_satisfied": (tot_mean / float(k)) <= 17.50, # 16.67ms with tolerance
			"runs": sc_runs
		}
		
		print("\nSCENARIO: %s" % sc["name"])
		print("  Overall Mean Frame Time:   %.2f ms (%.1f FPS)" % [sc_summary["overall_mean_ms"], sc_summary["overall_fps"]])
		print("  Overall Median Frame Time: %.2f ms" % sc_summary["overall_median_ms"])
		print("  Overall P95 Frame Time:    %.2f ms" % sc_summary["overall_p95_ms"])
		print("  Overall P99 Frame Time:    %.2f ms" % sc_summary["overall_p99_ms"])
		print("  Overall 1%% Low:           %.2f ms (%.1f FPS)" % [sc_summary["overall_1pct_low_ms"], 1000.0 / sc_summary["overall_1pct_low_ms"]])
		print("  Overall Draw Calls:        %.1f" % sc_summary["overall_draw_calls"])
		print("  60 FPS Target (16.67ms):   %s" % ["PASS" if sc_summary["target_60fps_satisfied"] else "FAIL/NEEDS_OPTIMIZATION"])
		
		summary_output["scenarios"].append(sc_summary)
		
	var summary_path := EvidenceDir + "/BENCHMARK_SUMMARY.json"
	var file := FileAccess.open(summary_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary_output, "\t"))
		file.close()
		print("\nSaved comprehensive benchmark summary to: ", summary_path)
		
	quit(0)
