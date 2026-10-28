extends "res://scripts/side_quarter_view/side_qv_stage_base.gd"
class_name SideQVStage4
## 사이드 쿼터뷰 Stage 4: 돌의 성소 (Side Quarter-View: Stone Sanctuary)
## - 고대 거석 제단 및 모놀리스 기둥 (Massive Stone Altars & Monoliths)
## - 붉은 주황 석양 & 마그마 앰비언스 (Color(0.55, 0.28, 0.15))
## - 공중에 흩날리는 불씨 엠버 파티클 (CPUParticles3D)
## - 웨이브 1: 헤비 골렘 미니언 (golem_v1.png) 2기 스폰
## - 웨이브 2: SideQVGolemGuardian 보스 스폰 및 처치 시 클리어

const SideQVGolemMinionClass = preload("res://scripts/side_quarter_view/side_qv_golem_minion.gd")
const SideQVGolemGuardianClass = preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")

const TexSanctuary = preload("res://assets/terrain_v2/sanctuary.png")
const TexFlagstone = preload("res://assets/side_qv/flagstone_floor.png")
const TexCitadel = preload("res://assets/terrain_v2/citadel.png")

var boss_hp_bar: ProgressBar
var boss_name_label: Label


func _init() -> void:
	stage_index = 4
	stage_title = "돌의 성소"
	arena_width = 38.0
	arena_depth = 12.0


func _setup_3d_environment() -> void:
	# 1. 붉은 주황 석양 & 마그마 앰비언스 WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.08, 0.06, 1.0) # Dark sunset volcanic dusk sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.28, 0.15, 1.0) # 규격 앰비언스 컬러
	env.ambient_light_energy = 1.35

	# 3D HDR Glow
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.45
	world_env.environment = env
	add_child(world_env)

	# 2. 석양빛 Directional Sunlight (Soft Real-time Shadows)
	var sun := DirectionalLight3D.new()
	sun.name = "SunsetSunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.65, 0.35, 1.0) # Warm sunset amber
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-36.0, -28.0, 0.0)
	add_child(sun)

	# 3. 공중에 흩날리는 불씨 엠버 파티클 (CPUParticles3D)
	var embers := CPUParticles3D.new()
	embers.name = "EmberParticles3D"
	embers.amount = 64
	embers.lifetime = 4.2
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(arena_width * 0.5, 3.5, arena_depth * 0.5)
	embers.position = Vector3(0.0, 3.0, 0.0)
	embers.gravity = Vector3(0.25, 0.75, 0.0)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.8

	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(3.8, 1.1, 0.25, 0.95)
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var pmesh := QuadMesh.new()
	pmesh.size = Vector2(0.12, 0.12)
	pmesh.material = pmat
	embers.mesh = pmesh
	add_child(embers)


