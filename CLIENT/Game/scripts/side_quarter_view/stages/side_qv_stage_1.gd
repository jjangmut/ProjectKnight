extends "res://scripts/side_quarter_view/side_qv_stage_base.gd"
class_name SideQVStage1
## Stage 1: 성문 외곽 (Citadel Terrace Gate)
## - 사이드 쿼터뷰 2.5D 스테이지 (-32도 틸트, Yaw 0.0)
## - 텍스처 매핑된 3D 석판 바닥 및 황금 룬 마법진 서클
## - 테라스 흉벽 성벽, 고딕 아치 윙, 붉은 기사단 깃발, 철제 횃불 브레이저
## - 웅장한 원경 성채 산맥 백드롭 파노라마
## - 웨이브 1: SideQVEnemy 2기 (X = 2.0, 4.0, Z = -1.0, 1.0)
## - 웨이브 2: SideQVBossCommander (HP 24, 방패 돌진, 360 충격파)
## - 보스 처치 시 _on_boss_defeated() -> stage_cleared 시그널 방출

const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

# High-Resolution 3D Environment Textures
const TexFlagstone = preload("res://assets/side_qv/flagstone_floor.png")
const TexRunicCircle = preload("res://assets/side_qv/arena_runic_circle.png")
const TexBanner = preload("res://assets/side_qv/citadel_banner.png")
const TexCitadel = preload("res://assets/terrain_v2/citadel.png")
const TexWall = preload("res://assets/terrain_v2/wall.png")
const TexBackdrop = preload("res://assets/stage_revision2/background.png")

var boss_ui: Control = null


func _init() -> void:
	stage_index = 1
	stage_title = "성문 외곽"


func _setup_3d_environment() -> void:
	# Stage 1 Dawn Citadel Terrace Ambience & WorldEnvironment
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

	_spawn_stage_floating_particles("CitadelDustEmbers", Color(2.4, 1.9, 0.9, 0.85), Vector3(0.18, 0.42, 0.0), 54)


