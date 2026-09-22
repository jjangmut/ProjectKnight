extends Node2D
## Fixed Stage graphics adapter: reads gameplay state; owns no gameplay decisions.

const BOUNDS := {
	"melee": Rect2(252, 28, 733, 1211),
	"ranged": Rect2(185, 42, 927, 1149),
	"projectile": Rect2(508, 202, 923, 381),
	"goal": Rect2(210, 120, 470, 1492),
}
const REVISION_BOUNDS := {"melee": Rect2(245,57,850,1174), "ranged": Rect2(136,75,1057,1088), "beast": Rect2(84,81,1369,834), "golem": Rect2(33,21,1331,1091)}
const TERRAIN_NAMES := ["outskirts", "forest", "wall", "sanctuary", "citadel"]
const TERRAIN_EDGES := [Color("d8cba0"), Color("91a365"), Color("a9c1cf"), Color("cbb484"), Color("a3a9bf")]
const ParallaxStageBackdropClass := preload("res://scripts/art/parallax_stage_backdrop.gd")
var textures: Dictionary = {}
var enemy_motions: Dictionary = {}
var actors: Array[Dictionary] = []
var installed := false
var background: TextureRect
var motion_time := 0.0
var player_pose := "idle"
var player_art: Sprite2D
var player_base_position := Vector2.ZERO
var player_base_scale := Vector2.ONE
var guard_audio: AudioStreamPlayer
var previous_guard_blocks := 0
var world_font := SystemFont.new()
@onready var stage: Node2D = get_parent()

func _guard_clang() -> AudioStreamWAV:
	# Original short procedural metallic placeholder; no external audio asset.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(4410 * 2)
	for index in range(4410):
		var t := float(index) / wav.mix_rate
		var envelope := minf(t * 1500.0, 1.0) * exp(-t * 34.0)
		var tone := sin(TAU * 1460 * t) * 0.45 + sin(TAU * 2371 * t) * 0.30 + sin(TAU * 3833 * t) * 0.20
		pcm.encode_s16(index * 2, int(tone * envelope * 16000))
	wav.data = pcm
	return wav

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR"])
	stage.child_entered_tree.connect(_on_stage_child)
	_install.call_deferred()

