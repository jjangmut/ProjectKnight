extends SceneTree
## Fast Render Bottleneck Diagnostic Probe
## Rapidly toggles each render feature on Stage 1 Start to identify CRITICAL bottlenecks in seconds.

var stage: Node = null

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_run_diagnostics.call_deferred()

func _setup() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
		stage = null
	for c in root.get_children():
		c.queue_free()
	await process_frame
	await process_frame

	var stage_scene := load("res://scenes/stage/FirstStage.tscn")
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

	# 20 frames warmup
	for i in range(20):
		await process_frame

func _measure_avg_ms(frames: int) -> float:
	var total := 0.0
	for i in range(frames):
		var t0 := Time.get_ticks_usec()
		await process_frame
		var t1 := Time.get_ticks_usec()
		total += float(t1 - t0) / 1000.0
	return total / float(frames)

func _run_diagnostics() -> void:
	print("\n=== START FAST RENDER BOTTLENECK DIAGNOSTIC ===")

	await _setup()
	var base_ms := await _measure_avg_ms(90)
	print("0. BASELINE: %.2f ms (%.1f FPS)" % [base_ms, 1000.0 / base_ms])

	# Test A: Glow OFF
	var env_node = stage.get_node_or_null("StageArt/StageWorldEnvironment")
	if env_node != null and env_node.environment != null:
		env_node.environment.glow_enabled = false
		var a_ms := await _measure_avg_ms(90)
		print("A. Glow OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [a_ms, 1000.0 / a_ms, a_ms - base_ms])
		env_node.environment.glow_enabled = true

	# Test B: CanvasModulate OFF
	var mod_node = stage.get_node_or_null("StageArt/StageCanvasModulate")
	if mod_node != null:
		mod_node.visible = false
		var b_ms := await _measure_avg_ms(90)
		print("B. CanvasModulate OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [b_ms, 1000.0 / b_ms, b_ms - base_ms])
		mod_node.visible = true

	# Test C: AtmosphericMotes OFF
	var motes = stage.get_node_or_null("StageArt/AtmosphericMotes")
	if motes != null:
		motes.visible = false
		motes.emitting = false
		var c_ms := await _measure_avg_ms(90)
		print("C. Motes OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [c_ms, 1000.0 / c_ms, c_ms - base_ms])
		motes.visible = true
		motes.emitting = true

	# Test D: Parallax OFF
	var parallax = stage.get_node_or_null("StageArt/ParallaxStageBackdrop")
	if parallax != null:
		parallax.visible = false
		var d_ms := await _measure_avg_ms(90)
		print("D. Parallax OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [d_ms, 1000.0 / d_ms, d_ms - base_ms])
		parallax.visible = true

	# Test E: StageArt redraw OFF
	var stage_art = stage.get_node_or_null("StageArt")
	if stage_art != null:
		stage_art.set_process(false)
		var e_ms := await _measure_avg_ms(90)
		print("E. StageArt process/redraw OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [e_ms, 1000.0 / e_ms, e_ms - base_ms])
		stage_art.set_process(true)

	# Test F: HUD Presentation redraw OFF
	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null:
		pres.visible = false
		pres.set_process(false)
		var f_ms := await _measure_avg_ms(90)
		print("F. HUD Presentation OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [f_ms, 1000.0 / f_ms, f_ms - base_ms])
		pres.visible = true
		pres.set_process(true)

	# Test G: MobileControls OFF
	var mobile = stage.get_node_or_null("MobileControls")
	if mobile != null:
		mobile.visible = false
		mobile.process_mode = Node.PROCESS_MODE_DISABLED
		var g_ms := await _measure_avg_ms(90)
		print("G. MobileControls OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [g_ms, 1000.0 / g_ms, g_ms - base_ms])
		mobile.visible = true
		mobile.process_mode = Node.PROCESS_MODE_INHERIT

	# Test H: ALL Combined OFF
	if env_node != null and env_node.environment != null: env_node.environment.glow_enabled = false
	if mod_node != null: mod_node.visible = false
	if motes != null: motes.visible = false; motes.emitting = false
	if parallax != null: parallax.visible = false
	if stage_art != null: stage_art.set_process(false)
	if pres != null: pres.visible = false; pres.set_process(false)
	if mobile != null: mobile.visible = false; mobile.process_mode = Node.PROCESS_MODE_DISABLED
	var h_ms := await _measure_avg_ms(90)
	print("H. ALL GRAPHIC EXTRAS OFF: %.2f ms (%.1f FPS) | Diff: %+.2f ms" % [h_ms, 1000.0 / h_ms, h_ms - base_ms])

	print("=== DIAGNOSTIC COMPLETE ===")
	quit(0)