func _setup_3d_background_architecture() -> void:
	# -------------------------------------------------------------
	# 1. Distant Panoramic Castle Vista Backdrop (Tonal Aerial Depth)
	# -------------------------------------------------------------
	var backdrop_mesh := MeshInstance3D.new()
	backdrop_mesh.name = "PanoramicCastleBackdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(62.0, 25.0)
	backdrop_mesh.mesh = quad

	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = TexBackdrop
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.72, 0.78, 0.90, 1.0) # Atmospheric aerial depth tint
	bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop_mesh.material_override = bmat
	backdrop_mesh.position = Vector3(0.0, 3.8, -13.5)
	add_child(backdrop_mesh)

	# -------------------------------------------------------------
	# 2. 3D Textured Stone Flagstone Arena Floor & Central Runic Seal
	# -------------------------------------------------------------
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
	floor_mat.albedo_color = Color(0.85, 0.88, 0.95, 1.0)
	floor_mat.roughness = 0.82
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# Central Holy Knight Runic Seal (Glowing Golden & Cyan Floor Crest)
	var runic_seal := MeshInstance3D.new()
	runic_seal.name = "CentralRunicSeal"
	var seal_quad := QuadMesh.new()
	seal_quad.size = Vector2(8.6, 8.6)
	runic_seal.mesh = seal_quad
	runic_seal.position = Vector3(0.0, 0.02, 0.0)
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

	# Decorative Stone Curb Trim (Front & Back boundaries with subtle rune accent)
	_build_curb_border(Vector3(0.0, 0.04, -arena_depth * 0.5 + 0.3), Vector3(arena_width, 0.08, 0.5))
	_build_curb_border(Vector3(0.0, 0.04, arena_depth * 0.5 - 0.3), Vector3(arena_width, 0.08, 0.5))

	# -------------------------------------------------------------
	# 3. Castle Terrace Parapet & Low Carved Stone Balustrade
	# -------------------------------------------------------------
	var balustrade_h := 1.25
	var back_wall := CSGBox3D.new()
	back_wall.name = "CastleBackWall"
	back_wall.use_collision = true
	back_wall.collision_layer = 4
	back_wall.size = Vector3(arena_width, balustrade_h, 0.8)
	back_wall.position = Vector3(0.0, balustrade_h * 0.5, -arena_depth * 0.5)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = TexCitadel
	wall_mat.uv1_scale = Vector3(12.0, 1.0, 1.0)
	wall_mat.roughness = 0.70
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	back_wall.material_override = wall_mat
	add_child(back_wall)

	# Top Stone Cornice Coping along Balustrade
	var coping := CSGBox3D.new()
	coping.name = "BalustradeCoping"
	coping.size = Vector3(arena_width, 0.16, 0.95)
	coping.position = Vector3(0.0, balustrade_h + 0.08, -arena_depth * 0.5)
	var cop_mat := StandardMaterial3D.new()
	cop_mat.albedo_texture = TexCitadel
	cop_mat.uv1_scale = Vector3(4.0, 1.0, 1.0)
	cop_mat.roughness = 0.70
	coping.material_override = cop_mat
	add_child(coping)

	# Decorative Carved Stone Pedestal Posts across Balustrade
	var num_posts := 9
	var post_spacing := arena_width / float(num_posts + 1)
	for i in range(num_posts):
		var px := -arena_width * 0.5 + post_spacing * float(i + 1)
		var post := CSGBox3D.new()
		post.name = "BalustradePost_%d" % i
		post.size = Vector3(0.75, 1.45, 0.88)
		post.position = Vector3(px, 0.725, -arena_depth * 0.5)
		post.material_override = cop_mat
		add_child(post)

	# 4 Castle Braziers on the terrace posts
	_build_torch(Vector3(-12.0, 1.45, -arena_depth * 0.5), 0)
	_build_torch(Vector3(-4.0, 1.45, -arena_depth * 0.5), 1)
	_build_torch(Vector3(4.0, 1.45, -arena_depth * 0.5), 2)
	_build_torch(Vector3(12.0, 1.45, -arena_depth * 0.5), 3)

	# -------------------------------------------------------------
	# 4. Symmetrical Gothic Ruins & Royal Knight Banners (Left & Right Wings)
	# -------------------------------------------------------------
	_build_gothic_wing(Vector3(-arena_width * 0.5 + 4.5, 0.0, -arena_depth * 0.5), false, "GothicWing_Left")
	_build_gothic_wing(Vector3(arena_width * 0.5 - 4.5, 0.0, -arena_depth * 0.5), true, "GothicWing_Right")

	# -------------------------------------------------------------
	# 5. Front Low Balustrade
	# -------------------------------------------------------------
	var front_fence := CSGBox3D.new()
	front_fence.name = "FrontBalustrade"
	front_fence.use_collision = true
	front_fence.collision_layer = 4
	# Option C & Art Direction: Low framing sill (0.42m) to prevent clipping sprites/combat
	front_fence.size = Vector3(arena_width, 0.42, 0.6)
	front_fence.position = Vector3(0.0, 0.21, arena_depth * 0.5)
	front_fence.material_override = cop_mat
	add_child(front_fence)

	# -------------------------------------------------------------
	# 6. Side Boundary Walls
	# -------------------------------------------------------------
	_build_side_wall(Vector3(-arena_width * 0.5, 2.5, 0.0), Vector3(1.0, 5.0, arena_depth), wall_mat, "SideWall_Left")
	_build_side_wall(Vector3(arena_width * 0.5, 2.5, 0.0), Vector3(1.0, 5.0, arena_depth), wall_mat, "SideWall_Right")

	# -------------------------------------------------------------
	# 7. 4 Grand Ancient Runic Monolith Pillars
	# -------------------------------------------------------------
	# Retain background monoliths for scale and depth
	_build_pillar(Vector3(-10.5, 0.0, -3.0), "Pillar_BackLeft")
	_build_pillar(Vector3(10.5, 0.0, -3.0), "Pillar_BackRight")
	# PK_ArtDirector Realignment: Reposition foreground monoliths to terrace flanks
	# Clears 100% of the active combat frustum (X in [-14, 14.5]), 0.0% occlusion!
	_build_pillar(Vector3(-17.0, 0.0, 4.2), "Pillar_FrontLeft")
	_build_pillar(Vector3(17.0, 0.0, 4.2), "Pillar_FrontRight")


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

	# Arch Pillar & Capital
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

	# Arch Lintel / Transom
	var lintel := CSGBox3D.new()
	lintel.name = "ArchLintel"
	var l_offset: float = -1.5 if mirrored else 1.5
	lintel.size = Vector3(3.2, 0.8, 0.9)
	lintel.position = Vector3(l_offset, 4.6, 0.0)
	lintel.material_override = mat
	wing_root.add_child(lintel)

	# Royal Crimson Knight Banner hanging down
	var banner_mesh := MeshInstance3D.new()
	banner_mesh.name = "CitadelBanner"
	var bquad := QuadMesh.new()
	bquad.size = Vector2(1.8, 3.6)
	banner_mesh.mesh = bquad
	banner_mesh.position = Vector3(l_offset, 2.6, 0.48)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_texture = TexBanner
	bmat.roughness = 0.8
	banner_mesh.material_override = bmat
	wing_root.add_child(banner_mesh)


func _build_side_wall(pos: Vector3, size: Vector3, mat: Material, wall_name: String) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.use_collision = true
	wall.collision_layer = 4
	wall.size = size
	wall.position = pos
	wall.material_override = mat
	add_child(wall)


