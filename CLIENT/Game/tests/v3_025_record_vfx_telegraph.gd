extends SceneTree
## ProjectKnight V3-025: VFX Telegraph Readability Fixture
## Classification: ISOLATED_FIXTURE_STATE_SETUP
## Captures shape-accurate textured attack telegraphs across all enemy types

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var camera: Camera3D = null

enum SequenceStep {
	INIT_PAUSE,
	DEMO_GRUNT_SLASH_ARC,
	DEMO_CROSSBOW_AIM_BEAM,
	DEMO_SHIELD_KNIGHT_BASH_RUNWAY,
	DEMO_BOSS_CHARGE_LANE,
	COMPLETE
}

var current_step: SequenceStep = SequenceStep.INIT_PAUSE
var step_ticks: int = 0
var total_frames: int = 0
var demo_actor: CharacterBody3D = null


func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_setup_scene")


func _setup_scene() -> void:
	_setup_input_actions()

	var packed := load(Stage1ScenePath) as PackedScene
	if packed == null:
		printerr("[RECORD] Failed to load Stage 1 scene")
		quit(1)
		return

	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	player = stage.get_node_or_null("SideQVPlayer")
	camera = root.get_camera_3d()

	# Clear initial enemies to spawn isolated demonstration actors
	for e in stage.enemies:
		if e != null and is_instance_valid(e):
			e.queue_free()
	stage.enemies.clear()

	player.global_position = Vector3(0.0, 0.05, 0.0)
	player.velocity = Vector3.ZERO

	physics_frame.connect(_on_physics_tick)


func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _transition_to(next_step: SequenceStep) -> void:
	current_step = next_step
	step_ticks = 0
	if demo_actor != null and is_instance_valid(demo_actor):
		demo_actor.queue_free()
		demo_actor = null

	match next_step:
		SequenceStep.DEMO_GRUNT_SLASH_ARC:
			player.global_position = Vector3(1.5, 0.05, 0.0)
			demo_actor = stage._spawn_enemy_grunt(Vector3(3.2, 0.05, 0.0), "Demo_Grunt")
		SequenceStep.DEMO_CROSSBOW_AIM_BEAM:
			player.global_position = Vector3(1.5, 0.05, 0.0)
			demo_actor = stage._spawn_enemy_crossbow(Vector3(6.5, 0.05, 0.0), "Demo_Crossbow")
		SequenceStep.DEMO_SHIELD_KNIGHT_BASH_RUNWAY:
			player.global_position = Vector3(1.5, 0.05, 0.0)
			demo_actor = stage._spawn_heavy_shield_knight(Vector3(3.6, 0.05, 0.0), "Demo_ShieldKnight")
		SequenceStep.DEMO_BOSS_CHARGE_LANE:
			player.global_position = Vector3(72.0, 0.05, 0.0)
			stage._start_boss_sanctuary()
			demo_actor = stage.active_boss
			if demo_actor != null:
				demo_actor.global_position = Vector3(81.0, 0.05, 0.0)
				demo_actor.facing_dir_x = -1.0
		SequenceStep.COMPLETE:
			print("[RECORD] VFX Telegraph Readability Demonstration complete (%d frames)." % total_frames)
			quit(0)


func _on_physics_tick() -> void:
	step_ticks += 1
	total_frames += 1

	match current_step:
		SequenceStep.INIT_PAUSE:
			if step_ticks >= 30:
				_transition_to(SequenceStep.DEMO_GRUNT_SLASH_ARC)

		SequenceStep.DEMO_GRUNT_SLASH_ARC:
			# Grunt telegraphs sweeping slash arc (0.28s) -> active crescent (0.14s) -> recovery (0.22s)
			if step_ticks == 30:
				if demo_actor != null:
					demo_actor.global_position = Vector3(2.8, 0.05, 0.0)
					demo_actor._execute_attack(false)
			if step_ticks >= 120:
				_transition_to(SequenceStep.DEMO_CROSSBOW_AIM_BEAM)

		SequenceStep.DEMO_CROSSBOW_AIM_BEAM:
			# Crossbowman shows dynamic tracking aim beam -> locked cue -> crimson fire
			if step_ticks == 20:
				if demo_actor != null:
					demo_actor.target_player = player
					demo_actor.is_aiming = true
					demo_actor.shoot_timer = 0.0
			if step_ticks >= 140:
				_transition_to(SequenceStep.DEMO_SHIELD_KNIGHT_BASH_RUNWAY)

		SequenceStep.DEMO_SHIELD_KNIGHT_BASH_RUNWAY:
			# Heavy Shield Knight runic barrier bash runway strip (0.35s) -> concussive surge (0.18s) -> recovery opening (0.42s)
			if step_ticks == 25:
				if demo_actor != null:
					demo_actor.global_position = Vector3(3.4, 0.05, 0.0)
					demo_actor._execute_attack(false)
			if step_ticks >= 130:
				_transition_to(SequenceStep.DEMO_BOSS_CHARGE_LANE)

		SequenceStep.DEMO_BOSS_CHARGE_LANE:
			# Boss telegraphs 9.5m charge runway lane
			if step_ticks == 25 and demo_actor != null:
				demo_actor.current_pattern = demo_actor.Pattern.CHARGE_WINDUP
				demo_actor.pattern_timer = 0.0
			if step_ticks >= 140:
				_transition_to(SequenceStep.COMPLETE)
