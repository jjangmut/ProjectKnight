extends SceneTree
## Project Knight - 5-Stage Side Quarter-View Commercial Release Gameplay Showcase Recorder
## Records the full production-quality showcase across ALL 5 STAGES:
## Stage 1 (Citadel Terrace Gate) -> Stage 2 (Beastwood Gorge) -> Stage 3 (Ruined Bastion) -> Stage 4 (Stone Sanctuary) -> Stage 5 (Silent Abyssal Citadel)

const Stage1Scene = preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const Stage2Scene = preload("res://scenes/side_quarter_view/SideQVStage2.tscn")
const Stage3Scene = preload("res://scenes/side_quarter_view/SideQVStage3.tscn")
const Stage4Scene = preload("res://scenes/side_quarter_view/SideQVStage4.tscn")
const Stage5Scene = preload("res://scenes/side_quarter_view/SideQVStage5.tscn")

enum ShowcasePhase {
	STAGE_1_CITADEL,
	STAGE_2_FOREST,
	STAGE_3_BASTION,
	STAGE_4_SANCTUARY,
	STAGE_5_ABYSS,
	CAMPAIGN_VICTORY
}

var current_phase: ShowcasePhase = ShowcasePhase.STAGE_1_CITADEL
var phase_timer: float = 0.0
var total_timer: float = 0.0

var current_stage: Node3D = null
var current_player: CharacterBody3D = null
var current_boss: CharacterBody3D = null


func _init() -> void:
	print(">>> [MASTER SHOWCASE RECORDER] Initializing 5-Stage Showcase Recorder...")
	# 25s Watchdog Fail-Safe Timer
	create_timer(25.0).timeout.connect(func():
		print(">>> [MASTER SHOWCASE RECORDER] Watchdog reached. Clean exit.")
		quit(0)
	)
	call_deferred("_start_showcase")


func _start_showcase() -> void:
	_setup_inputs()
	_load_showcase_stage(ShowcasePhase.STAGE_1_CITADEL)


func _setup_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _load_showcase_stage(phase: ShowcasePhase) -> void:
	current_phase = phase
	phase_timer = 0.0

	if current_stage != null and is_instance_valid(current_stage):
		current_stage.queue_free()
		current_stage = null

	match phase:
		ShowcasePhase.STAGE_1_CITADEL:
			current_stage = Stage1Scene.instantiate()
		ShowcasePhase.STAGE_2_FOREST:
			current_stage = Stage2Scene.instantiate()
		ShowcasePhase.STAGE_3_BASTION:
			current_stage = Stage3Scene.instantiate()
		ShowcasePhase.STAGE_4_SANCTUARY:
			current_stage = Stage4Scene.instantiate()
		ShowcasePhase.STAGE_5_ABYSS:
			current_stage = Stage5Scene.instantiate()

	root.add_child(current_stage)
	current_scene = current_stage

	await process_frame
	await process_frame

	current_player = current_stage.player
	if phase != ShowcasePhase.STAGE_1_CITADEL:
		if current_stage.active_boss == null and current_stage.has_method("_start_boss_wave"):
			current_stage._start_boss_wave()
	await process_frame
	current_boss = current_stage.active_boss
	print(">>> [MASTER SHOWCASE RECORDER] Loaded Stage Phase: %d <<<" % phase)


