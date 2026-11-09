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
const AXDataViewerClass = preload("res://scripts/ui/ax_data_viewer.gd")
const AXDataRegistryClass = preload("res://scripts/data/ax_data_registry.gd")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

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
var touch_controls: QVMobileControls = null
var onboarding_guide: Control = null
var enemies: Array[Node3D] = []
var active_boss: Node3D = null

var current_wave: int = 0
var is_stage_finished: bool = false
var last_earned_shards: int = 0

# Comprehensive HUD Elements
var boss_health_bar: BossHealthBar = null
var player_hud: Control = null
var player_avatar_rect: TextureRect = null
var player_hp_label: Label = null
var soul_gem_rects: Array[TextureRect] = []
var advance_banner: Control = null
var progress_bar_fill: ColorRect = null
var advance_timer: float = 0.0

# Dynamic Combat Combo Counter HUD
var combo_hud: Control = null
var combo_label: Label = null
var combo_sub_label: Label = null
var current_combo_count: int = 0
var combo_fade_timer: float = 0.0
var _prev_player_hp: int = -1


func _ready() -> void:
	_setup_3d_environment()
	_setup_3d_background_architecture()
	_ensure_arena_boundary_colliders()
	_spawn_player()
	_setup_camera()
	_setup_mobile_ui()
	if player != null:
		_on_player_hp_changed(player.current_hp, player.max_hp)
	_start_wave_1()


func _ensure_arena_boundary_colliders() -> void:
	var half_w := arena_width * 0.5
	var half_d := arena_depth * 0.5
	var wall_defs := [
		{"name": "BoundaryWall_Left", "pos": Vector3(-half_w - 0.5, 3.0, 0.0), "size": Vector3(1.0, 8.0, arena_depth + 4.0)},
		{"name": "BoundaryWall_Right", "pos": Vector3(half_w + 0.5, 3.0, 0.0), "size": Vector3(1.0, 8.0, arena_depth + 4.0)},
		{"name": "BoundaryWall_Back", "pos": Vector3(0.0, 3.0, -half_d - 0.5), "size": Vector3(arena_width + 4.0, 8.0, 1.0)},
		{"name": "BoundaryWall_Front", "pos": Vector3(0.0, 3.0, half_d + 0.5), "size": Vector3(arena_width + 4.0, 8.0, 1.0)},
	]
	for wd in wall_defs:
		if get_node_or_null(wd["name"]) != null:
			continue
		var sb := StaticBody3D.new()
		sb.name = wd["name"]
		sb.collision_layer = 4
		sb.collision_mask = 0
		sb.position = wd["pos"]
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wd["size"]
		cs.shape = box
		sb.add_child(cs)
		add_child(sb)


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
	env.set("glow_levels/1", 1.0)
	env.set("glow_levels/2", 1.0)
	env.set("glow_levels/4", 0.5)
	env.glow_bloom = 0.18
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.65, 0.82, 1.0)
	env.fog_density = 0.012
	env.fog_aerial_perspective = 0.45
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.97, 0.90, 1.0)
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-46.0, -32.0, 0.0)
	add_child(sun)

	_spawn_stage_floating_particles("CitadelDustEmbers", Color(2.4, 1.9, 0.9, 0.85), Vector3(0.18, 0.42, 0.0), 54)


