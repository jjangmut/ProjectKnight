extends "res://scripts/side_quarter_view/side_qv_stage_base.gd"
class_name SideQVStage3
## 사이드 쿼터뷰 Stage 3: 무너진 성벽 (Ruined Crossbow Bastion)
## - 코발트 블루 황혼 앰비언스 (Color(0.25, 0.35, 0.55)) 및 3D HDR 발광
## - 무너진 성채 잔해 벽돌, 깨진 흉벽(Broken Battlements), 파괴된 고대 석기둥
## - 공중에 떠 있는 신비로운 부유 석편(Floating Stone Shards) 및 비전 에너지 램프
## - 웨이브 1: 원거리 석궁병 미니언 2기 스폰
## - 웨이브 2: 보스 석궁 사령관 (SideQVCrossbowCommander) 조우 및 격퇴 시 클리어

const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVCrossbowCommanderClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")

const TexWall = preload("res://assets/terrain_v2/wall.png")
const TexCitadel = preload("res://assets/terrain_v2/citadel.png")
const TexFlagstone = preload("res://assets/side_qv/flagstone_floor.png")
const TexBackdrop = preload("res://assets/stage_revision2/background.png")

var floating_stones: Array[Node3D] = []
var floating_time: float = 0.0


func _init() -> void:
	stage_index = 3
	stage_title = "무너진 성벽"
	arena_width = 38.0
	arena_depth = 12.0


func _process(delta: float) -> void:
	super._process(delta)
	floating_time += delta
	# 부유하는 돌 파편들의 신비로운 상하 부유 운동 (Levitation Bobbing)
	for i in range(floating_stones.size()):
		var stone := floating_stones[i]
		if is_instance_valid(stone):
			var base_y: float = stone.get_meta("base_y", stone.position.y)
			var phase_offset: float = stone.get_meta("phase_offset", 0.0)
			stone.position.y = base_y + sin(floating_time * 1.5 + phase_offset) * 0.18
			stone.rotation_degrees.y += delta * 12.0


# ==============================================================================
# 3D 환경 및 조명 구축 (코발트 블루 황혼)
# ==============================================================================
func _setup_3d_environment() -> void:
	# 1. WorldEnvironment (코발트 블루 황혼 앰비언스 & HDR Bloom)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.14, 0.26, 1.0) # 깊은 황혼 밤하늘
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.35, 0.55, 1.0) # 코발트 블루 황혼 앰비언스
	env.ambient_light_energy = 1.25

	# 3D HDR 발광 (Glow Bloom) & 황혼 코발트 안개 (Fog)
	env.glow_enabled = true
	env.set("glow_levels/1", 1.0)
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/4", 0.5)
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.24, 0.42, 1.0)
	env.fog_density = 0.015
	env.fog_aerial_perspective = 0.45
	world_env.environment = env
	add_child(world_env)

	# 2. 황혼 달빛/비전광 DirectionalLight3D
	var sun := DirectionalLight3D.new()
	sun.name = "TwilightMoonLight"
	sun.shadow_enabled = true
	sun.light_color = Color(0.68, 0.80, 1.0, 1.0) # 은은한 푸른빛 달빛
	sun.light_energy = 1.30
	sun.rotation_degrees = Vector3(-45.0, 38.0, 0.0)
	add_child(sun)

	# 3. 부유 석편 주변 비전 마력 포자 파티클 (CPUParticles3D)
	_spawn_stage_floating_particles("BastionArcaneSpores", Color(0.6, 1.6, 3.2, 0.88), Vector3(0.15, 0.35, 0.0), 60)


# ==============================================================================
# 3D 건축물 및 지형 구축 (무너진 성벽, 파괴된 돌기둥, 부유 석편)
# ==============================================================================
func _setup_3d_background_architecture() -> void:
	# 1. 원경 성채 파노라마 백드롭 (황혼 필터 적용)
	var backdrop_mesh := MeshInstance3D.new()
	backdrop_mesh.name = "RuinedBastionBackdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(62.0, 25.0)
	backdrop_mesh.mesh = quad

	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = TexBackdrop
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.65, 0.75, 1.0, 1.0) # 코발트 황혼 톤 틴팅
	bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop_mesh.material_override = bmat
	backdrop_mesh.position = Vector3(0.0, 3.8, -13.5)
	add_child(backdrop_mesh)

	# 2. 텍스처 석판 아레나 바닥
	var floor_box := CSGBox3D.new()
	floor_box.name = "ArenaFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World Layer
	floor_box.size = Vector3(arena_width, 1.0, arena_depth)
	floor_box.position.y = -0.5

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = TexFlagstone
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	floor_mat.albedo_color = Color(0.70, 0.75, 0.85, 1.0) # 차가운 석재 톤
	floor_mat.roughness = 0.75
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# 3. 무너진 흉벽 및 성채 잔해 (Broken Battlements)
	_build_broken_battlements()

	# 4. 파괴된 고대 성채 석기둥 (Crumbling Ruined Columns)
	_build_ruined_pillars()

	# 5. 신비로운 부유 석편 (Floating Stone Shards)
	_build_floating_stone_debris()

	# 6. 비전 룬 램프 (Arcane Lanterns)
	_build_arcane_lantern(Vector3(-12.0, 1.8, -arena_depth * 0.5 + 0.5))
	_build_arcane_lantern(Vector3(12.0, 1.8, -arena_depth * 0.5 + 0.5))
	_build_arcane_lantern(Vector3(0.0, 1.8, -arena_depth * 0.5 + 0.5))

	# 7. 전면 낮은 잔해 펜스
	var front_fence := CSGBox3D.new()
	front_fence.name = "FrontRubbleFence"
	front_fence.use_collision = true
	front_fence.collision_layer = 4
	front_fence.size = Vector3(arena_width, 0.5, 0.5)
	front_fence.position = Vector3(0.0, 0.25, arena_depth * 0.5)
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_texture = TexCitadel
	fence_mat.roughness = 0.8
	front_fence.material_override = fence_mat
	add_child(front_fence)


