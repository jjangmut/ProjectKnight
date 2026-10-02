extends SceneTree
## Stage 1 Vertical Slice Capture Director for Graphics Quality Review
## Captures the 5 mandatory representative points of Stage 1 with high fidelity.

var stage: Node = null
var output_dir: String = ""

const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")

func _init() -> void:
	output_dir = OS.get_environment("STAGE1_CAPTURE_DIR")
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://../../ART_REVIEW/graphics-pass-001/after")
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
	print("\n=== START STAGE 1 VERTICAL SLICE CAPTURE ===")
	print("Output Directory: ", output_dir)

	# -------------------------------------------------------------------------
	# Scene 1: 시작 지점 (Stage 1 Start / Spawn Point)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 1: Stage 1 Spawn & Opening Vista]")
	await _setup_stage()
	stage.player.position = Vector2(240, 592)
	stage.player.velocity = Vector2.ZERO
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("01_stage1_start.png")

	# -------------------------------------------------------------------------
	# Scene 2: 첫 일반 전투 (First Combat Encounter)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 2: First Combat Encounter]")
	await _setup_stage()
	stage.encounter_index = 0
	stage.player.position = Vector2(620, 592)
	stage._start_encounter()
	await process_frame
	if not stage.enemies.is_empty() and is_instance_valid(stage.enemies[0]):
		stage.enemies[0].position = Vector2(740, 590)
		stage.enemies[0].set_physics_process(false)
	stage.player.position = Vector2(670, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	# Trigger attack for dynamic action frame
	stage.player._start_attack()
	stage.player._attack_time_remaining = stage.player.attack_duration * 0.45
	await process_frame
	await _capture_frame("02_stage1_first_combat.png")

	# -------------------------------------------------------------------------
	# Scene 3: 상층/하층 분기 (Upper/Lower Route Choice)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 3: Route Choice (Upper Platforms vs Lower Direct)]")
	await _setup_stage()
	# Move to the start of opt_01 (Watchdeck route: 1895 - 3155)
	stage.encounter_index = 1
	for i in range(1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(2150, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await process_frame
	await _capture_frame("03_stage1_route_choice.png")

	# -------------------------------------------------------------------------
	# Scene 4: BossCommander 전투 (Boss Combat)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 4: BossCommander Combat Encounter]")
	await _setup_stage()
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.required_count - 1):
		stage.completed[i] = true
		if i < stage.gates.size() and is_instance_valid(stage.gates[i]):
			stage.gates[i].queue_free()
	stage.player.position = Vector2(9200, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	stage._start_encounter()
	await process_frame
	await process_frame
	# Find boss in enemies or spawn directly if encounter spawning handles it
	var boss_found: Node2D = null
	for e in stage.enemies:
		if is_instance_valid(e) and (e.is_in_group("boss") or e is BossCommanderClass):
			boss_found = e
			break
	if boss_found == null:
		# If boss hasn't spawned yet in wave 2, instantiate and place
		boss_found = BossCommanderClass.new()
		stage.add_child(boss_found)
		stage.enemies.append(boss_found)
	boss_found.position = Vector2(9450, 590)
	boss_found.set_physics_process(false)
	stage.player.position = Vector2(9280, 592)
	stage.player.facing_direction = 1.0
	stage.player.get_node("Camera2D").force_update_scroll()
	# Boss in threatening heavy attack windup pose
	if boss_found.has_method("_start_attack"):
		boss_found.call("_start_attack", 1, 0.5, 0.25, true)
	await process_frame
	await _capture_frame("04_stage1_boss_combat.png")

	# -------------------------------------------------------------------------
	# Scene 5: 보스 처치 직후 / 유물 보상 카드 (Boss Defeat & Relic Reward)
	# -------------------------------------------------------------------------
	print("\n[Capturing Scene 5: Boss Defeat & Stage Clear Relic Card]")
	await _setup_stage()
	stage.player.position = Vector2(9300, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	# Trigger stage cleared state
	stage.call("_finish", 1) # StageState.CLEARED = 1
	await process_frame
	await process_frame
	await _capture_frame("05_stage1_boss_defeat_reward.png")

	if is_instance_valid(stage):
		stage.free()

	print("\n=== ALL 5 SCENES CAPTURED SUCCESSFULLY ===")
	quit(0)