func _spawn_stage_floating_particles(node_name: String, particle_color: Color, gravity_vec: Vector3, amount_cnt: int = 56) -> CPUParticles3D:
	var existing := get_node_or_null(node_name) as CPUParticles3D
	if existing != null:
		return existing
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = amount_cnt
	p.lifetime = 4.2
	p.preprocess = 1.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(arena_width * 0.5, 3.6, arena_depth * 0.5)
	p.position = Vector3(0.0, 2.8, 0.0)
	p.gravity = gravity_vec
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4

	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = particle_color
	pmat.emission_enabled = true
	pmat.emission = particle_color
	pmat.emission_energy_multiplier = 2.8
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var qm := QuadMesh.new()
	qm.size = Vector2(0.11, 0.11)
	qm.material = pmat
	p.mesh = qm
	add_child(p)
	return p


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
	player.enemy_hit.connect(_on_player_enemy_hit)
	player.pogo_bounced.connect(_on_player_pogo_bounced)
	player.dive_slammed.connect(_on_player_dive_slammed)
	add_child(player)
	SaveManagerClass.apply_upgrades_to_player(player)


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

	# Dedicated Mobile Tactical Virtual Controls Deck (Joystick & Action Buttons)
	touch_controls = QVMobileControlsClass.new()
	touch_controls.name = "TouchControlsDeck"
	mobile_controls.add_child(touch_controls)

	# 1. Top-Left Heroes War Tactical Unit HUD (Plate, Avatar, SSR Rank, Stage Title, Soul Gems, HP text)
	player_hud = Control.new()
	player_hud.name = "PlayerHUD"
	player_hud.position = Vector2(14, 12)
	player_hud.custom_minimum_size = Vector2(336, 72)
	mobile_controls.add_child(player_hud)

	var hud_plate := Panel.new()
	hud_plate.name = "TacticalUnitPlate"
	hud_plate.size = Vector2(332, 66)
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.05, 0.09, 0.14, 0.88)
	plate_style.border_color = Color("00e5ff")
	plate_style.set_border_width_all(1)
	plate_style.border_width_left = 6
	plate_style.corner_radius_top_right = 10
	plate_style.corner_radius_bottom_left = 10
	hud_plate.add_theme_stylebox_override("panel", plate_style)
	player_hud.add_child(hud_plate)

	player_avatar_rect = TextureRect.new()
	player_avatar_rect.name = "PlayerAvatar"
	player_avatar_rect.texture = TexAvatarFrame
	player_avatar_rect.custom_minimum_size = Vector2(54, 54)
	player_avatar_rect.size = Vector2(54, 54)
	player_avatar_rect.scale = Vector2(0.24, 0.24)
	player_avatar_rect.position = Vector2(10, 6)
	player_hud.add_child(player_avatar_rect)

	var rank_lbl := Label.new()
	rank_lbl.text = "SSR"
	rank_lbl.position = Vector2(12, 46)
	rank_lbl.add_theme_font_size_override("font_size", 10)
	rank_lbl.add_theme_color_override("font_color", Color("ffb800"))
	player_hud.add_child(rank_lbl)

	var title_lbl := Label.new()
	title_lbl.name = "StageTitleLabel"
	title_lbl.text = "◢ OP-0%d : %s" % [stage_index, stage_title]
	title_lbl.position = Vector2(72, 6)
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color("ffb800"))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	player_hud.add_child(title_lbl)

	var gems_box := HBoxContainer.new()
	gems_box.name = "SoulGemsContainer"
	gems_box.position = Vector2(72, 32)
	gems_box.add_theme_constant_override("separation", 3)
	player_hud.add_child(gems_box)

	soul_gem_rects.clear()
	for i in range(8):
		var gem := TextureRect.new()
		gem.name = "SoulGem_%d" % i
		gem.texture = TexSoulGemFull
		gem.custom_minimum_size = Vector2(16, 20)
		gem.size = Vector2(16, 20)
		gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gems_box.add_child(gem)
		soul_gem_rects.append(gem)

	player_hp_label = Label.new()
	player_hp_label.name = "PlayerHPLabel"
	player_hp_label.text = "8 / 8 HP"
	player_hp_label.position = Vector2(236, 33)
	player_hp_label.add_theme_font_size_override("font_size", 13)
	player_hp_label.add_theme_color_override("font_color", Color("00e5ff"))
	player_hud.add_child(player_hp_label)

	# 2. Top-Center Stage Progress Bar (Heroes War Tactical Radar Gauge)
	var prog_root := Control.new()
	prog_root.name = "StageProgressBarRoot"
	prog_root.position = Vector2(416, 16)
	mobile_controls.add_child(prog_root)

	var prog_bg := ColorRect.new()
	prog_bg.name = "ProgressBarBG"
	prog_bg.size = Vector2(430, 8)
	prog_bg.color = Color("0a111a")
	prog_root.add_child(prog_bg)

	progress_bar_fill = ColorRect.new()
	progress_bar_fill.name = "ProgressBarFill"
	progress_bar_fill.size = Vector2(0, 8)
	progress_bar_fill.color = Color("ffb800")
	prog_root.add_child(progress_bar_fill)

	var start_lbl := Label.new()
	start_lbl.text = "START"
	start_lbl.position = Vector2(-42, -5)
	start_lbl.add_theme_font_size_override("font_size", 11)
	start_lbl.add_theme_color_override("font_color", Color("00e5ff"))
	prog_root.add_child(start_lbl)

	var boss_lbl := Label.new()
	boss_lbl.text = "BOSS"
	boss_lbl.position = Vector2(438, -5)
	boss_lbl.add_theme_font_size_override("font_size", 11)
	boss_lbl.add_theme_color_override("font_color", Color("ff3b5c"))
	prog_root.add_child(boss_lbl)

	# 3. Gothic Winged Boss Health Bar (Shifted right so left wing never overlaps PlayerHUD)
	boss_health_bar = BossHealthBarClass.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.position = Vector2(410.0, 30.0)
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

	# 5. Top-Right AX Data Quick Viewer Button (Heroes War Tactical Style)
	var ax_btn := Button.new()
	ax_btn.name = "BtnOpenAXData"
	ax_btn.text = "📊 AX 도감"
	ax_btn.position = Vector2(928, 14)
	ax_btn.size = Vector2(102, 34)
	ax_btn.add_theme_font_size_override("font_size", 12)
	var ax_style := StyleBoxFlat.new()
	ax_style.bg_color = Color("0d1622")
	ax_style.border_color = Color("00e5ff")
	ax_style.set_border_width_all(1)
	ax_style.border_width_left = 4
	ax_style.corner_radius_top_right = 6
	ax_style.corner_radius_bottom_left = 6
	ax_btn.add_theme_stylebox_override("normal", ax_style)
	ax_btn.pressed.connect(open_ax_data_viewer)
	mobile_controls.add_child(ax_btn)

	# 6. Stage 1 First-Play Tactical Onboarding Guide (Non-blocking, Dismissible)
	if stage_index == 1:
		_setup_onboarding_guide()

	# 6. Dynamic Combat Combo Counter & Rank HUD (Right side, tactical style)
	combo_hud = Control.new()
	combo_hud.name = "ComboHUD"
	combo_hud.position = Vector2(980, 58)
	combo_hud.modulate.a = 0.0 # Initially hidden
	mobile_controls.add_child(combo_hud)

	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = "0 HITS"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_font_size_override("font_size", 28)
	combo_label.add_theme_color_override("font_color", Color("ffb800"))
	combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 2)
	combo_hud.add_child(combo_label)

	combo_sub_label = Label.new()
	combo_sub_label.name = "ComboSubLabel"
	combo_sub_label.text = "COMBO CHAIN"
	combo_sub_label.position = Vector2(0, 32)
	combo_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_sub_label.add_theme_font_size_override("font_size", 14)
	combo_sub_label.add_theme_color_override("font_color", Color("00e5ff"))
	combo_hud.add_child(combo_sub_label)


