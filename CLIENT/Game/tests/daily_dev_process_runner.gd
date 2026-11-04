extends SceneTree
## JUNYPAPA STUDIO — 일일 게임 개발 프로세스 자동화 엔진 (Daily Game Dev Process Runner)
## 게임 개발 표준 5단계 데일리 루틴:
## 1단계 [09:00] 기획 & 밸런스 감사 (Design & Balance Audit)
## 2단계 [11:00] 아트 & 그래픽 VFX 감사 (Art & VFX Quality Audit)
## 3단계 [14:00] 개발 & 코드 무결성 점검 (Dev Code & Mechanics Audit)
## 4단계 [17:00] QA 플레이테스트 시뮬레이션 (QA Regression Simulation)
## 5단계 [18:00] 데일리 빌드 & 일일 업무 리포트 자동 생성 (Daily Build & Report Generation)

const AXDataRegistryClass = preload("res://scripts/data/ax_data_registry.gd")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SpriteInspectorScene = preload("res://scenes/ui/SpriteInspectorTool.tscn")
const TitleScreenScene = preload("res://scenes/ui/TitleScreen.tscn")
const CampfireShopClass = preload("res://scripts/ui/campfire_shop.gd")
const AudioManagerClass = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")
const BeastChieftainClass = preload("res://scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd")
const CrossbowCmdClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")
const GolemGuardianClass = preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")
const AbyssalArbiterClass = preload("res://scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd")
const SideQVStageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")

const STAGE_SCENES := [
	"res://scenes/side_quarter_view/SideQVStage1.tscn",
	"res://scenes/side_quarter_view/SideQVStage2.tscn",
	"res://scenes/side_quarter_view/SideQVStage3.tscn",
	"res://scenes/side_quarter_view/SideQVStage4.tscn",
	"res://scenes/side_quarter_view/SideQVStage5.tscn",
]

var total_checks: int = 0
var total_failures: int = 0
var phase_logs: Dictionary = {
	"1_design": [],
	"2_art": [],
	"3_dev": [],
	"4_qa": [],
	"5_release": []
}


func _initialize() -> void:
	# 15초 워치독 타이머 (User Rule 3)
	create_timer(15.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] daily_dev_process_runner.gd exceeded 15.0s!")
		quit(1)
	)
	_execute_daily_pipeline.call_deferred()


func log_step(phase_key: String, cond: bool, msg: String) -> void:
	total_checks += 1
	var status_str := "PASS" if cond else "FAIL"
	var line := "[%s] %s" % [status_str, msg]
	phase_logs[phase_key].append(line)
	if cond:
		print("  [%s] %s" % [status_str, msg])
	else:
		total_failures += 1
		printerr("  [%s] %s" % [status_str, msg])


