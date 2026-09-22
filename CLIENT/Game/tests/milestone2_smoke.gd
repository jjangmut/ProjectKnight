extends SceneTree
## Milestone 2 Comprehensive Autonomous Verification Suite
## Tests Game Feel (HitStop, Shake), Boss Commander (Phase 1/2, Shockwaves, Bastion Guard),
## Soul Shard Economy & Drops, and BossHealthBar UI synchronization.

const GameFeelManagerClass = preload("res://scripts/system/game_feel_manager.gd")
const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")
const BossShockwaveClass = preload("res://scripts/enemy/boss_shockwave.gd")
const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")
const ShardDropClass = preload("res://scripts/system/shard_drop.gd")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")

var checks_passed: int = 0
var checks_failed: int = 0


func _init() -> void:
	print("\n--- START MILESTONE 2 AUTONOMOUS VERIFICATION SUITE ---")
	call_deferred("_run_suite")


func _check(condition: bool, msg: String) -> void:
	if condition:
		checks_passed += 1
		print("PASS: %s" % msg)
	else:
		checks_failed += 1
		printerr("FAIL: %s" % msg)


func _run_suite() -> void:
	await _test_game_feel()
	await _test_shard_drop_and_economy()
	await _test_boss_commander_phase_one()
	await _test_boss_commander_phase_two_and_defeat()
	await _test_boss_health_bar()
	await _test_save_persistence()

	print("\n--- MILESTONE 2 SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks_passed, checks_failed])
	if checks_failed == 0:
		print("TEST RESULT: ALL MILESTONE 2 CHECKS PASSED (100%)")
		quit(0)
	else:
		printerr("TEST RESULT: MILESTONE 2 FAILED WITH %d ERRORS" % checks_failed)
		quit(1)


func _test_game_feel() -> void:
	print("\n[Check 1: GameFeelManager - Hit Stop & Camera Shake]")
	var root_node := root
	var gfm = GameFeelManagerClass.ensure_manager(self)
	_check(gfm != null, "GameFeelManager instantiated successfully")


	# Test Hit Stop
	gfm.hit_stop(0.04, 0.05)
	_check(is_equal_approx(Engine.time_scale, 0.05), "Hit Stop set Engine.time_scale to 0.05")

	# Wait for hit stop ticks recovery
	var start_time := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < 60:
		await process_frame
	gfm._process(0.016)
	_check(is_equal_approx(Engine.time_scale, 1.0), "Hit Stop cleanly recovered Engine.time_scale to 1.0")

	# Test Camera Shake trauma
	var test_cam := Camera2D.new()
	root_node.add_child(test_cam)
	gfm.register_camera(test_cam)

	gfm.add_camera_shake(0.50)
	_check(is_equal_approx(gfm.trauma, 0.50), "Camera trauma updated to 0.50")
	gfm._process(0.016)
	_check(test_cam.offset != Vector2.ZERO, "Camera received shake offset based on trauma")

	# Decay trauma
	gfm._process(0.5)
	_check(gfm.trauma < 0.2, "Trauma smoothly decays over time")

	test_cam.queue_free()


func _test_shard_drop_and_economy() -> void:
	print("\n[Check 2: ShardDrop - Physics, Magnet Attraction & Collection]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(200, 580)
	stage.add_child(player)

	var shard := ShardDropClass.new()
	shard.value = 3
	shard.position = Vector2(280, 500)
	shard.init_velocity(Vector2(50.0, -100.0))
	shard.ground_y = 580.0
	stage.add_child(shard)

	_check(shard.value == 3, "Shard initialized with correct value (3)")
	_check(not shard.is_grounded, "Shard starts airborne with physics velocity")

	# Simulate physics frames for falling & bounce
	for i in range(40):
		shard._physics_process(0.016)

	_check(shard.position.y >= 570.0, "Shard fell toward ground floor")

	# Magnet attraction test: shard close to player attracts toward player
	var initial_dist := (player.global_position - shard.global_position).length()
	for i in range(25):
		shard._physics_process(0.016)
	var new_dist := (player.global_position - shard.global_position).length()
	_check(new_dist < initial_dist, "Shard magnetized and accelerated toward player")

	# Simulate collection trigger
	var initial_shards: int = player.soul_shards
	shard._collect()
	_check(player.soul_shards == initial_shards + 3, "Player collected shard and updated wallet count")

	stage.queue_free()
	await process_frame
	await process_frame


func _test_boss_commander_phase_one() -> void:

	print("\n[Check 3: BossCommander - Phase 1 & Bastion Guard]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(100, 580)
	stage.add_child(player)

	var boss := BossCommanderClass.new()
	boss.position = Vector2(200, 580)
	stage.add_child(boss)

	_check(boss.current_hp == 12 and boss.max_hp == 12, "Boss spawned with 12 HP")
	_check(boss.current_phase == 1, "Boss starts in Phase 1")

	# Test Bastion Guard frontal block
	boss.facing_direction = -1.0 # facing left toward player
	boss._start_bastion_guard()
	_check(boss.state == BossCommanderClass.State.BASTION_GUARD, "Boss entered Bastion Guard stance")

	var hp_before := boss.current_hp
	boss.receive_hit() # Player is in front (x=100 < boss x=200, hit_dir = -1 == facing_direction)
	_check(boss.current_hp == hp_before, "Frontal attack during Bastion Guard blocked with 0 damage")

	# End guard and test normal hit
	boss.state = BossCommanderClass.State.CHASE
	boss.receive_hit()
	_check(boss.current_hp == hp_before - 1, "Normal attack deals 1 damage to Boss (11 HP)")

	stage.queue_free()
	await process_frame
	await process_frame


func _test_boss_commander_phase_two_and_defeat() -> void:
	print("\n[Check 4: BossCommander - Phase 2 Enrage & Defeat Burst]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(100, 580)
	stage.add_child(player)

	var boss := BossCommanderClass.new()
	boss.position = Vector2(200, 580)
	stage.add_child(boss)

	# Damage boss down to threshold (6 HP)
	for i in range(5):
		boss.state = BossCommanderClass.State.CHASE
		boss.receive_hit()

	_check(boss.current_hp == 7, "Boss damaged to 7 HP")

	# 6th hit triggers Phase 2
	boss.state = BossCommanderClass.State.CHASE
	boss.receive_hit()
	_check(boss.current_hp == 6, "Boss reached 6 HP (<= 50% HP)")
	_check(boss.current_phase == 2, "Boss transitioned to Phase 2 (ENRAGED)")
	_check(boss.move_speed >= 150.0, "Boss movement speed boosted in Phase 2")
	_check(boss.aura_poly.visible, "Boss Enrage visual aura activated")

	# Test Shockwave Leap
	boss._emit_shockwaves()
	var shockwaves := []
	for child in stage.get_children():
		if child is BossShockwaveClass:
			shockwaves.append(child)
	_check(shockwaves.size() == 2, "Boss leap slam emitted 2 ground shockwaves (left & right)")

	# Test Boss Defeat
	var defeated_signal_received := [false]
	boss.boss_defeated.connect(func(): defeated_signal_received[0] = true)

	for i in range(6):
		boss.is_invulnerable = false
		boss.receive_hit()

	_check(boss.is_dead, "Boss marked dead when HP reaches 0")
	_check(defeated_signal_received[0], "Boss emitted boss_defeated signal")

	# Verify 10 shards spawned
	var shards_spawned := 0
	for child in stage.get_children():
		if child is ShardDropClass:
			shards_spawned += 1
	_check(shards_spawned == 10, "Boss defeat triggered burst of 10 Soul Shards")

	stage.queue_free()
	await process_frame
	await process_frame



func _test_boss_health_bar() -> void:
	print("\n[Check 5: BossHealthBar - UI Sync & Enraged State]")
	var bar: Control = BossHealthBarClass.new()
	root.add_child(bar)

	var boss: CharacterBody2D = BossCommanderClass.new()
	root.add_child(boss)

	bar.call("attach_boss", boss)
	_check(int(bar.get("max_hp")) == 12 and int(bar.get("current_hp")) == 12, "BossHealthBar synchronized with boss HP (12/12)")
	_check(not bool(bar.get("is_enraged")), "BossHealthBar starts in normal phase")

	boss.receive_hit()
	_check(int(bar.get("current_hp")) == 11, "BossHealthBar updated current_hp to 11 on hit")

	# Trigger phase 2
	boss.call("_trigger_phase_two")
	_check(bool(bar.get("is_enraged")), "BossHealthBar activated [ ENRAGED ] mode")

	bar.queue_free()
	boss.queue_free()



func _test_save_persistence() -> void:
	print("\n[Check 6: SaveManager - Economy & Soul Shards Persistence]")
	SaveManagerClass.clear_save()
	_check(SaveManagerClass.get_shards() == 0, "Initial saved soul shards is 0")

	SaveManagerClass.add_shards(25)
	_check(SaveManagerClass.get_shards() == 25, "Successfully added and persisted 25 soul shards")

	SaveManagerClass.add_shards(10)
	_check(SaveManagerClass.get_shards() == 35, "Cumulative soul shards correctly calculated (35)")

	SaveManagerClass.clear_save()
	_check(SaveManagerClass.get_shards() == 0, "Save data cleaned up cleanly")