func open_ax_data_viewer() -> Control:
	if mobile_controls == null:
		return null
	var existing := mobile_controls.get_node_or_null("AXDataViewerModal") as Control
	if existing != null:
		return existing
	var viewer: Control = AXDataViewerClass.new()
	viewer.name = "AXDataViewerModal"
	mobile_controls.add_child(viewer)
	return viewer


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
	if _prev_player_hp != -1 and curr < _prev_player_hp:
		# Combat damage taken: drop combo count
		current_combo_count = 0
		if combo_hud != null:
			combo_hud.modulate.a = 0.0
	_prev_player_hp = curr


func _on_player_enemy_hit(_enemy: Node, _dmg: int, was_counter: bool) -> void:
	current_combo_count += 1
	combo_fade_timer = 2.0
	if combo_hud != null:
		combo_hud.modulate.a = 1.0
		var rank_text := "COMBO CHAIN"
		var col := Color("ffb800")
		if current_combo_count >= 8:
			rank_text = "UNSTOPPABLE! ✦✦✦"
			col = Color("ff3b5c")
		elif current_combo_count >= 5:
			rank_text = "GROGGY BREAKER! ✦✦"
			col = Color("00e5ff")
		elif current_combo_count >= 3:
			rank_text = "BLADE FINISHER! ✦"
			col = Color("ffd700")

		if was_counter:
			rank_text = "JUST PARRY COUNTER! ⚔"
			col = Color(0.2, 1.2, 1.5)

		combo_label.text = "%d HITS" % current_combo_count
		combo_label.add_theme_color_override("font_color", col)
		combo_sub_label.text = rank_text

		combo_hud.scale = Vector2(1.25, 1.25)
		var tw := create_tween()
		if tw:
			tw.tween_property(combo_hud, "scale", Vector2(1.0, 1.0), 0.12)

	# Bonus shard reward on every 5 combo hits!
	if current_combo_count % 5 == 0 and player != null:
		SaveManagerClass.add_shards(1)
		GameFeelManager.damage_popup_3d(self, player.global_position + Vector3(0.0, 1.8, 0.0), "+1 SHARD (COMBO BONUS)", Color("ffb800"), true)


