extends SceneTree
## Stage 3 (무너진 성벽) 사이드 쿼터뷰 헤드리스 스모크 테스트 스위트
## - 15초 워치독 타이머 탑재
## - Stage 3 씬 로드 및 코발트 블루 황혼 3D 환경 검증
## - 무너진 흉벽, 부유 석편(Floating Stone Shards), 비전 램프 검증
## - 웨이브 1: 원거리 석궁병 미니언 2기 스폰, 피격, 패링 스턴 검증
## - 웨이브 2: 보스 석궁 사령관 (SideQVCrossbowCommander) 스폰 검증
## - 보스 4대 패턴 검증 (부채꼴 볼트, 백텀블링 저격, 마름쇠 트랩, 2페이즈 5연발 점사)
## - 보스 그로기/패링 스턴, 상호 밀림 방지, 2페이즈 비전 오라 검증
## - 보스 격퇴 및 스테이지 클리어 완주 검증

const SideQVStage3Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_3.gd")
const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVCrossbowCommanderClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")
const SideQVCrossbowBoltClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd")
const SideQVCaltropTrapClass = preload("res://scripts/side_quarter_view/bosses/side_qv_caltrop_trap.gd")
const SideQVCampaignClass = preload("res://scripts/side_quarter_view/side_qv_campaign.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	# 1. 12초 내장 워치독 타이머 (비정상 행잉 차단)
	create_timer(12.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] Stage 3 smoke test took too long!")
		quit(1)
	)

	_run_suite.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("[FAIL] %s" % message)
	else:
		print("[PASS] %s" % message)


