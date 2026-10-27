extends SceneTree
## Project Knight - Master Campaign QA Inspection Agent Suite
## (캠페인 종합 검수 에이전트: side_qv_full_campaign_qa_agent.gd)
##
## 종합 검증 항목:
## 1. 15초 내장 워치독 타이머 탑재 (User Rule 3 준수)
## 2. SideQVCampaign (SideQVCampaign.tscn) 인스턴스화 및 5개 스테이지 연속 진행
## 3. Stage 1 (성문 외곽): 씬 로드, 3D 환경, 플레이어/카메라, 미니언 2기 처치, 사령관 보스 스폰,
##    12m/s 방패 돌진 패링, 보스 처치 후 stage_cleared 및 승계
## 4. Stage 2 (야수숲): Stage 2 로드, 에메랄드 숲 환경 (Color(0.2, 0.45, 0.25)), 반딧불이 파티클,
##    돌진 야수 미니언 처치, 야수 추장 스폰, 도약 덮치기/발톱 참격 확인, 보스 처치 후 stage_cleared
## 5. Stage 3 (무너진 성벽): Stage 3 로드, 비전 잔해 및 부유 석편 환경 확인, 석궁병 미니언 처치,
##    석궁 사령관 스폰, 3방향 폭발 볼트/마름쇠 트랩 확인, 보스 처치 후 stage_cleared
## 6. Stage 4 (돌의 성소): Stage 4 로드, 용암 제단 및 거석 기둥 6개 환경 확인, 헤비 골렘 미니언 처치,
##    고대 골렘 수호자 스폰, 그라운드 슬램/스피닝 라리아트 확인, 보스 처치 후 stage_cleared
## 7. Stage 5 (침묵의 성채): Stage 5 로드, 흑요석 대리석 옥좌 홀 환경 확인, 엘리트 심연 기사 처치,
##    심연의 중재자 최종 보스 스폰, 암흑 초승달 참격파/그림자 텔레포트 확인, 최종 격파 후
##    campaign_completed 시그널 및 캠페인 승리 패널 (CampaignVictoryPanel) 검증
## 8. 5개 스테이지 전반에 걸친 공통 핵심 품질 검증:
##    - 카메라 뷰 앵글 (Pitch -32.0도, Yaw 0.0도 수평 뷰 엄수, Roll 0.0도)
##    - 플레이어 스프라이트 피봇 무지터 (Zero-Jitter, 발바닥 Y=0.0 고정)
##    - 몬스터/보스 실시간 플레이어 정면 응시 (flip_h 실시간 연동)
##    - 몬스터/보스와 플레이어 간 상호 밀림 방지 접촉 정지 (_prevent_player_pushing)
##    - 수직 황금 초승달 참격 검기파 (SideQVSwordBeam) 사출 및 3D 메쉬 검증

const CampaignScene: PackedScene = preload("res://scenes/side_quarter_view/SideQVCampaign.tscn")

const SideQVCampaignClass = preload("res://scripts/side_quarter_view/side_qv_campaign.gd")
const SideQVStageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const SideQVStage1Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_1.gd")
const SideQVStage2Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_2.gd")
const SideQVStage3Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_3.gd")
const SideQVStage4Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_4.gd")
const SideQVStage5Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_5.gd")

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const SideQVSwordBeamClass = preload("res://scripts/side_quarter_view/side_qv_sword_beam.gd")

const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossCommanderClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

const SideQVBeastMinionClass = preload("res://scripts/side_quarter_view/enemies/side_qv_beast_minion.gd")
const SideQVBeastChieftainClass = preload("res://scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd")

const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVCrossbowCommanderClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")

const SideQVGolemMinionClass = preload("res://scripts/side_quarter_view/side_qv_golem_minion.gd")
const SideQVGolemGuardianClass = preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")

const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVAbyssalArbiterClass = preload("res://scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd")

var checks: int = 0
var failures: int = 0

var campaign: SideQVCampaign = null
var stage_loaded_flags: Array[bool] = [false, false, false, false, false]
var stage_cleared_events: Dictionary = {
	0: false,
	1: false,
	2: false,
	3: false,
	4: false
}
var campaign_completed_flag: bool = false


func _initialize() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	# 15초 워치독 안전 타이머 (User Rule 3 준수)
	var watchdog: SceneTreeTimer = create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("\n[WATCHDOG TIMEOUT] Master Campaign QA Agent exceeded 15.0s execution limit! Terminating.")
		quit(1)
	)

	_run_campaign_qa.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [QA-PASS] %s" % msg)
	else:
		failures += 1
		printerr("  [QA-FAIL] %s" % msg)