func _install() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(stage) or stage.is_queued_for_deletion():
		return
	for key in ["melee", "ranged", "projectile", "goal", "ground", "background"]:
		var raw: Texture2D = load("res://assets/stage_batch/%s.png" % key)
		if BOUNDS.has(key):
			var atlas := AtlasTexture.new()
			atlas.atlas = raw
			atlas.region = BOUNDS[key]
			textures[key] = atlas
		else:
			textures[key] = raw
	for key in ["melee", "ranged", "beast", "golem", "background"]:
		var raw: Texture2D = load("res://assets/stage_revision2/%s.png" % key)
		if key == "background":
			textures[key] = raw
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = raw
			atlas.region = REVISION_BOUNDS[key]
			textures[key] = atlas
	if stage.stage_number == 2 and ResourceLoader.exists("res://assets/stage_two/background_v1.png"):
		textures.background = load("res://assets/stage_two/background_v1.png")
	var campaign_backgrounds := {3: "stage_three_v1", 4: "stage_four_v1", 5: "stage_five_v1"}
	if campaign_backgrounds.has(stage.stage_number):
		var background_path: String = "res://assets/campaign/%s.png" % campaign_backgrounds[stage.stage_number]
		if ResourceLoader.exists(background_path):
			textures.background = load(background_path)
	textures.ground = load("res://assets/terrain_v2/%s.png" % TERRAIN_NAMES[stage.stage_number - 1])
	_load_enemy_motions()
	var parallax_bg = ParallaxStageBackdropClass.new()
	parallax_bg.name = "ParallaxStageBackdrop"
	add_child(parallax_bg)
	parallax_bg.setup_parallax(stage.stage_number, textures.background)

	var layer := CanvasLayer.new()
	layer.name = "StageBackdrop"
	layer.layer = -10
	add_child(layer)
	background = TextureRect.new()
	background.texture = textures.background
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color(1, 1, 1, 0.45)
	layer.add_child(background)
	background.size = get_viewport_rect().size
	for terrain in get_tree().get_nodes_in_group("stage_terrain"):
		if not stage.is_ancestor_of(terrain):
			continue
		for visual in terrain.get_children():
			if visual is Polygon2D:
				visual.texture = textures.ground
				visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var uv := PackedVector2Array()
				var top := INF
				for vertex in visual.polygon:
					top = minf(top, vertex.y)
				for vertex in visual.polygon:
					uv.append(Vector2(vertex.x * textures.ground.get_width() / 384.0, (vertex.y - top) * textures.ground.get_height() / 128.0))
				visual.uv = uv
				visual.color = Color.WHITE
	for child in stage.get_children():
		if child is Label:
			child.visible = false
		if child is StaticBody2D and child.name in ["Ground", "LeftWall", "RightWall"]:
			for visual in child.get_children():
				if visual is Polygon2D:
					visual.visible = false
		if child is StaticBody2D and str(child.name).begins_with("Gate"):
			for visual in child.get_children():
				if visual is Polygon2D:
					visual.visible = false
		if child is Polygon2D and child.position == Vector2(stage.GOAL_X, 560):
			child.visible = false
	var goal := _sprite("goal", 120.0)
	goal.name = "GoalArt"
	goal.position = Vector2(stage.GOAL_X, 560)
	add_child(goal)
	installed = true
	guard_audio = AudioStreamPlayer.new()
	guard_audio.name = "GuardClang"
	guard_audio.stream = _guard_clang()
	guard_audio.volume_db = -10.0
	add_child(guard_audio)
	player_art = stage.player.get_node_or_null("CharacterArt")
	stage.player.get_node("Camera2D").zoom = Vector2(1.22, 1.22)
	if player_art != null:
		player_base_position = player_art.position
		player_base_scale = player_art.scale
		# One presentation pass after physics owns both tint/facing and pose.
		player_art.set_process(false)
	for child in stage.get_children():
		_attach(child)
	queue_redraw()

func _on_stage_child(child: Node) -> void:
	# A projectile may be freed by checkpoint reset before the deferred call runs.
	_attach_instance.call_deferred(child.get_instance_id())

func _attach_instance(instance_id: int) -> void:
	if is_instance_id_valid(instance_id):
		_attach(instance_from_id(instance_id))

func _sprite(key: String, height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = textures[key]
	sprite.scale = Vector2.ONE * (height / sprite.texture.get_height())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite

func _load_enemy_motions() -> void:
	var path := "res://assets/enemy_frames/enemy_motion_manifest.json"
	if not FileAccess.file_exists(path):
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary:
		return
	for variant in manifest:
		var spec: Dictionary = manifest[variant]
		var file: String = spec.get("file", "")
		if not file.begins_with("res://"):
			file = "res://assets/enemy_frames/" + file
		if not ResourceLoader.exists(file):
			continue
		var sheet := load(file) as Texture2D
		var pivots: Array = spec.get("pivots", [])
		var regions: Array = spec.get("regions", [])
		var columns := maxi(1, int(spec.get("columns", 3)))
		var rows := maxi(1, int(spec.get("rows", 2)))
		if sheet == null or pivots.size() != 6 or (regions.is_empty() and columns * rows < 6) or (not regions.is_empty() and regions.size() != 6):
			continue
		var frames: Array[AtlasTexture] = []
		var cell_size := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
		for index in range(6):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(index % columns, floori(index / float(columns))) * cell_size, cell_size)
			if not regions.is_empty():
				var region: Array = regions[index]
				frame.region = Rect2(region[0], region[1], region[2], region[3])
			frames.append(frame)
		enemy_motions[variant] = {"frames": frames, "pivots": pivots, "scale": float(spec.get("scale", 1.0))}