func _setup_3d_background_architecture() -> void:
	# 1. 고대 성소 원경 파노라마 백드롭 (Sanctuary Backdrop)
	var backdrop_mesh := MeshInstance3D.new()
	backdrop_mesh.name = "SanctuaryBackdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(64.0, 25.0)
	backdrop_mesh.mesh = quad

	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = TexSanctuary
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.92, 0.85, 1.0)
	bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop_mesh.material_override = bmat
	backdrop_mesh.position = Vector3(0.0, 4.2, -13.8)
	add_child(backdrop_mesh)

	# 2. 고대 석판 바닥 (Arena Floor)
	var floor_box := CSGBox3D.new()
	floor_box.name = "ArenaFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World (Layer 3)
	floor_box.size = Vector3(arena_width, 1.0, arena_depth)
	floor_box.position.y = -0.5

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = TexFlagstone
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	floor_mat.albedo_color = Color(0.85, 0.78, 0.72, 1.0) # Ancient warm stone
	floor_mat.roughness = 0.75
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# 3. 고대 거석 제단 (Massive Ancient Stone Altar Dais)
	var altar_container := Node3D.new()
	altar_container.name = "AncientStoneAltar"
	altar_container.position = Vector3(0.0, 0.0, -arena_depth * 0.5 + 1.2)

	# 제단 기단부 (Tier 1)
	var tier1 := CSGBox3D.new()
	tier1.name = "AltarTier1"
	tier1.size = Vector3(15.0, 0.6, 3.6)
	tier1.position.y = 0.3
	tier1.material_override = floor_mat
	altar_container.add_child(tier1)

	# 제단 상단부 (Tier 2)
	var tier2 := CSGBox3D.new()
	tier2.name = "AltarTier2"
	tier2.size = Vector3(9.5, 0.6, 2.6)
	tier2.position.y = 0.9
	tier2.material_override = floor_mat
	altar_container.add_child(tier2)

	# 중앙 제물석 모놀리스 (Sacrificial Altar Slab)
	var altar_slab := CSGBox3D.new()
	altar_slab.name = "AltarSlab"
	altar_slab.size = Vector3(4.8, 1.1, 1.8)
	altar_slab.position.y = 1.75
	var slab_mat := StandardMaterial3D.new()
	slab_mat.albedo_texture = TexCitadel
	slab_mat.uv1_scale = Vector3(2.0, 1.0, 1.0)
	slab_mat.emission_enabled = true
	slab_mat.emission = Color(3.2, 0.8, 0.15, 1.0) # Magma runic glow
	slab_mat.emission_energy_multiplier = 1.2
	altar_slab.material_override = slab_mat
	altar_container.add_child(altar_slab)

	# 제단 양측 화로 조명 (Brazier Fire Lights)
	_build_altar_brazier(altar_container, Vector3(-6.2, 0.9, 0.0))
	_build_altar_brazier(altar_container, Vector3(6.2, 0.9, 0.0))

	add_child(altar_container)

	# 4. 거석 모놀리스 기둥 (Massive Monolith Pillars)
	_build_monolith_pillar(Vector3(-14.5, 3.2, -arena_depth * 0.5 + 0.9), 6.4, 0)
	_build_monolith_pillar(Vector3(-7.5, 3.5, -arena_depth * 0.5 + 0.9), 7.0, 1)
	_build_monolith_pillar(Vector3(7.5, 3.5, -arena_depth * 0.5 + 0.9), 7.0, 2)
	_build_monolith_pillar(Vector3(14.5, 3.2, -arena_depth * 0.5 + 0.9), 6.4, 3)
	_build_monolith_pillar(Vector3(-17.5, 3.6, 0.0), 7.2, 4) # 좌측 관문 기둥
	_build_monolith_pillar(Vector3(17.5, 3.6, 0.0), 7.2, 5) # 우측 관문 기둥


func _build_monolith_pillar(pos: Vector3, h: float, idx: int = 0) -> void:
	var pillar := CSGBox3D.new()
	pillar.name = "MonolithPillar_%d" % idx
	pillar.size = Vector3(1.6, h, 1.6)
	pillar.position = pos
	pillar.use_collision = true
	pillar.collision_layer = 4

	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = TexCitadel
	pmat.uv1_scale = Vector3(1.0, 3.0, 1.0)
	pmat.roughness = 0.80
	pillar.material_override = pmat

	# 기둥 중앙 고대 룬 발광 밴드
	var rune_band := MeshInstance3D.new()
	rune_band.name = "RuneBand"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.85
	cyl.height = 0.4
	cyl.radial_segments = 6
	rune_band.mesh = cyl

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(3.5, 0.8, 0.15, 1.0)
	rmat.emission_enabled = true
	rmat.emission = Color(3.5, 0.8, 0.15, 1.0)
	rmat.emission_energy_multiplier = 3.2
	rune_band.material_override = rmat
	rune_band.position.y = 0.2
	pillar.add_child(rune_band)

	add_child(pillar)


