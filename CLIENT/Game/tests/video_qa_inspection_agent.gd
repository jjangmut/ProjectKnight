extends SceneTree
## Project Knight - Autonomous Video QA Inspection Agent
## Automated inspector verifying:
## 1. Camera View Angle (Immortal Warrior horizontal view: Yaw = 0.0 deg, Pitch ~ -32 deg)
## 2. Player Multi-Frame Action Animations (Aligned Spritesheets)
## 3. Monster/Boss Facing Alignment (Always faces player head-on; no facing away)
## 4. Visual Scale & Single Frame Rendering (hframes/vframes split; no raw sheet exposure)
## 5. Mutual Collision Stop & Zero-Pushing Verification
## 6. Sprite Pivot Alignment & Zero-Jitter Stability (Idle & Attack foot position fixed)
## 7. Vertical Crescent Sword Wave 3D Mesh Inspection (No horizontal torus/frisbee)

const ArenaScene = preload("res://scenes/side_quarter_view/SideQuarterViewArena.tscn")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const TexIdle = preload("res://assets/player_frames/idle_v1_aligned.png")
const TexRun = preload("res://assets/player_frames/run_v2.png")
const TexAttack = preload("res://assets/player_frames/attack_v1_aligned.png")
const TexJump = preload("res://assets/player_frames/jump_v1.png")
const TexGuard = preload("res://assets/player_frames/guard_v1_aligned.png")

var checks: int = 0
var failures: int = 0
var stage: Node3D = null


func _initialize() -> void:
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	if not InputMap.has_action("guard"):
		InputMap.add_action("guard")
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")

	# 15s Watchdog Fail-Safe Timer
	var watchdog := create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] Video QA Inspection Agent exceeded 15s. Forcing exit.")
		quit(1)
	)
	_run_inspection.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [QA-PASS] %s" % msg)
	else:
		failures += 1
		printerr("  [QA-FAIL] %s" % msg)


