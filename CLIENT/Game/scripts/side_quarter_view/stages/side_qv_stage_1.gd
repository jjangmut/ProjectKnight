extends "res://scripts/side_quarter_view/side_qv_stage_base.gd"
class_name SideQVStage1
## Stage 1: 성문 외곽 (Citadel Terrace Gate) — 2.5D Belt-Scroll Extended Vertical Slice
## - 완전한 2.5D 벨트스크롤 전장 (X: 100m 횡단 진행, Z: 6.4m 깊이 레인 기동)
## - 3개 대형 인카운터 관문(Encounter Gates) + 성채 고위 성소 보스 아레나
## - 일반 몬스터 총 12기 (근접 그런트 7기, 원거리 석궁병 3기, 중장 방패 기사 2기)
## - 환경 기믹: 바스티온 가시 마름쇠 트랩(Caltrop Hazard)
## - 보스: 성문 수호 기사단장 (3개 차별화 패턴: 지진 균열파, 방패 돌파 돌진, 360도 대회전 검격)

const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVCaltropTrapClass = preload("res://scripts/side_quarter_view/bosses/side_qv_caltrop_trap.gd")
const SideQVVitalityOrbClass = preload("res://scripts/side_quarter_view/side_qv_vitality_orb.gd")

# High-Resolution 3D Environment Textures
const TexFlagstone = preload("res://assets/side_qv/flagstone_floor.png")
const TexRunicCircle = preload("res://assets/side_qv/arena_runic_circle.png")
const TexBanner = preload("res://assets/side_qv/citadel_banner.png")
const TexCitadel = preload("res://assets/terrain_v2/citadel.png")
const TexWall = preload("res://assets/terrain_v2/wall.png")
const TexBackdrop = preload("res://assets/stage_revision2/background.png")

var boss_ui: Control = null
var current_encounter_idx: int = 0
var active_gate_barriers: Dictionary = {}
var hazard_traps: Array[Node3D] = []

# Stage Spatial Bounds (Extended 100m Corridor)
var stage_min_x: float = -12.0
var stage_max_x: float = 88.0
var stage_min_z: float = -3.2
var stage_max_z: float = 3.2

# Backward-compatibility aliases for corridor geometry
var stage_start_x: float = -12.0
var stage_end_x: float = 88.0
var corridor_min_z: float = -3.2
var corridor_max_z: float = 3.2


func _init() -> void:
	stage_index = 1
	stage_title = "성문 외곽"
	arena_width = 100.0
	arena_depth = 6.4


func _ready() -> void:
	_setup_3d_environment()
	_setup_3d_background_architecture()
	_ensure_arena_boundary_colliders()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()

	if player != null:
		player.position = Vector3(-6.0, 0.1, 0.0)
		_on_player_hp_changed(player.current_hp, player.max_hp)

	# Configure initial camera limits for Encounter 1
	if camera != null:
		camera.min_camera_x = -2.0
		camera.max_camera_x = 12.0

	_start_encounter_1()


func _setup_3d_environment() -> void:
	# Daylight Dawn Ambience & WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.65, 0.76, 0.90, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.92, 1.0)
	env.ambient_light_energy = 1.18
	env.glow_enabled = true
	env.set("glow_levels/1", 1.0)
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/4", 0.5)
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.62, 0.80, 1.0)
	env.fog_density = 0.016
	env.fog_aerial_perspective = 0.48
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.96, 0.90, 1.0)
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-46.0, -32.0, 0.0)
	add_child(sun)

	_spawn_stage_floating_particles("CitadelDustEmbers", Color(2.4, 1.9, 0.9, 0.85), Vector3(0.18, 0.42, 0.0), 64)


