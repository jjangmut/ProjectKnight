extends SceneTree
## Stage 3 Boss Battle Cinematic Gameplay Recorder
## Showcases newly designed 2.5-head Chibi Crossbow Commander:
## - 2.5-head chibi elite sniper knight proportion matching player
## - High-contrast silver/gold plated armor with royal crimson cloak & runic eye glow
## - Piercing Bolt aim & shot with HDR laser telegraph
## - Just Parry timing with sparks & hitstop
## - Rapid 3-hit sword counter-attack combo
## - Tactical Caltrop scattering & airborne backstep leap
## - Sky Volley arrow rain cascade
## - Phase 2 Dead-Eye Enrage awakening
## - Aerial down-thrust finisher, 4-step defeat collapse, and 15 soul shard geyser

const ThirdStageScene = preload("res://scenes/stage/ThirdStage.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const CrossbowCommanderClass = preload("res://scripts/enemy/crossbow_commander.gd")

enum State {
	INTRO,
	BOSS_STANDOFF,
	BOSS_AIM_SNIPE,
	PARRY_BOLT,
	PLAYER_COMBO,
	BOSS_BACKSTEP,
	BOSS_SKY_VOLLEY,
	BOSS_PHASE2_ENRAGE,
	PLAYER_AIR_FINISHER,
	BOSS_DEFEAT,
	FINISH
}

var current_state: State = State.INTRO
var state_time: float = 0.0
var total_elapsed: float = 0.0
var _last_logged_sec: int = -1

var stage: Node2D = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null


func _init() -> void:
	print(">>> [RECORDER] Initializing Stage 3 Boss Battle Cinematic Recorder...")
	SaveManagerClass.clear_save()
	call_deferred("_start_recording")


func _start_recording() -> void:
	var stage_scene := ThirdStageScene.instantiate()
	root.add_child(stage_scene)
	current_scene = stage_scene
	await process_frame
	await process_frame

	stage = stage_scene
	player = stage.player
	stage.campaign_mode = true
	stage.set_meta("boss_mode", true)

	# Purge all optional route actors
	for group in stage.optional_groups:
		for actor in group.get("actors", []):
			if is_instance_valid(actor):
				actor.queue_free()
		group["actors"].clear()
		group["started"] = true
		group["cleared"] = true

	# Set stage to final boss encounter (Stage 3 has 8 encounters, boss is index 7)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.completed.size()):
		stage.completed[i] = true
	stage.completed[stage.encounter_index] = false
	stage.encounter_active = true

	# Position player in the Ruined Ramparts Boss Arena (centered, clear of mobile HUD)
	player.position = Vector2(10120.0, 580.0)
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
			if c is Label and ("상층" in c.text or "과무" in c.text or "봉인" in c.text or "격전" in c.text):
				c.visible = false

	# Spawn official single Stage 3 boss
	stage._spawn_boss_encounter()
	if not stage.enemies.is_empty():
		boss = stage.enemies[0]
		boss.position = Vector2(10360.0, 580.0)
		boss.max_hp = 16
		boss.current_hp = 16
		boss.facing_direction = -1.0
		if boss.visual != null:
			boss.visual.scale.x = -1.0
		boss.boss_hp_changed.emit(16, 16)

	print(">>> [RECORDER] Ready at Stage 3 Arena. Chibi Crossbow Commander bound. Starting choreography!")


func _physics_process(delta: float) -> bool:
	if stage == null or player == null or not is_instance_valid(player):
		return false

	# Immortality safeguard for cinematic
	player.current_hp = 99
	player.is_dead = false
	Engine.time_scale = 1.0

	state_time += delta
	total_elapsed += delta

	var current_sec := int(total_elapsed)
	if current_sec > _last_logged_sec:
		_last_logged_sec = current_sec
		print(">>> [RECORDER PROGRESS] %.1f / 10.0s (%.0f%%)" % [total_elapsed, clampf(total_elapsed / 10.0 * 100.0, 0.0, 100.0)])

	# Hard timeout safeguard
	if total_elapsed >= 11.5:
		print(">>> [RECORDER] Hard timeout reached (%.2fs). Exiting cleanly." % total_elapsed)
		quit(0)
		return true

	match current_state:
		State.INTRO:
			# Player runs right into arena
			Input.action_press("move_right")
			if state_time >= 0.7:
				Input.action_release("move_right")
				_set_state(State.BOSS_STANDOFF)

		State.BOSS_STANDOFF:
			# Standoff: Boss and player face each other with breathing idle animations
			if is_instance_valid(boss):
				boss.state = boss.State.IDLE
				boss.velocity.x = 0.0
			if state_time >= 1.0:
				_set_state(State.BOSS_AIM_SNIPE)

		State.BOSS_AIM_SNIPE:
			# Boss aims crossbow with HDR laser sight
			if is_instance_valid(boss):
				boss.state = boss.State.AIM_BOLT
				boss._phase_timer = 0.8
				boss._update_laser_targeting()

			# Player prepares guard stance
			if state_time >= 0.7:
				Input.action_press("guard")

			if state_time >= 0.85:
				_set_state(State.PARRY_BOLT)

		State.PARRY_BOLT:
			# Boss fires piercing bolt
			if is_instance_valid(boss):
				if boss.laser_line != null:
					boss.laser_line.visible = false
				boss.state = boss.State.FIRE_BOLT
				boss._phase_timer = 0.20
				if state_time < 0.05:
					boss._fire_bolt(Vector2(-1.0, 0.0))

			# Player parries bolt
			if state_time >= 0.25:
				Input.action_release("guard")

			if state_time >= 0.5:
				_set_state(State.PLAYER_COMBO)

		State.PLAYER_COMBO:
			# Player dashes forward and executes 3-hit combo
			if state_time < 0.35:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")

			# Rhythmic attack inputs
			if state_time >= 0.3 and state_time < 0.4:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 12:
					boss.take_damage(2)
			elif state_time >= 0.4 and state_time < 0.55:
				Input.action_release("attack")
			elif state_time >= 0.55 and state_time < 0.65:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 10:
					boss.take_damage(2)
			elif state_time >= 0.65 and state_time < 0.8:
				Input.action_release("attack")
			elif state_time >= 0.8 and state_time < 0.9:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 8:
					boss.take_damage(2)
			elif state_time >= 0.9:
				Input.action_release("attack")

			if state_time >= 1.1:
				_set_state(State.BOSS_BACKSTEP)

		State.BOSS_BACKSTEP:
			# Boss executes tactical caltrop backstep evasion
			if is_instance_valid(boss):
				if state_time < 0.05:
					boss._start_backstep()

			# Player watches backstep cautiously
			if state_time >= 0.9:
				_set_state(State.BOSS_SKY_VOLLEY)

		State.BOSS_SKY_VOLLEY:
			# Boss aims into sky and summons arrow rain
			if is_instance_valid(boss):
				if state_time < 0.45:
					boss.state = boss.State.AIM_VOLLEY
					boss._phase_timer = 0.4
				elif state_time < 1.1:
					boss.state = boss.State.FIRE_VOLLEY
					boss._phase_timer = 0.3
					if state_time >= 0.5 and state_time < 0.55:
						boss._fire_volley()

			# Player leaps backward to evade raining volley
			if state_time >= 0.6 and state_time < 1.0:
				Input.action_press("move_left")
				if state_time < 0.7:
					Input.action_press("jump")
				else:
					Input.action_release("jump")
			else:
				Input.action_release("move_left")

			if state_time >= 1.3:
				_set_state(State.BOSS_PHASE2_ENRAGE)

		State.BOSS_PHASE2_ENRAGE:
			# Boss triggers Phase 2 Dead-Eye Enrage (scarlet aura, ruby eye glow)
			if is_instance_valid(boss):
				if state_time < 0.05:
					boss.current_hp = 6
					boss._trigger_phase_two()

			if state_time >= 0.8:
				_set_state(State.PLAYER_AIR_FINISHER)

		State.PLAYER_AIR_FINISHER:
			if is_instance_valid(boss):
				boss.is_invulnerable = false
			# Player jumps high and executes downthrust on boss
			if state_time < 0.3:
				Input.action_press("move_right")
				Input.action_press("jump")
			elif state_time < 0.6:
				Input.action_release("jump")
				Input.action_press("attack")
				Input.action_press("ui_down")
			else:
				Input.action_release("move_right")
				Input.action_release("attack")
				Input.action_release("ui_down")

			if state_time >= 0.55 and is_instance_valid(boss) and not boss.is_dead:
				boss.take_damage(6) # Fatal blow

			if state_time >= 0.8:
				_set_state(State.BOSS_DEFEAT)

		State.BOSS_DEFEAT:
			Input.action_release("attack")
			Input.action_release("move_right")
			Input.action_release("move_left")
			Input.action_release("guard")
			# Boss collapses through 4-stage defeat animation (20->21->22->23)
			# Shard fountain bursts, golden victory popup shines
			if state_time >= 1.8:
				_set_state(State.FINISH)

		State.FINISH:
			print(">>> [RECORDER] Stage 3 Boss Battle choreography complete! Exiting cleanly.")
			quit(0)
			return true

	return false


func _set_state(new_state: State) -> void:
	current_state = new_state
	state_time = 0.0
	print(">>> [RECORDER] State -> %s (elapsed: %.2fs)" % [State.keys()[new_state], total_elapsed])
