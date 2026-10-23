extends SceneTree
## Project Knight - Autonomous Video QA Inspection Agent
## Automated inspector verifying:
## 1. Camera View Angle (Immortal Warrior horizontal view: Yaw = 0.0 deg, Pitch ~ -32 deg)
## 2. Player Attack Motion (Sprite shifts to attack sheet during strikes)
## 3. Monster/Boss Facing Alignment (Always faces player head-on; no facing away)
## 4. Visual Scale & Single Frame Rendering (hframes/vframes split; no raw sheet exposure)

const ArenaScene = preload("res://scenes/side_quarter_view/SideQuarterViewArena.tscn")
const AttackSheetTexture = preload("res://assets/player_frames/attack_v1.png")
const PaladinTexture = preload("res://assets/player/knight_stage1_paladin.png")

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
	# Inspection 2: Player Attack Motion & Frame Transition
	# -------------------------------------------------------------
	print("\n--- Inspection 2: Player Attack Motion & Frame Verification ---")
	check(player.sprite_3d.texture == PaladinTexture, "Initial player sprite is Idle Paladin texture")
	check(player.sprite_3d.hframes == 1 and player.sprite_3d.vframes == 1, "Idle sprite is 1x1 single frame")

	# Trigger Attack
	player.attack_cooldown = 0.0
	player.start_attack()
	check(player.sprite_3d.texture == AttackSheetTexture, "Player texture transitioned to AttackSheetTexture during attack")
	check(player.sprite_3d.hframes == 2 and player.sprite_3d.vframes == 2, "Attack sprite configured as 2x2 sprite sheet")
	check(player.sprite_3d.frame == 0, "Attack Frame 0 (Combo 1 slash) active")

	await _advance_frames(14)
	check(player.sprite_3d.texture == PaladinTexture, "Player returned to Idle Paladin texture after attack duration")
	check(player.sprite_3d.hframes == 1, "Player hframes restored to 1")

	# -------------------------------------------------------------
	# Inspection 3: Monster & Boss Facing Alignment (Always Faces Player)
	# -------------------------------------------------------------
	print("\n--- Inspection 3: Monster & Boss Mutual Facing Alignment ---")
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
	# Inspection 4: Visual Scale & Single Frame Rendering
	# -------------------------------------------------------------
	print("\n--- Inspection 4: Visual Scale & Single Frame Rendering ---")
	check(boss.sprite_3d.hframes == 4 and boss.sprite_3d.vframes == 3, "Boss sprite sheet split into 4x3 frames (No raw sheet exposure)")
	check(is_equal_approx(boss.sprite_3d.pixel_size, 0.0082), "Boss calibrated height is ~2.45m (pixelsize = %.4f)" % boss.sprite_3d.pixel_size)
	check(is_equal_approx(player.sprite_3d.pixel_size, 0.0016), "Player calibrated height is ~1.77m (pixelsize = %.4f)" % player.sprite_3d.pixel_size)

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
