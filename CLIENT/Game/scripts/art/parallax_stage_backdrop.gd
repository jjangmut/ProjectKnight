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
		sky_rect.color = sky_color if stage_num != 2 else Color(0.02, 0.06, 0.04, 1.0)
		sky_rect.size = Vector2(LAYER_WIDTH, LAYER_HEIGHT)
		l1.add_child(sky_rect)

		# Stage 2: Filtered canopy sun/moon shafts (God Rays)
		if stage_num == 2:
			var rays := Node2D.new()
			rays.name = "ForestGodRays"
			var ray_configs := [
				[Vector2(320, 0), Vector2(460, 0), Vector2(200, 720), Vector2(80, 720), 0.045],
				[Vector2(760, 0), Vector2(920, 0), Vector2(620, 720), Vector2(480, 720), 0.065],
				[Vector2(1220, 0), Vector2(1380, 0), Vector2(1080, 720), Vector2(940, 720), 0.075],
				[Vector2(1580, 0), Vector2(1740, 0), Vector2(1440, 720), Vector2(1300, 720), 0.050]
			]
			for cfg in ray_configs:
				var r_poly := Polygon2D.new()
				r_poly.polygon = PackedVector2Array([cfg[0], cfg[1], cfg[2], cfg[3]])
				r_poly.color = Color(0.85, 1.25, 0.75, cfg[4])
				rays.add_child(r_poly)
			l1.add_child(rays)
		elif stage_num == 3:
			# Stage 3: Distant siege smoke plumes rising into dusty twilight sky
			var smoke_group := Node2D.new()
			smoke_group.name = "SiegeSmokePlumes"
			var smoke_columns := [
				[Vector2(260, 720), Vector2(340, 720), Vector2(420, 0), Vector2(280, 0), 0.045],
				[Vector2(680, 720), Vector2(780, 720), Vector2(890, 0), Vector2(720, 0), 0.060],
				[Vector2(1150, 720), Vector2(1260, 720), Vector2(1380, 0), Vector2(1200, 0), 0.055],
				[Vector2(1650, 720), Vector2(1740, 720), Vector2(1880, 0), Vector2(1720, 0), 0.050]
			]
			for col in smoke_columns:
				var s_poly := Polygon2D.new()
				s_poly.polygon = PackedVector2Array([col[0], col[1], col[2], col[3]])
				s_poly.color = Color(0.18, 0.12, 0.19, col[4])
				smoke_group.add_child(s_poly)
			l1.add_child(smoke_group)
		elif stage_num == 4:
			# Stage 4: Sacred Skylight Shafts & Cavern Void Light entering from sanctuary ceiling
			var shafts := Node2D.new()
			shafts.name = "SanctuaryLightShafts"
			var shaft_configs := [
				[Vector2(260, 0), Vector2(380, 0), Vector2(200, 720), Vector2(80, 720), 0.040],
				[Vector2(680, 0), Vector2(840, 0), Vector2(580, 720), Vector2(420, 720), 0.055],
				[Vector2(1160, 0), Vector2(1320, 0), Vector2(1060, 720), Vector2(900, 720), 0.065],
				[Vector2(1580, 0), Vector2(1730, 0), Vector2(1480, 720), Vector2(1330, 720), 0.045]
			]
			for sc in shaft_configs:
				var s_poly := Polygon2D.new()
				s_poly.polygon = PackedVector2Array([sc[0], sc[1], sc[2], sc[3]])
				s_poly.color = Color(0.65, 1.15, 1.25, sc[4])
				shafts.add_child(s_poly)
			l1.add_child(shafts)
		elif stage_num == 5:
			# Stage 5: Fractured Abyssal Sky & Void Astral Fissures
			var fissures := Node2D.new()
			fissures.name = "AbyssalVoidFissures"
			var fissure_configs := [
				[Vector2(200, 0), Vector2(340, 180), Vector2(420, 320), Color(0.8, 0.2, 0.5, 0.20)],
				[Vector2(750, 0), Vector2(860, 240), Vector2(980, 400), Color(0.6, 0.15, 0.7, 0.24)],
				[Vector2(1250, 0), Vector2(1380, 160), Vector2(1520, 340), Color(0.9, 0.25, 0.45, 0.22)],
				[Vector2(1650, 0), Vector2(1760, 220), Vector2(1880, 380), Color(0.7, 0.18, 0.6, 0.20)]
			]
			for fc in fissure_configs:
				var f_line := Line2D.new()
				f_line.width = 3.5
				f_line.default_color = fc[3]
				f_line.points = PackedVector2Array([fc[0], fc[1], fc[2]])
				fissures.add_child(f_line)
				var f_core := Line2D.new()
				f_core.width = 1.2
				f_core.default_color = Color(2.4, 0.6, 1.2, 0.45)
				f_core.points = PackedVector2Array([fc[0], fc[1], fc[2]])
				fissures.add_child(f_core)
			l1.add_child(fissures)

		# Celestial Body: Soft atmospheric sun / moon / Black Eclipse with diffuse corona
		var celestial := Node2D.new()
		celestial.name = "CelestialBody"
		var is_eclipse: bool = (stage_num == 5)
		var center := Vector2(1480.0, 200.0) if stage_num == 3 else (Vector2(1440.0, 160.0) if stage_num == 4 else (Vector2(1420.0, 180.0) if stage_num == 5 else Vector2(1400.0, 150.0)))

		# Outer diffuse corona
		var corona := Polygon2D.new()
		var corona_pts := PackedVector2Array()
		var c_radius := 64.0 if is_eclipse else 54.0
		for i in range(24):
			var rad := float(i) * TAU / 24.0
			corona_pts.append(center + Vector2(cos(rad), sin(rad)) * c_radius)
		corona.polygon = corona_pts
		corona.color = Color(0.85, 1.20, 0.75, 0.16) if stage_num == 2 else (Color(1.8, 0.7, 0.25, 0.20) if stage_num == 3 else (Color(0.40, 1.60, 1.90, 0.22) if stage_num == 4 else (Color(1.8, 0.25, 0.35, 0.26) if stage_num == 5 else Color(1.0, 0.95, 0.85, 0.12))))
		celestial.add_child(corona)

		# Core luminous body (or Black Void Eclipse core)
		var moon := Polygon2D.new()
		var points := PackedVector2Array()
		var radius := 36.0
		for i in range(24):
			var rad := float(i) * TAU / 24.0
			points.append(center + Vector2(cos(rad), sin(rad)) * radius)
		moon.polygon = points
		moon.color = Color(0.92, 1.0, 0.80, 0.65) if stage_num == 2 else (Color(2.2, 1.15, 0.45, 0.80) if stage_num == 3 else (Color(1.10, 1.35, 1.45, 0.85) if stage_num == 4 else (Color(0.015, 0.008, 0.025, 0.98) if stage_num == 5 else Color(1.0, 0.96, 0.88, 0.38))))
		celestial.add_child(moon)

		if is_eclipse:
			# Blistering Crimson Photonic Rim around the Black Moon Core
			var rim := Line2D.new()
			rim.width = 2.2
			rim.default_color = Color(3.2, 0.45, 0.65, 0.95)
			var closed_points := points.duplicate()
			closed_points.append(points[0])
			rim.points = closed_points
			celestial.add_child(rim)
		l1.add_child(celestial)

	var l2 := get_node_or_null("LayerDistantPeaks") as ParallaxLayer
	if l2:
		for c in l2.get_children():
			c.queue_free()
		# Stage 2: Distant Ancient Great Tree Silhouettes
		if stage_num == 2:
			var trees := Node2D.new()
			trees.name = "DistantForestSilhouettes"
			var canopy_pts := PackedVector2Array([
				Vector2(0, LAYER_HEIGHT),
				Vector2(0, 360),
				Vector2(140, 310), Vector2(280, 350), Vector2(400, 260),
				Vector2(560, 330), Vector2(700, 240), Vector2(860, 310),
				Vector2(1000, 250), Vector2(1160, 340), Vector2(1300, 230),
				Vector2(1480, 310), Vector2(1640, 240), Vector2(1800, 330),
				Vector2(LAYER_WIDTH, 270),
				Vector2(LAYER_WIDTH, LAYER_HEIGHT)
			])
			var canopy_poly := Polygon2D.new()
			canopy_poly.polygon = canopy_pts
			canopy_poly.color = Color(0.04, 0.11, 0.07, 0.88)
			trees.add_child(canopy_poly)

			var trunk_xs := [180.0, 480.0, 780.0, 1120.0, 1420.0, 1760.0]
			for tx in trunk_xs:
				var trunk := Polygon2D.new()
				trunk.polygon = PackedVector2Array([
					Vector2(tx - 34, LAYER_HEIGHT), Vector2(tx - 22, 230),
					Vector2(tx - 38, 160), Vector2(tx - 12, 180),
					Vector2(tx + 14, 170), Vector2(tx + 40, 140),
					Vector2(tx + 24, 230), Vector2(tx + 36, LAYER_HEIGHT)
				])
				trunk.color = Color(0.03, 0.09, 0.05, 0.92)
				trees.add_child(trunk)
			l2.add_child(trees)
		elif stage_num == 3:
			# Stage 3: Distant Jagged Ruined Fortress Silhouettes & Leaning Watchtowers
			var fortress := Node2D.new()
			fortress.name = "DistantRuinedFortressSilhouettes"
			var ridge_pts := PackedVector2Array([
				Vector2(0, LAYER_HEIGHT),
				Vector2(0, 420),
				Vector2(80, 420), Vector2(100, 360), Vector2(180, 360), Vector2(200, 410),
				Vector2(290, 410), Vector2(320, 290), Vector2(390, 275), Vector2(430, 430),
				Vector2(550, 440), Vector2(590, 380), Vector2(650, 380), Vector2(700, 450),
				Vector2(780, 450), Vector2(810, 260), Vector2(880, 245), Vector2(920, 420),
				Vector2(1020, 430), Vector2(1080, 390), Vector2(1150, 440),
				Vector2(1230, 440), Vector2(1260, 280), Vector2(1330, 295), Vector2(1370, 430),
				Vector2(1480, 440), Vector2(1540, 370), Vector2(1610, 370), Vector2(1660, 440),
				Vector2(1730, 440), Vector2(1760, 270), Vector2(1830, 285), Vector2(1870, 430),
				Vector2(LAYER_WIDTH, 420),
				Vector2(LAYER_WIDTH, LAYER_HEIGHT)
			])
			var ridge_poly := Polygon2D.new()
			ridge_poly.polygon = ridge_pts
			ridge_poly.color = Color(0.12, 0.09, 0.14, 0.90)
			fortress.add_child(ridge_poly)
			# Smoldering ember spots atop shattered towers
			for em_x in [355.0, 845.0, 1295.0, 1795.0]:
				var ember := Polygon2D.new()
				ember.polygon = PackedVector2Array([
					Vector2(em_x - 12, 280), Vector2(em_x + 12, 280),
					Vector2(em_x + 6, 290), Vector2(em_x - 6, 290)
				])
				ember.color = Color(1.8, 0.65, 0.25, 0.70)
				fortress.add_child(ember)
			l2.add_child(fortress)
		elif stage_num == 4:
			# Stage 4: Distant Megalithic Monolith Pillars & Cyclopean Temple Columns
			var sanctuary := Node2D.new()
			sanctuary.name = "DistantSanctuaryMegaliths"
			var ridge_pts := PackedVector2Array([
				Vector2(0, LAYER_HEIGHT),
				Vector2(0, 460),
				Vector2(60, 460), Vector2(80, 310), Vector2(160, 310), Vector2(180, 460),
				Vector2(270, 460), Vector2(300, 240), Vector2(380, 240), Vector2(410, 460),
				Vector2(530, 470), Vector2(560, 330), Vector2(640, 330), Vector2(670, 470),
				Vector2(790, 460), Vector2(820, 220), Vector2(900, 220), Vector2(930, 460),
				Vector2(1040, 470), Vector2(1070, 320), Vector2(1150, 320), Vector2(1180, 470),
				Vector2(1290, 460), Vector2(1320, 250), Vector2(1400, 250), Vector2(1430, 460),
				Vector2(1540, 470), Vector2(1570, 300), Vector2(1650, 300), Vector2(1680, 470),
				Vector2(1780, 460), Vector2(1810, 230), Vector2(1890, 230), Vector2(1910, 460),
				Vector2(LAYER_WIDTH, 460),
				Vector2(LAYER_WIDTH, LAYER_HEIGHT)
			])
			var ridge_poly := Polygon2D.new()
			ridge_poly.polygon = ridge_pts
			ridge_poly.color = Color(0.13, 0.11, 0.15, 0.92)
			sanctuary.add_child(ridge_poly)

			# Horizontal massive stone lintels spanning pillar pairs
			for lintel_rect in [
				Rect2(65, 290, 110, 20),
				Rect2(285, 220, 110, 20),
				Rect2(805, 200, 110, 20),
				Rect2(1305, 230, 110, 20),
				Rect2(1795, 210, 110, 20)
			]:
				var l_poly := Polygon2D.new()
				l_poly.polygon = PackedVector2Array([
					lintel_rect.position,
					lintel_rect.position + Vector2(lintel_rect.size.x, 0),
					lintel_rect.position + lintel_rect.size,
					lintel_rect.position + Vector2(0, lintel_rect.size.y)
				])
				l_poly.color = Color(0.16, 0.13, 0.18, 0.95)
				sanctuary.add_child(l_poly)

			# Ancient dormant cyan rune symbols glowing on distant monolith faces
			for rune_pos in [Vector2(120, 360), Vector2(340, 290), Vector2(860, 270), Vector2(1360, 300), Vector2(1850, 280)]:
				var rune_mark := Polygon2D.new()
				rune_mark.polygon = PackedVector2Array([
					rune_pos + Vector2(0, -9), rune_pos + Vector2(6, 0),
					rune_pos + Vector2(0, 9), rune_pos + Vector2(-6, 0)
				])
				rune_mark.color = Color(0.3, 1.8, 2.2, 0.45)
				sanctuary.add_child(rune_mark)
			l2.add_child(sanctuary)
		elif stage_num == 5:
			# Stage 5: Distant Impossible Citadel Spires & Floating Ruined Towers
			var citadel := Node2D.new()
			citadel.name = "DistantCitadelSpires"
			var ridge_pts := PackedVector2Array([
				Vector2(0, LAYER_HEIGHT),
				Vector2(0, 480),
				Vector2(70, 480), Vector2(100, 280), Vector2(130, 180), Vector2(150, 280), Vector2(190, 480),
				Vector2(290, 480), Vector2(330, 240), Vector2(370, 150), Vector2(400, 250), Vector2(440, 490),
				Vector2(560, 490), Vector2(600, 290), Vector2(630, 200), Vector2(660, 290), Vector2(700, 480),
				Vector2(810, 480), Vector2(850, 210), Vector2(880, 140), Vector2(920, 230), Vector2(960, 490),
				Vector2(1070, 490), Vector2(1110, 280), Vector2(1140, 190), Vector2(1180, 290), Vector2(1220, 480),
				Vector2(1320, 480), Vector2(1360, 230), Vector2(1400, 160), Vector2(1430, 240), Vector2(1480, 490),
				Vector2(1580, 490), Vector2(1620, 270), Vector2(1650, 180), Vector2(1690, 280), Vector2(1730, 480),
				Vector2(1810, 480), Vector2(1850, 220), Vector2(1880, 150), Vector2(1900, 240), Vector2(1920, 480),
				Vector2(LAYER_WIDTH, 480),
				Vector2(LAYER_WIDTH, LAYER_HEIGHT)
			])
			var ridge_poly := Polygon2D.new()
			ridge_poly.polygon = ridge_pts
			ridge_poly.color = Color(0.06, 0.04, 0.09, 0.94)
			citadel.add_child(ridge_poly)

			# Floating Ruined Citadel Masonry Blocks drifting in zero-g
			for f_rect in [
				Rect2(220, 190, 45, 60),
				Rect2(480, 160, 50, 75),
				Rect2(730, 180, 40, 55),
				Rect2(1000, 150, 48, 70),
				Rect2(1250, 170, 42, 58),
				Rect2(1510, 160, 52, 72),
				Rect2(1750, 180, 38, 52)
			]:
				var f_poly := Polygon2D.new()
				f_poly.polygon = PackedVector2Array([
					f_rect.position + Vector2(-6, 0),
					f_rect.position + Vector2(f_rect.size.x + 8, 4),
					f_rect.position + f_rect.size + Vector2(4, 6),
					f_rect.position + Vector2(-4, f_rect.size.y)
				])
				f_poly.color = Color(0.08, 0.05, 0.12, 0.95)
				citadel.add_child(f_poly)

			# Bleeding Abyssal Energy Fissures on distant spire crevices
			for fissure_pos in [Vector2(130, 210), Vector2(370, 180), Vector2(630, 230), Vector2(880, 170), Vector2(1140, 220), Vector2(1400, 190), Vector2(1650, 210), Vector2(1880, 180)]:
				var crevice := Line2D.new()
				crevice.width = 1.8
				crevice.default_color = Color(2.4, 0.35, 0.65, 0.65)
				crevice.points = PackedVector2Array([
					fissure_pos - Vector2(0, 18),
					fissure_pos + Vector2(3, 0),
					fissure_pos + Vector2(-2, 16),
					fissure_pos + Vector2(0, 32)
				])
				citadel.add_child(crevice)
			l2.add_child(citadel)
		elif base_texture == null:
			# Fallback geometric peak silhouettes for stages without dedicated textures
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
		# When illustrated backdrop texture is available, display it with high fidelity
		if base_texture != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = base_texture
			tex_rect.size = Vector2(LAYER_WIDTH, LAYER_HEIGHT)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex_rect.modulate = Color(0.94, 1.04, 0.96, 0.95) if stage_num == 2 else (Color(0.68, 0.52, 0.64, 0.95) if stage_num == 3 else (Color(1.02, 0.96, 0.88, 0.95) if stage_num == 4 else (Color(0.72, 0.60, 0.88, 0.95) if stage_num == 5 else Color(1, 1, 1, 0.95))))
			l3.add_child(tex_rect)
			if stage_num == 3:
				var mid_fracture := Polygon2D.new()
				mid_fracture.polygon = PackedVector2Array([
					Vector2(0, LAYER_HEIGHT), Vector2(0, 520),
					Vector2(160, 520), Vector2(210, 480), Vector2(320, 480), Vector2(360, 525),
					Vector2(580, 530), Vector2(640, 475), Vector2(760, 475), Vector2(810, 525),
					Vector2(1040, 525), Vector2(1090, 480), Vector2(1200, 480), Vector2(1250, 530),
					Vector2(1480, 530), Vector2(1530, 475), Vector2(1640, 475), Vector2(1690, 525),
					Vector2(LAYER_WIDTH, 520), Vector2(LAYER_WIDTH, LAYER_HEIGHT)
				])
				mid_fracture.color = Color(0.16, 0.12, 0.18, 0.70)
				l3.add_child(mid_fracture)
			elif stage_num == 4:
				var mid_sanctuary := Polygon2D.new()
				mid_sanctuary.polygon = PackedVector2Array([
					Vector2(0, LAYER_HEIGHT), Vector2(0, 530),
					Vector2(180, 530), Vector2(230, 460), Vector2(350, 460), Vector2(400, 535),
					Vector2(650, 540), Vector2(700, 450), Vector2(820, 450), Vector2(870, 535),
					Vector2(1120, 535), Vector2(1170, 460), Vector2(1290, 460), Vector2(1340, 540),
					Vector2(1580, 540), Vector2(1630, 450), Vector2(1750, 450), Vector2(1800, 535),
					Vector2(LAYER_WIDTH, 530), Vector2(LAYER_WIDTH, LAYER_HEIGHT)
				])
				mid_sanctuary.color = Color(0.18, 0.15, 0.20, 0.65)
				l3.add_child(mid_sanctuary)
			elif stage_num == 5:
				var mid_citadel := Polygon2D.new()
				mid_citadel.polygon = PackedVector2Array([
					Vector2(0, LAYER_HEIGHT), Vector2(0, 520),
					Vector2(160, 520), Vector2(210, 440), Vector2(340, 440), Vector2(390, 525),
					Vector2(620, 530), Vector2(670, 430), Vector2(800, 430), Vector2(850, 530),
					Vector2(1080, 525), Vector2(1130, 440), Vector2(1260, 440), Vector2(1310, 530),
					Vector2(1540, 535), Vector2(1590, 435), Vector2(1720, 435), Vector2(1770, 525),
					Vector2(LAYER_WIDTH, 520), Vector2(LAYER_WIDTH, LAYER_HEIGHT)
				])
				mid_citadel.color = Color(0.09, 0.06, 0.13, 0.75)
				l3.add_child(mid_citadel)

				# Broken hanging arches over the abyss
				for arch_x in [275.0, 735.0, 1195.0, 1655.0]:
					var arch_beam := Rect2(arch_x - 65, 428, 130, 16)
					var a_poly := Polygon2D.new()
					a_poly.polygon = PackedVector2Array([
						arch_beam.position,
						arch_beam.position + Vector2(arch_beam.size.x, 0),
						arch_beam.position + arch_beam.size + Vector2(-15, 0),
						arch_beam.position + Vector2(15, arch_beam.size.y)
					])
					a_poly.color = Color(0.12, 0.08, 0.16, 0.88)
					l3.add_child(a_poly)
		else:
			# Fallback procedural ruins silhouette for stages without dedicated textures
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
		if stage_num == 2:
			# Stage 2: Top hanging vine canopy framing
			var fg_canopy := Polygon2D.new()
			fg_canopy.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(LAYER_WIDTH, 0),
				Vector2(LAYER_WIDTH, 60), Vector2(1820, 40), Vector2(1740, 85),
				Vector2(1620, 50), Vector2(1500, 75), Vector2(1380, 40),
				Vector2(1250, 90), Vector2(1120, 45), Vector2(980, 80),
				Vector2(840, 50), Vector2(720, 95), Vector2(580, 45),
				Vector2(450, 80), Vector2(320, 50), Vector2(200, 90),
				Vector2(80, 40), Vector2(0, 70)
			])
			fg_canopy.color = Color(0.02, 0.06, 0.03, 0.80)
			l4.add_child(fg_canopy)

			# Low creeping emerald forest mist
			var fog := ColorRect.new()
			fog.color = Color(0.08, 0.28, 0.16, 0.12)
			fog.position = Vector2(0, 510)
			fog.size = Vector2(LAYER_WIDTH, 210)
			l4.add_child(fog)
		elif stage_num == 3:
			# Stage 3: Top broken battlements / burned timber beams framing
			var fg_debris := Polygon2D.new()
			fg_debris.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(LAYER_WIDTH, 0),
				Vector2(LAYER_WIDTH, 50), Vector2(1840, 40), Vector2(1780, 80),
				Vector2(1660, 35), Vector2(1540, 70), Vector2(1420, 35),
				Vector2(1300, 85), Vector2(1180, 40), Vector2(1040, 75),
				Vector2(900, 45), Vector2(780, 90), Vector2(640, 40),
				Vector2(510, 75), Vector2(380, 45), Vector2(260, 85),
				Vector2(140, 35), Vector2(0, 65)
			])
			fg_debris.color = Color(0.09, 0.07, 0.11, 0.82)
			l4.add_child(fg_debris)

			# Low battlefield ash & dust drift
			var fog := ColorRect.new()
			fog.color = Color(0.24, 0.17, 0.14, 0.14)
			fog.position = Vector2(0, 520)
			fog.size = Vector2(LAYER_WIDTH, 200)
			l4.add_child(fog)
		elif stage_num == 4:
			# Stage 4: Top cyclopean stone ceiling beams & carved cornice framing
			var fg_beams := Polygon2D.new()
			fg_beams.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(LAYER_WIDTH, 0),
				Vector2(LAYER_WIDTH, 55), Vector2(1850, 45), Vector2(1760, 75),
				Vector2(1640, 40), Vector2(1520, 70), Vector2(1400, 45),
				Vector2(1260, 80), Vector2(1140, 45), Vector2(1000, 75),
				Vector2(880, 40), Vector2(750, 80), Vector2(620, 45),
				Vector2(480, 70), Vector2(360, 45), Vector2(220, 80),
				Vector2(100, 40), Vector2(0, 60)
			])
			fg_beams.color = Color(0.08, 0.07, 0.10, 0.85)
			l4.add_child(fg_beams)

			# Low sacred sanctuary dust & cyan-tinted haze
			var fog := ColorRect.new()
			fog.color = Color(0.10, 0.24, 0.26, 0.10)
			fog.position = Vector2(0, 510)
			fog.size = Vector2(LAYER_WIDTH, 210)
			l4.add_child(fog)
		elif stage_num == 5:
			# Stage 5: Top black stone cornice beams & hanging heavy void chains
			var fg_cornice := Polygon2D.new()
			fg_cornice.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(LAYER_WIDTH, 0),
				Vector2(LAYER_WIDTH, 48), Vector2(1820, 38), Vector2(1740, 72),
				Vector2(1620, 38), Vector2(1500, 68), Vector2(1380, 38),
				Vector2(1250, 76), Vector2(1130, 38), Vector2(990, 72),
				Vector2(860, 38), Vector2(740, 76), Vector2(610, 38),
				Vector2(470, 68), Vector2(340, 38), Vector2(210, 76),
				Vector2(90, 38), Vector2(0, 56)
			])
			fg_cornice.color = Color(0.04, 0.03, 0.06, 0.92)
			l4.add_child(fg_cornice)

			# Hanging heavy void chains
			var chain_xs := [150.0, 420.0, 680.0, 930.0, 1190.0, 1440.0, 1680.0, 1860.0]
			for cx in chain_xs:
				var chain_len := 65.0 + float(int(cx * 7) % 55)
				var chain_line := Line2D.new()
				chain_line.width = 3.0
				chain_line.default_color = Color(0.12, 0.09, 0.15, 0.88)
				chain_line.points = PackedVector2Array([
					Vector2(cx, 35),
					Vector2(cx, 35 + chain_len)
				])
				l4.add_child(chain_line)
				var link_y := 45.0
				while link_y < 35.0 + chain_len:
					var link := Polygon2D.new()
					link.polygon = PackedVector2Array([
						Vector2(cx - 3, link_y), Vector2(cx + 3, link_y),
						Vector2(cx + 3, link_y + 6), Vector2(cx - 3, link_y + 6)
					])
					link.color = Color(0.18, 0.14, 0.22, 0.95)
					l4.add_child(link)
					link_y += 12.0

			# Subtle drifting abyssal void haze
			var fog := ColorRect.new()
			fog.color = Color(0.12, 0.06, 0.16, 0.12)
			fog.position = Vector2(0, 500)
			fog.size = Vector2(LAYER_WIDTH, 220)
			l4.add_child(fog)
		else:
			var fog := ColorRect.new()
			fog.color = Color(sky_color.r * 1.5, sky_color.g * 1.5, sky_color.b * 1.8, 0.08)
			fog.position = Vector2(0, 450)
			fog.size = Vector2(LAYER_WIDTH, 270)
			l4.add_child(fog)
