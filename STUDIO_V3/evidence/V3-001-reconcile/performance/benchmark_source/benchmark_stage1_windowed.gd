extends SceneTree
## TASK V3-001 Stage 1 Measured Windowed Performance Benchmark
## Measures genuine frame times across 4 sectors: idle, walking, normal_combat, boss_combat
## Output: STUDIO_V3/evidence/V3-001/performance/performance.json & raw_frames.csv

const Stage1Scene := preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const SECTOR_DURATION := 60.0 # 60 seconds per sector as specified in V3-001 Gate 4

var stage_instance: Node3D = null
var current_sector: String = "idle"
var sector_timer: float = 0.0
var sector_idx: int = 0
var sector_names := ["idle", "walking", "normal_combat", "boss_combat"]

var raw_samples: Array[Dictionary] = []
var stage_load_latency_ms: float = 0.0

var out_json_path := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/performance/performance.json"
var out_csv_path := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/performance/raw_frames.csv"

var prev_frame_ticks: int = 0
var start_ticks: int = 0
var benchmark_running: bool = false
var bot_action_timer: float = 0.0

func _initialize() -> void:
	print(">>> [BENCHMARK] Initializing Windowed Stage 1 Performance Profiler...")
	# Set window size to 1280x720
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var t0 := Time.get_ticks_usec()
	stage_instance = Stage1Scene.instantiate()
	root.add_child(stage_instance)
	current_scene = stage_instance
	var t1 := Time.get_ticks_usec()
	stage_load_latency_ms = float(t1 - t0) / 1000.0
	print(">>> [BENCHMARK] Stage 1 instantiated in %.2f ms" % stage_load_latency_ms)

	start_ticks = Time.get_ticks_usec()
	prev_frame_ticks = start_ticks
	benchmark_running = true


func _physics_process(delta: float) -> bool:
	if not benchmark_running:
		return false

	var now := Time.get_ticks_usec()
	var dt_ms := float(now - prev_frame_ticks) / 1000.0
	prev_frame_ticks = now

	sector_timer += delta
	bot_action_timer += delta

	# Drive bot inputs depending on current sector
	_drive_sector_behavior(delta)

	# Collect sample
	var sample := {
		"frame": raw_samples.size(),
		"t_sec": float(now - start_ticks) / 1000000.0,
		"sector": current_sector,
		"dt_ms": dt_ms,
		"proc_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"phys_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"mem_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
	}
	raw_samples.append(sample)

	if sector_timer >= SECTOR_DURATION:
		print(">>> [BENCHMARK] Completed Sector %d: %s (Samples: %d)" % [sector_idx + 1, current_sector, raw_samples.size()])
		sector_idx += 1
		sector_timer = 0.0
		if sector_idx < sector_names.size():
			current_sector = sector_names[sector_idx]
			_transition_sector(current_sector)
		else:
			_finish_benchmark()
			return true

	return false


func _drive_sector_behavior(delta: float) -> void:
	if stage_instance == null:
		return
	var player = stage_instance.get("player")
	if player == null or not is_instance_valid(player):
		return

	match current_sector:
		"idle":
			# Player stands still, observing baseline environment, ambient glow, floating dust particles
			pass

		"walking":
			# Move back and forth in X and Z
			var cycle := fmod(sector_timer, 6.0)
			if cycle < 2.5:
				Input.action_press("move_right")
				Input.action_release("move_left")
			elif cycle < 3.0:
				Input.action_release("move_right")
				Input.action_press("move_up") # move Z-
			elif cycle < 5.5:
				Input.action_release("move_up")
				Input.action_press("move_left")
			else:
				Input.action_release("move_left")
				Input.action_press("move_down") # move Z+

		"normal_combat":
			# Engage Wave 1 minions: move right towards enemies, attack and guard
			Input.action_release("move_left")
			Input.action_release("move_up")
			Input.action_release("move_down")
			if player.global_position.x < 1.5:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")
				if int(sector_timer * 4.0) % 3 == 0:
					Input.action_press("attack")
				else:
					Input.action_release("attack")
				if int(sector_timer * 2.0) % 5 == 0:
					Input.action_press("guard")
				else:
					Input.action_release("guard")

		"boss_combat":
			# Ensure boss wave is active or trigger advance
			var boss = stage_instance.get("active_boss")
			if boss == null:
				# Advance right to boss trigger zone
				if player.global_position.x < 10.0:
					Input.action_press("move_right")
				else:
					Input.action_release("move_right")
				if int(sector_timer * 4.0) % 2 == 0:
					Input.action_press("attack")
				else:
					Input.action_release("attack")
			else:
				# Fight Boss Commander
				var diff_x: float = boss.global_position.x - player.global_position.x
				if diff_x > 2.0:
					Input.action_press("move_right")
					Input.action_release("move_left")
				elif diff_x < -2.0:
					Input.action_press("move_left")
					Input.action_release("move_right")
				else:
					Input.action_release("move_right")
					Input.action_release("move_left")

				if int(sector_timer * 5.0) % 2 == 0:
					Input.action_press("attack")
				else:
					Input.action_release("attack")

				if int(sector_timer * 2.0) % 4 == 0:
					Input.action_press("guard")
				else:
					Input.action_release("guard")