func _build_broken_battlements() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = TexWall
	wall_mat.uv1_scale = Vector3(2.0, 1.0, 1.0)
	wall_mat.roughness = 0.8

	# 무너진 불규칙 흉벽 세그먼트들 (구멍 뚫린 틈새로 원경이 보임)
	var segments := [
		{"pos": Vector3(-14.0, 0.8, -arena_depth * 0.5), "size": Vector3(7.0, 1.6, 0.8)},
		{"pos": Vector3(-7.0, 0.4, -arena_depth * 0.5), "size": Vector3(4.0, 0.8, 0.8)}, # 크게 무너진 틈
		{"pos": Vector3(-1.0, 1.0, -arena_depth * 0.5), "size": Vector3(6.0, 2.0, 0.8)},
		{"pos": Vector3(5.0, 0.5, -arena_depth * 0.5), "size": Vector3(4.5, 1.0, 0.8)},  # 파괴된 벽돌 틈
		{"pos": Vector3(12.5, 0.9, -arena_depth * 0.5), "size": Vector3(7.0, 1.8, 0.8)}
	]

	for i in range(segments.size()):
		var data: Dictionary = segments[i]
		var wall := CSGBox3D.new()
		wall.name = "BrokenWall_%d" % i
		wall.use_collision = true
		wall.collision_layer = 4
		wall.size = data["size"]
		wall.position = data["pos"]
		wall.material_override = wall_mat
		add_child(wall)

	# 흩어진 성채 잔해 벽돌 블록들
	var rubble_positions: Array[Vector3] = [
		Vector3(-8.5, 0.2, -4.8),
		Vector3(-5.0, 0.25, -5.2),
		Vector3(4.0, 0.18, -4.9),
		Vector3(7.5, 0.3, -5.3)
	]
	for r_pos: Vector3 in rubble_positions:
		var brick := CSGBox3D.new()
		brick.size = Vector3(0.9, 0.45, 0.7)
		brick.position = r_pos
		brick.rotation_degrees = Vector3(randf_range(-10, 10), randf_range(0, 180), randf_range(-10, 10))
		brick.material_override = wall_mat
		add_child(brick)


func _build_ruined_pillars() -> void:
	var col_mat := StandardMaterial3D.new()
	col_mat.albedo_texture = TexWall
	col_mat.uv1_scale = Vector3(1.0, 2.0, 1.0)
	col_mat.roughness = 0.75

	# 기둥 1: 좌측 후방 - 중간이 부러진 기둥 (높이 2.6m)
	_create_pillar_instance(Vector3(-11.0, 1.3, -3.2), Vector3(1.1, 2.6, 1.1), col_mat)
	_create_shattered_top(Vector3(-11.0, 2.7, -3.2), col_mat)

	# 기둥 2: 우측 후방 - 비교적 온전한 고대 기둥 (높이 4.6m)
	_create_pillar_instance(Vector3(11.0, 2.3, -3.2), Vector3(1.1, 4.6, 1.1), col_mat)

	# 기둥 3: 좌측 전방 - 밑동만 남은 파괴된 그루터기 기둥 (높이 1.2m)
	_create_pillar_instance(Vector3(-11.0, 0.6, 3.2), Vector3(1.1, 1.2, 1.1), col_mat)
	# 쓰러진 기둥 몸통 블록
	var fallen := CSGBox3D.new()
	fallen.size = Vector3(2.2, 0.9, 0.9)
	fallen.position = Vector3(-9.2, 0.45, 3.2)
	fallen.rotation_degrees.z = 8.0
	fallen.material_override = col_mat
	add_child(fallen)

	# 기둥 4: 우측 전방 - 파괴된 석재 밑동 기둥 (높이 1.1m, 시야 가림 방지)
	_create_pillar_instance(Vector3(11.0, 0.55, 3.2), Vector3(1.1, 1.1, 1.1), col_mat)


