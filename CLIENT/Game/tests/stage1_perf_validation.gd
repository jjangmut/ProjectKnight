extends SceneTree
## TASK-AR-013: Stage 1 성능 측정 방법론 교정 벤치마크 (R1 / R2.1 공용).
##
## 기존 stage1_performance_benchmark.gd 의 측정 오류를 교정한 버전이다.
##  - Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS 는 "직전 1초 창의 단일 프레임 최대값"이며
##    1초에 1회만 갱신된다(main.cpp: process_max / physics_process_max). 매 프레임 평균내면 안 된다.
##    → 본 스크립트는 엔진 시그널 타임스탬프로 프레임별 구간 시간을 직접 측정한다.
##       physics  = 첫 physics_frame → process_frame        (해당 반복의 물리 스텝 전체)
##       process  = process_frame    → frame_pre_draw       (노드 _process + deferred _draw 콜백 포함)
##       render   = frame_pre_draw   → frame_post_draw      (렌더 제출 + swap, VSync 대기 포함 가능)
##       frame    = process_frame    → 다음 process_frame
##  - 스테이지 로드/인스턴스 비용은 워밍업 구간에서 분리 계측하고 본 측정 창에서 제외한다.
##  - VSync / FPS cap 은 벤치마크 실행 중에만 런타임으로 변경한다(project.godot 미변경).
##  - Headless 는 low_processor_usage_mode_sleep_usec(기본 6900us) 슬립이 매 프레임 들어가므로
##    --headless 실행 시 이 값을 0 으로 두어 순수 CPU 프레임 시간을 측정한다(벤치마크 한정).
##  - 게임 로직은 변경하지 않는다. 시나리오 구성용 상태 변경은 이 스크립트 내부에서만 한다.
##
## 사용법 (Godot 4.7.2):
##   Godot --path CLIENT/Game -s res://tests/stage1_perf_validation.gd -- --label=R2.1 --out=<json> --vsync=off
##   Godot --headless --path CLIENT/Game -s res://tests/stage1_perf_validation.gd -- --label=R2.1 --out=<json>

const MEASURE_SECONDS := 8.0
const MIN_FRAMES := 600
const WARMUP_SECONDS := 1.5
const LEGACY_WINDOWS := {"stage_start": 150, "first_combat": 180, "boss_combat": 240}

var label := "unlabeled"
var out_path := ""
var vsync_arg := "off"
var is_headless := false
var stage: Node = null
var results := {}

