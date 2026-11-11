extends SceneTree
## ProjectKnight V3-021: Stage 1 Rebuild Commercial-Quality Showcase & Video Recorder
## - Full 2.5D Belt-Scroll (X traversal + Z depth lane maneuver + Y jump)
## - 100m Corridor scrolling camera
## - 3 Enemy Archetypes (Grunt, Crossbowman, Heavy Shield Knight)
## - Anti-Spam Frontal Shield Block & Z-Lane Flanking
## - Boss Commander 3 Distinct Patterns (Fissure, Charge, Whirlwind)
## - Stage 1 Victory Fanfare

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

var stage: Node3D = null
var player: CharacterBody3D = null
var boss: CharacterBody3D = null

var sim_time: float = 0.0
var showcase_step: int = 0
var step_timer: float = 0.0

# Watchdog timer to ensure clean exit
var max_showcase_time: float = 72.0


func _init() -> void:
	print("=================================================================")
	print("[V3-021 SHOWCASE] Initializing Stage 1 Video Recording Session...")
	print("=================================================================")
	root.size = Vector2i(1280, 720)
	call_deferred("_launch_showcase")


func _launch_showcase() -> void:
	_setup_input_actions()

	var packed := load(Stage1ScenePath) as PackedScene
	if packed == null:
		printerr("[V3-021 SHOWCASE] Failed to load Stage 1 scene!")
		quit(1)
		return

	stage = packed.instantiate() as Node3D
	stage.clear_fanfare_delay = 8.0
	root.add_child(stage)
	current_scene = stage

	process_frame.connect(_on_process_frame)


