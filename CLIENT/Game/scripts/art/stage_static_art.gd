class_name StageStaticArt
extends Node2D
## Cached static terrain and stage decoration renderer.
## Precomputes static geometry once on stage load.
## Redraws ONLY when stage state (gates, checkpoints) changes, never per frame.

var stage: Node2D = null
var ground_texture: Texture2D = null
var edge_color: Color = Color.WHITE
var font: Font = null

var is_cached: bool = false

# Precomputed geometry caches
var cached_ground_tiles: Array[Dictionary] = []
var cached_platforms: Array[Dictionary] = []
var cached_landmarks: Array[Dictionary] = []
var cached_route_signs: Array[Dictionary] = []
var cached_checkpoints: Array[Dictionary] = []
var cached_goal_pos: Vector2 = Vector2.ZERO
var cached_stage_num: int = 1

var _cached_sign_style: StyleBoxFlat = null

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = -1

func _sign_style() -> StyleBoxFlat:
	if _cached_sign_style == null:
		_cached_sign_style = StyleBoxFlat.new()
		_cached_sign_style.bg_color = Color(0.07, 0.11, 0.15, 0.94)
		_cached_sign_style.border_color = Color(0.78, 0.65, 0.42, 0.88)
		_cached_sign_style.border_width_left = 2
		_cached_sign_style.border_width_right = 2
		_cached_sign_style.border_width_top = 2
		_cached_sign_style.border_width_bottom = 2
		_cached_sign_style.set_corner_radius_all(6)
		_cached_sign_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		_cached_sign_style.shadow_size = 4
		_cached_sign_style.shadow_offset = Vector2(0, 2)
	return _cached_sign_style

