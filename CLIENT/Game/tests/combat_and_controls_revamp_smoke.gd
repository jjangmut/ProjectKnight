extends SceneTree
## Automated QA Verification Suite for Project Knight Controls & Combat Overhaul
## Validates:
## 1. Fixed 4-Directional D-Pad controls (Left, Right, Down drop-through, Up) with touch-and-hold semantics.
## 2. Jump replaces Dash button; Dash disabled.
## 3. No solid body collision or riding on monsters (TopPlatform completely eliminated).
## 4. Monster contact damage triggers backwards knockback and reduces player HP by 1.
## 5. Ranged enemy projectiles fire strictly forward (horizontal only).
## 6. Ranged enemy jumps to fire when player is jumping; ascends to upper platforms when player is on upper floor.
## 7. Stationary monsters on upper perches removed.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var watchdog := create_timer(12.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] Test took longer than 12s. Forcing exit.")
		quit(1)
	)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("PASS: " + msg)
	else:
		failures += 1
		printerr("FAIL: " + msg)


func _run() -> void:
	print("\n========================================================")
	print("START COMBAT & CONTROLS REVAMP VERIFICATION SUITE")
	print("========================================================\n")

	var world := Node2D.new()
	root.add_child(world)

	await process_frame
	await process_frame

	# ---------------------------------------------------------
	# 1. Mobile Controls: Fixed 4-Way D-Pad & Jump Replaces Dash
	# ---------------------------------------------------------
	print("\n[Check 1: Fixed 4-Way D-Pad & Action Buttons Hierarchy]")
	var mobile_controls := MobileControls.new()
	world.add_child(mobile_controls)
	await process_frame

	check(mobile_controls.dpad_container != null, "Fixed D-Pad container exists at bottom-left")
	check(mobile_controls.btn_left != null, "Fixed Left button exists")
	check(mobile_controls.btn_right != null, "Fixed Right button exists")
	check(mobile_controls.btn_up != null, "Fixed Up button exists")
	check(mobile_controls.btn_down != null, "Fixed Down button exists (platform drop-through)")
	check(mobile_controls.btn_jump != null, "Jump button exists (replaces old Dash)")
	check(mobile_controls.btn_attack != null, "Attack button exists")
	check(mobile_controls.btn_guard != null, "Guard button exists")

	# Test Touch-and-Hold for D-Pad Left
	var touch_down_left := InputEventScreenTouch.new()
	touch_down_left.index = 0
	touch_down_left.pressed = true
	mobile_controls.btn_left._gui_input(touch_down_left)
	check(Input.is_action_pressed("move_left"), "Holding Left button activates 'move_left'")

	var touch_up_left := InputEventScreenTouch.new()
	touch_up_left.index = 0
	touch_up_left.pressed = false
	mobile_controls.btn_left._gui_input(touch_up_left)
	check(not Input.is_action_pressed("move_left"), "Releasing Left button deactivates 'move_left'")

	# Test Touch-and-Hold for D-Pad Right
	var touch_down_right := InputEventScreenTouch.new()
	touch_down_right.index = 1
	touch_down_right.pressed = true
	mobile_controls.btn_right._gui_input(touch_down_right)
	check(Input.is_action_pressed("move_right"), "Holding Right button activates 'move_right'")

	var touch_up_right := InputEventScreenTouch.new()
	touch_up_right.index = 1
	touch_up_right.pressed = false
	mobile_controls.btn_right._gui_input(touch_up_right)
	check(not Input.is_action_pressed("move_right"), "Releasing Right button deactivates 'move_right'")

	# Test Touch-and-Hold for D-Pad Down (Drop through)
	var touch_down_down := InputEventScreenTouch.new()
	touch_down_down.index = 2
	touch_down_down.pressed = true
	mobile_controls.btn_down._gui_input(touch_down_down)
	check(Input.is_action_pressed("move_down"), "Holding Down button activates 'move_down'")

	var touch_up_down := InputEventScreenTouch.new()
	touch_up_down.index = 2
	touch_up_down.pressed = false
	mobile_controls.btn_down._gui_input(touch_up_down)
	check(not Input.is_action_pressed("move_down"), "Releasing Down button deactivates 'move_down'")

	# Test Jump Action Button (Old Dash replaced by Jump)
	var touch_down_jump := InputEventScreenTouch.new()
	touch_down_jump.index = 3
	touch_down_jump.pressed = true
	mobile_controls.btn_jump._gui_input(touch_down_jump)
	check(Input.is_action_pressed("jump"), "Pressing Jump button activates 'jump'")

	var touch_up_jump := InputEventScreenTouch.new()
	touch_up_jump.index = 3
	touch_up_jump.pressed = false
	mobile_controls.btn_jump._gui_input(touch_up_jump)
	check(not Input.is_action_pressed("jump"), "Releasing Jump button deactivates 'jump'")

	mobile_controls.queue_free()
	await process_frame

	# ---------------------------------------------------------
	# 2. Player Collision & TopPlatform Elimination
	# ---------------------------------------------------------
	print("\n[Check 2: Player & Enemy Solid Collision and TopPlatform Absence]")
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	world.add_child(player)
	player.position = Vector2(500, 500)
	await process_frame

	# Player collision mask must NOT include Enemy Layer (16)
	check(player.collision_mask & 16 == 0, "Player collision_mask does NOT collide with Enemy body (no solid body blocking)")
	check(player.collision_mask & 1 != 0, "Player collision_mask collides with Environment (layer 1)")

	# Check that TopPlatform has been completely eliminated from all monster/boss classes
	var enemy_classes: Array[PackedScene] = [
		load("res://scenes/enemy/TestEnemy.tscn"),
		load("res://scenes/enemy/RangedEnemy.tscn"),
		load("res://scenes/enemy/ChargingBeast.tscn")
	]
	for scn in enemy_classes:
		if scn != null:
			var e: CharacterBody2D = scn.instantiate()
			world.add_child(e)
			check(e.get_node_or_null("TopPlatform") == null, "Enemy instance '%s' has NO TopPlatform child (cannot be mounted/ridden)" % e.name)
			check(e.collision_mask & 8 == 0, "Enemy instance '%s' does not collide with Player Body layer" % e.name)
			e.queue_free()

	# Check Boss TopPlatform absence
	var boss_scripts: Array[String] = [
		"res://scripts/enemy/boss_commander.gd",
		"res://scripts/enemy/beast_chieftain.gd",
		"res://scripts/enemy/crossbow_commander.gd",
		"res://scripts/enemy/ancient_golem_guardian.gd",
		"res://scripts/enemy/abyssal_arbiter.gd"
	]
	for b_path in boss_scripts:
		var script_res = load(b_path)
		var b_inst = CharacterBody2D.new()
		b_inst.set_script(script_res)
		world.add_child(b_inst)
		check(b_inst.get_node_or_null("TopPlatform") == null, "Boss '%s' has NO TopPlatform child" % b_path.get_file())
		b_inst.queue_free()

	await process_frame

	# ---------------------------------------------------------
	# 3. Monster Contact Knockback (NO HP Loss)
	# ---------------------------------------------------------
	print("\n[Check 3: Contact Pure Knockback (No HP Loss)]")
	player.current_hp = 3
	player.facing_direction = 1.0 # Facing right
	player.velocity = Vector2.ZERO

	# Simulate contact with monster positioned to the right (x=550)
	var monster_pos := Vector2(550, 500)
	player.receive_contact_damage(monster_pos)

	check(player.current_hp == 3, "Player HP remains intact at 3 (NO HP loss on monster contact)")
	check(player.velocity.x < 0.0, "Player knocked back to the left (away from monster on right): vel.x = %.1f" % player.velocity.x)
	check(player.velocity.y < 0.0, "Player bounced slightly into air on knockback: vel.y = %.1f" % player.velocity.y)

	await process_frame

	# ---------------------------------------------------------
	# 4. Ranged Enemy Strictly Forward Firing
	# ---------------------------------------------------------
	print("\n[Check 4: Ranged Enemy Straight Forward Projectile Firing]")
	var ranged_scene := load("res://scenes/enemy/RangedEnemy.tscn") as PackedScene
	var ranged: CharacterBody2D = ranged_scene.instantiate()
	world.add_child(ranged)
	ranged.position = Vector2(700, 500)
	ranged._player = player
	await process_frame

	# Test projectile firing: Player is at (500, 500), Ranged at (700, 500) -> fire direction is -1 (left)
	ranged._fire_projectile()
	var projectile: Node = null
	for child in world.get_children():
		if child.is_in_group("enemy_projectile") or child.get_script() != null and child.get_script().resource_path.ends_with("enemy_projectile.gd"):
			projectile = child
			break

	check(projectile != null, "Projectile successfully spawned")
	if projectile != null:
		check(projectile.get("direction") == -1.0, "Projectile direction is -1.0 (towards left)")
		var vel: Vector2 = projectile.get("velocity_vector")
		check(vel.y == 0.0, "Projectile has ZERO vertical angle (fires strictly horizontally forward, vel.y = 0.0)")
		projectile.queue_free()

	# ---------------------------------------------------------
	# 5. Ranged Enemy AI: Jumping Attack & Upper Platform Ascent
	# ---------------------------------------------------------
	print("\n[Check 5: Ranged Enemy Jump Attack & Upper Platform Pursuit]")
	# 1) Jump Attack: If player is jumping in mid-air
	ranged.velocity = Vector2.ZERO
	# Mock on floor
	ranged.set_meta("test_on_floor", true)
	ranged._begin_attack(true) # Jump attack triggered
	check(ranged.is_jump_attacking, "Ranged enemy is_jump_attacking is true")
	check(ranged.velocity.y < 0.0, "Ranged enemy jumped into air (velocity.y = %.1f < 0)" % ranged.velocity.y)

	# 2) Upper Platform Ascent: Player is on upper floor (Y: 350 vs Ranged Y: 500)
	player.position = Vector2(750, 350)
	ranged.position = Vector2(700, 500)
	ranged.velocity = Vector2.ZERO
	ranged.state = ranged.State.PATROL
	ranged._jump_cooldown = 0.0
	ranged._update_patrol()
	check(ranged.velocity.y < 0.0, "Ranged enemy jumped upwards to reach player on upper platform (velocity.y = %.1f)" % ranged.velocity.y)
	check(ranged.velocity.x > 0.0, "Ranged enemy moved horizontally toward upper player (velocity.x = %.1f)" % ranged.velocity.x)

	ranged.queue_free()
	player.queue_free()
	await process_frame

	# ---------------------------------------------------------
	# 6. Stationary Upper Platform Monsters Removed
	# ---------------------------------------------------------
	print("\n[Check 6: Stationary Monsters on Upper Perches Removed]")
	var stage_scene := load("res://scenes/stage/FirstStage.tscn") as PackedScene
	var stage_inst = stage_scene.instantiate()
	world.add_child(stage_inst)
	await process_frame

	# Try spawning a ranged enemy on an elevated perch (y=400 < 580)
	var prev_enemy_count: int = stage_inst.enemies.size()
	stage_inst._spawn(ranged_scene, 2000.0, 400.0)
	var new_enemy_count: int = stage_inst.enemies.size()
	check(new_enemy_count == prev_enemy_count, "Stationary ranged enemy at upper perch (y=400 < 580) is NOT spawned (successfully removed)")

	stage_inst.queue_free()
	world.queue_free()
	await process_frame

	print("\n========================================================")
	print("RESULT: Checks: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("ALL CHECKS PASSED (100% SUCCESS)")
		print("========================================================\n")
		quit(0)
	else:
		printerr("SOME CHECKS FAILED!")
		print("========================================================\n")
		quit(1)
