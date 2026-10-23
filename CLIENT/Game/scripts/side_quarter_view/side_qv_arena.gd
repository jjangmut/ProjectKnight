extends Node3D
class_name SideQVArena
## 사이드 쿼터뷰 2.5D 아레나 스테이지 (Side Quarter-View: 2D Characters + 3D Background)
## - 완전한 3D 석조 성채 배경 (3D 돌바닥, 3D 성벽, 3D 룬 기둥, 실시간 조명 및 그림자)
## - 2D 고해상도 스프라이트 플레이어, 적, 보스 캐릭터 연동

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const QVMobileControlsClass = preload("res://scripts/quarter_view/qv_mobile_controls.gd")

signal stage_cleared
signal boss_encountered

@export var arena_width: float = 40.0
@export var arena_depth: float = 14.0

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
	# 1. WorldEnvironment (3D HDR Glow Bloom & Lighting)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.08, 0.14, 1.0) # Midnight Castle Sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.40, 0.52, 1.0)
	env.ambient_light_energy = 1.2

	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.5
	world_env.environment = env
	add_child(world_env)

	# 2. Directional Sunlight with Shadows (Cast shadows from 2D sprites onto 3D floor)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.96, 0.88, 1.0)
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	add_child(sun)


func _setup_3d_background_architecture() -> void:
	# 1. 3D Stone Floor (CSGBox3D)
	var floor_box := CSGBox3D.new()
	floor_box.name = "ArenaFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World (Layer 3)
	floor_box.size = Vector3(arena_width, 1.0, arena_depth)
	floor_box.position.y = -0.5

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.22, 0.30, 1.0) # Slate Castle Stone
	floor_mat.roughness = 0.65
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# 2. 3D Castle Back Wall (Behind the action, showing immense depth)
	var wall_h := 6.5
	var back_wall := CSGBox3D.new()
	back_wall.name = "CastleBackWall"
	back_wall.use_collision = true
	back_wall.collision_layer = 4
	back_wall.size = Vector3(arena_width, wall_h, 1.2)
	back_wall.position = Vector3(0.0, wall_h * 0.5, -arena_depth * 0.5)

	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.24, 0.28, 0.38, 1.0)
	wmat.roughness = 0.8
	back_wall.material_override = wmat
	add_child(back_wall)

	# 3. 3D Front Low Balustrade (Foreground depth framing)
	var front_fence := CSGBox3D.new()
	front_fence.name = "FrontBalustrade"
	front_fence.use_collision = true
	front_fence.collision_layer = 4
	front_fence.size = Vector3(arena_width, 1.2, 0.6)
	front_fence.position = Vector3(0.0, 0.6, arena_depth * 0.5)
	front_fence.material_override = wmat
	add_child(front_fence)

	# 4. Side Boundary Walls
	_build_side_wall(Vector3(-arena_width * 0.5, wall_h * 0.5, 0.0), Vector3(1.0, wall_h, arena_depth))
	_build_side_wall(Vector3(arena_width * 0.5, wall_h * 0.5, 0.0), Vector3(1.0, wall_h, arena_depth))

	# 5. 4 Grand Ancient Runic Pillars
	_build_pillar(Vector3(-10.0, 0.0, -3.5), "Pillar_BackLeft")
	_build_pillar(Vector3(10.0, 0.0, -3.5), "Pillar_BackRight")
	_build_pillar(Vector3(-10.0, 0.0, 3.5), "Pillar_FrontLeft")
	_build_pillar(Vector3(10.0, 0.0, 3.5), "Pillar_FrontRight")

	# 6. Castle Torch Lights (Atmospheric OmniLight3D)
	_build_torch(Vector3(-6.0, 3.2, -arena_depth * 0.5 + 0.8))
	_build_torch(Vector3(6.0, 3.2, -arena_depth * 0.5 + 0.8))


func _build_side_wall(pos: Vector3, size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.use_collision = true
	wall.collision_layer = 4
	wall.size = size
	wall.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.24, 0.32, 1.0)
	wall.material_override = mat
	add_child(wall)


func _build_pillar(pos: Vector3, p_name: String) -> void:
	var pillar := CSGCylinder3D.new()
	pillar.name = p_name
	pillar.use_collision = true
	pillar.collision_layer = 4
	pillar.radius = 0.8
	pillar.height = 5.5
	pillar.position = pos + Vector3(0, 2.75, 0)

	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.28, 0.33, 0.44, 1.0)
	pillar.material_override = pmat
	add_child(pillar)

	# Glowing Cyan Runic Band
	var ring := CSGTorus3D.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 0.98
	ring.position = pos + Vector3(0, 2.5, 0)

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.4, 1.8, 2.5, 1.0)
	rmat.emission_enabled = true
	rmat.emission = Color(0.4, 1.8, 2.5, 1.0)
	rmat.emission_energy_multiplier = 3.0
	ring.material_override = rmat
	add_child(ring)


func _build_torch(pos: Vector3) -> void:
	var torch := OmniLight3D.new()
	torch.light_color = Color(1.8, 1.1, 0.4, 1.0) # Warm Torch Fire
	torch.light_energy = 2.2
	torch.omni_range = 8.0
	torch.position = pos
	add_child(torch)


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
