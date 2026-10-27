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
const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")

const TexAvatarFrame = preload("res://assets/ui/hud_player_avatar_frame.png")
const TexSoulGemFull = preload("res://assets/ui/hud_soul_gem_full.png")
const TexSoulGemEmpty = preload("res://assets/ui/hud_soul_gem_empty.png")

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

# Comprehensive HUD Elements
var boss_health_bar: BossHealthBar = null
var player_hud: Control = null
var player_avatar_rect: TextureRect = null
var player_hp_label: Label = null
var soul_gem_rects: Array[TextureRect] = []
var advance_banner: Control = null
var progress_bar_fill: ColorRect = null
var advance_timer: float = 0.0


func _ready() -> void:
	_setup_3d_environment()
	_setup_3d_background_architecture()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()
	if player != null:
		_on_player_hp_changed(player.current_hp, player.max_hp)
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
	player.hp_changed.connect(_on_player_hp_changed)
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

	# 1. Top-Left Player HUD (Avatar, Stage Title, Soul Gem Crystals, HP text)
	player_hud = Control.new()
	player_hud.name = "PlayerHUD"
	player_hud.position = Vector2(24, 18)
	player_hud.custom_minimum_size = Vector2(300, 70)
	mobile_controls.add_child(player_hud)

	player_avatar_rect = TextureRect.new()
	player_avatar_rect.name = "PlayerAvatar"
	player_avatar_rect.texture = TexAvatarFrame
	player_avatar_rect.custom_minimum_size = Vector2(64, 64)
	player_avatar_rect.size = Vector2(64, 64)
	player_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_hud.add_child(player_avatar_rect)

	var title_lbl := Label.new()
	title_lbl.name = "StageTitleLabel"
	title_lbl.text = "STAGE %d: %s" % [stage_index, stage_title]
	title_lbl.position = Vector2(74, 4)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	player_hud.add_child(title_lbl)

	var gems_box := HBoxContainer.new()
	gems_box.name = "SoulGemsContainer"
	gems_box.position = Vector2(74, 30)
	gems_box.add_theme_constant_override("separation", 4)
	player_hud.add_child(gems_box)

	soul_gem_rects.clear()
	for i in range(5):
		var gem := TextureRect.new()
		gem.name = "SoulGem_%d" % i
		gem.texture = TexSoulGemFull
		gem.custom_minimum_size = Vector2(20, 24)
		gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gems_box.add_child(gem)
		soul_gem_rects.append(gem)

	player_hp_label = Label.new()
	player_hp_label.name = "PlayerHPLabel"
	player_hp_label.text = "5 / 5 HP"
	player_hp_label.position = Vector2(200, 32)
	player_hp_label.add_theme_font_size_override("font_size", 15)
	player_hp_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.75))
	player_hud.add_child(player_hp_label)

	# 2. Top-Center Stage Progress Bar
	var prog_root := Control.new()
	prog_root.name = "StageProgressBarRoot"
	prog_root.position = Vector2(400, 16)
	mobile_controls.add_child(prog_root)

	var prog_bg := ColorRect.new()
	prog_bg.name = "ProgressBarBG"
	prog_bg.size = Vector2(480, 8)
	prog_bg.color = Color(0.10, 0.10, 0.14, 0.85)
	prog_root.add_child(prog_bg)

	progress_bar_fill = ColorRect.new()
	progress_bar_fill.name = "ProgressBarFill"
	progress_bar_fill.size = Vector2(0, 8)
	progress_bar_fill.color = Color(1.0, 0.82, 0.28, 0.95)
	prog_root.add_child(progress_bar_fill)

	var start_lbl := Label.new()
	start_lbl.text = "START"
	start_lbl.position = Vector2(-42, -5)
	start_lbl.add_theme_font_size_override("font_size", 12)
	start_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	prog_root.add_child(start_lbl)

	var boss_lbl := Label.new()
	boss_lbl.text = "BOSS"
	boss_lbl.position = Vector2(488, -5)
	boss_lbl.add_theme_font_size_override("font_size", 12)
	boss_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	prog_root.add_child(boss_lbl)

	# 3. Gothic Winged Boss Health Bar
	boss_health_bar = BossHealthBarClass.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.position = Vector2((1280.0 - BossHealthBar.BAR_WIDTH) * 0.5, 28.0)
	mobile_controls.add_child(boss_health_bar)

	# Backward compatibility alias for Stage 5 smoke test
	var boss_ui_alias := Node.new()
	boss_ui_alias.name = "BossHealthBarUI"
	mobile_controls.add_child(boss_ui_alias)

	# 4. Advance Guidance Banner ("GO! ▶▶▶")
	advance_banner = Control.new()
	advance_banner.name = "AdvanceBanner"
	advance_banner.position = Vector2(1080, 290)
	advance_banner.visible = false
	mobile_controls.add_child(advance_banner)

	var go_lbl := Label.new()
	go_lbl.name = "GoLabel"
	go_lbl.text = "ADVANCE  ▶▶▶"
	go_lbl.add_theme_font_size_override("font_size", 24)
	go_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22, 1.0))
	go_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	go_lbl.add_theme_constant_override("shadow_offset_x", 2)
	go_lbl.add_theme_constant_override("shadow_offset_y", 2)
	advance_banner.add_child(go_lbl)


func _on_player_hp_changed(curr: int, m_hp: int) -> void:
	if player_hp_label != null:
		player_hp_label.text = "%d / %d HP" % [maxi(0, curr), m_hp]
	for i in range(soul_gem_rects.size()):
		if i < curr:
			soul_gem_rects[i].texture = TexSoulGemFull
		else:
			soul_gem_rects[i].texture = TexSoulGemEmpty
	if player_avatar_rect != null and curr < m_hp:
		var tw := create_tween()
		if tw:
			player_avatar_rect.modulate = Color(2.5, 0.4, 0.4)
			tw.tween_property(player_avatar_rect, "modulate", Color.WHITE, 0.2)


func _process(delta: float) -> void:
	# Update stage advancement progress bar
	if player != null and is_instance_valid(player) and progress_bar_fill != null:
		var p_x: float = player.global_position.x
		var ratio: float = clampf((p_x - (-8.0)) / (8.0 - (-8.0)), 0.0, 1.0)
		progress_bar_fill.size.x = 480.0 * ratio

	# Advance guidance when Wave 1 minions cleared
	if current_wave == 1 and enemies.is_empty() and not is_stage_finished:
		if advance_banner != null and not advance_banner.visible:
			advance_banner.visible = true
		advance_timer += delta * 6.0
		if advance_banner != null:
			advance_banner.modulate.a = 0.65 + 0.35 * sin(advance_timer)

		# Player advancing forward towards Boss
		if player != null and is_instance_valid(player) and player.global_position.x >= 2.0:
			_start_boss_wave()


func _get_boss_title() -> String:
	match stage_index:
		1: return "성문 수호 기사단장"
		2: return "야수숲 우두머리 추장"
		3: return "폐허의 석궁 사령관"
		4: return "티탄 골렘 가디언"
		5: return "심연의 중재자"
		_: return "보스 사령관"


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
	if advance_banner != null:
		advance_banner.visible = false
	_spawn_stage_boss()
	if active_boss != null:
		if boss_health_bar != null:
			boss_health_bar.boss_name = _get_boss_title()
			boss_health_bar.attach_boss(active_boss)
			boss_health_bar.is_active = true
			boss_health_bar.modulate.a = 1.0
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