# 프레임 구간 타임스탬프 (usec)
var _ts_process := 0
var _ts_pre := 0
var _ts_post := 0
var _ts_phys_first := 0
var _phys_ticks_this_iter := 0
var _recording := false
var _rec: Dictionary = {}
var _draw_counts: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.substr(8)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
		elif arg.begins_with("--vsync="):
			vsync_arg = arg.substr(8)
	is_headless = DisplayServer.get_name() == "headless"
	# --- 벤치마크 전용 런타임 설정 (프로젝트 설정 파일은 변경하지 않음) ---
	if is_headless:
		OS.low_processor_usage_mode_sleep_usec = 0
		Engine.max_fps = 0
	elif vsync_arg == "off":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if not is_headless:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	physics_frame.connect(_on_physics_frame)
	process_frame.connect(_on_process_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_run.call_deferred()

# ---------------------------------------------------------------- 시그널 계측
func _on_physics_frame() -> void:
	if _ts_phys_first == 0:
		_ts_phys_first = Time.get_ticks_usec()
	_phys_ticks_this_iter += 1

func _on_process_frame() -> void:
	var now := Time.get_ticks_usec()
	if _recording and _ts_process > 0:
		var frame_ms := float(now - _ts_process) / 1000.0
		var proc_ms := -1.0
		var render_ms := -1.0
		if _ts_pre >= _ts_process:
			proc_ms = float(_ts_pre - _ts_process) / 1000.0
			if _ts_post >= _ts_pre:
				render_ms = float(_ts_post - _ts_pre) / 1000.0
		elif is_headless:
			# headless 에서는 RenderingServer::draw 가 호출되지 않아 pre/post 시그널이 없다.
			# 슬립을 0 으로 두었으므로 프레임 전체가 CPU 시간(물리 제외분 포함)이다.
			proc_ms = frame_ms
		_rec.frame_ms.append(frame_ms)
		_rec.process_ms.append(proc_ms)
		_rec.render_ms.append(render_ms)
		_rec.draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		_rec.primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		_rec.objects_in_frame.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		_rec.legacy_mon_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_rec.legacy_mon_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var vp := root.get_viewport_rid()
		_rec.vp_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		_rec.vp_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		if _phys_ticks_this_iter > 0:
			var phys_ms := float(now - _ts_phys_first) / 1000.0
			_rec.physics_iter_ms.append(phys_ms)
			_rec.physics_ticks += _phys_ticks_this_iter
			_rec.physics_per_tick_ms.append(phys_ms / float(_phys_ticks_this_iter))
	_ts_process = now
	_ts_phys_first = 0
	_phys_ticks_this_iter = 0

func _on_pre_draw() -> void:
	_ts_pre = Time.get_ticks_usec()

func _on_post_draw() -> void:
	_ts_post = Time.get_ticks_usec()

func _new_record() -> Dictionary:
	return {"frame_ms": [], "process_ms": [], "render_ms": [], "draw_calls": [], "primitives": [], "objects_in_frame": [],
		"legacy_mon_process_ms": [], "legacy_mon_physics_ms": [], "vp_cpu_ms": [], "vp_gpu_ms": [],
		"physics_iter_ms": [], "physics_per_tick_ms": [], "physics_ticks": 0}

# ---------------------------------------------------------------- 통계
static func _stats(values: Array) -> Dictionary:
	var v: Array = []
	for x in values:
		if float(x) >= 0.0:
			v.append(float(x))
	if v.is_empty():
		return {"n": 0, "avg": -1.0, "min": -1.0, "max": -1.0, "p50": -1.0, "p95": -1.0, "p99": -1.0, "worst1_avg": -1.0}
	v.sort()
	var total := 0.0
	for x in v:
		total += x
	var n := v.size()
	var worst_n := maxi(1, int(ceil(n * 0.01)))
	var worst_total := 0.0
	for i in range(n - worst_n, n):
		worst_total += v[i]
	return {
		"n": n,
		"avg": total / n,
		"min": v[0],
		"max": v[n - 1],
		"p50": v[clampi(int(ceil(n * 0.50)) - 1, 0, n - 1)],
		"p95": v[clampi(int(ceil(n * 0.95)) - 1, 0, n - 1)],
		"p99": v[clampi(int(ceil(n * 0.99)) - 1, 0, n - 1)],
		"worst1_avg": worst_total / worst_n,
	}

# ---------------------------------------------------------------- 시나리오
func _setup_stage() -> Dictionary:
	for action in ["move_left", "move_right", "jump", "attack", "guard", "dash", "move_down"]:
		Input.action_release(action)
	if is_instance_valid(stage):
		stage.queue_free()
		stage = null
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await process_frame

	var t0 := Time.get_ticks_usec()
	var stage_scene: PackedScene = load("res://scenes/stage/FirstStage.tscn")
	stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage
	var t1 := Time.get_ticks_usec()

	# 벤치마크 중 사망으로 인한 자동 change_scene_to_file 재로드 방지 (테스트 내부 격리)
	var restart_timer = stage.get_node_or_null("RestartTimer")
	if restart_timer != null:
		restart_timer.stop()
		for conn in restart_timer.timeout.get_connections():
			restart_timer.timeout.disconnect(conn.callable)

	var first_frames: Array = []
	for i in range(3):
		var f0 := Time.get_ticks_usec()
		await process_frame
		first_frames.append(float(Time.get_ticks_usec() - f0) / 1000.0)
	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null and "intro_remaining" in pres:
		pres.set("intro_remaining", 0.0)
	return {"instantiate_add_child_ms": float(t1 - t0) / 1000.0, "first_3_frames_ms": first_frames}

func _connect_draw_counters() -> void:
	_draw_counts.clear()
	var stack: Array = [stage]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is CanvasItem and n.get_script() != null and n.has_method("_draw"):
			var key := "%s (%s)" % [str(stage.get_path_to(n)), str(n.get_script().resource_path.get_file())]
			_draw_counts[key] = 0
			n.draw.connect(func(): _draw_counts[key] += 1)

func _canvas_item_census() -> Dictionary:
	var total := 0
	var visible := 0
	var custom_draw := 0
	var stack: Array = [stage]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is CanvasItem:
			total += 1
			if n.is_visible_in_tree():
				visible += 1
			if n.get_script() != null and n.has_method("_draw"):
				custom_draw += 1
	return {"canvas_items": total, "visible_canvas_items": visible, "custom_draw_canvas_items": custom_draw}

func _measure(scene_key: String, setup_info: Dictionary, action: Callable) -> void:
	# 1) 레거시 방식 재현 창: 셋업 직후(워밍업 없음) 기존 스크립트와 동일 프레임 수 동안 모니터 값을 매 프레임 평균
	var legacy_frames: int = LEGACY_WINDOWS[scene_key]
	var legacy_proc := 0.0
	var legacy_phys := 0.0
	var warm_start := Time.get_ticks_usec()
	var warm_max_dt := 0.0
	var prev := Time.get_ticks_usec()
	var f := 0
	while f < legacy_frames or Time.get_ticks_usec() - warm_start < int(WARMUP_SECONDS * 1000000.0):
		if is_instance_valid(stage) and is_instance_valid(stage.player):
			stage.player.current_hp = stage.player.max_hp
			stage.player.is_dead = false
		action.call(float(Time.get_ticks_usec() - warm_start) / 1000000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		warm_max_dt = maxf(warm_max_dt, float(now - prev) / 1000.0)
		prev = now
		if f < legacy_frames:
			legacy_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			legacy_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		f += 1
	# 2) 본 측정 창
	_connect_draw_counters()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_rec = _new_record()
	_ts_process = 0
	_recording = true
	var m_start := Time.get_ticks_usec()
	while _rec.frame_ms.size() < MIN_FRAMES or Time.get_ticks_usec() - m_start < int(MEASURE_SECONDS * 1000000.0):
		if is_instance_valid(stage) and is_instance_valid(stage.player):
			stage.player.current_hp = stage.player.max_hp
			stage.player.is_dead = false
		action.call(float(Time.get_ticks_usec() - warm_start) / 1000000.0)
		await process_frame
	_recording = false
	var wall_s := float(Time.get_ticks_usec() - m_start) / 1000000.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), false)
	var frames: int = _rec.frame_ms.size()
	var ft := _stats(_rec.frame_ms)
	var redraws := {}
	for k in _draw_counts:
		redraws[k] = {"total": _draw_counts[k], "per_frame": float(_draw_counts[k]) / maxf(1.0, float(frames))}
	var player_dead: bool = is_instance_valid(stage.player) and bool(stage.player.get("is_dead"))
	results[scene_key] = {
		"setup": setup_info,
		"warmup_max_frame_ms": warm_max_dt,
		"legacy_method": {
			"frames": legacy_frames,
			"mean_of_TIME_PROCESS_ms": legacy_proc / float(legacy_frames),
			"mean_of_TIME_PHYSICS_PROCESS_ms": legacy_phys / float(legacy_frames),
		},
		"frames": frames,
		"wall_seconds": wall_s,
		"avg_fps": float(frames) / maxf(wall_s, 0.000001),
		"min_fps": 1000.0 / maxf(ft.max, 0.000001),
		"low_1pct_fps": 1000.0 / maxf(ft.worst1_avg, 0.000001),
		"frame_ms": ft,
		"process_ms": _stats(_rec.process_ms),
		"render_ms": _stats(_rec.render_ms),
		"physics_iter_ms": _stats(_rec.physics_iter_ms),
		"physics_per_tick_ms": _stats(_rec.physics_per_tick_ms),
		"physics_ticks": _rec.physics_ticks,
		"draw_calls": _stats(_rec.draw_calls),
		"primitives": _stats(_rec.primitives),
		"objects_in_frame": _stats(_rec.objects_in_frame),
		"viewport_render_cpu_ms": _stats(_rec.vp_cpu_ms),
		"viewport_render_gpu_ms": _stats(_rec.vp_gpu_ms),
		"in_window_TIME_PROCESS_monitor_ms": _stats(_rec.legacy_mon_process_ms),
		"in_window_TIME_PHYSICS_monitor_ms": _stats(_rec.legacy_mon_physics_ms),
		"custom_draw_redraws": redraws,
		"canvas_census": _canvas_item_census(),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"player_dead_at_end": player_dead,
		"player_x_at_end": stage.player.position.x if is_instance_valid(stage.player) else -1.0,
		"raw_frame_ms": _round_array(_rec.frame_ms),
		"raw_process_ms": _round_array(_rec.process_ms),
		"raw_render_ms": _round_array(_rec.render_ms),
	}
	for action_name in ["move_left", "move_right", "jump", "attack", "guard", "dash", "move_down"]:
		Input.action_release(action_name)
	print("  [%s] %s frames=%d avgFPS=%.1f avg=%.3fms p95=%.3fms p99=%.3fms max=%.3fms proc=%.3fms render=%.3fms phys/tick=%.3fms draws=%.1f nodes=%d | legacy proc=%.3f phys=%.3f" % [
		label, scene_key, frames, results[scene_key].avg_fps, ft.avg, ft.p95, ft.p99, ft.max,
		results[scene_key].process_ms.avg, results[scene_key].render_ms.avg, results[scene_key].physics_per_tick_ms.avg,
		results[scene_key].draw_calls.avg, results[scene_key].node_count,
		results[scene_key].legacy_method.mean_of_TIME_PROCESS_ms, results[scene_key].legacy_method.mean_of_TIME_PHYSICS_PROCESS_ms])