func _advance_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _wait_for_stage(idx: int) -> void:
	while not stage_loaded_flags[idx]:
		await physics_frame


func _verify_common_stage_invariants(stage: SideQVStageBase, s_num: int) -> void:
	# 1. 사이드 쿼터뷰 카메라 앵글
	var cam: SideQVCamera = stage.camera
	check(cam != null, "Stage %d: SideQVCamera attached" % s_num)
	if cam != null:
		check(is_equal_approx(cam.rotation_degrees.x, -32.0),
			"Stage %d: Camera Pitch is -32.0 deg (Got: %.2f deg)" % [s_num, cam.rotation_degrees.x])
		check(is_equal_approx(cam.rotation_degrees.y, 0.0),
			"Stage %d: Camera Yaw is strictly 0.0 deg (Side-View horizontal, Got: %.2f deg)" % [s_num, cam.rotation_degrees.y])
		check(is_equal_approx(cam.rotation_degrees.z, 0.0),
			"Stage %d: Camera Roll is 0.0 deg (Got: %.2f deg)" % [s_num, cam.rotation_degrees.z])

	# 2. 플레이어 스프라이트 피봇 무지터 & 발바닥 Y=0.0 고정
	var pl: SideQVPlayer = stage.player
	check(pl != null, "Stage %d: SideQVPlayer active" % s_num)
	if pl != null and pl.sprite_3d != null:
		check(is_zero_approx(pl.sprite_3d.position.x),
			"Stage %d: Player Sprite3D X is centered at 0.0 (Zero-Jitter, Got: %.4f)" % [s_num, pl.sprite_3d.position.x])
		check(is_equal_approx(pl.sprite_3d.position.y, 0.874),
			"Stage %d: Player Sprite3D anchors feet accurately at ground Y=0.0 (Got: %.4f)" % [s_num, pl.sprite_3d.position.y])

	# 3. 3D WorldEnvironment HDR Glow
	var world_env := stage.get_node_or_null("WorldEnvironment3D") as WorldEnvironment
	check(world_env != null and world_env.environment != null, "Stage %d: WorldEnvironment3D exists" % s_num)
	if world_env != null and world_env.environment != null:
		check(world_env.environment.glow_enabled, "Stage %d: 3D HDR Glow is enabled" % s_num)


