extends Node3D
class_name SideQVArena
## 사이드 쿼터뷰 2.5D 아레나 스테이지 (Side Quarter-View: 2D Characters + Full High-End 3D Castle Citadel)
## - 텍스처 매핑된 3D 석판 바닥 (Sanctuary Paved Stone) 및 성채 테두리 림
## - 흉벽(Battlements)과 고딕 아치가 장식된 3D 거대 시타델 성벽
## - 성벽 너머로 펼쳐지는 웅장한 달밤 성채 산맥 파노라마 원경 (Panoramic Epic Castle Backdrop)
## - 고대 룬 기둥(Runic Monoliths), 중세 철제 횃불(Castle Torches & Warm Fire Glow)
## - 3D 대기 포그(Atmospheric Fog) 및 실시간 3D 햇빛 그림자

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const QVMobileControlsClass = preload("res://scripts/quarter_view/qv_mobile_controls.gd")

# High-Res Textures for 3D Environment
const TexFlagstone = preload("res://assets/side_qv/flagstone_floor.png")
const TexRunicCircle = preload("res://assets/side_qv/arena_runic_circle.png")
const TexBanner = preload("res://assets/side_qv/citadel_banner.png")
const TexCitadel = preload("res://assets/terrain_v2/citadel.png")
const TexWall = preload("res://assets/terrain_v2/wall.png")
const TexBackdrop = preload("res://assets/stage_revision2/background.png")

signal stage_cleared
signal boss_encountered

@export var arena_width: float = 38.0
@export var arena_depth: float = 12.0

var player: Node3D
var camera: Camera3D
var mobile_controls: CanvasLayer
var enemies: Array[Node3D] = []
var active_boss: Node3D = null

var current_wave: int = 0


func _ready() -> void:
	_setup_3d_environment()
	_setup_3d_background_architecture()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()
	_start_wave_1()


func _setup_3d_environment() -> void:
	# 1. WorldEnvironment (3D HDR Glow Bloom & Daylight Fantasy Sky)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.70, 0.80, 0.92, 1.0) # Clear Daylight Fantasy Sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.82, 1.0)
	env.ambient_light_energy = 1.15

	# 3D HDR Glow Bloom
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.4
	world_env.environment = env
	add_child(world_env)

	# 2. Directional Sunlight with Soft Real-time Shadows
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.97, 0.90, 1.0) # Warm Sunlight
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-46.0, -32.0, 0.0) # Light coming from upper-right matching backdrop
	add_child(sun)