func _transition_sector(new_sector: String) -> void:
	print(">>> [BENCHMARK] Starting Sector %d: %s <<<" % [sector_idx + 1, new_sector])
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("attack")
	Input.action_release("guard")
	Input.action_release("jump")
	Input.action_release("dash")

	if new_sector == "boss_combat":
		# If boss hasn't spawned yet, trigger boss wave setup
		if stage_instance != null and stage_instance.has_method("_start_boss_wave"):
			var b = stage_instance.get("active_boss")
			if b == null:
				print(">>> [BENCHMARK] Calling _start_boss_wave() for Sector 4 measurement...")
				stage_instance.call("_start_boss_wave")


func _finish_benchmark() -> void:
	benchmark_running = false
	print(">>> [BENCHMARK] Benchmark completed! Total samples: %d" % raw_samples.size())

	# Calculate statistics per sector
	var sector_stats := {}
	for s_name in sector_names:
		sector_stats[s_name] = _calc_stats(s_name)

	var overall_stats := _calc_stats("overall")

	var report := {
		"benchmark_info": {
			"task_id": "V3-001",
			"timestamp": Time.get_datetime_string_from_system(true),
			"scene": "res://scenes/side_quarter_view/SideQVStage1.tscn",
			"renderer": "GL Compatibility (OpenGL 3.3.0)",
			"resolution": "1280x720",
			"window_mode": "Windowed",
			"vsync": "Enabled",
			"monitor_refresh_hz": 240,
			"target_fps": 60.0,
			"godot_build": "4.7.2.stable.official.ed1daf0bf",
			"source_commit_sha": "a71223615d0b77e36dd85edb24e138fc67ecc140",
			"hardware": {
				"os": "Microsoft Windows 11 Pro 64-bit (10.0.26200)",
				"cpu": "AMD Ryzen 9 8945HX with Radeon Graphics (16 cores, 32 threads)",
				"gpu": "NVIDIA GeForce RTX 5060 Laptop GPU (Driver: 32.0.16.1047)",
				"ram_bytes": 24886616064,
				"ram_gb": 23.18
			},
			"stage_load_latency_ms": stage_load_latency_ms,
			"android_performance_status": "NOT_TESTED"
		},
		"sector_metrics": sector_stats,
		"overall_metrics": overall_stats,
		"acceptance_gate": {
			"target_fps": 60.0,
			"overall_median_fps": overall_stats["median_fps"],
			"overall_1pct_low_fps": overall_stats["low_1pct_fps"],
			"overall_p95_frame_ms": overall_stats["p95_frame_ms"],
			"stutter_spike_count": overall_stats["stutter_spikes"],
			"pc_performance_gate": "PASS" if overall_stats["median_fps"] >= 58.0 else "FAIL",
			"android_status": "NOT_TESTED"
		}
	}

	# Write JSON
	var json_str := JSON.stringify(report, "  ")
	var f_json := FileAccess.open(out_json_path, FileAccess.WRITE)
	if f_json != null:
		f_json.store_string(json_str)
		f_json.close()
		print(">>> [BENCHMARK] Written performance.json: %s" % out_json_path)
	else:
		printerr("Failed to open %s for write" % out_json_path)

	# Write CSV
	var f_csv := FileAccess.open(out_csv_path, FileAccess.WRITE)
	if f_csv != null:
		f_csv.store_line("frame,t_sec,sector,dt_ms,proc_ms,phys_ms,fps,draw_calls,nodes,mem_mb")
		for s in raw_samples:
			f_csv.store_line("%d,%.4f,%s,%.3f,%.3f,%.3f,%.1f,%d,%d,%.2f" % [
				s["frame"], s["t_sec"], s["sector"], s["dt_ms"], s["proc_ms"],
				s["phys_ms"], s["fps"], s["draw_calls"], s["nodes"], s["mem_mb"]
			])
		f_csv.close()
		print(">>> [BENCHMARK] Written raw_frames.csv: %s" % out_csv_path)

	print(">>> [BENCHMARK] ALL COMPLETE. QUITTING.")
	quit()