func _run_campaign_qa() -> void:
	print("\n===================================================================")
	print(">>> START MASTER CAMPAIGN QA INSPECTION SUITE (5 STAGES FULL) <<<")
	print("===================================================================\n")

	# --- Campaign Instantiation ---
	print("--- Setup: Instantiating SideQVCampaign ---")
	campaign = CampaignScene.instantiate() as SideQVCampaign
	check(campaign != null, "SideQVCampaign instantiated successfully")
	check(campaign is SideQVCampaignClass, "Campaign instance inherits from SideQVCampaign")

	campaign.transition_delay = 0.15 # Fast transition for headless verification

	campaign.stage_transitioned.connect(func(idx: int):
		print("  >>> [CAMPAIGN-SIGNAL] stage_transitioned(%d) received <<<" % idx)
		if idx >= 0 and idx < stage_loaded_flags.size():
			stage_loaded_flags[idx] = true
		var st = campaign.current_stage_instance as SideQVStageBase
		if st != null:
			st.boss_wave_delay = 0.05
			st.clear_fanfare_delay = 0.1
			if st.player != null:
				st.player.max_hp = 100
				st.player.current_hp = 100
			st.stage_cleared.connect(func():
				stage_cleared_events[idx] = true
			)
	)

	campaign.campaign_completed.connect(func():
		print("  >>> [CAMPAIGN-SIGNAL] campaign_completed received! <<<")
		campaign_completed_flag = true
	)

	root.add_child(campaign)
	current_scene = campaign

	# ==============================================================================
	# STAGE 1 (성문 외곽 / Citadel Terrace Gate)
	# ==============================================================================
	print("\n-------------------------------------------------------------")
	print(">>> [STAGE 1] 검증: 성문 외곽 (Citadel Terrace Gate) <<<")
	print("-------------------------------------------------------------")
	await _wait_for_stage(0)
	await _advance_frames(5)

	var stage1 := campaign.current_stage_instance as SideQVStage1Class
	check(stage1 != null, "Stage 1 loaded and instantiated")
	check(stage1.stage_index == 1, "Stage 1 index is 1 (Got: %d)" % stage1.stage_index)
	check(stage1.stage_title == "성문 외곽", "Stage 1 title is '성문 외곽'")

	_verify_common_stage_invariants(stage1, 1)

	# 3D Environment Check
	var backdrop := stage1.get_node_or_null("PanoramicCastleBackdrop") as MeshInstance3D
	check(backdrop != null, "Stage 1 PanoramicCastleBackdrop exists")
	var sun_light := stage1.get_node_or_null("SunLight3D") as DirectionalLight3D
	check(sun_light != null and sun_light.shadow_enabled, "Stage 1 SunLight3D has shadows enabled")
	var floor_node := stage1.get_node_or_null("ArenaFloor") as CSGBox3D
	check(floor_node != null and floor_node.collision_layer == 4, "Stage 1 ArenaFloor is on collision layer 4")
	var braziers: Array[Node] = stage1.get_tree().get_nodes_in_group("stage_torches")
	check(braziers.size() == 4, "Stage 1 has 4 Castle Braziers spawned (Count: %d)" % braziers.size())

	# 수직 황금 초승달 참격 검기파 (SideQVSwordBeam) 사출 검증
	print("\n  [Stage 1 Action Inspection] Vertical Crescent Sword Wave 사출 검증")
	var beam_info := {
		"spawned": false,
		"core_is_array": false,
		"has_aura": false,
		"has_particles": false,
		"has_light": false
	}
	var beam_listener := func(b: Node3D):
		if b is SideQVSwordBeamClass:
			var s_beam := b as SideQVSwordBeamClass
			beam_info["spawned"] = true
			beam_info["core_is_array"] = (s_beam.core_mesh_inst != null and s_beam.core_mesh_inst.mesh is ArrayMesh)
			beam_info["has_aura"] = (s_beam.aura_mesh_inst != null)
			beam_info["has_particles"] = (s_beam.trail_particles != null)
			beam_info["has_light"] = (s_beam.beam_light != null)

	stage1.player.sword_beam_fired.connect(beam_listener)
	stage1.player.global_position = Vector3(-6.0, 0.1, -2.0)
	stage1.player.facing_dir_x = 1.0
	stage1.player.is_attacking = false
	stage1.player.attack_cooldown = 0.0
	stage1.player.combo_step = 2
	stage1.player.start_attack() # combo_step becomes 3, triggers _fire_sword_beam()
	await _advance_frames(4)
	stage1.player.sword_beam_fired.disconnect(beam_listener)

	check(beam_info["spawned"], "SideQVSwordBeam fired via combo finisher")
	check(beam_info["core_is_array"], "SideQVSwordBeam has vertical crescent ArrayMesh core")
	check(beam_info["has_aura"], "SideQVSwordBeam has outer golden energy aura shell")
	check(beam_info["has_particles"], "SideQVSwordBeam has golden spark trail particles")
	check(beam_info["has_light"], "SideQVSwordBeam has dynamic OmniLight3D")

	# Wave 1 Minions Check & Defeat
	print("\n  [Stage 1 Wave 1 Inspection]")
	check(stage1.current_wave == 1, "Stage 1 current_wave is 1")
	check(stage1.enemies.size() == 2, "Wave 1 spawned 2 enemies (Count: %d)" % stage1.enemies.size())

	var enemy1: SideQVEnemyClass = stage1.enemies[0] as SideQVEnemyClass
	check(enemy1 != null, "Minion 1 is SideQVEnemy")

	# 몬스터 정면 응시 flip_h 검증
	stage1.player.global_position = Vector3(-5.0, 0.1, 0.0)
	enemy1.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(enemy1.sprite_3d.flip_h == true, "Minion faces left towards player on the left")

	stage1.player.global_position = Vector3(5.0, 0.1, 0.0)
	enemy1.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(enemy1.sprite_3d.flip_h == false, "Minion faces right towards player on the right")

	# Eliminate Wave 1 Minions
	for m in stage1.enemies.duplicate():
		if is_instance_valid(m) and m.has_method("receive_hit"):
			m.receive_hit(20, Vector3.ZERO)

	await _advance_frames(8)

	# Wave 2 Boss Spawn
	print("\n  [Stage 1 Wave 2 Boss Inspection]")
	check(stage1.current_wave == 2, "Transitioned to Wave 2 (Boss Wave)")
	var boss1: SideQVBossCommanderClass = stage1.active_boss as SideQVBossCommanderClass
	check(boss1 != null, "Active boss is SideQVBossCommander")
	check(int(boss1.get("max_hp")) == 24, "Stage 1 Boss max HP is 24 (Got: 24)")
	check(float(boss1.get("charge_speed")) == 12.0, "Stage 1 Boss charge speed is 12.0 m/s")

	# Boss facing alignment
	stage1.player.global_position = Vector3(-4.0, 0.1, 0.0)
	boss1.global_position = Vector3(3.0, 0.1, 0.0)
	await _advance_frames(3)
	check(boss1.sprite_3d.flip_h == true, "Boss faces left towards player")

	stage1.player.global_position = Vector3(5.0, 0.1, 0.0)
	boss1.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(boss1.sprite_3d.flip_h == false, "Boss faces right towards player")

	# Boss Parry Stun & Mutual Push Prevention
	boss1.apply_parry_stun(1.5)
	check(boss1.is_stunned == true, "Stage 1 Boss parry stunned successfully")
	check(boss1.velocity == Vector3.ZERO, "Stage 1 Boss velocity halted on parry")

	# Mutual Push Prevention (Boss moving towards player halted)
	stage1.player.global_position = Vector3(-0.9, 0.1, 0.0)
	boss1.global_position = Vector3(0.0, 0.1, 0.0)
	boss1.velocity = Vector3(-5.0, 0.0, 0.0)
	boss1._prevent_player_pushing()
	check(absf(boss1.velocity.x) <= 0.1, "Stage 1 Boss _prevent_player_pushing clamps velocity")

	# Boss Defeat & Stage Clear Verification
	boss1.receive_hit(50, Vector3.ZERO)

	var s1_timer: float = 0.0
	while not stage_cleared_events[0] and s1_timer < 1.0:
		await physics_frame
		s1_timer += 1.0 / 60.0

	check(stage_cleared_events[0], "Stage 1 stage_cleared signal emitted")
	check(campaign.cleared_stages[0] == true, "Campaign marked Stage 1 as cleared")

	# ==============================================================================
	# STAGE 2 (야수숲 / Beastwood Forest Gorge)
	# ==============================================================================
	print("\n-------------------------------------------------------------")
	print(">>> [STAGE 2] 검증: 야수숲 (Beastwood Forest Gorge) <<<")
	print("-------------------------------------------------------------")
	await _wait_for_stage(1)
	await _advance_frames(5)

	var stage2 := campaign.current_stage_instance as SideQVStage2Class
	check(stage2 != null, "Stage 2 loaded and instantiated")
	check(stage2.stage_index == 2, "Stage 2 index is 2 (Got: %d)" % stage2.stage_index)
	check(stage2.stage_title == "야수숲", "Stage 2 title is '야수숲'")

	_verify_common_stage_invariants(stage2, 2)

	# Stage 2 3D Environment: Emerald Ambience & Fireflies
	var env2: Environment = stage2.get_node("WorldEnvironment3D").environment
	check(env2.ambient_light_color.is_equal_approx(Color(0.2, 0.45, 0.25)),
		"Stage 2 Deep Forest Emerald Ambience verified: Color(0.2, 0.45, 0.25)")
	check(stage2.get_node_or_null("ForestFireflies") is CPUParticles3D, "Stage 2 ForestFireflies particle system active")

	# Wave 1 Beast Minions
	print("\n  [Stage 2 Wave 1 Inspection]")
	check(stage2.current_wave == 1, "Stage 2 current_wave is 1")
	check(stage2.enemies.size() == 2, "Stage 2 Wave 1 spawned 2 beast minions")
	var b_minion: SideQVBeastMinionClass = stage2.enemies[0] as SideQVBeastMinionClass
	check(b_minion != null, "Minion is SideQVBeastMinion")
	check(b_minion.sprite_3d.hframes == 3 and b_minion.sprite_3d.vframes == 2, "Minion sprite sheet is 3x2 (beast_v2)")

	# Minion facing towards player
	stage2.player.global_position = Vector3(-4.0, 0.1, 0.0)
	b_minion.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(b_minion.sprite_3d.flip_h == true, "Beast minion faces left towards player")

	for m in stage2.enemies.duplicate():
		if is_instance_valid(m) and m.has_method("receive_hit"):
			m.receive_hit(20, Vector3.ZERO)

	await _advance_frames(8)

	# Wave 2 Beast Chieftain Boss Spawn
	print("\n  [Stage 2 Wave 2 Boss Inspection]")
	check(stage2.current_wave == 2, "Stage 2 transitioned to Wave 2 (Boss Wave)")
	var boss2: SideQVBeastChieftainClass = stage2.active_boss as SideQVBeastChieftainClass
	check(boss2 != null, "Stage 2 active boss is SideQVBeastChieftain")
	check(boss2.max_hp == 28, "Stage 2 Boss max HP is 28 (Got: %d)" % boss2.max_hp)
	check(boss2.sprite_3d.hframes == 4 and boss2.sprite_3d.vframes == 3, "Boss sprite sheet is 4x3 (beast_chieftain_v2)")

	# Boss Patterns: Pounce Leap & Triple Claw
	boss2._execute_pounce_leap(Vector3(-4.0, 0.0, 0.0))
	check(boss2.current_pattern == SideQVBeastChieftainClass.Pattern.POUNCE_LEAP, "Boss pattern is POUNCE_LEAP")
	check(boss2.is_leap_airborne == true, "Boss marked airborne during leap")
	check(boss2.velocity.y > 0.0, "Boss leap upward velocity applied")

	boss2._on_pounce_landed()
	check(boss2.is_leap_airborne == false, "Boss airborne cleared on landing")
	check(boss2.velocity == Vector3.ZERO, "Boss velocity zeroed on landing")

	boss2._execute_triple_claw()
	check(boss2.current_pattern == SideQVBeastChieftainClass.Pattern.TRIPLE_CLAW_STRIKE, "Boss pattern is TRIPLE_CLAW_STRIKE")

	# Parry Stun & Push Prevention
	boss2.apply_parry_stun(1.2)
	check(boss2.is_stunned == true, "Boss parry stunned")
	check(boss2.current_pattern == SideQVBeastChieftainClass.Pattern.STUNNED, "Boss pattern set to STUNNED")

	stage2.player.global_position = Vector3(-0.9, 0.1, 0.0)
	boss2.global_position = Vector3(0.0, 0.1, 0.0)
	boss2.velocity = Vector3(-6.0, 0.0, 0.0)
	boss2._prevent_player_pushing()
	check(absf(boss2.velocity.x) <= 0.1, "Boss _prevent_player_pushing stops pushing into player")

	# Boss Defeat & Stage Clear Verification
	boss2.receive_hit(50, Vector3.ZERO)

	var s2_timer: float = 0.0
	while not stage_cleared_events[1] and s2_timer < 1.0:
		await physics_frame
		s2_timer += 1.0 / 60.0

	check(stage_cleared_events[1], "Stage 2 stage_cleared signal emitted")
	check(campaign.cleared_stages[1] == true, "Campaign marked Stage 2 as cleared")

	# ==============================================================================
	# STAGE 3 (무너진 성벽 / Ruined Crossbow Bastion)
	# ==============================================================================
	print("\n-------------------------------------------------------------")
	print(">>> [STAGE 3] 검증: 무너진 성벽 (Ruined Crossbow Bastion) <<<")
	print("-------------------------------------------------------------")
	await _wait_for_stage(2)
	await _advance_frames(5)

	var stage3 := campaign.current_stage_instance as SideQVStage3Class
	check(stage3 != null, "Stage 3 loaded and instantiated")
	check(stage3.stage_index == 3, "Stage 3 index is 3 (Got: %d)" % stage3.stage_index)
	check(stage3.stage_title == "무너진 성벽", "Stage 3 title is '무너진 성벽'")

	_verify_common_stage_invariants(stage3, 3)

	# Stage 3 Environment: Floating Stone Shards & Broken Battlement
	check(stage3.floating_stones.size() >= 6, "Stage 3 has floating stone shards (count: %d >= 6)" % stage3.floating_stones.size())
	check(stage3.get_node_or_null("BrokenWall_0") != null, "Stage 3 broken masonry battlement segment exists")

	# Wave 1 Ranged Minions
	print("\n  [Stage 3 Wave 1 Inspection]")
	check(stage3.current_wave == 1, "Stage 3 current_wave is 1")
	check(stage3.enemies.size() == 2, "Stage 3 Wave 1 spawned 2 ranged minions")
	var r_minion: SideQVRangedMinionClass = stage3.enemies[0] as SideQVRangedMinionClass
	check(r_minion != null, "Minion is SideQVRangedMinion")

	# Minion facing towards player
	stage3.player.global_position = Vector3(-4.0, 0.1, 0.0)
	r_minion.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(r_minion.sprite_3d.flip_h == true, "Ranged minion faces left towards player")

	for m in stage3.enemies.duplicate():
		if is_instance_valid(m) and m.has_method("receive_hit"):
			m.receive_hit(20, Vector3.ZERO)

	await _advance_frames(8)

	# Wave 2 Crossbow Commander Boss Spawn
	print("\n  [Stage 3 Wave 2 Boss Inspection]")
	check(stage3.current_wave == 2, "Stage 3 transitioned to Wave 2 (Boss Wave)")
	var boss3: SideQVCrossbowCommanderClass = stage3.active_boss as SideQVCrossbowCommanderClass
	check(boss3 != null, "Stage 3 active boss is SideQVCrossbowCommander")
	check(boss3.max_hp == 28, "Stage 3 Boss max HP is 28 (Got: %d)" % boss3.max_hp)

	# Boss Patterns: Fan Crossbow Volley & Caltrop Trap
	boss3._execute_fan_volley()
	check(boss3.current_pattern == SideQVCrossbowCommanderClass.Pattern.FAN_VOLLEY, "Boss pattern is FAN_VOLLEY (3-way bolt)")

	boss3._execute_caltrop_trap()
	check(boss3.current_pattern == SideQVCrossbowCommanderClass.Pattern.CALTROP_TRAP, "Boss pattern is CALTROP_TRAP")

	# Parry Stun & Push Prevention
	boss3.apply_parry_stun(1.2)
	check(boss3.is_stunned == true, "Boss parry stunned")
	check(boss3.current_pattern == SideQVCrossbowCommanderClass.Pattern.STUNNED, "Boss pattern set to STUNNED")

	stage3.player.global_position = Vector3(-0.9, 0.1, 0.0)
	boss3.global_position = Vector3(0.0, 0.1, 0.0)
	boss3.velocity = Vector3(-5.0, 0.0, 0.0)
	boss3._prevent_player_pushing()
	check(absf(boss3.velocity.x) <= 0.1, "Boss _prevent_player_pushing stops pushing into player")

	# Boss Defeat & Stage Clear Verification
	boss3.receive_hit(50, Vector3.ZERO)

	var s3_timer: float = 0.0
	while not stage_cleared_events[2] and s3_timer < 1.0:
		await physics_frame
		s3_timer += 1.0 / 60.0

	check(stage_cleared_events[2], "Stage 3 stage_cleared signal emitted")
	check(campaign.cleared_stages[2] == true, "Campaign marked Stage 3 as cleared")

	# ==============================================================================
	# STAGE 4 (돌의 성소 / Titan Stone Sanctuary)
	# ==============================================================================
	print("\n-------------------------------------------------------------")
	print(">>> [STAGE 4] 검증: 돌의 성소 (Titan Stone Sanctuary) <<<")
	print("-------------------------------------------------------------")
	await _wait_for_stage(3)
	await _advance_frames(5)

	var stage4 := campaign.current_stage_instance as SideQVStage4Class
	check(stage4 != null, "Stage 4 loaded and instantiated")
	check(stage4.stage_index == 4, "Stage 4 index is 4 (Got: %d)" % stage4.stage_index)
	check(stage4.stage_title == "돌의 성소", "Stage 4 title is '돌의 성소'")

	_verify_common_stage_invariants(stage4, 4)

	# Stage 4 Environment: Sunset Magma Amber Ambience & Altar Dais
	var env4: Environment = stage4.get_node("WorldEnvironment3D").environment
	check(env4.ambient_light_color.is_equal_approx(Color(0.55, 0.28, 0.15)),
		"Stage 4 Sunset Magma Amber Ambience verified: Color(0.55, 0.28, 0.15)")
	check(stage4.get_node_or_null("AncientStoneAltar") != null, "AncientStoneAltar dais exists")

	var monolith_count := 0
	for child in stage4.get_children():
		if child.name.begins_with("MonolithPillar"):
			monolith_count += 1
			check(child.get_node_or_null("RuneBand") != null, "Monolith pillar has glowing RuneBand")
	check(monolith_count >= 6, "At least 6 massive monolithic pillars present around sanctuary (Count: %d)" % monolith_count)

	# Wave 1 Heavy Golem Minions
	print("\n  [Stage 4 Wave 1 Inspection]")
	check(stage4.current_wave == 1, "Stage 4 current_wave is 1")
	check(stage4.enemies.size() == 2, "Stage 4 Wave 1 spawned 2 golem minions")
	var g_minion: SideQVGolemMinionClass = stage4.enemies[0] as SideQVGolemMinionClass
	check(g_minion != null, "Minion is SideQVGolemMinion")
	check(g_minion.max_hp == 8, "Golem minion HP is 8 (High durability)")

	# Minion facing towards player
	stage4.player.global_position = Vector3(-4.0, 0.1, 0.0)
	g_minion.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(g_minion.sprite_3d.flip_h == true, "Golem minion faces left towards player")

	for m in stage4.enemies.duplicate():
		if is_instance_valid(m) and m.has_method("receive_hit"):
			m.receive_hit(20, Vector3.ZERO)

	await _advance_frames(8)

	# Wave 2 Golem Guardian Boss Spawn
	print("\n  [Stage 4 Wave 2 Boss Inspection]")
	check(stage4.current_wave == 2, "Stage 4 transitioned to Wave 2 (Boss Wave)")
	var boss4: SideQVGolemGuardianClass = stage4.active_boss as SideQVGolemGuardianClass
	check(boss4 != null, "Stage 4 active boss is SideQVGolemGuardian")
	check(boss4.max_hp == 32, "Stage 4 Boss max HP is 32 (Titan Durability)")
	check(boss4.sprite_3d.hframes == 4 and boss4.sprite_3d.vframes == 3, "Boss sprite sheet is 4x3")

	# Boss Patterns: Ground Slam & Spinning Lariat
	boss4._execute_ground_slam()
	check(boss4.current_pattern == SideQVGolemGuardianClass.Pattern.GROUND_SLAM, "Boss pattern is GROUND_SLAM")

	boss4._execute_spinning_lariat()
	check(boss4.current_pattern == SideQVGolemGuardianClass.Pattern.SPINNING_LARIAT, "Boss pattern is SPINNING_LARIAT")

	# Parry Stun & Push Prevention
	boss4.apply_parry_stun(1.2)
	check(boss4.is_stunned == true, "Boss parry stunned")
	check(boss4.current_pattern == SideQVGolemGuardianClass.Pattern.STUNNED, "Boss pattern set to STUNNED")

	stage4.player.global_position = Vector3(-0.9, 0.1, 0.0)
	boss4.global_position = Vector3(0.0, 0.1, 0.0)
	boss4.velocity = Vector3(-4.0, 0.0, 0.0)
	boss4._prevent_player_pushing()
	check(absf(boss4.velocity.x) <= 0.1, "Boss _prevent_player_pushing stops pushing into player")

	# Boss Defeat & Stage Clear Verification
	boss4.receive_hit(50, Vector3.ZERO)

	var s4_timer: float = 0.0
	while not stage_cleared_events[3] and s4_timer < 1.0:
		await physics_frame
		s4_timer += 1.0 / 60.0

	check(stage_cleared_events[3], "Stage 4 stage_cleared signal emitted")
	check(campaign.cleared_stages[3] == true, "Campaign marked Stage 4 as cleared")

	# ==============================================================================
	# STAGE 5 (침묵의 성채 / Silent Abyssal Citadel)
	# ==============================================================================
	print("\n-------------------------------------------------------------")
	print(">>> [STAGE 5] 검증: 침묵의 성채 (Silent Abyssal Citadel) <<<")
	print("-------------------------------------------------------------")
	await _wait_for_stage(4)
	await _advance_frames(5)

	var stage5 := campaign.current_stage_instance as SideQVStage5Class
	check(stage5 != null, "Stage 5 loaded and instantiated")
	check(stage5.stage_index == 5, "Stage 5 index is 5 (Got: %d)" % stage5.stage_index)
	check(stage5.stage_title == "침묵의 성채", "Stage 5 title is '침묵의 성채'")

	_verify_common_stage_invariants(stage5, 5)

	# Stage 5 Environment: Void Purple Ambience & Dark Obsidian Floor
	var env5: Environment = stage5.get_node("WorldEnvironment3D").environment
	check(env5.ambient_light_color.is_equal_approx(Color(0.22, 0.12, 0.38)),
		"Stage 5 Void Purple Ambience verified: Color(0.22, 0.12, 0.38)")
	check(stage5.get_node_or_null("DarkObsidianFloor") != null, "DarkObsidianFloor exists")
	check(stage5.get_node_or_null("ThronePodium") != null, "ThronePodium exists")

	# Wave 1 Elite Knights
	print("\n  [Stage 5 Wave 1 Inspection]")
	check(stage5.current_wave == 1, "Stage 5 current_wave is 1")
	check(stage5.enemies.size() == 2, "Stage 5 Wave 1 spawned 2 elite knights")
	var ek: SideQVEliteKnightClass = stage5.enemies[0] as SideQVEliteKnightClass
	check(ek != null, "Minion is SideQVEliteKnight")
	check(ek.max_hp == 6, "Elite knight HP is 6")

	# Minion facing towards player
	stage5.player.global_position = Vector3(-4.0, 0.1, 0.0)
	ek.global_position = Vector3(2.0, 0.1, 0.0)
	await _advance_frames(3)
	check(ek.sprite_3d.flip_h == true, "Elite knight faces left towards player")

	for m in stage5.enemies.duplicate():
		if is_instance_valid(m) and m.has_method("receive_hit"):
			m.receive_hit(20, Vector3.ZERO)

	await _advance_frames(8)

	# Wave 2 Final Boss Abyssal Arbiter Spawn
	print("\n  [Stage 5 Wave 2 Final Boss Inspection]")
	check(stage5.current_wave == 2, "Stage 5 transitioned to Wave 2 (Boss Wave)")
	var boss5: SideQVAbyssalArbiterClass = stage5.active_boss as SideQVAbyssalArbiterClass
	check(boss5 != null, "Stage 5 active boss is SideQVAbyssalArbiter")
	check(boss5.max_hp == 30, "Final Boss max HP is 30")
	check(boss5.sprite_3d.hframes == 4 and boss5.sprite_3d.vframes == 3, "Final Boss sprite sheet is 4x3")

	# Boss Patterns: Dark Crescent Wave & Shadow Blink Strike
	boss5._execute_dark_crescent_wave()
	check(boss5.current_pattern == SideQVAbyssalArbiterClass.Pattern.DARK_CRESCENT_WAVE,
		"Final Boss pattern is DARK_CRESCENT_WAVE")

	boss5._execute_shadow_blink_strike()
	check(boss5.current_pattern == SideQVAbyssalArbiterClass.Pattern.SHADOW_BLINK_STRIKE,
		"Final Boss pattern is SHADOW_BLINK_STRIKE")

	# Parry Stun & Push Prevention
	boss5.apply_parry_stun(1.2)
	check(boss5.is_stunned == true, "Final Boss parry stunned")
	check(boss5.current_pattern == SideQVAbyssalArbiterClass.Pattern.STUNNED, "Final Boss pattern set to STUNNED")

	stage5.player.global_position = Vector3(-0.9, 0.1, 0.0)
	boss5.global_position = Vector3(0.0, 0.1, 0.0)
	boss5.velocity = Vector3(-6.0, 0.0, 0.0)
	boss5._prevent_player_pushing()
	check(absf(boss5.velocity.x) <= 0.1, "Final Boss _prevent_player_pushing stops pushing into player")

	# Final Boss Defeat & Campaign Completion Verification
	boss5.receive_hit(50, Vector3.ZERO)

	var s5_timer: float = 0.0
	while not stage_cleared_events[4] and s5_timer < 1.0:
		await physics_frame
		s5_timer += 1.0 / 60.0

	check(stage_cleared_events[4], "Stage 5 stage_cleared signal emitted")
	check(campaign.cleared_stages[4] == true, "Campaign marked Stage 5 as cleared")

	# ==============================================================================
	# FINAL CAMPAIGN VICTORY & SUMMARY INSPECTION
	# ==============================================================================
	print("\n-------------------------------------------------------------")
	print(">>> [CAMPAIGN COMPLETION] 최종 캠페인 승리 및 결과 검증 <<<")
	print("-------------------------------------------------------------")
	var comp_timer: float = 0.0
	while not campaign_completed_flag and comp_timer < 1.0:
		await physics_frame
		comp_timer += 1.0 / 60.0

	check(campaign_completed_flag, "campaign_completed signal emitted by SideQVCampaign")
	check(campaign.cleared_stages == [true, true, true, true, true],
		"All 5 stages marked cleared: [true, true, true, true, true]")

	# Victory UI Panel Check
	var vic_panel = campaign.ui_layer.get_node_or_null("CampaignVictoryPanel") as PanelContainer
	check(vic_panel != null, "CampaignVictoryPanel exists in CampaignUILayer")
	if vic_panel != null:
		var labels: Array[Node] = vic_panel.find_children("*", "Label", true, false)
		check(labels.size() >= 2, "Victory panel contains title and subtitle labels (Count: %d)" % labels.size())
		var has_vic_title := false
		var has_vic_desc := false
		for lbl in labels:
			var l := lbl as Label
			if "★ CAMPAIGN VICTORY ★" in l.text:
				has_vic_title = true
			if "All 5 Side Quarter-View Stages Cleared!" in l.text:
				has_vic_desc = true
		check(has_vic_title, "Victory title '★ CAMPAIGN VICTORY ★' verified")
		check(has_vic_desc, "Victory subtitle 'All 5 Side Quarter-View Stages Cleared!' verified")

	# ==============================================================================
	# QA SUMMARY
	# ==============================================================================
	print("\n===================================================================")
	print("MASTER CAMPAIGN QA RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("===================================================================")

	if failures == 0:
		print("\n>>> ALL 5-STAGE CAMPAIGN QA INSPECTION CHECKS PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> CAMPAIGN QA FAILED: %d defects detected <<<\n" % failures)
		quit(1)
