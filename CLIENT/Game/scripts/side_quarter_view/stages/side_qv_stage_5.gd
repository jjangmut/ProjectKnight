extends SideQVStageBase
class_name SideQVStage5
## Stage 5 침묵의 성채 (Silent Citadel) - 사이드 쿼터뷰 옥좌 홀
## - 검은 대리석 옥좌 홀 (Dark Obsidian Floor & Throne Podium)
## - 딥 바이올렛 & 보이드 퍼플 앰비언스 (Color(0.22, 0.12, 0.38))
## - 보이드 안개 및 핏빛 룬 오라 펄스
## - 2단계 웨이브 진행:
##   Wave 1: 엘리트 심연 기사 미니언 2기 스폰
##   Wave 2: 최종 보스 '심연의 심판관(Abyssal Arbiter)' 격돌 및 처치 시 최종 클리어

const TexFlagstone = preload("res://assets/side_qv/flagstone_floor.png")
const TexRunicCircle = preload("res://assets/side_qv/arena_runic_circle.png")
const TexBanner = preload("res://assets/side_qv/citadel_banner.png")
const TexCitadel = preload("res://assets/terrain_v2/citadel.png")
const TexBackdrop = preload("res://assets/stage_revision2/background.png")

const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVAbyssalArbiterClass = preload("res://scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd")

var boss_ui_bar: Control = null
var boss_bar_fill: ColorRect = null
var boss_enraged_tag: Label = null
var throne_rune_pulse: MeshInstance3D = null


func _init() -> void:
	stage_index = 5
	stage_title = "침묵의 성채"
	arena_width = 38.0
	arena_depth = 12.0


func _process(delta: float) -> void:
	super._process(delta)
	if throne_rune_pulse != null and is_instance_valid(throne_rune_pulse):
		# Subtle pulsing of the throne blood rune aura
		var s := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.003)
		throne_rune_pulse.scale = Vector3(s, 1.0, s)


# ==============================================================================
# 3D 조명 및 앰비언스 환경 설정 (딥 바이올렛 & 보이드 퍼플)
# ==============================================================================
func _setup_3d_environment() -> void:
	# 1. WorldEnvironment with Deep Violet & Void Purple Ambience
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment3D"
	var env := Environment.new()

	# Deep Void Night Sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.03, 0.12, 1.0) # Deep Abyssal Void

	# Deep Violet & Void Purple Ambience (as required)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.12, 0.38, 1.0)
	env.ambient_light_energy = 1.35

	# 3D HDR Glow Bloom
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.4
	env.glow_bloom = 0.28

	# Void Fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.08, 0.28, 1.0)
	env.fog_density = 0.016
	env.fog_aerial_perspective = 0.5

	world_env.environment = env
	add_child(world_env)

	# 2. Moody Void Directional Sunlight
	var sun := DirectionalLight3D.new()
	sun.name = "VoidSunLight3D"
	sun.shadow_enabled = true
	sun.light_color = Color(0.78, 0.68, 0.96, 1.0) # Ethereal Violet Moonlight
	sun.light_energy = 1.30
	sun.rotation_degrees = Vector3(-50.0, -28.0, 0.0)
	add_child(sun)

	# 3. 심연 보이드 부유 입자 (Abyssal Void Particles)
	_spawn_stage_floating_particles("AbyssalVoidParticles", Color(2.2, 0.35, 3.2, 0.88), Vector3(0.0, 0.45, 0.0), 68)