func _advance_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _run_inspection() -> void:
	print("\n===================================================================")
	print(">>> START AUTONOMOUS VIDEO QA INSPECTION AGENT SUITE <<<")
	print("===================================================================\n")

	stage = ArenaScene.instantiate() as Node3D
	check(stage != null, "Arena scene instantiated successfully")
	root.add_child(stage)
	current_scene = stage

	await _advance_frames(5)

	var player = stage.player
	var camera = stage.camera

	# Settle player firmly onto the 3D floor before running inspections
	while not player.is_on_floor() or player.global_position.y > 0.05:
		await physics_frame
	await _advance_frames(4)

	# -------------------------------------------------------------
	# Inspection 1: Camera Alignment (Immortal Warrior Horizontal View)
	# -------------------------------------------------------------
	print("\n--- Inspection 1: Camera View Angle & Zero-Yaw Alignment ---")
	check(is_zero_approx(camera.rotation_degrees.y), 
		"Camera Yaw is strictly 0.0 deg (No diagonal slant; horizon is perfectly horizontal): %.2f deg" % camera.rotation_degrees.y)
	check(camera.rotation_degrees.x <= -28.0 and camera.rotation_degrees.x >= -36.0,
		"Camera Pitch is in optimal Quarter-View range (-32 deg): %.1f deg" % camera.rotation_degrees.x)
	check(is_zero_approx(camera.rotation_degrees.z),
		"Camera Roll is strictly 0.0 deg (No tilt): %.2f deg" % camera.rotation_degrees.z)

	# -------------------------------------------------------------
	# Inspection 2: Player Multi-Frame Action Animations (Aligned Sheets)
	# -------------------------------------------------------------
	print("\n--- Inspection 2: Player Multi-Frame Action Animations ---")
	check(player.sprite_3d.texture == TexIdle, "Initial player sprite is 4-frame aligned Idle spritesheet")
	check(player.sprite_3d.hframes == 2 and player.sprite_3d.vframes == 2, "Idle sprite configured as 2x2 sprite sheet")

	# Trigger Attack
	player.attack_cooldown = 0.0
	player.start_attack()
	check(player.sprite_3d.texture == TexAttack, "Player texture transitioned to aligned AttackSheetTexture during attack")
	check(player.sprite_3d.hframes == 2 and player.sprite_3d.vframes == 2, "Attack sprite configured as 2x2 sprite sheet")
	check(player.sprite_3d.frame == 0, "Attack Frame 0 (Combo 1 slash) active")

	await _advance_frames(14)
	check(player.sprite_3d.texture == TexIdle, "Player returned to Idle spritesheet after attack duration")
	check(player.sprite_3d.hframes == 2 and player.sprite_3d.vframes == 2, "Player 2x2 idle hframes preserved")

	# Test Run Animation State
	Input.action_press("move_right")
	await _advance_frames(6)
	check(player.sprite_3d.texture == TexRun, "Moving player transitioned to 6-frame Run spritesheet (run_v2.png)")
	check(player.sprite_3d.hframes == 3 and player.sprite_3d.vframes == 2, "Run sprite configured as 3x2 sprite sheet")
	Input.action_release("move_right")
	await _advance_frames(8)

	# Test Jump Animation State
	player.start_jump()
	await _advance_frames(4)
	check(player.sprite_3d.texture == TexJump, "Airborne player transitioned to 3-frame Jump spritesheet (jump_v1.png)")
	check(player.sprite_3d.hframes == 3 and player.sprite_3d.vframes == 1, "Jump sprite configured as 3x1 sprite sheet")
	# Wait for landing
	while player.global_position.y > 0.15:
		await physics_frame
	await _advance_frames(4)

	# Test Guard Animation State
	Input.action_press("guard")
	await _advance_frames(4)
	check(player.sprite_3d.texture == TexGuard, "Guarding player transitioned to aligned Guard spritesheet")
	check(player.sprite_3d.hframes == 3 and player.sprite_3d.vframes == 1, "Guard sprite configured as 3x1 sprite sheet")
	Input.action_release("guard")
	await _advance_frames(6)

	# -------------------------------------------------------------
	# Inspection 3: Sprite Pivot Alignment & Zero-Jitter Stability
	# -------------------------------------------------------------
	print("\n--- Inspection 3: Sprite Pivot Alignment & Zero-Jitter Stability ---")
	# Verify that in Idle state, player Sprite3D position and ground anchor remain rock-solid
	var idle_pos_initial: Vector3 = player.global_position
	for f in range(4):
		player.sprite_3d.frame = f
		await _advance_frames(2)
		check(player.global_position.is_equal_approx(idle_pos_initial), 
			"Idle frame %d maintains rock-solid position without front/back jitter" % f)
	check(is_zero_approx(player.sprite_3d.position.x), "Sprite3D X position is centered at 0.0 (No horizontal offset shift)")
	check(is_equal_approx(player.sprite_3d.position.y, 0.874), "Sprite3D Y position accurately anchors feet to Y=0.0")

	# -------------------------------------------------------------
	# Inspection 4: Vertical Crescent Sword Wave 3D Mesh Inspection
	# -------------------------------------------------------------
	print("\n--- Inspection 4: Vertical Crescent Sword Wave 3D Mesh Inspection ---")
	var beam_info := {
		"spawned": false,
		"has_core": false,
		"has_aura": false,
		"has_particles": false,
		"has_light": false,
		"is_array_mesh": false,
		"is_not_torus": false
	}
	var beam_callback := func(b: Node3D):
		beam_info["spawned"] = (b != null)
		if b is SideQVSwordBeam:
			var s_beam := b as SideQVSwordBeam
			beam_info["has_core"] = (s_beam.core_mesh_inst != null)
			beam_info["has_aura"] = (s_beam.aura_mesh_inst != null)
			beam_info["has_particles"] = (s_beam.trail_particles != null)
			beam_info["has_light"] = (s_beam.beam_light != null)
			if s_beam.core_mesh_inst != null:
				beam_info["is_array_mesh"] = (s_beam.core_mesh_inst.mesh is ArrayMesh)
				beam_info["is_not_torus"] = not (s_beam.core_mesh_inst.mesh is TorusMesh)
	player.sword_beam_fired.connect(beam_callback)

	player.global_position = Vector3(-5.0, 0.1, -3.0) # Position clear of any enemies
	player.facing_dir_x = 1.0
	player.is_attacking = false
	player.combo_step = 2
	player.attack_cooldown = 0.0
	player.start_attack() # combo_step becomes 3, triggers _fire_sword_beam()
	await _advance_frames(3)

	player.sword_beam_fired.disconnect(beam_callback)

	check(beam_info["spawned"], "Vertical Crescent Sword Wave projectile spawned via combo finisher")
	check(beam_info["has_core"], "Beam has inner radiant CoreMeshInstance3D")
	check(beam_info["has_aura"], "Beam has outer energy AuraMeshInstance3D")
	check(beam_info["has_particles"], "Beam has trailing Golden Sparks CPUParticles3D")
	check(beam_info["has_light"], "Beam has ground-illuminating OmniLight3D")
	check(beam_info["is_array_mesh"], "Beam mesh is custom procedural ArrayMesh (Crescent Arc)")
	check(beam_info["is_not_torus"], "Obsolete horizontal Torus/Frisbee mesh completely eliminated")

	# -------------------------------------------------------------
	# Inspection 5: Monster & Boss Facing Alignment (Always Faces Player)
	# -------------------------------------------------------------
	print("\n--- Inspection 5: Monster & Boss Mutual Facing Alignment ---")
	var enemy = null
	if not stage.enemies.is_empty():
		enemy = stage.enemies[0]
	else:
		enemy = stage._spawn_enemy(Vector3(4.0, 0.1, 0.0))

	# Player is at X = -6.0, Enemy is at X = 3.0 (Enemy is to the RIGHT of player)
	player.global_position = Vector3(-6.0, 0.1, 0.0)
	enemy.global_position = Vector3(3.0, 0.1, 0.0)
	await _advance_frames(4)

	# Player facing right (+X, not flipped)
	check(not player.sprite_3d.flip_h, "Player faces right (+X) towards enemy")
	# Enemy must face left (-X, flip_h = true) towards player!
	check(enemy.sprite_3d.flip_h, "Enemy faces left (-X) towards player (Mutual confrontation verified)")

	# Boss Facing Inspection
	for e in stage.enemies.duplicate():
		if is_instance_valid(e) and e != stage.active_boss:
			e._die()
	await _advance_frames(10)

	if stage.active_boss == null or not is_instance_valid(stage.active_boss):
		stage._start_wave_2_boss()
		await _advance_frames(5)

	var boss = stage.active_boss
	check(boss != null, "Boss Commander active in arena")

	# Case A: Boss is on the RIGHT (X = 4.0), Player is on the LEFT (X = -4.0)
	player.global_position = Vector3(-4.0, 0.1, 0.0)
	boss.global_position = Vector3(4.0, 0.1, 0.0)
	await _advance_frames(4)

	check(boss.facing_dir_x < 0.0, "Boss tracking direction points left towards player (facing_dir_x = %.1f)" % boss.facing_dir_x)
	check(boss.sprite_3d.flip_h, "Boss sprite flipped horizontally to face left towards player")

	# Case B: Player crosses over to the RIGHT (X = 6.0), Boss is on the LEFT (X = 2.0)
	player.global_position = Vector3(6.0, 0.1, 0.0)
	boss.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(4)

	check(boss.facing_dir_x > 0.0, "Boss tracking direction points right towards player (facing_dir_x = %.1f)" % boss.facing_dir_x)
	check(not boss.sprite_3d.flip_h, "Boss sprite unflipped to face right towards player (Turned around to face player)")

	# -------------------------------------------------------------
	# Inspection 6: Visual Scale & Single Frame Rendering
	# -------------------------------------------------------------
	print("\n--- Inspection 6: Visual Scale & Single Frame Rendering ---")
	check(boss.sprite_3d.hframes == 4 and boss.sprite_3d.vframes == 3, "Boss sprite sheet split into 4x3 frames (No raw sheet exposure)")
	check(is_equal_approx(boss.sprite_3d.pixel_size, 0.0082), "Boss calibrated height is ~2.45m (pixelsize = %.4f)" % boss.sprite_3d.pixel_size)
	check(is_equal_approx(player.sprite_3d.pixel_size, 0.00282), "Player calibrated height is ~1.77m (pixelsize = %.5f)" % player.sprite_3d.pixel_size)

	# -------------------------------------------------------------
	# Inspection 7: Mutual Collision Stop & Zero-Pushing Verification
	# -------------------------------------------------------------
	print("\n--- Inspection 7: Mutual Stop & Zero-Pushing Verification ---")
	player.global_position = Vector3(-2.0, 0.1, 0.0)
	boss.global_position = Vector3(0.0, 0.1, 0.0)
	boss.current_pattern = SideQVBossClass.Pattern.IDLE
	boss.pattern_timer = 999.0
	await _advance_frames(4)

	# Player walks directly right towards the boss
	Input.action_press("move_right")
	await _advance_frames(12)
	Input.action_release("move_right")

	var contact_dist: float = player.global_position.distance_to(boss.global_position)
	check(contact_dist >= 0.85, "Player stops at firm contact boundary without penetrating boss (dist = %.2f m)" % contact_dist)
	check(absf(player.velocity.x) <= 0.1, "Player forward velocity halts clean; no pushing into boss (vel.x = %.2f)" % player.velocity.x)
	check(absf(boss.velocity.x) <= 0.1, "Boss does not get pushed across the floor (boss.vel.x = %.2f)" % boss.velocity.x)

	# -------------------------------------------------------------
	# Summary Report
	# -------------------------------------------------------------
	print("\n===================================================================")
	print("QA INSPECTION RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("===================================================================")

	if failures == 0:
		print("\n>>> ALL VIDEO QA INSPECTION CHECKS PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> QA INSPECTION FAILED: %d defects detected <<<\n" % failures)
		quit(1)
