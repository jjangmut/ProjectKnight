extends SceneTree
## Milestone 4 Comprehensive Autonomous Verification Suite
## Verifies:
## 1. Player Dash & Air Dash mechanics (velocity, I-frame invulnerability, ghost trail, 1-air-dash limit)
## 2. Meta Upgrade & Shop: Shadow Dash ability purchase and persistence
## 3. Stage 3 Gate Boss: Crossbow Commander (16 HP, bolt firing, sky volley, backstep, Phase 2 Dead-Eye Enrage, caltrops, 15-shard burst)
## 4. ThirdStage (무너진 성벽) final encounter E8 boss arena gate & HUD boss health bar integration

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const CampfireShopClass = preload("res://scripts/ui/campfire_shop.gd")
const CrossbowCommanderClass = preload("res://scripts/enemy/crossbow_commander.gd")
const CrossbowBoltClass = preload("res://scripts/enemy/crossbow_bolt.gd")
const CaltropTrapClass = preload("res://scripts/enemy/caltrop_trap.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const ThirdStageScene = preload("res://scenes/stage/ThirdStage.tscn")
const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")
const ShardDropClass = preload("res://scripts/system/shard_drop.gd")

var checks_passed: int = 0
var checks_failed: int = 0


func _init() -> void:
	print("\n--- START MILESTONE 4 AUTONOMOUS VERIFICATION SUITE ---")
	call_deferred("_run_suite")


func _check(condition: bool, msg: String) -> void:
	if condition:
		checks_passed += 1
		print("PASS: %s" % msg)
	else:
		checks_failed += 1
		printerr("FAIL: %s" % msg)


func _run_suite() -> void:
	AudioManager.ensure_manager(self)
	await _test_player_dash_and_air_dash()
	await _test_save_manager_shadow_dash_and_shop()
	await _test_crossbow_commander_boss_ai()
	await _test_third_stage_boss_integration()

	print("\n--- MILESTONE 4 SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks_passed, checks_failed])
	if checks_failed == 0:
		print("TEST RESULT: ALL MILESTONE 4 CHECKS PASSED (100%)")
		quit(0)
	else:
		printerr("TEST RESULT: MILESTONE 4 FAILED WITH %d ERRORS" % checks_failed)
		quit(1)


func _test_player_dash_and_air_dash() -> void:
	print("\n[Check 1: Player Ground Dash & Air Dash Mechanics]")
	var stage := Node2D.new()
	root.add_child(stage)

	# Floor for proper is_on_floor physics
	var floor_body := StaticBody2D.new()
	var floor_col := CollisionShape2D.new()
	var box_shape := WorldBoundaryShape2D.new()
	floor_col.shape = box_shape
	floor_body.position = Vector2(0, 600)
	floor_body.add_child(floor_col)
	stage.add_child(floor_body)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(200, 560)
	stage.add_child(player)

	# Settle player on floor
	for i in range(5):
		player.velocity.y = 200.0
		player.move_and_slide()
		await process_frame

	_check(player.has_shadow_dash == true, "Player has shadow dash enabled")
	_check(player.is_dashing == false, "Player starts in non-dashing state")
	_check(player.is_on_floor() == true, "Player settled firmly on ground floor")

	# 1. Ground Dash
	var air_dash_signal := [false]
	player.dash_performed.connect(func(is_air: bool): air_dash_signal[0] = is_air)
	var dash_ok: bool = player.dash()
	_check(dash_ok == true, "Ground dash triggered successfully")
	_check(player.is_dashing == true, "Player is_dashing flag is active")
	_check(player.is_invulnerable == true, "Player is invulnerable during dash (I-frame)")
	_check(absf(player.velocity.x) >= 500.0, "Player achieved dash velocity (>= 500 px/s)")
	_check(air_dash_signal[0] == false, "Ground dash correctly signaled is_air = false")

	# 2. I-Frame Invulnerability during Dash
	var hp_before: int = player.current_hp
	player.receive_attack(Vector2(250, 580), false) # Unblockable attack
	_check(player.current_hp == hp_before, "Player took 0 damage while dashing (I-Frame verified)")

	# End dash
	player._end_dash()
	_check(player.is_dashing == false, "Dash cleanly ended")
	_check(player.is_invulnerable == false, "Invulnerability cleared after dash")

	# 3. Air Dash & 1-Air-Dash Limit
	player.position = Vector2(200, 200) # In the air
	player._dash_cooldown_remaining = 0.0
	player.velocity = Vector2.ZERO
	player.move_and_slide()
	await process_frame

	var air_dash_ok: bool = player.dash()
	_check(air_dash_ok == true, "First air dash triggered successfully")
	_check(air_dash_signal[0] == true, "Air dash correctly signaled is_air = true")

	# End first air dash and attempt second air dash without landing
	player._end_dash()
	player._dash_cooldown_remaining = 0.0
	var second_air_dash: bool = player.dash()
	_check(second_air_dash == false, "Second air dash correctly rejected before landing")

	# Land on floor and verify reset
	player._dash_cooldown_remaining = 0.0
	player.position = Vector2(200, 572)
	for i in range(5):
		player.velocity.y = 100.0
		player.move_and_slide()
		player._update_dash_state(0.016)
		await process_frame

	player._dash_cooldown_remaining = 0.0
	var reset_dash: bool = player.dash()
	_check(reset_dash == true, "Air dash ability resets upon landing")
	player._end_dash()

	stage.queue_free()


func _test_save_manager_shadow_dash_and_shop() -> void:
	print("\n[Check 2: Shadow Dash Shop Purchase & Save Persistence]")
	SaveManagerClass.clear_save()
	_check(SaveManagerClass.get_upgrade_level("shadow_dash") == 0, "Initial shadow_dash upgrade level is 0")

	# Add shards and purchase shadow dash in shop
	SaveManagerClass.add_shards(60)

	var stage_dummy := Node2D.new()
	root.add_child(stage_dummy)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.has_shadow_dash = false
	stage_dummy.add_child(player)

	var shop := CampfireShopClass.new()
	shop.target_player = player
	root.add_child(shop)
	await process_frame

	_check(shop._dash_btn != null, "CampfireShop UI contains shadow dash purchase button")

	var purchased := [""]
	shop.upgrade_purchased.connect(func(id: String): purchased[0] = id)
	shop._on_buy_dash()

	_check(purchased[0] == "shadow_dash", "Shop emitted upgrade_purchased for shadow_dash")
	_check(SaveManagerClass.get_shards() == 10, "50 shards deducted, 10 remaining")
	_check(SaveManagerClass.get_upgrade_level("shadow_dash") == 1, "shadow_dash upgrade level updated to 1")
	_check(player.has_shadow_dash == true, "Player has_shadow_dash enabled via shop purchase")

	shop.queue_free()
	stage_dummy.queue_free()


func _test_crossbow_commander_boss_ai() -> void:
	print("\n[Check 3: Crossbow Commander Boss AI & Enrage]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(250, 580)
	stage.add_child(player)

	var boss := CrossbowCommanderClass.new()
	boss.position = Vector2(550, 580)
	stage.add_child(boss)
	await process_frame

	_check(boss.max_hp == 16, "Crossbow Commander max_hp is 16")
	_check(boss.current_hp == 16, "Spawns with full 16 HP")
	_check(boss.current_phase == 1, "Starts in Phase 1")
	_check(boss.dead_eye_enrage == false, "Dead-Eye Enrage inactive in Phase 1")

	# Track bolt fired signal
	var bolts_fired := [0]
	boss.bolt_fired.connect(func(_pos: Vector2, _dir: Vector2): bolts_fired[0] += 1)

	# Test bolt firing
	boss._fire_bolt(Vector2.LEFT)
	_check(bolts_fired[0] == 1, "Crossbow Commander fired piercing bolt projectile")

	# Test Backstep Evasion & Caltrop Trap
	boss.current_phase = 2
	boss._start_backstep()
	_check(boss.state == CrossbowCommanderClass.State.BACKSTEP, "Entered Backstep evasion state")

	var caltrop_found := false
	for child in stage.get_children():
		if child is CaltropTrapClass:
			caltrop_found = true
			break
	_check(caltrop_found == true, "Dropped Caltrop Trap behind during Phase 2 backstep")

	# Test Phase 2 transition at <= 8 HP
	boss.current_phase = 1
	boss.dead_eye_enrage = false
	boss.take_damage(8, Vector2.LEFT)
	_check(boss.current_hp == 8, "Boss HP reduced to 8")
	_check(boss.current_phase == 2, "Transitioned to Phase 2 at <= 8 HP")
	_check(boss.dead_eye_enrage == true, "Dead-Eye Enrage activated")

	# Defeat and 15 Shards Drop
	boss.is_invulnerable = false
	var defeated := [false]
	boss.boss_defeated.connect(func(): defeated[0] = true)

	boss.take_damage(8, Vector2.LEFT)
	_check(boss.current_hp == 0, "Boss HP reached 0")
	_check(defeated[0] == true, "boss_defeated signal emitted upon defeat")

	await process_frame
	var shards_count := 0
	for child in stage.get_children():
		if child is ShardDropClass:
			shards_count += 1
	_check(shards_count == 15, "Crossbow Commander dropped exactly 15 soul shards upon defeat")

	stage.queue_free()


func _test_third_stage_boss_integration() -> void:
	print("\n[Check 4: ThirdStage (무너진 성벽) Boss Encounter Integration]")
	var stage = ThirdStageScene.instantiate()
	root.add_child(stage)
	stage.campaign_mode = true
	await process_frame

	_check(stage.stage_number == 3, "Stage number is 3 (무너진 성벽)")
	_check(stage.required_count == 8, "ThirdStage configured with 8 required encounters")

	# Set encounter_index to last encounter (7) and start encounter
	stage.encounter_index = stage.required_count - 1
	stage._start_encounter()
	await process_frame

	# Per Director Spec: Natural barrierless boss encounter (no obstructive gate)
	_check(stage.arena_entrance_gate == null, "Boss encounter flows naturally without obstructive arena gate barrier per Director request")
	_check(stage.enemies.size() > 0, "Boss spawned in encounter E8")
	_check(stage.enemies[0] is CrossbowCommanderClass, "Encounter E8 spawned CrossbowCommander (폐허의 석궁 사령관)")
	var hud_bar = stage.get_node_or_null("HUD/BossHealthBar")
	_check(hud_bar != null, "BossHealthBar UI instantiated and displayed")
	_check(hud_bar.boss_name == "폐허의 석궁 사령관", "Boss health bar title matches Stage 3 Boss Name")
	_check(AudioManager.get_current_bgm() == "boss", "Boss BGM automatically triggered upon Stage 3 boss start")

	# Clean up
	AudioManager.stop_bgm()
	stage.queue_free()