# ==============================================================================
# 3D 성채 옥좌 홀 배경 및 건축물 설정 (검은 대리석 옥좌 홀 & 룬 기둥)
# ==============================================================================
func _setup_3d_background_architecture() -> void:
	# 1. Distant Panoramic Void Vista Backdrop
	var backdrop_mesh := MeshInstance3D.new()
	backdrop_mesh.name = "PanoramicCitadelBackdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(62.0, 26.0)
	backdrop_mesh.mesh = quad

	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = TexBackdrop
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.42, 0.32, 0.62, 1.0) # Atmospheric Void Tint
	bmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop_mesh.material_override = bmat
	backdrop_mesh.position = Vector3(0.0, 4.2, -13.5)
	add_child(backdrop_mesh)

	# 2. Polished Dark Obsidian Marble Floor
	var floor_box := CSGBox3D.new()
	floor_box.name = "DarkObsidianFloor"
	floor_box.use_collision = true
	floor_box.collision_layer = 4 # World (Layer 3)
	floor_box.size = Vector3(arena_width, 1.0, arena_depth)
	floor_box.position = Vector3(0.0, -0.5, 0.0)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = TexFlagstone
	floor_mat.albedo_color = Color(0.14, 0.12, 0.20, 1.0) # Dark Obsidian Tint
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	floor_mat.roughness = 0.22 # Polished high-gloss marble
	floor_mat.metallic = 0.35
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	floor_box.material_override = floor_mat
	add_child(floor_box)

	# 3. Central Abyssal Runic Seal (Glowing Violet-Crimson Crest)
	var runic_seal := MeshInstance3D.new()
	runic_seal.name = "AbyssalRunicSeal"
	var seal_quad := QuadMesh.new()
	seal_quad.size = Vector2(9.2, 9.2)
	runic_seal.mesh = seal_quad
	runic_seal.position = Vector3(0.0, 0.02, 0.0)
	runic_seal.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = TexRunicCircle
	smat.albedo_color = Color(1.8, 0.3, 2.5, 0.95)
	smat.emission_enabled = true
	smat.emission_texture = TexRunicCircle
	smat.emission = Color(1.8, 0.3, 2.5, 1.0)
	smat.emission_energy_multiplier = 2.8
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	runic_seal.material_override = smat
	add_child(runic_seal)

	# 4. Stepped Throne Dais & Grand Royal Obsidian Throne
	_build_throne_podium(Vector3(0.0, 0.0, -arena_depth * 0.5 + 1.2))

	# 5. Colossal Black Stone Pillars & Ethereal Violet Braziers
	_build_hall_pillars()

	# 6. Terrace Balustrades (Boundaries)
	_build_balustrades()


func _build_throne_podium(pos: Vector3) -> void:
	var podium_parent := Node3D.new()
	podium_parent.name = "ThronePodium"
	add_child(podium_parent)

	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = TexCitadel
	pmat.albedo_color = Color(0.18, 0.14, 0.24, 1.0)
	pmat.uv1_scale = Vector3(3.0, 1.0, 1.0)
	pmat.roughness = 0.35

	# Step 1: Lower Dais
	var step1 := CSGBox3D.new()
	step1.size = Vector3(10.0, 0.35, 3.8)
	step1.position = pos + Vector3(0.0, 0.175, 0.0)
	step1.material_override = pmat
	podium_parent.add_child(step1)

	# Step 2: Upper Dais
	var step2 := CSGBox3D.new()
	step2.size = Vector3(7.0, 0.35, 2.6)
	step2.position = pos + Vector3(0.0, 0.525, -0.4)
	step2.material_override = pmat
	podium_parent.add_child(step2)

	# Royal Crimson Velvet Runner
	var carpet := MeshInstance3D.new()
	var c_quad := QuadMesh.new()
	c_quad.size = Vector2(2.4, 4.2)
	carpet.mesh = c_quad
	carpet.position = pos + Vector3(0.0, 0.53, 0.4)
	carpet.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.55, 0.04, 0.12, 1.0) # Deep Crimson
	cmat.roughness = 0.85
	carpet.material_override = cmat
	podium_parent.add_child(carpet)

	# Grand Obsidian Throne
	var throne_seat := CSGBox3D.new()
	throne_seat.size = Vector3(2.6, 0.7, 1.6)
	throne_seat.position = pos + Vector3(0.0, 1.05, -1.0)
	throne_seat.material_override = pmat
	podium_parent.add_child(throne_seat)

	var throne_back := CSGBox3D.new()
	throne_back.size = Vector3(2.4, 3.8, 0.5)
	throne_back.position = pos + Vector3(0.0, 2.9, -1.6)
	throne_back.material_override = pmat
	podium_parent.add_child(throne_back)

	# Throne Armrests
	for arm_side in [-1.2, 1.2]:
		var arm := CSGBox3D.new()
		arm.size = Vector3(0.35, 0.8, 1.5)
		arm.position = pos + Vector3(arm_side, 1.45, -1.0)
		arm.material_override = pmat
		podium_parent.add_child(arm)

	# Pulsing Blood Rune Aura halo behind throne
	throne_rune_pulse = MeshInstance3D.new()
	throne_rune_pulse.name = "ThroneBloodRuneHalo"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 1.95
	throne_rune_pulse.mesh = torus
	throne_rune_pulse.position = pos + Vector3(0.0, 3.6, -1.5)
	throne_rune_pulse.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(3.0, 0.2, 0.6, 0.95)
	tmat.emission_enabled = true
	tmat.emission = Color(3.0, 0.2, 0.6, 1.0)
	tmat.emission_energy_multiplier = 4.2
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	throne_rune_pulse.material_override = tmat
	podium_parent.add_child(throne_rune_pulse)


