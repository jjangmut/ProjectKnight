extends SceneTree
## Automated Headless Smoke Test for Side Quarter-View Stage 2 (야수숲 협곡 / Beastwood Forest Gorge)
## Tests:
## 1. Stage 2 initialization and configuration
## 2. 3D Environment (Emerald ambience Color(0.2, 0.45, 0.25), Fog, Sunlight, Firefly particles)
## 3. 3D Architecture (Ancient tree trunks, beast totems, arena floor)
## 4. Wave 1: 2 SideQVBeastMinion spawns and combat mechanics
## 5. Wave 2: SideQVBeastChieftain boss spawn, UI BossHealthBar attachment
## 6. Boss Patterns: Pounce Leap, Triple Claw, Just Parry Stun, Phase 2 Enraged Roar
## 7. Stage clear signal flow on boss defeat

var total_checks: int = 0
var failed_checks: int = 0

const Stage2Scene = preload("res://scenes/side_quarter_view/SideQVStage2.tscn")
const SideQVBeastMinionClass = preload("res://scripts/side_quarter_view/enemies/side_qv_beast_minion.gd")
const SideQVBeastChieftainClass = preload("res://scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd")

func _init() -> void:
	# 15초 내장 워치독 타이머 필수 탑재
	var watchdog := create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] stage2_side_qv_smoke did not finish within 15.0s. Forcing exit.")
		quit(1)
	)
	call_deferred("_run_tests")


func _check(condition: bool, message: String) -> void:
	total_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failed_checks += 1
		printerr("FAIL: %s" % message)


