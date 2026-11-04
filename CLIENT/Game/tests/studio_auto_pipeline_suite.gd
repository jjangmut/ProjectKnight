extends SceneTree
## JUNYPAPA STUDIO — 자율형 3대 에이전트 통합 분석·검증·피드백 파이프라인 (Autonomous Studio Pipeline Suite)
## - 15초 내장 워치독 타이머 탑재 (User Rule 3 준수)
## - [Agent 1: 기획·밸런스 에이전트] AX 마스터 데이터 정합성, 코요테 타임/선입력 버퍼, 유물 5종 & 성소 강화 런타임 연동 검증
## - [Agent 2: 그래픽·테크니컬 아트 에이전트] Stage 1~5 HDR Glow/Fog/부유 파티클, 28종 스프라이트 셀 침범 0건, 보스/플레이어 3D VFX 검증
## - [Agent 3: 빌드 & QA 에이전트] 캠페인/UI 런타임 시뮬레이션 및 빌드 산출물(APK/EXE) 상태 점검 & 승인 게이트 리포트 출력

const AXDataRegistryClass = preload("res://scripts/data/ax_data_registry.gd")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SpriteInspectorScene = preload("res://scenes/ui/SpriteInspectorTool.tscn")
const TitleScreenScene = preload("res://scenes/ui/TitleScreen.tscn")
const CampfireShopClass = preload("res://scripts/ui/campfire_shop.gd")
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

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	create_timer(15.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] studio_auto_pipeline_suite.gd exceeded 15.0s!")
		quit(1)
	)
	_run_studio_pipeline.call_deferred()


func check(condition: bool, agent_tag: String, message: String) -> void:
	checks += 1
	if condition:
		print("  [%s PASS] %s" % [agent_tag, message])
	else:
		failures += 1
		printerr("  [%s FAIL] %s" % [agent_tag, message])