static func _round_array(values: Array) -> Array:
	var out: Array = []
	for x in values:
		out.append(snappedf(float(x), 0.001))
	return out

static func _pulse(t: float, period: float, hold: float) -> bool:
	return fmod(t, period) < hold

func _act_stage_start(t: float) -> void:
	if is_instance_valid(stage) and is_instance_valid(stage.player):
		if stage.player.position.x > 820.0:
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif stage.player.position.x < 260.0:
			Input.action_release("move_left")
			Input.action_press("move_right")
		elif not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"):
			Input.action_press("move_right")
	if _pulse(t, 0.6, 0.12):
		Input.action_press("jump")
	else:
		Input.action_release("jump")

func _act_first_combat(t: float) -> void:
	if _pulse(t, 0.25, 0.07):
		Input.action_press("attack")
	else:
		Input.action_release("attack")

func _act_boss(t: float) -> void:
	var phase := fmod(t, 0.7)
	if phase < 0.40:
		Input.action_press("guard")
		Input.action_release("attack")
	else:
		Input.action_release("guard")
		if phase < 0.48:
			Input.action_press("attack")
		else:
			Input.action_release("attack")

func _environment() -> Dictionary:
	var env := {
		"label": label,
		"godot_version": Engine.get_version_info().string,
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"headless": is_headless,
		"max_fps": Engine.max_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"low_processor_usage_mode": OS.low_processor_usage_mode,
		"low_processor_usage_mode_sleep_usec": OS.low_processor_usage_mode_sleep_usec,
		"viewport_size": root.get_visible_rect().size,
		"is_debug_build": OS.is_debug_build(),
		"measure_seconds": MEASURE_SECONDS,
		"min_frames": MIN_FRAMES,
		"warmup_seconds": WARMUP_SECONDS,
	}
	if not is_headless:
		env["vsync_mode"] = ["DISABLED", "ENABLED", "ADAPTIVE", "MAILBOX"][DisplayServer.window_get_vsync_mode()]
		env["window_size"] = DisplayServer.window_get_size()
		env["screen_refresh_rate"] = DisplayServer.screen_get_refresh_rate()
	else:
		env["vsync_mode"] = "N/A (headless, no presentation)"
	return env

