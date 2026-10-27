extends SideQVStageBase
class_name SideQVStage2
## 사이드 쿼터뷰 스테이지 2: 야수숲 협곡 (Side QV Stage 2: Beastwood Forest Gorge)
## - 깊은 숲속 에메랄드 앰비언스 (Color(0.2, 0.45, 0.25)) & 녹음 포그
## - 거대한 고목 나무 기둥 (CSGCylinder3D & Foliage) & 야수숲 지형 바닥
## - 숲속을 부유하는 반딧불이 파티클 (CPUParticles3D)
## - 웨이브 1: 숲의 맹수 미니언 (SideQVBeastMinion) 2기 스폰
## - 웨이브 2: 심연의 야수 우두머리 (SideQVBeastChieftain) 보스전

const SideQVBeastMinionClass = preload("res://scripts/side_quarter_view/enemies/side_qv_beast_minion.gd")
const SideQVBeastChieftainClass = preload("res://scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd")

const TexForest = preload("res://assets/terrain_v2/forest.png")

var fireflies_particles: CPUParticles3D = null


func _init() -> void:
	stage_index = 2
	stage_title = "야수숲"
	arena_width = 40.0
	arena_depth = 12.0


func _setup_3d_environment() -> void:
	# 1. WorldEnvironment (에메랄드 앰비언스 & 녹음 포그 & 3D HDR Glow)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.11, 0.06, 1.0) # 야수숲 밤하늘 심연 암록색

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# [필수 규격] 깊은 숲속 에메랄드 앰비언스 Color(0.2, 0.45, 0.25)
	env.ambient_light_color = Color(0.2, 0.45, 0.25, 1.0)
	env.ambient_light_energy = 1.30

	# 녹음 포그 (Lush Emerald Fog)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.12, 0.28, 0.18, 1.0)
	env.fog_density = 0.018

	# 3D HDR Glow Bloom
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.4
	world_env.environment = env
	add_child(world_env)

	# 2. 캐노피 사이로 내리쬐는 에메랄드 달빛 (Directional Sunlight/Moonlight)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(0.85, 1.0, 0.88, 1.0)
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	add_child(sun)

	# 3. 숲속 반딧불이 파티클 (CPUParticles3D)
	fireflies_particles = CPUParticles3D.new()
	fireflies_particles.name = "ForestFireflies"
	fireflies_particles.amount = 56
	fireflies_particles.lifetime = 5.0
	fireflies_particles.preprocess = 2.0
	fireflies_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies_particles.emission_box_extents = Vector3(arena_width * 0.5, 3.5, arena_depth * 0.5)
	fireflies_particles.gravity = Vector3(0.0, 0.25, 0.0)
	fireflies_particles.initial_velocity_min = 0.2
	fireflies_particles.initial_velocity_max = 0.6
	fireflies_particles.spread = 180.0
	fireflies_particles.position = Vector3(0.0, 3.2, 0.0)

	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.06
	p_mesh.height = 0.12
	fireflies_particles.mesh = p_mesh

	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(1.8, 2.6, 0.5, 1.0) # 발광 에메랄드 옐로우그린
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.8, 2.6, 0.5, 1.0)
	p_mat.emission_energy_multiplier = 4.0
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fireflies_particles.material_override = p_mat
	add_child(fireflies_particles)


