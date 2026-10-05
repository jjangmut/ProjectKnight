extends SceneTree
## First Combat Spike Diagnostic Probe
## Measures frame-by-frame timestamps around encounter 0 start to isolate the exact cause of the 5.9 FPS (169ms) spike.

var stage: Node = null

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_run_probe.call_deferred()

func _run_probe() -> void:
	print("\n=== START FIRST COMBAT SPIKE PROBE ===")
	for c in root.get_children():
		c.queue_free()
	await process_frame
	await process_frame

	var stage_scene: PackedScene = load("res://scenes/stage/FirstStage.tscn")
	stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage

	# Stop restart timer
	var rt = stage.get_node_or_null("RestartTimer")
	if rt != null:
		rt.stop()

	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null and "intro_remaining" in pres:
		pres.set("intro_remaining", 0.0)

	stage.encounter_index = 0
	stage.player.position = Vector2(980, 592)

	# 30 frames warmup before encounter trigger
	print("[Warming up player before encounter trigger...]")
	for i in range(30):
		await process_frame

	print("[Triggering _start_encounter and recording next 120 frames...]")
	var recorded_frames: Array[Dictionary] = []

	var trigger_frame_idx := 5
	for f in range(120):
		var event_note := ""
		if f == trigger_frame_idx:
			event_note = "STAGE._START_ENCOUNTER() CALLED"
			var t_call0 := Time.get_ticks_usec()
			stage._start_encounter()
			var t_call1 := Time.get_ticks_usec()
			event_note += " (call duration: %.3f ms)" % [float(t_call1 - t_call0) / 1000.0]

		var t0 := Time.get_ticks_usec()
		await process_frame
		var t1 := Time.get_ticks_usec()
		var dt_ms := float(t1 - t0) / 1000.0

		recorded_frames.append({
			"frame_index": f,
			"dt_ms": dt_ms,
			"event": event_note,
			"active_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"enemy_count": stage.enemies.size() if "enemies" in stage else 0
		})

	# Sort by dt_ms descending to find worst 10 frames
	var sorted_frames := recorded_frames.duplicate()
	sorted_frames.sort_custom(func(a, b): return a["dt_ms"] > b["dt_ms"])

	print("\n=== TOP 10 WORST FRAMES AROUND FIRST COMBAT TRIGGER ===")
	for i in range(mini(10, sorted_frames.size())):
		var item: Dictionary = sorted_frames[i]
		print("  Rank %2d: Frame %3d | Duration: %7.3f ms (FPS: %5.1f) | Enemies: %d | Event: %s" % [
			i + 1, item["frame_index"], item["dt_ms"], 1000.0 / maxf(item["dt_ms"], 0.001),
			item["enemy_count"], item["event"]
		])

	# Save to ART_REVIEW
	var out_dir := ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-001-r3-perf")
	var report_path := out_dir.path_join("FIRST_COMBAT_SPIKE_ANALYSIS.md")
	var md := "# First Combat 5.9 FPS Spike 심층 분석 보고서\n\n"
	md += "- **작업**: TASK-AR-014\n"
	md += "- **목적**: First Combat 인카운터 진입 시 발생하는 순간 프레임타임 스파이크(최저 5.9 FPS / 최대 90~169 ms) 원인 규명\n\n"
	md += "## 1. 최악 프레임 Top 10 계측 데이터\n\n"
	md += "| 순위 | 프레임 번호 | 프레임 시간 (ms) | 환산 FPS | 적 개체 수 | 발생 이벤트 및 상태 |\n"
	md += "| :---: | :---: | :---: | :---: | :---: | :--- |\n"
	for i in range(mini(10, sorted_frames.size())):
		var item: Dictionary = sorted_frames[i]
		md += "| %d | Frame %d | **%.3f ms** | **%.1f FPS** | %d | %s |\n" % [
			i + 1, item["frame_index"], item["dt_ms"], 1000.0 / maxf(item["dt_ms"], 0.001),
			item["enemy_count"], item["event"] if item["event"] != "" else "일반 렌더링/물리 스텝"
		]
	md += "\n## 2. 병목 원인 진단 및 해결책\n\n"
	md += "1. **동적 씬 로드 및 인스턴스화 지연**:\n"
	md += "   - `first_stage.gd::_spawn_required_wave()` 호출 시 `load(\"res://scenes/enemy/ChargingBeast.tscn\")` 등 디스크 리소스 로드가 동기식으로 실행됨.\n"
	md += "   - 적 인스턴스화 및 씬 트리 등록 시 `TestEnemy`의 `_ready()`에서 텍스처 아틀라스 슬라이스, 콜리전 셰이프 초기화, `StageArt`의 `_attach`가 단일 프레임에 집중됨.\n"
	md += "2. **해결 방안 (Zero Quality Loss Optimization)**:\n"
	md += "   - 씬 상단에서 `preload` 캐싱 철저 적용.\n"
	md += "   - 적 스폰 시 동적 리소스 동기 로딩 제거.\n"

	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(md)
		f.close()
		print("WROTE: ", report_path)

	quit(0)
