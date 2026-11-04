extends SceneTree
## JUNYPAPA STUDIO — 콘솔/스팀 명작 액션 게임 수준 고급 전투 감각(Game Feel) & 보스 그로기/텔레그래프 검증 스위트
## 검증 항목:
## 1. 3D 플로팅 데미지 텍스트 (Label3D 빌보드, 노뎁스테스트, 팝업 트윈)
## 2. 공중 하단 베기 적 밟기 반동 점프 (Hollow Knight Style Air Pogo Bounce & 충격파 링)
## 3. 5대 보스 체간 & 그로기 시스템 (Poise Stagger & 방어력 산산조각 +1 추가 데미지)
## 4. 위험 공격 사전 경고 전조 (Danger Telegraph '!' 마커 & 3D 비콘 링)
## 5. 실시간 전투 콤보 카운터 & 랭크 HUD (연속 타격 시 영혼 파편 추가 보너스)

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const BeastChieftainClass = preload("res://scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd")
const CrossbowCmdClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")
const GolemGuardianClass = preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")
const AbyssalArbiterClass = preload("res://scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd")
const SideQVStageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")
const AudioManagerClass = preload("res://scripts/audio/audio_manager.gd")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")

var total_checks: int = 0
var total_failures: int = 0


func _initialize() -> void:
	# 15초 워치독 타이머 (User Rule 3)
	create_timer(15.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] test_advanced_combat_feel.gd exceeded 15.0s!")
		quit(1)
	)
	_run_verification.call_deferred()


func check(cond: bool, msg: String) -> void:
	total_checks += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		total_failures += 1
		printerr("  [FAIL] %s" % msg)