func _run_studio_pipeline() -> void:
	print("\n========================================================================")
	print(">>> JUNYPAPA STUDIO : AUTONOMOUS 3-AGENT QUALITY PIPELINE START <<<")
	print("========================================================================")

	# ==========================================================================
	# [AGENT 1] 기획 & 밸런스 에이전트 (DESIGN & BALANCE DIRECTOR)
	# ==========================================================================
	print("\n--- [AGENT 1: DESIGN & BALANCE] AX Data, Input Buffering & Relics Audit ---")
	var ax_data: Dictionary = AXDataRegistryClass.load_ax_data()
	check(not ax_data.is_empty(), "DESIGN", "AX Master Data JSON loaded cleanly")

	# Verify all Boss script_path and sprite_sheet references in AX Data exist on disk
	var bosses_arr: Array = ax_data.get("bosses", [])
	check(bosses_arr.size() == 5, "DESIGN", "AX Data defines all 5 stage bosses")
	for b in bosses_arr:
		var sp: String = b.get("script_path", "")
		var tex: String = b.get("sprite_sheet", "")
		check(ResourceLoader.exists(sp), "DESIGN", "Boss '%s' script_path exists (%s)" % [b.get("id", ""), sp])
		check(ResourceLoader.exists(tex), "DESIGN", "Boss '%s' sprite_sheet exists (%s)" % [b.get("id", ""), tex])

	# Verify Player Input Buffering, Coyote Time & Relic Passive Mechanics
	var test_arena := Node3D.new()
	root.add_child(test_arena)
	var player := SideQVPlayerClass.new()
	test_arena.add_child(player)
	await process_frame

	check(is_equal_approx(player.COYOTE_TIME, 0.12), "DESIGN", "Player Coyote Time is 0.12s")
	check(is_equal_approx(player.JUMP_BUFFER_TIME, 0.14), "DESIGN", "Player Jump Input Buffer is 0.14s")
	check(is_equal_approx(player.ATTACK_BUFFER_TIME, 0.12), "DESIGN", "Player Attack Input Buffer is 0.12s")
	check(player.max_hp == 8 and player.current_attack_damage == 2, "DESIGN", "Player baseline stats intact (8 HP, 2 DMG)")

	# Test Relic Grants (Stage 2 Shadow Cloak, Stage 3 Piercing Quiver, Stage 4 Titan Pauldrons, Stage 5 Abyssal Crown)
	player.grant_relic("shadow_cloak")
	check(player.move_speed_x > 7.5 and player.dash_speed > 14.0, "DESIGN", "Relic [shadow_cloak] boosts move_speed_x (%.2f) and dash_speed (%.2f)" % [player.move_speed_x, player.dash_speed])

	player.grant_relic("wind_quiver")
	check(player.has_relic("piercing_quiver") and player.has_relic("wind_quiver"), "DESIGN", "Relic [wind_quiver / piercing_quiver] alias synced")
	player._fire_sword_beam()
	var fired_beam := test_arena.get_node_or_null("SideQVSwordBeam_Finisher")
	check(fired_beam != null and fired_beam.pierce_count == 1 and is_equal_approx(fired_beam.max_range, 33.6), "DESIGN", "Relic [wind_quiver] grants SwordBeam +40% range (33.6m) and +1 pierce")

	player.grant_relic("titan_pauldrons")
	check(player.max_hp == 9, "DESIGN", "Relic [titan_pauldrons / golem_pauldrons] increases max_hp to 9")
	player._trigger_titan_landing_shockwave()
	var landing_ring := test_arena.get_node_or_null("TitanLandingShockwave3D")
	check(landing_ring != null, "DESIGN", "Relic [titan_pauldrons] spawns 3D landing ground-slam shockwave")

	player.grant_relic("abyssal_crown")
	check(player.current_attack_damage == 3, "DESIGN", "Relic [abyssal_crown] increases base attack damage to 3")

	# Verify 3 Runic Engravings (Vampiric Edge, Thunder Step, Aegis Reflect)
	check(SaveManagerClass.RUNIC_ENGRAVINGS.size() == 3, "DESIGN", "SaveManager defines all 3 Runic Engravings")
	player.grant_engraving("vampiric_edge")
	player.grant_engraving("thunder_step")
	player.grant_engraving("aegis_reflect")
	check(player.has_engraving("vampiric_edge") and player.has_engraving("thunder_step") and player.has_engraving("aegis_reflect"), "DESIGN", "Player loaded all 3 Runic Engravings")

	# Test Thunder Step dash spark
	player.start_dash()
	var thunder_spark := test_arena.get_node_or_null("ThunderStepSpark3D")
	check(thunder_spark != null, "DESIGN", "Runic [thunder_step] spawns 3D ThunderStepSpark3D on dash")

	# Test Vampiric Edge HP heal on combo 3 finisher
	player.current_hp = 5
	player.combo_step = 3
	player.vampiric_cooldown = 0.0
	player._spawn_vampiric_heal_vfx(player.global_position)
	var v_aura := test_arena.get_node_or_null("VampiricHealAura3D")
	check(v_aura != null, "DESIGN", "Runic [vampiric_edge] spawns 3D VampiricHealAura3D")

	# Test Aegis Reflect burst VFX
	player._spawn_aegis_reflect_vfx(player.global_position)
	var a_burst := test_arena.get_node_or_null("AegisReflectBurst3D")
	check(a_burst != null, "DESIGN", "Runic [aegis_reflect] spawns 3D AegisReflectBurst3D on parry reflect")

	# Verify Balanced Boss HP & Reward Curves
	var expected_boss_hp := { "boss_commander": 24, "boss_beast_chieftain": 28, "boss_crossbow_commander": 30, "boss_golem_guardian": 34, "boss_abyssal_arbiter": 38 }
	for b in bosses_arr:
		var bid: String = b.get("id", "")
		var hp: int = int(b.get("hp", 0))
		check(hp == expected_boss_hp.get(bid, -1), "DESIGN", "Boss '%s' HP curve verified (%d HP)" % [bid, hp])

	var stages_arr: Array = ax_data.get("stages", [])
	var expected_rewards := [20, 25, 30, 35, 50]
	for i in range(stages_arr.size()):
		var stg_info: Dictionary = stages_arr[i]
		var reward: int = int(stg_info.get("clear_shard_reward", 0))
		check(reward == expected_rewards[i], "DESIGN", "Stage %d shard reward curve verified (+%d Shards)" % [i + 1, reward])

	# 5대 보스 체간(Poise) 스탯 무결성 검증
	var b1 := SideQVBossClass.new()
	var b2 := BeastChieftainClass.new()
	var b3 := CrossbowCmdClass.new()
	var b4 := GolemGuardianClass.new()
	var b5 := AbyssalArbiterClass.new()
	check(b1.max_poise == 12 and b2.max_poise == 14 and b3.max_poise == 12 and b4.max_poise == 16 and b5.max_poise == 18, "DESIGN", "5 Bosses Poise & Groggy balance integrity verified (12/14/12/16/18)")
	b1.free()
	b2.free()
	b3.free()
	b4.free()
	b5.free()

	# ==========================================================================
	# [AGENT 2] 그래픽 & 테크니컬 아트 에이전트 (GRAPHICS & VFX DIRECTOR)
	# ==========================================================================
	print("\n--- [AGENT 2: GRAPHICS & VFX] 3D Combat VFX, Stage Atmospherics & 28 Sprites ---")
	player._trigger_parry_flash()
	var parry_ring := test_arena.get_node_or_null("ParryShockwaveRing3D")
	check(parry_ring != null, "GRAPHICS", "Just Parry spawns 3D Golden-Cyan ParryShockwaveRing3D")

	player._spawn_hit_impact_vfx(Vector3.ZERO, true)
	var hit_spark := test_arena.get_node_or_null("MeleeHitImpact3D")
	check(hit_spark != null, "GRAPHICS", "Melee hit spawns 3D HDR MeleeHitImpact3D burst")

	# 3D 플로팅 데미지 텍스트 팝업 검증
	GameFeelManager.damage_popup_3d(test_arena, player.global_position, "16", Color.GOLD)
	await process_frame
	var has_damage_pop := test_arena.get_node_or_null("FloatingDamage3D") != null or test_arena.get_node_or_null("FloatingDamage3D_Direct") != null
	check(has_damage_pop, "GRAPHICS", "3D Floating Billboard Damage Popup verified")

	# 대시 3D 네온 잔상 아프터이미지 검증
	player.start_dash()
	await process_frame
	check(test_arena.get_node_or_null("DashGhost3D") != null, "GRAPHICS", "Dash 3D Neon Ghost Afterimage verified")

	# 할로우 나이트 스타일 공중 포고 바운스 (Pogo Bounce) 충격파 링 & 수직 반동 검증
	player.velocity.y = -5.0
	player._execute_pogo_bounce()
	var pogo_ring := test_arena.get_node_or_null("PogoShockwaveRing3D")
	check(pogo_ring != null and player.velocity.y > 0.0, "GRAPHICS", "Hollow Knight Air Pogo Shockwave Ring & Vertical Recoil verified")

	# 공중 급강하 스톰프 다이브 (Dive Slam) & 3D 대지 충격파 검증
	player.global_position = Vector3(0.0, 3.5, 0.0)
	player.start_dive_slam()
	player.global_position.y = 0.0
	player._execute_dive_slam_landing()
	await process_frame
	check(test_arena.get_node_or_null("DiveShockwaveRing3D") != null, "GRAPHICS", "Air Dive Slam Ground Stomp Shockwave Ring verified")

	var boss1 := SideQVBossClass.new()
	test_arena.add_child(boss1)
	await process_frame
	boss1._execute_quake_ring()
	check(test_arena.get_node_or_null("DangerTelegraphRing3D") != null, "GRAPHICS", "Stage 1 Boss Danger Telegraph Ring verified")
	await create_timer(0.4).timeout
	var quake_ring := test_arena.get_node_or_null("QuakeShockwaveRing3D")
	check(quake_ring != null, "GRAPHICS", "Stage 1 Boss Quake Ring spawns visible 3D QuakeShockwaveRing3D")

	# 다이내믹 카메라 전방 Lookahead & 듀얼 보스 프레이밍 검증
	var cam := SideQVCameraClass.new()
	test_arena.add_child(cam)
	boss1.global_position = Vector3(10.0, 0.0, 0.0)
	cam.target = player
	cam.boss_target = boss1
	cam._physics_process(0.1)
	check(cam.fov > 42.0 and cam.base_pos.x != 0.0, "GRAPHICS", "Dynamic Camera Lookahead & Dual Boss Framing verified")
	cam.queue_free()

	# 보스 위험 공격 전조 비콘 링 & 그로기 어지럼 헤일로 연출 검증
	boss1._show_danger_telegraph(0.3)
	boss1._spawn_groggy_halo()
	check(test_arena.get_node_or_null("DangerTelegraphRing3D") != null and boss1.get_node_or_null("GroggyHalo3D") != null, "GRAPHICS", "Boss Danger Telegraph Ring & Groggy Stagger Halo verified")
	await process_frame
	await process_frame

	test_arena.queue_free()
	await process_frame

	# Audit all 5 Stages for WorldEnvironment HDR Glow, Fog, and Floating Particles
	var expected_particles := [
		"CitadelDustEmbers",
		"ForestFireflies",
		"BastionArcaneSpores",
		"EmberParticles3D",
		"AbyssalVoidParticles",
	]
	for i in range(STAGE_SCENES.size()):
		var stg_scene := load(STAGE_SCENES[i]) as PackedScene
		var stg := stg_scene.instantiate()
		root.add_child(stg)
		await process_frame

		var wenv := stg.get_node_or_null("WorldEnvironment3D") as WorldEnvironment
		check(wenv != null and wenv.environment != null, "GRAPHICS", "Stage %d has WorldEnvironment3D" % (i + 1))
		if wenv != null and wenv.environment != null:
			check(wenv.environment.glow_enabled, "GRAPHICS", "Stage %d has HDR Glow enabled" % (i + 1))
			check(wenv.environment.fog_enabled, "GRAPHICS", "Stage %d has Atmospheric Depth Fog enabled" % (i + 1))

		var pnode := stg.get_node_or_null(expected_particles[i]) as CPUParticles3D
		check(pnode != null, "GRAPHICS", "Stage %d has floating 3D particles (%s)" % [i + 1, expected_particles[i]])

		stg.queue_free()
		await process_frame

	# Verify all 28 Sprites via SpriteInspectorTool
	var inspector := SpriteInspectorScene.instantiate()
	root.add_child(inspector)
	await process_frame
	var total_bleeds: int = 0
	for entry in inspector.SPRITE_CATALOG:
		inspector.select_sprite_by_id(entry["id"])
		total_bleeds += inspector.get_current_sheet_bleed_count()
	check(inspector.get_catalog_size() == 28 and total_bleeds == 0, "GRAPHICS", "All 28 character/minion/boss sprites verified with 0 cell bleeds")
	inspector.queue_free()
	await process_frame

	# ==========================================================================
	# [AGENT 3] 빌드 & QA 총괄 에이전트 (BUILD & QA INSPECTOR)
	# ==========================================================================
	print("\n--- [AGENT 3: QA & BUILD] Title Lobby, Runtime Simulation & Build Artifacts ---")
	var title := TitleScreenScene.instantiate()
	root.add_child(title)
	await process_frame
	check(title.btn_new_game != null and title.btn_ax_data != null and title.btn_sprite_studio != null, "QA", "TitleScreen operational with Campaign, AX Codex, and Sprite Studio buttons")
	title.queue_free()
	await process_frame

	var shop := CampfireShopClass.new()
	root.add_child(shop)
	await process_frame
	check(shop._vamp_btn != null and shop._thunder_btn != null and shop._aegis_btn != null, "QA", "CampfireShop operational with all 3 Runic Engraving buttons")
	shop.queue_free()
	await process_frame

	# 실시간 콤보 HUD 및 5콤보 달성 시 영혼 파편 보상 검증
	var stage1 := SideQVStageBaseClass.new()
	stage1.stage_index = 1
	root.add_child(stage1)
	await process_frame
	var initial_shards: int = SaveManagerClass.get_shards()
	for i in range(5):
		stage1._on_player_enemy_hit(null, 2, false)
	check(stage1.current_combo_count == 5 and stage1.combo_label != null and stage1.combo_label.text == "5 HITS", "QA", "In-game Combo Hit Counter & HUD rank updates properly")
	check(SaveManagerClass.get_shards() == initial_shards + 1, "QA", "5-hit combo milestone rewards +1 Soul Shard")
	stage1.queue_free()
	await process_frame
	await process_frame

	var apk_path := ProjectSettings.globalize_path("res://builds/android/ProjectKnight.apk")
	var exe_path := ProjectSettings.globalize_path("res://builds/windows/ProjectKnight.exe")
	check(FileAccess.file_exists(apk_path), "QA", "Android APK build artifact verified (%s)" % apk_path)
	check(FileAccess.file_exists(exe_path), "QA", "Windows EXE build artifact verified (%s)" % exe_path)

	print("\n========================================================================")
	print("STUDIO PIPELINE SUMMARY: %d CHECKS | %d FAILURES" % [checks, failures])
	print("========================================================================\n")
	var audio_mgr := root.get_node_or_null("AudioManager")
	if audio_mgr != null:
		if audio_mgr.has_method("stop_music"):
			audio_mgr.stop_music()
		if "_streams" in audio_mgr:
			audio_mgr._streams.clear()
		if "_players" in audio_mgr:
			for p in audio_mgr._players:
				if is_instance_valid(p):
					p.stop()
					p.stream = null
		if "_bgm_player" in audio_mgr and is_instance_valid(audio_mgr._bgm_player):
			audio_mgr._bgm_player.stop()
			audio_mgr._bgm_player.stream = null
		audio_mgr.queue_free()
	var am_script := load("res://scripts/audio/audio_manager.gd") as GDScript
	if am_script != null:
		am_script._instance = null
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