func _build_altar_brazier(parent: Node3D, local_pos: Vector3) -> void:
	var brazier := CSGBox3D.new()
	brazier.size = Vector3(0.9, 0.9, 0.9)
	brazier.position = local_pos

	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.18, 0.16, 1.0)
	brazier.material_override = bmat
	parent.add_child(brazier)

	var flame_light := OmniLight3D.new()
	flame_light.name = "BrazierLight"
	flame_light.light_color = Color(1.0, 0.55, 0.15, 1.0) # Warm fire glow
	flame_light.light_energy = 2.2
	flame_light.omni_range = 7.5
	flame_light.position = local_pos + Vector3(0.0, 0.8, 0.0)
	parent.add_child(flame_light)


func _setup_mobile_ui() -> void:
	super._setup_mobile_ui()

	# 보스 전용 HP바 컨테이너 (웨이브 2 시작 시 표시)
	boss_name_label = Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.text = "BOSS: 골렘 가디언 (Lv.4 고대 수호자)"
	boss_name_label.position = Vector2(420, 24)
	boss_name_label.add_theme_font_size_override("font_size", 18)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	boss_name_label.visible = false
	mobile_controls.add_child(boss_name_label)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.name = "BossHPBar"
	boss_hp_bar.position = Vector2(400, 52)
	boss_hp_bar.size = Vector2(360, 18)
	boss_hp_bar.max_value = 32
	boss_hp_bar.value = 32
	boss_hp_bar.show_percentage = true
	boss_hp_bar.visible = false
	mobile_controls.add_child(boss_hp_bar)


# ==============================================================================
# 웨이브 시스템: 웨이브 1 (헤비 골렘 2기) -> 웨이브 2 (골렘 가디언 보스)
# ==============================================================================
func _spawn_wave_1_enemies() -> void:
	enemies.clear()

	# 헤비 골렘 미니언 1
	var golem1 = SideQVGolemMinionClass.new()
	golem1.name = "HeavyGolem_1"
	golem1.position = Vector3(4.0, 0.1, -1.2)
	golem1.enemy_defeated.connect(_on_enemy_defeated)
	add_child(golem1)
	enemies.append(golem1)

	# 헤비 골렘 미니언 2
	var golem2 = SideQVGolemMinionClass.new()
	golem2.name = "HeavyGolem_2"
	golem2.position = Vector3(8.5, 0.1, 1.2)
	golem2.enemy_defeated.connect(_on_enemy_defeated)
	add_child(golem2)
	enemies.append(golem2)


func _spawn_stage_boss() -> void:
	var boss = SideQVGolemGuardianClass.new()
	boss.name = "SideQVGolemGuardian"
	var p_x: float = player.global_position.x if (player != null and is_instance_valid(player)) else 0.0
	var spawn_x: float = clampf(maxf(p_x + 5.5, 11.5), 10.0, arena_width * 0.5 - 2.5)
	boss.position = Vector3(spawn_x, 0.1, 0.0)
	boss.boss_defeated.connect(_on_boss_defeated)
	boss.boss_hp_changed.connect(_on_boss_hp_changed)
	add_child(boss)
	active_boss = boss
	enemies.append(boss)

	# 메인 BossHealthBar와 겹치지 않도록 보조 노드는 투명 상태 유지
	if boss_name_label != null:
		boss_name_label.visible = false
	if boss_hp_bar != null:
		boss_hp_bar.visible = false
		boss_hp_bar.max_value = boss.max_hp
		boss_hp_bar.value = boss.current_hp


func _on_boss_hp_changed(curr: int, max_val: int) -> void:
	if boss_hp_bar != null:
		boss_hp_bar.max_value = max_val
		boss_hp_bar.value = curr


func _on_boss_defeated(boss_node: Node = null) -> void:
	if boss_hp_bar != null:
		boss_hp_bar.visible = false
	if boss_name_label != null:
		boss_name_label.visible = false
	super._on_boss_defeated(boss_node)
