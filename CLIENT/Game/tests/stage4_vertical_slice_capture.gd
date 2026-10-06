extends SceneTree
## Stage 4 Vertical Slice Capture Director for Graphics Quality Review (Pass 004)
## Captures the 6 mandatory representative points of Stage 4 (돌의 성소):
##   1. 01_stage4_entry.png
##   2. 02_stage4_first_golem.png
##   3. 03_stage4_mid_sanctuary.png
##   4. 04_stage4_route_choice.png
##   5. 05_stage4_boss_combat.png
##   6. 06_stage4_boss_reward.png

var stage: Node = null
var output_dir: String = ""

func _init() -> void:
	output_dir = OS.get_environment("STAGE4_CAPTURE_DIR")
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-004-stage4/before")
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
	print("\n=== START STAGE 4 VERTICAL SLICE CAPTURE ===")
	print("Output Directory: ", output_dir)

	# -------------------------------------------------------------------------
	# Scene 1: 시작 지점 (Stage 4 Entry / Stone Sanctuary Opening)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 1: Stage 4 Entry (01_stage4_entry.png)]")
	await _setup_stage()
	stage.player.position = Vector2(240, 592)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("01_stage4_entry.png")

	# -------------------------------------------------------------------------
	# Scene 2: 첫 GroundSlamGolem 전투 (First Golem Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 2: First Golem Combat (02_stage4_first_golem.png)]")
	await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(520, 592)
	stage._start_encounter()
	await process_frame
	if not stage.enemies.is_empty() and is_instance_valid(stage.enemies[0]):
		var golem = stage.enemies[0]
		golem.position = Vector2(760, 580)
		golem.set_physics_process(false)
		golem.state = 2 # ATTACK
		golem.attack_phase = 0 # WINDUP
		golem._phase_time_remaining = 0.35
	stage.player.position = Vector2(550, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	stage.player._start_attack()
	stage.player._attack_time_remaining = stage.player.attack_duration * 0.45
	await process_frame
	await _capture_frame("02_stage4_first_golem.png")

	# -------------------------------------------------------------------------
	# Scene 3: 중반부 성소 전경 (Mid Sanctuary Traversal)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 3: Mid Sanctuary (03_stage4_mid_sanctuary.png)]")
	await _setup_stage()
	stage.encounter_index = 3
	for i in range(3):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(4600, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("03_stage4_mid_sanctuary.png")

	# -------------------------------------------------------------------------
	# Scene 4: 상층 성소 vs 하층 회랑 분기 (Route Choice)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 4: Route Choice (04_stage4_route_choice.png)]")
	await _setup_stage()
	stage.encounter_index = 1
	for i in range(1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(1650, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("04_stage4_route_choice.png")

	# -------------------------------------------------------------------------
	# Scene 5: Ancient Golem Guardian 보스 결전 (Boss Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 5: Ancient Golem Guardian Boss Combat (05_stage4_boss_combat.png)]")
	await _setup_stage()
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.required_count - 1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(10150, 592)
	stage._start_encounter()
	await process_frame
	var boss = null
	for e in stage.enemies:
		if is_instance_valid(e) and e.is_in_group("boss"):
			boss = e
			break
	if boss != null:
		boss.position = Vector2(10550, 580)
		boss.set_physics_process(false)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	var bar := stage.get_node_or_null("HUD/BossHealthBar")
	if bar != null and bar.has_method("snap_to_visible"):
		bar.snap_to_visible()
	await process_frame
	await _capture_frame("05_stage4_boss_combat.png")

	# -------------------------------------------------------------------------
	# Scene 6: 보스 격파 및 스테이지 클리어 보상 (Boss Defeat & Reward)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 6: Boss Defeat & Stage Clear Reward (06_stage4_boss_reward.png)]")
	await _setup_stage()
	for i in range(stage.required_count):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(stage.GOAL_X - 100.0, 592)
	stage.stage_state = 1 # CLEARED
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("06_stage4_boss_reward.png")

	print("\n=== ALL 6 STAGE 4 SCENES CAPTURED SUCCESSFULLY ===")
	quit(0)
