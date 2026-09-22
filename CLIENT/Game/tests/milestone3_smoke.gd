extends SceneTree
## Milestone 3 Comprehensive Autonomous Verification Suite
## Verifies:
## 1. Meta-upgrade economy & persistence (SaveManager stats.upgrades)
## 2. Campfire Shop UI (modal, purchase flow, wallet sync, heal & stat boost)
## 3. Stage 2 Gateway Boss: Beast Chieftain (14 HP, Phase 1/2, shockwaves, shard explosion)
## 4. Dynamic BGM Audio System (AudioManager exploration & boss BGM state machine)
## 5. SecondStage (야수숲) Stage 2 Boss Encounter integration

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const CampfireShopClass = preload("res://scripts/ui/campfire_shop.gd")
const BeastChieftainClass = preload("res://scripts/enemy/beast_chieftain.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const SecondStageScene = preload("res://scenes/stage/SecondStage.tscn")
const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")
const ShardDropClass = preload("res://scripts/system/shard_drop.gd")

var checks_passed: int = 0
var checks_failed: int = 0


func _init() -> void:
	print("\n--- START MILESTONE 3 AUTONOMOUS VERIFICATION SUITE ---")
	call_deferred("_run_suite")


func _check(condition: bool, msg: String) -> void:
	if condition:
		checks_passed += 1
		print("PASS: %s" % msg)
	else:
		checks_failed += 1
		printerr("FAIL: %s" % msg)


func _run_suite() -> void:
	await _test_save_manager_upgrades()
	await _test_campfire_shop_ui()
	await _test_beast_chieftain_boss()
	await _test_audio_manager_bgm()
	await _test_second_stage_integration()

	print("\n--- MILESTONE 3 SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks_passed, checks_failed])
	if checks_failed == 0:
		print("TEST RESULT: ALL MILESTONE 3 CHECKS PASSED (100%)")
		quit(0)
	else:
		printerr("TEST RESULT: MILESTONE 3 FAILED WITH %d ERRORS" % checks_failed)
		quit(1)


func _test_save_manager_upgrades() -> void:
	print("\n[Check 1: SaveManager Meta Upgrades & Wallet]")
	SaveManagerClass.clear_save()
	_check(SaveManagerClass.get_shards() == 0, "Initial shards are 0 after clear_save")
	_check(SaveManagerClass.get_upgrade_level("hp_boost") == 0, "Initial hp_boost level is 0")
	_check(SaveManagerClass.get_upgrade_level("dmg_boost") == 0, "Initial dmg_boost level is 0")

	# Attempt purchase without enough shards
	var bought_fail := SaveManagerClass.purchase_upgrade("hp_boost", 25)
	_check(bought_fail == false, "Cannot purchase upgrade without sufficient shards")
	_check(SaveManagerClass.get_upgrade_level("hp_boost") == 0, "hp_boost level remains 0")

	# Add shards and purchase hp_boost
	SaveManagerClass.add_shards(60)
	_check(SaveManagerClass.get_shards() == 60, "Shards successfully added to 60")
	var bought_hp := SaveManagerClass.purchase_upgrade("hp_boost", 25)
	_check(bought_hp == true, "Successfully purchased hp_boost level 1 for 25 shards")
	_check(SaveManagerClass.get_shards() == 35, "Remaining shards updated to 35")
	_check(SaveManagerClass.get_upgrade_level("hp_boost") == 1, "hp_boost level increased to 1")

	# Purchase dmg_boost
	var bought_dmg := SaveManagerClass.purchase_upgrade("dmg_boost", 35)
	_check(bought_dmg == true, "Successfully purchased dmg_boost level 1 for 35 shards")
	_check(SaveManagerClass.get_shards() == 0, "Remaining shards updated to 0")
	_check(SaveManagerClass.get_upgrade_level("dmg_boost") == 1, "dmg_boost level increased to 1")

	# Attempt to exceed max level for dmg_boost (max is 1)
	SaveManagerClass.add_shards(50)
	var bought_exceed := SaveManagerClass.purchase_upgrade("dmg_boost", 0)
	_check(bought_exceed == false, "Cannot exceed max level (1) for dmg_boost")

	# Verify applying upgrades to player
	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	root.add_child(player)
	SaveManagerClass.apply_upgrades_to_player(player)
	_check(player.max_hp == 4, "Player max_hp upgraded from 3 to 4")
	_check(player.current_hp == 4, "Player current_hp updated to 4")
	_check(player.current_attack_damage == 2, "Player attack damage upgraded from 1 to 2")
	player.queue_free()


func _test_campfire_shop_ui() -> void:
	print("\n[Check 2: Campfire Shop UI & Purchase Interactions]")
	SaveManagerClass.clear_save()
	SaveManagerClass.add_shards(35)

	var stage_dummy := Node2D.new()
	root.add_child(stage_dummy)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.current_hp = 1
	stage_dummy.add_child(player)

	var shop := CampfireShopClass.new()
	shop.target_player = player
	root.add_child(shop)
	await process_frame

	_check(shop._shard_label != null, "CampfireShop UI built successfully with shard label")
	_check(shop._shard_label.text.contains("35"), "Shop displays initial shard count 35")

	# Buy HP upgrade
	var upgrade_received := [""]
	shop.upgrade_purchased.connect(func(id: String): upgrade_received[0] = id)
	shop._on_buy_hp()

	_check(upgrade_received[0] == "hp_boost", "Emitted upgrade_purchased signal for hp_boost")
	_check(SaveManagerClass.get_shards() == 10, "Remaining shards reduced to 10")
	_check(player.max_hp == 4, "Player max_hp increased to 4 via shop purchase")

	# Buy Heal with remaining 10 shards
	shop._on_buy_heal()
	_check(SaveManagerClass.get_shards() == 0, "Remaining shards reduced to 0 after heal")
	_check(player.current_hp == player.max_hp, "Player HP completely restored to max_hp")

	# Test close button signal
	var closed := [false]
	shop.shop_closed.connect(func(): closed[0] = true)
	shop._on_close_pressed()
	_check(closed[0] == true, "Emitted shop_closed signal upon close button press")

	shop.queue_free()
	stage_dummy.queue_free()


func _test_beast_chieftain_boss() -> void:
	print("\n[Check 3: Beast Chieftain Gateway Boss AI & Phases]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(300, 580)
	stage.add_child(player)

	var boss := BeastChieftainClass.new()
	boss.position = Vector2(500, 580)
	stage.add_child(boss)
	await process_frame

	_check(boss.max_hp == 14, "Beast Chieftain max_hp is 14")
	_check(boss.current_hp == 14, "Beast Chieftain spawns with full 14 HP")
	_check(boss.current_phase == 1, "Beast Chieftain starts in Phase 1")
	_check(boss.blood_frenzy == false, "Blood Frenzy inactive in Phase 1")

	# Track shockwave emissions
	var shockwave_count := [0]
	boss.emit_shockwave.connect(func(_pos: Vector2, _dir: float): shockwave_count[0] += 1)

	# Deal 7 damage to trigger Phase 2
	boss.take_damage(7, Vector2.LEFT)
	_check(boss.current_hp == 7, "Beast Chieftain HP reduced to 7")
	_check(boss.current_phase == 2, "Transitioned to Phase 2 at <= 7 HP")
	_check(boss.blood_frenzy == true, "Blood Frenzy activated in Phase 2")
	_check(boss.move_speed > 140.0, "Boss movement speed enraged in Phase 2")

	# Trigger Blood Slam to verify shockwave emission
	boss.is_invulnerable = false
	boss._trigger_blood_slam()
	_check(shockwave_count[0] == 2, "Blood Slam emits 2 shockwaves (left and right)")

	# Track defeat and shard drops
	var defeated := [false]
	boss.boss_defeated.connect(func(): defeated[0] = true)

	# Deal lethal 7 damage
	boss.take_damage(7, Vector2.LEFT)
	_check(boss.current_hp == 0, "Beast Chieftain HP reached 0")
	_check(defeated[0] == true, "boss_defeated signal emitted upon death")

	# Verify 12 shards spawned
	await process_frame
	var shards_found := 0
	for child in stage.get_children():
		if child is ShardDropClass:
			shards_found += 1
	_check(shards_found == 12, "Beast Chieftain dropped exactly 12 soul shards upon defeat")

	stage.queue_free()


func _test_audio_manager_bgm() -> void:
	print("\n[Check 4: Dynamic BGM Audio System]")
	var audio_mgr := AudioManager.ensure_manager(self)
	_check(audio_mgr != null, "AudioManager ensured and instantiated successfully")

	AudioManager.bgm("exploration")
	_check(AudioManager.get_current_bgm() == "exploration", "AudioManager switched to exploration BGM")
	_check(AudioManager.is_bgm_playing() == true, "Exploration music stream is active")

	AudioManager.bgm("boss")
	_check(AudioManager.get_current_bgm() == "boss", "AudioManager switched to boss BGM")
	_check(AudioManager.is_bgm_playing() == true, "Boss music stream is active")

	AudioManager.stop_bgm()
	_check(AudioManager.get_current_bgm() == "", "AudioManager track cleared after stop_bgm")
	_check(AudioManager.is_bgm_playing() == false, "Music player stopped")


func _test_second_stage_integration() -> void:
	print("\n[Check 5: SecondStage (야수숲) Boss Encounter Integration]")
	var stage = SecondStageScene.instantiate()
	root.add_child(stage)
	stage.campaign_mode = true
	await process_frame

	_check(stage.stage_number == 2, "Stage number is 2 (야수숲)")
	_check(stage.required_count == 6, "SecondStage configured with 6 required encounters")

	# Set encounter_index to last encounter (5) and start encounter
	stage.encounter_index = stage.required_count - 1
	stage._start_encounter()
	await process_frame

	# Per Director Spec: Natural barrierless boss encounter (no obstructive gate)
	_check(stage.arena_entrance_gate == null, "Boss encounter flows naturally without obstructive arena gate barrier per Director request")
	_check(stage.enemies.size() > 0, "Boss spawned in encounter E6")
	_check(stage.enemies[0] is BeastChieftainClass, "Encounter E6 spawned BeastChieftain (심연의 맹수 우두머리)")
	var hud_bar = stage.get_node_or_null("HUD/BossHealthBar")
	_check(hud_bar != null, "BossHealthBar UI instantiated and displayed")
	_check(hud_bar.boss_name == "심연의 맹수 우두머리", "Boss health bar title matches Stage 2 Boss Name")
	_check(AudioManager.get_current_bgm() == "boss", "Boss BGM automatically triggered upon boss encounter start")

	# Clean up
	AudioManager.stop_bgm()
	stage.queue_free()