func _attach(actor: Node) -> void:
	if not installed or not is_inside_tree() or not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.has_node("BatchArt"):
		return
	if not actor.get_script():
		return
	var source: String = actor.get_script().resource_path
	var key := ""
	if source.ends_with("/test_enemy.gd") or source.ends_with("/charging_beast.gd") or source.ends_with("/ground_slam_golem.gd"):
		key = "melee"
	elif source.ends_with("/ranged_enemy.gd"):
		key = "ranged"
	elif source.ends_with("/enemy_projectile.gd"):
		key = "projectile"
	if key.is_empty():
		return
	var variant: String = actor.get_meta("art_variant", key)
	var height := 12.0 if key == "projectile" else 96.0 if variant == "golem" else 50.0 if variant == "beast" else 64.0
	var sprite := _sprite(variant, height)
	sprite.name = "BatchArt"
	actor.add_child(sprite)
	var visual: Polygon2D = actor.get_node("Visual")
	visual.visible = false
	var label := Label.new()
	label.name = "ArtFeedback"
	label.position = Vector2(-24, -54)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.09))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.add_child(label)
	actors.append({"actor": actor, "sprite": sprite, "visual": visual, "label": label, "key": key, "height": height, "variant": variant, "charging": source.ends_with("/charging_beast.gd"), "last_x": actor.global_position.x, "distance": 0.0, "frame_index": -1})
	_update_actor(actors.back())

func _process(delta: float) -> void:
	if not installed:
		return
	motion_time += delta
	if stage.player.guard_block_count > previous_guard_blocks:
		guard_audio.play()
	previous_guard_blocks = stage.player.guard_block_count
	_update_player_pose(delta)
	var viewport_size := get_viewport_rect().size
	background.size = Vector2(viewport_size.y * 2.25, viewport_size.y)
	background.position.x = -clampf(stage.player.position.x / stage.WORLD_WIDTH, 0, 1) * maxf(0, background.size.x - viewport_size.x)
	for index in range(actors.size() - 1, -1, -1):
		if not is_instance_valid(actors[index].actor):
			actors.remove_at(index)
		else:
			_update_actor(actors[index])
	queue_redraw()

func _update_player_pose(delta: float = 0.0) -> void:
	if not is_instance_valid(player_art) or not is_instance_valid(stage.player):
		return
	var player: CharacterBody2D = stage.player
	var direction: float = player.facing_direction
	player_art.position = player_base_position
	player_art.scale = player_base_scale
	player_art.rotation = 0.0
	# Replace only the opaque placeholder drawing, retaining controller visibility/state.
	player.attack_visual.self_modulate.a = 0.0
	if player_art.update_motion(delta):
		var pose_names := {"death": "dead", "hurt": "hit", "run": "move"}
		player_pose = pose_names.get(player_art.motion_name, player_art.motion_name)
		if player_art.motion_name == "jump":
			player_pose = "rise" if player.velocity.y < 0 else "fall"
		return
	player_pose = "idle"
	if player.is_dead:
		player_pose = "dead"
		player_art.rotation = direction * PI * 0.42
	elif player._hurt_flash_remaining > 0.0:
		player_pose = "hit"
		var recoil := clampf(player._hurt_flash_remaining / 0.12, 0.0, 1.0)
		player_art.rotation = -direction * 0.30 * recoil
		player_art.position.x -= direction * 7.0 * recoil
	elif player.is_guarding:
		player_pose = "guard"
		player_art.flip_h = player._guard_direction < 0.0
	elif player.is_attacking:
		player_pose = "attack"
		# Real pose frames own the action silhouette; do not rotate the full sprite again.
		player_art.apply_attack_frame()
	elif not player.is_on_floor():
		player_pose = "rise" if player.velocity.y < 0 else "fall"
		player_art.rotation = direction * (-0.05 if player.velocity.y < 0 else 0.05)
	elif absf(player.velocity.x) > 1.0:
		player_pose = "move"
		player_art.position.y -= absf(sin(motion_time * 14.0)) * 1.5
		player_art.rotation = sin(motion_time * 14.0) * 0.025