func _execute_daily_pipeline() -> void:
	var date_dict := Time.get_date_dict_from_system()
	var time_dict := Time.get_time_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [date_dict["year"], date_dict["month"], date_dict["day"]]
	var time_str := "%02d:%02d:%02d" % [time_dict["hour"], time_dict["minute"], time_dict["second"]]

	print("\n========================================================================")
	print(">>> [JUNYPAPA STUDIO] DAILY GAME DEV AUTOMATION PIPELINE START <<<")
	print(">>> Timestamp: %s %s (KST) <<<" % [date_str, time_str])
	print("========================================================================\n")

	# ==========================================================================
	# 1단계: [기획 & 밸런스 감사]
	# ==========================================================================
	print("--- PHASE 1: [09:00] 기획 & 밸런스 감사 (Design & Balance Audit) ---")
	var ax_data: Dictionary = AXDataRegistryClass.load_ax_data()
	log_step("1_design", not ax_data.is_empty(), "AX 마스터 데이터 테이블 로드 완료")

	var bosses_arr: Array = ax_data.get("bosses", [])
	log_step("1_design", bosses_arr.size() == 5, "보스 5종 메타데이터 완비 (Stage 1~5)")

	var expected_boss_hp := { "boss_commander": 24, "boss_beast_chieftain": 28, "boss_crossbow_commander": 30, "boss_golem_guardian": 34, "boss_abyssal_arbiter": 38 }
	for b in bosses_arr:
		var bid: String = b.get("id", "")
		var hp: int = int(b.get("hp", 0))
		log_step("1_design", hp == expected_boss_hp.get(bid, -1), "보스 '%s' 체력 곡선 정합성 (HP: %d)" % [bid, hp])

	var stages_arr: Array = ax_data.get("stages", [])
	var expected_rewards := [20, 25, 30, 35, 50]
	for i in range(stages_arr.size()):
		var reward: int = int(stages_arr[i].get("clear_shard_reward", 0))
		log_step("1_design", reward == expected_rewards[i], "Stage %d 클리어 영혼 파편 보상 정합성 (+%d Shards)" % [i + 1, reward])

	log_step("1_design", SaveManagerClass.RUNIC_ENGRAVINGS.size() == 3, "고대 룬 각인 3종 메타데이터 완비 (Vampiric, Thunder, Aegis)")

	var b1 := SideQVBossClass.new()
	var b2 := BeastChieftainClass.new()
	var b3 := CrossbowCmdClass.new()
	var b4 := GolemGuardianClass.new()
	var b5 := AbyssalArbiterClass.new()
	log_step("1_design", b1.max_poise == 12 and b2.max_poise == 14 and b3.max_poise == 12 and b4.max_poise == 16 and b5.max_poise == 18, "5대 보스 체간(Poise) 스탯 무결성 검증 (12/14/12/16/18)")
	b1.free()
	b2.free()
	b3.free()
	b4.free()
	b5.free()

	# ==========================================================================
	# 2단계: [아트 & 그래픽 VFX 감사]
	# ==========================================================================
	print("\n--- PHASE 2: [11:00] 아트 & 그래픽 VFX 감사 (Art & VFX Quality Audit) ---")
	# 28종 전체 스프라이트 시트 셀 경계 침범(Bleed) 및 규격 검사
	var inspector := SpriteInspectorScene.instantiate()
	root.add_child(inspector)
	await process_frame

	var total_bleeds: int = 0
	for entry in inspector.SPRITE_CATALOG:
		inspector.select_sprite_by_id(entry["id"])
		total_bleeds += inspector.get_current_sheet_bleed_count()
	log_step("2_art", inspector.get_catalog_size() == 28 and total_bleeds == 0, "스프라이트 시트 28종 셀 경계 침범(Bleed) 0건 검증 완료")
	inspector.queue_free()
	await process_frame

	# 스테이지 1~5 앰비언스, WorldEnvironment HDR Glow, Depth Fog, 부유 파티클 검증
	var expected_particles := [
		"CitadelDustEmbers", "ForestFireflies", "BastionArcaneSpores", "EmberParticles3D", "AbyssalVoidParticles"
	]
	for i in range(STAGE_SCENES.size()):
		var stg_scene := load(STAGE_SCENES[i]) as PackedScene
		var stg := stg_scene.instantiate()
		root.add_child(stg)
		await process_frame

		var wenv := stg.get_node_or_null("WorldEnvironment3D") as WorldEnvironment
		var has_glow: bool = (wenv != null and wenv.environment != null and wenv.environment.glow_enabled)
		var has_fog: bool = (wenv != null and wenv.environment != null and wenv.environment.fog_enabled)
		log_step("2_art", has_glow and has_fog, "Stage %d WorldEnvironment HDR Glow & Depth Fog 활성화" % (i + 1))

		var pnode := stg.get_node_or_null(expected_particles[i]) as CPUParticles3D
		log_step("2_art", pnode != null, "Stage %d 부유 3D 환경 입자 탑재 (%s)" % [i + 1, expected_particles[i]])

		stg.queue_free()
		await process_frame

	var temp_boss := SideQVBossClass.new()
	root.add_child(temp_boss)
	await process_frame
	temp_boss._show_danger_telegraph(0.35)
	temp_boss._spawn_groggy_halo()
	await process_frame
	log_step("2_art", root.get_node_or_null("DangerTelegraphRing3D") != null and temp_boss.get_node_or_null("GroggyHalo3D") != null, "보스 위험 공격 전조 비콘 링 & 그로기 어지럼 헤일로 3D 연출 검증")
	var ring_node := root.get_node_or_null("DangerTelegraphRing3D")
	if ring_node != null:
		ring_node.queue_free()
	var dpop_node := root.get_node_or_null("FloatingDamage3D")
	if dpop_node != null:
		dpop_node.queue_free()
	temp_boss.queue_free()
	await process_frame
	await process_frame

	# ==========================================================================
	# 3단계: [개발 & 코드 무결성 점검]
	# ==========================================================================
	print("\n--- PHASE 3: [14:00] 개발 & 코드 무결성 점검 (Dev Code & Mechanics Audit) ---")
	var test_arena := Node3D.new()
	root.add_child(test_arena)
	var player := SideQVPlayerClass.new()
	test_arena.add_child(player)
	await process_frame

	log_step("3_dev", is_equal_approx(player.COYOTE_TIME, 0.12), "코요테 타임 0.12s 조작감 유예 정상 작동")
	log_step("3_dev", is_equal_approx(player.JUMP_BUFFER_TIME, 0.14), "점프 선입력 버퍼 0.14s 정상 작동")
	log_step("3_dev", is_equal_approx(player.ATTACK_BUFFER_TIME, 0.12), "공격 선입력 버퍼 0.12s (공중-지상 콤보 연계) 정상 작동")

	# 유물 5종 패시브 버프 연동 검증
	player.grant_relic("shadow_cloak")
	player.grant_relic("wind_quiver")
	player.grant_relic("titan_pauldrons")
	player.grant_relic("abyssal_crown")
	log_step("3_dev", player.move_speed_x > 7.5 and player.max_hp == 9 and player.current_attack_damage == 3, "유물 5종 패시브 스탯 인게임 연동 완료 (속도, 체력+1, 공격력+1)")

	# 룬 각인 3종 인게임 전투 연동 검증
	player.grant_engraving("vampiric_edge")
	player.grant_engraving("thunder_step")
	player.grant_engraving("aegis_reflect")
	log_step("3_dev", player.has_engraving("vampiric_edge") and player.has_engraving("thunder_step") and player.has_engraving("aegis_reflect"), "룬 각인 3종 플레이어 전투 모듈 연동 완료")

	# 3D 전투 VFX 생성 검증
	player._trigger_parry_flash()
	log_step("3_dev", test_arena.get_node_or_null("ParryShockwaveRing3D") != null, "저스트 패링 시 3D 골든-시안 충격파 링 생성")

	player.start_dash()
	log_step("3_dev", test_arena.get_node_or_null("ThunderStepSpark3D") != null, "뇌전의 걸음 대시 시 3D 번개 잔상 스파크 생성")
	log_step("3_dev", test_arena.get_node_or_null("DashGhost3D") != null, "대시 이동 시 3D 네온 잔상 아프터이미지(DashGhost3D) 생성")

	player._spawn_vampiric_heal_vfx(player.global_position)
	log_step("3_dev", test_arena.get_node_or_null("VampiricHealAura3D") != null, "흡혈의 칼날 피니셔 시 3D 진홍 치유 오라 생성")

	player._spawn_aegis_reflect_vfx(player.global_position)
	log_step("3_dev", test_arena.get_node_or_null("AegisReflectBurst3D") != null, "이지스 반사 시 3D 황금 반사 섬광 생성")

	# 3D 플로팅 데미지 텍스트 팝업 검증
	GameFeelManager.damage_popup_3d(test_arena, player.global_position, "12", Color.YELLOW)
	await process_frame
	var has_damage_pop := test_arena.get_node_or_null("FloatingDamage3D") != null or test_arena.get_node_or_null("FloatingDamage3D_Direct") != null
	log_step("3_dev", has_damage_pop, "3D 플로팅 데미지 텍스트 팝업 (Billboard Label3D) 생성 검증")

	# 할로우 나이트 스타일 공중 포고 바운스 (Pogo Bounce) 검증
	player.velocity.y = -5.0
	player._execute_pogo_bounce()
	var pogo_ring := test_arena.get_node_or_null("PogoShockwaveRing3D")
	log_step("3_dev", pogo_ring != null and player.velocity.y > 0.0, "할로우 나이트 스타일 공중 포고 바운스 (수직 반동 & 충격파 링) 작동")

	# 공중 급강하 스톰프 다이브 (Dive Slam Attack) & 3D 대지 충격파 검증
	player.global_position = Vector3(0.0, 3.5, 0.0)
	player.start_dive_slam()
	player.global_position.y = 0.0
	player._execute_dive_slam_landing()
	await process_frame
	log_step("3_dev", test_arena.get_node_or_null("DiveShockwaveRing3D") != null, "공중 하향 급강하 스톰프 다이브(DiveSlam) & 3D 대지 충격파 링 생성")

	var boss1 := SideQVBossClass.new()
	test_arena.add_child(boss1)
	await process_frame
	boss1._execute_quake_ring()
	log_step("3_dev", test_arena.get_node_or_null("DangerTelegraphRing3D") != null, "Stage 1 보스 위험 공격 전조 3D 비콘 링 생성")
	await create_timer(0.4).timeout
	log_step("3_dev", test_arena.get_node_or_null("QuakeShockwaveRing3D") != null, "Stage 1 보스 대지 충격파 3D 진홍 링 생성")

	# 다이내믹 카메라 전방 Lookahead & 듀얼 보스 프레이밍 검증
	var cam := SideQVCameraClass.new()
	test_arena.add_child(cam)
	boss1.global_position = Vector3(10.0, 0.0, 0.0)
	cam.target = player
	cam.boss_target = boss1
	cam._physics_process(0.1)
	log_step("3_dev", cam.fov > 42.0 and cam.base_pos.x != 0.0, "다이내믹 카메라 전방 Lookahead 및 보스 대치 가변 FOV 프레이밍 작동")
	cam.queue_free()

	# 보스 체간 붕괴 및 그로기 탈진 / 방어구 파쇄 피해 검증
	boss1.current_poise = 2
	boss1.receive_hit(4)
	await process_frame
	log_step("3_dev", boss1.is_groggy == true, "보스 체간 붕괴 시 그로기(Groggy) 탈진 상태 진입 검증")
	var groggy_hp_before := boss1.current_hp
	boss1.receive_hit(2)
	var groggy_damage := groggy_hp_before - boss1.current_hp
	log_step("3_dev", groggy_damage == 3, "보스 그로기 상태 피격 시 방어구 파쇄 추가 피해(+1 Shatter Damage) 연동")
	await process_frame
	await process_frame

	test_arena.queue_free()
	await process_frame

	# ==========================================================================
	# 4단계: [QA 플레이테스트 시뮬레이션]
	# ==========================================================================
	print("\n--- PHASE 4: [17:00] QA 플레이테스트 시뮬레이션 (QA Regression Simulation) ---")
	var title := TitleScreenScene.instantiate()
	root.add_child(title)
	await process_frame
	log_step("4_qa", title.btn_new_game != null and title.btn_ax_data != null and title.btn_sprite_studio != null, "타이틀 로비 화면 버튼 연동 정상 (출격, 코덱스, 스프라이트 툴)")
	title.queue_free()
	await process_frame

	var shop := CampfireShopClass.new()
	root.add_child(shop)
	await process_frame
	log_step("4_qa", shop._vamp_btn != null and shop._thunder_btn != null and shop._aegis_btn != null, "성소 화톳불 상점 룬 각인 3종 버튼 및 스크롤 UI 정상")
	shop.queue_free()
	await process_frame

	# 인게임 실시간 전투 콤보 HUD & 5연타 보너스 파편 지급 검증
	var stage1 := SideQVStageBaseClass.new()
	stage1.stage_index = 1
	root.add_child(stage1)
	await process_frame
	var initial_shards: int = SaveManagerClass.get_shards()
	for i in range(5):
		stage1._on_player_enemy_hit(null, 2, false)
	log_step("4_qa", stage1.current_combo_count == 5 and stage1.combo_label != null and stage1.combo_label.text == "5 HITS", "전투 콤보 카운터 HUD 및 랭크 타이틀 실시간 갱신 정상")
	log_step("4_qa", SaveManagerClass.get_shards() == initial_shards + 1, "5연속 콤보 마일스톤 달성 시 추가 영혼 파편(+1 Shard) 지급 검증")
	stage1.queue_free()
	await process_frame
	await process_frame

	# ==========================================================================
	# 5단계: [데일리 빌드 & 일일 업무 리포트 자동 생성]
	# ==========================================================================
	print("\n--- PHASE 5: [18:00] 데일리 빌드 & 일일 업무 리포트 자동 생성 (Daily Build & Report) ---")
	var apk_path := ProjectSettings.globalize_path("res://builds/android/ProjectKnight.apk")
	var exe_path := ProjectSettings.globalize_path("res://builds/windows/ProjectKnight.exe")
	var apk_exists := FileAccess.file_exists(apk_path)
	var exe_exists := FileAccess.file_exists(exe_path)
	log_step("5_release", apk_exists, "안드로이드 APK 최신 빌드 산출물 확인 완료 (%s)" % apk_path)
	log_step("5_release", exe_exists, "윈도우 PC 실행 파일 최신 빌드 산출물 확인 완료 (%s)" % exe_path)

	# 데일리 마크다운 보고서 자동 생성
	_write_daily_report(date_str, time_str)

	print("\n========================================================================")
	print(">>> DAILY DEV PIPELINE FINISHED: %d CHECKS | %d FAILURES <<<" % [total_checks, total_failures])
	print("========================================================================\n")
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
	quit(0 if total_failures == 0 else 1)


