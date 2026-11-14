extends SceneTree
## Visual Recording Driver for Boss Corner & Depth Rail Escape Scenarios
## Runs in SceneTree physics frames so Godot Movie Maker records every frame at 60 FPS

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null
var camera: Camera3D = null

enum ScenarioStep {
	INIT_PAUSE,
	CORNER_1_SETUP, CORNER_1_RUN,
	CORNER_2_SETUP, CORNER_2_RUN,
	CORNER_3_SETUP, CORNER_3_RUN,
	CORNER_4_SETUP, CORNER_4_RUN,
	TOP_RAIL_SETUP, TOP_RAIL_RUN,
	BOTTOM_RAIL_SETUP, BOTTOM_RAIL_RUN,
	DASH_PHASE_SETUP, DASH_PHASE_RUN,
	COMPLETE
}

var current_step: ScenarioStep = ScenarioStep.INIT_PAUSE
var step_ticks: int = 0
var total_recorded_frames: int = 0

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

	physics_frame.connect(_on_physics_tick)

func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func _release_all_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		Input.action_release(action)

func _on_physics_tick() -> void:
	total_recorded_frames += 1
	step_ticks += 1

	if player == null or boss == null:
		return

	match current_step:
		ScenarioStep.INIT_PAUSE:
			if step_ticks >= 15:
				current_step = ScenarioStep.CORNER_1_SETUP
				step_ticks = 0

		ScenarioStep.CORNER_1_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(70.0, 0.1, -2.4)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(72.2, 0.1, -1.8)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.CHASE
			boss.pattern_timer = 3.0
			current_step = ScenarioStep.CORNER_1_RUN
			step_ticks = 0

		ScenarioStep.CORNER_1_RUN:
			Input.action_press("move_right")
			Input.action_press("move_down") # into center (+Z)
			if step_ticks >= 45:
				_release_all_inputs()
				current_step = ScenarioStep.CORNER_2_SETUP
				step_ticks = 0

		ScenarioStep.CORNER_2_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(85.0, 0.1, -2.4)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(82.8, 0.1, -1.8)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.CHASE
			boss.pattern_timer = 3.0
			current_step = ScenarioStep.CORNER_2_RUN
			step_ticks = 0

		ScenarioStep.CORNER_2_RUN:
			Input.action_press("move_left")
			Input.action_press("move_down") # into center (+Z)
			if step_ticks >= 45:
				_release_all_inputs()
				current_step = ScenarioStep.CORNER_3_SETUP
				step_ticks = 0

		ScenarioStep.CORNER_3_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(70.0, 0.1, 2.4)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(72.2, 0.1, 1.8)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.CHASE
			boss.pattern_timer = 3.0
			current_step = ScenarioStep.CORNER_3_RUN
			step_ticks = 0

		ScenarioStep.CORNER_3_RUN:
			Input.action_press("move_right")
			Input.action_press("move_up") # into center (-Z)
			if step_ticks >= 45:
				_release_all_inputs()
				current_step = ScenarioStep.CORNER_4_SETUP
				step_ticks = 0

		ScenarioStep.CORNER_4_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(85.0, 0.1, 2.4)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(82.8, 0.1, 1.8)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.CHASE
			boss.pattern_timer = 3.0
			current_step = ScenarioStep.CORNER_4_RUN
			step_ticks = 0

		ScenarioStep.CORNER_4_RUN:
			Input.action_press("move_left")
			Input.action_press("move_up") # into center (-Z)
			if step_ticks >= 45:
				_release_all_inputs()
				current_step = ScenarioStep.TOP_RAIL_SETUP
				step_ticks = 0

		ScenarioStep.TOP_RAIL_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(77.5, 0.1, -2.45)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(77.5, 0.1, -1.6)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.CHASE
			boss.pattern_timer = 3.0
			current_step = ScenarioStep.TOP_RAIL_RUN
			step_ticks = 0

		ScenarioStep.TOP_RAIL_RUN:
			Input.action_press("move_down") # straight in +Z
			if step_ticks >= 45:
				_release_all_inputs()
				current_step = ScenarioStep.BOTTOM_RAIL_SETUP
				step_ticks = 0

		ScenarioStep.BOTTOM_RAIL_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(77.5, 0.1, 2.45)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(77.5, 0.1, 1.6)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.CHASE
			boss.pattern_timer = 3.0
			current_step = ScenarioStep.BOTTOM_RAIL_RUN
			step_ticks = 0

		ScenarioStep.BOTTOM_RAIL_RUN:
			Input.action_press("move_up") # straight in -Z
			if step_ticks >= 45:
				_release_all_inputs()
				current_step = ScenarioStep.DASH_PHASE_SETUP
				step_ticks = 0

		ScenarioStep.DASH_PHASE_SETUP:
			_release_all_inputs()
			player.global_position = Vector3(70.0, 0.1, 0.0)
			player.velocity = Vector3.ZERO
			boss.global_position = Vector3(72.0, 0.1, 0.0)
			boss.velocity = Vector3.ZERO
			boss.current_pattern = boss.Pattern.IDLE
			player.facing_attack_dir = Vector3(1.0, 0.0, 0.0)
			player.facing_dir_x = 1.0
			player.start_dash()
			current_step = ScenarioStep.DASH_PHASE_RUN
			step_ticks = 0

		ScenarioStep.DASH_PHASE_RUN:
			if step_ticks >= 30:
				_release_all_inputs()
				current_step = ScenarioStep.COMPLETE
				step_ticks = 0

		ScenarioStep.COMPLETE:
			_release_all_inputs()
			print("[RECORD] Completed all visual corner escape demonstrations! Total frames: ", total_recorded_frames)
			quit(0)