func _setup_3d_background_architecture() -> void:
	var total_w := stage_end_x - stage_start_x
	var center_x := (stage_start_x + stage_end_x) * 0.5

	# -------------------------------------------------------------
	# 1. Distant Panoramic Castle Vista Backdrop (Tiled Panorama across 100m)
	# -------------------------------------------------------------
	var num_backdrops := 3
	var backdrop_span := total_w / float(num_backdrops)
	for i in range(num_backdrops):
		var bx := stage_start_x + backdrop_span * (float(i) + 0.5)
		var backdrop_mesh := MeshInstance3D.new()
		backdrop_mesh.name = "PanoramicCastleBackdrop_%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(backdrop_span * 1.05, 26.0)
		backdrop_mesh.mesh = quad

		var bmat := StandardMaterial3D.new()
		bmat.albedo_texture = TexBackdrop
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color(0.72, 0.78, 0.90, 1.0)
		bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		backdrop_mesh.material_override = bmat
		backdrop_mesh.position = Vector3(bx, 4.2, -14.0)
		add_child(backdrop_mesh)

	# -------------------------------------------------------------
	# 2. 3D Textured Stone Flagstone Arena Floor (100m Corridor)
	# -------------------------------------------------------------
	var floor_box := CSGBox3D.new()
	floor_box.name = "CorridorFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World (Layer 3)
	floor_box.size = Vector3(total_w + 4.0, 1.0, arena_depth)
	floor_box.position = Vector3(center_x, -0.5, 0.0)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = TexFlagstone
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	floor_mat.albedo_color = Color(0.85, 0.88, 0.95, 1.0)
	floor_mat.roughness = 0.82
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# Decorative Golden Runic Seals at Key Landmarks
	_build_runic_seal(Vector3(-6.0, 0.02, 0.0), 6.4, "EntryRunicSeal")
	_build_runic_seal(Vector3(34.0, 0.02, 0.0), 6.4, "BastionRunicSeal")
	_build_runic_seal(Vector3(76.0, 0.02, 0.0), 8.6, "BossSanctuaryRunicSeal")

	# Decorative Curbs along Rear (Z = -3.2) and Front (Z = 3.2)
	_build_curb_border(Vector3(center_x, 0.04, corridor_min_z), Vector3(total_w + 4.0, 0.08, 0.4))
	_build_curb_border(Vector3(center_x, 0.04, corridor_max_z), Vector3(total_w + 4.0, 0.08, 0.4))

	# -------------------------------------------------------------
	# 3. Rear Castle Terrace Parapet Wall & Carved Balustrade
	# -------------------------------------------------------------
	var balustrade_h := 1.25
	var back_wall := CSGBox3D.new()
	back_wall.name = "CastleBackWall"
	back_wall.use_collision = true
	back_wall.collision_layer = 4
	back_wall.size = Vector3(total_w + 4.0, balustrade_h, 0.8)
	back_wall.position = Vector3(center_x, balustrade_h * 0.5, corridor_min_z)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = TexCitadel
	wall_mat.uv1_scale = Vector3(32.0, 1.0, 1.0)
	wall_mat.roughness = 0.70
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	back_wall.material_override = wall_mat
	add_child(back_wall)

	# Carved Balustrade Posts & Torches along back wall every 8m
	var num_posts := int(total_w / 8.0)
	for i in range(num_posts + 1):
		var px := stage_start_x + float(i) * 8.0
		var post := CSGBox3D.new()
		post.name = "ParapetPost_%d" % i
		post.size = Vector3(0.75, 1.45, 0.88)
		post.position = Vector3(px, 0.725, corridor_min_z)
		post.material_override = wall_mat
		add_child(post)
		if i % 2 == 0:
			_build_torch(Vector3(px, 1.45, corridor_min_z), i)

	# -------------------------------------------------------------
	# 4. Front Framing Low Balustrade Sill (0.42m height)
	# -------------------------------------------------------------
	var front_fence := CSGBox3D.new()
	front_fence.name = "FrontBalustrade"
	front_fence.use_collision = true
	front_fence.collision_layer = 4
	front_fence.size = Vector3(total_w + 4.0, 0.42, 0.5)
	front_fence.position = Vector3(center_x, 0.21, corridor_max_z)
	front_fence.material_override = wall_mat
	add_child(front_fence)

	# -------------------------------------------------------------
	# 5. Gothic Ruins & Royal Banners at Landmarks
	# -------------------------------------------------------------
	_build_gothic_wing(Vector3(-10.0, 0.0, corridor_min_z), false, "GothicWing_Start")
	_build_gothic_wing(Vector3(20.0, 0.0, corridor_min_z), false, "GothicWing_Bastion")
	_build_gothic_wing(Vector3(45.0, 0.0, corridor_min_z), false, "GothicWing_Terrace")
	_build_gothic_wing(Vector3(84.0, 0.0, corridor_min_z), true, "GothicWing_Boss")

	# Grand Ancient Runic Monolith Pillars along corridor flanks
	_build_pillar(Vector3(18.0, 0.0, corridor_min_z + 0.5), "GatePillar_1")
	_build_pillar(Vector3(44.0, 0.0, corridor_min_z + 0.5), "GatePillar_2")
	_build_pillar(Vector3(68.0, 0.0, corridor_min_z + 0.5), "GatePillar_3")
	_build_pillar(Vector3(76.0, 0.0, corridor_min_z + 0.5), "BossPillar_Rear")