func _setup_3d_background_architecture() -> void:
	# -------------------------------------------------------------
	# 1. 야수숲 바닥 지형 (Beastwood Forest Floor)
	# -------------------------------------------------------------
	var floor_box := CSGBox3D.new()
	floor_box.name = "ArenaFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World Layer (4)
	floor_box.size = Vector3(arena_width, 1.0, arena_depth)
	floor_box.position = Vector3(0.0, -0.5, 0.0)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = TexForest
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_scale = Vector3(0.28, 0.28, 0.28)
	floor_mat.roughness = 0.85
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# -------------------------------------------------------------
	# 2. 거대한 고목 나무 기둥 군락 (Ancient Forest Tree Trunks & Branches)
	# -------------------------------------------------------------
	var tree_mat := StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.18, 0.14, 0.10, 1.0) # 짙은 고목 수피
	tree_mat.roughness = 0.9

	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.08, 0.26, 0.12, 1.0) # 울창한 짙은 녹음
	foliage_mat.roughness = 0.7

	# 배경 고목 기둥 5기 배치 (Z = -5.8)
	var tree_configs := [
		Vector3(-15.0, 0.0, -5.8),
		Vector3(-8.0, 0.0, -6.0),
		Vector3(-1.0, 0.0, -5.6),
		Vector3(6.5, 0.0, -6.0),
		Vector3(14.0, 0.0, -5.8)
	]
	var tree_radii := [1.2, 1.45, 1.1, 1.35, 1.5]
	var tree_heights := [14.0, 16.0, 13.0, 15.5, 16.0]

	for i in range(tree_configs.size()):
		_build_ancient_tree(
			tree_configs[i],
			tree_radii[i],
			tree_heights[i],
			tree_mat,
			foliage_mat,
			"AncientTree_%d" % i
		)

	# -------------------------------------------------------------
	# 3. 야수숲 전방 및 좌우 암벽 경계 (Forest Gorge Boundary)
	# -------------------------------------------------------------
	_build_forest_border_rocks(tree_mat, foliage_mat)

	# -------------------------------------------------------------
	# 4. 고대 야수 토템 룬 비석 (Ancient Beastwood Totems)
	# -------------------------------------------------------------
	_build_beast_totem(Vector3(-11.0, 0.0, -3.2), "BeastTotem_Left")
	_build_beast_totem(Vector3(11.0, 0.0, -3.2), "BeastTotem_Right")


func _build_ancient_tree(pos: Vector3, radius: float, height: float, t_mat: Material, f_mat: Material, node_name: String) -> void:
	var trunk := CSGCylinder3D.new()
	trunk.name = node_name
	trunk.radius = radius
	trunk.height = height
	trunk.position = pos + Vector3(0.0, height * 0.5, 0.0)
	trunk.material_override = t_mat
	trunk.use_collision = true
	trunk.collision_layer = 4
	add_child(trunk)

	# 뻗어나온 나뭇가지 (CSGBox3D)
	var branch := CSGBox3D.new()
	branch.size = Vector3(3.6, 0.65, 0.65)
	branch.position = pos + Vector3(1.2, height * 0.55, 0.4)
	branch.rotation_degrees = Vector3(15.0, 20.0, 18.0)
	branch.material_override = t_mat
	add_child(branch)

	# 상단 울창한 캐노피 나뭇잎 클러스터 (CSGSphere3D)
	var foliage := CSGSphere3D.new()
	foliage.radius = radius * 2.8
	foliage.position = pos + Vector3(0.0, height - 1.5, 0.0)
	foliage.material_override = f_mat
	add_child(foliage)


func _build_forest_border_rocks(rock_mat: Material, moss_mat: Material) -> void:
	# 전방 통나무 난간 경계 (Z = 5.8)
	var front_log := CSGBox3D.new()
	front_log.name = "FrontBoundaryLog"
	front_log.size = Vector3(arena_width, 0.7, 0.7)
	front_log.position = Vector3(0.0, 0.35, arena_depth * 0.5 - 0.2)
	front_log.use_collision = true
	front_log.collision_layer = 4
	front_log.material_override = rock_mat
	add_child(front_log)

	# 후방 통나무 난간 경계 (Z = -5.8)
	var back_log := CSGBox3D.new()
	back_log.name = "BackBoundaryLog"
	back_log.size = Vector3(arena_width, 0.7, 0.7)
	back_log.position = Vector3(0.0, 0.35, -arena_depth * 0.5 + 0.2)
	back_log.use_collision = true
	back_log.collision_layer = 4
	back_log.material_override = rock_mat
	add_child(back_log)

	# 좌우 협곡 암벽 (Left/Right Gorge Walls)
	var left_wall := CSGBox3D.new()
	left_wall.size = Vector3(1.2, 6.0, arena_depth)
	left_wall.position = Vector3(-arena_width * 0.5, 3.0, 0.0)
	left_wall.use_collision = true
	left_wall.collision_layer = 4
	left_wall.material_override = rock_mat
	add_child(left_wall)

	var right_wall := CSGBox3D.new()
	right_wall.size = Vector3(1.2, 6.0, arena_depth)
	right_wall.position = Vector3(arena_width * 0.5, 3.0, 0.0)
	right_wall.use_collision = true
	right_wall.collision_layer = 4
	right_wall.material_override = rock_mat
	add_child(right_wall)

	# 이끼 바위 볼더 4기 (Front/Back corners)
	var rock_coords := [
		Vector3(-14.0, 0.3, 4.5),
		Vector3(14.0, 0.3, 4.5),
		Vector3(-17.0, 0.4, -4.5),
		Vector3(17.0, 0.4, -4.5)
	]
	for rc in rock_coords:
		var boulder := CSGSphere3D.new()
		boulder.radius = 0.95
		boulder.position = rc
		boulder.scale = Vector3(1.4, 0.7, 1.1)
		boulder.material_override = moss_mat
		add_child(boulder)