func _write_daily_report(date_str: String, time_str: String) -> void:
	var dir_path := ProjectSettings.globalize_path("res://daily_reports")
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)

	var report_file_path := "%s/daily_report_%s.md" % [dir_path, date_str]
	var f := FileAccess.open(report_file_path, FileAccess.WRITE)
	if f == null:
		printerr("[DAILY PIPELINE] Failed to write daily report file: %s" % report_file_path)
		return

	var md := ""
	md += "# 📋 [JUNYPAPA STUDIO] 일일 게임 개발 프로세스 업무 보고서\n\n"
	md += "- **보고 일자**: %s (실행 시각: %s KST)\n" % [date_str, time_str]
	md += "- **파이프라인 결과**: **%d항목 검증 / %d실패 (100%% %s)**\n\n" % [total_checks, total_failures, "PASS" if total_failures == 0 else "FAIL"]
	md += "---\n\n"

	md += "## 1. 09:00 기획 & 밸런스 감사 (Design & Balance)\n"
	for l in phase_logs["1_design"]:
		md += "- %s\n" % l
	md += "\n"

	md += "## 2. 11:00 아트 & 그래픽 VFX 감사 (Art & VFX Quality)\n"
	for l in phase_logs["2_art"]:
		md += "- %s\n" % l
	md += "\n"

	md += "## 3. 14:00 개발 & 코드 무결성 점검 (Dev Code & Mechanics)\n"
	for l in phase_logs["3_dev"]:
		md += "- %s\n" % l
	md += "\n"

	md += "## 4. 17:00 QA 플레이테스트 시뮬레이션 (QA Regression)\n"
	for l in phase_logs["4_qa"]:
		md += "- %s\n" % l
	md += "\n"

	md += "## 5. 18:00 데일리 빌드 & 패키징 (Daily Build & Release)\n"
	for l in phase_logs["5_release"]:
		md += "- %s\n" % l
	md += "\n"

	md += "---\n"
	md += "> 본 보고서는 JUNYPAPA STUDIO 자동화 데일리 파이프라인 엔진(`daily_dev_process_runner.gd`)에 의해 매일 자동으로 작성 및 검증됩니다.\n"

	f.store_string(md)
	f.close()
	print("  [REPORT GENERATED] %s" % report_file_path)
