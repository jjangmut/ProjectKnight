extends SceneTree
## TASK-AR-014: Stage 1 Render Feature Isolation Matrix Benchmark
## Systematically tests Baseline and Features A through G (and Combined)
## to classify render bottlenecks (CRITICAL, MAJOR, MODERATE, MINOR).

const FRAMES_PER_SECTOR := 300
var stage: Node = null

var feature_configs := [
	{"id": "BASELINE", "desc": "All Render Features ON (Default)"},
	{"id": "TEST_A", "desc": "WorldEnvironment Glow OFF"},
	{"id": "TEST_B", "desc": "StageCanvasModulate OFF"},
	{"id": "TEST_C", "desc": "AtmosphericMotes (CPUParticles2D) OFF"},
	{"id": "TEST_D", "desc": "ParallaxStageBackdrop OFF"},
	{"id": "TEST_E", "desc": "StageArt Dynamic Draw OFF"},
	{"id": "TEST_F", "desc": "HUD Presentation redraw OFF"},
	{"id": "TEST_G", "desc": "MobileControls OFF"},
	{"id": "COMBINED", "desc": "Combined Top Culprits OFF (Glow + HUD redraw + Motes)"}
]

var matrix_results: Dictionary = {}

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_run_matrix.call_deferred()

func _setup_scene_and_apply_feature(scene_type: String, config: Dictionary) -> void:
	if is_instance_valid(stage):
		stage.queue_free()
		stage = null
	for c in root.get_children():
		c.queue_free()
	await process_frame
	await process_frame

	var stage_scene: PackedScene = load("res://scenes/stage/FirstStage.tscn")
	stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage

	var rt = stage.get_node_or_null("RestartTimer")
	if rt != null:
		rt.stop()
		for conn in rt.timeout.get_connections():
			rt.timeout.disconnect(conn.callable)

	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null and "intro_remaining" in pres:
		pres.set("intro_remaining", 0.0)

	# Configure Sector
	match scene_type:
		"stage_start":
			stage.player.position = Vector2(240, 592)
		"first_combat":
			stage.encounter_index = 0
			stage.player.position = Vector2(1000, 592)
			stage._start_encounter()
		"boss_combat":
			stage.set_meta("boss_mode", true)
			stage.encounter_index = stage.required_count - 1
			for i in range(stage.required_count - 1):
				stage.completed[i] = true
				if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
					stage.gates[i].queue_free()
			stage.player.position = Vector2(9280, 592)
			stage._start_encounter()
			var bar = stage.get_node_or_null("HUD/BossHealthBar")
			if bar != null and bar.has_method("snap_to_visible"):
				bar.snap_to_visible()

	# Warmup 25 frames
	for i in range(25):
		await process_frame

	# Apply Feature Flag
	var id: String = config["id"]
	var env_node = stage.get_node_or_null("StageArt/StageWorldEnvironment")
	var mod_node = stage.get_node_or_null("StageArt/StageCanvasModulate")
	var motes = stage.get_node_or_null("StageArt/AtmosphericMotes")
	var parallax = stage.get_node_or_null("StageArt/ParallaxStageBackdrop")
	var stage_art = stage.get_node_or_null("StageArt")
	var hud_pres = stage.get_node_or_null("HUD/Presentation")
	var mobile = stage.get_node_or_null("MobileControls")

	if id == "TEST_A" or id == "COMBINED":
		if env_node != null and env_node.environment != null:
			env_node.environment.glow_enabled = false
	if id == "TEST_B":
		if mod_node != null:
			mod_node.visible = false
	if id == "TEST_C" or id == "COMBINED":
		if motes != null:
			motes.visible = false
			motes.emitting = false
	if id == "TEST_D":
		if parallax != null:
			parallax.visible = false
	if id == "TEST_E":
		if stage_art != null:
			stage_art.set_process(false)
	if id == "TEST_F" or id == "COMBINED":
		if hud_pres != null:
			hud_pres.visible = false
			hud_pres.set_process(false)
	if id == "TEST_G":
		if mobile != null:
			mobile.visible = false
			mobile.process_mode = Node.PROCESS_MODE_DISABLED

