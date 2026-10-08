extends SceneTree
## Stage 2 Boss Battle Cinematic Gameplay Recorder
## Showcases newly designed 2.5-head Chibi Beast Chieftain:
## - 2.5-head chibi beast warrior proportion matching player
## - 4-legged feral charge running cycle (no moonwalking, facing player)
## - Multi-frame Claw Strike, Just Parry, Hitstop, 3-Hit Combo
## - Airborne Leap & Ground Slam with dual shockwaves
## - Phase 2 Blood Roar howling with crimson frenzy aura
## - Aerial down-thrust finisher, defeat collapse, and soul shard geyser

const SecondStageScene = preload("res://scenes/stage/SecondStage.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const BeastChieftainClass = preload("res://scripts/enemy/beast_chieftain.gd")

enum State {
	INTRO,
	BOSS_SPAWN,
	BOSS_RUN_APPROACH,
	BOSS_ATTACK_PARRY,
	PLAYER_COMBO,
	BOSS_LEAP_SLAM,
	BOSS_ENRAGE_ROAR,
	PLAYER_AIR_FINISHER,
	BOSS_DEFEAT,
	FINISH
}

var current_state: State = State.INTRO
var state_time: float = 0.0
var total_elapsed: float = 0.0

var stage: Node2D = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null


func _init() -> void:
	print(">>> [RECORDER] Initializing Stage 2 Boss Battle Cinematic Recorder...")
	SaveManagerClass.clear_save()
	call_deferred("_start_recording")


func _start_recording() -> void:
	var stage_scene := SecondStageScene.instantiate()
	root.add_child(stage_scene)
	current_scene = stage_scene
	await process_frame
	await process_frame

	stage = stage_scene
	player = stage.player

	# Set stage to final boss encounter
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.completed.size()):
		stage.completed[i] = true
	stage.completed[stage.encounter_index] = false
	stage.encounter_active = true

	# Position player in the True Alpha Beast Arena (x = 9700~10400)
	player.position = Vector2(9750.0, 580.0)
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam != null:
		cam.force_update_scroll()

	# Remove any ambient or previous enemies
	for e in stage.enemies:
		if is_instance_valid(e):
			e.queue_free()
	stage.enemies.clear()
	for child in stage.get_children():
		if child != player and child.is_in_group("enemies"):
			child.queue_free()

	# Clean HUD labels
	if stage.status_label != null:
		stage.status_label.text = ""
	var hud := stage.get_node_or_null("HUD")
	if hud != null:
		for c in hud.get_children():
			if c is Label and ("상층" in c.text or "과무" in c.text or "봉인" in c.text or "마지막 전투" in c.text):
				c.visible = false

	# Spawn official single Stage 2 boss
	stage._spawn_boss_encounter()
	if not stage.enemies.is_empty():
		boss = stage.enemies[0]
		boss.position = Vector2(10080.0, 580.0)
		boss.max_hp = 14
		boss.current_hp = 14
		boss.facing_direction = -1.0
		if boss.visual != null:
			boss.visual.scale.x = -1.0
		if boss.attack_area != null:
			boss.attack_area.scale.x = -1.0
		boss.boss_hp_changed.emit(14, 14)

	print(">>> [RECORDER] Ready at Stage 2 Beast Arena. Chibi Beast Chieftain bound. Starting choreography!")


func _physics_process(delta: float) -> bool:
	if stage == null or player == null or not is_instance_valid(player):
		return false

	# Immortality safeguard
	player.current_hp = 99
	player.is_dead = false

	state_time += delta
	total_elapsed += delta

	# Hard timeout safeguard
	if total_elapsed >= 12.5:
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
			# Boss stands proud, locking eyes with player
			if state_time >= 1.2:
				_set_state(State.BOSS_RUN_APPROACH)

		State.BOSS_RUN_APPROACH:
			# Boss charges forward on 4 legs (Run animation, facing left, NO moonwalk)
			if state_time < 0.3:
				Input.action_press("move_left") # Spacing
			else:
				Input.action_release("move_left")
			if state_time >= 1.3:
				_set_state(State.BOSS_ATTACK_PARRY)

		State.BOSS_ATTACK_PARRY:
			# Boss initiates ferocious claw slash -> Player executes JUST PARRY!
			if state_time < 0.15:
				if is_instance_valid(boss):
					boss._start_attack(BeastChieftainClass.Pattern.WILD_CLAW, 0.45, 0.20, true)
			elif state_time >= 0.35 and state_time < 0.85:
				Input.action_press("guard") # Just Guard / Parry
			elif state_time >= 0.85:
				Input.action_release("guard")
				_set_state(State.PLAYER_COMBO)

		State.PLAYER_COMBO:
			# Counter-attack: 3-hit combo with crescent sword beam
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
					boss.take_damage(3)
				_set_state(State.BOSS_LEAP_SLAM)

		State.BOSS_LEAP_SLAM:
			# Boss leaps into the air and slams down with shockwaves!
			if state_time < 0.1:
				if is_instance_valid(boss):
					boss._start_leap_slam()
			elif state_time < 0.45:
				Input.action_press("dash") # Player dashes back to evade
			elif state_time < 0.65:
				Input.action_release("dash")
			if state_time >= 1.4:
				_set_state(State.BOSS_ENRAGE_ROAR)

		State.BOSS_ENRAGE_ROAR:
			# Phase 2 Blood Frenzy: Boss roars to the heavens, bursting with crimson aura!
			if state_time < 0.1:
				if is_instance_valid(boss) and boss.current_phase == 1:
					boss.take_damage(5) # drops below 6 HP -> triggers Phase 2 Blood Frenzy
			elif state_time > 0.75 and state_time < 1.35:
				# Boss roars, player jumps forward to attack
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
					boss.take_damage(10) # Lethal blow!
				_set_state(State.BOSS_DEFEAT)

		State.BOSS_DEFEAT:
			# Boss collapses on ground, soul shards burst out
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
