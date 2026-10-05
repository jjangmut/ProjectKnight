extends SceneTree
## TASK-AR-013: Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS 의미 검증 프로브.
##
## 게임 코드는 로드하지 않는다. 엔진 모니터 값의 단위·갱신 주기·집계 방식(최대값/평균)을
## 인위적인 busy-wait 부하로 실측하여 R2 performance.md 의 비정상 수치 원인을 증명한다.
##
## 사용법:
##   Godot --headless --path CLIENT/Game -s res://tests/perf_monitor_semantics_probe.gd -- --out=<json>
##   Godot            --path CLIENT/Game -s res://tests/perf_monitor_semantics_probe.gd -- --out=<json> [--vsync=on|off]

var out_path := ""
var vsync_arg := "keep"
var result := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr(6)
		elif arg.begins_with("--vsync="):
			vsync_arg = arg.substr(8)
	if DisplayServer.get_name() != "headless":
		if vsync_arg == "off":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
		elif vsync_arg == "on":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	# 실험 A: _initialize 에서 예약한 deferred 호출 안의 120ms 부하가 어느 버킷에 집계되는지 확인.
	_busy_deferred.call_deferred()
	_run.call_deferred()

func _busy(usec: int) -> void:
	var t := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t < usec:
		pass

func _busy_deferred() -> void:
	result["exp_a_injected_ms"] = 120.0
	result["exp_a_engine_in_physics_frame"] = Engine.is_in_physics_frame()
	_busy(120000)

func _sample_window(seconds: float) -> Array:
	var rows: Array = []
	var start := Time.get_ticks_usec()
	var prev := start
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		rows.append({
			"t_ms": float(now - start) / 1000.0,
			"frame_dt_ms": float(now - prev) / 1000.0,
			"mon_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"mon_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"mon_fps": Performance.get_monitor(Performance.TIME_FPS),
		})
		prev = now
	return rows

func _summarize(rows: Array) -> Dictionary:
	var changes_p := 0
	var changes_ph := 0
	var last_p := -1.0
	var last_ph := -1.0
	var sum_dt := 0.0
	var sum_p := 0.0
	var sum_ph := 0.0
	var max_p := 0.0
	var max_ph := 0.0
	for r in rows:
		if not is_equal_approx(r.mon_process_ms, last_p):
			changes_p += 1
			last_p = r.mon_process_ms
		if not is_equal_approx(r.mon_physics_ms, last_ph):
			changes_ph += 1
			last_ph = r.mon_physics_ms
		sum_dt += r.frame_dt_ms
		sum_p += r.mon_process_ms
		sum_ph += r.mon_physics_ms
		max_p = maxf(max_p, r.mon_process_ms)
		max_ph = maxf(max_ph, r.mon_physics_ms)
	var n := maxf(1.0, float(rows.size()))
	return {
		"frames": rows.size(),
		"avg_frame_dt_ms": sum_dt / n,
		"legacy_mean_of_mon_process_ms": sum_p / n,
		"legacy_mean_of_mon_physics_ms": sum_ph / n,
		"max_mon_process_ms": max_p,
		"max_mon_physics_ms": max_ph,
		"distinct_process_values": changes_p,
		"distinct_physics_values": changes_ph,
	}

func _run() -> void:
	result["godot_version"] = Engine.get_version_info().string
	result["display_server"] = DisplayServer.get_name()
	result["vsync_mode"] = DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1
	result["max_fps"] = Engine.max_fps
	result["low_processor_usage_mode"] = OS.low_processor_usage_mode
	result["low_processor_usage_mode_sleep_usec"] = OS.low_processor_usage_mode_sleep_usec

	# 실험 A 결과: 초기 1.5초 동안의 모니터 값 (deferred 120ms 부하 직후)
	var a_rows := await _sample_window(1.5)
	result["exp_a_initial_window"] = _summarize(a_rows)

	# 실험 B: 부하 없는 유휴 3초. 모니터 값 갱신 횟수(초당 1회인지)와 프레임 dt 비교.
	var b_rows := await _sample_window(3.0)
	result["exp_b_idle"] = _summarize(b_rows)

	# 실험 C: process_frame 으로 재개된 코루틴에서 1회 100ms 부하 → TIME_PROCESS 가 다음 1초 창 동안 유지되는지.
	await process_frame
	_busy(100000)
	var c_rows := await _sample_window(2.5)
	result["exp_c_after_100ms_process_spike"] = _summarize(c_rows)
	var c_trace: Array = []
	for i in range(0, c_rows.size(), maxi(1, c_rows.size() / 25)):
		c_trace.append([snappedf(c_rows[i].t_ms, 0.1), snappedf(c_rows[i].mon_process_ms, 0.001), snappedf(c_rows[i].frame_dt_ms, 0.001)])
	result["exp_c_trace_t_mon_dt"] = c_trace

	# 실험 D: 매 프레임 2ms 부하(지속 부하) 3초 → 모니터가 '해당 1초 창의 최대 단일 프레임 process 시간'임을 확인.
	var d_rows: Array = []
	var start := Time.get_ticks_usec()
	var prev := start
	while Time.get_ticks_usec() - start < 3000000:
		await process_frame
		_busy(2000)
		var now := Time.get_ticks_usec()
		d_rows.append({"t_ms": float(now - start) / 1000.0, "frame_dt_ms": float(now - prev) / 1000.0,
			"mon_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"mon_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"mon_fps": Performance.get_monitor(Performance.TIME_FPS)})
		prev = now
	result["exp_d_constant_2ms_load"] = _summarize(d_rows)

	print("PERF_PROBE_RESULT ", JSON.stringify(result))
	if not out_path.is_empty():
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(result, "  "))
			f.close()
			print("WROTE: ", out_path)
	quit(0)