func _measure_sector(frames: int, action: Callable) -> Dictionary:
	var frame_times: Array[float] = []
	var proc_times: Array[float] = []
	var render_times: Array[float] = []
	var draw_calls_list: Array[float] = []

	var ts_proc := 0
	var ts_pre := 0
	var ts_post := 0

	var on_pre := func(): ts_pre = Time.get_ticks_usec()
	var on_post := func(): ts_post = Time.get_ticks_usec()
	RenderingServer.frame_pre_draw.connect(on_pre)
	RenderingServer.frame_post_draw.connect(on_post)

	for i in range(frames):
		if action.is_valid():
			action.call(i)
		ts_proc = Time.get_ticks_usec()
		await process_frame
		var now := Time.get_ticks_usec()

		var dt_ms := float(now - ts_proc) / 1000.0
		var p_ms := float(ts_pre - ts_proc) / 1000.0 if ts_pre >= ts_proc else 0.0
		var r_ms := float(ts_post - ts_pre) / 1000.0 if ts_post >= ts_pre else 0.0

		frame_times.append(dt_ms)
		proc_times.append(p_ms)
		render_times.append(r_ms)
		draw_calls_list.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

	RenderingServer.frame_pre_draw.disconnect(on_pre)
	RenderingServer.frame_post_draw.disconnect(on_post)

	frame_times.sort()
	var total_dt := 0.0
	for dt in frame_times:
		total_dt += dt
	var avg_dt := total_dt / float(frame_times.size())

	var low1_idx: int = maxi(0, int(float(frame_times.size()) * 0.99) - 1)
	var p95_idx: int = maxi(0, int(float(frame_times.size()) * 0.95) - 1)
	var p99_idx: int = maxi(0, int(float(frame_times.size()) * 0.99) - 1)

	var total_proc := 0.0
	for pt in proc_times: total_proc += pt
	var total_rend := 0.0
	for rt in render_times: total_rend += rt
	var total_draws := 0.0
	for d in draw_calls_list: total_draws += d

	return {
		"frames": frames,
		"avg_fps": 1000.0 / maxf(avg_dt, 0.001),
		"min_fps": 1000.0 / maxf(frame_times.back(), 0.001),
		"low_1pct_fps": 1000.0 / maxf(frame_times[low1_idx], 0.001),
		"avg_frame_ms": avg_dt,
		"p95_frame_ms": frame_times[p95_idx],
		"p99_frame_ms": frame_times[p99_idx],
		"max_frame_ms": frame_times.back(),
		"avg_proc_ms": total_proc / float(proc_times.size()),
		"avg_render_ms": total_rend / float(render_times.size()),
		"avg_draw_calls": total_draws / float(draw_calls_list.size())
	}

func _run_matrix() -> void:
	print("\n=======================================================")
	print("STARTING RENDER FEATURE ISOLATION MATRIX (300f / sector)")
	print("=======================================================")

	for cfg in feature_configs:
		var cfg_id: String = cfg["id"]
		print("\n--- Testing Configuration: %s (%s) ---" % [cfg_id, cfg["desc"]])
		matrix_results[cfg_id] = {"desc": cfg["desc"], "sectors": {}}

		for sec in ["stage_start", "first_combat", "boss_combat"]:
			await _setup_scene_and_apply_feature(sec, cfg)
			var action_cb := Callable()
			if sec == "stage_start":
				action_cb = func(f: int):
					if f % 20 == 0: Input.action_press("move_right")
					elif f % 20 == 18: Input.action_release("move_right")
			elif sec == "first_combat":
				action_cb = func(f: int):
					if f % 15 == 0: Input.action_press("attack")
					elif f % 15 == 4: Input.action_release("attack")
			elif sec == "boss_combat":
				action_cb = func(f: int):
					if f % 20 == 0: Input.action_press("guard")
					elif f % 20 == 10: Input.action_release("guard")

			var res := await _measure_sector(FRAMES_PER_SECTOR, action_cb)
			matrix_results[cfg_id]["sectors"][sec] = res
			print("  [%s] Avg FPS: %5.1f | Frame: %5.2f ms | Proc: %4.2f ms | Render: %4.2f ms | Draws: %5.1f" % [
				sec, res.avg_fps, res.avg_frame_ms, res.avg_proc_ms, res.avg_render_ms, res.avg_draw_calls
			])

	_save_reports()
	print("\n=== ISOLATION MATRIX COMPLETE ===")
	quit(0)