func _create_pillar_instance(pos: Vector3, size: Vector3, mat: Material) -> void:
	var col := CSGBox3D.new()
	col.size = size
	col.position = pos
	col.material_override = mat
	add_child(col)


func _create_shattered_top(pos: Vector3, mat: Material) -> void:
	var top := CSGBox3D.new()
	top.size = Vector3(1.3, 0.35, 1.3)
	top.position = pos
	top.rotation_degrees = Vector3(8.0, 15.0, -12.0)
	top.material_override = mat
	add_child(top)


func _build_floating_stone_debris() -> void:
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.35, 0.42, 0.58, 1.0)
	shard_mat.roughness = 0.65
	shard_mat.emission_enabled = true
	shard_mat.emission = Color(0.2, 0.5, 1.8, 1.0) # 균열 비전 발광
	shard_mat.emission_energy_multiplier = 1.6

	var shard_data := [
		{"pos": Vector3(-9.5, 2.2, -2.0), "size": Vector3(0.7, 0.5, 0.6)},
		{"pos": Vector3(-4.0, 2.8, -3.5), "size": Vector3(0.5, 0.6, 0.4)},
		{"pos": Vector3(2.5, 2.4, -2.8), "size": Vector3(0.8, 0.4, 0.5)},
		{"pos": Vector3(8.5, 3.0, -1.8), "size": Vector3(0.6, 0.7, 0.6)},
		{"pos": Vector3(-6.0, 1.8, 2.2), "size": Vector3(0.5, 0.4, 0.5)},
		{"pos": Vector3(6.5, 2.2, 2.5), "size": Vector3(0.6, 0.5, 0.4)}
	]

	for i in range(shard_data.size()):
		var data: Dictionary = shard_data[i]
		var shard := MeshInstance3D.new()
		shard.name = "FloatingShard_%d" % i
		var box := BoxMesh.new()
		box.size = data["size"]
		shard.mesh = box
		shard.material_override = shard_mat
		shard.position = data["pos"]
		shard.rotation_degrees = Vector3(randf_range(-30, 30), randf_range(0, 360), randf_range(-30, 30))

		shard.set_meta("base_y", data["pos"].y)
		shard.set_meta("phase_offset", float(i) * 1.1)

		floating_stones.append(shard)
		add_child(shard)


func _build_arcane_lantern(pos: Vector3) -> void:
	var post := CSGBox3D.new()
	post.size = Vector3(0.4, 1.8, 0.4)
	post.position = pos + Vector3(0, 0.9, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.18, 0.22, 0.28, 1.0)
	pmat.metallic = 0.8
	post.material_override = pmat
	add_child(post)

	# 룬 오브
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	orb.mesh = sphere
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.4, 1.2, 3.2, 1.0)
	omat.emission_enabled = true
	omat.emission = Color(0.4, 1.2, 3.2, 1.0)
	omat.emission_energy_multiplier = 4.0
	orb.material_override = omat
	orb.position = pos + Vector3(0, 1.9, 0)
	add_child(orb)

	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.70, 2.40)
	light.light_energy = 2.0
	light.omni_range = 5.5
	light.position = pos + Vector3(0, 1.9, 0)
	add_child(light)


# ==============================================================================
# 웨이브 1: 원거리 석궁병 미니언 2기 스폰
# ==============================================================================
func _spawn_wave_1_enemies() -> void:
	enemies.clear()

	var spawn_points := [
		Vector3(6.0, 0.1, 0.0),
		Vector3(8.5, 0.1, 0.0)
	]

	for i in range(spawn_points.size()):
		var minion := SideQVRangedMinionClass.new()
		minion.name = "RangedMinion_%d" % (i + 1)
		minion.position = spawn_points[i]
		minion.enemy_defeated.connect(_on_enemy_defeated)
		add_child(minion)
		enemies.append(minion)

	print(">>> [STAGE 3] Wave 1 Started: 2 Ranged Crossbow Minions Spawned <<<")


# ==============================================================================
# 웨이브 2: 보스 석궁 사령관 (SideQVCrossbowCommander) 스폰
# ==============================================================================
func _spawn_stage_boss() -> void:
	var commander := SideQVCrossbowCommanderClass.new()
	commander.name = "SideQVCrossbowCommander"
	var p_x: float = player.global_position.x if (player != null and is_instance_valid(player)) else 0.0
	var spawn_x: float = clampf(maxf(p_x + 5.5, 11.5), 10.0, arena_width * 0.5 - 2.5)
	commander.position = Vector3(spawn_x, 0.1, 0.0)
	commander.boss_defeated.connect(_on_boss_defeated)
	add_child(commander)
	active_boss = commander
	enemies.append(commander)

	print(">>> [STAGE 3] Wave 2 Started: SideQVCrossbowCommander Emerged! <<<")