func _run_verification() -> void:
	print("\n========================================================================")
	print(">>> [JUNYPAPA STUDIO] ADVANCED COMBAT FEEL & BOSS GROGGY VERIFICATION <<<")
	print("========================================================================\n")

	var arena := Node3D.new()
	arena.name = "TestArena3D"
	root.add_child(arena)
	await process_frame

	# --------------------------------------------------------------------------
	# 1. 3D 플로팅 데미지 텍스트 시스템 검증
	# --------------------------------------------------------------------------
	print("--- 1. 3D 플로팅 데미지 텍스트 시스템 (Floating Combat Text) ---")
	GameFeelManager.damage_popup_3d(arena, Vector3(0.0, 1.0, 0.0), "24 CRIT!", Color(0.2, 1.0, 1.4), true)
	await process_frame
	var float_label := arena.get_node_or_null("FloatingDamage3D") as Label3D
	check(float_label != null, "3D 데미지 팝업 Label3D 생성 완료")
	if float_label != null:
		check(float_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Label3D 카메라 방향 상시 빌보드 활성화")
		check(float_label.no_depth_test == true, "3D 모델 관통 방지용 no_depth_test 활성화")
		check(float_label.text == "24 CRIT!", "크리티컬 텍스트 정합성 확인")

	# --------------------------------------------------------------------------
	# 2. 플레이어 전투 피드백 & 공중 포고 점프 (Air Pogo Bounce) 검증
	# --------------------------------------------------------------------------
	print("\n--- 2. 플레이어 전투 피드백 & 공중 포고 점프 (Air Pogo Bounce) ---")
	var player := SideQVPlayerClass.new()
	arena.add_child(player)
	player.global_position = Vector3(0.0, 2.5, 0.0) # 공중 위치
	await process_frame

	var dummy_enemy := SideQVBossClass.new()
	arena.add_child(dummy_enemy)
	dummy_enemy.global_position = Vector3(0.5, 0.5, 0.0) # 플레이어 발 아래
	await process_frame

	var pogo_called := [false]
	player.pogo_bounced.connect(func(_p): pogo_called[0] = true)

	# 공중 공격 수행
	player.start_attack()
	await process_frame

	check(player.velocity.y > 5.0, "공중 하단 공격 적중 시 상향 반동 점프 가속도 부여 (Vy: %.2f)" % player.velocity.y)
	check(pogo_called[0] == true, "포고 바운스 시그널(pogo_bounced) 정상 발신")
	check(arena.get_node_or_null("PogoShockwaveRing3D") != null, "발 아래 3D 수평 포고 충격파 링(PogoShockwaveRing3D) 생성")

	# --------------------------------------------------------------------------
	# 3. 5대 보스 체간 & 그로기 시스템 (Boss Poise & Groggy Stagger) 검증
	# --------------------------------------------------------------------------
	print("\n--- 3. 5대 보스 체간 & 그로기 시스템 (Poise & Groggy) ---")
	var boss1 := SideQVBossClass.new()
	var boss2 := BeastChieftainClass.new()
	var boss3 := CrossbowCmdClass.new()
	var boss4 := GolemGuardianClass.new()
	var boss5 := AbyssalArbiterClass.new()

	check(boss1.max_poise == 12 and boss1.current_poise == 12, "Stage 1 보스 체간 12 설정 확인")
	check(boss2.max_poise == 14 and boss2.current_poise == 14, "Stage 2 보스 체간 14 설정 확인")
	check(boss3.max_poise == 12 and boss3.current_poise == 12, "Stage 3 보스 체간 12 설정 확인")
	check(boss4.max_poise == 16 and boss4.current_poise == 16, "Stage 4 보스 체간 16 설정 확인")
	check(boss5.max_poise == 18 and boss5.current_poise == 18, "Stage 5 보스 체간 18 설정 확인")

	# 보스 1 체간 파괴 시뮬레이션
	arena.add_child(boss1)
	await process_frame
	var init_hp := boss1.current_hp
	boss1.receive_hit(12) # 체간 12 즉시 소진
	await process_frame

	check(boss1.is_groggy == true, "체간 0 도달 시 보스 그로기(Stagger) 상태 진입")
	check(boss1.get_node_or_null("GroggyHalo3D") != null, "보스 머리 위 황금빛 회전 어지럼 헤일로(GroggyHalo3D) 생성")

	# 그로기 중 추가 피격 시 방어 파쇄 보너스 (+1 추가 데미지)
	var hp_before_shatter := boss1.current_hp
	boss1.receive_hit(2) # 기본 2 데미지 + 그로기 파쇄 1 = 총 3 데미지
	check(boss1.current_hp == hp_before_shatter - 3, "그로기 상태에서 방어 파쇄 추가 데미지(+1) 적용 확인 (예상 피격: 3)")

	boss1._exit_groggy_state()
	check(boss1.is_groggy == false and boss1.current_poise == boss1.max_poise, "그로기 종료 후 체간 최대치 자동 복구 확인")

	boss1.queue_free()
	boss2.queue_free()
	boss3.queue_free()
	boss4.queue_free()
	boss5.queue_free()
	await process_frame

	# --------------------------------------------------------------------------
	# 4. 보스 위험 공격 사전 경고 전조 (Danger Telegraph) 검증
	# --------------------------------------------------------------------------
	print("\n--- 4. 보스 위험 공격 사전 경고 전조 (Danger Telegraph) ---")
	var test_boss := SideQVBossClass.new()
	arena.add_child(test_boss)
	await process_frame
	test_boss._show_danger_telegraph(0.35)
	await process_frame

	check(arena.get_node_or_null("DangerTelegraphRing3D") != null, "공격 전조 시 바닥 3D 붉은 비콘 링(DangerTelegraphRing3D) 생성")
	test_boss.queue_free()
	await process_frame

	# --------------------------------------------------------------------------
	# 5. 실시간 전투 콤보 카운터 & 랭크 HUD 검증
	# --------------------------------------------------------------------------
	print("\n--- 5. 실시간 전투 콤보 카운터 & 랭크 HUD (Combo Chain) ---")
	var stage := SideQVStageBaseClass.new()
	stage.stage_index = 1
	root.add_child(stage)
	await process_frame

	check(stage.combo_hud != null, "모바일/PC 공용 콤보 HUD 컨트롤 생성 확인")
	check(stage.combo_label != null and stage.combo_sub_label != null, "콤보 수치 라벨 및 랭크 서브 라벨 구비")

	# 연속 타격 시뮬레이션
	var shards_before := SaveManagerClass.get_shards()
	for i in range(5):
		stage._on_player_enemy_hit(null, 2, false)

	check(stage.current_combo_count == 5, "5연타 콤보 카운트 정상 누적")
	check(stage.combo_label.text == "5 HITS", "콤보 라벨 '5 HITS' 표시")
	check(stage.combo_sub_label.text.begins_with("GROGGY BREAKER"), "5연타 달성 시 'GROGGY BREAKER' 랭크 승급")
	check(SaveManagerClass.get_shards() == shards_before + 1, "5콤보 마일스톤 달성 시 보너스 영혼 파편 +1 즉시 지급 확인")

	stage.queue_free()
	arena.queue_free()
	await process_frame
	await process_frame

	# 오디오 및 인스턴스 무결점 정리 (Rule 3)
	if AudioManagerClass._instance != null and is_instance_valid(AudioManagerClass._instance):
		AudioManagerClass._instance.stop_music()
		for p in AudioManagerClass._instance._players:
			if is_instance_valid(p):
				p.stop()
				p.stream = null
		if is_instance_valid(AudioManagerClass._instance._bgm_player):
			AudioManagerClass._instance._bgm_player.stop()
			AudioManagerClass._instance._bgm_player.stream = null
		AudioManagerClass._instance._streams.clear()
		AudioManagerClass._instance.queue_free()
		AudioManagerClass._instance = null
	await process_frame
	await process_frame

	print("\n========================================================================")
	print(">>> COMBAT FEEL VERIFICATION RESULT: %d CHECKS | %d FAILURES <<<" % [total_checks, total_failures])
	print("========================================================================\n")
	quit(0 if total_failures == 0 else 1)
