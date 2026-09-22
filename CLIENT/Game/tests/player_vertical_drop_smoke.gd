extends SceneTree
## Automated QA Smoke Test for Player One-Way Platform Drop & Solid Ground Safety.

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
	print("\n--- START PLAYER ONE-WAY DROP & PLATFORM TRAVERSAL SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	# 1. Ground floor (Solid StaticBody2D at y=400, top surface y=380)
	var ground := StaticBody2D.new()
	var ground_col := CollisionShape2D.new()
	var ground_shape := RectangleShape2D.new()
	ground_shape.size = Vector2(2000, 40)
	ground_col.shape = ground_shape
	ground_col.one_way_collision = false # Solid ground
	ground.add_child(ground_col)
	ground.position = Vector2(500, 400)
	world.add_child(ground)

	# 2. One-way platform at y=250 (top surface y=240)
	var platform := StaticBody2D.new()
	var plat_col := CollisionShape2D.new()
	var plat_shape := RectangleShape2D.new()
	plat_shape.size = Vector2(400, 20)
	plat_col.shape = plat_shape
	plat_col.one_way_collision = true # One-way platform
	platform.add_child(plat_col)
	platform.position = Vector2(500, 250)
	world.add_child(platform)

	# 3. Instantiate Player on top of one-way platform
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(500, 200)
	world.add_child(player)

	# Settle on platform
	for i in range(25):
		await physics_frame

	print("\n[Check 1: Player Settled on One-Way Platform]")
	check(player.is_on_floor(), "Player landed and settled on one-way platform")
	check(player.position.y < 245.0, "Player vertical position is above platform surface (y: %f)" % player.position.y)

	print("\n[Check 2: Drop Down Through One-Way Platform on move_down]")
	var y_before_drop := player.position.y
	Input.action_press("move_down")
	await physics_frame
	Input.action_release("move_down")

	# Wait for drop frames
	for i in range(25):
		await physics_frame

	check(player.position.y > y_before_drop + 30.0, "Player dropped through one-way platform (y before: %f, y after: %f)" % [y_before_drop, player.position.y])

	# Let player fall to solid ground floor
	for i in range(40):
		await physics_frame

	print("\n[Check 3: Player Lands on Solid Ground Floor]")
	check(player.is_on_floor(), "Player landed on solid ground floor")
	check(player.position.y > 340.0 and player.position.y < 385.0, "Player safely positioned on ground floor (y: %f)" % player.position.y)

	print("\n[Check 4: Solid Ground Safety - Cannot drop through solid terrain]")
	var ground_y := player.position.y
	Input.action_press("move_down")
	for i in range(15):
		await physics_frame
	Input.action_release("move_down")

	for i in range(10):
		await physics_frame

	check(absf(player.position.y - ground_y) < 5.0, "Player remained securely on solid ground (did not fall through, diff: %f)" % absf(player.position.y - ground_y))
	check(player.is_on_floor(), "Player still on floor after pressing move_down on solid terrain")

	print("\n--- PLAYER ONE-WAY DROP SMOKE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: ALL PLAYER DROP CHECKS PASSED (100%)\n")
		quit(0)
	else:
		push_error("TEST RESULT: PLAYER DROP TEST FAILED")
		quit(1)
