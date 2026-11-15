extends SceneTree
## ProjectKnight V3-025: Enemy Role Counterplay Demonstration Fixture
## Classification: ISOLATED_FIXTURE_STATE_SETUP
## Captures distinct tactical counterplay across all enemy roles

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var camera: Camera3D = null

enum SequenceStep {
	INIT_PAUSE,
	DEMO_GRUNT_WHIFF_PUNISH,
	DEMO_CROSSBOW_PARRY_EVADE,
	DEMO_SHIELD_KNIGHT_FLANK_PUNISH,
	DEMO_BOSS_Z_DODGE_EVASION,
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


func _release_all_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		Input.action_release(action)


func _transition_to(next_step: SequenceStep) -> void:
	_release_all_inputs()
	current_step = next_step
	step_ticks = 0
	if demo_actor != null and is_instance_valid(demo_actor):
		demo_actor.queue_free()
		demo_actor = null

	match next_step:
		SequenceStep.DEMO_GRUNT_WHIFF_PUNISH:
			player.global_position = Vector3(1.2, 0.05, 0.0)
			demo_actor = stage._spawn_enemy_grunt(Vector3(2.8, 0.05, 0.0), "Counter_Grunt")
		SequenceStep.DEMO_CROSSBOW_PARRY_EVADE:
			player.global_position = Vector3(1.2, 0.05, 0.0)
			demo_actor = stage._spawn_enemy_crossbow(Vector3(6.2, 0.05, 0.0), "Counter_Crossbow")
		SequenceStep.DEMO_SHIELD_KNIGHT_FLANK_PUNISH:
			player.global_position = Vector3(1.2, 0.05, 0.0)
			demo_actor = stage._spawn_heavy_shield_knight(Vector3(3.2, 0.05, 0.0), "Counter_ShieldKnight")
		SequenceStep.DEMO_BOSS_Z_DODGE_EVASION:
			player.global_position = Vector3(73.0, 0.05, 0.0)
			stage._start_boss_sanctuary()
			demo_actor = stage.active_boss
			if demo_actor != null:
				demo_actor.global_position = Vector3(81.5, 0.05, 0.0)
				demo_actor.facing_dir_x = -1.0
		SequenceStep.COMPLETE:
			print("[RECORD] Enemy Role Counterplay Demonstration complete (%d frames)." % total_frames)
			quit(0)


func _on_physics_tick() -> void:
	step_ticks += 1
	total_frames += 1

	match current_step:
		SequenceStep.INIT_PAUSE:
			if step_ticks >= 30:
				_transition_to(SequenceStep.DEMO_GRUNT_WHIFF_PUNISH)

		SequenceStep.DEMO_GRUNT_WHIFF_PUNISH:
			# 1. Grunt winds up attack -> player steps back during tell, dashes forward and punishes during recovery opening!
			if step_ticks == 20:
				demo_actor._execute_attack(false)
			elif step_ticks == 25:
				Input.action_press("move_left") # back away from arc tell
			elif step_ticks == 42:
				Input.action_release("move_left")
				Input.action_press("move_right") # close in on recovery opening
				Input.action_press("attack") # whiff punish
			elif step_ticks == 46:
				Input.action_release("attack")
			elif step_ticks == 56:
				Input.action_press("attack") # combo 2
			elif step_ticks == 60:
				Input.action_release("attack")
				Input.action_release("move_right")
			if step_ticks >= 120:
				_transition_to(SequenceStep.DEMO_CROSSBOW_PARRY_EVADE)

		SequenceStep.DEMO_CROSSBOW_PARRY_EVADE:
			# 2. Crossbowman fires bolt -> player executes Just Parry clashing bolt with blue spark burst
			if step_ticks == 15:
				demo_actor.target_player = player
				demo_actor.shoot_timer = 0.40 # trigger fire
			# Bolt flies at 14m/s; reaches player (~5m away) in ~0.35s (~21 ticks)
			if step_ticks == 34:
				Input.action_press("guard") # Just Parry
			elif step_ticks == 44:
				Input.action_release("guard")
			if step_ticks >= 110:
				_transition_to(SequenceStep.DEMO_SHIELD_KNIGHT_FLANK_PUNISH)

		SequenceStep.DEMO_SHIELD_KNIGHT_FLANK_PUNISH:
			# 3. Heavy Shield Knight blocks frontal spam (sparks/sound) -> player sidesteps Z flank (dz=0.5m) and slashes exposed side
			if step_ticks == 15:
				Input.action_press("move_right")
				Input.action_press("attack") # frontal attack blocked by shield!
			elif step_ticks == 20:
				Input.action_release("attack")
			elif step_ticks == 28:
				# Sidestep into flanking lane
				Input.action_release("move_right")
				Input.action_press("move_down") # move in +Z
			elif step_ticks == 44:
				Input.action_release("move_down")
				Input.action_press("move_right")
				Input.action_press("attack") # Flank attack bypasses shield! Full damage!
			elif step_ticks == 48:
				Input.action_release("attack")
				Input.action_release("move_right")
			if step_ticks >= 130:
				_transition_to(SequenceStep.DEMO_BOSS_Z_DODGE_EVASION)

		SequenceStep.DEMO_BOSS_Z_DODGE_EVASION:
			# 4. Boss charges along center lane -> player Z-dodges to top rail (-Z) -> charge harmlessly passes
			if step_ticks == 20 and demo_actor != null:
				demo_actor.current_pattern = demo_actor.Pattern.CHARGE_WINDUP
				demo_actor.pattern_timer = 0.0
			elif step_ticks == 35:
				Input.action_press("move_up") # dodge in Z
				Input.action_press("dash")
			elif step_ticks == 42:
				Input.action_release("dash")
			elif step_ticks == 55:
				Input.action_release("move_up")
			if step_ticks >= 130:
				_transition_to(SequenceStep.COMPLETE)