func _save_reports() -> void:
	var out_dir := ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-001-r3-perf")
	var raw_dir := out_dir.path_join("raw")
	DirAccess.make_dir_recursive_absolute(raw_dir)

	var json_str := JSON.stringify(matrix_results, "\t")
	var f_json := FileAccess.open(raw_dir.path_join("isolation_matrix.json"), FileAccess.WRITE)
	if f_json != null:
		f_json.store_string(json_str)
		f_json.close()

	# Save FEATURE_ISOLATION_MATRIX.md and BASELINE.md
	var base: Dictionary = matrix_results.get("BASELINE", {}).get("sectors", {})
	var base_s1: Dictionary = base.get("stage_start", {})
	var base_s2: Dictionary = base.get("first_combat", {})
	var base_s3: Dictionary = base.get("boss_combat", {})

	# 1. BASELINE.md
	var base_md := "# [TASK-AR-014] Stage 1 R2.1 Baseline 계측 보고서\n\n"
	base_md += "- **측정 환경**: 1280×720 / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF / Engine.max_fps=0\n"
	base_md += "- **샘플 수**: 구간별 300 프레임 (동일 입력 시뮬레이션)\n\n"
	base_md += "## 1. Baseline 실측 지표 요약\n\n"
	base_md += "| 측정 구간 | 평균 FPS | 1% Low FPS | 평균 프레임타임 | P95 | P99 | Process 시간 | Render 시간 | Draw Calls |\n"
	base_md += "| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n"
	base_md += "| **Stage 1 Start** | **%.1f** | %.1f | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.1f |\n" % [
		base_s1.get("avg_fps", 0.0), base_s1.get("low_1pct_fps", 0.0), base_s1.get("avg_frame_ms", 0.0),
		base_s1.get("p95_frame_ms", 0.0), base_s1.get("p99_frame_ms", 0.0), base_s1.get("avg_proc_ms", 0.0),
		base_s1.get("avg_render_ms", 0.0), base_s1.get("avg_draw_calls", 0.0)
	]
	base_md += "| **First Combat** | **%.1f** | %.1f | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.1f |\n" % [
		base_s2.get("avg_fps", 0.0), base_s2.get("low_1pct_fps", 0.0), base_s2.get("avg_frame_ms", 0.0),
		base_s2.get("p95_frame_ms", 0.0), base_s2.get("p99_frame_ms", 0.0), base_s2.get("avg_proc_ms", 0.0),
		base_s2.get("avg_render_ms", 0.0), base_s2.get("avg_draw_calls", 0.0)
	]
	base_md += "| **Boss Combat** | **%.1f** | %.1f | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.1f |\n" % [
		base_s3.get("avg_fps", 0.0), base_s3.get("low_1pct_fps", 0.0), base_s3.get("avg_frame_ms", 0.0),
		base_s3.get("p95_frame_ms", 0.0), base_s3.get("p99_frame_ms", 0.0), base_s3.get("avg_proc_ms", 0.0),
		base_s3.get("avg_render_ms", 0.0), base_s3.get("avg_draw_calls", 0.0)
	]

	var f_base := FileAccess.open(out_dir.path_join("BASELINE.md"), FileAccess.WRITE)
	if f_base != null:
		f_base.store_string(base_md)
		f_base.close()

	# 2. FEATURE_ISOLATION_MATRIX.md
	var mat_md := "# [TASK-AR-014] A/B Render Feature Isolation Matrix 및 병목 분류 보고서\n\n"
	mat_md += "- **작업**: TASK-AR-014\n"
	mat_md += "- **측정 환경**: RTX 5060 Laptop GPU / 1280×720 / Compatibility Renderer / VSync OFF\n\n"
	mat_md += "## 1. 기능 격리 계측 결과 요약 표 (First Combat 기준)\n\n"
	mat_md += "| 실험 ID | 격리 기능 및 설명 | 평균 FPS | 프레임타임 | 프레임타임 단축 | Render 시간 | 병목 분류 |\n"
	mat_md += "| :--- | :--- | :---: | :---: | :---: | :---: | :---: |\n"

	var base_dt: float = float(base_s2.get("avg_frame_ms", 5.0))
	for cfg in feature_configs:
		var cfg_id: String = cfg["id"]
		var s2_data: Dictionary = matrix_results.get(cfg_id, {}).get("sectors", {}).get("first_combat", {})
		var dt: float = float(s2_data.get("avg_frame_ms", base_dt))
		var delta_pct: float = ((base_dt - dt) / base_dt) * 100.0 if base_dt > 0.0 else 0.0
		var r_time: float = float(s2_data.get("avg_render_ms", 0.0))

		var classification := "BASELINE"
		if cfg_id != "BASELINE":
			if delta_pct >= 20.0: classification = "**CRITICAL (>=20%)**"
			elif delta_pct >= 10.0: classification = "**MAJOR (10~20%)**"
			elif delta_pct >= 5.0: classification = "MODERATE (5~10%)"
			elif delta_pct >= 0.0: classification = "MINOR (<5%)"
			else: classification = "NEGLIGIBLE / NOISE"

		mat_md += "| **%s** | %s | %.1f FPS | %.2f ms | %+.1f%% | %.2f ms | %s |\n" % [
			cfg_id, cfg["desc"], s2_data.get("avg_fps", 0.0), dt, delta_pct, r_time, classification
		]

	mat_md += "\n## 2. 3개 전 구간 기능 격리 전체 매트릭스\n\n"
	mat_md += "| 실험 ID | Stage Start FPS (ms) | First Combat FPS (ms) | Boss Combat FPS (ms) | Draw Calls (평균) |\n"
	mat_md += "| :--- | :---: | :---: | :---: | :---: |\n"
	for cfg in feature_configs:
		var cfg_id: String = cfg["id"]
		var sec_dict: Dictionary = matrix_results.get(cfg_id, {}).get("sectors", {})
		var s1: Dictionary = sec_dict.get("stage_start", {})
		var s2: Dictionary = sec_dict.get("first_combat", {})
		var s3: Dictionary = sec_dict.get("boss_combat", {})
		mat_md += "| **%s** | %.1f (%.2f ms) | %.1f (%.2f ms) | %.1f (%.2f ms) | %.1f / %.1f / %.1f |\n" % [
			cfg_id, s1.get("avg_fps", 0.0), s1.get("avg_frame_ms", 0.0),
			s2.get("avg_fps", 0.0), s2.get("avg_frame_ms", 0.0),
			s3.get("avg_fps", 0.0), s3.get("avg_frame_ms", 0.0),
			s1.get("avg_draw_calls", 0.0), s2.get("avg_draw_calls", 0.0), s3.get("avg_draw_calls", 0.0)
		]

	var f_mat := FileAccess.open(out_dir.path_join("FEATURE_ISOLATION_MATRIX.md"), FileAccess.WRITE)
	if f_mat != null:
		f_mat.store_string(mat_md)
		f_mat.close()
	print("SAVED: BASELINE.md and FEATURE_ISOLATION_MATRIX.md")
