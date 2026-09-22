extends SceneTree
## Automated QA Regression Test for Character Stacking Bug Fix
## Verifies that:
## 1. Enemies falling from above do not stack/land on player head as a floor.
## 2. Player is never trapped under enemy: jump, horizontal move, and dash work freely.
## 3. Player attacks successfully hit enemies at point-blank / overlapping range (no blind spot).
## 4. Airborne enemies do not enter endless attack lock above player head.

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
	print("\n--- START CHARACTER STACKING & OVERLAP BUG FIX TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	# 1. Ground floor setup (y=400, top surface y=380)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(2000, 40)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position = Vector2(500, 400)
	world.add_child(floor_body)

	# Spawn Player
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(500, 320)
	world.add_child(player)

	# Spawn Enemy directly above player's head
	var enemy_scene := load("res://scenes/enemy/TestEnemy.tscn") as PackedScene
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy.position = Vector2(500, 200) # 120px directly above player
	world.add_child(enemy)

	# Wait for physics settlement
	for i in range(30):
		await physics_frame

	var player_settled_y := player.position.y
	check(player.is_on_floor(), "Player safely settled on floor (y=%.1f)" % player_settled_y)
	check(player.collision_layer == 8, "Player collision_layer is isolated to layer 8")
	check(player.collision_mask == 1, "Player collision_mask targets terrain layer 1 only")
	check(enemy.collision_layer == 16, "Enemy collision_layer is isolated to layer 16")
	check(enemy.collision_mask == 1, "Enemy collision_mask targets terrain layer 1 only")

	print("\n[Check 1: Enemy Falls Through Player Head without Stacking]")
	# Wait for enemy to fall directly through player position
	for i in range(40):
		await physics_frame

	check(enemy.is_on_floor(), "Enemy reached and settled on ground floor instead of player head")
	check(absf(enemy.position.y - player_settled_y) < 15.0, "Enemy Y (%.1f) is on the ground level alongside player (%.1f)" % [enemy.position.y, player_settled_y])

	print("\n[Check 2: Player Movement & Jump Freedom When Overlapping Enemy]")
	# Player attempts upward jump with enemy right on top / overlapping
	player.position = enemy.position # force exact overlap
	player.velocity.y = player.jump_velocity
	await physics_frame
	check(player.velocity.y < -400.0, "Player jumped upward freely without ceiling blockage from enemy (vel.y=%.1f)" % player.velocity.y)

	# Settle player back
	player.position = enemy.position
	for i in range(30):
		await physics_frame

	# Player attempts horizontal walk through enemy
	player.velocity.x = player.move_speed
	for i in range(10):
		await physics_frame
	check(player.position.x > enemy.position.x, "Player walked right through enemy without solid body lock (pos.x=%.1f vs enemy=%.1f)" % [player.position.x, enemy.position.x])

	# Player dash through enemy
	player.position = enemy.position - Vector2(30, 0)
	player.facing_direction = 1.0
	player.dash()
	check(player.is_dashing, "Player dash activated while in contact with enemy")
	for i in range(10):
		await physics_frame
	check(player.position.x > enemy.position.x, "Player dashed through enemy smoothly")

	print("\n[Check 3: Player Point-Blank Attack Hits Overlapping Enemy]")
	# Position enemy overlapping / point-blank to player
	enemy.position = Vector2(500, player_settled_y)
	player.position = Vector2(495, player_settled_y) # 5px overlap!
	player.facing_direction = 1.0
	var enemy_initial_hp: int = enemy.current_hp
	player._start_attack()
	# Let physics frame process Area2D overlap callbacks
	for i in range(10):
		await physics_frame

	check(enemy.current_hp < enemy_initial_hp, "Player point-blank attack struck overlapping enemy (HP: %d -> %d)" % [enemy_initial_hp, enemy.current_hp])

	print("\n[Check 4: Soft Separation & Airborne Attack Lock Prevention]")
	# Spawn enemy in air right above player
	var airborne_enemy: CharacterBody2D = enemy_scene.instantiate()
	airborne_enemy.position = Vector2(player.position.x, player.position.y - 40.0) # In air right above
	world.add_child(airborne_enemy)
	await physics_frame
	check(airborne_enemy.state != 2, "Airborne enemy does not enter ATTACK state (state=%d) while falling above player" % airborne_enemy.state)

	print("\n--- TEST SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: CHARACTER STACKING BUG FIX VERIFIED (100% PASS)\n")
		quit(0)
	else:
		push_error("TEST RESULT: CHARACTER STACKING TEST FAILED")
		quit(1)
