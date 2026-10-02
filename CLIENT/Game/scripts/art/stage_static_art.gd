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
var cached_route_signs: Array[Dictionary] = []
var cached_checkpoints: Array[Dictionary] = []
var cached_goal_pos: Vector2 = Vector2.ZERO

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

	# 2. Precompute platform terrain geometry & corbels
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
			"corbel_lines": []
		}

		if points.size() == 2 and points[0].y < 540 and points[1].x - points[0].x > 140:
			platform_data.has_supports = true
			platform_data.slab_shadow = Rect2(points[0].x, points[0].y + 18, points[1].x - points[0].x, 8)
			var shade := Color(0.63, 0.66, 0.65, 0.88)
			var stage_num: int = int(stage.get("stage_number")) if "stage_number" in stage else 1
			var width := 24.0 if stage_num == 2 else 30.0

			for x_pos in [points[0].x + 36, points[1].x - 36]:
				var top_at := Vector2(x_pos, points[0].y + 18)
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

	# 3. Precompute route choice plaques
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

	# 4. Precompute checkpoints
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

	# 3. Platforms, slab shadows, corbels, polylines from cache
	for p in cached_platforms:
		var points: PackedVector2Array = p.points
		if p.has_supports:
			draw_rect(p.slab_shadow, Color(0.02, 0.04, 0.06, 0.42))
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
