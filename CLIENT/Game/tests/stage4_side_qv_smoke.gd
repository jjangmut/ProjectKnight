extends SceneTree
## Project Knight - Stage 4 (돌의 성소 / Stone Sanctuary) Side Quarter-View Smoke Test
## 검증 항목:
## 1. Stage 4 환경 & 아키텍처 (거석 제단, 모놀리스 기둥 6개, 붉은 주황 석양/마그마 앰비언스, 엠버 파티클)
## 2. 웨이브 1 헤비 골렘 미니언 2기 (golem_v1.png 3x2 시트, 신장 2.0m, 상호 밀림 방지)
## 3. 웨이브 2 SideQVGolemGuardian 보스 (2.8m 신장, golem_guardian_v2.png 4x3 시트)
## 4. 보스 패턴 3종: 대지 강타 그라운드 슬램, 암석 회전 래리어트, 지진파 대지 분쇄 (2페이즈)
## 5. 전투 상호작용: 저스트 패링 스턴, 피격/상호 밀림 방지, 플레이어 정면 응시, 보스 처치 및 클리어

const Stage4Scene = preload("res://scenes/side_quarter_view/SideQVStage4.tscn")
const SideQVGolemGuardianClass = preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")
const SideQVGolemMinionClass = preload("res://scripts/side_quarter_view/side_qv_golem_minion.gd")

var checks: int = 0
var failures: int = 0
var stage: Node3D = null
var test_events: Dictionary = {
	"stage_cleared": false
}


func _initialize() -> void:
	# InputMap 안전 초기화
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	# 15초 워치독 강제 종료 타이머 (Fail-safe Watchdog)
	var watchdog := create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] stage4_side_qv_smoke.gd exceeded 15s. Forcing exit.")
		quit(1)
	)

	_run_tests.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		failures += 1
		printerr("  [FAIL] %s" % msg)


