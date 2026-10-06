extends SceneTree
## Stage 4 R1 Ground Slam Capture Director
## Captures:
##   1. 01_ground_slam_windup.png (amber crack, corner brackets, rune ticks)
##   2. 02_ground_slam_active.png (shockwave ring, impact core, stone debris)

var stage: Node = null
var output_dir: String = ""

func _init() -> void:
	output_dir = ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-004-stage4-r1")
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
	for c in root.get_children():
		c.queue_free()
	await process_frame
	await process_frame

	var stage_scene := load("res://scenes/stage/FourthStage.tscn")
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

	await process_frame
	await process_frame

func _run_captures() -> void:
	print("\n=== START STAGE 4 R1 GROUND SLAM CAPTURES ===")

	# -------------------------------------------------------------------------
	# Capture 1: Ground Slam Windup
	# -------------------------------------------------------------------------
	print("\n[Capturing: 01_ground_slam_windup.png]")
	await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(500, 592)
	stage._start_encounter()
	await process_frame
	await process_frame

	var golem = null
	for e in stage.enemies:
		if is_instance_valid(e) and (e.get_meta("art_variant", "") == "golem" or e.get_meta("ground_slam", false) == true):
			golem = e
			break

	if golem != null:
		golem.position = Vector2(740, 580)
		golem.set_physics_process(false)
		golem.state = 2 # ATTACK
		golem.attack_phase = 0 # WINDUP
		golem.is_attack_active = false
		golem._phase_time_remaining = 0.35

	stage.player.position = Vector2(520, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()

	await process_frame
	await _capture_frame("01_ground_slam_windup.png")

	# -------------------------------------------------------------------------
	# Capture 2: Ground Slam Active
	# -------------------------------------------------------------------------
	print("\n[Capturing: 02_ground_slam_active.png]")
	await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(500, 592)
	stage._start_encounter()
	await process_frame
	await process_frame

	golem = null
	for e in stage.enemies:
		if is_instance_valid(e) and (e.get_meta("art_variant", "") == "golem" or e.get_meta("ground_slam", false) == true):
			golem = e
			break

	if golem != null:
		golem.position = Vector2(740, 580)
		golem.set_physics_process(false)
		golem.state = 2 # ATTACK
		golem.attack_phase = 1 # ACTIVE
		golem.is_attack_active = true
		golem._phase_time_remaining = 0.08

	stage.player.position = Vector2(520, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()

	await process_frame
	await _capture_frame("02_ground_slam_active.png")

	print("\n=== ALL R1 CAPTURES COMPLETED SUCCESSFULLY ===")
	quit(0)