func _physics_process(delta: float) -> bool:
	if current_stage == null or current_player == null or not is_instance_valid(current_player):
		return false

	phase_timer += delta
	total_timer += delta

	match current_phase:
		ShowcasePhase.STAGE_1_CITADEL:
			# Stage 1 Flow: Smooth Run -> Melee Minion with Overhead HP bar -> Thrust Finish Beam -> Advance Prompt -> Boss Emergence & Parry
			if phase_timer < 0.7:
				Input.action_press("move_right")
			elif phase_timer < 1.2:
				Input.action_release("move_right")
				if current_player.attack_cooldown <= 0.0:
					current_player.start_attack() # Linear Thrust Spear 1 & 2
			elif phase_timer < 1.8:
				if current_player.attack_cooldown <= 0.0 and current_player.combo_step < 3:
					current_player.start_attack() # Strike 3 Finisher -> Piercing Lance Beam!
				if phase_timer >= 1.55 and not current_stage.enemies.is_empty():
					for e in current_stage.enemies.duplicate():
						if is_instance_valid(e) and e.has_method("receive_hit"):
							e.receive_hit(10, Vector3.ZERO)
			elif phase_timer < 2.3:
				# Advance forward to trigger Boss
				Input.action_press("move_right")
				if current_stage.current_wave == 1 and current_stage.active_boss == null:
					current_stage._start_boss_wave()
					current_boss = current_stage.active_boss
			elif phase_timer < 2.8:
				Input.action_release("move_right")
				if is_instance_valid(current_boss):
					current_boss.global_position = current_player.global_position + Vector3(3.8, 0, 0)
					if current_boss.has_method("_execute_shield_charge"):
						current_boss._execute_shield_charge()
			elif phase_timer < 3.4:
				current_player.start_guard() # Just parry
				if is_instance_valid(current_boss) and current_boss.has_method("apply_parry_stun"):
					current_boss.apply_parry_stun(2.0)
					current_stage.camera.add_trauma(0.5)
			elif phase_timer >= 3.8:
				current_player.release_guard()
				_load_showcase_stage(ShowcasePhase.STAGE_2_FOREST)

		ShowcasePhase.STAGE_2_FOREST:
			# Stage 2: Beast Chieftain pounce leap & emerald roar
			if phase_timer < 0.6:
				Input.action_press("move_right")
			elif phase_timer < 1.2:
				Input.action_release("move_right")
				current_player.start_jump() # Jump over beast minion
			elif phase_timer < 2.2:
				if is_instance_valid(current_boss):
					current_boss.global_position = current_player.global_position + Vector3(4.0, 0, 0)
					if current_boss.has_method("_execute_pounce_leap"):
						current_boss._execute_pounce_leap(current_player.global_position)
			elif phase_timer < 2.8:
				current_player.start_dash() # Dash dodge under leap
				if is_instance_valid(current_boss) and current_boss.has_method("receive_hit"):
					current_boss.receive_hit(15, Vector3(1, 0, 0)) # Triggers Roar
			elif phase_timer >= 3.4:
				_load_showcase_stage(ShowcasePhase.STAGE_3_BASTION)

		ShowcasePhase.STAGE_3_BASTION:
			# Stage 3: Crossbow Commander fan volley & caltrop trap dodge
			if phase_timer < 0.8:
				Input.action_press("move_right")
			elif phase_timer < 1.5:
				Input.action_release("move_right")
				if is_instance_valid(current_boss):
					current_boss.global_position = current_player.global_position + Vector3(5.0, 0, 0)
					if current_boss.has_method("_execute_fan_volley"):
						current_boss._execute_fan_volley()
			elif phase_timer < 2.2:
				current_player.start_guard() # Deflect crossbow bolts
			elif phase_timer < 2.8:
				current_player.release_guard()
				current_player.start_jump() # Mid-air jump
				if current_player.attack_cooldown <= 0.0:
					current_player.start_attack() # Mid-air down thrust
			elif phase_timer >= 3.4:
				_load_showcase_stage(ShowcasePhase.STAGE_4_SANCTUARY)

		ShowcasePhase.STAGE_4_SANCTUARY:
			# Stage 4: Golem Guardian Ground Slam & Rock Spikes eruption
			if phase_timer < 0.6:
				Input.action_press("move_right")
			elif phase_timer < 1.6:
				Input.action_release("move_right")
				if is_instance_valid(current_boss):
					current_boss.global_position = current_player.global_position + Vector3(4.5, 0, 0)
					if current_boss.has_method("_execute_ground_slam"):
						current_boss._execute_ground_slam()
						current_stage.camera.add_trauma(0.6)
			elif phase_timer < 2.2:
				current_player.start_jump() # Jump above ground slam shockwave!
			elif phase_timer < 2.8:
				if current_player.attack_cooldown <= 0.0:
					current_player.start_attack() # Golden finisher strike
			elif phase_timer >= 3.4:
				_load_showcase_stage(ShowcasePhase.STAGE_5_ABYSS)

		ShowcasePhase.STAGE_5_ABYSS:
			# Stage 5: Abyssal Arbiter Dark Crescent Wave vs Holy Wave, Shadow Blink & Victory!
			if phase_timer < 0.8:
				Input.action_press("move_right")
			elif phase_timer < 1.6:
				Input.action_release("move_right")
				if is_instance_valid(current_boss):
					current_boss.global_position = current_player.global_position + Vector3(5.5, 0, 0)
					if current_boss.has_method("_execute_dark_crescent_wave"):
						current_boss._execute_dark_crescent_wave()
			elif phase_timer < 2.2:
				if current_player.attack_cooldown <= 0.0:
					current_player.start_attack() # Holy Sword Beam fired! Clash!
			elif phase_timer < 2.8:
				if is_instance_valid(current_boss):
					if current_boss.has_method("_execute_shadow_blink_strike"):
						current_boss._execute_shadow_blink_strike()
			elif phase_timer < 3.4:
				current_player.facing_dir_x = -1.0 # Turn and just parry
				current_player.start_guard()
				if is_instance_valid(current_boss) and current_boss.has_method("apply_parry_stun"):
					current_boss.apply_parry_stun(3.0)
					current_stage.camera.add_trauma(0.8)
			elif phase_timer < 4.2:
				current_player.release_guard()
				if current_player.attack_cooldown <= 0.0:
					current_player.start_attack() # Decisive 3x Counter Finisher
				if is_instance_valid(current_boss):
					current_boss.current_hp = 0
					if current_boss.has_method("_die"):
						current_boss._die()
			elif phase_timer >= 4.8:
				print(">>> [MASTER SHOWCASE RECORDER] Showcase completed successfully! <<<")
				quit(0)

	return false
