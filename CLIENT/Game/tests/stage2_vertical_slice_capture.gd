extends SceneTree
## Stage 2 Vertical Slice Capture Director for Graphics Quality Review (Pass 002)
## Captures the 6 mandatory representative points of Stage 2 (야수숲):
##   1. 01_stage2_entry.png
##   2. 02_stage2_first_beast.png
##   3. 03_stage2_mid_forest.png
##   4. 04_stage2_route_choice.png
##   5. 05_stage2_boss_combat.png
##   6. 06_stage2_boss_reward.png

var stage: Node = null
var output_dir: String = ""

func _init() -> void:
	output_dir = OS.get_environment("STAGE2_CAPTURE_DIR")
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-002-stage2/before")
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

	var stage_scene := load("res://scenes/stage/SecondStage.tscn")
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
	print("\n=== START STAGE 2 VERTICAL SLICE CAPTURE ===")
	print("Output Directory: ", output_dir)

	# -------------------------------------------------------------------------
	# Scene 1: 시작 지점 (Stage 2 Entry / Wildwood Vista)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 1: Stage 2 Entry (01_stage2_entry.png)]")
	await _setup_stage()
	stage.player.position = Vector2(240, 592)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("01_stage2_entry.png")

	# -------------------------------------------------------------------------
	# Scene 2: 첫 Charging Beast 전투 (First Beast Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 2: First Beast Combat (02_stage2_first_beast.png)]")
	await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(620, 592)
	stage._start_encounter()
	await process_frame
	if not stage.enemies.is_empty() and is_instance_valid(stage.enemies[0]):
		var beast = stage.enemies[0]
		beast.position = Vector2(880, 590)
		beast.set_physics_process(false)
		beast.state = 2 # ATTACK
		beast.attack_phase = 0 # WINDUP
		beast._attack_direction = -1.0
		beast._phase_time_remaining = 0.35
	stage.player.position = Vector2(650, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	# Trigger attack for dynamic action composition
	stage.player._start_attack()
	stage.player._attack_time_remaining = stage.player.attack_duration * 0.45
	await process_frame
	await _capture_frame("02_stage2_first_beast.png")

	# -------------------------------------------------------------------------
	# Scene 3: 중반부 숲/지형 전경 (Mid Forest)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 3: Mid Forest (03_stage2_mid_forest.png)]")
	await _setup_stage()
	stage.encounter_index = 2
	for i in range(2):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(4150, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("03_stage2_mid_forest.png")

	# -------------------------------------------------------------------------
	# Scene 4: 상층/하층 분기 (Upper/Lower Route Choice)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 4: Route Choice (04_stage2_route_choice.png)]")
	await _setup_stage()
	stage.encounter_index = 1
	for i in range(1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(2150, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("04_stage2_route_choice.png")

	# -------------------------------------------------------------------------
	# Scene 5: Beast Chieftain 보스 결전 (Boss Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 5: Beast Chieftain Boss Combat (05_stage2_boss_combat.png)]")
	await _setup_stage()
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.required_count - 1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(9800, 592)
	stage._start_encounter()
	await process_frame
	var boss = null
	for e in stage.enemies:
		if is_instance_valid(e) and e.is_in_group("boss"):
			boss = e
			break
	if boss != null:
		boss.position = Vector2(10150, 590)
		boss.set_physics_process(false)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	var bar := stage.get_node_or_null("HUD/BossHealthBar")
	if bar != null and bar.has_method("snap_to_visible"):
		bar.snap_to_visible()
	await process_frame
	await _capture_frame("05_stage2_boss_combat.png")

	# -------------------------------------------------------------------------
	# Scene 6: 보스 격파 및 스테이지 클리어 보상 (Boss Defeat & Reward)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 6: Boss Defeat & Stage Clear Reward (06_stage2_boss_reward.png)]")
	await _setup_stage()
	for i in range(stage.required_count):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(stage.GOAL_X - 100.0, 592)
	stage.stage_state = 1 # CLEARED
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("06_stage2_boss_reward.png")

	print("\n=== ALL 6 STAGE 2 SCENES CAPTURED SUCCESSFULLY ===")
	quit(0)