func _build_hall_pillars() -> void:
	var x_coords := [-13.0, -6.5, 6.5, 13.0]
	for px in x_coords:
		_build_obsidian_pillar(Vector3(px, 0.0, -arena_depth * 0.5 + 0.6))


func _build_obsidian_pillar(pos: Vector3) -> void:
	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = TexCitadel
	pmat.albedo_color = Color(0.16, 0.13, 0.22, 1.0)
	pmat.uv1_scale = Vector3(2.0, 4.0, 1.0)
	pmat.roughness = 0.40

	# Base Pedestal
	var base := CSGBox3D.new()
	base.size = Vector3(1.8, 0.8, 1.8)
	base.position = pos + Vector3(0.0, 0.4, 0.0)
	base.material_override = pmat
	add_child(base)

	# Main Cylinder Shaft
	var shaft := CSGCylinder3D.new()
	shaft.use_collision = true
	shaft.collision_layer = 4
	shaft.radius = 0.72
	shaft.height = 5.2
	shaft.position = pos + Vector3(0.0, 3.0, 0.0)
	shaft.material_override = pmat
	add_child(shaft)

	# Capital
	var cap := CSGBox3D.new()
	cap.size = Vector3(1.8, 0.7, 1.8)
	cap.position = pos + Vector3(0.0, 5.75, 0.0)
	cap.material_override = pmat
	add_child(cap)

	# Dual Violet Rune Bands
	_build_pillar_rune_band(pos + Vector3(0.0, 2.0, 0.0), Color(1.8, 0.2, 2.5, 1.0), 3.2)
	_build_pillar_rune_band(pos + Vector3(0.0, 4.2, 0.0), Color(2.6, 0.2, 1.2, 1.0), 3.0)

	# Ethereal Violet Torch Brazier
	var brazier_light := OmniLight3D.new()
	brazier_light.light_color = Color(1.6, 0.4, 2.2, 1.0)
	brazier_light.light_energy = 2.4
	brazier_light.omni_range = 8.5
	brazier_light.position = pos + Vector3(0.0, 2.5, 0.8)
	add_child(brazier_light)


func _build_pillar_rune_band(pos: Vector3, color: Color, energy: float) -> void:
	var ring := CSGTorus3D.new()
	ring.inner_radius = 0.74
	ring.outer_radius = 0.88
	ring.position = pos

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = color
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = energy
	ring.material_override = rmat
	add_child(ring)


func _build_balustrades() -> void:
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = TexCitadel
	bmat.albedo_color = Color(0.18, 0.14, 0.24, 1.0)
	bmat.uv1_scale = Vector3(8.0, 1.0, 1.0)
	bmat.roughness = 0.45

	# Back Balustrade
	var back_wall := CSGBox3D.new()
	back_wall.use_collision = true
	back_wall.collision_layer = 4
	back_wall.size = Vector3(arena_width, 1.2, 0.8)
	back_wall.position = Vector3(0.0, 0.6, -arena_depth * 0.5)
	back_wall.material_override = bmat
	add_child(back_wall)

	# Front Balustrade
	var front_wall := CSGBox3D.new()
	front_wall.use_collision = true
	front_wall.collision_layer = 4
	front_wall.size = Vector3(arena_width, 0.6, 0.6)
	front_wall.position = Vector3(0.0, 0.3, arena_depth * 0.5)
	front_wall.material_override = bmat
	add_child(front_wall)