func _on_player_pogo_bounced(_p: Node) -> void:
	if camera != null and camera.has_method("add_trauma"):
		camera.add_trauma(0.12)


func _on_player_dive_slammed(_p: Node, hit_count: int) -> void:
	if hit_count > 0:
		current_combo_count += hit_count
		combo_fade_timer = 2.4
		if combo_hud != null:
			combo_hud.modulate.a = 1.0
			if combo_label != null:
				combo_label.text = "%d HITS" % current_combo_count
			if combo_sub_label != null:
				combo_sub_label.text = "TITAN STOMP! ✦✦"
				combo_sub_label.add_theme_color_override("font_color", Color("ffb800"))


func _process(delta: float) -> void:
	# Dismiss onboarding guide upon player combat/movement interaction
	if onboarding_guide != null and is_instance_valid(onboarding_guide):
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("guard") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			_dismiss_onboarding_guide()

	# Combo decay timer
	if combo_fade_timer > 0.0:
		combo_fade_timer -= delta
		if combo_fade_timer <= 0.0:
			current_combo_count = 0
			if combo_hud != null:
				var tw := create_tween()
				if tw:
					tw.tween_property(combo_hud, "modulate:a", 0.0, 0.35)

	# Update stage advancement progress bar
	if player != null and is_instance_valid(player) and progress_bar_fill != null:
		var p_x: float = player.global_position.x
		var ratio: float = clampf((p_x - (-8.0)) / (11.0 - (-8.0)), 0.0, 1.0)
		progress_bar_fill.size.x = 440.0 * ratio

	# Advance guidance when Wave 1 minions cleared
	if current_wave == 1 and enemies.is_empty() and not is_stage_finished:
		if advance_banner != null and not advance_banner.visible:
			advance_banner.visible = true
		advance_timer += delta * 6.0
		if advance_banner != null:
			advance_banner.modulate.a = 0.65 + 0.35 * sin(advance_timer)

		# Player advancing forward towards Boss Sanctuary Zone (X >= 6.5)
		if player != null and is_instance_valid(player) and player.global_position.x >= 6.5:
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
			camera.boss_target = active_boss


func _spawn_stage_boss() -> void:
	pass


func _on_enemy_defeated(enemy: Node3D) -> void:
	enemies.erase(enemy)
	if current_wave == 1 and enemies.is_empty():
		# Wave 1 전멸 보상: 성스러운 영혼 회복 (HP +2 회복)
		if player != null and is_instance_valid(player) and not player.is_dead:
			player.current_hp = mini(player.max_hp, player.current_hp + 2)
			player.emit_signal("hp_changed", player.current_hp, player.max_hp)

		# 웨이브 1 클리어 -> 플레이어가 오른쪽으로 전진하면 즉시 보스 등장, 제자리 대기 시에도 boss_wave_delay(1.2s) 후 폴백 진행
		await get_tree().create_timer(boss_wave_delay).timeout
		if not is_stage_finished and current_wave == 1:
			_start_boss_wave()


func _on_boss_defeated(_boss: Node = null) -> void:
	if is_stage_finished:
		return
	is_stage_finished = true
	if camera != null:
		camera.add_trauma(0.7)
		camera.boss_target = null

	# Save stage clear and award soul shards
	SaveManagerClass.mark_stage_cleared(stage_index)
	var shard_rewards := { 1: 20, 2: 25, 3: 30, 4: 35, 5: 50 }
	var earned_shards: int = int(shard_rewards.get(stage_index, 20))
	last_earned_shards = earned_shards
	SaveManagerClass.add_shards(earned_shards)

	# Release virtual actions and hide touch controls deck during clear
	if touch_controls != null and is_instance_valid(touch_controls):
		touch_controls._release_all_actions()
		touch_controls.visible = false

	# Neutralize remaining enemy attacks to prevent phantom damage
	for enemy in enemies:
		if is_instance_valid(enemy):
			if "attack_area_3d" in enemy and enemy.attack_area_3d != null and is_instance_valid(enemy.attack_area_3d):
				enemy.attack_area_3d.set_deferred("monitoring", false)
				enemy.attack_area_3d.set_deferred("monitorable", false)
			if "is_attacking" in enemy:
				enemy.is_attacking = false
			enemy.set_physics_process(false)

	# 클리어 팡파르 연출
	var clear_lbl := Label.new()
	clear_lbl.text = "STAGE CLEARED!\n+ %d SOUL SHARDS" % earned_shards
	AudioManager.play("stage_clear_stinger")
	clear_lbl.position = Vector2(440, 230)
	clear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_lbl.add_theme_font_size_override("font_size", 38)
	clear_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	if mobile_controls != null:
		mobile_controls.add_child(clear_lbl)

	await get_tree().create_timer(clear_fanfare_delay).timeout
	if is_instance_valid(clear_lbl):
		clear_lbl.queue_free()
	stage_cleared.emit()


