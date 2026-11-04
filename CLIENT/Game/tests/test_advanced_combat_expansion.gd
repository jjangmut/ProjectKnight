extends SceneTree
## JUNYPAPA STUDIO — 고급 전투 & 카메라 다이내믹스 확장 검증 스위트
## 검증 항목:
## 1. 다이내믹 카메라 전방 시야 확장(Lookahead) & 보스 대치 시 듀얼 프레이밍/가변 FOV
## 2. 대시 시 3D 네온 잔상 고스트 아프터이미지(DashGhost3D) 생성 & 소멸
## 3. 공중 하향 급강하 스톰프 다이브(DiveSlam) & 착지 3D 대지 충격파 링(DiveShockwaveRing3D) & 광역 피해
## 4. 다이브 스톰프 적중 시 체간 파쇄(Poise Damage) 및 콤보 HUD 연동

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const SideQVStageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const AudioManagerClass = preload("res://scripts/audio/audio_manager.gd")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")

var total_checks: int = 0
var total_failures: int = 0


func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] test_advanced_combat_expansion.gd exceeded 15.0s!")
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
	print(">>> [JUNYPAPA STUDIO] ADVANCED COMBAT EXPANSION & CAMERA AUDIT <<<")
	print("========================================================================\n")

	var arena := Node3D.new()
	arena.name = "ExpansionTestArena3D"
	root.add_child(arena)
	await process_frame

	# --------------------------------------------------------------------------
	# 1. 다이내믹 카메라 전방 Lookahead & 듀얼 보스 프레이밍 검증
	# --------------------------------------------------------------------------
	print("--- 1. 다이내믹 카메라 시스템 (Dynamic Lookahead & Boss Dual Framing) ---")
	var cam := SideQVCameraClass.new()
	arena.add_child(cam)
	var player := SideQVPlayerClass.new()
	arena.add_child(player)
	cam.target = player
	await process_frame

	# 플레이어가 오른쪽을 바라볼 때 전방 시야 오프셋 적용
	player.facing_dir_x = 1.0
	cam._physics_process(0.1)
	check(cam.base_pos.x > player.global_position.x + 0.1, "플레이어 전방 시야 확장(Lookahead) 오른쪽 오프셋 작동 (Cam X: %.2f)" % cam.base_pos.x)

	# 보스 등장 시 듀얼 프레이밍 & 가변 FOV 테스트
	var boss := SideQVBossClass.new()
	arena.add_child(boss)
	boss.global_position = Vector3(12.0, 0.0, 0.0)
	cam.boss_target = boss
	cam._physics_process(0.1)
	var expected_mid_x := (player.global_position.x + boss.global_position.x) * 0.5
	check(absf(cam.base_pos.x - expected_mid_x) < 1.5, "보스 대치 시 중점(Midpoint) 듀얼 프레이밍 작동 (Mid X: %.2f)" % expected_mid_x)
	check(cam.fov > 42.0, "원거리 보스 대치 시 가변 FOV 확장 (FOV: %.1f > 42.0)" % cam.fov)

	cam.boss_target = null
	cam.queue_free()
	boss.queue_free()
	await process_frame

	# --------------------------------------------------------------------------
	# 2. 대시 시 3D 네온 잔상 아프터이미지 (DashGhost3D) 검증
	# --------------------------------------------------------------------------
	print("\n--- 2. 대시 3D 네온 잔상 아프터이미지 (Dash Shadow Ghost Trail) ---")
	player.start_dash()
	await process_frame
	var ghost := arena.get_node_or_null("DashGhost3D")
	check(ghost != null, "대시 시작 시 3D 네온 잔상 고스트(DashGhost3D) 생성 확인")
	if ghost != null:
		check(ghost.no_depth_test == true, "잔상 고스트 모델 관통 방지(no_depth_test) 활성화")

	# --------------------------------------------------------------------------
	# 3. 공중 급강하 스톰프 다이브 (Dive Slam) & 3D 대지 충격파 검증
	# --------------------------------------------------------------------------
	print("\n--- 3. 공중 급강하 스톰프 다이브 (Dive Slam Attack) ---")
	player.global_position = Vector3(0.0, 3.5, 0.0)
	var dummy_enemy := SideQVBossClass.new()
	arena.add_child(dummy_enemy)
	dummy_enemy.global_position = Vector3(1.2, 0.0, 0.0)
	dummy_enemy.current_poise = 10
	var enemy_hp_before := dummy_enemy.current_hp
	await process_frame

	var dive_called := [false]
	player.dive_slammed.connect(func(_p, _cnt): dive_called[0] = true)

	player.start_dive_slam()
	check(player.current_state == SideQVPlayerClass.State.DIVE_SLAM, "공중에서 다이브 슬램 상태(DIVE_SLAM) 진입")
	check(player.velocity.y < -15.0, "고속 하향 급강하 가속도 적용 (Vy: %.2f)" % player.velocity.y)

	# 착지 시뮬레이션
	player.global_position.y = 0.0
	player._execute_dive_slam_landing()
	await process_frame

	check(dive_called[0] == true, "다이브 슬램 착지 시그널(dive_slammed) 정상 발신")
	var shockwave := arena.get_node_or_null("DiveShockwaveRing3D")
	check(shockwave != null, "착지 시 3D 대지 충격파 링(DiveShockwaveRing3D) 생성")
	check(dummy_enemy.current_hp < enemy_hp_before, "범위 내 적에게 강타 데미지 적용 (HP: %d -> %d)" % [enemy_hp_before, dummy_enemy.current_hp])
	check(dummy_enemy.current_poise <= 6, "다이브 스톰프 적중 시 대형 체간 피해(-4) 적용 (Poise: %d)" % dummy_enemy.current_poise)

	# --------------------------------------------------------------------------
	# 4. 콤보 HUD 및 스테이지 연동 검증
	# --------------------------------------------------------------------------
	print("\n--- 4. 콤보 HUD 다이브 스톰프 랭크 연동 ---")
	var stage := SideQVStageBaseClass.new()
	stage.stage_index = 1
	root.add_child(stage)
	await process_frame

	stage._on_player_dive_slammed(player, 2)
	check(stage.current_combo_count >= 2, "다이브 스톰프로 다수 적 적중 시 콤보 누적 확인")
	check(stage.combo_sub_label.text.contains("TITAN STOMP"), "다이브 스톰프 성공 시 'TITAN STOMP' 콤보 랭크 표시")

	# 정리 (Rule 3)
	stage.queue_free()
	dummy_enemy.queue_free()
	player.queue_free()
	arena.queue_free()
	await process_frame
	await process_frame

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
	print(">>> ADVANCED EXPANSION VERIFICATION: %d CHECKS | %d FAILURES <<<" % [total_checks, total_failures])
	print("========================================================================\n")
	quit(0 if total_failures == 0 else 1)
