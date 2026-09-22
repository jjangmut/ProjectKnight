extends SceneTree
## Automated QA Smoke Test for Vertical Traversal & Responsive Monster AI.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func _run() -> void:
	print("--- START VERTICAL TRAVERSAL & RESPONSIVE AI SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	# 1. Ground floor (y=300, top surface y=280)
	var floor_body := StaticBody2D.new()
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(2000, 40)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position = Vector2(500, 300)
	world.add_child(floor_body)

	# 2. Elevated one-way platform (y=180, top surface y=170)
	var platform := StaticBody2D.new()
	var plat_col := CollisionShape2D.new()
	var plat_shape := RectangleShape2D.new()
	plat_shape.size = Vector2(400, 20)
	plat_col.shape = plat_shape
	plat_col.one_way_collision = true
	platform.add_child(plat_col)
	platform.position = Vector2(500, 180)
	world.add_child(platform)

	# Spawn player initially far away so enemy patrols without chasing
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(1600, 240) # Far away from enemy
	world.add_child(player)

	# Spawn enemy on ground floor (y=240, gravity lands on y=250)
	var enemy_scene := load("res://scenes/enemy/TestEnemy.tscn") as PackedScene
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy.position = Vector2(500, 240)
	world.add_child(enemy)

	for i in range(15):
		await physics_frame

	# Check 1: Responsive AI & Rendering Layer Parameters
	print("[Check 1: AI & Rendering Parameters]")
	check(enemy.detection_range >= 560.0, "Detection range expanded to >= 560px")
	check(enemy.patrol_distance >= 240.0, "Patrol distance expanded to >= 240px")
	check(player.z_index == 10, "Player z_index is set to 10 (rendered in front of platforms)")
	check(enemy.z_index == 5, "Enemy z_index is set to 5 (rendered in front of platforms)")

	# Check 2: Active Patrol when player is far away
	print("[Check 2: Active Patrol]")
	check(enemy.state == enemy.State.PATROL, "Enemy is in PATROL state when player is far")
	check(absf(enemy.velocity.x) > 50.0, "Patrol velocity is active (> 50 px/s)")

	# Check 3: Jump Up (Enemy below, Player on elevated platform)
	print("[Check 3: Jump Up to Elevated Platform]")
	# Enemy lands on ground while player is still far away
	enemy.velocity = Vector2.ZERO
	enemy.position = Vector2(480, 240)
	for i in range(15):
		await physics_frame

	check(enemy.is_on_floor(), "Enemy safely settled on ground floor")

	# Now place player on elevated platform right above enemy
	player.position = Vector2(500, 140)
	enemy.state = enemy.State.CHASE
	for i in range(5):
		await physics_frame

	check(enemy.velocity.y < -300.0 or enemy.position.y < 230.0, "Enemy triggers upward jump or ascends toward elevated player")

	# Check 4: Drop Down (Enemy on platform, Player on ground floor)
	print("[Check 4: Drop Down from Platform]")
	enemy.velocity = Vector2.ZERO
	enemy.position = Vector2(500, 135) # Land on platform
	for i in range(15):
		await physics_frame

	check(enemy.is_on_floor(), "Enemy safely settled on platform")
	# Move player to ground below platform
	player.position = Vector2(520, 240)
	enemy.state = enemy.State.CHASE
	var enemy_y_start := enemy.position.y
	print("Before drop - enemy y: ", enemy.position.y, " floor: ", enemy.is_on_floor(), " state: ", enemy.state)

	for i in range(25):
		await physics_frame
		if i % 5 == 0:
			print("Frame ", i, " - enemy y: ", enemy.position.y, " floor: ", enemy.is_on_floor(), " vel: ", enemy.velocity)

	check(enemy.position.y > enemy_y_start + 20.0, "Enemy dropped down through one-way platform to pursue player below")

	print("--- VERTICAL TRAVERSAL SMOKE SUMMARY ---")
	print("Checks: %d, Failures: %d" % [checks, failures])

	if failures > 0:
		print("TEST RESULT: FAILED")
		quit(1)
	else:
		print("TEST RESULT: ALL VERTICAL TRAVERSAL CHECKS PASSED")
		quit(0)