func _setup_3d_background_architecture() -> void:
	# -------------------------------------------------------------
	# 1. Distant Panoramic Castle Vista Backdrop (Epic Vista)
	# -------------------------------------------------------------
	var backdrop_mesh := MeshInstance3D.new()
	backdrop_mesh.name = "PanoramicCastleBackdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(62.0, 25.0)
	backdrop_mesh.mesh = quad

	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = TexBackdrop
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 1.0, 1.0, 1.0) # Pristine Original Concept Art Brilliance
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
	floor_mat.roughness = 0.70
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
	smat.emission_enabled = true
	smat.emission_texture = TexRunicCircle
	smat.emission_energy_multiplier = 2.4
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	runic_seal.material_override = smat
	add_child(runic_seal)

	# Decorative Stone Curb Trim (Front & Back boundaries)
	_build_curb_border(Vector3(0.0, 0.04, -arena_depth * 0.5 + 0.3), Vector3(arena_width, 0.08, 0.5))
	_build_curb_border(Vector3(0.0, 0.04, arena_depth * 0.5 - 0.3), Vector3(arena_width, 0.08, 0.5))

	# -------------------------------------------------------------
	# 3. Castle Terrace Parapet & Low Carved Stone Balustrade (Back Vista Opening)
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
		post.size = Vector3(0.75, 1.45, 0.88)
		post.position = Vector3(px, 0.725, -arena_depth * 0.5)
		post.material_override = cop_mat
		add_child(post)

	# 4 Castle Braziers on the terrace posts
	_build_torch(Vector3(-12.0, 1.45, -arena_depth * 0.5))
	_build_torch(Vector3(-4.0, 1.45, -arena_depth * 0.5))
	_build_torch(Vector3(4.0, 1.45, -arena_depth * 0.5))
	_build_torch(Vector3(12.0, 1.45, -arena_depth * 0.5))

	# -------------------------------------------------------------
	# 4. Symmetrical Gothic Ruins & Royal Knight Banners (Left & Right Wings)
	# -------------------------------------------------------------
	_build_gothic_wing(Vector3(-arena_width * 0.5 + 4.5, 0.0, -arena_depth * 0.5), false)
	_build_gothic_wing(Vector3(arena_width * 0.5 - 4.5, 0.0, -arena_depth * 0.5), true)

	# -------------------------------------------------------------
	# 5. Front Low Balustrade
	# -------------------------------------------------------------
	var front_fence := CSGBox3D.new()
	front_fence.name = "FrontBalustrade"
	front_fence.use_collision = true
	front_fence.collision_layer = 4
	front_fence.size = Vector3(arena_width, 0.6, 0.6)
	front_fence.position = Vector3(0.0, 0.3, arena_depth * 0.5)
	front_fence.material_override = cop_mat
	add_child(front_fence)

	# -------------------------------------------------------------
	# 6. Side Boundary Walls
	# -------------------------------------------------------------
	_build_side_wall(Vector3(-arena_width * 0.5, 2.5, 0.0), Vector3(1.0, 5.0, arena_depth), wall_mat)
	_build_side_wall(Vector3(arena_width * 0.5, 2.5, 0.0), Vector3(1.0, 5.0, arena_depth), wall_mat)

	# -------------------------------------------------------------
	# 7. 4 Grand Ancient Runic Monolith Pillars
	# -------------------------------------------------------------
	_build_pillar(Vector3(-10.5, 0.0, -3.0), "Pillar_BackLeft")
	_build_pillar(Vector3(10.5, 0.0, -3.0), "Pillar_BackRight")
	_build_pillar(Vector3(-10.5, 0.0, 3.0), "Pillar_FrontLeft")
	_build_pillar(Vector3(10.5, 0.0, 3.0), "Pillar_FrontRight")


func _build_curb_border(pos: Vector3, size: Vector3) -> void:
	var curb := CSGBox3D.new()
	curb.size = size
	curb.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.42, 0.55, 1.0)
	mat.roughness = 0.5
	curb.material_override = mat
	add_child(curb)


