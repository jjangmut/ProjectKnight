extends SceneTree
## Milestone 5 Comprehensive Autonomous Verification Suite
## Verifies:
## 1. Stage 4 Gate Boss: Ancient Golem Guardian (18 HP, Quake Slam, Falling Boulders, Phase 2 Core Overload Rolling Charge, 18-shard burst)
## 2. Stage 5 Climax Final Boss: Abyssal Arbiter (24 HP, 3-Phase Climax, Shadow Blink Teleport, Void Blade Ring, Phase 3 Final Judgment Wings, 25-shard burst)
## 3. FourthStage (돌의 성소) E8 Ancient Golem Guardian boss encounter & arena lock
## 4. FifthStage (침묵의 성채) E8 Abyssal Arbiter climax boss encounter & campaign completion

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const AncientGolemGuardianClass = preload("res://scripts/enemy/ancient_golem_guardian.gd")
const FallingBoulderClass = preload("res://scripts/enemy/falling_boulder.gd")
const AbyssalArbiterClass = preload("res://scripts/enemy/abyssal_arbiter.gd")
const AbyssalBladeClass = preload("res://scripts/enemy/abyssal_blade.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const FourthStageScene = preload("res://scenes/stage/FourthStage.tscn")
const FifthStageScene = preload("res://scenes/stage/FifthStage.tscn")
const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")
const ShardDropClass = preload("res://scripts/system/shard_drop.gd")

var checks_passed: int = 0
var checks_failed: int = 0


func _init() -> void:
	print("\n--- START MILESTONE 5 AUTONOMOUS VERIFICATION SUITE ---")
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
	await _test_ancient_golem_guardian()
	await _test_abyssal_arbiter_final_boss()
	await _test_stage4_and_stage5_integration()

	print("\n--- MILESTONE 5 SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks_passed, checks_failed])
	if checks_failed == 0:
		print("TEST RESULT: ALL MILESTONE 5 CHECKS PASSED (100%)")
		quit(0)
	else:
		printerr("TEST RESULT: MILESTONE 5 FAILED WITH %d ERRORS" % checks_failed)
		quit(1)


func _test_ancient_golem_guardian() -> void:
	print("\n[Check 1: Stage 4 Ancient Golem Guardian AI & Phases]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(250, 580)
	stage.add_child(player)

	var boss := AncientGolemGuardianClass.new()
	boss.position = Vector2(550, 580)
	stage.add_child(boss)
	await process_frame

	_check(boss.max_hp == 18, "Ancient Golem Guardian max_hp is 18")
	_check(boss.current_hp == 18, "Golem spawns with full 18 HP")
	_check(boss.current_phase == 1, "Golem starts in Phase 1")
	_check(boss.core_overload == false, "Core Overload inactive in Phase 1")

	# Track Quake Slam shockwaves
	var shockwaves := [0]
	boss.emit_shockwave.connect(func(_pos: Vector2, _dir: float): shockwaves[0] += 1)
	boss._emit_shockwaves()
	_check(shockwaves[0] == 2, "Quake Slam emits 2 ground shockwaves (left & right)")

	# Track Falling Boulders summon
	var boulders := [0]
	boss.boulder_summoned.connect(func(_pos: Vector2): boulders[0] += 1)
	boss._spawn_boulders()
	_check(boulders[0] == 3, "Summoned 3 falling boulders targeting player area")

	# Test Phase 2 transition at <= 9 HP
	boss.take_damage(9, Vector2.LEFT)
	_check(boss.current_hp == 9, "Golem HP reduced to 9")
	_check(boss.current_phase == 2, "Transitioned to Phase 2 at <= 9 HP")
	_check(boss.core_overload == true, "Core Overload activated in Phase 2")

	# Test Rolling Charge State
	boss._start_rolling_charge()
	_check(boss.state == AncientGolemGuardianClass.State.ROLLING_CHARGE, "Entered Rolling Charge attack state")

	# Defeat and 18 Shards Drop
	boss.is_invulnerable = false
	var defeated := [false]
	boss.boss_defeated.connect(func(): defeated[0] = true)

	boss.take_damage(9, Vector2.LEFT)
	_check(boss.current_hp == 0, "Golem HP reached 0")
	_check(defeated[0] == true, "boss_defeated signal emitted upon death")

	await process_frame
	var shards := 0
	for child in stage.get_children():
		if child is ShardDropClass:
			shards += 1
	_check(shards == 18, "Ancient Golem Guardian dropped exactly 18 soul shards upon defeat")

	stage.queue_free()


func _test_abyssal_arbiter_final_boss() -> void:
	print("\n[Check 2: Stage 5 Climax Final Boss Abyssal Arbiter 3-Phase AI]")
	var stage := Node2D.new()
	root.add_child(stage)

	var player_scene := preload("res://scenes/player/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(300, 580)
	stage.add_child(player)

	var boss := AbyssalArbiterClass.new()
	boss.position = Vector2(600, 580)
	stage.add_child(boss)
	boss._player = player
	await process_frame

	_check(boss.max_hp == 24, "Abyssal Arbiter max_hp is 24")
	_check(boss.current_hp == 24, "Spawns with full 24 HP")
	_check(boss.current_phase == 1, "Starts in Phase 1 (Void Executioner)")
	_check(boss.final_judgment == false, "Final Judgment wings inactive in Phase 1")

	# 1. Test Shadow Blink Teleportation
	var teleported_signal := [false]
	boss.teleported.connect(func(_pos: Vector2): teleported_signal[0] = true)
	boss._start_shadow_blink()
	boss._process_shadow_blink(0.35)
	_check(teleported_signal[0] == true, "Arbiter executed shadow blink teleport behind player")

	# 2. Test Phase 2 transition at <= 16 HP
	boss.take_damage(8, Vector2.LEFT)
	_check(boss.current_hp == 16, "Arbiter HP reduced to 16")
	_check(boss.current_phase == 2, "Transitioned to Phase 2 (Void Rift Opened)")

	# Test Blade Ring Cast
	var blades_cast := [false]
	boss.blade_ring_cast.connect(func(_pos: Vector2): blades_cast[0] = true)
	boss._cast_blade_ring()
	_check(blades_cast[0] == true, "Arbiter cast 4-directional spinning void blade ring")

	# 3. Test Phase 3 transition at <= 8 HP (Final Judgment)
	boss.is_invulnerable = false
	boss.take_damage(8, Vector2.LEFT)
	_check(boss.current_hp == 8, "Arbiter HP reduced to 8")
	_check(boss.current_phase == 3, "Transitioned to Phase 3 (Final Judgment)")
	_check(boss.final_judgment == true, "Final Judgment black wings fully opened")
	_check(boss.wing_left.visible == true and boss.wing_right.visible == true, "Black wings visually displayed")

	# 4. Final Defeat & 25 Shards Burst
	boss.is_invulnerable = false
	var defeated := [false]
	boss.boss_defeated.connect(func(): defeated[0] = true)

	boss.take_damage(8, Vector2.LEFT)
	_check(boss.current_hp == 0, "Arbiter HP reached 0")
	_check(defeated[0] == true, "boss_defeated signal emitted upon ultimate defeat")

	await process_frame
	var shards := 0
	for child in stage.get_children():
		if child is ShardDropClass:
			shards += 1
	_check(shards == 25, "Abyssal Arbiter dropped exactly 25 soul shards upon campaign completion")

	stage.queue_free()


func _test_stage4_and_stage5_integration() -> void:
	print("\n[Check 3: FourthStage & FifthStage Boss Encounter Integration]")

	# 1. FourthStage (돌의 성소)
	var stage4 = FourthStageScene.instantiate()
	root.add_child(stage4)
	stage4.campaign_mode = true
	await process_frame

	_check(stage4.stage_number == 4, "Stage 4 number verified (돌의 성소)")
	_check(stage4.required_count == 8, "FourthStage configured with 8 required encounters")

	# Start final boss encounter E8
	stage4.encounter_index = stage4.required_count - 1
	stage4._start_encounter()
	await process_frame

	# Per Director Spec: Natural barrierless boss encounter (no obstructive gate)
	_check(stage4.arena_entrance_gate == null, "Stage 4 boss encounter flows naturally without gate barrier per Director request")
	_check(stage4.enemies.size() > 0, "Stage 4 boss spawned in encounter E8")
	_check(stage4.enemies[0] is AncientGolemGuardianClass, "Encounter E8 spawned AncientGolemGuardian (고대 골렘 수호자)")
	var bar4 = stage4.get_node_or_null("HUD/BossHealthBar")
	_check(bar4 != null, "BossHealthBar UI instantiated for Stage 4")
	_check(bar4.boss_name == "고대 골렘 수호자", "Boss bar title matches '고대 골렘 수호자'")
	stage4.queue_free()

	# 2. FifthStage (침묵의 성채)
	var stage5 = FifthStageScene.instantiate()
	root.add_child(stage5)
	stage5.campaign_mode = true
	await process_frame

	_check(stage5.stage_number == 5, "Stage 5 number verified (침묵의 성채)")
	_check(stage5.required_count == 8, "FifthStage configured with 8 required encounters")

	# Start final climax boss encounter E8
	stage5.encounter_index = stage5.required_count - 1
	stage5._start_encounter()
	await process_frame

	# Per Director Spec: Natural barrierless boss encounter (no obstructive gate)
	_check(stage5.arena_entrance_gate == null, "Stage 5 boss encounter flows naturally without gate barrier per Director request")
	_check(stage5.enemies.size() > 0, "Stage 5 final boss spawned in encounter E8")
	_check(stage5.enemies[0] is AbyssalArbiterClass, "Encounter E8 spawned AbyssalArbiter (심연의 심판관)")
	var bar5 = stage5.get_node_or_null("HUD/BossHealthBar")
	_check(bar5 != null, "BossHealthBar UI instantiated for Climax Boss")
	_check(bar5.boss_name == "심연의 심판관", "Boss bar title matches '심연의 심판관'")
	stage5.queue_free()
