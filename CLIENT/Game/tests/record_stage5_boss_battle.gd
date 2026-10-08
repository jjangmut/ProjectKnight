extends SceneTree
## Stage 5 Boss Battle Cinematic Gameplay Recorder
## Showcases newly designed 2.5-head Chibi Abyssal Arbiter (심연의 심판관):
## - 2.5-head chibi dark obsidian void champion proportion matching player (105px)
## - Glowing void purple/crimson eyes & abyssal greatsword
## - Crescent Void Greatsword Slash & Just Parry clash
## - Rapid 3-hit sword counter-attack combo
## - Shadow Blink teleportation behind player
## - Rotating Abyssal Blade Ring radial burst
## - Phase 3 Black Wings & Final Judgment awakening
## - Aerial down-thrust finisher, 4-step defeat vapor dissolution, and 25 void shard geyser

const FifthStageScene = preload("res://scenes/stage/FifthStage.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const AbyssalArbiterClass = preload("res://scripts/enemy/abyssal_arbiter.gd")

enum State {
	INTRO,
	BOSS_STANDOFF,
	VOID_SLASH_PARRY,
	PLAYER_COMBO,
	SHADOW_BLINK,
	BLADE_RING,
	PHASE3_AWAKENING,
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
	print(">>> [RECORDER] Initializing Stage 5 Boss Battle Cinematic Recorder...")
	SaveManagerClass.clear_save()
	call_deferred("_start_recording")


func _start_recording() -> void:
	var stage_scene := FifthStageScene.instantiate()
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

	# Set stage to final boss encounter (Encounter 7)
	stage.encounter_index = stage.required_count - 1
	for i in range(stage.completed.size()):
		stage.completed[i] = true
	stage.completed[stage.encounter_index] = false
	stage.encounter_active = true

	var boss_arena_x: float = stage.ENTRY_X[stage.encounter_index]

	# Position player in the Abyssal Judgment Hall
	player.position = Vector2(boss_arena_x + 120.0, 580.0)
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

	# Spawn official single Stage 5 boss
	stage._spawn_boss_encounter()
	if not stage.enemies.is_empty():
		boss = stage.enemies[0]
		boss.position = Vector2(boss_arena_x + 360.0, 580.0)
		boss.max_hp = 24
		boss.current_hp = 24
		boss.facing_direction = -1.0
		if boss.visual != null:
			boss.visual.scale.x = -1.0
		boss.boss_hp_changed.emit(24, 24)

	print(">>> [RECORDER] Ready at Stage 5 Abyssal Arena. Chibi Abyssal Arbiter bound. Starting choreography!")


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
			# Standoff: Arbiter dark breathing stance
			if is_instance_valid(boss):
				boss.state = boss.State.IDLE
				boss.velocity.x = 0.0
			if state_time >= 1.0:
				_set_state(State.VOID_SLASH_PARRY)

		State.VOID_SLASH_PARRY:
			# Arbiter initiates Void Slash with crescent greatsword
			if is_instance_valid(boss):
				if state_time < 0.05:
					boss._start_void_slash()

			# Player guards right before impact for Just Parry
			if state_time >= 0.28:
				Input.action_press("guard")

			if state_time >= 0.55:
				Input.action_release("guard")
				_set_state(State.PLAYER_COMBO)

		State.PLAYER_COMBO:
			# Player attacks with 3-hit sword combo
			if state_time < 0.3:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")

			if state_time >= 0.25 and state_time < 0.35:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 20:
					boss.take_damage(2)
			elif state_time >= 0.35 and state_time < 0.5:
				Input.action_release("attack")
			elif state_time >= 0.5 and state_time < 0.6:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 18:
					boss.take_damage(2)
			elif state_time >= 0.6 and state_time < 0.75:
				Input.action_release("attack")
			elif state_time >= 0.75 and state_time < 0.85:
				Input.action_press("attack")
				if is_instance_valid(boss) and boss.current_hp > 16:
					boss.take_damage(2)
			elif state_time >= 0.85:
				Input.action_release("attack")

			if state_time >= 1.0:
				_set_state(State.SHADOW_BLINK)

		State.SHADOW_BLINK:
			# Arbiter vanishes into shadow mist and reappears
			if is_instance_valid(boss):
				if state_time < 0.05:
					boss._start_shadow_blink()

			if state_time >= 0.8:
				_set_state(State.BLADE_RING)

		State.BLADE_RING:
			# Arbiter summons 4-directional spinning Void Blade Ring
			if is_instance_valid(boss):
				if state_time < 0.05:
					boss._start_blade_ring()

			# Player hops backward to evade
			if state_time >= 0.2 and state_time < 0.6:
				Input.action_press("move_left")
			else:
				Input.action_release("move_left")

			if state_time >= 1.1:
				_set_state(State.PHASE3_AWAKENING)

		State.PHASE3_AWAKENING:
			# Final Judgment Phase 3 Awakening: Black Wings & Crimson Glare
			if is_instance_valid(boss):
				boss.velocity.x = 0.0
				if state_time < 0.05:
					boss.current_hp = 8
					boss._trigger_phase_three()

			if state_time >= 0.85:
				_set_state(State.PLAYER_AIR_FINISHER)

		State.PLAYER_AIR_FINISHER:
			if is_instance_valid(boss):
				boss.is_invulnerable = false
			# Player jump + downthrust aerial finisher
			if state_time < 0.3:
				Input.action_press("move_right")
				Input.action_press("jump")
			elif state_time < 0.65:
				Input.action_release("jump")
				Input.action_press("attack")
				Input.action_press("ui_down")
			else:
				Input.action_release("move_right")
				Input.action_release("attack")
				Input.action_release("ui_down")

			if state_time >= 0.55 and is_instance_valid(boss) and not boss.is_dead:
				boss.take_damage(8) # Fatal blow triggers _die()

			if state_time >= 0.85:
				_set_state(State.BOSS_DEFEAT)

		State.BOSS_DEFEAT:
			Input.action_release("attack")
			Input.action_release("move_right")
			Input.action_release("move_left")
			Input.action_release("guard")
			# 4-stage defeat mist dissolution and shard burst
			if state_time >= 1.8:
				_set_state(State.FINISH)

		State.FINISH:
			print(">>> [RECORDER] Stage 5 Boss Battle choreography complete! Exiting cleanly.")
			quit(0)
			return true

	return false


func _set_state(new_state: State) -> void:
	current_state = new_state
	state_time = 0.0
	print(">>> [RECORDER] State -> %s (elapsed: %.2fs)" % [State.keys()[new_state], total_elapsed])