func _phase(remaining: float, duration: float) -> float:
	return clampf(1.0 - remaining / maxf(duration, 0.0001), 0.0, 1.0)

func _update_actor(entry: Dictionary) -> void:
	var actor: Node2D = entry.actor
	var sprite: Sprite2D = entry.sprite
	var label: Label = entry.label
	if entry.key == "projectile":
		sprite.flip_h = actor.direction < 0.0
		return
	var direction: float = actor.velocity.x
	if entry.key == "melee" and actor.state == 2:
		direction = actor._attack_direction
	elif entry.key == "ranged" and actor.state == 1 and is_instance_valid(stage.player):
		direction = stage.player.global_position.x - actor.global_position.x
	if not is_zero_approx(direction):
		sprite.flip_h = direction < 0.0
	var color: Color = entry.visual.color
	var base := Color(0.92, 0.3, 0.28, 1) if entry.key == "melee" else Color(0.55, 0.3, 0.92, 1)
	sprite.self_modulate = Color.WHITE if color.is_equal_approx(base) else Color.WHITE.lerp(color, 0.35)
	label.text = ""
	if not color.is_equal_approx(Color.WHITE) and not color.is_equal_approx(base):
		label.text = "!"
	label.position.y = 9.0 - float(entry.height)
	label.modulate = color if not color.is_equal_approx(base) else Color.WHITE
	sprite.position = Vector2(0, 30.0 - float(entry.height) * 0.5)
	sprite.rotation = 0.0
	if _apply_enemy_frame(entry):
		return
	var facing := -1.0 if sprite.flip_h else 1.0
	if actor._hit_flash_remaining > 0.0:
		sprite.rotation = -facing * 0.28 * clampf(actor._hit_flash_remaining / 0.12, 0.0, 1.0)
	elif (entry.key == "melee" and actor.state == 2) or (entry.key == "ranged" and actor.state == 1):
		if actor.attack_phase == 0:
			var phase := _phase(actor._phase_time_remaining, actor.attack_windup)
			sprite.rotation = -facing * lerpf(0.06, 0.26, phase)
			sprite.position.x = -facing * phase * 4.0
		elif entry.key == "melee" and actor.is_attack_active:
			var phase := _phase(actor._phase_time_remaining, actor.attack_active)
			sprite.rotation = facing * lerpf(0.32, 0.12, phase)
			sprite.position.x = facing * sin(phase * PI) * 6.0
		else:
			var phase := _phase(actor._phase_time_remaining, actor.attack_cooldown)
			sprite.rotation = facing * 0.12 * (1.0 - phase)
	elif absf(actor.velocity.x) > 1.0:
		sprite.position.y -= absf(sin(motion_time * 12.0))

func _apply_enemy_frame(entry: Dictionary) -> bool:
	if not enemy_motions.has(entry.variant):
		return false
	var actor: CharacterBody2D = entry.actor
	var sprite: Sprite2D = entry.sprite
	var travel := absf(actor.global_position.x - float(entry.last_x))
	entry.last_x = actor.global_position.x
	if travel < 100.0:
		entry.distance += travel
	var frame_index := 0
	if (entry.key == "melee" and actor.state == 2) or (entry.key == "ranged" and actor.state == 1):
		if actor.attack_phase == 0:
			frame_index = 3
		elif entry.key == "melee":
			frame_index = 4 if actor.is_attack_active else 5
		else:
			frame_index = 4 if actor.attack_cooldown - actor._phase_time_remaining < 0.12 else 5
	elif absf(actor.velocity.x) > 1.0:
		frame_index = 1 + int(float(entry.distance) / 18.0) % 2
	var spec: Dictionary = enemy_motions[entry.variant]
	sprite.texture = spec.frames[frame_index]
	var pivot := Vector2(spec.pivots[frame_index][0], spec.pivots[frame_index][1])
	sprite.centered = false
	sprite.offset = Vector2(-(sprite.texture.get_width() - pivot.x) if sprite.flip_h else -pivot.x, -pivot.y)
	sprite.scale = Vector2.ONE * float(spec.scale)
	sprite.position = Vector2(0, 30)
	sprite.rotation = 0.0
	entry.frame_index = frame_index
	return true

