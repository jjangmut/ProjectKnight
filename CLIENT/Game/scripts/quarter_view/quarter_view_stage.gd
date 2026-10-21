extends Node2D
class_name QuarterViewStage
## 쿼터뷰 2.5D 아레나 챔버 스테이지 (Quarter-View 2.5D Arena Stage)
## - Y-Sort 뎁스 소팅 엔진 통합
## - 4방향 고대 룬 결계 기둥 & 외곽 결계벽 (물리 충돌 및 Y-Sort 오버랩)
## - WorldEnvironment 2D Glow & CanvasModulate 미드나잇 앰비언스
## - 쿼터뷰 플레이어, 카메라, 적, 보스 라이프사이클 관리

const QVPlayerClass = preload("res://scripts/quarter_view/qv_player.gd")
const QVEnemyClass = preload("res://scripts/quarter_view/qv_enemy.gd")
const QVBossCommanderClass = preload("res://scripts/quarter_view/qv_boss_commander.gd")
const QVCameraClass = preload("res://scripts/quarter_view/qv_camera.gd")
const QVMobileControlsClass = preload("res://scripts/quarter_view/qv_mobile_controls.gd")

signal stage_cleared
signal boss_encountered

@export var arena_width: float = 1400.0
@export var arena_height: float = 900.0

var ysort_layer: Node2D
var player: Node2D
var camera: Camera2D
var mobile_controls: CanvasLayer
var enemies: Array[Node2D] = []
var active_boss: Node2D = null

var stage_state: int = 0 # 0: Playing, 1: Cleared, 2: GameOver
var current_wave: int = 0


func _ready() -> void:
	_setup_environment()
	_setup_arena_world()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()
	_start_wave_1()


func _setup_environment() -> void:
	# 1. WorldEnvironment 2D Glow
	var world_env := WorldEnvironment.new()
	world_env.name = "QVGlowEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.6
	world_env.environment = env
	add_child(world_env)

	# 2. CanvasModulate Midnight Atmosphere
	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "QVCatalogAtmosphere"
	canvas_mod.color = Color(0.88, 0.92, 1.0, 1.0) # Midnight Castle Tone
	add_child(canvas_mod)


func _setup_arena_world() -> void:
	# 1. Background Grid Floor (Not Y-sorted)
	var floor_bg := Node2D.new()
	floor_bg.name = "ArenaFloorBackground"
	add_child(floor_bg)

	# Draw isometric floor tiles using Line2D grid
	var grid_color := Color(0.12, 0.16, 0.24, 0.5)
	for x in range(int(-arena_width * 0.5), int(arena_width * 0.5), 100):
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = grid_color
		line.points = PackedVector2Array([Vector2(x, -arena_height * 0.5), Vector2(x, arena_height * 0.5)])
		floor_bg.add_child(line)

	for y in range(int(-arena_height * 0.5), int(arena_height * 0.5), 80):
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = grid_color
		line.points = PackedVector2Array([Vector2(-arena_width * 0.5, y), Vector2(arena_width * 0.5, y)])
		floor_bg.add_child(line)

	# 2. Main Y-Sort Depth Layer
	ysort_layer = Node2D.new()
	ysort_layer.name = "YSortEntityLayer"
	ysort_layer.y_sort_enabled = true
	add_child(ysort_layer)

	# 3. Outer Barrier Walls (StaticBody2D)
	_build_boundary_walls()

	# 4. 4 Ancient Runic Pillars (Y-Sorted Obstacles)
	_build_runic_pillar(Vector2(-320.0, -180.0), "Pillar_TopLeft")
	_build_runic_pillar(Vector2(320.0, -180.0), "Pillar_TopRight")
	_build_runic_pillar(Vector2(-320.0, 180.0), "Pillar_BottomLeft")
	_build_runic_pillar(Vector2(320.0, 180.0), "Pillar_BottomRight")


func _build_boundary_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "BoundaryWalls"
	walls.collision_layer = 4 # Walls
	walls.collision_mask = 0

	var half_w := arena_width * 0.5
	var half_h := arena_height * 0.5
	var wall_thickness := 40.0

	# Top, Bottom, Left, Right
	var wall_data := [
		[Vector2(0, -half_h - wall_thickness * 0.5), Vector2(arena_width + wall_thickness * 2, wall_thickness)],
		[Vector2(0, half_h + wall_thickness * 0.5), Vector2(arena_width + wall_thickness * 2, wall_thickness)],
		[Vector2(-half_w - wall_thickness * 0.5, 0), Vector2(wall_thickness, arena_height)],
		[Vector2(half_w + wall_thickness * 0.5, 0), Vector2(wall_thickness, arena_height)]
	]

	for data in wall_data:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = data[1]
		col.shape = rect
		col.position = data[0]
		walls.add_child(col)

	add_child(walls)