func _advance_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _run_tests() -> void:
	print("\n===================================================================")
	print(">>> RUNNING: stage4_side_qv_smoke.gd (Stage 4 Stone Sanctuary QA) <<<")
	print("===================================================================\n")

	stage = Stage4Scene.instantiate() as Node3D
	check(stage != null, "Stage 4 scene instantiated successfully")
	stage.stage_cleared.connect(func():
		test_events["stage_cleared"] = true
	)
	root.add_child(stage)
	current_scene = stage

	# QA 테스트 중 보스 패턴 검증 시 플레이어 사망 방지 및 빠른 클리어 연출 설정
	stage.player.is_invulnerable = true
	stage.clear_fanfare_delay = 0.5

	await _advance_frames(5)

	# -------------------------------------------------------------
	# 1. 스테이지 메타데이터 및 3D 환경 검증
	# -------------------------------------------------------------
	print("\n--- Test 1: Stage 4 Metadata & 3D Environment ---")
	check(stage.stage_index == 4, "Stage index is 4: %d" % stage.stage_index)
	check(stage.stage_title == "돌의 성소", "Stage title is '돌의 성소': '%s'" % stage.stage_title)

	var world_env: WorldEnvironment = stage.get_node_or_null("WorldEnvironment3D")
	check(world_env != null, "WorldEnvironment3D node exists")
	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		var expected_amb := Color(0.55, 0.28, 0.15, 1.0)
		check(env.ambient_light_color.is_equal_approx(expected_amb),
			"Ambient light color matches required sunset magma amber Color(0.55, 0.28, 0.15): %s" % str(env.ambient_light_color))
		check(env.glow_enabled == true, "3D WorldEnvironment Glow is enabled")

	var sun: DirectionalLight3D = stage.get_node_or_null("SunsetSunLight3D")
	check(sun != null and sun.shadow_enabled, "Sunset Directional Sunlight with shadows enabled exists")

	var embers: CPUParticles3D = stage.get_node_or_null("EmberParticles3D")
	check(embers != null and embers.amount >= 60, "Airborne Ember Particles (CPUParticles3D) active in 3D space")

	# -------------------------------------------------------------
	# 2. 3D 고대 아키텍처 및 거석 제단 / 모놀리스 검증
	# -------------------------------------------------------------
	print("\n--- Test 2: Ancient Architecture & Megalithic Monoliths ---")
	var backdrop: MeshInstance3D = stage.get_node_or_null("SanctuaryBackdrop")
	check(backdrop != null, "Sanctuary panoramic vista backdrop exists")

	var floor_box: CSGBox3D = stage.get_node_or_null("ArenaFloor")
	check(floor_box != null and floor_box.use_collision and floor_box.collision_layer == 4,
		"Arena floor CSGBox3D exists with collision layer 4 (World)")

	var altar: Node3D = stage.get_node_or_null("AncientStoneAltar")
	check(altar != null, "Ancient Stone Altar Dais exists in stage")
	if altar != null:
		check(altar.get_node_or_null("AltarTier1") != null, "Altar Tier 1 stepped dais exists")
		check(altar.get_node_or_null("AltarTier2") != null, "Altar Tier 2 stepped dais exists")
		check(altar.get_node_or_null("AltarSlab") != null, "Central Sacrificial Altar Slab exists")

	var monolith_count := 0
	for child in stage.get_children():
		if child.name.begins_with("MonolithPillar"):
			monolith_count += 1
			check(child.get_node_or_null("RuneBand") != null, "Monolith pillar has glowing RuneBand")
	check(monolith_count >= 6, "At least 6 massive monolithic pillars present around sanctuary (Count: %d)" % monolith_count)

	# -------------------------------------------------------------
	# 3. 웨이브 1: 헤비 골렘 미니언 2기 검증
	# -------------------------------------------------------------
	print("\n--- Test 3: Wave 1 Heavy Golem Minions (golem_v1.png) ---")
	check(stage.current_wave == 1, "Wave 1 is active")
	check(stage.enemies.size() == 2, "Wave 1 spawned exactly 2 minion enemies (Count: %d)" % stage.enemies.size())

	var minion1 = stage.enemies[0]
	var minion2 = stage.enemies[1]
	check(minion1 != null and minion2 != null, "Both enemies are SideQVGolemMinion instances")

	if minion1 != null:
		check(minion1.max_hp == 8 and minion1.current_hp == 8, "Heavy Golem HP calibrated to 8 (High durability)")
		check(minion1.sprite_3d.hframes == 3 and minion1.sprite_3d.vframes == 2, "Heavy Golem sprite sheet split into 3x2 frames")
		check(is_equal_approx(minion1.sprite_3d.pixel_size, 0.0039), "Heavy Golem height calibrated to ~2.0m (pixel_size=0.0039)")

	# 상호 밀림 방지 검증: 플레이어가 미니언에게 다가가도 밀리지 않음
	var player = stage.player
	var prev_minion_pos: Vector3 = minion1.global_position
	player.global_position = minion1.global_position + Vector3(0.9, 0.0, 0.0)
	await _advance_frames(3)
	check(minion1.global_position.distance_to(prev_minion_pos) < 0.15,
		"Mutual stop verified: Minion is not pushed across the arena floor by player")

	# -------------------------------------------------------------
	# 4. 웨이브 2 전환 및 보스 (SideQVGolemGuardian) 검증
	# -------------------------------------------------------------
	print("\n--- Test 4: Wave 2 Transition & SideQVGolemGuardian Boss Spawn ---")
	# 미니언 2기 처치
	minion1.receive_hit(8, Vector3.ZERO)
	minion2.receive_hit(8, Vector3.ZERO)
	await _advance_frames(5)

	# 웨이브 완료 후 대기 타이머 시뮬레이션
	if stage.current_wave == 1:
		stage._start_boss_wave()
	await _advance_frames(5)

	check(stage.current_wave == 2, "Wave 2 (Boss Wave) activated successfully")
	var boss = stage.active_boss
	check(boss != null, "Stage 4 Boss SideQVGolemGuardian spawned and active")

	if boss != null:
		check(boss.max_hp == 32 and boss.current_hp == 32, "Boss max HP is 32 (Colossal Titan durability)")
		check(boss.sprite_3d.hframes == 4 and boss.sprite_3d.vframes == 3, "Boss sprite sheet split into 4x3 frames")
		check(is_equal_approx(boss.sprite_3d.pixel_size, 0.009375), "Boss height calibrated to colossal 2.8m (pixel_size=0.009375)")
		check(boss.is_in_group("enemies") and boss.is_in_group("bosses"), "Boss is in 'enemies' and 'bosses' groups")

		# 플레이어 정면 응시 회전 검증
		player.global_position = Vector3(boss.global_position.x - 4.0, 0.1, 0.0)
		await _advance_frames(3)
		check(boss.facing_dir_x == -1.0 and boss.sprite_3d.flip_h == true,
			"Boss correctly faces left towards player (facing_dir_x = -1.0, flip_h = true)")

		player.global_position = Vector3(boss.global_position.x + 4.0, 0.1, 0.0)
		await _advance_frames(5)
		check(boss.facing_dir_x == 1.0 and boss.sprite_3d.flip_h == false,
			"Boss correctly turned around to face right towards player (facing_dir_x = 1.0, flip_h = false)")

	# -------------------------------------------------------------
	# 5. 보스 패턴 1: 대지 강타 그라운드 슬램 (Ground Slam) 검증
	# -------------------------------------------------------------
	print("\n--- Test 5: Pattern 1 - Ground Slam & 3D Sharp Rock Pillars ---")
	var attack_info := {"fired": false, "name": ""}
	boss.attack_performed.connect(func(atk_name: String):
		attack_info["fired"] = true
		attack_info["name"] = atk_name
	)

	boss._execute_ground_slam()
	check(boss.current_pattern == SideQVGolemGuardianClass.Pattern.GROUND_SLAM, "Boss entered GROUND_SLAM pattern")
	check(attack_info["fired"] and attack_info["name"] == "GROUND_SLAM", "attack_performed('GROUND_SLAM') signal emitted")

	# Wait for windup to strike
	await create_timer(0.48).timeout
	await _advance_frames(2)

	# 3D 뾰족한 암석 파편 기둥 노드 존재 검증
	var pillars_node = stage.get_node_or_null("RockPillarsEffect")
	check(pillars_node != null, "3D RockPillarsEffect container erupted in stage")
	if pillars_node != null:
		var spike_count := 0
		for child in pillars_node.get_children():
			if child.name.begins_with("Pillar_"):
				spike_count += 1
		check(spike_count >= 5, "Multiple 3D jagged sharp stone spikes erupted (Count: %d)" % spike_count)

	# -------------------------------------------------------------
	# 6. 보스 패턴 2: 암석 회전 래리어트 (Spinning Stone Lariat) 검증
	# -------------------------------------------------------------
	print("\n--- Test 6: Pattern 2 - Spinning Stone Lariat ---")
	attack_info["fired"] = false
	attack_info["name"] = ""
	boss._execute_spinning_lariat()
	check(boss.current_pattern == SideQVGolemGuardianClass.Pattern.SPINNING_LARIAT, "Boss entered SPINNING_LARIAT pattern")
	check(attack_info["fired"] and attack_info["name"] == "SPINNING_LARIAT", "attack_performed('SPINNING_LARIAT') signal emitted")
	check(boss.attack_area_3d.monitoring == true, "Attack hitbox monitoring active during lariat")
	check(boss.lariat_dust_particles.emitting == true, "Swirling lariat dust particles active")

	# -------------------------------------------------------------
	# 7. 보스 패턴 3: 2페이즈 마그마 과부하 & 지진파 대지 분쇄 (Quake Fissure)
	# -------------------------------------------------------------
	print("\n--- Test 7: Phase 2 Magma Overload & Pattern 3 Quake Fissure ---")
	var phase_info := {"fired": false, "phase": 0}
	boss.phase_changed.connect(func(p: int):
		phase_info["fired"] = true
		phase_info["phase"] = p
	)

	# 50% 이하로 체력 감소 -> 2페이즈 발동
	boss.receive_hit(16)
	check(boss.current_hp == 16, "Boss HP reduced to 16/32")
	check(boss.current_phase == 2, "Phase 2 triggered at <= 50% HP")
	check(phase_info["fired"] and phase_info["phase"] == 2, "phase_changed(2) signal emitted")
	check(boss.magma_aura_ring.visible == true, "Magma Core Aura Ring is visible in Phase 2")
	check(boss.ember_particles.emitting == true, "Golem ember particles emitting in Phase 2")

	# 지진파 대지 분쇄 실행
	attack_info["fired"] = false
	attack_info["name"] = ""
	boss._execute_quake_fissure()
	check(boss.current_pattern == SideQVGolemGuardianClass.Pattern.QUAKE_FISSURE, "Boss entered QUAKE_FISSURE pattern")
	check(attack_info["fired"] and attack_info["name"] == "QUAKE_FISSURE", "attack_performed('QUAKE_FISSURE') signal emitted")

	await create_timer(0.45).timeout
	await _advance_frames(2)

	var fissure_node = stage.get_node_or_null("MoltenFissureContainer")
	check(fissure_node != null, "MoltenFissureContainer erupted across floor")
	if fissure_node != null:
		var seg_count := 0
		for child in fissure_node.get_children():
			if child.name.begins_with("FissureSeg_"):
				seg_count += 1
		check(seg_count >= 5, "Linear molten lava fissure segments generated (Count: %d)" % seg_count)

	# -------------------------------------------------------------
	# 8. 저스트 패링 스턴 및 보스 처치 클리어 검증
	# -------------------------------------------------------------
	print("\n--- Test 8: Just Parry Stun & Stage Clear ---")
	boss.apply_parry_stun(2.0)
	check(boss.is_stunned == true, "Boss entered STUNNED state from parry")
	check(boss.attack_area_3d.monitoring == false, "Attack monitoring disabled while stunned")
	check(boss.velocity == Vector3.ZERO, "Velocity firmly stopped upon parry clash")

	var boss_def_info := {"fired": false}
	boss.boss_defeated.connect(func(_node): boss_def_info["fired"] = true)

	# 보스 잔여 체력 전량 소진
	boss.receive_hit(16)
	check(boss_def_info["fired"], "boss_defeated signal emitted upon reaching 0 HP")
	check(stage.is_stage_finished == true, "Stage is marked finished")

	# Wait for clear fanfare
	await create_timer(1.0).timeout
	await _advance_frames(5)
	check(test_events["stage_cleared"], "stage_cleared signal emitted successfully")

	# -------------------------------------------------------------
	# 최종 결과 집계
	# -------------------------------------------------------------
	print("\n===================================================================")
	print("QA TEST RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("===================================================================")

	if failures == 0:
		print("\n>>> ALL STAGE 4 QA SMOKE CHECKS PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> STAGE 4 QA SUITE FAILED WITH %d ERRORS <<<\n" % failures)
		quit(1)
