extends Node3D
class_name QuarterViewArena3D
## 쿼터뷰 3D 아레나 챔버 스테이지 (Quarter-View 3D Arena Stage)
## 3D PBR 석조 아레나, 4대 룬 기둥, DirectionalLight3D 실시간 섀도우, 3D 보스전 파이프라인

const QVPlayer3DClass = preload("res://scripts/quarter_view_3d/qv_player_3d.gd")
const QVEnemy3DClass = preload("res://scripts/quarter_view_3d/qv_enemy_3d.gd")
const QVBossCommander3DClass = preload("res://scripts/quarter_view_3d/qv_boss_commander_3d.gd")
const QVCamera3DClass = preload("res://scripts/quarter_view_3d/qv_camera_3d.gd")
const QVMobileControlsClass = preload("res://scripts/quarter_view/qv_mobile_controls.gd")

signal stage_cleared
signal boss_encountered

@export var arena_size: float = 30.0

var player: Node3D
var camera: Camera3D
var mobile_controls: CanvasLayer
var enemies: Array[Node3D] = []
var active_boss: Node3D = null

var stage_state: int = 0
var current_wave: int = 0


func _ready() -> void:
	_setup_3d_environment()
	_setup_arena_architecture()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()
	_start_wave_1()


func _setup_3d_environment() -> void:
	# 1. WorldEnvironment (3D Glow Bloom & Lighting)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.06, 0.1, 1.0) # Dark Midnight Sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.35, 0.45, 1.0)
	env.ambient_light_energy = 1.0

	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.6
	world_env.environment = env
	add_child(world_env)

	# 2. Directional Sunlight with Shadows
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.95, 0.85, 1.0)
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	add_child(sun)


func _setup_arena_architecture() -> void:
	# 1. 3D Floor (CSGBox3D)
	var floor_box := CSGBox3D.new()
	floor_box.name = "ArenaFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World (Layer 3)
	floor_box.size = Vector3(arena_size, 1.0, arena_size)
	floor_box.position.y = -0.5

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.16, 0.20, 0.28, 1.0) # Slate Stone Floor
	floor_mat.roughness = 0.7
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# 2. Outer Boundary Walls
	var wall_h := 3.0
	var half_s := arena_size * 0.5
	_build_wall(Vector3(0, wall_h * 0.5, -half_s), Vector3(arena_size, wall_h, 0.8))
	_build_wall(Vector3(0, wall_h * 0.5, half_s), Vector3(arena_size, wall_h, 0.8))
	_build_wall(Vector3(-half_s, wall_h * 0.5, 0), Vector3(0.8, wall_h, arena_size))
	_build_wall(Vector3(half_s, wall_h * 0.5, 0), Vector3(0.8, wall_h, arena_size))

	# 3. 4 Ancient Runic Pillars
	_build_pillar(Vector3(-7.0, 0, -7.0), "Pillar_TL")
	_build_pillar(Vector3(7.0, 0, -7.0), "Pillar_TR")
	_build_pillar(Vector3(-7.0, 0, 7.0), "Pillar_BL")
	_build_pillar(Vector3(7.0, 0, 7.0), "Pillar_BR")


func _build_wall(pos: Vector3, size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.use_collision = true
	wall.collision_layer = 4 # World
	wall.size = size
	wall.position = pos

	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.24, 0.28, 0.38, 1.0)
	wmat.roughness = 0.8
	wall.material_override = wmat
	add_child(wall)


func _build_pillar(pos: Vector3, p_name: String) -> void:
	var pillar := CSGCylinder3D.new()
	pillar.name = p_name
	pillar.use_collision = true
	pillar.collision_layer = 4 # World
	pillar.radius = 0.8
	pillar.height = 4.5
	pillar.position = pos + Vector3(0, 2.25, 0)

	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.3, 0.35, 0.45, 1.0)
	pmat.roughness = 0.6
	pillar.material_override = pmat
	add_child(pillar)

	# Glowing Runic Band
	var ring := CSGTorus3D.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 0.95
	ring.position = pos + Vector3(0, 2.0, 0)

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.4, 1.8, 2.5, 1.0)
	rmat.emission_enabled = true
	rmat.emission = Color(0.4, 1.8, 2.5, 1.0)
	rmat.emission_energy_multiplier = 2.5
	ring.material_override = rmat
	add_child(ring)


func _spawn_player() -> void:
	player = QVPlayer3DClass.new()
	player.name = "QVPlayer3D"
	player.position = Vector3(0.0, 0.1, 3.0)
	add_child(player)


func _setup_camera() -> void:
	camera = QVCamera3DClass.new()
	camera.name = "QVCamera3D"
	camera.target = player
	add_child(camera)


func _setup_mobile_ui() -> void:
	mobile_controls = QVMobileControlsClass.new()
	mobile_controls.name = "QVMobileControls"
	add_child(mobile_controls)


func _start_wave_1() -> void:
	current_wave = 1
	_spawn_enemy(Vector3(-5.0, 0.1, -4.0))
	_spawn_enemy(Vector3(5.0, 0.1, -4.0))


func _spawn_enemy(pos: Vector3) -> Node3D:
	var enemy: Node3D = QVEnemy3DClass.new()
	enemy.position = pos
	enemy.enemy_died.connect(_on_enemy_died)
	add_child(enemy)
	enemies.append(enemy)
	return enemy


func _on_enemy_died(enemy_node: Node) -> void:
	enemies.erase(enemy_node)
	if enemies.is_empty():
		if current_wave == 1:
			_start_boss_wave()
		elif current_wave == 2:
			stage_state = 1
			emit_signal("stage_cleared")


func _start_boss_wave() -> void:
	current_wave = 2
	emit_signal("boss_encountered")

	active_boss = QVBossCommander3DClass.new()
	active_boss.name = "QVBossCommander3D"
	active_boss.position = Vector3(0.0, 0.1, -6.5)
	active_boss.boss_defeated.connect(_on_boss_defeated)
	add_child(active_boss)
	enemies.append(active_boss)

	if camera != null and camera.has_method("add_trauma"):
		camera.add_trauma(0.5)


func _on_boss_defeated(_boss_node: Node) -> void:
	enemies.erase(active_boss)
	active_boss = null
	stage_state = 1
	emit_signal("stage_cleared")