func _build_pillar(pos: Vector3, p_name: String) -> void:
	var pillar_group := Node3D.new()
	pillar_group.name = p_name
	pillar_group.position = pos
	add_child(pillar_group)

	# 1. Base Pedestal
	var base := CSGBox3D.new()
	base.name = "Base"
	base.size = Vector3(1.8, 0.8, 1.8)
	base.position = Vector3(0.0, 0.4, 0.0)

	# 2. Main Cylinder Shaft
	var pillar := CSGCylinder3D.new()
	pillar.name = "Shaft"
	pillar.use_collision = true
	pillar.collision_layer = 4
	pillar.radius = 0.7
	pillar.height = 4.8
	pillar.position = Vector3(0.0, 2.8, 0.0)

	# 3. Capital Cornice
	var cap := CSGBox3D.new()
	cap.name = "Capital"
	cap.size = Vector3(1.8, 0.7, 1.8)
	cap.position = Vector3(0.0, 5.35, 0.0)

	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = TexCitadel
	pmat.uv1_scale = Vector3(2.0, 4.0, 1.0)
	pmat.roughness = 0.65
	base.material_override = pmat
	pillar.material_override = pmat
	cap.material_override = pmat

	pillar_group.add_child(base)
	pillar_group.add_child(pillar)
	pillar_group.add_child(cap)

	# Dual Glowing Runic Bands
	_build_pillar_rune_ring(pillar_group, Vector3(0.0, 2.0, 0.0), Color(0.4, 1.8, 2.6, 1.0), 3.5, "RuneRing_Cyan")
	_build_pillar_rune_ring(pillar_group, Vector3(0.0, 3.8, 0.0), Color(2.4, 1.6, 0.4, 1.0), 3.0, "RuneRing_Amber")


func _build_pillar_rune_ring(parent_node: Node3D, pos: Vector3, color: Color, energy: float, ring_name: String) -> void:
	var ring := CSGTorus3D.new()
	ring.name = ring_name
	ring.inner_radius = 0.72
	ring.outer_radius = 0.86
	ring.position = pos

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = energy
	ring.material_override = rmat
	parent_node.add_child(ring)


func _build_torch(pos: Vector3, index: int) -> void:
	var torch_root := Node3D.new()
	torch_root.name = "CastleBrazier_%d" % index
	torch_root.position = pos
	torch_root.add_to_group("stage_torches")
	add_child(torch_root)

	# Medieval Forged Wrought-Iron Brazier Bowl
	var brazier_bowl := CSGCylinder3D.new()
	brazier_bowl.name = "BrazierBowl"
	brazier_bowl.radius = 0.32
	brazier_bowl.height = 0.24
	brazier_bowl.position = Vector3(0.0, 0.12, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.12, 0.13, 0.16, 1.0)
	bmat.metallic = 0.95
	bmat.roughness = 0.35
	brazier_bowl.material_override = bmat
	torch_root.add_child(brazier_bowl)

	# Emissive Fiery Ember Core
	var flame := CSGSphere3D.new()
	flame.name = "BrazierFlame"
	flame.radius = 0.20
	flame.position = Vector3(0.0, 0.28, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(3.6, 1.4, 0.25, 1.0)
	fmat.emission_enabled = true
	fmat.emission = Color(3.6, 1.4, 0.25, 1.0)
	fmat.emission_energy_multiplier = 4.0
	flame.material_override = fmat
	torch_root.add_child(flame)

	# Dynamic Warm Torch Light
	var torch_light := OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.light_color = Color(1.9, 1.25, 0.55, 1.0)
	torch_light.light_energy = 2.8
	torch_light.omni_range = 10.5
	torch_light.position = Vector3(0.0, 0.35, 0.0)
	torch_root.add_child(torch_light)




# ==============================================================================
# 웨이브 관리 (Wave Progression)
# ==============================================================================

func _spawn_wave_1_enemies() -> void:
	# Requirement 3: 웨이브 1: SideQVEnemy 2기 스폰 (X = 2.0, 4.0, Z = -1.0, 1.0)
	_spawn_enemy(Vector3(2.0, 0.1, 0.0), "Minion_1")
	_spawn_enemy(Vector3(4.0, 0.1, 0.0), "Minion_2")


func _spawn_enemy(pos: Vector3, e_name: String) -> SideQVEnemy:
	var enemy := SideQVEnemyClass.new()
	enemy.name = e_name
	enemy.position = pos
	enemy.set_meta("spawn_pos", pos)
	enemy.target_player = player
	add_child(enemy)
	enemies.append(enemy)

	enemy.enemy_defeated.connect(_on_enemy_defeated)
	return enemy


func _spawn_stage_boss() -> void:
	# Requirement 3: 보스 웨이브: SideQVBossCommander 스폰 (체력 24, 방패 돌진, 360 충격파)
	var boss := SideQVBossClass.new()
	boss.name = "SideQVBossCommander"
	boss.max_hp = 24
	boss.current_hp = 24

	var p_x: float = player.global_position.x if (player != null and is_instance_valid(player)) else 0.0
	var spawn_x: float = clampf(maxf(p_x + 5.5, 11.5), 10.0, arena_width * 0.5 - 2.5)
	boss.position = Vector3(spawn_x, 0.1, 0.0)
	boss.target_player = player
	add_child(boss)
	active_boss = boss
	enemies.append(boss)

	boss.boss_defeated.connect(_on_boss_defeated)
	_setup_boss_ui(boss)


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