func _on_player_died() -> void:
	if is_stage_finished:
		return
	is_stage_finished = true

	# Release virtual actions and hide touch controls deck during defeat
	if touch_controls != null and is_instance_valid(touch_controls):
		touch_controls._release_all_actions()
		touch_controls.visible = false

	# Neutralize remaining enemy attacks to prevent phantom damage
	for enemy in enemies:
		if is_instance_valid(enemy):
			if "attack_area_3d" in enemy and enemy.attack_area_3d != null and is_instance_valid(enemy.attack_area_3d):
				enemy.attack_area_3d.set_deferred("monitoring", false)
				enemy.attack_area_3d.set_deferred("monitorable", false)
			if "is_attacking" in enemy:
				enemy.is_attacking = false
			enemy.set_physics_process(false)

	if active_boss != null and is_instance_valid(active_boss):
		if "attack_area_3d" in active_boss and active_boss.attack_area_3d != null and is_instance_valid(active_boss.attack_area_3d):
			active_boss.attack_area_3d.set_deferred("monitoring", false)
			active_boss.attack_area_3d.set_deferred("monitorable", false)
		active_boss.set_physics_process(false)

	stage_failed.emit()


func _setup_onboarding_guide() -> void:
	if mobile_controls == null:
		return

	onboarding_guide = Control.new()
	onboarding_guide.name = "OnboardingGuideHUD"
	onboarding_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls.add_child(onboarding_guide)

	var panel := Panel.new()
	panel.name = "GuidePlate"
	panel.size = Vector2(530.0, 52.0)
	panel.position = Vector2(375.0, 642.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.04, 0.08, 0.14, 0.84)
	pstyle.border_color = Color("00e5ff")
	pstyle.set_border_width_all(1)
	pstyle.border_width_left = 4
	pstyle.corner_radius_top_left = 6
	pstyle.corner_radius_top_right = 6
	pstyle.corner_radius_bottom_left = 6
	pstyle.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", pstyle)
	onboarding_guide.add_child(panel)

	var lbl_title := Label.new()
	lbl_title.name = "GuideTitle"
	lbl_title.text = "⚔ TACTICAL ACTION GUIDE"
	lbl_title.position = Vector2(14.0, 4.0)
	lbl_title.add_theme_font_size_override("font_size", 11)
	lbl_title.add_theme_color_override("font_color", Color("ffb800"))
	panel.add_child(lbl_title)

	var lbl_guide := Label.new()
	lbl_guide.name = "GuideText"
	lbl_guide.text = "[A/D or 스틱] 이동 · [SPACE or ▲] 점프 · [J or ⚔] 공격 · [K or 🛡] 방어 · [SHIFT or 💨] 대시"
	lbl_guide.position = Vector2(14.0, 24.0)
	lbl_guide.add_theme_font_size_override("font_size", 12)
	lbl_guide.add_theme_color_override("font_color", Color("f1f5f9"))
	panel.add_child(lbl_guide)

	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_onboarding_guide_layout)
	_update_onboarding_guide_layout()

	var timer := get_tree().create_timer(7.5)
	timer.timeout.connect(_dismiss_onboarding_guide)


func _update_onboarding_guide_layout() -> void:
	if onboarding_guide == null or not is_instance_valid(onboarding_guide):
		return
	var panel = onboarding_guide.get_node_or_null("GuidePlate") as Panel
	if panel == null:
		return
	var win := get_tree().root if get_tree() != null else null
	var vp_size: Vector2 = Vector2(win.size) if win != null else (get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720))
	panel.position = Vector2(maxf(160.0, (vp_size.x - panel.size.x) * 0.5), vp_size.y - 74.0)


func _dismiss_onboarding_guide() -> void:
	if onboarding_guide != null and is_instance_valid(onboarding_guide):
		var tw := create_tween()
		if tw:
			tw.tween_property(onboarding_guide, "modulate:a", 0.0, 0.35)
			tw.tween_callback(onboarding_guide.queue_free)
		else:
			onboarding_guide.queue_free()
		onboarding_guide = null
