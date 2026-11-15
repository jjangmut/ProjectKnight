extends SceneTree
## ProjectKnight V3-026-R1: Pure 2D Attack 1 In-Game Verification & Recording
## Records authentic 2D chibi knight performing Attack 1 (Horizontal Slash)
## inside the authentic 3D Stage 1 castle environment at 1280x720, 60 FPS.

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var camera: Camera3D = null

enum SequenceStep {
	INIT_PAUSE,
	FORWARD_WALK,
	ATTACK_1_SOLO,
	ATTACK_1_RHYTHM,
	ADVANCE_TO_ENEMY,
	ATTACK_1_COMBAT_HIT,
	RECOVERY_DASH_CANCEL,
	STANCE_RESET,
	COMPLETE
}

var current_step: SequenceStep = SequenceStep.INIT_PAUSE
var step_ticks: int = 0
var total_frames: int = 0

func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_launch_recording")

func _launch_recording() -> void:
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

	if player == null:
		player = stage.find_child("SideQVPlayer", true, false) as CharacterBody3D

	if player == null:
		printerr("[RECORD] Failed to resolve SideQVPlayer node!")
		quit(1)
		return

	print("[RECORD] Resolved SideQVPlayer at: ", player.global_position)
	physics_frame.connect(_on_physics_tick)

func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func _release_all_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		Input.action_release(action)

func _transition_to(next_step: SequenceStep) -> void:
	_release_all_inputs()
	current_step = next_step
	step_ticks = 0
	print("[RECORD] Step: %s at frame %d (sim_time=%.2fs)" % [SequenceStep.keys()[next_step], total_frames, total_frames / 60.0])

func _on_physics_tick() -> void:
	step_ticks += 1
	total_frames += 1

	match current_step:
		SequenceStep.INIT_PAUSE:
			# 0.5s idle stance against 3D castle background
			if step_ticks >= 30:
				_transition_to(SequenceStep.FORWARD_WALK)

		SequenceStep.FORWARD_WALK:
			# Walk right across stone castle floor
			Input.action_press("move_right")
			if step_ticks >= 40: # ~0.66s
				_transition_to(SequenceStep.ATTACK_1_SOLO)

		SequenceStep.ATTACK_1_SOLO:
			# Single Attack 1 Horizontal Slash (0.30s total = 18 ticks)
			if step_ticks == 1:
				Input.action_press("attack")
			elif step_ticks == 3:
				Input.action_release("attack")

			# Allow full recovery into idle
			if step_ticks >= 35: # ~0.58s
				_transition_to(SequenceStep.ATTACK_1_RHYTHM)

		SequenceStep.ATTACK_1_RHYTHM:
			# Second standing Attack 1 to show consistency
			if step_ticks == 1:
				Input.action_press("attack")
			elif step_ticks == 3:
				Input.action_release("attack")

			if step_ticks >= 35:
				_transition_to(SequenceStep.ADVANCE_TO_ENEMY)

		SequenceStep.ADVANCE_TO_ENEMY:
			# Move into melee engagement range of corridor enemy
			Input.action_press("move_right")
			if step_ticks >= 50: # ~0.83s
				_transition_to(SequenceStep.ATTACK_1_COMBAT_HIT)

		SequenceStep.ATTACK_1_COMBAT_HIT:
			# Attack 1 hitting enemy: frame-exact contact and hitstop
			if step_ticks == 1:
				Input.action_press("attack")
			elif step_ticks == 3:
				Input.action_release("attack")

			# Cancel recovery window into dash at t=0.20s (~12 ticks)
			if step_ticks == 12:
				_transition_to(SequenceStep.RECOVERY_DASH_CANCEL)

		SequenceStep.RECOVERY_DASH_CANCEL:
			if step_ticks == 1:
				Input.action_press("dash")
			elif step_ticks == 3:
				Input.action_release("dash")

			if step_ticks >= 35:
				_transition_to(SequenceStep.STANCE_RESET)

		SequenceStep.STANCE_RESET:
			# Final settling in stance
			if step_ticks >= 30:
				_transition_to(SequenceStep.COMPLETE)

		SequenceStep.COMPLETE:
			_release_all_inputs()
			print("[RECORD] Pure 2D Attack 1 gameplay recording completed! Total frames: %d" % total_frames)
			quit(0)