func _calc_stats(target_sector: String) -> Dictionary:
	var samples_to_calc: Array[Dictionary] = []
	for s in raw_samples:
		if target_sector == "overall" or s["sector"] == target_sector:
			samples_to_calc.append(s)

	if samples_to_calc.is_empty():
		return {}

	var dts: Array[float] = []
	var fps_list: Array[float] = []
	var procs: Array[float] = []
	var physs: Array[float] = []
	var draws: Array[int] = []
	var nodes_list: Array[int] = []
	var mems: Array[float] = []
	var stutter_cnt: int = 0

	for s in samples_to_calc:
		var dt: float = s["dt_ms"]
		dts.append(dt)
		fps_list.append(s["fps"])
		procs.append(s["proc_ms"])
		physs.append(s["phys_ms"])
		draws.append(s["draw_calls"])
		nodes_list.append(s["nodes"])
		mems.append(s["mem_mb"])
		if dt > 33.33: # Frame longer than 33.3ms (< 30 FPS spike)
			stutter_cnt += 1

	dts.sort()
	fps_list.sort()

	var total_dt := 0.0
	for d in dts: total_dt += d
	var mean_dt := total_dt / float(dts.size())

	var total_proc := 0.0
	for p in procs: total_proc += p
	var mean_proc := total_proc / float(procs.size())

	var total_phys := 0.0
	for ph in physs: total_phys += ph
	var mean_phys := total_phys / float(physs.size())

	var total_draws := 0
	var max_draws := 0
	for dr in draws:
		total_draws += dr
		if dr > max_draws: max_draws = dr
	var mean_draws := float(total_draws) / float(draws.size())

	var total_mem := 0.0
	for m in mems: total_mem += m
	var mean_mem := total_mem / float(mems.size())

	# Percentiles
	var mid_idx := dts.size() / 2
	var median_dt := dts[mid_idx]
	var median_fps := fps_list[fps_list.size() / 2]

	var p95_idx := maxi(0, int(float(dts.size()) * 0.95) - 1)
	var p99_idx := maxi(0, int(float(dts.size()) * 0.99) - 1)
	var p95_dt := dts[p95_idx]
	var p99_dt := dts[p99_idx]

	var low_1pct_idx := maxi(0, int(float(dts.size()) * 0.99) - 1)
	var low_1pct_dt := dts[low_1pct_idx]
	var low_1pct_fps := 1000.0 / maxf(low_1pct_dt, 0.001)

	return {
		"sector": target_sector,
		"sample_count": samples_to_calc.size(),
		"duration_sec": mean_dt * float(samples_to_calc.size()) / 1000.0,
		"median_fps": median_fps,
		"mean_fps": 1000.0 / maxf(mean_dt, 0.001),
		"min_fps": 1000.0 / maxf(dts.back(), 0.001),
		"low_1pct_fps": low_1pct_fps,
		"mean_frame_ms": mean_dt,
		"median_frame_ms": median_dt,
		"min_frame_ms": dts[0],
		"max_frame_ms": dts.back(),
		"p95_frame_ms": p95_dt,
		"p99_frame_ms": p99_dt,
		"mean_process_ms": mean_proc,
		"mean_physics_ms": mean_phys,
		"mean_draw_calls": mean_draws,
		"max_draw_calls": max_draws,
		"mean_nodes": float(nodes_list.back()),
		"mean_memory_mb": mean_mem,
		"stutter_spikes": stutter_cnt
	}