# ==============================================================================
# 웨이브 진행 로직:
# Wave 1: 엘리트 심연 기사 2기 스폰
# Wave 2: 최종 보스 '심연의 심판관(Abyssal Arbiter)' 스폰
# ==============================================================================
func _spawn_wave_1_enemies() -> void:
	var minion1 := SideQVEliteKnightClass.new()
	minion1.name = "EliteAbyssalKnight_1"
	minion1.position = Vector3(4.0, 0.1, 0.0)
	add_child(minion1)
	enemies.append(minion1)
	minion1.enemy_defeated.connect(_on_enemy_defeated)

	var minion2 := SideQVEliteKnightClass.new()
	minion2.name = "EliteAbyssalKnight_2"
	minion2.position = Vector3(8.5, 0.1, 0.0)
	add_child(minion2)
	enemies.append(minion2)
	minion2.enemy_defeated.connect(_on_enemy_defeated)


func _spawn_stage_boss() -> void:
	var arbiter := SideQVAbyssalArbiterClass.new()
	arbiter.name = "SideQVAbyssalArbiter"
	var p_x: float = player.global_position.x if (player != null and is_instance_valid(player)) else 0.0
	var spawn_x: float = clampf(maxf(p_x + 5.5, 11.5), 10.0, arena_width * 0.5 - 2.5)
	arbiter.position = Vector3(spawn_x, 0.1, 0.0)
	add_child(arbiter)
	active_boss = arbiter
	enemies.append(arbiter)

	arbiter.boss_defeated.connect(func(_b):
		if boss_ui_bar != null and is_instance_valid(boss_ui_bar):
			var t := create_tween()
			if t:
				t.tween_property(boss_ui_bar, "modulate:a", 0.0, 0.5)
				t.tween_callback(boss_ui_bar.queue_free)
		_on_boss_defeated()
	)

	_setup_boss_health_bar(arbiter)


func _setup_boss_health_bar(arbiter: SideQVAbyssalArbiter) -> void:
	if mobile_controls == null:
		return

	boss_ui_bar = Control.new()
	boss_ui_bar.name = "BossHealthBarUI"
	boss_ui_bar.custom_minimum_size = Vector2(720, 70)
	boss_ui_bar.position = Vector2(280, 40)
	boss_ui_bar.modulate.a = 0.0 # 부모 BossHealthBar 단일 표시를 위해 호환 노드는 투명 유지
	mobile_controls.add_child(boss_ui_bar)

	# Boss Name Label
	var name_lbl := Label.new()
	name_lbl.text = "심연의 심판관 (Abyssal Arbiter)"
	name_lbl.size = Vector2(720, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.85, 1.0))
	boss_ui_bar.add_child(name_lbl)

	# Enraged Phase 2 Tag
	boss_enraged_tag = Label.new()
	boss_enraged_tag.text = "[ 2페이즈: 심연의 폭풍 ]"
	boss_enraged_tag.size = Vector2(720, 24)
	boss_enraged_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_enraged_tag.add_theme_font_size_override("font_size", 16)
	boss_enraged_tag.add_theme_color_override("font_color", Color(1.0, 0.3, 0.4))
	boss_enraged_tag.visible = false
	boss_ui_bar.add_child(boss_enraged_tag)

	# Bar Background
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(0, 32)
	bar_bg.size = Vector2(720, 22)
	bar_bg.color = Color(0.08, 0.04, 0.12, 0.9)
	boss_ui_bar.add_child(bar_bg)

	# Bar Fill (Abyssal Violet-Crimson)
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.position = Vector2(2, 34)
	boss_bar_fill.size = Vector2(716, 18)
	boss_bar_fill.color = Color(0.85, 0.15, 0.65, 1.0)
	boss_ui_bar.add_child(boss_bar_fill)

	# Signal connections
	arbiter.boss_hp_changed.connect(func(curr: int, m_hp: int):
		if boss_bar_fill != null and is_instance_valid(boss_bar_fill):
			var ratio := clampf(float(curr) / float(maxi(1, m_hp)), 0.0, 1.0)
			boss_bar_fill.size.x = 716.0 * ratio
	)

	arbiter.phase_changed.connect(func(phase: int):
		if phase == 2:
			if boss_enraged_tag != null and is_instance_valid(boss_enraged_tag):
				boss_enraged_tag.visible = true
			if boss_bar_fill != null and is_instance_valid(boss_bar_fill):
				boss_bar_fill.color = Color(1.0, 0.15, 0.35, 1.0) # Blood Crimson
	)