func _build_beast_totem(pos: Vector3, totem_name: String) -> void:
	var pillar := CSGBox3D.new()
	pillar.name = totem_name
	pillar.size = Vector3(0.9, 3.6, 0.9)
	pillar.position = pos + Vector3(0.0, 1.8, 0.0)
	pillar.use_collision = true
	pillar.collision_layer = 4

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.16, 0.18, 1.0)
	mat.roughness = 0.65
	pillar.material_override = mat
	add_child(pillar)

	# 발광 에메랄드 룬 링
	var ring := CSGTorus3D.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.68
	ring.position = pos + Vector3(0.0, 2.5, 0.0)

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.2, 2.6, 0.9, 1.0)
	rmat.emission_enabled = true
	rmat.emission = Color(0.2, 2.6, 0.9, 1.0)
	rmat.emission_energy_multiplier = 4.2
	ring.material_override = rmat
	add_child(ring)

	# 룬 불빛 조명
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.8, 0.7, 1.0)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = pos + Vector3(0.0, 2.7, 0.0)
	add_child(light)


# ==============================================================================
# 웨이브 1: 숲의 맹수 미니언 2기 스폰
# ==============================================================================
func _spawn_wave_1_enemies() -> void:
	enemies.clear()

	var beast1 := SideQVBeastMinionClass.new()
	beast1.name = "SideQVBeastMinion_1"
	beast1.position = Vector3(4.5, 0.1, -1.6)
	add_child(beast1)
	enemies.append(beast1)
	beast1.enemy_defeated.connect(_on_enemy_defeated)

	var beast2 := SideQVBeastMinionClass.new()
	beast2.name = "SideQVBeastMinion_2"
	beast2.position = Vector3(8.0, 0.1, 1.6)
	add_child(beast2)
	enemies.append(beast2)
	beast2.enemy_defeated.connect(_on_enemy_defeated)


# ==============================================================================
# 웨이브 2: 심연의 야수 우두머리 (SideQVBeastChieftain) 스폰
# ==============================================================================
func _spawn_stage_boss() -> void:
	var boss := SideQVBeastChieftainClass.new()
	boss.name = "SideQVBeastChieftain"
	var p_x: float = player.global_position.x if player != null else 0.0
	boss.position = Vector3(p_x + 8.5, 0.1, 0.0)
	add_child(boss)

	active_boss = boss
	enemies.append(boss)
	boss.boss_defeated.connect(func(_b): _on_boss_defeated())

	# 보스 전용 HP바 UI 생성 및 부착
	if mobile_controls != null:
		boss_health_bar = BossHealthBarClass.new()
		boss_health_bar.name = "Stage2BossHealthBar"
		boss_health_bar.boss_name = "심연의 야수 우두머리 (Beast Chieftain)"
		boss_health_bar.position = Vector2((1280.0 - BossHealthBar.BAR_WIDTH) * 0.5, 36.0)
		mobile_controls.add_child(boss_health_bar)
		boss_health_bar.snap_to_visible()
		boss_health_bar.attach_boss(boss)