func _draw() -> void:
	if not installed:
		return
	var ground: Texture2D = textures.ground
	# Mirror alternate full tiles to match border colors without changing the PNG.
	for index in range(ceili(stage.WORLD_WIDTH / 256.0)):
		var x := index * 256.0
		var width := minf(256.0, stage.WORLD_WIDTH - x)
		var source_width := ground.get_width() * width / 256.0
		var source := Rect2(0, 0, source_width, ground.get_height())
		if index % 2 == 1:
			source.position.x = ground.get_width() - source_width
			draw_set_transform(Vector2(x + width, 620), 0, Vector2(-1, 1))
		else:
			draw_set_transform(Vector2(x, 620))
		draw_texture_rect_region(ground, Rect2(0, 0, width, 80), source)
	draw_set_transform(Vector2.ZERO)
	var edge: Color = TERRAIN_EDGES[stage.stage_number - 1]
	draw_line(Vector2(0, 620), Vector2(stage.WORLD_WIDTH, 620), edge, 2.0)
	for terrain in get_tree().get_nodes_in_group("stage_terrain"):
		if not stage.is_ancestor_of(terrain):
			continue
		var surface: PackedVector2Array = terrain.get_meta("surface_points")
		var points := PackedVector2Array()
		for point in surface:
			points.append(point + terrain.position)
		# Decorative supports remain behind traversable surfaces, never colliders.
		if points.size() == 2 and points[0].y < 540 and points[1].x - points[0].x > 140:
			var shade := Color(0.63, 0.66, 0.65, 0.88)
			for x in [points[0].x + 36, points[1].x - 36]:
				var top_at := Vector2(x, points[0].y + 18)
				var width := 24.0 if stage.stage_number == 2 else 30.0
				var support := Rect2(top_at - Vector2(width * 0.5, 0), Vector2(width, 620 - top_at.y))
				var source := Rect2(ground.get_width() * 0.28, ground.get_height() * 0.18, ground.get_width() * 0.09, ground.get_height() * 0.82)
				draw_texture_rect_region(ground, support, source, shade)
				draw_line(top_at + Vector2(-22, 1), top_at + Vector2(22, 1), edge.darkened(0.35), 7, true)
		draw_polyline(points, edge.darkened(0.25), 4, true)
		draw_polyline(points, edge, 1.5, true)
	_draw_stage_markers()
	_draw_combat_feedback()

func _draw_stage_markers() -> void:
	for cluster in stage.route_clusters:
		var at := Vector2(cluster.left + 10, 376)
		draw_style_box(_route_sign_style(), Rect2(at - Vector2(10, 23), Vector2(256, 52)))
		draw_string(world_font, at, "↑ 상층: 선택 전투 · 회복 +1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ecd6a7"))
		draw_string(world_font, at + Vector2(0, 22), "→ 아래 길: 필수 전투로 합류", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d1dddd"))
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
		draw_string_outline(world_font, Vector2(x - 38, 516), "%d구간 봉인" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("203137"))
		draw_string(world_font, Vector2(x - 38, 516), "%d구간 봉인" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.65, 0.88, 0.86))
	for index in range(stage.CHECKPOINT_POSITIONS.size()):
		var checkpoint_text := "휴식처 %d · %s" % [index + 1, "최근 저장" if index == stage.checkpoint_index else "통과함" if index < stage.checkpoint_index else "체크포인트"]
		draw_string_outline(world_font, stage.CHECKPOINT_POSITIONS[index] + Vector2(-65, -93), checkpoint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("142126"))
		draw_string(world_font, stage.CHECKPOINT_POSITIONS[index] + Vector2(-65, -93), checkpoint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.47, 0.88, 0.9))
	var goal_ready: bool = not stage.completed.has(false)
	draw_string_outline(world_font, Vector2(stage.GOAL_X - 46, 474), "목표에 도착하세요" if goal_ready else "최종 목적지", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("142126"))
	draw_string(world_font, Vector2(stage.GOAL_X - 46, 474), "목표에 도착하세요" if goal_ready else "최종 목적지", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.89, 0.79, 0.55))
	if goal_ready:
		var y := 457.0 + sin(motion_time * 3.0) * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(stage.GOAL_X - 8, y), Vector2(stage.GOAL_X + 8, y), Vector2(stage.GOAL_X, y + 9)]), Color(0.95, 0.82, 0.52))

