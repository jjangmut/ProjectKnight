extends SceneTree
## Stage 4 Boss Battle Cinematic Gameplay Recorder
## Showcases newly designed 2.5-head Chibi Ancient Golem Guardian:
## - 2.5-head chibi ancient runic stone titan proportion matching player
## - Glowing golden cyan ancient rune core & stone armor plates
## - Quake Slam shockwave & Just Parry timing
## - Rapid 3-hit sword counter-attack combo
## - Roaring Falling Boulders summons
## - High-Speed Rolling Charge ball rotation
## - Phase 2 Magma Core Overload awakening
## - Aerial down-thrust finisher, 4-step stone crumble shatter, and 18 soul shard geyser

const FourthStageScene = preload("res://scenes/stage/FourthStage.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const AncientGolemGuardianClass = preload("res://scripts/enemy/ancient_golem_guardian.gd")

enum State {
	INTRO,
	BOSS_STANDOFF,
	BOSS_QUAKE_SLAM,
	PARRY_OR_EVADE,
	PLAYER_COMBO,
	BOSS_SUMMON_BOULDERS,
	BOSS_ROLLING_CHARGE,
	BOSS_PHASE2_OVERLOAD,
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
	print(">>> [RECORDER] Initializing Stage 4 Boss Battle Cinematic Recorder...")
	SaveManagerClass.clear_save()
	call_deferred("_start_recording")


func _start_recording() -> void:
	var stage_scene := FourthStageScene.instantiate()
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

	# Set stage to final boss encounter
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.completed.size()):
		stage.completed[i] = true
	stage.completed[stage.encounter_index] = false
	stage.encounter_active = true

	# Position player in the Megalithic Boss Arena
	player.position = Vector2(9480.0, 580.0)
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

	# Spawn official single Stage 4 boss
	stage._spawn_boss_encounter()
	if not stage.enemies.is_empty():
		boss = stage.enemies[0]
		boss.position = Vector2(9720.0, 580.0)
		boss.max_hp = 18
		boss.current_hp = 18
		boss.facing_direction = -1.0
		if boss.visual != null:
			boss.visual.scale.x = -1.0
		boss.boss_hp_changed.emit(18, 18)

	print(">>> [RECORDER] Ready at Stage 4 Stone Arena. Chibi Ancient Golem Guardian bound. Starting choreography!")


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
			# Player runs into arena
			Input.action_press("move_right")
			if state_time >= 0.7:
				Input.action_release("move_right")
				_set_state(State.BOSS_STANDOFF)

		State.BOSS_STANDOFF:
			# Standoff: Ancient golem breathes with glowing core
			if is_instance_valid(boss):
				boss.state = boss.State.IDLE
				boss.velocity.x = 0.0
			if state_time >= 1.0:
				_set_state(State.BOSS_QUAKE_SLAM)

		State.BOSS_QUAKE_SLAM:
			# Golem raises fists and smashes the ground
			if is_instance_valid(boss):
				boss.state = boss.State.QUAKE_SLAM
				if state_time < 0.05:
					boss._phase_timer = 0.6
				elif state_time >= 0.45 and state_time < 0.5:
					boss._emit_shockwaves()
					boss._spawn_quake_vfx()

			if state_time >= 0.35:
				Input.action_press("guard")

			if state_time >= 0.55:
				_set_state(State.PARRY_OR_EVADE)

		State.PARRY_OR_EVADE:
			Input.action_release("guard")
			if state_time >= 0.4:
				_set_state(State.PLAYER_COMBO)

		State.PLAYER_COMBO:
			# Player attacks with 3-hit sword combo
			if state_time < 0.3:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")

			if state_time >= 0.25 and state_time < 0.35:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 14:
					boss.take_damage(2)
			elif state_time >= 0.35 and state_time < 0.5:
				Input.action_release("attack")
			elif state_time >= 0.5 and state_time < 0.6:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 12:
					boss.take_damage(2)
			elif state_time >= 0.6 and state_time < 0.75:
				Input.action_release("attack")
			elif state_time >= 0.75 and state_time < 0.85:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 10:
					boss.take_damage(2)
			elif state_time >= 0.85:
				Input.action_release("attack")

			if state_time >= 1.0:
				_set_state(State.BOSS_SUMMON_BOULDERS)

		State.BOSS_SUMMON_BOULDERS:
			# Golem roars and summons falling boulders
			if is_instance_valid(boss):
				boss.state = boss.State.SUMMON_BOULDERS
				boss._phase_timer = 0.5
				if state_time >= 0.15 and state_time < 0.2:
					boss._spawn_boulders()

			# Player hops backward
			if state_time >= 0.3 and state_time < 0.6:
				Input.action_press("move_left")
			else:
				Input.action_release("move_left")

			if state_time >= 1.1:
				_set_state(State.BOSS_ROLLING_CHARGE)

		State.BOSS_ROLLING_CHARGE:
			# Golem rolls into boulder ball and charges forward
			if is_instance_valid(boss):
				boss.state = boss.State.ROLLING_CHARGE
				boss.velocity.x = boss.facing_direction * 180.0

			# Player jumps over rolling golem
			if state_time >= 0.2 and state_time < 0.6:
				Input.action_press("jump")
			else:
				Input.action_release("jump")

			if state_time >= 0.9:
				_set_state(State.BOSS_PHASE2_OVERLOAD)

		State.BOSS_PHASE2_OVERLOAD:
			# Core Overload Magma Rage
			if is_instance_valid(boss):
				boss.velocity.x = 0.0
				if state_time < 0.05:
					boss.current_hp = 6
					boss._trigger_phase_two()

			if state_time >= 0.8:
				_set_state(State.PLAYER_AIR_FINISHER)

		State.PLAYER_AIR_FINISHER:
			if is_instance_valid(boss):
				boss.is_invulnerable = false
			# Player downthrust attack
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
			# 4-stage shatter collapse
			if state_time >= 1.8:
				_set_state(State.FINISH)

		State.FINISH:
			print(">>> [RECORDER] Stage 4 Boss Battle choreography complete! Exiting cleanly.")
			quit(0)
			return true

	return false


func _set_state(new_state: State) -> void:
	current_state = new_state
	state_time = 0.0
	print(">>> [RECORDER] State -> %s (elapsed: %.2fs)" % [State.keys()[new_state], total_elapsed])
