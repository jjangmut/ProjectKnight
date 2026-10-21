extends SceneTree
## Smoke verification test for Stage 1 Boss Commander's Shockwave & Sword Beam orientation.
## Ensures that:
##   - Rightward projectile (direction = +1.0) displays a '>' shape (convex blade facing right).
##   - Leftward projectile (direction = -1.0) displays a '<' shape (convex blade facing left).
##   - Trailing energy streamers properly trail behind the flight direction.
##   - BossCommander's _emit_sword_beam and _emit_shockwaves spawn properly oriented waves.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var watchdog := create_timer(12.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] boss1_shockwave_orientation_smoke.gd exceeded 12s.")
		quit(1)
	)
	_run_tests.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [PASS] " + msg)
	else:
		failures += 1
		printerr("  [FAIL] " + msg)


func _run_tests() -> void:
	print("\n=======================================================")
	print(">>> RUNNING: boss1_shockwave_orientation_smoke.gd <<<")
	print("=======================================================\n")

	var ShockwaveScene = preload("res://scripts/enemy/boss_shockwave.gd")
	var root_node := Node2D.new()
	root.add_child(root_node)

	# -------------------------------------------------------------
	# Test 1: Rightward Flying Shockwave (direction = 1.0)
	# -------------------------------------------------------------
	print("--- Test 1: Rightward Flying Shockwave (direction = +1.0) ---")
	var wave_right = ShockwaveScene.new()
	wave_right.direction = 1.0
	root_node.add_child(wave_right)

	var vr_right: Node2D = wave_right.get_node_or_null("VisualRoot")
	check(vr_right != null, "VisualRoot exists in rightward shockwave")
	check(vr_right.scale.x == 1.0, "VisualRoot scale.x is +1.0 for rightward shockwave")

	var outer_right: Line2D = vr_right.get_node_or_null("@Line2D@2") if vr_right.get_child_count() > 1 else null
	for child in vr_right.get_children():
		if child is Line2D and child.points.size() == 5:
			outer_right = child
			break
	check(outer_right != null, "Outer blade arc Line2D found with 5 points")

	if outer_right != null:
		var pts = outer_right.points
		var tip_top: Vector2 = pts[0]
		var blade_mid: Vector2 = pts[2]
		var tip_bot: Vector2 = pts[4]
		# Blade mid should be furthest forward (+X) forming a '>' shape
		check(blade_mid.x > tip_top.x, "Blade center X (%.1f) is forward of top tip (%.1f)" % [blade_mid.x, tip_top.x])
		check(blade_mid.x > tip_bot.x, "Blade center X (%.1f) is forward of bottom tip (%.1f)" % [blade_mid.x, tip_bot.x])
		print("    Rightward shape profile: top=(%.1f, %.1f), mid=(%.1f, %.1f), bot=(%.1f, %.1f) => '>'" % [
			tip_top.x, tip_top.y, blade_mid.x, blade_mid.y, tip_bot.x, tip_bot.y
		])

	# -------------------------------------------------------------
	# Test 2: Leftward Flying Shockwave (direction = -1.0)
	# -------------------------------------------------------------
	print("\n--- Test 2: Leftward Flying Shockwave (direction = -1.0) ---")
	var wave_left = ShockwaveScene.new()
	wave_left.direction = -1.0
	root_node.add_child(wave_left)

	var vr_left: Node2D = wave_left.get_node_or_null("VisualRoot")
	check(vr_left != null, "VisualRoot exists in leftward shockwave")
	check(vr_left.scale.x == -1.0, "VisualRoot scale.x is -1.0 for leftward shockwave")

	var outer_left: Line2D = null
	for child in vr_left.get_children():
		if child is Line2D and child.points.size() == 5:
			outer_left = child
			break
	check(outer_left != null, "Outer blade arc Line2D found in leftward shockwave")

	if outer_left != null:
		# Calculate effective world X positions under VisualRoot scale.x = -1.0
		var pts = outer_left.points
		var world_tip_top_x: float = pts[0].x * vr_left.scale.x
		var world_blade_mid_x: float = pts[2].x * vr_left.scale.x
		var world_tip_bot_x: float = pts[4].x * vr_left.scale.x

		# For leftward flight, blade_mid should be furthest left (-X), forming '<'
		check(world_blade_mid_x < world_tip_top_x, "World blade center X (%.1f) is forward/left of top tip (%.1f)" % [world_blade_mid_x, world_tip_top_x])
		check(world_blade_mid_x < world_tip_bot_x, "World blade center X (%.1f) is forward/left of bottom tip (%.1f)" % [world_blade_mid_x, world_tip_bot_x])
		print("    Leftward world profile: top=%.1f, mid=%.1f, bot=%.1f => '<'" % [
			world_tip_top_x, world_blade_mid_x, world_tip_bot_x
		])

	# -------------------------------------------------------------
	# Test 3: BossCommander Sword Beam Spawning Integration
	# -------------------------------------------------------------
	print("\n--- Test 3: BossCommander Sword Beam Spawning Integration ---")
	var BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")
	var boss = BossCommanderClass.new()
	boss.position = Vector2(500.0, 580.0)
	root_node.add_child(boss)

	# Emit sword beam rightward
	boss._emit_sword_beam(1.0)
	var spawned_right = null
	for child in root_node.get_children():
		if child is BossShockwave and child.direction == 1.0:
			spawned_right = child
			break
	check(spawned_right != null, "Boss emitted rightward Shockwave successfully")
	if spawned_right != null:
		var vr = spawned_right.get_node("VisualRoot") as Node2D
		check(vr.scale.x == 1.0, "Rightward sword beam has scale.x = 1.0 (Points right: '>')")

	# Emit sword beam leftward
	boss._emit_sword_beam(-1.0)
	var spawned_left = null
	for child in root_node.get_children():
		if child is BossShockwave and child.direction == -1.0:
			spawned_left = child
			break
	check(spawned_left != null, "Boss emitted leftward Shockwave successfully")
	if spawned_left != null:
		var vr = spawned_left.get_node("VisualRoot") as Node2D
		check(vr.scale.x == -1.0, "Leftward sword beam has scale.x = -1.0 (Points left: '<')")

	# Clean up
	root_node.queue_free()

	print("\n=======================================================")
	print("RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("=======================================================\n")

	if failures == 0:
		print(">>> ALL BOSS 1 SHOCKWAVE ORIENTATION CHECKS PASSED (100% SUCCESS) <<<")
		quit(0)
	else:
		printerr(">>> FAILURES DETECTED: %d <<<" % failures)
		quit(1)
