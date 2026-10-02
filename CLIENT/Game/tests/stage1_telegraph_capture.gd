extends SceneTree
## Stage 1 Boss Telegraph HDR Calibration Capture
## Captures BossCommander's attack telegraph across bright and dark backgrounds at windup start & late.

var stage: Node = null
var output_dir: String = ""

const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")

func _init() -> void:
	output_dir = ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-001-r2/telegraph")
	DirAccess.make_dir_recursive_absolute(output_dir)

func _initialize() -> void:
	_run_captures.call_deferred()

func _capture_frame(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null:
		var target_path := output_dir.path_join(filename)
		img.save_png(target_path)
		print("CAPTURED: ", target_path)

func _setup_stage() -> void:
	if is_instance_valid(stage):
		stage.free()
	var stage_scene := load("res://scenes/stage/FirstStage.tscn")
	stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage
	await process_frame
	await process_frame
	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null and "intro_remaining" in pres:
		pres.set("intro_remaining", 0.0)

func _run_captures() -> void:
	print("\n=== START BOSS TELEGRAPH HDR CALIBRATION CAPTURE ===")
	print("Output Directory: ", output_dir)

	# 1. Bright Background - Windup Start
	print("\n[Capturing 1: Bright Background - Windup Start]")
	await _setup_stage()
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.required_count - 1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(9280, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	stage._start_encounter()
	await process_frame
	await process_frame
	var bar := stage.get_node_or_null("HUD/BossHealthBar")
	if bar != null and bar.has_method("snap_to_visible"):
		bar.snap_to_visible()

	var boss_found: Node2D = null
	for e in stage.enemies:
		if is_instance_valid(e) and (e.is_in_group("boss") or e is BossCommanderClass):
			boss_found = e
			break
	if boss_found != null:
		boss_found.position = Vector2(9450, 580)
		boss_found.set_physics_process(false)
		if boss_found.has_method("_start_attack"):
			boss_found.call("_start_attack", 1, 0.60, 0.25, true) # SHIELD_BASH windup start
	await process_frame
	await process_frame
	await _capture_frame("telegraph_bright_start.png")

	# 2. Bright Background - Windup Late
	print("\n[Capturing 2: Bright Background - Windup Late]")
	if boss_found != null:
		boss_found.set("_phase_timer", 0.08) # Near active trigger
	await process_frame
	await process_frame
	await _capture_frame("telegraph_bright_late.png")

	# 3. Dark Background - Windup Start
	print("\n[Capturing 3: Dark Background - Windup Start]")
	await _setup_stage()
	# Apply dark ambience via CanvasModulate to simulate dark/indoor ruins lighting
	var stage_art = stage.get_node_or_null("StageArt")
	var modulate_node = stage_art.get_node_or_null("StageCanvasModulate") if stage_art != null else null
	if modulate_node != null:
		modulate_node.color = Color(0.28, 0.28, 0.38, 1.0)
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.required_count - 1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(9280, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	stage._start_encounter()
	await process_frame
	await process_frame
	var bar2 := stage.get_node_or_null("HUD/BossHealthBar")
	if bar2 != null and bar2.has_method("snap_to_visible"):
		bar2.snap_to_visible()

	boss_found = null
	for e in stage.enemies:
		if is_instance_valid(e) and (e.is_in_group("boss") or e is BossCommanderClass):
			boss_found = e
			break
	if boss_found != null:
		boss_found.position = Vector2(9450, 580)
		boss_found.set_physics_process(false)
		if boss_found.has_method("_start_attack"):
			boss_found.call("_start_attack", 1, 0.60, 0.25, true)
	await process_frame
	await process_frame
	await _capture_frame("telegraph_dark_start.png")

	# 4. Dark Background - Windup Late
	print("\n[Capturing 4: Dark Background - Windup Late]")
	if boss_found != null:
		boss_found.set("_phase_timer", 0.08)
	await process_frame
	await process_frame
	await _capture_frame("telegraph_dark_late.png")

	print("\n=== ALL TELEGRAPH CALIBRATION SCENES CAPTURED ===")
	quit(0)