func _route_sign_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.12, 0.85)
	style.set_corner_radius_all(4)
	return style

func _draw_combat_feedback() -> void:
	if not is_instance_valid(stage.player):
		return
	var player: CharacterBody2D = stage.player
	var origin := to_local(player.global_position)
	var facing: float = player.facing_direction
	if player.is_attacking and not player.attack_collision.disabled and not player.is_dead:
		# A tapered silver sword ribbon, animated within the unchanged attack rectangle.
		var shape: RectangleShape2D = player.attack_collision.shape
		var points := PackedVector2Array()
		var inner := PackedVector2Array()
		var phase := _phase(player._attack_time_remaining, player.attack_duration)
		var opacity := 0.45 + sin(phase * PI) * 0.55
		for index in range(17):
			var t := float(index) / 16.0
			var angle := lerpf(-1.25 + phase * 0.6, 0.8 + phase * 0.6, t)
			var radius := Vector2(shape.size.x * 0.5 - 3.0, shape.size.y * 0.5 - 3.0)
			var unit := Vector2(cos(angle) * facing, sin(angle))
			points.append(to_local(player.attack_collision.to_global(unit * radius)))
			inner.append(to_local(player.attack_collision.to_global(unit * (radius - Vector2.ONE * sin(t * PI) * 6.0))))
		inner.reverse()
		var ribbon := points.duplicate()
		ribbon.append_array(inner)
		draw_polyline(points, Color(0.21, 0.31, 0.35, opacity * 0.8), 4.0, true)
		draw_colored_polygon(ribbon, Color(0.81, 0.9, 0.93, opacity * 0.95))
		draw_polyline(points, Color(0.96, 0.97, 0.87, opacity), 1.5, true)
	if player._guard_block_flash_remaining > 0.0 and not player.is_dead:
		var contact := origin + Vector2(player._guard_direction * 34, -28)
		var strength: float = player._guard_block_flash_remaining / 0.14
		for index in range(7):
			var unit := Vector2.from_angle(TAU * index / 7.0)
			draw_line(contact + unit * 4, contact + unit * (10 + strength * 7), Color(1.0, 0.91, 0.62, strength), 2.5, true)
		draw_circle(contact, 3.5, Color(1.0, 0.98, 0.86, strength))
	if player_pose == "hit":
		for index in range(8):
			var angle := TAU * index / 8.0
			var unit := Vector2(cos(angle), sin(angle))
			draw_line(origin + unit * 31.0, origin + unit * 37.0, Color(1.0, 0.75, 0.6), 2.0, true)
	for entry in actors:
		if not is_instance_valid(entry.actor):
			continue
		_draw_enemy_effect(entry)
		if entry.key == "projectile":
			continue
		if entry.charging and entry.actor.state == 2 and entry.actor.attack_phase == 0:
			var start := to_local(entry.actor.global_position) + Vector2(0, 29)
			var distance: float = entry.actor.charge_speed * entry.actor.attack_active
			var end := start + Vector2(entry.actor._attack_direction * distance, 0)
			# Expected travel, not a second hitbox; walls can shorten the charge.
			draw_line(start, end, Color(1.0, 0.65, 0.15, 0.65), 5.0, true)
			draw_line(end, end + Vector2(-entry.actor._attack_direction * 12, -7), Color(1.0, 0.8, 0.3), 3, true)
		var health_at := to_local(entry.actor.global_position) + Vector2(-18, 23 - float(entry.height))
		draw_rect(Rect2(health_at, Vector2(36, 3)), Color(0.1, 0.13, 0.17, 0.9))
		draw_rect(Rect2(health_at, Vector2(36.0 * maxf(0, float(entry.actor.current_hp) / entry.actor.max_hp), 3)), Color(0.9, 0.53, 0.43))