func _build_runic_seal(pos: Vector3, seal_size: float, sname: String) -> void:
	var runic_seal := MeshInstance3D.new()
	runic_seal.name = sname
	var seal_quad := QuadMesh.new()
	seal_quad.size = Vector2(seal_size, seal_size)
	runic_seal.mesh = seal_quad
	runic_seal.position = pos
	runic_seal.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = TexRunicCircle
	smat.albedo_color = Color(1.0, 0.94, 0.70, 0.95)
	smat.emission_enabled = true
	smat.emission_texture = TexRunicCircle
	smat.emission_energy_multiplier = 3.6
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	runic_seal.material_override = smat
	add_child(runic_seal)


func _build_curb_border(pos: Vector3, size: Vector3) -> void:
	var curb := CSGBox3D.new()
	curb.size = size
	curb.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.46, 0.60, 1.0)
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.38, 0.72, 1.0)
	mat.emission_energy_multiplier = 1.35
	curb.material_override = mat
	add_child(curb)


func _build_gothic_wing(pos: Vector3, mirrored: bool, wing_name: String) -> void:
	var wing_root := Node3D.new()
	wing_root.name = wing_name
	wing_root.position = pos
	add_child(wing_root)

	var arch_p := CSGBox3D.new()
	arch_p.name = "ArchPillar"
	arch_p.size = Vector3(1.0, 4.6, 0.9)
	arch_p.position = Vector3(0.0, 2.3, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TexWall
	mat.uv1_scale = Vector3(1.0, 3.0, 1.0)
	mat.roughness = 0.7
	arch_p.material_override = mat
	wing_root.add_child(arch_p)

	# Banner
	var banner := MeshInstance3D.new()
	banner.name = "KnightBanner"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 2.6)
	banner.mesh = quad
	banner.position = Vector3(0.0, 2.2, 0.52)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_texture = TexBanner
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	banner.material_override = bmat
	wing_root.add_child(banner)


func _build_pillar(pos: Vector3, p_name: String) -> void:
	var pillar := Node3D.new()
	pillar.name = p_name
	pillar.position = pos
	add_child(pillar)

	var shaft := CSGBox3D.new()
	shaft.name = "PillarShaft"
	shaft.size = Vector3(1.35, 6.2, 1.35)
	shaft.position = Vector3(0.0, 3.1, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TexWall
	mat.uv1_scale = Vector3(1.0, 4.0, 1.0)
	mat.roughness = 0.65
	shaft.material_override = mat
	pillar.add_child(shaft)


func _build_torch(pos: Vector3, idx: int) -> void:
	var torch_root := Node3D.new()
	torch_root.name = "CitadelBrazier_%d" % idx
	torch_root.position = pos
	add_child(torch_root)

	var brazier := CSGBox3D.new()
	brazier.size = Vector3(0.65, 0.55, 0.65)
	brazier.position = Vector3(0.0, 0.28, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.12, 0.12, 0.15, 1.0)
	b_mat.metallic = 0.85
	b_mat.roughness = 0.35
	brazier.material_override = b_mat
	torch_root.add_child(brazier)

	var torch_light := OmniLight3D.new()
	torch_light.name = "BrazierLight"
	torch_light.light_color = Color(1.0, 0.72, 0.32, 1.0)
	torch_light.light_energy = 2.4
	torch_light.omni_range = 8.5
	torch_light.position = Vector3(0.0, 0.45, 0.0)
	torch_root.add_child(torch_light)


# ==============================================================================
# Spectral Barrier Gates (Progression Locks)
# ==============================================================================

func _create_gate_barrier(gate_id: String, gate_x: float) -> Node3D:
	if active_gate_barriers.has(gate_id):
		return active_gate_barriers[gate_id]

	var barrier_root := Node3D.new()
	barrier_root.name = "Barrier_" + gate_id
	barrier_root.position = Vector3(gate_x, 0.0, 0.0)

	# Physical barrier collider (prevents passing forward)
	var sb := StaticBody3D.new()
	sb.name = "BarrierCollider"
	sb.collision_layer = 4
	sb.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 6.0, arena_depth + 1.0)
	col.shape = box
	col.position = Vector3(0.0, 3.0, 0.0)
	sb.add_child(col)
	barrier_root.add_child(sb)

	# Visual spectral barrier wall
	var v_box := CSGBox3D.new()
	v_box.name = "SpectralWall"
	v_box.size = Vector3(0.35, 4.8, arena_depth)
	v_box.position = Vector3(0.0, 2.4, 0.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.8, 1.5, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.5, 1.0)
	mat.emission_energy_multiplier = 2.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	v_box.material_override = mat
	barrier_root.add_child(v_box)

	add_child(barrier_root)
	active_gate_barriers[gate_id] = barrier_root
	return barrier_root