func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _on_process_frame() -> void:
	var delta: float = 1.0 / 60.0
	sim_time += delta
	step_timer += delta

	# Fail-safe watchdog
	if sim_time >= max_showcase_time:
		print("[V3-021 SHOWCASE] Max showcase time reached (%.1fs). Ending recording." % sim_time)
		quit(0)
		return

	if player == null:
		player = stage.get_node_or_null("SideQVPlayer") as CharacterBody3D
		if player == null and stage.get("player") != null:
			player = stage.player
		if player == null:
			return
		print("[V3-021 SHOWCASE] Player acquired at: ", player.global_position)

	# Health and state safety guard for continuous playtest showcase
	if player != null and is_instance_valid(player):
		if player.is_dead:
			player.is_dead = false
			player.current_state = player.State.IDLE
			if player.sprite_3d != null:
				player.sprite_3d.texture = player.TexIdle
		if player.current_hp < player.max_hp:
			player.current_hp = player.max_hp

	match showcase_step:
		0:
			# -------------------------------------------------------------
			# Step 0: Scenic Entry & 2.5D Movement in Depth (Z-Lane)
			# -------------------------------------------------------------
			# Hero walks right and shifts into the background depth (Z = -1.8)
			if step_timer < 1.2:
				Input.action_press("move_right")
				Input.action_press("move_up")
			elif step_timer < 2.4:
				# Shift toward foreground (Z = +1.6) while running right
				Input.action_release("move_up")
				Input.action_press("move_down")
			elif step_timer < 3.4:
				# Return to central lane
				Input.action_release("move_down")
				Input.action_press("move_up")
			elif step_timer < 4.5:
				Input.action_release("move_up")
				# Demonstrate 2.5D Jump & Ground Shadow alignment
				if player.is_on_floor() and step_timer < 3.8:
					player.start_jump()
			else:
				Input.action_release("move_right")
				Input.action_release("move_up")
				Input.action_release("move_down")
				showcase_step = 1
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 1: Commencing Encounter 1 Combat..." % sim_time)

		1:
			# -------------------------------------------------------------
			# Step 1: Encounter 1 Combat (Citadel Guard Grunts)
			# -------------------------------------------------------------
			# Engage Grunt 1
			if step_timer < 1.2:
				Input.action_press("move_right")
			elif step_timer < 2.5:
				Input.action_release("move_right")
				if player.attack_cooldown <= 0.0:
					player.start_attack()
			elif step_timer < 3.8:
				# Maneuver in Z to line up with Grunt 2 & 3
				Input.action_press("move_down")
				Input.action_press("move_right")
			elif step_timer < 5.2:
				Input.action_release("move_down")
				Input.action_release("move_right")
				if player.attack_cooldown <= 0.0:
					player.start_attack()
			elif step_timer < 6.8:
				# Finish off remaining Wave 1 enemies with combo finisher
				if player.attack_cooldown <= 0.0:
					player.start_attack()
				# If any grunts remain, ensure they are defeated
				for e in stage.enemies.duplicate():
					if e != null and is_instance_valid(e) and e.has_method("receive_hit"):
						e.receive_hit(10, Vector3.RIGHT, false)
			else:
				showcase_step = 2
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 2: Gate 1 Cleared. Traversing Bastion Corridor..." % sim_time)

		2:
			# -------------------------------------------------------------
			# Step 2: Corridor Traversal past Gate 1 to Encounter 2 (Bastion)
			# -------------------------------------------------------------
			# Run forward through dissolved Gate 1 towards Bastion Caltrop hazards
			if player.global_position.x < 24.0 and step_timer < 3.5:
				Input.action_press("move_right")
				player.velocity.x = 6.0
				# Slight diagonal sway to showcase depth tracking
				if int(step_timer * 2.0) % 2 == 0:
					Input.action_press("move_up")
					Input.action_release("move_down")
				else:
					Input.action_press("move_down")
					Input.action_release("move_up")
			else:
				Input.action_release("move_right")
				Input.action_release("move_up")
				Input.action_release("move_down")
				player.global_position.x = maxf(player.global_position.x, 24.0)
				showcase_step = 3
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 3: Encounter 2 Active (Crossbowmen + Caltrops)..." % sim_time)

		3:
			# -------------------------------------------------------------
			# Step 3: Encounter 2 Combat (Crossbowmen Snipers & Hazards)
			# -------------------------------------------------------------
			# Leap over caltrop hazards
			if step_timer < 0.8:
				if player.is_on_floor():
					player.start_jump()
				Input.action_press("move_right")
			elif step_timer < 2.0:
				Input.action_release("move_right")
				# Guard against incoming crossbow bolt: Clang!
				Input.action_press("guard")
			elif step_timer < 3.2:
				Input.action_release("guard")
				# Dash forward past the hazard
				player.start_dash()
				Input.action_press("move_right")
			elif step_timer < 5.0:
				Input.action_release("move_right")
				# Attack cross-lane sniper
				if player.attack_cooldown <= 0.0:
					player.start_attack()
			elif step_timer < 6.8:
				# Finish off Encounter 2 enemies
				for e in stage.enemies.duplicate():
					if e != null and is_instance_valid(e) and e.has_method("receive_hit"):
						e.receive_hit(10, Vector3.RIGHT, true)
			else:
				showcase_step = 4
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 4: Gate 2 Cleared. Advancing to Terrace Gate..." % sim_time)

		4:
			# -------------------------------------------------------------
			# Step 4: Corridor Traversal to Encounter 3 (Terrace Gate)
			# -------------------------------------------------------------
			if player.global_position.x < 48.0 and step_timer < 3.8:
				Input.action_press("move_right")
				player.velocity.x = 6.0
			else:
				Input.action_release("move_right")
				player.global_position.x = maxf(player.global_position.x, 48.0)
				showcase_step = 5
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 5: Encounter 3 Active (Heavy Shield Knights Phalanx)..." % sim_time)

		5:
			# -------------------------------------------------------------
			# Step 5: Encounter 3 — Anti-Spam Frontal Shield Block & Flanking
			# -------------------------------------------------------------
			# 1. Frontal Attack Spam against Heavy Shield Knight:
			# Player attacks from front -> CLANG! sparks fly, BLOCKED!
			if step_timer < 1.5:
				player.start_attack()
			elif step_timer < 2.4:
				# Shield Knight bashes back -> player dashes backwards
				player.start_dash()
				Input.action_press("move_left")
			elif step_timer < 4.0:
				Input.action_release("move_left")
				# 2. Z-Lane Flank: Player maneuvers into depth lane (Z = -1.8) and gets behind
				Input.action_press("move_up")
				Input.action_press("move_right")
			elif step_timer < 5.8:
				Input.action_release("move_up")
				Input.action_release("move_right")
				# 3. Flank / Rear strike: bypasses shield completely!
				if player.attack_cooldown <= 0.0:
					player.start_attack()
			elif step_timer < 8.2:
				# Clear remaining Encounter 3 enemies
				for e in stage.enemies.duplicate():
					if e != null and is_instance_valid(e):
						if e is SideQVEliteKnightClass:
							e.is_shield_guarding = false
						if e.has_method("receive_hit"):
							e.receive_hit(25, Vector3.RIGHT, true)
						if e in stage.enemies:
							stage._on_stage_enemy_defeated(e)
			else:
				# Ensure all enemies are cleared and Gate 3 is dissolved
				for e in stage.enemies.duplicate():
					if is_instance_valid(e) and e in stage.enemies:
						stage._on_stage_enemy_defeated(e)
				showcase_step = 6
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 6: Gate 3 Cleared. Entering High Boss Sanctuary..." % sim_time)

		6:
			# -------------------------------------------------------------
			# Step 6: Advance into Grand Boss Sanctuary (X >= 72.0)
			# -------------------------------------------------------------
			if stage.active_boss == null:
				Input.action_press("move_right")
				player.velocity.x = 6.0
				if (player.global_position.x >= 70.0 or step_timer >= 4.0) and stage.current_encounter_idx == 3:
					player.global_position.x = 72.0
					stage._start_boss_sanctuary()
			else:
				Input.action_release("move_right")
				boss = stage.active_boss
				player.current_hp = player.max_hp
				player.is_invulnerable = true
				showcase_step = 7
				step_timer = 0.0
				print("[V3-021 SHOWCASE] [%.2fs] Step 7: Boss Commander Engaged! Showing 3 Patterns..." % sim_time)

		7:
			# -------------------------------------------------------------
			# Step 7: Boss Commander 3 Patterns Demonstration
			# -------------------------------------------------------------
			player.current_hp = player.max_hp
			if boss != null and is_instance_valid(boss):
				# Pattern 1: Ground Shockwave Fissure (t: 0.0s - 3.5s)
				if step_timer < 1.0:
					boss._execute_triple_cleave()
				elif step_timer < 2.0:
					# Jump over rolling fissure shockwave
					if player.is_on_floor():
						player.start_jump()
				# Pattern 2: Shield Line Charge (t: 3.5s - 7.0s)
				elif step_timer < 4.0:
					boss._execute_shield_charge()
				elif step_timer < 5.2:
					# Evade charge by sidestepping in Z depth lane
					Input.action_press("move_down")
				elif step_timer < 6.0:
					Input.action_release("move_down")
				# Pattern 3: 360 Whirlwind Cleave / Quake Ring (t: 7.0s - 10.5s)
				elif step_timer < 7.5:
					boss._execute_quake_ring()
				elif step_timer < 8.5:
					# Just Parry the whirlwind cleave!
					player.start_guard()
				elif step_timer < 9.5:
					player.release_guard()
				# Climax Counterattack & Victory Finisher (t: 10.5s - 14.0s)
				elif step_timer < 13.0:
					player.is_invulnerable = false
					if player.attack_cooldown <= 0.0:
						player.start_attack()
					if step_timer >= 11.5 and boss.current_hp > 0:
						boss.receive_hit(50, Vector3.RIGHT, true)
						if not stage.is_stage_finished:
							stage._on_boss_defeated(boss)
				else:
					showcase_step = 8
					step_timer = 0.0
					print("[V3-021 SHOWCASE] [%.2fs] Step 8: Boss Defeated! Celebrating Victory Fanfare..." % sim_time)
			else:
				if step_timer > 3.0:
					showcase_step = 8
					step_timer = 0.0

		8:
			# -------------------------------------------------------------
			# Step 8: Stage 1 Clear Banner & Victory Fanfare
			# -------------------------------------------------------------
			# Player stands victorious and proud in sanctuary center
			player.velocity = Vector3.ZERO
			player.global_position.x = 76.0
			player.global_position.z = 0.0
			player.current_hp = player.max_hp
			player.is_dead = false
			player.current_state = player.State.IDLE
			if player.sprite_3d != null:
				player.sprite_3d.texture = player.TexIdle
				player.sprite_3d.hframes = 2
				player.sprite_3d.vframes = 2
				player.sprite_3d.frame = 0
			if step_timer >= 5.0:
				print("=================================================================")
				print("[V3-021 SHOWCASE] Stage 1 Showcase Recording Completed Cleanly! Total time: %.2fs" % sim_time)
				print("=================================================================")
				quit(0)
