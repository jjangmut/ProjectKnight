extends SceneTree
## Project Knight - Side Quarter-View (2D Characters + 3D World) Gameplay Showcase Recorder
## Records the real-time gameplay featuring:
## 1. 2D Paladin Sprite3D movement in full 3D Stone Castle Arena
## 2. 3D Jump & real-time shadow separation
## 3. 3-Hit Combo & 3D Glowing Crescent Sword Beam
## 4. 2D Boss Commander 12m/s Shield Charge & 0.14s Just Parry with 3x counter
## 5. 360-degree Quake Shockwave Ring jump evasion & dashing backstab finisher

const ArenaScene = preload("res://scenes/side_quarter_view/SideQuarterViewArena.tscn")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

enum Phase {
	INTRO_MOVE,
	JUMP_SHOWCASE,
	MELEE_MINION_COMBO,
	SWORD_BEAM_FINISHER,
	BOSS_ENTER,
	PARRY_BOSS_CHARGE,
	COUNTER_STRIKE,
	EVADE_QUAKE_RING,
	FINAL_DASH_SLASH,
	VICTORY_OUTRO
}

var current_phase: Phase = Phase.INTRO_MOVE
var phase_time: float = 0.0
var total_time: float = 0.0

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null
var minion: CharacterBody3D = null


func _init() -> void:
	print(">>> [SIDE-QV RECORDER] Initializing Side Quarter-View Recorder...")
	# 15s Watchdog Fail-Safe
	create_timer(15.0).timeout.connect(func():
		print(">>> [SIDE-QV RECORDER] 15s Watchdog reached. Exiting cleanly.")
		quit(0)
	)
	call_deferred("_start_recording")


func _start_recording() -> void:
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")

	stage = ArenaScene.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	await process_frame
	await process_frame

	player = stage.player
	player.global_position = Vector3(-8.0, 0.1, 1.2)
	print(">>> [SIDE-QV RECORDER] 3D Arena & 2D Characters ready. Commencing recording!")


func _physics_process(delta: float) -> bool:
	if stage == null or player == null or not is_instance_valid(player):
		return false

	phase_time += delta
	total_time += delta

	if total_time >= 10.0:
		print(">>> [SIDE-QV RECORDER] Showcase completed successfully (10.0s).")
		quit(0)
		return true

	match current_phase:
		Phase.INTRO_MOVE:
			# Paladin moves right (+X) and slightly inward (-Z) in 3D arena
			Input.action_press("move_right")
			Input.action_press("move_up")
			if phase_time >= 1.2:
				Input.action_release("move_right")
				Input.action_release("move_up")
				_set_phase(Phase.JUMP_SHOWCASE)

		Phase.JUMP_SHOWCASE:
			# 3D Jump showcasing real-time shadow separation from 2D sprite
			if phase_time < 0.1:
				player.start_jump()
			elif phase_time >= 0.8:
				_set_phase(Phase.MELEE_MINION_COMBO)

		Phase.MELEE_MINION_COMBO:
			# Position minion in front of 2D paladin
			if minion == null or not is_instance_valid(minion):
				if not stage.enemies.is_empty():
					minion = stage.enemies[0]
					minion.global_position = player.global_position + Vector3(2.2, 0.1, 0.0)

			player.facing_dir_x = 1.0

			# 2-Hit Combo
			if phase_time >= 0.1 and phase_time < 0.2:
				player.attack_cooldown = 0.0
				player.start_attack()
			elif phase_time >= 0.35 and phase_time < 0.45:
				player.attack_cooldown = 0.0
				player.start_attack()
			elif phase_time >= 0.65:
				_set_phase(Phase.SWORD_BEAM_FINISHER)

		Phase.SWORD_BEAM_FINISHER:
			# Finisher strike -> fires 3D glowing sword beam
			if phase_time < 0.1:
				player.attack_cooldown = 0.0
				player.start_attack() # Step 3 Finisher -> Sword Beam
			elif phase_time >= 0.6:
				# Clear minions to trigger Wave 2 (Boss Wave)
				for e in stage.enemies.duplicate():
					if is_instance_valid(e) and e != stage.active_boss:
						e._die()
				_set_phase(Phase.BOSS_ENTER)

		Phase.BOSS_ENTER:
			# 2D Boss Commander spawns in 3D arena
			if is_instance_valid(stage.active_boss):
				boss = stage.active_boss
				boss.max_hp = 50
				boss.current_hp = 50
				boss.global_position = player.global_position + Vector3(7.5, 0.1, 0.0)
				boss.current_pattern = SideQVBossClass.Pattern.IDLE
				boss.pattern_timer = 999.0 # Manual choreography control
			
			if phase_time >= 0.8:
				_set_phase(Phase.PARRY_BOSS_CHARGE)

		Phase.PARRY_BOSS_CHARGE:
			# Boss initiates 12.0 m/s Shield Charge towards player!
			if phase_time < 0.1:
				if is_instance_valid(boss):
					boss._execute_shield_charge()
			elif phase_time >= 0.38 and not player.is_guarding:
				# Player raises 3D runic shield right into parry window!
				player.start_guard()
			elif phase_time >= 0.52 and is_instance_valid(boss) and boss.current_pattern == SideQVBossClass.Pattern.SHIELD_CHARGE:
				# Clash! Just Parry triggered!
				boss.apply_parry_stun(2.5)
				boss.velocity = Vector3.ZERO
				player.release_guard()
				player.counter_attack_buff = true
				player.counter_buff_timer = 3.5
				# Camera shake impact
				stage.camera.add_trauma(0.55)
				_set_phase(Phase.COUNTER_STRIKE)

		Phase.COUNTER_STRIKE:
			# Paladin executes devastating 3x counter strike on stunned boss
			if phase_time >= 0.2 and phase_time < 0.3:
				player.attack_cooldown = 0.0
				player.start_attack()
				if is_instance_valid(boss):
					boss.receive_hit(26, Vector3(1, 0, 0)) # Boss enters Phase 2 Enrage!
			elif phase_time >= 1.0:
				_set_phase(Phase.EVADE_QUAKE_RING)

		Phase.EVADE_QUAKE_RING:
			# Phase 2 Boss unleashes 360 Quake Shockwave Ring
			if phase_time < 0.1:
				if is_instance_valid(boss):
					boss._execute_quake_ring()
			elif phase_time >= 0.25 and is_zero_approx(player.velocity.y):
				# Player mid-air jumps over the expanding red quake ring!
				player.start_jump()
				Input.action_press("move_right")
			elif phase_time >= 0.9:
				Input.action_release("move_right")
				_set_phase(Phase.FINAL_DASH_SLASH)

		Phase.FINAL_DASH_SLASH:
			# Dash past boss and deliver ultimate combo finisher
			if phase_time < 0.1:
				if is_instance_valid(boss):
					player.move_direction = Vector3(1, 0, 0)
				player.start_dash()
			elif phase_time >= 0.35 and phase_time < 0.45:
				player.attack_cooldown = 0.0
				player.start_attack()
				if is_instance_valid(boss):
					boss.receive_hit(40, Vector3(1, 0, 0))
			elif phase_time >= 1.2:
				_set_phase(Phase.VICTORY_OUTRO)

		Phase.VICTORY_OUTRO:
			player.velocity = Vector3.ZERO

	return false


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_time = 0.0
