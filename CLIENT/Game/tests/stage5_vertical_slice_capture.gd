extends SceneTree
## Stage 5 Vertical Slice Capture Director for Graphics Quality Review (Pass 005)
## Captures the 7 mandatory representative points of Stage 5 (침묵의 성채):
##   1. 01_stage5_entry.png
##   2. 02_stage5_first_combat.png
##   3. 03_stage5_royal_ruins.png
##   4. 04_stage5_route_choice.png
##   5. 05_stage5_preboss.png
##   6. 06_stage5_boss_combat.png
##   7. 07_stage5_boss_reward.png

var stage: Node = null
var output_dir: String = ""

func _init() -> void:
	output_dir = OS.get_environment("STAGE5_CAPTURE_DIR")
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-005-stage5/before")
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

	var stage_scene := load("res://scenes/stage/FifthStage.tscn")
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
	print("\n=== START STAGE 5 VERTICAL SLICE CAPTURE ===")
	print("Output Directory: ", output_dir)

	# -------------------------------------------------------------------------
	# Scene 1: 시작 지점 (Stage 5 Entry / Silent Citadel Opening)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 1: Stage 5 Entry (01_stage5_entry.png)]")
	await _setup_stage()
	stage.player.position = Vector2(240, 592)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("01_stage5_entry.png")

	# -------------------------------------------------------------------------
	# Scene 2: 첫 전투 (First Mixed Enemy Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 2: First Combat (02_stage5_first_combat.png)]")
	await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(520, 592)
	stage._start_encounter()
	await process_frame
	if not stage.enemies.is_empty() and is_instance_valid(stage.enemies[0]):
		var enemy = stage.enemies[0]
		enemy.position = Vector2(760, 580)
		enemy.set_physics_process(false)
		enemy.state = 2 # ATTACK
		enemy.attack_phase = 0 # WINDUP
		if "_phase_time_remaining" in enemy:
			enemy._phase_time_remaining = 0.35
	stage.player.position = Vector2(550, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	stage.player._start_attack()
	stage.player._attack_time_remaining = stage.player.attack_duration * 0.45
	await process_frame
	await _capture_frame("02_stage5_first_combat.png")

	# -------------------------------------------------------------------------
	# Scene 3: 중반부 왕국 잔해 회랑 (Royal Citadel Ruins Traversal)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 3: Royal Citadel Ruins (03_stage5_royal_ruins.png)]")
	await _setup_stage()
	stage.player.position = Vector2(3600, 480)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("03_stage5_royal_ruins.png")

	# -------------------------------------------------------------------------
	# Scene 4: 갈림길 선택 현판 (Route Choice Sign & High Platforms)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 4: Route Choice (04_stage5_route_choice.png)]")
	await _setup_stage()
	var route_x := 4600.0
	if not stage.route_clusters.is_empty():
		route_x = float(stage.route_clusters[1].left if stage.route_clusters.size() > 1 else stage.route_clusters[0].left)
	stage.player.position = Vector2(route_x - 30.0, 592)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("04_stage5_route_choice.png")

	# -------------------------------------------------------------------------
	# Scene 5: 보스전 직전 회랑 (Pre-Boss Citadel Corridor)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 5: Pre-Boss Citadel (05_stage5_preboss.png)]")
	await _setup_stage()
	stage.player.position = Vector2(9800, 592)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("05_stage5_preboss.png")

	# -------------------------------------------------------------------------
	# Scene 6: Abyssal Arbiter 결전 (Boss Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 6: Abyssal Arbiter Combat (06_stage5_boss_combat.png)]")
	await _setup_stage()
	stage.set_meta("boss_mode", true)
	stage.encounter_index = stage.required_count - 1 # Encounter 7
	stage.player.position = Vector2(10800, 592)
	stage._start_encounter()
	await process_frame
	if not stage.enemies.is_empty() and is_instance_valid(stage.enemies[0]):
		var boss = stage.enemies[0]
		boss.position = Vector2(11150, 580)
		boss.set_physics_process(false)
		if "current_phase" in boss:
			boss.current_phase = 2
		if "state" in boss:
			boss.state = 2 # VOID_SLASH
		if "slash_collision" in boss and boss.slash_collision != null:
			boss.slash_collision.disabled = false
		if "slash_visual" in boss and boss.slash_visual != null:
			boss.slash_visual.color = Color(1.0, 0.2, 0.35, 0.75)
	stage.player.position = Vector2(10960, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("06_stage5_boss_combat.png")

	# -------------------------------------------------------------------------
	# Scene 7: 보스 격파 및 보상 (Boss Reward / Campaign Victory)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 7: Boss Reward (07_stage5_boss_reward.png)]")
	await _setup_stage()
	for i in range(stage.required_count):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(stage.GOAL_X - 100.0, 592)
	stage.stage_state = 1 # CLEARED
	stage.player.get_node("Camera2D").force_update_scroll()
	var pres = stage.get_node_or_null("HUD/Presentation")
	if pres != null and pres.has_method("queue_redraw"):
		pres.queue_redraw()
	await process_frame
	await _capture_frame("07_stage5_boss_reward.png")

	print("\n=== STAGE 5 VERTICAL SLICE CAPTURE COMPLETED ===")
	quit(0)