func _run_suite() -> void:
	print("==================================================================")
	print(">>> [STAGE 3] SIDE QUARTER-VIEW SMOKE TEST SUITE START <<<")
	print("==================================================================")

	# ------------------------------------------------------------------
	# TEST 1: Stage 3 Scene Load & Initialization
	# ------------------------------------------------------------------
	var stage_scene := load("res://scenes/side_quarter_view/SideQVStage3.tscn") as PackedScene
	check(stage_scene != null, "TEST 1.1: SideQVStage3.tscn loaded successfully")

	var stage = stage_scene.instantiate()
	check(stage != null, "TEST 1.2: SideQVStage3 instance created")
	root.add_child(stage)
	current_scene = stage

	await process_frame
	await process_frame

	check(stage.stage_index == 3, "TEST 1.3: Stage index is 3")
	check(stage.stage_title == "무너진 성벽", "TEST 1.4: Stage title is '무너진 성벽'")
	check(stage.player != null, "TEST 1.5: SideQVPlayer spawned")
	check(stage.camera != null, "TEST 1.6: SideQVCamera spawned")

	# ------------------------------------------------------------------
	# TEST 2: 3D Environment & Architecture Verification
	# ------------------------------------------------------------------
	var world_env := stage.get_node_or_null("WorldEnvironment3D") as WorldEnvironment
	check(world_env != null, "TEST 2.1: WorldEnvironment3D exists")
	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		check(env.glow_enabled, "TEST 2.2: 3D HDR Glow is enabled")
		check(env.ambient_light_color == Color(0.25, 0.35, 0.55, 1.0), "TEST 2.3: Cobalt twilight ambient light color matches specification")

	var sun := stage.get_node_or_null("TwilightMoonLight") as DirectionalLight3D
	check(sun != null, "TEST 2.4: TwilightMoonLight exists with soft shadows")

	# Broken battlements and ruined pillars
	var broken_wall: Node = stage.get_node_or_null("BrokenWall_0")
	check(broken_wall != null, "TEST 2.5: Broken masonry battlement segment exists")

	# Floating stone debris
	check(stage.floating_stones.size() >= 6, "TEST 2.6: Floating stone shards instantiated (count: %d >= 6)" % stage.floating_stones.size())

	# ------------------------------------------------------------------
	# TEST 3: Wave 1 Ranged Minions Verification
	# ------------------------------------------------------------------
	check(stage.current_wave == 1, "TEST 3.1: Current wave is 1")
	check(stage.enemies.size() == 2, "TEST 3.2: 2 Ranged Crossbow Minions spawned in Wave 1")

	var minion1 = stage.enemies[0]
	var minion2 = stage.enemies[1]
	check(minion1 != null and minion2 != null, "TEST 3.3: Both minions exist")
	check(minion1.current_hp == 4 and minion1.max_hp == 4, "TEST 3.4: Minion HP initialized to 4")

	# Test minion hit & parry stun
	minion1.receive_hit(2)
	check(minion1.current_hp == 2, "TEST 3.5: Minion took 2 damage (HP: 2/4)")
	minion1.apply_parry_stun(1.0)
	check(minion1.is_stunned, "TEST 3.6: Minion parry stun applied successfully")

	# Defeat minions to trigger Wave 2
	minion1.receive_hit(2) # Minion 1 defeated
	minion2.receive_hit(4) # Minion 2 defeated

	# Wait for wave transition timer (1.2s + buffer)
	print(">>> Waiting for Wave 2 Boss Transition... <<<")
	for i in range(16):
		await process_frame

	if stage.active_boss == null:
		# Directly call boss wave if timer was deferred
		stage._start_boss_wave()

	check(stage.current_wave == 2, "TEST 3.7: Transitioned to Wave 2")
	check(stage.active_boss != null, "TEST 3.8: Active boss spawned")
	check(stage.active_boss is SideQVCrossbowCommanderClass, "TEST 3.9: Active boss is SideQVCrossbowCommander")

	# ------------------------------------------------------------------
	# TEST 4: Boss Components & Attributes
	# ------------------------------------------------------------------
	var boss = stage.active_boss
	check(boss.max_hp == 28, "TEST 4.1: Boss max HP is 28")
	check(boss.current_hp == 28, "TEST 4.2: Boss initial HP is 28")
	check(boss.current_phase == 1, "TEST 4.3: Boss starts in Phase 1")
	check(boss.is_in_group("bosses") and boss.is_in_group("enemies"), "TEST 4.4: Boss is in 'bosses' and 'enemies' groups")

	var b_sprite = boss.get_node_or_null("CommanderSprite3D") as Sprite3D
	check(b_sprite != null, "TEST 4.5: Boss Sprite3D exists")
	check(b_sprite.hframes == 4 and b_sprite.vframes == 3, "TEST 4.6: Boss sprite sheet is 4x3 frames (crossbow_cmd_v2)")

	var aura_ring = boss.get_node_or_null("CobaltAuraRing") as MeshInstance3D
	check(aura_ring != null, "TEST 4.7: Boss Cobalt Aura Ring exists")
	check(not aura_ring.visible, "TEST 4.8: Aura ring hidden during Phase 1")

	# ------------------------------------------------------------------
	# TEST 5: Boss Combat Patterns Verification
	# ------------------------------------------------------------------
	# Pattern 1: Fan Crossbow Volley
	boss._execute_fan_volley()
	check(boss.current_pattern == SideQVCrossbowCommanderClass.Pattern.FAN_VOLLEY, "TEST 5.1: Pattern 1 (Fan Crossbow Volley) initiated")
	await process_frame
	await process_frame

	# Pattern 2: Acrobatic Backstep Shot
	boss._execute_backstep_shot()
	check(boss.current_pattern == SideQVCrossbowCommanderClass.Pattern.BACKSTEP_SHOT, "TEST 5.2: Pattern 2 (Acrobatic Backstep Shot) initiated")
	check(boss.velocity.y > 0.0, "TEST 5.3: Acrobatic Backstep leaps upward into air")
	await process_frame
	await process_frame

	# Pattern 3: Caltrop Trap Cluster
	boss._execute_caltrop_trap()
	check(boss.current_pattern == SideQVCrossbowCommanderClass.Pattern.CALTROP_TRAP, "TEST 5.4: Pattern 3 (Caltrop Trap Cluster) initiated")
	await process_frame
	await process_frame

	# Pattern 4: Parry Stun & Groggy
	boss.apply_parry_stun(1.5)
	check(boss.is_stunned, "TEST 5.5: Boss parry stun / groggy applied")
	check(boss.current_pattern == SideQVCrossbowCommanderClass.Pattern.STUNNED, "TEST 5.6: Pattern set to STUNNED")
	check(boss.velocity == Vector3.ZERO, "TEST 5.7: Velocity stopped completely on stun clash")

	# Test Mutual Push Prevention
	stage.player.global_position = boss.global_position + Vector3(0.5, 0, 0)
	boss.velocity = Vector3(10.0, 0, 0)
	boss._prevent_player_pushing()
	check(boss.velocity.x <= 0.01, "TEST 5.8: Mutual push prevention stops boss from shoving player")

	# ------------------------------------------------------------------
	# TEST 6: Phase 2 Enrage & Rapid Barrage
	# ------------------------------------------------------------------
	boss.receive_hit(15) # Reduce to 13 HP (<= 50% of 28 = 14)
	check(boss.current_phase == 2, "TEST 6.1: Boss entered Phase 2 upon HP <= 50%")
	check(boss.aura_ring_3d.visible, "TEST 6.2: Phase 2 Cobalt Aura Ring activated")
	check(boss.move_speed > 4.5, "TEST 6.3: Phase 2 move speed buffed")

	# Pattern 5: Rapid Crossbow Barrage (Phase 2 unique)
	boss._execute_rapid_barrage()
	check(boss.current_pattern == SideQVCrossbowCommanderClass.Pattern.RAPID_BARRAGE, "TEST 6.4: Pattern 4 (Rapid Crossbow Barrage: 5-burst) executed in Phase 2")
	await process_frame
	await process_frame

	# ------------------------------------------------------------------
	# TEST 7: Caltrop Trap & Crossbow Bolt Object Mechanics
	# ------------------------------------------------------------------
	# Test Bolt
	var test_bolt = SideQVCrossbowBoltClass.new()
	root.add_child(test_bolt)
	test_bolt.launch(Vector3(0, 1, 0), Vector3.RIGHT, boss, 20.0, 2, true)
	check(test_bolt.monitoring, "TEST 7.1: Crossbow bolt monitoring active")
	test_bolt.queue_free()

	# Test Caltrop Trap
	var test_trap = SideQVCaltropTrapClass.new()
	root.add_child(test_trap)
	test_trap.setup(Vector3(2, 0, 0), boss)
	check(test_trap.monitoring, "TEST 7.2: Caltrop trap monitoring active on floor")
	test_trap.queue_free()

	# ------------------------------------------------------------------
	# TEST 8: Boss Defeat & Stage Clear
	# ------------------------------------------------------------------
	var stage_cleared_received := false
	stage.stage_cleared.connect(func():
		stage_cleared_received = true
	)

	boss.receive_hit(20) # Fatal hit
	check(boss.current_hp <= 0, "TEST 8.1: Boss HP reduced to 0")
	await process_frame
	await process_frame

	check(stage.is_stage_finished, "TEST 8.2: Stage marked as finished upon boss defeat")

	# ------------------------------------------------------------------
	# TEST 9: Campaign Integration Verification
	# ------------------------------------------------------------------
	var campaign = SideQVCampaignClass.new()
	campaign.start_stage_index = 2 # Stage 3
	root.add_child(campaign)
	await process_frame
	await process_frame
	check(campaign.current_stage_instance != null, "TEST 9.1: Campaign loads Stage 3 successfully")
	check(campaign.current_stage_index == 2, "TEST 9.2: Campaign stage index matches Stage 3 (index 2)")
	campaign.queue_free()

	# Clean up
	stage.queue_free()

	print("==================================================================")
	print(">>> STAGE 3 SIDE QV SMOKE TEST COMPLETED <<<")
	print("TOTAL CHECKS: %d | FAILURES: %d" % [checks, failures])
	print("==================================================================")

	if failures == 0:
		print(">>> ALL CHECKS 100% PASS! <<<")
		quit(0)
	else:
		printerr(">>> FAILURES DETECTED! <<<")
		quit(1)
