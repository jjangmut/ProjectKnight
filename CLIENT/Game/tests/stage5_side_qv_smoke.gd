extends SceneTree
## Stage 5 사이드 쿼터뷰(SideQVStage5) 및 최종 보스(SideQVAbyssalArbiter) 검증 테스트 스위트
## 검증 항목:
## 1. Stage 5 씬 인스턴스화, 메타데이터(stage_index=5, stage_title="침묵의 성채") 확인
## 2. 딥 바이올렛 & 보이드 퍼플 앰비언스 (Color(0.22, 0.12, 0.38)), 3D HDR Glow 및 포그
## 3. 검은 대리석 옥좌 홀 (Dark Obsidian Floor & Stepped Throne Dais & Blood Rune Halo)
## 4. 플레이어 및 사이드 쿼터뷰 카메라 정상 정렬
## 5. Wave 1: 엘리트 심연 기사 미니언 2기 스폰 및 처치 후 Wave 2 전환
## 6. Wave 2: 최종 보스 'SideQVAbyssalArbiter' 스폰 (2.6m 신장, 4x3 스프라이트 시트)
## 7. 심연 암흑 참격파 (Dark Crescent Wave) 사출 및 투사체 검증
## 8. 그림자 텔레포트 기습 (Shadow Blink Strike) 배후 이동 검증
## 9. 2페이즈 심연의 심판 폭풍 (Abyssal Judgment Storm) 및 전방위 보이드 펄스 검증
## 10. 피격/그로기/저스트 패링 스턴/상호 밀림 방지/최종 클리어 연동 검증

var checks_passed: int = 0
var checks_failed: int = 0

# Dictionary container to reliably capture lambda signal callbacks in GDScript
var test_flags: Dictionary = {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] ", description)
		checks_passed += 1
	else:
		printerr("  [FAIL] ", description)
		checks_failed += 1


func _initialize() -> void:
	# 15초 내장 워치독 타이머 (비정상 지연 및 멈춤 원천 차단)
	create_timer(15.0).timeout.connect(func():
		printerr("\n[TIMEOUT] 15s Watchdog timer expired! Test aborted.")
		quit(1)
	)
	_run_tests.call_deferred()