func _run() -> void:
	print("\n=== STAGE 1 PERF VALIDATION [%s] ===" % label)
	results["environment"] = _environment()

	# Scene 1: Stage 1 Start (탐험/이동)
	var s1 := await _setup_stage()
	stage.player.position = Vector2(240, 592)
	await _measure("stage_start", s1, _act_stage_start)

	# Scene 2: First Combat
	var s2 := await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(1000, 592)
	stage._start_encounter()
	await process_frame
	await process_frame
	await _measure("first_combat", s2, _act_first_combat)

	# Scene 3: Boss Combat (시나리오 구성용 상태 변경은 테스트 내부에서만 수행)
	var s3 := await _setup_stage()
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.required_count - 1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(9280, 592)
	stage._start_encounter()
	await process_frame
	await process_frame
	var bar := stage.get_node_or_null("HUD/BossHealthBar")
	if bar != null and bar.has_method("snap_to_visible"):
		bar.snap_to_visible()
	await _measure("boss_combat", s3, _act_boss)

	results["environment"]["vsync_mode_at_end"] = results["environment"]["vsync_mode"] if is_headless else ["DISABLED", "ENABLED", "ADAPTIVE", "MAILBOX"][DisplayServer.window_get_vsync_mode()]
	if not out_path.is_empty():
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(results, "  "))
			file.close()
			print("WROTE: ", out_path)
	print("=== PERF VALIDATION DONE [%s] ===" % label)
	if is_instance_valid(stage):
		stage.free()
	quit(0)