func build_cache(p_stage: Node2D, p_ground: Texture2D, p_edge: Color, p_font: Font) -> void:
	stage = p_stage
	ground_texture = p_ground
	edge_color = p_edge
	font = p_font

	if not is_instance_valid(stage) or ground_texture == null:
		return

	cached_stage_num = int(stage.get("stage_number")) if "stage_number" in stage else 1

	# 1. Precompute ground tiling
	cached_ground_tiles.clear()
	var world_w: float = float(stage.get("WORLD_WIDTH")) if "WORLD_WIDTH" in stage else 11000.0
	var num_tiles := ceili(world_w / 256.0)
	var g_w := float(ground_texture.get_width())
	var g_h := float(ground_texture.get_height())

	for index in range(num_tiles):
		var x := index * 256.0
		var width := minf(256.0, world_w - x)
		var source_width := g_w * width / 256.0
		var source := Rect2(0, 0, source_width, g_h)
		var transform_pos := Vector2(x, 620)
		var flip: bool = false
		if index % 2 == 1:
			source.position.x = g_w - source_width
			transform_pos = Vector2(x + width, 620)
			flip = true
		cached_ground_tiles.append({
			"pos": transform_pos,
			"flip": flip,
			"rect": Rect2(0, 0, width, 80),
			"source": source
		})

	# 2. Precompute platform terrain geometry, root supports, or masonry corbels
	cached_platforms.clear()
	var terrain_nodes := get_tree().get_nodes_in_group("stage_terrain")
	for terrain in terrain_nodes:
		if not stage.is_ancestor_of(terrain):
			continue
		if not terrain.has_meta("surface_points"):
			continue
		var surface: PackedVector2Array = terrain.get_meta("surface_points")
		var points := PackedVector2Array()
		for pt in surface:
			points.append(pt + terrain.position)

		var platform_data := {
			"points": points,
			"has_supports": false,
			"slab_shadow": Rect2(),
			"supports": [],
			"corbels": [],
			"corbel_polylines": [],
			"corbel_lines": [],
			"root_polys": [],
			"hanging_moss": []
		}

		var min_px := minf(points[0].x, points[1].x)
		var max_px := maxf(points[0].x, points[1].x)
		var p_width := max_px - min_px
		var top_y := minf(points[0].y, points[1].y)

		var is_grounded_stage: bool = (cached_stage_num >= 2)
		var valid_height: bool = (top_y < 595) if is_grounded_stage else (top_y < 540)
		var valid_width: bool = (p_width > 40.0) if is_grounded_stage else (p_width > 140.0)

		if points.size() == 2 and valid_height and valid_width:
			platform_data.has_supports = true
			platform_data.slab_shadow = Rect2(min_px, top_y + 18, p_width, 8)

			if cached_stage_num == 2:
				# Stage 2: Natural organic moss underlayer & fine hanging vine tendrils
				var moss_under_pts := PackedVector2Array([
					Vector2(min_px, top_y + 18),
					Vector2(max_px, top_y + 18)
				])
				var num_crests := maxi(4, int(p_width / 16.0))
				for c_i in range(num_crests, -1, -1):
					var cx := min_px + (p_width * float(c_i) / float(num_crests))
					var wave := sin(cx * 0.09) * 3.5 + cos(cx * 0.21) * 2.5
					moss_under_pts.append(Vector2(cx, top_y + 24.0 + wave))
				platform_data["moss_underlayer"] = moss_under_pts

				# Fine hanging vine tendrils with variable organic lengths & tip leaves
				var vine_count := int(p_width / 15.0)
				for v_i in range(vine_count):
					var vx := min_px + 7.5 + float(v_i) * 15.0
					var v_len := 7.0 + float((v_i * 11 + 3) % 17)
					if v_i % 3 == 0:
						v_len += 9.0
					var vy_top := top_y + 18.0
					platform_data["hanging_moss"].append({
						"start": Vector2(vx, vy_top),
						"end": Vector2(vx + sin(vx * 0.25) * 3.5, vy_top + v_len),
						"leaf": Vector2(vx + sin(vx * 0.25) * 3.5, vy_top + v_len)
					})

				# Organic root supports with buttress flares
				if p_width > 120.0:
					for x_pos in [min_px + 36, max_px - 36]:
						var top_at := Vector2(x_pos, top_y + 18)
						var root_poly := PackedVector2Array([
							top_at + Vector2(-16, 0),
							top_at + Vector2(16, 0),
							Vector2(x_pos + 11, lerpf(top_at.y, 620.0, 0.45)),
							Vector2(x_pos + 26, 620),
							Vector2(x_pos - 26, 620),
							Vector2(x_pos - 11, lerpf(top_at.y, 620.0, 0.45))
						])
						platform_data.root_polys.append(root_poly)
				else:
					var mid_x := (min_px + max_px) * 0.5
					var top_at := Vector2(mid_x, top_y + 18)
					var bracket_poly := PackedVector2Array([
						top_at + Vector2(-18, 0),
						top_at + Vector2(18, 0),
						Vector2(mid_x + 10, lerpf(top_at.y, 620.0, 0.45)),
						Vector2(mid_x + 22, 620),
						Vector2(mid_x - 22, 620),
						Vector2(mid_x - 10, lerpf(top_at.y, 620.0, 0.45))
					])
					platform_data.root_polys.append(bracket_poly)
			elif cached_stage_num == 3:
				# Stage 3: Fractured stone masonry pillars & timber scaffolding struts
				platform_data["scaffold_struts"] = []
				platform_data["fractured_pillars"] = []
				platform_data["slab_timber"] = Rect2(min_px, top_y + 18, p_width, 10)

				if p_width > 120.0:
					for x_pos in [min_px + 34, max_px - 34]:
						var top_at := Vector2(x_pos, top_y + 18)
						var pillar_rect := Rect2(top_at - Vector2(16, 0), Vector2(32, 620 - top_at.y))
						var joints: Array[Vector2] = []
						var j_y := top_at.y + 35.0
						while j_y < 600.0:
							joints.append(Vector2(x_pos - 16, j_y))
							joints.append(Vector2(x_pos + 16, j_y))
							j_y += 45.0
						var corbel_poly := PackedVector2Array([
							top_at + Vector2(-26, 0),
							top_at + Vector2(26, 0),
							top_at + Vector2(16, 16),
							top_at + Vector2(-16, 16)
						])
						platform_data.fractured_pillars.append({
							"rect": pillar_rect,
							"joints": joints,
							"corbel": corbel_poly,
							"clamp": Rect2(top_at.x - 18, lerpf(top_at.y, 620.0, 0.4), 36, 8)
						})
				else:
					var mid_x := (min_px + max_px) * 0.5
					var top_at := Vector2(mid_x, top_y + 18)
					var strut_left := PackedVector2Array([
						Vector2(min_px + 6, top_y + 18), Vector2(min_px + 16, top_y + 18),
						Vector2(mid_x + 8, 620), Vector2(mid_x - 2, 620)
					])
					var strut_right := PackedVector2Array([
						Vector2(max_px - 6, top_y + 18), Vector2(max_px - 16, top_y + 18),
						Vector2(mid_x - 8, 620), Vector2(mid_x + 2, 620)
					])
					var crossbeam := Rect2(min_px + 10, lerpf(top_at.y, 620.0, 0.5) - 6, p_width - 20, 12)
					platform_data.scaffold_struts.append({
						"left": strut_left,
						"right": strut_right,
						"cross": crossbeam
					})
			elif cached_stage_num == 4:
				# Stage 4: Megalithic Stone Pillars & Monolithic Sanctuary Plinths
				platform_data["monolith_pillars"] = []
				platform_data["pylon_supports"] = []
				platform_data["slab_stone"] = Rect2(min_px, top_y + 18, p_width, 14)

				if p_width > 120.0:
					for x_pos in [min_px + 38, max_px - 38]:
						var top_at := Vector2(x_pos, top_y + 18)
						var pillar_rect := Rect2(top_at - Vector2(22, 0), Vector2(44, 620 - top_at.y))
						var joints: Array[Vector2] = []
						var j_y := top_at.y + 40.0
						while j_y < 605.0:
							joints.append(Vector2(x_pos - 22, j_y))
							joints.append(Vector2(x_pos + 22, j_y))
							j_y += 50.0
						var corbel_poly := PackedVector2Array([
							top_at + Vector2(-32, 0),
							top_at + Vector2(32, 0),
							top_at + Vector2(24, 18),
							top_at + Vector2(-24, 18)
						])
						var plinth_rect := Rect2(x_pos - 26, 606, 52, 14)
						var rune_channel := [Vector2(x_pos, top_at.y + 24), Vector2(x_pos, 600)]
						platform_data.monolith_pillars.append({
							"rect": pillar_rect,
							"joints": joints,
							"corbel": corbel_poly,
							"plinth": plinth_rect,
							"rune_line": rune_channel
						})
				else:
					var mid_x := (min_px + max_px) * 0.5
					var top_at := Vector2(mid_x, top_y + 18)
					var pylon_poly := PackedVector2Array([
						top_at + Vector2(-24, 0),
						top_at + Vector2(24, 0),
						Vector2(mid_x + 16, lerpf(top_at.y, 620.0, 0.40)),
						Vector2(mid_x + 30, 620),
						Vector2(mid_x - 30, 620),
						Vector2(mid_x - 16, lerpf(top_at.y, 620.0, 0.40))
					])
					var pylon_corbel := PackedVector2Array([
						top_at + Vector2(-30, 0),
						top_at + Vector2(30, 0),
						top_at + Vector2(20, 16),
						top_at + Vector2(-20, 16)
					])
					platform_data.pylon_supports.append({
						"pylon": pylon_poly,
						"corbel": pylon_corbel,
						"plinth": Rect2(mid_x - 34, 608, 68, 12),
						"rune_center": Vector2(mid_x, lerpf(top_at.y, 620.0, 0.50))
					})
			else:
				var shade := Color(0.63, 0.66, 0.65, 0.88)
				var width := 30.0

				for x_pos in [min_px + 36, max_px - 36]:
					var top_at := Vector2(x_pos, top_y + 18)
					var support_rect := Rect2(top_at - Vector2(width * 0.5, 0), Vector2(width, 620 - top_at.y))
					var support_source := Rect2(g_w * 0.28, g_h * 0.18, g_w * 0.09, g_h * 0.82)
					platform_data.supports.append({
						"rect": support_rect,
						"source": support_source,
						"shade": shade
					})

					var corbel_poly := PackedVector2Array([
						top_at + Vector2(-width * 0.8, 0),
						top_at + Vector2(width * 0.8, 0),
						top_at + Vector2(width * 0.45, 14),
						top_at + Vector2(-width * 0.45, 14)
					])
					var corbel_poly_closed := corbel_poly.duplicate()
					corbel_poly_closed.append(corbel_poly[0])

					platform_data.corbels.append(corbel_poly)
					platform_data.corbel_polylines.append(corbel_poly_closed)
					platform_data.corbel_lines.append({
						"start": top_at + Vector2(-22, 1),
						"end": top_at + Vector2(22, 1)
					})

		cached_platforms.append(platform_data)

	# 3. Precompute Stage Landmarks
	cached_landmarks.clear()
	if cached_stage_num == 2:
		# Landmark 1: Megalithic Overgrown Ruin Portal (x ≈ 400)
		cached_landmarks.append({
			"type": "portal",
			"pillars": [
				Rect2(340, 240, 48, 380), # Left megalith
				Rect2(434, 240, 48, 380)  # Right megalith
			],
			"lintels": [
				Rect2(318, 205, 186, 38), # Massive stone lintel
				Rect2(306, 198, 210, 9)   # Cornice slab
			],
			"stone_joints": [
				[Vector2(340, 340), Vector2(388, 340)],
				[Vector2(340, 450), Vector2(388, 450)],
				[Vector2(340, 540), Vector2(388, 540)],
				[Vector2(434, 330), Vector2(482, 330)],
				[Vector2(434, 440), Vector2(482, 440)],
				[Vector2(434, 535), Vector2(482, 535)]
			],
			"roots": [
				PackedVector2Array([Vector2(334, 620), Vector2(348, 470), Vector2(336, 350), Vector2(358, 240), Vector2(372, 240), Vector2(360, 350), Vector2(368, 470), Vector2(352, 620)]),
				PackedVector2Array([Vector2(490, 620), Vector2(472, 470), Vector2(486, 350), Vector2(464, 240), Vector2(450, 240), Vector2(468, 350), Vector2(456, 470), Vector2(470, 620)])
			],
			"rubble": [
				Rect2(305, 585, 32, 35),
				Rect2(486, 592, 28, 28)
			],
			"keystone": Vector2(411, 224)
		})

		# Landmark 2: Fallen Ancient Beast Colossus (x ≈ 5400)
		cached_landmarks.append({
			"type": "colossus",
			"horn_poly": PackedVector2Array([
				Vector2(5335, 620), Vector2(5352, 510), Vector2(5384, 450),
				Vector2(5408, 475), Vector2(5382, 540), Vector2(5370, 620)
			]),
			"head_poly": PackedVector2Array([
				Vector2(5370, 620), Vector2(5380, 535), Vector2(5435, 500),
				Vector2(5485, 545), Vector2(5490, 620)
			]),
			"pedestal_rect": Rect2(5475, 555, 75, 65),
			"eye_pos": Vector2(5415, 530)
		})

		# Landmark 3: Alpha Beast Domain Gate (x ≈ 9350)
		cached_landmarks.append({
			"type": "totem_gate",
			"left_tusk": PackedVector2Array([
				Vector2(9302, 620), Vector2(9316, 470), Vector2(9330, 330), Vector2(9350, 240),
				Vector2(9338, 245), Vector2(9320, 340), Vector2(9304, 480), Vector2(9286, 620)
			]),
			"right_tusk": PackedVector2Array([
				Vector2(9438, 620), Vector2(9424, 470), Vector2(9410, 330), Vector2(9390, 240),
				Vector2(9402, 245), Vector2(9418, 340), Vector2(9434, 480), Vector2(9454, 620)
			]),
			"bands": [
				Rect2(9308, 480, 18, 7), Rect2(9322, 340, 14, 6),
				Rect2(9428, 480, 18, 7), Rect2(9414, 340, 14, 6)
			],
			"cross_beam": Rect2(9315, 280, 110, 20),
			"ward_gem": Vector2(9370, 335)
		})

		# Boss Arena Colosseum Root Framing & Sacrificial Altar (x ≈ 9400..10740)
		cached_landmarks.append({
			"type": "boss_arena",
			"left_arch": PackedVector2Array([
				Vector2(9420, 620), Vector2(9435, 420), Vector2(9470, 270), Vector2(9535, 195),
				Vector2(9565, 215), Vector2(9500, 295), Vector2(9460, 440), Vector2(9450, 620)
			]),
			"right_arch": PackedVector2Array([
				Vector2(10720, 620), Vector2(10705, 420), Vector2(10670, 270), Vector2(10605, 195),
				Vector2(10575, 215), Vector2(10640, 295), Vector2(10680, 440), Vector2(10690, 620)
			]),
			"altar_base": Rect2(10010, 595, 300, 25),
			"altar_step": Rect2(10060, 570, 200, 25),
			"altar_slab": Rect2(10110, 540, 100, 30),
			"altar_center": Vector2(10160, 555),
			"braziers": [Vector2(10035, 565), Vector2(10285, 565)]
		})
	elif cached_stage_num == 3:
		# Landmark 1: Leaning Ruined Watchtower (x ≈ 370)
		cached_landmarks.append({
			"type": "leaning_watchtower",
			"tower_poly": PackedVector2Array([
				Vector2(300, 620), Vector2(330, 265), Vector2(420, 275), Vector2(440, 620)
			]),
			"battlements": [
				Rect2(325, 245, 24, 25),
				Rect2(365, 250, 24, 25),
				Rect2(405, 255, 26, 25)
			],
			"fractures": [
				[Vector2(350, 285), Vector2(380, 350)],
				[Vector2(380, 350), Vector2(370, 450)],
				[Vector2(370, 450), Vector2(410, 540)],
				[Vector2(410, 370), Vector2(435, 420)]
			],
			"exposed_beams": [
				Rect2(400, 310, 45, 10),
				Rect2(320, 390, 35, 10)
			],
			"courses": [
				[Vector2(308, 540), Vector2(435, 540)],
				[Vector2(315, 460), Vector2(430, 460)],
				[Vector2(322, 380), Vector2(425, 380)],
				[Vector2(326, 300), Vector2(422, 300)]
			],
			"arrow_slit": Rect2(375, 360, 8, 30),
			"rubble": [
				Rect2(260, 580, 40, 40),
				Rect2(435, 590, 35, 30),
				Rect2(455, 600, 25, 20)
			],
			"ember_sparks": [Vector2(350, 265), Vector2(410, 275)]
		})

		# Landmark 2: Shattered Trebuchet & Siege Engine Wreckage (x ≈ 5500)
		cached_landmarks.append({
			"type": "trebuchet_wreckage",
			"a_frame_left": PackedVector2Array([
				Vector2(5380, 620), Vector2(5470, 380), Vector2(5495, 380), Vector2(5420, 620)
			]),
			"a_frame_right": PackedVector2Array([
				Vector2(5580, 620), Vector2(5495, 380), Vector2(5470, 380), Vector2(5540, 620)
			]),
			"cross_beam": Rect2(5405, 490, 150, 16),
			"throwing_arm": PackedVector2Array([
				Vector2(5440, 360), Vector2(5580, 490), Vector2(5570, 505), Vector2(5430, 375)
			]),
			"counterweight_box": Rect2(5410, 350, 45, 40),
			"broken_wheel_center": Vector2(5600, 580),
			"broken_wheel_radius": 36.0,
			"siege_bolts": [
				[Vector2(5350, 615), Vector2(5390, 600)],
				[Vector2(5365, 618), Vector2(5410, 608)],
				[Vector2(5590, 612), Vector2(5635, 618)]
			]
		})

		# Landmark 3: Crossbow Commander's Command Parapet (x ≈ 10000)
		cached_landmarks.append({
			"type": "command_parapet",
			"base_rampart": Rect2(9880, 360, 240, 260),
			"courses": [
				[Vector2(9880, 430), Vector2(10120, 430)],
				[Vector2(9880, 500), Vector2(10120, 500)],
				[Vector2(9880, 570), Vector2(10120, 570)]
			],
			"crenels": [
				Rect2(9880, 320, 42, 45),
				Rect2(9946, 320, 42, 45),
				Rect2(10012, 320, 42, 45),
				Rect2(10078, 320, 42, 45)
			],
			"flagpoles": [
				[Vector2(9915, 300), Vector2(9915, 415)],
				[Vector2(10100, 300), Vector2(10100, 420)]
			],
			"ballista_mount": Rect2(9940, 280, 70, 45),
			"ballista_bow": PackedVector2Array([
				Vector2(9920, 290), Vector2(9975, 275), Vector2(10030, 290),
				Vector2(10025, 298), Vector2(9975, 285), Vector2(9925, 298)
			]),
			"banners": [
				PackedVector2Array([Vector2(9905, 325), Vector2(9930, 335), Vector2(9920, 410), Vector2(9895, 395)]),
				PackedVector2Array([Vector2(10090, 325), Vector2(10115, 335), Vector2(10105, 415), Vector2(10080, 400)])
			],
			"braziers": [Vector2(9870, 350), Vector2(10130, 350)]
		})

		# Boss Arena Architecture (x ≈ 10000..11200)
		cached_landmarks.append({
			"type": "boss_arena_wall",
			"arena_backdrop_crenels": [
				Rect2(10250, 480, 50, 40), Rect2(10350, 480, 50, 40),
				Rect2(10450, 480, 50, 40), Rect2(10550, 480, 50, 40),
				Rect2(10650, 480, 50, 40), Rect2(10750, 480, 50, 40),
				Rect2(10850, 480, 50, 40), Rect2(10950, 480, 50, 40)
			],
			"burnt_stakes": [
				[Vector2(10220, 620), Vector2(10235, 570)],
				[Vector2(10240, 620), Vector2(10250, 575)],
				[Vector2(11020, 620), Vector2(11005, 570)],
				[Vector2(11040, 620), Vector2(11030, 575)]
			],
			"scorch_rects": [
				Rect2(10300, 615, 120, 5),
				Rect2(10600, 615, 160, 5)
			]
		})
	elif cached_stage_num == 4:
		# Landmark 1: Great Rune Monolith Gate (거대한 룬 석문, x ≈ 400)
		# Lintel top at y=230 to keep 70px buffer below top HUD
		cached_landmarks.append({
			"type": "rune_monolith_gate",
			"left_monolith": Rect2(310, 260, 60, 360),
			"right_monolith": Rect2(450, 260, 60, 360),
			"lintel": Rect2(285, 220, 250, 42),
			"cornice": Rect2(270, 210, 280, 12),
			"keystone": Vector2(410, 241),
			"rune_line": [Vector2(315, 241), Vector2(505, 241)],
			"joints": [
				[Vector2(310, 360), Vector2(370, 360)],
				[Vector2(310, 480), Vector2(370, 480)],
				[Vector2(450, 360), Vector2(510, 360)],
				[Vector2(450, 480), Vector2(510, 480)]
			],
			"rubble": [
				Rect2(265, 585, 42, 35),
				Rect2(515, 590, 38, 30)
			]
		})

		# Landmark 2: Fallen Ancient Guardian Colossus (쓰러진 수호자 석상, x ≈ 5400)
		cached_landmarks.append({
			"type": "guardian_colossus",
			"head_poly": PackedVector2Array([
				Vector2(5310, 620), Vector2(5325, 510), Vector2(5370, 460), Vector2(5435, 460),
				Vector2(5475, 515), Vector2(5470, 620)
			]),
			"eye_socket": Rect2(5375, 505, 26, 15),
			"fissure_rune": [
				Vector2(5400, 465), Vector2(5390, 520), Vector2(5415, 565), Vector2(5390, 620)
			],
			"broken_arm": PackedVector2Array([
				Vector2(5475, 620), Vector2(5490, 535), Vector2(5545, 515),
				Vector2(5565, 545), Vector2(5550, 620)
			]),
			"shield_fragment": PackedVector2Array([
				Vector2(5560, 620), Vector2(5575, 485), Vector2(5635, 485),
				Vector2(5655, 565), Vector2(5640, 620)
			]),
			"rubble_blocks": [
				Rect2(5265, 595, 40, 25),
				Rect2(5645, 600, 38, 20)
			]
		})

		# Landmark 3: Ancient Guardian Sanctuary Gate & Statues (x ≈ 10000)
		cached_landmarks.append({
			"type": "guardian_sanctuary_gate",
			"portal_frame": Rect2(9920, 270, 220, 350),
			"portal_jamb_top": Rect2(9890, 250, 280, 25),
			"portal_inner": Rect2(9950, 305, 160, 315),
			"rune_circle_center": Vector2(10030, 430),
			"left_sentinel": PackedVector2Array([
				Vector2(9830, 620), Vector2(9840, 460), Vector2(9860, 330), Vector2(9900, 320),
				Vector2(9910, 470), Vector2(9900, 620)
			]),
			"right_sentinel": PackedVector2Array([
				Vector2(10150, 620), Vector2(10140, 470), Vector2(10150, 320), Vector2(10190, 330),
				Vector2(10210, 460), Vector2(10220, 620)
			]),
			"braziers": [Vector2(9850, 490), Vector2(10200, 490)]
		})

		# Boss Arena Architecture (x ≈ 10000..11200)
		cached_landmarks.append({
			"type": "sanctuary_boss_arena",
			"altar_steps": [
				Rect2(10300, 600, 340, 20),
				Rect2(10340, 578, 260, 22),
				Rect2(10390, 554, 160, 24)
			],
			"altar_rune_center": Vector2(10470, 566),
			"pillars": [
				Rect2(10280, 360, 46, 260),
				Rect2(10420, 360, 46, 260),
				Rect2(10560, 360, 46, 260),
				Rect2(10700, 360, 46, 260),
				Rect2(10840, 360, 46, 260),
				Rect2(10980, 360, 46, 260)
			],
			"floor_runes": [
				[Vector2(10300, 616), Vector2(10640, 616)],
				[Vector2(10720, 616), Vector2(11060, 616)]
			]
		})

	# 4. Precompute route choice plaques
	cached_route_signs.clear()
	if "route_clusters" in stage and stage.route_clusters != null:
		for cluster in stage.route_clusters:
			var at := Vector2(float(cluster.left) + 10.0, 376.0)
			var sign_rect := Rect2(at - Vector2(10, 23), Vector2(264, 54))
			var notch_rect := Rect2(sign_rect.position.x + 3, sign_rect.position.y + 4, 4, sign_rect.size.y - 8)
			cached_route_signs.append({
				"at": at,
				"rect": sign_rect,
				"notch": notch_rect
			})

	# 5. Precompute checkpoints
	cached_checkpoints.clear()
	if "CHECKPOINT_POSITIONS" in stage and stage.CHECKPOINT_POSITIONS != null:
		for index in range(stage.CHECKPOINT_POSITIONS.size()):
			cached_checkpoints.append({
				"index": index,
				"pos": stage.CHECKPOINT_POSITIONS[index]
			})

	if "GOAL_X" in stage:
		cached_goal_pos = Vector2(float(stage.GOAL_X), 560.0)

	is_cached = true
	queue_redraw()