func _build_gothic_wing(pos: Vector3, mirrored: bool) -> void:
	# Arch Pillar & Capital
	var arch_p := CSGBox3D.new()
	arch_p.size = Vector3(1.0, 4.6, 0.9)
	arch_p.position = pos + Vector3(0.0, 2.3, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TexWall
	mat.uv1_scale = Vector3(1.0, 3.0, 1.0)
	mat.roughness = 0.7
	arch_p.material_override = mat
	add_child(arch_p)

	# Arch Lintel / Transom
	var lintel := CSGBox3D.new()
	var l_offset: float = -1.5 if mirrored else 1.5
	lintel.size = Vector3(3.2, 0.8, 0.9)
	lintel.position = pos + Vector3(l_offset, 4.6, 0.0)
	lintel.material_override = mat
	add_child(lintel)

	# Royal Crimson Knight Banner hanging down
	var banner_mesh := MeshInstance3D.new()
	var bquad := QuadMesh.new()
	bquad.size = Vector2(1.8, 3.6)
	banner_mesh.mesh = bquad
	banner_mesh.position = pos + Vector3(l_offset, 2.6, 0.48)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_texture = TexBanner
	bmat.roughness = 0.8
	banner_mesh.material_override = bmat
	add_child(banner_mesh)


func _build_side_wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	var wall := CSGBox3D.new()
	wall.use_collision = true
	wall.collision_layer = 4
	wall.size = size
	wall.position = pos
	wall.material_override = mat
	add_child(wall)


func _build_pillar(pos: Vector3, p_name: String) -> void:
	# 1. Base Pedestal
	var base := CSGBox3D.new()
	base.size = Vector3(1.8, 0.8, 1.8)
	base.position = pos + Vector3(0.0, 0.4, 0.0)

	# 2. Main Cylinder Shaft
	var pillar := CSGCylinder3D.new()
	pillar.name = p_name
	pillar.use_collision = true
	pillar.collision_layer = 4
	pillar.radius = 0.7
	pillar.height = 4.8
	pillar.position = pos + Vector3(0.0, 2.8, 0.0)

	# 3. Capital Cornice
	var cap := CSGBox3D.new()
	cap.size = Vector3(1.8, 0.7, 1.8)
	cap.position = pos + Vector3(0.0, 5.35, 0.0)

	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = TexCitadel
	pmat.uv1_scale = Vector3(2.0, 4.0, 1.0)
	pmat.roughness = 0.65
	base.material_override = pmat
	pillar.material_override = pmat
	cap.material_override = pmat

	add_child(base)
	add_child(pillar)
	add_child(cap)

	# Dual Glowing Runic Bands
	_build_pillar_rune_ring(pos + Vector3(0.0, 2.0, 0.0), Color(0.4, 1.8, 2.6, 1.0), 3.5)
	_build_pillar_rune_ring(pos + Vector3(0.0, 3.8, 0.0), Color(2.4, 1.6, 0.4, 1.0), 3.0)


func _build_pillar_rune_ring(pos: Vector3, color: Color, energy: float) -> void:
	var ring := CSGTorus3D.new()
	ring.inner_radius = 0.72
	ring.outer_radius = 0.86
	ring.position = pos

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = energy
	ring.material_override = rmat
	add_child(ring)


func _build_torch(pos: Vector3) -> void:
	# Medieval Forged Wrought-Iron Brazier Bowl
	var brazier_bowl := CSGCylinder3D.new()
	brazier_bowl.radius = 0.32
	brazier_bowl.height = 0.24
	brazier_bowl.position = pos + Vector3(0.0, 0.12, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.12, 0.13, 0.16, 1.0) # Forged Black Iron
	bmat.metallic = 0.95
	bmat.roughness = 0.35
	brazier_bowl.material_override = bmat
	add_child(brazier_bowl)

	# Emissive Fiery Ember Core
	var flame := CSGSphere3D.new()
	flame.radius = 0.20
	flame.position = pos + Vector3(0.0, 0.28, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(3.6, 1.4, 0.25, 1.0) # Fiery Orange HDR
	fmat.emission_enabled = true
	fmat.emission = Color(3.6, 1.4, 0.25, 1.0)
	fmat.emission_energy_multiplier = 4.0
	flame.material_override = fmat
	add_child(flame)

	# Dynamic Warm Torch Light
	var torch_light := OmniLight3D.new()
	torch_light.light_color = Color(1.8, 1.2, 0.5, 1.0) # Warm Fire Light
	torch_light.light_energy = 2.4
	torch_light.omni_range = 9.0
	torch_light.position = pos + Vector3(0.0, 0.35, 0.0)
	add_child(torch_light)


func _spawn_player() -> void:
	player = SideQVPlayerClass.new()
	player.name = "SideQVPlayer"
	player.position = Vector3(-6.0, 0.1, 0.0)
	add_child(player)


func _setup_camera() -> void:
	camera = SideQVCameraClass.new()
	camera.name = "SideQVCamera"
	camera.target = player
	camera.base_pos = player.global_position + camera.camera_offset
	add_child(camera)


func _setup_mobile_ui() -> void:
	mobile_controls = QVMobileControlsClass.new()
	mobile_controls.name = "SideQVMobileControls"
	add_child(mobile_controls)


func _start_wave_1() -> void:
	current_wave = 1
	_spawn_enemy(Vector3(3.0, 0.1, -1.5))
	_spawn_enemy(Vector3(6.5, 0.1, 1.5))


func _spawn_enemy(pos: Vector3) -> Node3D:
	var enemy := SideQVEnemyClass.new()
	enemy.position = pos
	add_child(enemy)
	enemies.append(enemy)

	enemy.enemy_defeated.connect(func(e):
		enemies.erase(e)
		if enemies.is_empty() and current_wave == 1:
			_start_wave_2_boss()
	)
	return enemy


func _start_wave_2_boss() -> void:
	current_wave = 2
	emit_signal("boss_encountered")

	active_boss = SideQVBossClass.new()
	active_boss.name = "SideQVBossCommander"
	active_boss.position = Vector3(player.global_position.x + 8.0, 0.1, 0.0)
	add_child(active_boss)
	enemies.append(active_boss)

	active_boss.boss_defeated.connect(func(_b):
		emit_signal("stage_cleared")
	)
