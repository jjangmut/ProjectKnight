extends SceneTree
## Stage 1 Boss Battle Cinematic Gameplay Recorder
## Showcases newly designed Chibi Knight Commander Boss:
## - Natural 2.5-head chibi proportion matching player
## - Multi-frame Walk/Run (no moonwalking, facing player)
## - Multi-frame Attack Windup, Slash, Bastion Guard, Hurt, and Defeat collapse
## - Just Parry, Hitstop, Camera Shake, Combo 3, and Shard Burst

const CampaignScene = preload("res://scenes/stage/Campaign.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")

enum State {
	INTRO,
	BOSS_SPAWN,
	BOSS_WALK_APPROACH,
	BOSS_ATTACK_PARRY,
	PLAYER_COMBO,
	BOSS_GUARD,
	BOSS_ENRAGE_PHASE2,
	PLAYER_AIR_FINISHER,
	BOSS_DEFEAT,
	FINISH
}

var current_state: State = State.INTRO
var state_time: float = 0.0
var total_elapsed: float = 0.0

var campaign: Node = null
var stage: Node2D = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null


func _init() -> void:
	print(">>> [RECORDER] Initializing Stage 1 Boss Battle Cinematic Recorder...")
	SaveManagerClass.clear_save()
	call_deferred("_start_recording")


func _start_recording() -> void:
	campaign = CampaignScene.instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await process_frame
	await process_frame

	stage = campaign.stage
	player = stage.player

	# Set stage to final boss encounter
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.completed.size()):
		stage.completed[i] = true
	stage.completed[stage.encounter_index] = false
	stage.encounter_active = true

	# Position player in the True Castle Gate Boss Arena (x = 9100~9600)
	player.position = Vector2(9120.0, 580.0)
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam != null:
		cam.force_update_scroll()

	# Clean HUD labels
	if stage.status_label != null:
		stage.status_label.text = ""
	var hud := stage.get_node_or_null("HUD")
	if hud != null:
		for c in hud.get_children():
			if c is Label and ("상층" in c.text or "과무" in c.text or "봉인" in c.text or "마지막 전투" in c.text):
				c.visible = false

	# Spawn official single boss encounter from stage
	stage._spawn_boss_encounter()
	if not stage.enemies.is_empty():
		boss = stage.enemies[0]
		boss.position = Vector2(9450.0, 580.0)
		boss.max_hp = 14
		boss.current_hp = 14
		boss.facing_direction = -1.0
		if boss.visual != null:
			boss.visual.scale.x = -1.0
		if boss.attack_area != null:
			boss.attack_area.scale.x = -1.0
		boss.boss_hp_changed.emit(14, 14)

	print(">>> [RECORDER] Ready at True Boss Arena. Single boss bound. Starting choreography!")