func _dissolve_gate_barrier(gate_id: String) -> void:
	if not active_gate_barriers.has(gate_id):
		return
	var barrier: Node3D = active_gate_barriers[gate_id]
	active_gate_barriers.erase(gate_id)
	if is_instance_valid(barrier):
		var sb = barrier.get_node_or_null("BarrierCollider")
		if sb != null and is_instance_valid(sb):
			sb.queue_free()
		var tw := barrier.create_tween()
		if tw:
			var wall = barrier.get_node_or_null("SpectralWall")
			if wall != null and wall.material_override is StandardMaterial3D:
				tw.tween_property(wall.material_override, "albedo_color:a", 0.0, 0.45)
			tw.chain().tween_callback(barrier.queue_free)


# ==============================================================================
# 3-Encounter Progression + Boss Sanctuary
# ==============================================================================

func _start_encounter_1() -> void:
	current_encounter_idx = 1
	current_wave = 1
	_create_gate_barrier("Gate_1", 18.0)
	if camera != null:
		camera.min_camera_x = -2.0
		camera.max_camera_x = 12.0

	_show_stage_banner("ENCOUNTER 1: 성문 외곽 경비대", Color(0.2, 1.0, 1.4))

	# 3 Melee Grunts (Role 1: Melee Chaser)
	_spawn_enemy_grunt(Vector3(5.0, 0.1, -1.2), "Minion_Grunt_1")
	_spawn_enemy_grunt(Vector3(9.0, 0.1, 1.0), "Minion_Grunt_2")
	_spawn_enemy_grunt(Vector3(13.0, 0.1, -0.2), "Minion_Grunt_3")


func _start_encounter_2() -> void:
	current_encounter_idx = 2
	current_wave = 2
	_create_gate_barrier("Gate_2", 44.0)
	_create_gate_barrier("Gate_Behind_2", 16.0)
	if camera != null:
		camera.min_camera_x = 22.0
		camera.max_camera_x = 38.0

	_show_stage_banner("ENCOUNTER 2: 성벽 회랑 요격조", Color(1.4, 0.8, 0.2))

	# Environmental Caltrop Trap Hazard Cluster
	_spawn_caltrop_hazard(Vector3(29.0, 0.05, -1.2))
	_spawn_caltrop_hazard(Vector3(29.5, 0.05, 0.0))
	_spawn_caltrop_hazard(Vector3(30.0, 0.05, 1.2))

	# 2 Grunts + 2 Crossbowmen (Role 1: Melee + Role 3: Ranged Telegraph)
	_spawn_enemy_grunt(Vector3(25.0, 0.1, 1.2), "Minion_Grunt_4")
	_spawn_enemy_crossbow(Vector3(33.0, 0.1, -1.4), "Minion_Crossbow_1")
	_spawn_enemy_grunt(Vector3(36.0, 0.1, -0.6), "Minion_Grunt_5")
	_spawn_enemy_crossbow(Vector3(40.0, 0.1, 1.2), "Minion_Crossbow_2")


func _start_encounter_3() -> void:
	current_encounter_idx = 3
	current_wave = 3
	_create_gate_barrier("Gate_3", 68.0)
	_create_gate_barrier("Gate_Behind_3", 42.0)
	if camera != null:
		camera.min_camera_x = 48.0
		camera.max_camera_x = 62.0

	_show_stage_banner("ENCOUNTER 3: 테라스 중장 근위대", Color(1.5, 0.4, 0.4))

	# 2 Heavy Shield Knights + 2 Grunts + 1 Crossbowman (5 enemies)
	# Role 2: Heavy Shield Knight (Frontal guard, requires flanking / jump attack)
	_spawn_heavy_shield_knight(Vector3(52.0, 0.1, -1.0), "Knight_HeavyShield_1")
	_spawn_enemy_grunt(Vector3(55.0, 0.1, 1.2), "Minion_Grunt_6")
	_spawn_enemy_crossbow(Vector3(59.0, 0.1, 0.0), "Minion_Crossbow_3")
	_spawn_heavy_shield_knight(Vector3(62.0, 0.1, 1.0), "Knight_HeavyShield_2")
	_spawn_enemy_grunt(Vector3(65.0, 0.1, -1.2), "Minion_Grunt_7")


