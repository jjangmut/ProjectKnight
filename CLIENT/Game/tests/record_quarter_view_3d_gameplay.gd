extends SceneTree
## Project Knight - True Quarter-View 3D Live Gameplay Showcase Recorder
## Records the real-time 3D Quarter-View action gameplay featuring:
## 1. Mixamo Animated 3D Paladin smooth movement & turning
## 2. 3D Jump & real-time shadow projection
## 3. 3-Hit Combo & 360-degree glowing crescent sword beam
## 4. 3D Boss Commander shield charge & 0.14s Just Parry with 3x counter strike
## 5. 360-degree Quake Shockwave Ring jump evasion & dashing backstab finisher

const Arena3DScene = preload("res://scenes/quarter_view_3d/QuarterViewArena3D.tscn")
const QVBossCommander3DClass = preload("res://scripts/quarter_view_3d/qv_boss_commander_3d.gd")

enum Phase {
	INTRO_MOVE,
	JUMP_AND_TURN,
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
	print(">>> [QV-3D RECORDER] Initializing True Quarter-View 3D Gameplay Recorder...")
	# 15s Watchdog Fail-Safe Timer
	create_timer(15.0).timeout.connect(func():
		print(">>> [QV-3D RECORDER] 15s Watchdog reached. Exiting cleanly.")
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

	stage = Arena3DScene.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	await process_frame
	await process_frame

	player = stage.player
	player.global_position = Vector3(-4.0, 0.1, 4.0)
	print(">>> [QV-3D RECORDER] 3D Arena & Paladin Player ready. Commencing cinematic showcase!")


func _physics_process(delta: float) -> bool:
	if stage == null or player == null or not is_instance_valid(player):
		return false

	phase_time += delta
	total_time += delta

	if total_time >= 10.0:
		print(">>> [QV-3D RECORDER] Gameplay showcase recording completed successfully (10.0s).")
		quit(0)
		return true

	match current_phase:
		Phase.INTRO_MOVE:
			# Paladin runs into arena center towards (+X, -Z)
			Input.action_press("move_right")
			Input.action_press("move_up")
			if phase_time >= 1.2:
				Input.action_release("move_right")
				Input.action_release("move_up")
				_set_phase(Phase.JUMP_AND_TURN)

		Phase.JUMP_AND_TURN:
			# 3D Jump with real-time shadow separation & turn toward minion
			if phase_time < 0.1:
				player.start_jump()
			elif phase_time >= 0.8:
				_set_phase(Phase.MELEE_MINION_COMBO)

		Phase.MELEE_MINION_COMBO:
			# Position minion in front of player
			if minion == null or not is_instance_valid(minion):
				if not stage.enemies.is_empty():
					minion = stage.enemies[0]
					minion.global_position = player.global_position + Vector3(2.5, 0.1, -1.0)
			
			player.facing_direction = Vector3(1.0, 0.0, -0.4).normalized()
			player.look_at(player.global_position + player.facing_direction, Vector3.UP)

			# 3-Hit Combo attacks
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
			# Boss Commander spawns and faces player
			if is_instance_valid(stage.active_boss):
				boss = stage.active_boss
				boss.max_hp = 50
				boss.current_hp = 50
				boss.global_position = player.global_position + Vector3(0.0, 0.1, -7.0)
				boss.look_at(player.global_position, Vector3.UP)
				boss.current_pattern = QVBossCommander3DClass.Pattern.IDLE
				boss.pattern_timer = 999.0 # Manual choreography control
			
			if phase_time >= 0.8:
				_set_phase(Phase.PARRY_BOSS_CHARGE)

		Phase.PARRY_BOSS_CHARGE:
			# Boss initiates 12.0 m/s Shield Charge!
			if phase_time < 0.1:
				if is_instance_valid(boss):
					boss._execute_shield_charge()
			elif phase_time >= 0.38 and not player.is_guarding:
				# Player raises runic shield right into parry window!
				player.start_guard()
			elif phase_time >= 0.52 and is_instance_valid(boss) and boss.current_pattern == QVBossCommander3DClass.Pattern.SHIELD_CHARGE:
				# Clash! Just Parry triggered!
				boss.current_pattern = QVBossCommander3DClass.Pattern.STUNNED
				boss.stun_timer = 2.0
				boss.velocity = Vector3.ZERO
				player.release_guard()
				player.counter_attack_buff = true
				player.counter_buff_timer = 3.0
				# Trigger camera shake & visual impact
				stage.camera.add_trauma(0.55)
				_set_phase(Phase.COUNTER_STRIKE)

		Phase.COUNTER_STRIKE:
			# Paladin executes devastating 3x counter strike on stunned boss
			if phase_time >= 0.2 and phase_time < 0.3:
				player.attack_cooldown = 0.0
				player.start_attack()
				if is_instance_valid(boss):
					boss.receive_hit(26, player.facing_direction) # Boss enters Phase 2 Enrage!
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
			# Dash behind boss and deliver ultimate combo finisher
			if phase_time < 0.1:
				if is_instance_valid(boss):
					player.move_direction = (boss.global_position - player.global_position).normalized()
				player.start_dash()
			elif phase_time >= 0.35 and phase_time < 0.45:
				player.attack_cooldown = 0.0
				player.start_attack()
				if is_instance_valid(boss):
					boss.receive_hit(40, player.facing_direction)
			elif phase_time >= 1.2:
				_set_phase(Phase.VICTORY_OUTRO)

		Phase.VICTORY_OUTRO:
			# Boss dissolves, paladin stands triumphant in stone arena
			player.velocity = Vector3.ZERO
			if player.anim_player != null and player.anim_player.current_animation != "Idle":
				player.anim_player.play("Idle", 0.2)

	return false


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_time = 0.0