func _build_runic_pillar(pos: Vector2, pillar_name: String) -> void:
	var pillar := StaticBody2D.new()
	pillar.name = pillar_name
	pillar.global_position = pos
	pillar.collision_layer = 4 # Walls
	pillar.collision_mask = 0

	# Pillar Visual (Y-sorted, pivot at feet)
	var pillar_vis := Node2D.new()
	pillar_vis.name = "Visual"

	# Shadow
	var p_shadow := Line2D.new()
	p_shadow.width = 16.0
	p_shadow.default_color = Color(0.02, 0.02, 0.05, 0.5)
	p_shadow.points = PackedVector2Array([Vector2(-18.0, 0.0), Vector2(18.0, 0.0)])
	p_shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	p_shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	pillar_vis.add_child(p_shadow)

	# Pillar Column Sprite/Block
	var column := Line2D.new()
	column.width = 28.0
	column.default_color = Color(0.35, 0.45, 0.55, 1.0)
	column.points = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, -80.0)])
	column.begin_cap_mode = Line2D.LINE_CAP_ROUND
	column.end_cap_mode = Line2D.LINE_CAP_ROUND
	pillar_vis.add_child(column)

	# Runic Glowing Ring
	var rune := Line2D.new()
	rune.width = 4.0
	rune.default_color = Color(0.4, 1.6, 2.5, 0.9) # HDR Cyan Glow
	rune.points = PackedVector2Array([Vector2(-14.0, -40.0), Vector2(14.0, -40.0)])
	rune.begin_cap_mode = Line2D.LINE_CAP_ROUND
	rune.end_cap_mode = Line2D.LINE_CAP_ROUND
	pillar_vis.add_child(rune)

	pillar.add_child(pillar_vis)

	# Collision (small base at feet)
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 16.0
	col.shape = circ
	col.position = Vector2(0.0, -4.0)
	pillar.add_child(col)

	ysort_layer.add_child(pillar)


func _spawn_player() -> void:
	player = QVPlayerClass.new()
	player.name = "QVPlayer"
	player.global_position = Vector2(0.0, 80.0)
	player.add_to_group("player")
	ysort_layer.add_child(player)


func _setup_camera() -> void:
	camera = QVCameraClass.new()
	camera.name = "QVCamera"
	camera.target = player
	add_child(camera)
	camera.make_current()


func _setup_mobile_ui() -> void:
	mobile_controls = QVMobileControlsClass.new()
	mobile_controls.name = "QVMobileControls"
	add_child(mobile_controls)


func _start_wave_1() -> void:
	current_wave = 1
	# Spawn 2 quarter-view regular enemies
	_spawn_enemy(Vector2(-240.0, -100.0))
	_spawn_enemy(Vector2(240.0, -100.0))


func _spawn_enemy(pos: Vector2) -> Node2D:
	var enemy: Node2D = QVEnemyClass.new()
	enemy.global_position = pos
	enemy.enemy_died.connect(_on_enemy_died)
	ysort_layer.add_child(enemy)
	enemies.append(enemy)
	return enemy


func _on_enemy_died(enemy_node: Node) -> void:
	enemies.erase(enemy_node)
	if enemies.is_empty():
		if current_wave == 1:
			# Advance to Boss Wave
			_start_boss_wave()
		elif current_wave == 2:
			# Stage Cleared!
			stage_state = 1
			emit_signal("stage_cleared")


func _start_boss_wave() -> void:
	current_wave = 2
	emit_signal("boss_encountered")

	# Spawn Quarter-View Boss Commander
	active_boss = QVBossCommanderClass.new()
	active_boss.name = "QVBossCommander"
	active_boss.global_position = Vector2(0.0, -180.0)
	active_boss.boss_defeated.connect(_on_boss_defeated)
	ysort_layer.add_child(active_boss)
	enemies.append(active_boss)

	# Camera Shake upon boss roar
	if camera != null:
		camera.add_trauma(0.5)


func _on_boss_defeated(_boss_node: Node) -> void:
	enemies.erase(active_boss)
	active_boss = null
	stage_state = 1
	emit_signal("stage_cleared")