func _run_tests() -> void:
	print("\n=== START STAGE 2 (BEASTWOOD FOREST GORGE) SMOKE TEST ===")

	# 1. 씬 인스턴스화
	var stage = Stage2Scene.instantiate()
	root.add_child(stage)

	await process_frame
	await process_frame

	# -------------------------------------------------------------
	# Check 1: Stage 2 기본 설정 및 식별자
	# -------------------------------------------------------------
	print("\n[Check 1: Stage 2 Metadata & Configuration]")
	_check(stage != null, "Stage 2 instantiated from SideQVStage2.tscn")
	_check(stage.stage_index == 2, "Stage index is 2 (Got: %d)" % stage.stage_index)
	_check(stage.stage_title == "야수숲", "Stage title is '야수숲' (Got: %s)" % stage.stage_title)
	_check(stage.arena_width == 40.0, "Arena width is 40.0m")
	_check(stage.arena_depth == 12.0, "Arena depth is 12.0m")

	# 헤드리스 테스트 스위트의 신속하고 안정적인 완료를 위한 딜레이 캘리브레이션
	stage.boss_wave_delay = 0.25
	stage.clear_fanfare_delay = 0.35

	# -------------------------------------------------------------
	# Check 2: 3D 환경 (WorldEnvironment, 에메랄드 앰비언스, 포그, 반딧불이)
	# -------------------------------------------------------------
	print("\n[Check 2: 3D Environment & Atmospheric Polish]")
	var world_env: WorldEnvironment = stage.get_node_or_null("WorldEnvironment3D")
	_check(world_env != null, "WorldEnvironment3D node present")
	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		_check(env.ambient_light_color.is_equal_approx(Color(0.2, 0.45, 0.25, 1.0)), 
			"Deep Forest Emerald Ambience configured correctly (Color(0.2, 0.45, 0.25))")
		_check(env.fog_enabled == true, "Lush emerald fog enabled")
		_check(env.glow_enabled == true, "3D HDR Glow bloom enabled")

	var sun: DirectionalLight3D = stage.get_node_or_null("SunLight3D")
	_check(sun != null, "Directional SunLight3D present")
	if sun != null:
		_check(sun.shadow_enabled == true, "Real-time shadow casting enabled on sun")

	var fireflies: CPUParticles3D = stage.get_node_or_null("ForestFireflies")
	_check(fireflies != null, "ForestFireflies CPUParticles3D present in stage")
	if fireflies != null:
		_check(fireflies.amount >= 50, "Fireflies particle count calibrated (%d particles)" % fireflies.amount)

	# -------------------------------------------------------------
	# Check 3: 3D 배경 구조물 (고목 나무 기둥, 토템, 바닥)
	# -------------------------------------------------------------
	print("\n[Check 3: 3D Architecture & Forest Terrain]")
	var floor_box: CSGBox3D = stage.get_node_or_null("ArenaFloor")
	_check(floor_box != null, "Textured ArenaFloor CSGBox3D present")
	_check(stage.get_node_or_null("AncientTree_0") != null, "Ancient Tree 0 cylinder present")
	_check(stage.get_node_or_null("AncientTree_4") != null, "Ancient Tree 4 cylinder present")
	_check(stage.get_node_or_null("BeastTotem_Left") != null, "Left Beast Totem present")
	_check(stage.get_node_or_null("BeastTotem_Right") != null, "Right Beast Totem present")

	# -------------------------------------------------------------
	# Check 4: 플레이어 & 카메라 & 모바일 UI
	# -------------------------------------------------------------
	print("\n[Check 4: Core Gameplay Setup]")
	_check(stage.player != null, "SideQVPlayer spawned in stage")
	_check(stage.camera != null, "SideQVCamera initialized with player target")
	_check(stage.mobile_controls != null, "Mobile controls / UI layer spawned")
	if stage.player != null:
		# 테스트 진행 중 피격으로 인한 조기 사망 방지 (풍부한 보스 패턴 검증용)
		stage.player.max_hp = 50
		stage.player.current_hp = 50

	# -------------------------------------------------------------
	# Check 5: 웨이브 1 맹수 미니언 스폰 및 동작 검증
	# -------------------------------------------------------------
	print("\n[Check 5: Wave 1 Beast Minions]")
	_check(stage.current_wave == 1, "Wave 1 active on start")
	_check(stage.enemies.size() == 2, "2 Beast Minions spawned in Wave 1")

	var minion1: SideQVBeastMinion = stage.enemies[0] as SideQVBeastMinion
	var minion2: SideQVBeastMinion = stage.enemies[1] as SideQVBeastMinion
	_check(minion1 != null and minion2 != null, "Both enemies are SideQVBeastMinion instances")

	if minion1 != null:
		_check(minion1.sprite_3d != null, "Minion 1 has Sprite3D")
		_check(minion1.sprite_3d.hframes == 3 and minion1.sprite_3d.vframes == 2, "Minion sprite sheet is 3x2 (beast_v2)")
		_check(minion1.max_hp == 5, "Minion max HP is 5")

		# Just Parry Stun 검증
		minion1.apply_parry_stun(1.5)
		_check(minion1.is_stunned == true, "Minion stunned on apply_parry_stun")
		_check(minion1.velocity == Vector3.ZERO, "Minion velocity zeroed on parry stun")

	# -------------------------------------------------------------
	# Check 6: 웨이브 1 클리어 -> 웨이브 2 보스 전환
	# -------------------------------------------------------------
	print("\n[Check 6: Wave Transition to Beast Chieftain]")
	minion1.receive_hit(10)
	minion2.receive_hit(10)

	await create_timer(0.4).timeout
	await process_frame
	await process_frame

	_check(stage.current_wave == 2, "Stage transitioned to Wave 2 (Boss Encounter)")
	_check(stage.active_boss != null, "Active boss node present in stage")
	_check(stage.active_boss is SideQVBeastChieftainClass, "Active boss is SideQVBeastChieftain")

	var boss: SideQVBeastChieftain = stage.active_boss as SideQVBeastChieftain

	# -------------------------------------------------------------
	# Check 7: 보스 스펙 및 구성 요소 검증
	# -------------------------------------------------------------
	print("\n[Check 7: Beast Chieftain Boss Specs & Components]")
	_check(boss.max_hp == 28, "Boss max HP is 28")
	_check(boss.current_hp == 28, "Boss current HP is 28")
	_check(boss.sprite_3d != null, "Boss Sprite3D present")
	_check(boss.sprite_3d.hframes == 4 and boss.sprite_3d.vframes == 3, "Boss sprite sheet is 4x3 (beast_chieftain_v2)")
	_check(boss.sprite_3d.pixel_size >= 0.0080, "Boss pixel_size calibrated for ~2.5m tall presence")
	_check(boss.aura_ring_3d != null, "Phase 2 Emerald Aura Ring mesh present")
	_check(boss.aura_ring_3d.visible == false, "Aura ring initially invisible in Phase 1")
	_check(boss.attack_area_3d != null, "Boss attack area present")

	# UI Boss Health Bar 부착 확인
	_check(stage.boss_health_bar != null, "BossHealthBar attached to UI")
	if stage.boss_health_bar != null:
		_check(stage.boss_health_bar.is_active == true, "BossHealthBar is active and tracking boss")

	# -------------------------------------------------------------
	# Check 8: 보스 패턴 및 전투 메커니즘
	# -------------------------------------------------------------
	print("\n[Check 8: Boss Combat Patterns & Just Parry]")
	# 8-1: 도약 덮치기 (Pounce Leap)
	boss._execute_pounce_leap(Vector3(-5.0, 0.0, 0.0))
	_check(boss.current_pattern == SideQVBeastChieftain.Pattern.POUNCE_LEAP, "Pattern switched to POUNCE_LEAP")
	_check(boss.is_leap_airborne == true, "Boss marked airborne during leap")
	_check(boss.velocity.y > 0.0, "Boss upward leap velocity applied (> 0.0)")

	boss._on_pounce_landed()
	_check(boss.is_leap_airborne == false, "Airborne cleared upon pounce landing")
	_check(boss.velocity == Vector3.ZERO, "Velocity firmly stopped upon pounce landing")

	# 8-2: 저스트 패링 스턴
	boss.apply_parry_stun(1.2)
	_check(boss.is_stunned == true, "Boss is_stunned true on apply_parry_stun")
	_check(boss.current_pattern == SideQVBeastChieftain.Pattern.STUNNED, "Boss pattern set to STUNNED")
	_check(boss.velocity == Vector3.ZERO, "Boss stands firm without knockback slide on parry clash")

	# 8-3: 분노 포효 및 2페이즈 전환 (HP 50% 이하)
	print("\n[Check 9: Phase 2 Enraged Roar]")
	var initial_speed: float = boss.move_speed
	boss.receive_hit(15) # 28 - 15 = 13 (<= 50%)

	_check(boss.current_hp == 13, "Boss HP reduced to 13")
	_check(boss.current_phase == 2, "Boss transitioned to Phase 2 (HP <= 50%)")
	_check(boss.aura_ring_3d.visible == true, "Emerald Aura Ring activated on Phase 2")
	_check(boss.move_speed > initial_speed, "Boss move speed increased on enrage (%.1f > %.1f)" % [boss.move_speed, initial_speed])
	_check(boss.current_pattern == SideQVBeastChieftain.Pattern.ENRAGED_ROAR, "Pattern switched to ENRAGED_ROAR")

	# -------------------------------------------------------------
	# Check 10: 보스 처치 및 스테이지 클리어
	# -------------------------------------------------------------
	print("\n[Check 10: Boss Defeat & Stage Clear Flow]")
	var signal_tracker := {"cleared": false}
	stage.stage_cleared.connect(func():
		signal_tracker.cleared = true
	)

	boss.receive_hit(20) # Lethal damage
	_check(boss.current_hp <= 0, "Boss HP reached 0 or below")
	_check(stage.is_stage_finished == true, "Stage marked finished upon boss defeat")

	await create_timer(0.5).timeout
	await process_frame
	await process_frame

	_check(signal_tracker.cleared == true, "stage_cleared signal emitted upon stage completion")

	# -------------------------------------------------------------
	# 요약 보고
	# -------------------------------------------------------------
	print("\n=== STAGE 2 SMOKE TEST SUMMARY ===")
	print("Total Checks: %d, Passed: %d, Failed: %d" % [total_checks, total_checks - failed_checks, failed_checks])

	if failed_checks == 0:
		print("TEST RESULT: ALL STAGE 2 CHECKS PASSED (100% PASS)!\n")
		quit(0)
	else:
		printerr("TEST RESULT: %d CHECKS FAILED!\n" % failed_checks)
		quit(1)
