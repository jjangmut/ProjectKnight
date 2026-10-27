extends Node3D
class_name SideQVStageBase
## 사이드 쿼터뷰 스테이지 공통 기반 클래스 (Side Quarter-View Base Stage)
## 1~5 스테이지 공통:
## - 3D 뷰포트 / 월드 인바이런먼트 / 디렉셔널 선라이트
## - 사이드 쿼터뷰 카메라 (-32도 피치, Yaw 0.0 수평 뷰)
## - 2D 팔라딘 플레이어 (Sprite3D + 3D 콜리전 + 3D 그림자)
## - 모바일 컨트롤 UI & 보스 체력바
## - 웨이브 시스템: 웨이브 1 (일반 몬스터) -> 웨이브 2 (고유 보스) -> 스테이지 클리어

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const QVMobileControlsClass = preload("res://scripts/quarter_view/qv_mobile_controls.gd")

signal stage_cleared
signal stage_failed
signal boss_encountered(boss_node: Node3D)

@export var stage_index: int = 1
@export var stage_title: String = "Stage"
@export var arena_width: float = 38.0
@export var arena_depth: float = 12.0
@export var boss_wave_delay: float = 1.2
@export var clear_fanfare_delay: float = 2.0

var player: SideQVPlayer
var camera: SideQVCamera
var mobile_controls: CanvasLayer
var enemies: Array[Node3D] = []
var active_boss: Node3D = null

var current_wave: int = 0
var is_stage_finished: bool = false


func _ready() -> void:
	_setup_3d_environment()
	_setup_3d_background_architecture()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()
	_start_wave_1()


# ==============================================================================
# 가상 메서드 (자식 스테이지에서 오버라이드)
# ==============================================================================

func _setup_3d_environment() -> void:
	# 기본 Daylight 조명 및 WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.70, 0.80, 0.92, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.82, 1.0)
	env.ambient_light_energy = 1.15
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.4
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.97, 0.90, 1.0)
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-46.0, -32.0, 0.0)
	add_child(sun)


func _setup_3d_background_architecture() -> void:
	# 기본 바닥 생성
	var floor_box := CSGBox3D.new()
	floor_box.name = "ArenaFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4
	floor_box.size = Vector3(arena_width, 1.0, arena_depth)
	floor_box.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_box)


func _spawn_player() -> void:
	player = SideQVPlayerClass.new()
	player.name = "SideQVPlayer"
	player.position = Vector3(-8.0, 0.1, 0.0)
	player.died.connect(_on_player_died)
	add_child(player)


func _setup_camera() -> void:
	camera = SideQVCameraClass.new()
	camera.name = "SideQVCamera"
	camera.target = player
	camera.base_pos = player.global_position + camera.camera_offset
	add_child(camera)


func _setup_mobile_ui() -> void:
	mobile_controls = CanvasLayer.new()
	mobile_controls.name = "SideQVMobileUI"
	add_child(mobile_controls)

	# 스테이지 타이틀 배너
	var title_lbl := Label.new()
	title_lbl.name = "StageTitleLabel"
	title_lbl.text = "STAGE %d: %s" % [stage_index, stage_title]
	title_lbl.position = Vector2(24, 24)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	mobile_controls.add_child(title_lbl)


func _start_wave_1() -> void:
	current_wave = 1
	# 서브클래스에서 미니언 스폰 구현
	_spawn_wave_1_enemies()


func _spawn_wave_1_enemies() -> void:
	pass


func _start_boss_wave() -> void:
	if current_wave == 2 or is_stage_finished:
		return
	current_wave = 2
	_spawn_stage_boss()
	if active_boss != null:
		boss_encountered.emit(active_boss)
		if camera != null:
			camera.add_trauma(0.4)


func _spawn_stage_boss() -> void:
	pass


func _on_enemy_defeated(enemy: Node3D) -> void:
	enemies.erase(enemy)
	if current_wave == 1 and enemies.is_empty():
		# 웨이브 1 클리어 -> 잠시 후 보스 웨이브 시작
		await get_tree().create_timer(boss_wave_delay).timeout
		if not is_stage_finished and current_wave == 1:
			_start_boss_wave()


func _on_boss_defeated(_boss: Node = null) -> void:
	if is_stage_finished:
		return
	is_stage_finished = true
	if camera != null:
		camera.add_trauma(0.7)
	
	# 클리어 팡파르 연출
	var clear_lbl := Label.new()
	clear_lbl.text = "STAGE CLEARED!"
	clear_lbl.position = Vector2(480, 240)
	clear_lbl.add_theme_font_size_override("font_size", 42)
	clear_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	if mobile_controls != null:
		mobile_controls.add_child(clear_lbl)

	await get_tree().create_timer(clear_fanfare_delay).timeout
	stage_cleared.emit()


func _on_player_died() -> void:
	if is_stage_finished:
		return
	is_stage_finished = true
	stage_failed.emit()