func _run_tests() -> void:
	print("\n==================================================")
	print(">>> RUNNING: stage5_side_qv_smoke.gd <<<")
	print("==================================================")

	# -------------------------------------------------------------------------
	# Test 1: Stage 5 Scene Load & Metadata
	# -------------------------------------------------------------------------
	print("\n--- Test 1: Stage 5 Scene Load & Metadata ---")
	var scene_path := "res://scenes/side_quarter_view/SideQVStage5.tscn"
	_check(ResourceLoader.exists(scene_path), "SideQVStage5.tscn scene file exists")

	var stage_res := load(scene_path) as PackedScene
	_check(stage_res != null, "SideQVStage5 scene loaded successfully")

	var stage = stage_res.instantiate()
	_check(stage != null, "SideQVStage5 instantiated successfully")
	root.add_child(stage)
	await process_frame
	await process_frame

	_check(int(stage.get("stage_index")) == 5, "Stage index is 5")
	_check(String(stage.get("stage_title")) == "침묵의 성채", "Stage title is '침묵의 성채'")
	_check(float(stage.get("arena_width")) == 38.0, "Arena width is 38.0m")
	_check(float(stage.get("arena_depth")) == 12.0, "Arena depth is 12.0m")

	# -------------------------------------------------------------------------
	# Test 2: 3D Environment & Void Purple Ambience
	# -------------------------------------------------------------------------
	print("\n--- Test 2: 3D Environment & Void Purple Ambience ---")
	var world_env := stage.get_node_or_null("WorldEnvironment3D") as WorldEnvironment
	_check(world_env != null, "WorldEnvironment3D exists in Stage 5")
	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		_check(env.ambient_light_color.is_equal_approx(Color(0.22, 0.12, 0.38, 1.0)), "Ambient light color is Deep Violet & Void Purple: Color(0.22, 0.12, 0.38)")
		_check(env.ambient_light_energy >= 1.2, "Ambient light energy is >= 1.2")
		_check(env.glow_enabled == true, "3D HDR Glow is enabled")
		_check(env.fog_enabled == true, "Void atmospheric fog is enabled")

	var sunlight := stage.get_node_or_null("VoidSunLight3D") as DirectionalLight3D
	_check(sunlight != null, "VoidSunLight3D directional light exists")
	if sunlight != null:
		_check(sunlight.shadow_enabled == true, "Sunlight real-time shadows enabled")

	# -------------------------------------------------------------------------
	# Test 3: Dark Obsidian Floor & Throne Podium Architecture
	# -------------------------------------------------------------------------
	print("\n--- Test 3: Dark Obsidian Floor & Throne Architecture ---")
	var floor_node := stage.get_node_or_null("DarkObsidianFloor") as CSGBox3D
	_check(floor_node != null, "DarkObsidianFloor CSGBox3D exists")
	if floor_node != null:
		_check(floor_node.use_collision == true, "Obsidian floor has collision enabled")
		_check(floor_node.size.x == 38.0, "Floor width matches arena_width (38.0m)")

	var throne_podium: Node = stage.get_node_or_null("ThronePodium")
	_check(throne_podium != null, "ThronePodium dais exists in background")
	var blood_halo: Node = throne_podium.get_node_or_null("ThroneBloodRuneHalo") if throne_podium != null else null
	_check(blood_halo != null, "ThroneBloodRuneHalo pulsing halo exists behind throne")

	var runic_seal: Node = stage.get_node_or_null("AbyssalRunicSeal")
	_check(runic_seal != null, "Central AbyssalRunicSeal exists on obsidian floor")

	# -------------------------------------------------------------------------
	# Test 4: Player & SideQV Camera Setup
	# -------------------------------------------------------------------------
	print("\n--- Test 4: Player & SideQV Camera Setup ---")
	var player_node: Node3D = stage.get("player")
	_check(player_node != null, "Player (SideQVPlayer) spawned")
	_check(stage.get("camera") != null, "SideQV Camera spawned and tracking player")
	_check(stage.get("mobile_controls") != null, "Mobile UI controls CanvasLayer spawned")
	if player_node != null:
		# Ensure player survives testing damage from lethal boss patterns
		player_node.set("max_hp", 100)
		player_node.set("current_hp", 100)

	# -------------------------------------------------------------------------
	# Test 5: Wave 1 - Elite Abyssal Knight Minions
	# -------------------------------------------------------------------------
	print("\n--- Test 5: Wave 1 Elite Minions Encounter ---")
	_check(int(stage.get("current_wave")) == 1, "Initial wave is Wave 1")
	var enemies_list = stage.get("enemies")
	_check(enemies_list.size() == 2, "Wave 1 has 2 elite minion enemies spawned")
	var minion_1: Node = enemies_list[0]
	var minion_2: Node = enemies_list[1]
	_check(minion_1 != null and minion_2 != null, "Both enemies are valid minion instances")
	if minion_1 != null:
		_check(int(minion_1.get("max_hp")) == 6, "Elite knight minion HP is 6 (Enhanced endurance)")
		_check(float(minion_1.get("move_speed")) == 4.0, "Elite knight speed is 4.0 m/s")
		_check(minion_1.get_node_or_null("EliteVoidRing") != null, "Elite knight has EliteVoidRing under feet")

	# Defeat Wave 1 minions -> triggers automated wave 2 transition
	print("Defeating Wave 1 minions...")
	minion_1.call("receive_hit", 6, Vector3.ZERO)
	minion_2.call("receive_hit", 6, Vector3.ZERO)
	await process_frame
	await process_frame

	_check(enemies_list.is_empty(), "Wave 1 enemies cleared")

	# -------------------------------------------------------------------------
	# Test 6: Wave 2 - SideQVAbyssalArbiter Final Boss Spawn
	# -------------------------------------------------------------------------
	print("\n--- Test 6: Wave 2 Abyssal Arbiter Boss Spawn ---")
	# Wait for natural 1.2s wave transition timer in SideQVStageBase
	await create_timer(1.35).timeout

	_check(int(stage.get("current_wave")) == 2, "Advanced to Wave 2 (Boss Encounter)")
	var arbiter: Node = stage.get("active_boss")
	_check(arbiter != null, "active_boss is assigned")

	if arbiter != null:
		_check(int(arbiter.get("max_hp")) == 30, "Abyssal Arbiter max_hp is 30")
		_check(int(arbiter.get("current_hp")) == 30, "Abyssal Arbiter current_hp starts at 30")
		_check(arbiter.is_in_group("enemies"), "Arbiter is in 'enemies' group")
		_check(arbiter.is_in_group("bosses"), "Arbiter is in 'bosses' group")

		var b_sprite := arbiter.get_node_or_null("ArbiterSprite3D") as Sprite3D
		_check(b_sprite != null, "ArbiterSprite3D node exists")
		if b_sprite != null:
			_check(b_sprite.hframes == 4 and b_sprite.vframes == 3, "Sprite3D is 4x3 sheet (12 frames)")
			_check(is_equal_approx(b_sprite.pixel_size, 0.008705), "Sprite3D pixel_size is 0.008705 (~2.6m tall)")
			_check(b_sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Billboard mode is FIXED_Y")

		var b_col := arbiter.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_check(b_col != null, "CollisionShape3D exists on Arbiter")

	# Verify Boss Health Bar UI
	var mobile_ui: CanvasLayer = stage.get("mobile_controls")
	var boss_bar: Node = mobile_ui.get_node_or_null("BossHealthBarUI") if mobile_ui != null else null
	_check(boss_bar != null, "BossHealthBarUI added to mobile controls UI")

	# -------------------------------------------------------------------------
	# Test 7: Pattern 1 - Dark Crescent Wave (심연 암흑 참격파)
	# -------------------------------------------------------------------------
	print("\n--- Test 7: Pattern 1 - Dark Crescent Wave ---")
	test_flags["wave_spawned"] = false
	test_flags["wave_damage"] = 0
	test_flags["wave_speed"] = 0.0
	test_flags["has_core"] = false
	test_flags["has_aura"] = false
	test_flags["has_particles"] = false

	arbiter.dark_crescent_fired.connect(func(w: Node3D):
		test_flags["wave_spawned"] = true
		test_flags["wave_damage"] = int(w.get("damage"))
		test_flags["wave_speed"] = float(w.get("speed"))
		test_flags["has_core"] = (w.get_node_or_null("AbyssalCoreMesh") != null)
		test_flags["has_aura"] = (w.get_node_or_null("VoidAuraMesh") != null)
		test_flags["has_particles"] = (w.get_node_or_null("VoidTrailParticles") != null)
	)

	arbiter.call("_execute_dark_crescent_wave")
	await create_timer(0.45).timeout

	_check(bool(test_flags.get("wave_spawned", false)), "Dark crescent fired signal received")
	_check(int(test_flags.get("wave_damage", 0)) == 2, "Dark Crescent Wave damage is 2")
	_check(float(test_flags.get("wave_speed", 0.0)) == 13.5, "Dark Crescent Wave speed is 13.5 m/s")
	_check(bool(test_flags.get("has_core", false)), "Dark Crescent Wave has AbyssalCoreMesh")
	_check(bool(test_flags.get("has_aura", false)), "Dark Crescent Wave has VoidAuraMesh")
	_check(bool(test_flags.get("has_particles", false)), "Dark Crescent Wave has VoidTrailParticles")

	# -------------------------------------------------------------------------
	# Test 8: Pattern 2 - Shadow Blink Strike (그림자 텔레포트 기습)
	# -------------------------------------------------------------------------
	print("\n--- Test 8: Pattern 2 - Shadow Blink Strike ---")
	var initial_x: float = arbiter.global_position.x
	test_flags["blink_occurred"] = false

	arbiter.teleported.connect(func(_pos: Vector3):
		test_flags["blink_occurred"] = true
	)

	arbiter.call("_execute_shadow_blink_strike")
	await create_timer(0.35).timeout

	_check(bool(test_flags.get("blink_occurred", false)), "Shadow blink strike teleported signal received")
	_check(arbiter.global_position.x != initial_x, "Arbiter repositioned behind player via shadow blink")

	# -------------------------------------------------------------------------
	# Test 9: Pattern 3 - Phase 2 Abyssal Judgment Storm (심연의 심판 폭풍)
	# -------------------------------------------------------------------------
	print("\n--- Test 9: Pattern 3 - Phase 2 Abyssal Judgment Storm ---")
	test_flags["phase_changed"] = false
	test_flags["storm_triggered"] = false

	arbiter.phase_changed.connect(func(p: int):
		if p == 2:
			test_flags["phase_changed"] = true
	)
	arbiter.judgment_storm_triggered.connect(func():
		test_flags["storm_triggered"] = true
	)

	# Deal damage to trigger Phase 2 (HP <= 50%, i.e. current_hp <= 15)
	arbiter.call("receive_hit", 15, Vector3.ZERO)
	await process_frame

	_check(int(arbiter.get("current_hp")) == 15, "Arbiter HP reduced to 15 (50%)")
	_check(int(arbiter.get("current_phase")) == 2, "Arbiter transitioned to Phase 2")
	_check(bool(test_flags.get("phase_changed", false)), "phase_changed(2) signal emitted")
	_check(float(arbiter.get("move_speed")) == 5.2, "Phase 2 move_speed boosted to 5.2 m/s")
	_check(int(arbiter.get("wave_damage")) == 3, "Phase 2 wave_damage boosted to 3")
	var aura_ring: MeshInstance3D = arbiter.get("aura_ring_3d")
	_check(aura_ring != null and aura_ring.visible == true, "Phase 2 VoidAuraRing is visible")
	var enraged_tag: Label = stage.get("boss_enraged_tag")
	_check(enraged_tag != null and enraged_tag.visible == true, "UI Boss Enraged 2-Phase tag is visible")
	_check(bool(test_flags.get("storm_triggered", false)), "judgment_storm_triggered signal emitted")

	await create_timer(0.50).timeout

	# -------------------------------------------------------------------------
	# Test 10: Combat Mechanics (Parry Stun, Mutual Push Prevention, Clear)
	# -------------------------------------------------------------------------
	print("\n--- Test 10: Parry Stun, Push Prevention & Stage Defeat ---")
	# Test Parry Stun
	arbiter.call("apply_parry_stun", 2.0)
	_check(bool(arbiter.get("is_stunned")) == true, "Arbiter is stunned after apply_parry_stun")
	_check(arbiter.velocity == Vector3.ZERO, "Velocity is ZERO on parry clash")

	# Test Mutual Push Prevention
	arbiter.velocity = Vector3(-5.0, 0.0, 0.0)
	arbiter.global_position = player_node.global_position + Vector3(0.5, 0.0, 0.0)
	arbiter.call("_prevent_player_pushing")
	_check(arbiter.velocity.x >= -0.1, "Velocity clamped by _prevent_player_pushing to prevent overlap")

	# Test Boss Defeat & Stage Clear
	test_flags["boss_defeated"] = false
	test_flags["stage_cleared"] = false

	arbiter.boss_defeated.connect(func(_b):
		test_flags["boss_defeated"] = true
	)
	stage.stage_cleared.connect(func():
		test_flags["stage_cleared"] = true
	)

	# Set short fanfare delay for fast headless test execution
	stage.set("clear_fanfare_delay", 0.25)

	arbiter.call("receive_hit", 20, Vector3.ZERO)
	await process_frame
	await process_frame

	_check(int(arbiter.get("current_hp")) <= 0, "Arbiter HP is 0 or less")
	_check(bool(test_flags.get("boss_defeated", false)), "boss_defeated signal emitted")
	_check(bool(stage.get("is_stage_finished")) == true, "Stage is marked finished")

	await create_timer(0.55).timeout
	_check(bool(test_flags.get("stage_cleared", false)), "stage_cleared signal emitted upon fanfare completion")

	# -------------------------------------------------------------------------
	# Final Results Summary
	# -------------------------------------------------------------------------
	print("\n==================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks_passed, checks_failed])
	print("==================================================")

	if checks_failed == 0:
		print(">>> STAGE 5 SIDE QV SMOKE: ALL PASS! <<<\n")
		quit(0)
	else:
		printerr(">>> STAGE 5 SIDE QV SMOKE: FAILED! <<<\n")
		quit(1)