func _draw_enemy_effect(entry: Dictionary) -> void:
	# Presentation only: existing controller phases gate every effect. No timers,
	# damage, collision, camera shake or scene particles are created here.
	var actor: Node2D = entry.actor
	var at := to_local(actor.global_position)
	if entry.key == "projectile":
		var direction: float = actor.direction
		for index in range(4):
			var offset := float(index) * 7.0
			draw_line(at - Vector2(direction * (8.0 + offset), 0), at - Vector2(direction * (14.0 + offset), 0), Color(0.69, 0.43, 0.95, 0.48 - index * 0.10), 3.0 - index * 0.5, true)
		return
	var direction := -1.0 if entry.sprite.flip_h else 1.0
	if (entry.charging or actor.get_meta("ground_slam", false)) and actor.state == 2 and actor.attack_phase == 0:
		var rune := at + Vector2(0, 4 - float(entry.height))
		var diamond := PackedVector2Array([rune + Vector2(0,-10), rune + Vector2(10,0), rune + Vector2(0,10), rune + Vector2(-10,0), rune + Vector2(0,-10)])
		draw_colored_polygon(diamond.slice(0,4), Color(0.18,0.07,0.04,0.95))
		draw_polyline(diamond, Color(1.0,0.48,0.20), 2.5, true)
		draw_line(rune + Vector2(-4,-4), rune + Vector2(4,4), Color.WHITE, 2, true)
		draw_line(rune + Vector2(-4,4), rune + Vector2(4,-4), Color.WHITE, 2, true)
	if entry.key == "ranged":
		if actor.state != 1:
			return
		var windup: bool = actor.attack_phase == 0
		var phase := _phase(actor._phase_time_remaining, actor.attack_windup) if windup else clampf((actor.attack_cooldown - actor._phase_time_remaining) / 0.16, 0.0, 1.0)
		if not windup and phase >= 1.0:
			return
		var tip := at + Vector2(direction * 31.0, -1.0)
		var opacity := 0.35 + phase * 0.45 if windup else (1.0 - phase) * 0.8
		draw_circle(tip, 10.0 + phase * 6.0, Color(0.61, 0.31, 0.95, opacity * 0.18))
		draw_arc(tip, 6.0 + phase * 7.0, motion_time * 2.0, motion_time * 2.0 + TAU * 0.85, 20, Color(0.77, 0.56, 1.0, opacity), 2.0, true)
		draw_arc(tip, 5.0 + phase * 7.0, motion_time * 2.0, motion_time * 2.0 + TAU * 0.85, 20, Color(1.0, 0.92, 1.0, opacity), 1.5, true)
		for index in range(4):
			var unit := Vector2.from_angle(index * PI * 0.5 + motion_time * 2.0)
			draw_line(tip + unit * 5.0, tip + unit * (9.0 + phase * 5.0), Color(0.96, 0.85, 1.0, opacity), 1.5, true)
		return
	if entry.variant == "golem" and actor.state == 2 and actor.attack_phase == 0:
		var warning_shape: CollisionShape2D = actor.get_node("AttackArea/CollisionShape2D")
		var warning_bounds := warning_shape.shape as RectangleShape2D
		if warning_bounds != null:
			var warning_at := to_local(warning_shape.global_position)
			var warning_y := warning_at.y + warning_bounds.size.y * 0.5
			var half_width := warning_bounds.size.x * 0.5
			draw_line(Vector2(warning_at.x - half_width, warning_y), Vector2(warning_at.x + half_width, warning_y), Color(1.0, 0.76, 0.28, 0.65), 3.0, true)
			for side in [-1.0, 1.0]:
				var edge := Vector2(warning_at.x + side * half_width, warning_y)
				draw_line(edge, edge + Vector2(0, -7), Color(1.0, 0.86, 0.49, 0.85), 2.0, true)
	if actor.state != 2 or not actor.is_attack_active:
		return
	var phase := _phase(actor._phase_time_remaining, actor.attack_active)
	var opacity := 1.0 - phase * 0.35
	var attack_shape: CollisionShape2D = actor.get_node("AttackArea/CollisionShape2D")
	var bounds := attack_shape.shape as RectangleShape2D
	if bounds == null:
		return
	var center := to_local(attack_shape.global_position)
	if entry.variant == "beast":
		# A low wake follows the body; it does not imply a second damage zone.
		for index in range(5):
			var t := fmod(phase * 2.0 + float(index) / 5.0, 1.0)
			var dust := at + Vector2(-direction * (18.0 + t * 37.0), 26.0 - sin(t * PI) * 10.0)
			draw_circle(dust, 3.0 + t * 4.0, Color(0.56, 0.42, 0.25, (1.0 - t) * 0.50))
			draw_line(dust, dust + Vector2(-direction * 5.0, -2), Color(0.94, 0.82, 0.56, (1.0 - t) * 0.8), 2.0, true)
		draw_line(center + Vector2(-direction * 7.0, 12), center + Vector2(direction * 6.0, 5), Color(0.99, 0.81, 0.49, opacity), 2.0, true)
	elif entry.variant == "golem":
		var ground_at := Vector2(center.x, at.y + 29.0)
		var radius := bounds.size.x * 0.5
		var ripple := PackedVector2Array()
		for index in range(17):
			var angle := float(index) / 16.0 * PI
			ripple.append(ground_at + Vector2(cos(angle) * maxf(0.0, radius - 4.0), -sin(angle) * 12.0))
		draw_polyline(ripple, Color(0.30, 0.21, 0.12, opacity * 0.55), 8.0, true)
		draw_polyline(ripple, Color(1.0, 0.71, 0.31, opacity * 0.8), 5.0, true)
		draw_polyline(ripple, Color(1.0, 0.96, 0.75, opacity), 2.5, true)
		for index in range(5):
			var spread := float(index - 2) * radius * 0.38
			var shard := ground_at + Vector2(spread, -sin(phase * PI) * (8.0 + (index % 2) * 7.0))
			draw_circle(shard + Vector2(0, 3), 6.0, Color(0.57, 0.43, 0.28, opacity * 0.20))
			draw_line(shard, shard + Vector2(spread * 0.10, -5.0), Color(0.30, 0.28, 0.22, opacity), 5.0, true)
			draw_line(shard, shard + Vector2(spread * 0.10, -5.0), Color(0.97, 0.88, 0.65, opacity), 2.5, true)
		if phase < 0.65:
			var burst_at := ground_at + Vector2(direction * minf(35.0, radius * 0.35), -6)
			for index in range(5):
				var unit := Vector2.from_angle(-PI + index * PI / 4.0)
				draw_line(burst_at + unit * 4, burst_at + unit * (12.0 - phase * 5), Color(1.0, 0.95, 0.75, opacity), 2.5, true)
	else:
		# Tapered axe sweep stays inside the existing attack rectangle.
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var radius := bounds.size * 0.43
		for index in range(15):
			var t := float(index) / 14.0
			var angle := lerpf(-1.3, 1.1, t) + phase * 0.3
			var unit := Vector2(cos(angle) * direction, sin(angle))
			outer.append(center + unit * radius)
			inner.append(center + unit * (radius - Vector2.ONE * sin(t * PI) * minf(10.0, radius.y * 0.65)))
		inner.reverse()
		var ribbon := outer.duplicate()
		ribbon.append_array(inner)
		draw_polyline(outer, Color(0.32, 0.22, 0.12, opacity * 0.6), 6.0, true)
		draw_colored_polygon(ribbon, Color(1.0, 0.69, 0.32, opacity * 0.72))
		draw_polyline(outer, Color(1.0, 0.97, 0.80, opacity), 3.5, true)