func _start_boss_sanctuary() -> void:
	current_encounter_idx = 4
	current_wave = 4
	_create_gate_barrier("Gate_Boss_Rear", 68.0)
	if camera != null:
		camera.min_camera_x = 74.0
		camera.max_camera_x = 78.0

	_show_stage_banner("BOSS: 성문 수호 기사단장", Color(2.5, 0.3, 0.3))
	_spawn_stage_boss()


# ==============================================================================
# Enemy Spawn Helpers
# ==============================================================================

func _spawn_enemy_grunt(pos: Vector3, e_name: String) -> SideQVEnemy:
	var enemy := SideQVEnemyClass.new()
	enemy.name = e_name
	enemy.position = pos
	enemy.target_player = player
	add_child(enemy)
	enemies.append(enemy)
	enemy.enemy_defeated.connect(_on_stage_enemy_defeated)
	return enemy


func _spawn_enemy_crossbow(pos: Vector3, e_name: String) -> SideQVRangedMinion:
	var enemy := SideQVRangedMinionClass.new()
	enemy.name = e_name
	enemy.position = pos
	enemy.target_player = player
	add_child(enemy)
	enemies.append(enemy)
	enemy.enemy_defeated.connect(_on_stage_enemy_defeated)
	return enemy


func _spawn_heavy_shield_knight(pos: Vector3, e_name: String) -> SideQVEliteKnight:
	var knight := SideQVEliteKnightClass.new()
	knight.name = e_name
	knight.position = pos
	knight.target_player = player
	add_child(knight)
	enemies.append(knight)
	knight.enemy_defeated.connect(_on_stage_enemy_defeated)
	return knight


func _spawn_caltrop_hazard(pos: Vector3) -> Node3D:
	var trap := SideQVCaltropTrapClass.new()
	add_child(trap)
	trap.setup(pos, self)
	hazard_traps.append(trap)
	return trap


func _spawn_stage_boss() -> void:
	var boss := SideQVBossClass.new()
	boss.name = "SideQVBossCommander"
	boss.max_hp = 38
	boss.current_hp = 38
	boss.position = Vector3(78.0, 0.1, 0.0)
	boss.target_player = player
	add_child(boss)
	active_boss = boss
	enemies.append(boss)

	boss.boss_defeated.connect(_on_boss_defeated)
	_setup_boss_ui(boss)


func _on_stage_enemy_defeated(defeated_enemy: Node) -> void:
	if defeated_enemy in enemies:
		enemies.erase(defeated_enemy)

	# Natural in-game vitality drop from defeated enemies
	if defeated_enemy != null and is_instance_valid(defeated_enemy) and defeated_enemy is Node3D:
		var drop_pos: Vector3 = (defeated_enemy as Node3D).global_position
		drop_pos.y = 0.45
		if defeated_enemy is SideQVEliteKnightClass or defeated_enemy is SideQVRangedMinionClass:
			_spawn_vitality_orb(drop_pos, 2)
		elif randf() < 0.60:
			_spawn_vitality_orb(drop_pos, 1)

	if enemies.is_empty():
		match current_encounter_idx:
			1:
				_dissolve_gate_barrier("Gate_1")
				if camera != null:
					camera.max_camera_x = 38.0
				_show_stage_banner("PROCEED >>", Color(0.2, 1.0, 0.4))
				_spawn_vitality_orb(Vector3(14.0, 0.45, 0.0), 2)
			2:
				_dissolve_gate_barrier("Gate_2")
				_dissolve_gate_barrier("Gate_Behind_2")
				if camera != null:
					camera.max_camera_x = 62.0
				_show_stage_banner("PROCEED >>", Color(0.2, 1.0, 0.4))
				_spawn_vitality_orb(Vector3(38.0, 0.45, 0.0), 2)
			3:
				_dissolve_gate_barrier("Gate_3")
				_dissolve_gate_barrier("Gate_Behind_3")
				if camera != null:
					camera.max_camera_x = 78.0
				_show_stage_banner("BOSS AHEAD >>", Color(1.0, 0.8, 0.2))
				_spawn_vitality_orb(Vector3(64.0, 0.45, 0.0), 3)


