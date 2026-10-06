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

		var is_stage2: bool = (cached_stage_num == 2)
		var valid_height: bool = (top_y < 595) if is_stage2 else (top_y < 540)
		var valid_width: bool = (p_width > 40.0) if is_stage2 else (p_width > 140.0)

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
