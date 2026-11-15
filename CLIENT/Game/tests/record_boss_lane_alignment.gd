extends SceneTree
## ProjectKnight V3-024-R4: Boss Overlap Stress Fixture Suite
## Explicit Label: ISOLATED_FIXTURE_STATE_SETUP
## Drives deterministic in-engine combat sequence for 1.0x 60 FPS Movie Maker capture

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null
var camera: Camera3D = null

enum SequenceStep {
	INIT_PAUSE,
	SAME_LANE_CENTER_DUEL,
	PURSUIT_AND_TOP_RAIL_ALIGN,
	Z_DODGE_EVASION_DEMO,
	BOTTOM_LANE_DUEL,
	COMPLETE
}

var current_step: SequenceStep = SequenceStep.INIT_PAUSE
var step_ticks: int = 0
var total_frames: int = 0


func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_launch_sanctuary")


func _launch_sanctuary() -> void:
	_setup_input_actions()

	var packed := load(Stage1ScenePath) as PackedScene
	if packed == null:
		printerr("[RECORD] Failed to load Stage 1 scene")
		quit(1)
		return

	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	stage._start_boss_sanctuary()
	player = stage.get_node_or_null("SideQVPlayer")
	boss = stage.active_boss
	camera = root.get_camera_3d()

	if player == null or boss == null or camera == null:
		printerr("[RECORD] Failed to resolve combatants or camera!")
		quit(1)
		return

	# Setup initial combat state
	player.global_position = Vector3(74.5, 0.05, 0.0)
	player.velocity = Vector3.ZERO
	boss.global_position = Vector3(77.5, 0.05, 0.0)
	boss.velocity = Vector3.ZERO
	boss.facing_dir_x = -1.0

	physics_frame.connect(_on_physics_tick)


func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _release_all_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		Input.action_release(action)


func _on_physics_tick() -> void:
	step_ticks += 1
	total_frames += 1

	match current_step:
		SequenceStep.INIT_PAUSE:
			if step_ticks >= 30: # 0.5s pause
				_transition_to(SequenceStep.SAME_LANE_CENTER_DUEL)

		SequenceStep.SAME_LANE_CENTER_DUEL:
			# Center lane (Z=0.0): both fighters engage at same screen height
			if step_ticks % 30 == 10:
				Input.action_press("attack")
			elif step_ticks % 30 == 13:
				Input.action_release("attack")

			# Micro lateral adjustments to simulate human combat spacing
			if step_ticks % 60 < 20:
				Input.action_press("move_right")
				Input.action_release("move_left")
			elif step_ticks % 60 < 40:
				Input.action_press("move_left")
				Input.action_release("move_right")
			else:
				Input.action_release("move_left")
				Input.action_release("move_right")

			if step_ticks >= 200: # ~3.3 seconds
				_transition_to(SequenceStep.PURSUIT_AND_TOP_RAIL_ALIGN)

		SequenceStep.PURSUIT_AND_TOP_RAIL_ALIGN:
			# Player moves up towards top depth rail (Z=-1.6)
			if step_ticks < 40:
				Input.action_press("move_up")
				Input.action_release("move_down")
			else:
				Input.action_release("move_up")
				# Duel on top rail
				if step_ticks % 35 == 10:
					Input.action_press("attack")
				elif step_ticks % 35 == 13:
					Input.action_release("attack")

			if step_ticks >= 180: # ~3.0 seconds
				_transition_to(SequenceStep.Z_DODGE_EVASION_DEMO)

		SequenceStep.Z_DODGE_EVASION_DEMO:
			# Trigger Boss Charge or Cleave, then Player sidesteps in Z
			if step_ticks == 10:
				boss._execute_shield_charge()
			elif step_ticks >= 20 and step_ticks <= 50:
				# Sidestep down to evade charge along screen
				Input.action_press("move_down")
				Input.action_press("dash")
			elif step_ticks > 50 and step_ticks <= 70:
				Input.action_release("dash")
				Input.action_release("move_down")
			elif step_ticks > 70:
				# Counter attack from flank
				if step_ticks % 25 == 10:
					Input.action_press("attack")
				elif step_ticks % 25 == 13:
					Input.action_release("attack")

			if step_ticks >= 160: # ~2.6 seconds
				_transition_to(SequenceStep.BOTTOM_LANE_DUEL)

		SequenceStep.BOTTOM_LANE_DUEL:
			# Intense tactical exchange on bottom lane (Z=1.2) with guard and strike
			if step_ticks % 40 < 15:
				Input.action_press("guard")
				Input.action_release("attack")
			elif step_ticks % 40 == 20:
				Input.action_release("guard")
				Input.action_press("attack")
			elif step_ticks % 40 == 24:
				Input.action_release("attack")
			else:
				Input.action_release("guard")
				Input.action_release("attack")

			if step_ticks >= 150: # ~2.5 seconds
				_transition_to(SequenceStep.COMPLETE)

		SequenceStep.COMPLETE:
			_release_all_inputs()
			print("[RECORD] All combat alignment sequence steps completed (%d frames recorded)" % total_frames)
			quit(0)


func _transition_to(next_step: SequenceStep) -> void:
	_release_all_inputs()
	current_step = next_step
	step_ticks = 0
	print("[RECORD] Advanced to sequence step: %s at frame %d" % [SequenceStep.keys()[next_step], total_frames])