func invalidate() -> void:
	queue_redraw()

func _draw() -> void:
	if not is_cached or not is_instance_valid(stage) or ground_texture == null:
		return

	# 1. Ground tiles from precomputed cache
	for tile in cached_ground_tiles:
		if tile.flip:
			draw_set_transform(tile.pos, 0, Vector2(-1, 1))
		else:
			draw_set_transform(tile.pos)
		draw_texture_rect_region(ground_texture, tile.rect, tile.source)
	draw_set_transform(Vector2.ZERO)

	# 2. Ground top edge line
	var world_w: float = float(stage.get("WORLD_WIDTH")) if "WORLD_WIDTH" in stage else 11000.0
	draw_line(Vector2(0, 620), Vector2(world_w, 620), edge_color, 2.0)

	# 2.5 Landmarks from cache
	for lm in cached_landmarks:
		if lm.type == "portal":
			for r in lm.pillars:
				draw_rect(r, Color(0.25, 0.28, 0.23, 0.94))
				draw_rect(r, Color(0.36, 0.44, 0.28, 0.85), false, 1.5)
			for j in lm.stone_joints:
				draw_line(j[0], j[1], Color(0.14, 0.17, 0.12, 0.85), 2.0)
			for l in lm.lintels:
				draw_rect(l, Color(0.27, 0.30, 0.24, 0.95))
				draw_rect(l, Color(0.38, 0.46, 0.30, 0.85), false, 1.5)
			for root in lm.roots:
				draw_colored_polygon(root, Color(0.17, 0.13, 0.10, 0.95))
				draw_polyline(root, Color(0.28, 0.38, 0.18, 0.80), 1.5, true)
			for rub in lm.rubble:
				draw_rect(rub, Color(0.24, 0.27, 0.22, 0.92))
				draw_rect(rub, Color(0.34, 0.42, 0.26, 0.80), false, 1.5)
			draw_circle(lm.keystone, 7.0, Color(2.4, 1.4, 0.3, 0.90))
			draw_circle(lm.keystone, 3.0, Color(3.2, 2.5, 1.2, 0.98))
		elif lm.type == "colossus":
			draw_colored_polygon(lm.horn_poly, Color(0.28, 0.30, 0.25, 0.94))
			draw_polyline(lm.horn_poly, Color(0.40, 0.50, 0.30, 0.85), 2.0, true)
			draw_colored_polygon(lm.head_poly, Color(0.24, 0.26, 0.22, 0.95))
			draw_polyline(lm.head_poly, Color(0.36, 0.46, 0.28, 0.85), 2.0, true)
			draw_rect(lm.pedestal_rect, Color(0.22, 0.24, 0.20, 0.95))
			draw_circle(lm.eye_pos, 4.5, Color(2.0, 1.2, 0.35, 0.85))
		elif lm.type == "totem_gate":
			draw_colored_polygon(lm.left_tusk, Color(0.70, 0.65, 0.55, 0.94))
			draw_polyline(lm.left_tusk, Color(0.45, 0.42, 0.34, 0.85), 1.5, true)
			draw_colored_polygon(lm.right_tusk, Color(0.70, 0.65, 0.55, 0.94))
			draw_polyline(lm.right_tusk, Color(0.45, 0.42, 0.34, 0.85), 1.5, true)
			for b in lm.bands:
				draw_rect(b, Color(0.18, 0.16, 0.14, 0.95))
			draw_rect(lm.cross_beam, Color(0.28, 0.22, 0.17, 0.95))
			draw_circle(lm.ward_gem, 7.5, Color(2.8, 1.3, 0.3, 0.95))
			draw_circle(lm.ward_gem, 3.5, Color(3.5, 2.5, 1.0, 0.98))
		elif lm.type == "boss_arena":
			draw_colored_polygon(lm.left_arch, Color(0.16, 0.13, 0.10, 0.92))
			draw_polyline(lm.left_arch, Color(0.28, 0.38, 0.22, 0.80), 2.0, true)
			draw_colored_polygon(lm.right_arch, Color(0.16, 0.13, 0.10, 0.92))
			draw_polyline(lm.right_arch, Color(0.28, 0.38, 0.22, 0.80), 2.0, true)
			draw_rect(lm.altar_base, Color(0.20, 0.22, 0.18, 0.95))
			draw_rect(lm.altar_step, Color(0.25, 0.27, 0.22, 0.95))
			draw_rect(lm.altar_slab, Color(0.32, 0.20, 0.18, 0.98))
			draw_line(lm.altar_center + Vector2(-22, -6), lm.altar_center + Vector2(20, 8), Color(2.6, 0.9, 0.2, 0.90), 2.5, true)
			draw_line(lm.altar_center + Vector2(-12, -11), lm.altar_center + Vector2(24, 4), Color(3.0, 1.2, 0.3, 0.95), 1.8, true)
			for bz in lm.braziers:
				draw_rect(Rect2(bz.x - 7, bz.y, 14, 30), Color(0.20, 0.17, 0.14, 0.95))
				draw_circle(bz + Vector2(0, -3), 7.0, Color(2.8, 1.2, 0.25, 0.85))
				draw_circle(bz + Vector2(0, -3), 3.0, Color(3.5, 2.5, 1.0, 0.98))
		elif lm.type == "leaning_watchtower":
			draw_colored_polygon(lm.tower_poly, Color(0.22, 0.20, 0.24, 0.95))
			draw_polyline(lm.tower_poly, Color(0.36, 0.32, 0.38, 0.85), 2.0, true)
			if lm.has("courses"):
				for c in lm.courses:
					draw_line(c[0], c[1], Color(0.14, 0.12, 0.16, 0.70), 1.5)
			if lm.has("arrow_slit"):
				draw_rect(lm.arrow_slit, Color(0.10, 0.08, 0.12, 0.98))
				draw_rect(lm.arrow_slit, Color(0.35, 0.30, 0.38, 0.80), false, 1.0)
			for b in lm.battlements:
				draw_rect(b, Color(0.24, 0.21, 0.26, 0.95))
				draw_rect(b, Color(0.38, 0.33, 0.40, 0.80), false, 1.5)
			for f in lm.fractures:
				draw_line(f[0], f[1], Color(0.10, 0.08, 0.12, 0.90), 2.5)
			for bm in lm.exposed_beams:
				draw_rect(bm, Color(0.18, 0.13, 0.10, 0.98))
			for r in lm.rubble:
				draw_rect(r, Color(0.20, 0.18, 0.22, 0.95))
				draw_rect(r, Color(0.32, 0.28, 0.34, 0.75), false, 1.5)
			for spk in lm.ember_sparks:
				draw_circle(spk, 4.0, Color(2.4, 1.1, 0.3, 0.85))
		elif lm.type == "trebuchet_wreckage":
			draw_colored_polygon(lm.a_frame_left, Color(0.20, 0.15, 0.12, 0.95))
			draw_polyline(lm.a_frame_left, Color(0.34, 0.26, 0.19, 0.80), 2.0, true)
			draw_colored_polygon(lm.a_frame_right, Color(0.20, 0.15, 0.12, 0.95))
			draw_polyline(lm.a_frame_right, Color(0.34, 0.26, 0.19, 0.80), 2.0, true)
			draw_rect(lm.cross_beam, Color(0.24, 0.18, 0.14, 0.95))
			draw_colored_polygon(lm.throwing_arm, Color(0.16, 0.12, 0.09, 0.98))
			draw_polyline(lm.throwing_arm, Color(0.30, 0.22, 0.16, 0.85), 1.5, true)
			draw_rect(lm.counterweight_box, Color(0.14, 0.13, 0.15, 0.98))
			draw_arc(lm.broken_wheel_center, lm.broken_wheel_radius, 0.4, PI * 1.6, 16, Color(0.26, 0.20, 0.16, 0.95), 5.0, true)
			draw_circle(lm.broken_wheel_center, 8.0, Color(0.18, 0.17, 0.18, 0.95))
			for blt in lm.siege_bolts:
				draw_line(blt[0], blt[1], Color(0.45, 0.38, 0.32, 0.90), 2.5)
		elif lm.type == "command_parapet":
			draw_rect(lm.base_rampart, Color(0.22, 0.20, 0.25, 0.95))
			draw_rect(lm.base_rampart, Color(0.35, 0.30, 0.38, 0.85), false, 2.0)
			if lm.has("courses"):
				for c in lm.courses:
					draw_line(c[0], c[1], Color(0.14, 0.12, 0.16, 0.65), 1.5)
			for cr in lm.crenels:
				draw_rect(cr, Color(0.24, 0.21, 0.27, 0.95))
				draw_rect(cr, Color(0.38, 0.33, 0.42, 0.80), false, 1.5)
			draw_rect(lm.ballista_mount, Color(0.16, 0.14, 0.18, 0.98))
			draw_colored_polygon(lm.ballista_bow, Color(0.38, 0.28, 0.20, 0.95))
			draw_polyline(lm.ballista_bow, Color(0.55, 0.42, 0.30, 0.85), 2.0, true)
			if lm.has("flagpoles"):
				for fp in lm.flagpoles:
					draw_line(fp[0], fp[1], Color(0.25, 0.20, 0.16, 0.95), 3.0)
			for bnr in lm.banners:
				draw_colored_polygon(bnr, Color(0.75, 0.18, 0.16, 0.90))
				draw_polyline(bnr, Color(1.0, 0.35, 0.25, 0.80), 1.5, true)
			for bz in lm.braziers:
				draw_rect(Rect2(bz.x - 8, bz.y, 16, 32), Color(0.18, 0.16, 0.19, 0.95))
				draw_circle(bz + Vector2(0, -4), 8.0, Color(2.6, 1.1, 0.3, 0.85))
				draw_circle(bz + Vector2(0, -4), 4.0, Color(3.5, 2.4, 1.0, 0.98))
		elif lm.type == "boss_arena_wall":
			for cr in lm.arena_backdrop_crenels:
				draw_rect(cr, Color(0.18, 0.16, 0.20, 0.90))
				draw_rect(cr, Color(0.28, 0.24, 0.30, 0.75), false, 1.5)
			for stk in lm.burnt_stakes:
				draw_line(stk[0], stk[1], Color(0.14, 0.11, 0.09, 0.95), 3.5)
			for sc in lm.scorch_rects:
				draw_rect(sc, Color(0.08, 0.06, 0.08, 0.85))
		elif lm.type == "rune_monolith_gate":
			draw_rect(lm.left_monolith, Color(0.24, 0.22, 0.26, 0.95))
			draw_rect(lm.left_monolith, Color(0.36, 0.34, 0.38, 0.85), false, 1.5)
			draw_rect(lm.right_monolith, Color(0.24, 0.22, 0.26, 0.95))
			draw_rect(lm.right_monolith, Color(0.36, 0.34, 0.38, 0.85), false, 1.5)
			for j in lm.joints:
				draw_line(j[0], j[1], Color(0.12, 0.11, 0.14, 0.85), 2.0)
			draw_rect(lm.lintel, Color(0.26, 0.24, 0.28, 0.95))
			draw_rect(lm.lintel, Color(0.38, 0.36, 0.40, 0.85), false, 1.5)
			draw_rect(lm.cornice, Color(0.28, 0.26, 0.30, 0.95))
			draw_rect(lm.cornice, Color(0.40, 0.38, 0.42, 0.80), false, 1.5)
			draw_line(lm.rune_line[0], lm.rune_line[1], Color(0.3, 1.8, 2.2, 0.65), 2.5)
			draw_circle(lm.keystone, 8.0, Color(0.3, 1.8, 2.2, 0.75))
			draw_circle(lm.keystone, 4.0, Color(1.1, 2.2, 2.5, 0.95))
			for rub in lm.rubble:
				draw_rect(rub, Color(0.22, 0.20, 0.24, 0.92))
				draw_rect(rub, Color(0.32, 0.30, 0.34, 0.75), false, 1.5)
		elif lm.type == "guardian_colossus":
			draw_colored_polygon(lm.head_poly, Color(0.22, 0.21, 0.25, 0.95))
			draw_polyline(lm.head_poly, Color(0.35, 0.33, 0.38, 0.85), 2.0, true)
			draw_rect(lm.eye_socket, Color(0.10, 0.09, 0.12, 0.98))
			draw_circle(lm.eye_socket.position + lm.eye_socket.size * 0.5, 3.5, Color(0.3, 1.8, 2.2, 0.55))
			for i in range(lm.fissure_rune.size() - 1):
				draw_line(lm.fissure_rune[i], lm.fissure_rune[i + 1], Color(0.3, 1.8, 2.2, 0.60), 2.0)
			draw_colored_polygon(lm.broken_arm, Color(0.20, 0.19, 0.23, 0.95))
			draw_polyline(lm.broken_arm, Color(0.32, 0.30, 0.35, 0.80), 1.5, true)
			draw_colored_polygon(lm.shield_fragment, Color(0.23, 0.22, 0.26, 0.95))
			draw_polyline(lm.shield_fragment, Color(0.36, 0.34, 0.40, 0.80), 1.5, true)
			for blk in lm.rubble_blocks:
				draw_rect(blk, Color(0.21, 0.20, 0.24, 0.92))
				draw_rect(blk, Color(0.33, 0.31, 0.36, 0.75), false, 1.5)
		elif lm.type == "guardian_sanctuary_gate":
			draw_rect(lm.portal_frame, Color(0.22, 0.20, 0.25, 0.95))
			draw_rect(lm.portal_frame, Color(0.35, 0.33, 0.38, 0.85), false, 2.0)
			draw_rect(lm.portal_jamb_top, Color(0.25, 0.23, 0.28, 0.95))
			draw_rect(lm.portal_jamb_top, Color(0.38, 0.36, 0.42, 0.85), false, 1.5)
			draw_rect(lm.portal_inner, Color(0.08, 0.07, 0.10, 0.98))
			draw_circle(lm.rune_circle_center, 42.0, Color(0.3, 1.8, 2.2, 0.40))
			draw_arc(lm.rune_circle_center, 42.0, 0, TAU, 32, Color(0.4, 2.0, 2.4, 0.75), 2.0, true)
			draw_arc(lm.rune_circle_center, 24.0, 0, TAU, 24, Color(0.4, 2.0, 2.4, 0.65), 1.5, true)
			draw_colored_polygon(lm.left_sentinel, Color(0.24, 0.22, 0.27, 0.95))
			draw_polyline(lm.left_sentinel, Color(0.38, 0.35, 0.42, 0.85), 2.0, true)
			draw_colored_polygon(lm.right_sentinel, Color(0.24, 0.22, 0.27, 0.95))
			draw_polyline(lm.right_sentinel, Color(0.38, 0.35, 0.42, 0.85), 2.0, true)
			for bz in lm.braziers:
				draw_rect(Rect2(bz.x - 8, bz.y, 16, 32), Color(0.18, 0.16, 0.20, 0.95))
				draw_circle(bz + Vector2(0, -4), 8.0, Color(2.6, 1.2, 0.3, 0.85))
				draw_circle(bz + Vector2(0, -4), 4.0, Color(3.5, 2.5, 1.1, 0.98))
		elif lm.type == "sanctuary_boss_arena":
			for st in lm.altar_steps:
				draw_rect(st, Color(0.23, 0.21, 0.26, 0.95))
				draw_rect(st, Color(0.36, 0.33, 0.40, 0.85), false, 1.5)
			draw_circle(lm.altar_rune_center, 12.0, Color(0.3, 1.8, 2.2, 0.65))
			draw_circle(lm.altar_rune_center, 5.0, Color(1.1, 2.2, 2.5, 0.95))
			for pil in lm.pillars:
				draw_rect(pil, Color(0.21, 0.19, 0.24, 0.92))
				draw_rect(pil, Color(0.34, 0.31, 0.38, 0.80), false, 1.5)
			for fr in lm.floor_runes:
				draw_line(fr[0], fr[1], Color(0.3, 1.8, 2.2, 0.50), 2.0)

	# 3. Platforms, slab shadows, corbels/roots, polylines from cache
	for p in cached_platforms:
		var points: PackedVector2Array = p.points
		if p.has_supports:
			draw_rect(p.slab_shadow, Color(0.02, 0.04, 0.06, 0.42))
			if cached_stage_num == 2:
				if p.has("moss_underlayer") and not p.moss_underlayer.is_empty():
					draw_colored_polygon(p.moss_underlayer, Color(0.13, 0.22, 0.11, 0.95))
				for rp in p.root_polys:
					draw_colored_polygon(rp, Color(0.20, 0.16, 0.12, 0.95))
					draw_polyline(rp, Color(0.32, 0.44, 0.22, 0.80), 2.0, true)
					if rp.size() >= 6:
						draw_line(rp[0] + Vector2(10, 2), rp[3] + Vector2(-18, -2), Color(0.13, 0.10, 0.08, 0.75), 1.5, true)
				for vine in p.hanging_moss:
					draw_line(vine.start, vine.end, Color(0.22, 0.38, 0.15, 0.90), 1.5, true)
					draw_circle(vine.leaf, 2.0, Color(0.35, 0.55, 0.24, 0.95))
			elif cached_stage_num == 3:
				if p.has("slab_timber"):
					draw_rect(p.slab_timber, Color(0.16, 0.12, 0.10, 0.95))
				if p.has("fractured_pillars"):
					for pil in p.fractured_pillars:
						draw_rect(pil.rect, Color(0.22, 0.20, 0.24, 0.95))
						draw_rect(pil.rect, Color(0.34, 0.30, 0.36, 0.85), false, 1.5)
						for j_idx in range(0, pil.joints.size(), 2):
							if j_idx + 1 < pil.joints.size():
								draw_line(pil.joints[j_idx], pil.joints[j_idx + 1], Color(0.11, 0.09, 0.12, 0.85), 2.0)
						draw_rect(pil.clamp, Color(0.14, 0.13, 0.16, 0.98))
						draw_colored_polygon(pil.corbel, Color(0.19, 0.17, 0.21, 0.95))
						draw_polyline(pil.corbel, Color(0.36, 0.31, 0.38, 0.80), 1.5, true)
				if p.has("scaffold_struts"):
					for st in p.scaffold_struts:
						draw_colored_polygon(st.left, Color(0.18, 0.14, 0.11, 0.95))
						draw_polyline(st.left, Color(0.30, 0.23, 0.17, 0.80), 1.5, true)
						draw_colored_polygon(st.right, Color(0.18, 0.14, 0.11, 0.95))
						draw_polyline(st.right, Color(0.30, 0.23, 0.17, 0.80), 1.5, true)
						draw_rect(st.cross, Color(0.22, 0.17, 0.13, 0.95))
						draw_rect(st.cross, Color(0.34, 0.26, 0.19, 0.85), false, 1.5)
			elif cached_stage_num == 4:
				if p.has("slab_stone"):
					draw_rect(p.slab_stone, Color(0.18, 0.16, 0.20, 0.95))
					draw_line(Vector2(p.slab_stone.position.x, p.slab_stone.position.y), Vector2(p.slab_stone.position.x + p.slab_stone.size.x, p.slab_stone.position.y), Color(0.44, 0.42, 0.48, 0.90), 1.5)
				if p.has("monolith_pillars"):
					for pil in p.monolith_pillars:
						draw_rect(pil.rect, Color(0.22, 0.20, 0.25, 0.95))
						draw_rect(pil.rect, Color(0.35, 0.32, 0.38, 0.85), false, 1.5)
						for j_idx in range(0, pil.joints.size(), 2):
							if j_idx + 1 < pil.joints.size():
								draw_line(pil.joints[j_idx], pil.joints[j_idx + 1], Color(0.12, 0.10, 0.14, 0.85), 2.0)
						draw_colored_polygon(pil.corbel, Color(0.20, 0.18, 0.23, 0.95))
						draw_polyline(pil.corbel, Color(0.36, 0.32, 0.40, 0.80), 1.5, true)
						draw_rect(pil.plinth, Color(0.19, 0.17, 0.22, 0.98))
						draw_rect(pil.plinth, Color(0.32, 0.29, 0.36, 0.85), false, 1.5)
						if pil.has("rune_line") and pil.rune_line.size() >= 2:
							draw_line(pil.rune_line[0], pil.rune_line[1], Color(0.3, 1.8, 2.2, 0.55), 2.0)
				if p.has("pylon_supports"):
					for pyl in p.pylon_supports:
						draw_colored_polygon(pyl.pylon, Color(0.21, 0.19, 0.24, 0.95))
						draw_polyline(pyl.pylon, Color(0.34, 0.31, 0.38, 0.85), 1.5, true)
						draw_colored_polygon(pyl.corbel, Color(0.20, 0.18, 0.22, 0.95))
						draw_polyline(pyl.corbel, Color(0.36, 0.32, 0.40, 0.80), 1.5, true)
						draw_rect(pyl.plinth, Color(0.18, 0.16, 0.21, 0.98))
						draw_rect(pyl.plinth, Color(0.30, 0.27, 0.34, 0.85), false, 1.5)
						if pyl.has("rune_center"):
							draw_circle(pyl.rune_center, 4.0, Color(0.3, 1.8, 2.2, 0.60))
			else:
				for s in p.supports:
					draw_texture_rect_region(ground_texture, s.rect, s.source, s.shade)
				for i in range(p.corbels.size()):
					draw_colored_polygon(p.corbels[i], edge_color.darkened(0.45))
					draw_polyline(p.corbel_polylines[i], edge_color.darkened(0.20), 1.5, true)
					var line_info: Dictionary = p.corbel_lines[i]
					draw_line(line_info.start, line_info.end, edge_color.darkened(0.35), 7, true)
		draw_polyline(points, edge_color.darkened(0.25), 4, true)
		draw_polyline(points, edge_color, 1.5, true)
		draw_polyline(points, edge_color.lightened(0.35) * 1.35, 1.0, true)

	# 4. Route choice stone plaques
	var in_boss: bool = false
	if "encounter_index" in stage and "required_count" in stage and "encounter_active" in stage:
		in_boss = stage.encounter_index >= stage.required_count - 1 and stage.encounter_active

	if not in_boss:
		var style := _sign_style()
		for sign_info in cached_route_signs:
			draw_style_box(style, sign_info.rect)
			draw_rect(sign_info.notch, Color(0.85, 0.72, 0.45, 0.9))
			if cached_stage_num == 2:
				draw_string(font, sign_info.at + Vector2(6, 0), "↑ 상층: 거목 덩굴길 · 회복 +1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4dfb5"))
				draw_string(font, sign_info.at + Vector2(6, 22), "→ 아래 길: 야수 숲길로 진행", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d5e2e2"))
			elif cached_stage_num == 3:
				draw_string(font, sign_info.at + Vector2(6, 0), "↑ 상층: 성벽 흉벽 상부 · 회복 +1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4dfb5"))
				draw_string(font, sign_info.at + Vector2(6, 22), "→ 아래 길: 무너진 성벽 다리로 전진", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d5e2e2"))
			elif cached_stage_num == 4:
				draw_string(font, sign_info.at + Vector2(6, 0), "↑ 상층: 고대 성소 상층 회랑 · 회복 +1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4dfb5"))
				draw_string(font, sign_info.at + Vector2(6, 22), "→ 아래 길: 거석 의식 통로로 전진", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d5e2e2"))
			else:
				draw_string(font, sign_info.at + Vector2(6, 0), "↑ 상층: 선택 전투 · 회복 +1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4dfb5"))
				draw_string(font, sign_info.at + Vector2(6, 22), "→ 아래 길: 필수 전투로 합류", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d5e2e2"))

	# 5. Encounter Gates
	if "gates" in stage and stage.gates != null:
		for index in range(stage.gates.size()):
			var gate = stage.gates[index]
			if not is_instance_valid(gate) or gate.is_queued_for_deletion():
				continue
			var x: float = gate.position.x
			draw_rect(Rect2(x - 12, 0, 24, 620), Color(0.25, 0.65, 0.7, 0.12))
			draw_line(Vector2(x - 10, 0), Vector2(x - 10, 620), Color(0.42, 0.82, 0.84, 0.65), 2)
			draw_line(Vector2(x + 10, 0), Vector2(x + 10, 620), Color(0.42, 0.82, 0.84, 0.65), 2)
			for y in range(30, 620, 42):
				draw_line(Vector2(x - 7, y), Vector2(x + 7, y + 12), Color(0.55, 0.88, 0.85, 0.45), 2)
			draw_string_outline(font, Vector2(x - 38, 516), "%d구간 봉인" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("203137"))
			draw_string(font, Vector2(x - 38, 516), "%d구간 봉인" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.65, 0.88, 0.86))

	# 6. Checkpoints
	var current_cp: int = int(stage.get("checkpoint_index")) if "checkpoint_index" in stage else -1
	for cp in cached_checkpoints:
		var idx: int = cp.index
		var status_str: String = "최근 저장" if idx == current_cp else "통과함" if idx < current_cp else "체크포인트"
		var checkpoint_text := "휴식처 %d · %s" % [idx + 1, status_str]
		draw_string_outline(font, cp.pos + Vector2(-65, -93), checkpoint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("142126"))
		draw_string(font, cp.pos + Vector2(-65, -93), checkpoint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.47, 0.88, 0.9))

	# 7. Goal Marker
	var goal_ready: bool = "completed" in stage and not stage.completed.has(false)
	draw_string_outline(font, Vector2(cached_goal_pos.x - 46, 474), "목표에 도착하세요" if goal_ready else "최종 목적지", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("142126"))
	draw_string(font, Vector2(cached_goal_pos.x - 46, 474), "목표에 도착하세요" if goal_ready else "최종 목적지", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.89, 0.79, 0.55))
