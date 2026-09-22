class_name ParallaxStageBackdrop
extends ParallaxBackground
## 4-Layer Parallax Environment Backdrop for Project Knight.
## Implements DESIGN/ENVIRONMENT_TILESET_SPEC_001 with depth differential scrolling.

@onready var layer_sky: ParallaxLayer = $LayerSky
@onready var layer_distant: ParallaxLayer = $LayerDistantPeaks
@onready var layer_mid: ParallaxLayer = $LayerMidRuins
@onready var layer_fg_fog: ParallaxLayer = $LayerForegroundFog

const LAYER_WIDTH: float = 1920.0
const LAYER_HEIGHT: float = 720.0

const STAGE_SKY_COLORS := [
	Color(0.04, 0.06, 0.12, 1.0), # 1: Castle Outskirts (Dark Midnight Navy)
	Color(0.03, 0.08, 0.05, 1.0), # 2: Beast Forest (Deep Forest Green-Black)
	Color(0.08, 0.05, 0.08, 1.0), # 3: Ruined Wall (Dusty Purple Twilight)
	Color(0.09, 0.07, 0.04, 1.0), # 4: Stone Sanctuary (Warm Amber Night)
	Color(0.02, 0.03, 0.06, 1.0)  # 5: Silent Citadel (Ominous Abyss)
]

const STAGE_SILHOUETTE_COLORS := [
	Color(0.08, 0.11, 0.18, 0.85),
	Color(0.06, 0.14, 0.09, 0.85),
	Color(0.12, 0.09, 0.14, 0.85),
	Color(0.14, 0.11, 0.07, 0.85),
	Color(0.05, 0.06, 0.10, 0.85)
]


func _init() -> void:
	layer = -100
	scroll_base_scale = Vector2.ONE
	_build_node_hierarchy()


func _build_node_hierarchy() -> void:
	# Layer 1: Sky & Celestial (0.05x scroll)
	var l1 := ParallaxLayer.new()
	l1.name = "LayerSky"
	l1.motion_scale = Vector2(0.05, 0.05)
	l1.motion_mirroring = Vector2(LAYER_WIDTH, 0)
	add_child(l1)

	# Layer 2: Distant Peaks & Castle Silhouette (0.20x scroll)
	var l2 := ParallaxLayer.new()
	l2.name = "LayerDistantPeaks"
	l2.motion_scale = Vector2(0.20, 0.10)
	l2.motion_mirroring = Vector2(LAYER_WIDTH, 0)
	add_child(l2)

	# Layer 3: Mid-ground Ruins & Arches (0.50x scroll)
	var l3 := ParallaxLayer.new()
	l3.name = "LayerMidRuins"
	l3.motion_scale = Vector2(0.50, 0.20)
	l3.motion_mirroring = Vector2(LAYER_WIDTH, 0)
	add_child(l3)

	# Layer 4: Atmospheric Fog (1.15x foreground scroll)
	var l4 := ParallaxLayer.new()
	l4.name = "LayerForegroundFog"
	l4.motion_scale = Vector2(1.15, 0.30)
	l4.motion_mirroring = Vector2(LAYER_WIDTH, 0)
	add_child(l4)


func setup_parallax(stage_num: int, base_texture: Texture2D = null) -> void:
	var stage_idx := clampi(stage_num - 1, 0, 4)
	var sky_color: Color = STAGE_SKY_COLORS[stage_idx]
	var silhouette_color: Color = STAGE_SILHOUETTE_COLORS[stage_idx]

	var l1 := get_node_or_null("LayerSky") as ParallaxLayer
	if l1:
		for c in l1.get_children():
			c.queue_free()
		# Sky background rect
		var sky_rect := ColorRect.new()
		sky_rect.color = sky_color
		sky_rect.size = Vector2(LAYER_WIDTH, LAYER_HEIGHT)
		l1.add_child(sky_rect)

		# Celestial Moon / Red Star
		var moon := Polygon2D.new()
		var points := PackedVector2Array()
		var radius := 38.0
		var center := Vector2(1400.0, 150.0)
		for i in range(24):
			var rad := float(i) * TAU / 24.0
			points.append(center + Vector2(cos(rad), sin(rad)) * radius)
		moon.polygon = points
		moon.color = Color(0.95, 0.85, 0.65, 0.88) if stage_num != 5 else Color(0.95, 0.3, 0.25, 0.90)
		l1.add_child(moon)

	var l2 := get_node_or_null("LayerDistantPeaks") as ParallaxLayer
	if l2:
		for c in l2.get_children():
			c.queue_free()
		var peaks := Polygon2D.new()
		var peak_points := PackedVector2Array([
			Vector2(0, LAYER_HEIGHT),
			Vector2(0, 380),
			Vector2(280, 260),
			Vector2(550, 360),
			Vector2(820, 220),
			Vector2(1100, 310),
			Vector2(1420, 190),
			Vector2(1680, 300),
			Vector2(LAYER_WIDTH, 240),
			Vector2(LAYER_WIDTH, LAYER_HEIGHT)
		])
		peaks.polygon = peak_points
		peaks.color = silhouette_color
		l2.add_child(peaks)

	var l3 := get_node_or_null("LayerMidRuins") as ParallaxLayer
	if l3:
		for c in l3.get_children():
			c.queue_free()
		# If base texture is available, map it with subtle opacity for ruins atmosphere
		if base_texture != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = base_texture
			tex_rect.size = Vector2(LAYER_WIDTH, LAYER_HEIGHT)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex_rect.modulate = Color(1, 1, 1, 0.35)
			l3.add_child(tex_rect)

		var ruins := Polygon2D.new()
		var ruin_points := PackedVector2Array([
			Vector2(0, LAYER_HEIGHT),
			Vector2(0, 480),
			Vector2(120, 480),
			Vector2(140, 430),
			Vector2(200, 430),
			Vector2(220, 480),
			Vector2(600, 490),
			Vector2(750, 410),
			Vector2(850, 410),
			Vector2(950, 490),
			Vector2(1300, 470),
			Vector2(1450, 420),
			Vector2(1520, 420),
			Vector2(1600, 470),
			Vector2(LAYER_WIDTH, 480),
			Vector2(LAYER_WIDTH, LAYER_HEIGHT)
		])
		ruins.polygon = ruin_points
		ruins.color = Color(silhouette_color.r * 0.7, silhouette_color.g * 0.7, silhouette_color.b * 0.7, 0.75)
		l3.add_child(ruins)

	var l4 := get_node_or_null("LayerForegroundFog") as ParallaxLayer
	if l4:
		for c in l4.get_children():
			c.queue_free()
		var fog := ColorRect.new()
		fog.color = Color(sky_color.r * 1.5, sky_color.g * 1.5, sky_color.b * 1.8, 0.08)
		fog.position = Vector2(0, 450)
		fog.size = Vector2(LAYER_WIDTH, 270)
		l4.add_child(fog)