func _spawn_vitality_orb(pos: Vector3, heal_val: int = 2) -> SideQVVitalityOrb:
	var orb := SideQVVitalityOrbClass.new()
	orb.heal_amount = heal_val
	add_child(orb)
	orb.global_position = pos
	return orb


func _process(delta: float) -> void:
	# Progress bar tracking across 100m corridor
	if player != null and is_instance_valid(player) and progress_bar_fill != null:
		var p_x: float = player.global_position.x
		var ratio: float = clampf((p_x - (-6.0)) / (78.0 - (-6.0)), 0.0, 1.0)
		progress_bar_fill.size.x = 440.0 * ratio

		# Trigger next encounters when player traverses forward
		if current_encounter_idx == 1 and enemies.is_empty() and p_x >= 19.5:
			_start_encounter_2()
		elif current_encounter_idx == 2 and enemies.is_empty() and p_x >= 45.5:
			_start_encounter_3()
		elif current_encounter_idx == 3 and enemies.is_empty() and p_x >= 69.5:
			_start_boss_sanctuary()


func _show_stage_banner(text: String, color: Color) -> void:
	if mobile_controls == null:
		return
	var banner := Label.new()
	banner.name = "EncounterBanner"
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 80.0
	banner.offset_left = -300.0
	banner.offset_right = 300.0
	banner.offset_bottom = 120.0
	banner.add_theme_font_size_override("font_size", 24)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 2)
	mobile_controls.add_child(banner)

	var tw := banner.create_tween()
	if tw:
		banner.modulate.a = 0.0
		tw.tween_property(banner, "modulate:a", 1.0, 0.25)
		tw.tween_interval(1.8)
		tw.tween_property(banner, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(banner.queue_free)


func _setup_boss_ui(boss: Node3D) -> void:
	if boss_health_bar != null:
		boss_ui = boss_health_bar
		boss_health_bar.boss_name = "성문 수호 기사단장"
		boss_health_bar.attach_boss(boss)
		boss_health_bar.is_active = true
		boss_health_bar.modulate.a = 1.0
		return

	if mobile_controls == null:
		return

	boss_ui = Control.new()
	boss_ui.name = "BossUIContainer"
	boss_ui.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_ui.offset_top = 20.0
	boss_ui.offset_bottom = 80.0
	mobile_controls.add_child(boss_ui)

	var boss_title := Label.new()
	boss_title.name = "BossTitleLabel"
	boss_title.text = "성문 수호 기사단장"
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_title.offset_bottom = 26.0
	boss_title.add_theme_font_size_override("font_size", 22)
	boss_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65, 1.0))
	boss_ui.add_child(boss_title)

	var bar_bg := ColorRect.new()
	bar_bg.name = "BossHealthBarBG"
	bar_bg.color = Color(0.08, 0.08, 0.12, 0.85)
	bar_bg.custom_minimum_size = Vector2(500.0, 16.0)
	bar_bg.size = Vector2(500.0, 16.0)
	bar_bg.position = Vector2((1152.0 - 500.0) * 0.5, 32.0)
	boss_ui.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "BossHealthBarFill"
	bar_fill.color = Color(0.9, 0.18, 0.18, 0.95)
	bar_fill.custom_minimum_size = Vector2(500.0, 16.0)
	bar_fill.size = Vector2(500.0, 16.0)
	bar_fill.position = bar_bg.position
	boss_ui.add_child(bar_fill)

	if boss.has_signal("boss_hp_changed"):
		boss.connect("boss_hp_changed", func(cur_hp: int, m_hp: int):
			var ratio: float = clampf(float(cur_hp) / float(max(1, m_hp)), 0.0, 1.0)
			bar_fill.size.x = 500.0 * ratio
		)


func _on_boss_defeated(_boss: Node = null) -> void:
	if boss_ui != null and is_instance_valid(boss_ui):
		var tween := create_tween()
		if tween:
			tween.tween_property(boss_ui, "modulate:a", 0.0, 0.5)
	super._on_boss_defeated(_boss)