func _physics_process(delta: float) -> bool:
	if campaign == null or stage == null:
		return false
	if is_instance_valid(campaign.stage):
		stage = campaign.stage
		player = stage.player
	if player == null or not is_instance_valid(player):
		return false

	# Immortality during cinematic recording
	player.current_hp = 99
	player.is_dead = false

	state_time += delta
	total_elapsed += delta

	# Hard timeout safeguard: always quit cleanly by 11.5 seconds
	if total_elapsed >= 11.5:
		print(">>> [RECORDER] Hard timeout reached (%.2fs). Exiting cleanly." % total_elapsed)
		quit(0)
		return true

	match current_state:
		State.INTRO:
			# Player runs into arena
			Input.action_press("move_right")
			if state_time >= 1.0:
				Input.action_release("move_right")
				_set_state(State.BOSS_SPAWN)

		State.BOSS_SPAWN:
			# Boss stands proud, locks eyes with player
			if state_time >= 1.2:
				_set_state(State.BOSS_WALK_APPROACH)

		State.BOSS_WALK_APPROACH:
			# Boss advances naturally towards player (4-frame walk cycle, facing left, NO moonwalk)
			if state_time < 0.3:
				Input.action_press("move_left") # Micro spacing
			else:
				Input.action_release("move_left")
			if state_time >= 1.3:
				_set_state(State.BOSS_ATTACK_PARRY)

		State.BOSS_ATTACK_PARRY:
			# Boss winds up heavy shield cleave -> Player triggers JUST PARRY!
			if state_time < 0.15:
				if is_instance_valid(boss):
					boss._start_attack(BossCommanderClass.Pattern.SHIELD_BASH, 0.45, 0.2, true)
			elif state_time >= 0.35 and state_time < 0.85:
				Input.action_press("guard") # Just Guard / Parry
			elif state_time >= 0.85:
				Input.action_release("guard")
				_set_state(State.PLAYER_COMBO)

		State.PLAYER_COMBO:
			# Player executes rapid 3-hit combo counterattack with flying sword beam
			if state_time < 0.14:
				Input.action_press("attack")
			elif state_time < 0.32:
				Input.action_release("attack")
			elif state_time < 0.46:
				Input.action_press("attack") # Combo 2
			elif state_time < 0.65:
				Input.action_release("attack")
			elif state_time < 0.80:
				Input.action_press("attack") # Combo 3 Finisher + Crescent Beam
			elif state_time < 1.05:
				Input.action_release("attack")
			elif state_time >= 1.25:
				if is_instance_valid(boss):
					boss.receive_hit(3)
				_set_state(State.BOSS_GUARD)

		State.BOSS_GUARD:
			# Boss fortifies with Bastion Guard stance (runic golden shield barrier)
			if state_time < 0.1:
				if is_instance_valid(boss):
					boss._start_bastion_guard()
			elif state_time < 0.45:
				Input.action_press("dash") # Player dashes back to safety
			elif state_time < 0.65:
				Input.action_release("dash")
			if state_time >= 1.4:
				_set_state(State.BOSS_ENRAGE_PHASE2)

		State.BOSS_ENRAGE_PHASE2:
			# Phase 2 Enrage: Boss bursts with crimson aura, fires flying sword wave!
			if state_time < 0.1:
				if is_instance_valid(boss) and boss.current_phase == 1:
					boss.receive_hit(5) # drops below 6 HP -> triggers Phase 2 ENRAGE
			elif state_time > 0.75 and state_time < 1.35:
				# Boss fires wave, player leaps forward over the blade wave!
				Input.action_press("jump")
				Input.action_press("move_right")
			elif state_time >= 1.35:
				Input.action_release("jump")
				Input.action_release("move_right")
			if state_time >= 1.7:
				_set_state(State.PLAYER_AIR_FINISHER)

		State.PLAYER_AIR_FINISHER:
			# Aerial attack & landing impact finisher
			if state_time < 0.2:
				Input.action_press("attack")
			elif state_time < 0.4:
				Input.action_release("attack")
			elif state_time < 0.6:
				Input.action_press("attack")
			elif state_time < 0.8:
				Input.action_release("attack")
			elif state_time >= 0.95:
				if is_instance_valid(boss) and not boss.is_dead:
					boss.receive_hit(10) # Final lethal blow!
				_set_state(State.BOSS_DEFEAT)

		State.BOSS_DEFEAT:
			# Boss kneels and collapses, soul shard geyser erupts
			Input.action_release("attack")
			Input.action_release("move_right")
			Input.action_release("move_left")
			Input.action_release("guard")
			if state_time >= 1.6:
				_set_state(State.FINISH)

		State.FINISH:
			print(">>> [RECORDER] Choreography successfully finished! Total Time: %.2f sec" % total_elapsed)
			quit(0)

	return false


func _set_state(new_st: State) -> void:
	current_state = new_st
	state_time = 0.0
	print(">>> [RECORDER] State -> %s (at %.2fs)" % [State.keys()[new_st], total_elapsed])
