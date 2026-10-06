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

const StageStaticArtClass := preload("res://scripts/art/stage_static_art.gd")
var static_art: Node2D = null
var _last_gate_count := -1
var _last_checkpoint := -1
var _last_in_boss := false
var _had_combat_draw := false

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

	# 1. World Environment: 2D HDR Glow & Atmospheric Bloom
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05, 1.0)
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 1.4
	env.glow_intensity = 0.85
	env.glow_bloom = 0.20
	var world_env := WorldEnvironment.new()
	world_env.name = "StageWorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# 2. Dynamic Ambiance: Thematic Stage Tint
	var modulate_colors := [
		Color(0.92, 0.95, 1.05, 1.0), # Stage 1: Castle dawn blue-gold
		Color(0.88, 1.02, 0.90, 1.0), # Stage 2: Beast forest emerald
		Color(1.05, 0.90, 0.82, 1.0), # Stage 3: Ruined twilight orange
		Color(0.85, 0.96, 1.02, 1.0), # Stage 4: Ancient sanctuary cyan
		Color(0.82, 0.78, 0.98, 1.0)  # Stage 5: Abyssal citadel violet
	]
	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "StageCanvasModulate"
	canvas_mod.color = modulate_colors[clampi(stage.stage_number - 1, 0, 4)]
	add_child(canvas_mod)

	# 3. Atmospheric Floating Motes & Embers
	var motes := CPUParticles2D.new()
	motes.name = "AtmosphericMotes"
	motes.amount = 22
	motes.lifetime = 5.5
	motes.preprocess = 0.5
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(750, 420)
	motes.gravity = Vector2(0, -8)
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 28.0
	motes.spread = 180.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.5
	var mote_colors := [
		Color(1.5, 1.3, 0.7, 0.35), # S1 gold dust
		Color(0.8, 1.5, 0.9, 0.35), # S2 emerald spores
		Color(1.6, 0.8, 0.4, 0.35), # S3 embers
		Color(0.7, 1.4, 1.5, 0.35), # S4 mystic runes
		Color(1.3, 0.7, 1.6, 0.35)  # S5 void motes
	]
	motes.color = mote_colors[clampi(stage.stage_number - 1, 0, 4)]
	motes.position = Vector2(stage.player.position.x, 480)
	motes.z_index = 8
	add_child(motes)

	var layer := CanvasLayer.new()
	layer.name = "StageBackdrop"
	layer.layer = -10
	layer.visible = false
	add_child(layer)
	background = TextureRect.new()
	background.texture = textures.background
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.visible = false
	layer.add_child(background)
	background.size = get_viewport_rect().size
	for terrain in get_tree().get_nodes_in_group("stage_terrain"):
		if not stage.is_ancestor_of(terrain):
			continue
		for visual in terrain.get_children():
			if visual is Polygon2D:
				visual.texture = textures.ground
				visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var min_x := INF
				var min_y := INF
				for vertex in visual.polygon:
					min_x = minf(min_x, vertex.x)
					min_y = minf(min_y, vertex.y)
				var uv := PackedVector2Array()
				for vertex in visual.polygon:
					uv.append(Vector2((vertex.x - min_x) * textures.ground.get_width() / 384.0, (vertex.y - min_y) * textures.ground.get_height() / 128.0))
				visual.uv = uv
				visual.color = Color(0.92, 0.95, 0.98, 1.0)
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
	_build_persistent_hero_shadows()
	for child in stage.get_children():
		_attach(child)

	static_art = StageStaticArtClass.new()
	static_art.name = "StageStaticArt"
	add_child(static_art)
	var edge: Color = TERRAIN_EDGES[stage.stage_number - 1]
	static_art.build_cache(stage, textures.ground, edge, world_font)

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
	var hp_bar: Node2D = _build_persistent_enemy_shadow_and_bar(actor, height, key)
	actors.append({"actor": actor, "sprite": sprite, "visual": visual, "label": label, "hp_bar": hp_bar, "key": key, "height": height, "variant": variant, "charging": source.ends_with("/charging_beast.gd"), "last_x": actor.global_position.x, "distance": 0.0, "frame_index": -1})
	_update_actor(actors.back())

func _process(delta: float) -> void:
	if not installed:
		return
	motion_time += delta
	var motes = get_node_or_null("AtmosphericMotes") as CPUParticles2D
	if motes != null and is_instance_valid(motes) and is_instance_valid(stage.player):
		motes.position.x = lerpf(motes.position.x, stage.player.position.x, 6.0 * delta)
		if stage.stage_number == 2:
			var in_boss_now: bool = (stage.encounter_index >= stage.required_count - 1 and stage.encounter_active) if ("encounter_index" in stage and "required_count" in stage and "encounter_active" in stage) else false
			var target_color := Color(1.8, 1.1, 0.35, 0.45) if in_boss_now else Color(0.8, 1.5, 0.9, 0.35)
			motes.color = motes.color.lerp(target_color, 3.0 * delta)
		elif stage.stage_number == 4:
			var in_boss_now: bool = (stage.encounter_index >= stage.required_count - 1 and stage.encounter_active) if ("encounter_index" in stage and "required_count" in stage and "encounter_active" in stage) else false
			var target_color := Color(0.9, 1.8, 2.0, 0.45) if in_boss_now else Color(0.7, 1.4, 1.5, 0.35)
			motes.color = motes.color.lerp(target_color, 3.0 * delta)
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

	# Invalidate static art only when stage progression flags change
	var current_gate_count := 0
	if "gates" in stage and stage.gates != null:
		for g in stage.gates:
			if is_instance_valid(g) and not g.is_queued_for_deletion():
				current_gate_count += 1
	var current_cp: int = stage.checkpoint_index if "checkpoint_index" in stage else -1
	var in_boss: bool = (stage.encounter_index >= stage.required_count - 1 and stage.encounter_active) if ("encounter_index" in stage and "required_count" in stage and "encounter_active" in stage) else false
	if current_gate_count != _last_gate_count or current_cp != _last_checkpoint or in_boss != _last_in_boss:
		_last_gate_count = current_gate_count
		_last_checkpoint = current_cp
		_last_in_boss = in_boss
		if static_art != null:
			static_art.invalidate()

	var needs_redraw := false
	if is_instance_valid(stage.player):
		if stage.player.is_attacking and not stage.player.attack_collision.disabled:
			needs_redraw = true
		elif stage.player._guard_block_flash_remaining > 0.0:
			needs_redraw = true
		elif player_pose == "hit":
			needs_redraw = true
	var goal_ready: bool = "completed" in stage and not stage.completed.has(false)
	if goal_ready:
		needs_redraw = true
	for entry in actors:
		if is_instance_valid(entry.actor) and entry.charging and entry.actor.state == 2 and entry.actor.attack_phase == 0:
			needs_redraw = true
			break

	if needs_redraw:
		_had_combat_draw = true
		queue_redraw()
	elif _had_combat_draw:
		_had_combat_draw = false
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
	if player_art.has_method("update_motion") and player_art.update_motion(delta):
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
	if entry.variant == "beast":
		sprite.self_modulate = Color(1.22, 1.15, 1.05, 1.0) if color.is_equal_approx(base) else Color(1.2, 1.1, 1.0).lerp(color, 0.35)
	else:
		sprite.self_modulate = Color.WHITE if color.is_equal_approx(base) else Color.WHITE.lerp(color, 0.35)
	label.text = ""
	if not color.is_equal_approx(Color.WHITE) and not color.is_equal_approx(base):
		label.text = "!"
	label.position.y = 9.0 - float(entry.height)
	label.modulate = color if not color.is_equal_approx(base) else Color.WHITE
	sprite.position = Vector2(0, 30.0 - float(entry.height) * 0.5)
	sprite.rotation = 0.0
	var hp_bar: Node2D = entry.get("hp_bar", null)
	if hp_bar != null and is_instance_valid(hp_bar):
		var is_dead_e: bool = bool(actor.get("is_dead")) if "is_dead" in actor else false
		if is_dead_e or not actor.visible:
			hp_bar.visible = false
		else:
			hp_bar.visible = true
			var fill: Polygon2D = hp_bar.get_node_or_null("Fill")
			if fill != null:
				var ratio: float = clampf(float(actor.current_hp) / maxf(1.0, float(actor.max_hp)), 0.0, 1.0)
				fill.scale.x = ratio
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
	var goal_ready: bool = "completed" in stage and not stage.completed.has(false)
	if goal_ready:
		var y := 457.0 + sin(motion_time * 3.0) * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(stage.GOAL_X - 8, y), Vector2(stage.GOAL_X + 8, y), Vector2(stage.GOAL_X, y + 9)]), Color(0.95, 0.82, 0.52))
	_draw_combat_feedback()

func _draw_combat_feedback() -> void:
	if not is_instance_valid(stage.player):
		return
	var player: CharacterBody2D = stage.player
	var origin := to_local(player.global_position)
	var facing: float = player.facing_direction

	# 0. Contact Shadows & Hero Ambiance: Grounding ambient shadows for player and enemies
	if not player.is_dead:
		var floor_contact := origin + Vector2(0, 2.0)
		draw_set_transform(floor_contact, 0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, 22.0, Color(0.02, 0.03, 0.06, 0.50))
		draw_set_transform(Vector2.ZERO)

		# Soft hero ambient light
		var hero_center := origin + Vector2(0, -26)
		draw_circle(hero_center, 28.0, Color(0.9, 0.96, 1.2, 0.06))
		draw_circle(hero_center, 18.0, Color(1.1, 1.3, 1.8, 0.08))

	# Dynamic grounding shadows under active enemies
	if "enemies" in stage and stage.enemies != null:
		for e in stage.enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				var is_dead_enemy: bool = e.get("is_dead") if "is_dead" in e else false
				if not is_dead_enemy:
					var e_pos: Vector2 = to_local(e.global_position)
					var rad: float = 65.0 if e.is_in_group("boss") else 18.0
					draw_set_transform(e_pos + Vector2(0, 2.0), 0, Vector2(1.0, 0.30))
					draw_circle(Vector2.ZERO, rad, Color(0.02, 0.03, 0.06, 0.45))
					draw_set_transform(Vector2.ZERO)

	if player.is_attacking and not player.attack_collision.disabled and not player.is_dead:
		var shape: RectangleShape2D = player.attack_collision.shape
		var phase := _phase(player._attack_time_remaining, player.attack_duration)
		var opacity := 0.45 + sin(phase * PI) * 0.55
		var points := PackedVector2Array()
		var inner := PackedVector2Array()

		if player.is_down_thrusting:
			# Down Thrust: Piercing vertical incandescent spike
			var spike_top := origin + Vector2(0, 10)
			var spike_tip := origin + Vector2(0, 48)
			var w := 18.0 * (1.0 - phase * 0.4)
			var spike_poly := PackedVector2Array([
				spike_top + Vector2(-w, 0),
				spike_top + Vector2(w, 0),
				spike_tip + Vector2(w * 0.3, 0),
				spike_tip + Vector2(0, 8),
				spike_tip + Vector2(-w * 0.3, 0)
			])
			draw_colored_polygon(spike_poly, Color(1.5, 1.2, 0.4, opacity * 0.9))
			draw_polyline(spike_poly, Color(2.8, 2.4, 0.9, opacity), 2.5, true)
			for side in [-1.0, 0.0, 1.0]:
				draw_line(spike_top + Vector2(side * 8, 4), spike_tip + Vector2(side * 4, 12), Color(3.0, 2.8, 1.2, opacity), 1.5, true)

		elif player.is_air_attacking:
			# Aerial Spin: 360-degree whirlwind ring blade
			var spin_radius := Vector2(shape.size.x * 0.48, shape.size.y * 0.48)
			var start_ang := -PI * 0.9 + phase * TAU
			var end_ang := start_ang + PI * 1.45
			for index in range(21):
				var t := float(index) / 20.0
				var angle := lerpf(start_ang, end_ang, t)
				var unit := Vector2(cos(angle) * facing, sin(angle))
				var thick := sin(t * PI) * 12.0
				points.append(to_local(player.attack_collision.to_global(unit * spin_radius)))
				inner.append(to_local(player.attack_collision.to_global(unit * (spin_radius - Vector2.ONE * thick))))
			inner.reverse()
			var ribbon := points.duplicate()
			ribbon.append_array(inner)
			draw_colored_polygon(ribbon, Color(0.5, 1.2, 1.6, opacity * 0.88))
			draw_polyline(points, Color(1.6, 2.6, 3.4, opacity), 3.5, true)
			draw_polyline(points, Color(2.8, 2.8, 3.2, opacity), 1.5, true)

		elif player.is_counter_attacking:
			# Counter Slash: Blinding cyan arc with cross-flash
			var radius := Vector2(shape.size.x * 0.5 - 2.0, shape.size.y * 0.5 - 2.0)
			for index in range(19):
				var t := float(index) / 18.0
				var angle := lerpf(-1.35 + phase * 0.5, 1.1 + phase * 0.5, t)
				var unit := Vector2(cos(angle) * facing, sin(angle))
				var thick := sin(t * PI) * 14.0
				points.append(to_local(player.attack_collision.to_global(unit * radius)))
				inner.append(to_local(player.attack_collision.to_global(unit * (radius - Vector2.ONE * thick))))
			inner.reverse()
			var ribbon := points.duplicate()
			ribbon.append_array(inner)
			draw_colored_polygon(ribbon, Color(0.3, 1.4, 2.2, opacity * 0.95))
			draw_polyline(points, Color(1.5, 3.0, 3.8, opacity), 4.5, true)
			draw_polyline(points, Color(3.0, 3.2, 3.8, opacity), 2.0, true)

		elif player.combo_step == 3:
			# Combo 3 Heavy Finish: Wide 170-degree blazing golden crescent wave
			var radius := Vector2(shape.size.x * 0.52 - 2.0, shape.size.y * 0.52 - 2.0)
			for index in range(21):
				var t := float(index) / 20.0
				var angle := lerpf(-1.5 + phase * 0.55, 1.2 + phase * 0.55, t)
				var unit := Vector2(cos(angle) * facing, sin(angle))
				var thick := sin(t * PI) * 15.0
				points.append(to_local(player.attack_collision.to_global(unit * radius)))
				inner.append(to_local(player.attack_collision.to_global(unit * (radius - Vector2.ONE * thick))))
			inner.reverse()
			var ribbon := points.duplicate()
			ribbon.append_array(inner)
			draw_colored_polygon(ribbon, Color(1.8, 1.1, 0.35, opacity * 0.92))
			draw_polyline(points, Color(3.5, 2.6, 0.9, opacity), 5.0, true)
			draw_polyline(points, Color(3.5, 3.2, 2.5, opacity), 2.0, true)
			var swing_center := to_local(player.attack_collision.global_position)
			for s in range(3):
				var s_ang := lerpf(-0.5, 0.5, float(s) / 2.0)
				var s_dir := Vector2(cos(s_ang) * facing, sin(s_ang))
				draw_line(swing_center + s_dir * (radius.x * 0.4), swing_center + s_dir * (radius.x * 0.95), Color(3.5, 2.8, 1.2, opacity * 0.8), 2.0, true)

		elif player.combo_step == 2:
			# Combo 2: Rising jade slash sweep
			var radius := Vector2(shape.size.x * 0.5 - 3.0, shape.size.y * 0.5 - 3.0)
			for index in range(17):
				var t := float(index) / 16.0
				var angle := lerpf(1.1 - phase * 0.55, -0.9 - phase * 0.55, t)
				var unit := Vector2(cos(angle) * facing, sin(angle))
				var thick := sin(t * PI) * 10.0
				points.append(to_local(player.attack_collision.to_global(unit * radius)))
				inner.append(to_local(player.attack_collision.to_global(unit * (radius - Vector2.ONE * thick))))
			inner.reverse()
			var ribbon := points.duplicate()
			ribbon.append_array(inner)
			draw_colored_polygon(ribbon, Color(0.7, 1.35, 1.15, opacity * 0.92))
			draw_polyline(points, Color(1.6, 2.8, 2.5, opacity), 3.8, true)
			draw_polyline(points, Color(2.6, 3.2, 3.0, opacity), 1.8, true)

		else:
			# Combo 1: Sharp crisp azure downward diagonal slash
			var radius := Vector2(shape.size.x * 0.5 - 3.0, shape.size.y * 0.5 - 3.0)
			for index in range(17):
				var t := float(index) / 16.0
				var angle := lerpf(-1.35 + phase * 0.5, 0.65 + phase * 0.5, t)
				var unit := Vector2(cos(angle) * facing, sin(angle))
				var thick := sin(t * PI) * 8.5
				points.append(to_local(player.attack_collision.to_global(unit * radius)))
				inner.append(to_local(player.attack_collision.to_global(unit * (radius - Vector2.ONE * thick))))
			inner.reverse()
			var ribbon := points.duplicate()
			ribbon.append_array(inner)
			draw_colored_polygon(ribbon, Color(0.85, 1.15, 1.45, opacity * 0.92))
			draw_polyline(points, Color(1.8, 2.5, 3.2, opacity), 3.5, true)
			draw_polyline(points, Color(2.8, 2.8, 3.2, opacity), 1.6, true)
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
		if not is_instance_valid(entry.actor) or not entry.actor.visible:
			continue
		_draw_enemy_effect(entry)
		if entry.key == "projectile":
			continue
		if entry.charging and entry.actor.state == 2 and entry.actor.attack_phase == 0:
			var start := to_local(entry.actor.global_position) + Vector2(0, 29)
			var distance: float = entry.actor.charge_speed * entry.actor.attack_active
			var end := start + Vector2(entry.actor._attack_direction * distance, 0)
			var dir: float = entry.actor._attack_direction
			var min_x := minf(start.x, end.x)
			var max_x := maxf(start.x, end.x)
			var runway_h := 26.0
			var runway_rect := Rect2(min_x, start.y - runway_h * 0.5, max_x - min_x, runway_h)
			# 1. Semi-transparent warm amber hazard runway
			draw_rect(runway_rect, Color(1.0, 0.42, 0.08, 0.22))
			# 2. Outer hazard border rails
			draw_line(Vector2(min_x, runway_rect.position.y), Vector2(max_x, runway_rect.position.y), Color(1.8, 0.75, 0.2, 0.65), 2.0, true)
			draw_line(Vector2(min_x, runway_rect.end.y), Vector2(max_x, runway_rect.end.y), Color(1.8, 0.75, 0.2, 0.65), 2.0, true)
			# 3. Directional glowing chevrons >> >> >>
			var chevron_count := int((max_x - min_x) / 36.0)
			for c_idx in range(chevron_count):
				var cx := (min_x + 18.0 + float(c_idx) * 36.0) if dir > 0.0 else (max_x - 18.0 - float(c_idx) * 36.0)
				var chev := PackedVector2Array([
					Vector2(cx - dir * 10.0, start.y - 8.0),
					Vector2(cx, start.y),
					Vector2(cx - dir * 10.0, start.y + 8.0)
				])
				draw_polyline(chev, Color(2.4, 1.2, 0.25, 0.85), 3.0, true)
				draw_polyline(chev, Color(3.2, 2.2, 0.8, 0.95), 1.2, true)
			# 4. Target impact bracket
			var bracket := PackedVector2Array([
				end + Vector2(dir * 2, -13),
				end + Vector2(dir * 8, -13),
				end + Vector2(dir * 8, 13),
				end + Vector2(dir * 2, 13)
			])
			draw_polyline(bracket, Color(2.8, 1.3, 0.25, 0.95), 3.0, true)
			# 5. Glowing predator eye spark at head
			var eye_pos := to_local(entry.actor.global_position) + Vector2(dir * 20, -10)
			draw_circle(eye_pos, 4.5, Color(2.8, 1.2, 0.2, 0.95))
			draw_line(eye_pos - Vector2(8, 0), eye_pos + Vector2(8, 0), Color(3.5, 2.4, 1.0, 0.9), 1.5, true)
			draw_line(eye_pos - Vector2(0, 6), eye_pos + Vector2(0, 6), Color(3.5, 2.4, 1.0, 0.9), 1.5, true)


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
		# Luminous projectile head for high combat contrast across dark/dusty backgrounds
		draw_circle(at, 4.0, Color(2.6, 1.3, 0.4, 0.95))
		draw_circle(at, 2.0, Color(3.5, 2.5, 1.2, 0.98))
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

		# Stage 3 Enhanced Warm Amber Telegraph & Trajectory Aiming Line (High Contrast)
		if windup:
			var target_pt := tip + Vector2(direction * 320.0, 0)
			if is_instance_valid(stage.player):
				var p_local := to_local(stage.player.global_position) + Vector2(0, -16)
				var dir_vec := (p_local - tip).normalized()
				var aim_dist := minf(360.0, tip.distance_to(p_local))
				target_pt = tip + dir_vec * aim_dist
			# 1. Outer warm amber guide line
			draw_line(tip, target_pt, Color(1.8, 0.72, 0.20, opacity * 0.55), 2.5, true)
			# 2. Inner high-intensity laser core
			draw_line(tip, target_pt, Color(3.2, 1.8, 0.6, opacity * 0.85), 1.0, true)
			# 3. Reticle diamond at aim target
			var reticle := PackedVector2Array([
				target_pt + Vector2(0, -6), target_pt + Vector2(6, 0),
				target_pt + Vector2(0, 6), target_pt + Vector2(-6, 0), target_pt + Vector2(0, -6)
			])
			draw_polyline(reticle, Color(2.6, 1.2, 0.3, opacity * 0.95), 1.5, true)
			# 4. Muzzle spark flash at weapon tip
			draw_circle(tip, 4.5 * phase, Color(2.8, 1.4, 0.4, opacity * 0.95))
			draw_line(tip - Vector2(6, 0), tip + Vector2(6, 0), Color(3.5, 2.4, 1.0, opacity), 1.2, true)
			draw_line(tip - Vector2(0, 6), tip + Vector2(0, 6), Color(3.5, 2.4, 1.0, opacity), 1.2, true)
		return
	if entry.variant == "golem" and actor.state == 2 and actor.attack_phase == 0:
		var warning_shape: CollisionShape2D = actor.get_node("AttackArea/CollisionShape2D")
		var warning_bounds := warning_shape.shape as RectangleShape2D
		if warning_bounds != null:
			var warning_at := to_local(warning_shape.global_position)
			var warning_y := warning_at.y + warning_bounds.size.y * 0.5
			var half_width := warning_bounds.size.x * 0.5
			var windup_phase := _phase(actor._phase_time_remaining, actor.attack_windup) if "attack_windup" in actor and actor.attack_windup > 0.0 else 0.5
			# 1. Broad underglow amber field
			draw_line(Vector2(warning_at.x - half_width, warning_y), Vector2(warning_at.x + half_width, warning_y), Color(2.2, 0.9, 0.2, 0.40 * (0.6 + 0.4 * windup_phase)), 9.0, true)
			# 2. High-contrast amber/orange ground crack rim
			draw_line(Vector2(warning_at.x - half_width, warning_y), Vector2(warning_at.x + half_width, warning_y), Color(2.6, 1.2, 0.35, 0.90), 3.5, true)
			# 3. Bright core line
			draw_line(Vector2(warning_at.x - half_width + 8.0, warning_y), Vector2(warning_at.x + half_width - 8.0, warning_y), Color(3.2, 1.8, 0.5, 0.95), 1.5, true)
			# 4. Corner bracket teeth & rising rune sparks
			for side in [-1.0, 1.0]:
				var edge := Vector2(warning_at.x + side * half_width, warning_y)
				draw_line(edge, edge + Vector2(0, -12), Color(2.8, 1.4, 0.4, 0.95), 2.5, true)
				draw_line(edge, edge + Vector2(-side * 10, 0), Color(2.8, 1.4, 0.4, 0.95), 2.5, true)
			# 5. Pulsing rune ticks along the warning zone
			for seg in range(1, 6):
				var sx := warning_at.x - half_width + float(seg) * (warning_bounds.size.x / 6.0)
				var tick_h := 5.0 + sin(windup_phase * TAU + seg) * 2.0
				draw_line(Vector2(sx, warning_y), Vector2(sx, warning_y - tick_h), Color(2.6, 1.3, 0.35, 0.85), 1.8, true)
				draw_circle(Vector2(sx, warning_y - tick_h - 2.0), 1.5, Color(3.5, 2.2, 0.8, 0.90))
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
		var inner_ripple := PackedVector2Array()
		for index in range(17):
			var angle := float(index) / 16.0 * PI
			var r := maxf(0.0, radius - 4.0)
			ripple.append(ground_at + Vector2(cos(angle) * r, -sin(angle) * 14.0))
			inner_ripple.append(ground_at + Vector2(cos(angle) * (r * 0.65), -sin(angle) * 9.0))
		# Broad shockwave base glow
		draw_polyline(ripple, Color(0.40, 0.18, 0.08, opacity * 0.60), 10.0, true)
		# Outer shockwave ring (amber/orange)
		draw_polyline(ripple, Color(2.6, 1.1, 0.25, opacity * 0.88), 5.0, true)
		# Inner bright shockwave core
		draw_polyline(inner_ripple, Color(3.2, 1.6, 0.45, opacity * 0.95), 3.0, true)
		draw_polyline(inner_ripple, Color(3.5, 2.4, 1.0, opacity), 1.5, true)
		# Stone debris shards
		for index in range(7):
			var spread := float(index - 3) * radius * 0.28
			var shard := ground_at + Vector2(spread, -sin(phase * PI) * (10.0 + (index % 3) * 6.0))
			draw_circle(shard + Vector2(0, 3), 7.0, Color(0.35, 0.22, 0.14, opacity * 0.35))
			draw_line(shard, shard + Vector2(spread * 0.12, -7.0), Color(0.24, 0.22, 0.20, opacity), 6.0, true)
			draw_line(shard, shard + Vector2(spread * 0.12, -7.0), Color(2.4, 1.2, 0.35, opacity * 0.9), 2.5, true)
			draw_circle(shard + Vector2(spread * 0.12, -7.0), 2.0, Color(3.2, 2.0, 0.8, opacity))
		if phase < 0.65:
			var burst_at := ground_at + Vector2(direction * minf(35.0, radius * 0.35), -6)
			for index in range(7):
				var unit := Vector2.from_angle(-PI + index * PI / 6.0)
				draw_line(burst_at + unit * 5, burst_at + unit * (16.0 - phase * 7), Color(3.0, 1.8, 0.5, opacity), 3.0, true)
				draw_line(burst_at + unit * 5, burst_at + unit * (14.0 - phase * 6), Color(3.5, 2.5, 1.0, opacity), 1.5, true)
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

func _build_persistent_hero_shadows() -> void:
	if not is_instance_valid(stage.player):
		return
	if stage.player.get_node_or_null("HeroShadow") == null:
		var shadow := Polygon2D.new()
		shadow.name = "HeroShadow"
		var pts := PackedVector2Array()
		for i in range(16):
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * 22.0, sin(a) * 7.0))
		shadow.polygon = pts
		shadow.color = Color(0.02, 0.03, 0.06, 0.50)
		shadow.position = Vector2(0, 2.0)
		shadow.z_index = -1
		stage.player.add_child(shadow)

		var aura := Polygon2D.new()
		aura.name = "HeroAura"
		var a_pts := PackedVector2Array()
		for i in range(16):
			var a := TAU * float(i) / 16.0
			a_pts.append(Vector2(cos(a) * 24.0, sin(a) * 24.0))
		aura.polygon = a_pts
		aura.color = Color(0.9, 0.96, 1.2, 0.06)
		aura.position = Vector2(0, -26.0)
		aura.z_index = -1
		stage.player.add_child(aura)

func _build_persistent_enemy_shadow_and_bar(actor: Node, height: float, key: String) -> Node2D:
	if actor.get_node_or_null("EnemyShadow") == null:
		var rad: float = 65.0 if actor.is_in_group("boss") else 18.0
		var shadow := Polygon2D.new()
		shadow.name = "EnemyShadow"
		var pts := PackedVector2Array()
		for i in range(16):
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * rad, sin(a) * (rad * 0.30)))
		shadow.polygon = pts
		shadow.color = Color(0.02, 0.03, 0.06, 0.45)
		shadow.position = Vector2(0, 2.0)
		shadow.z_index = -1
		actor.add_child(shadow)

	if key == "projectile":
		return null

	if actor.get_node_or_null("EnemyHealthBar") == null:
		var bar := Node2D.new()
		bar.name = "EnemyHealthBar"
		bar.position = Vector2(0, 20.0 - height)
		var bg := Polygon2D.new()
		bg.name = "BG"
		bg.polygon = PackedVector2Array([Vector2(-22, -1), Vector2(22, -1), Vector2(22, 6), Vector2(-22, 6)])
		bg.color = Color(0.04, 0.07, 0.10, 0.92)
		bar.add_child(bg)
		var inner_bg := Polygon2D.new()
		inner_bg.name = "InnerBG"
		inner_bg.polygon = PackedVector2Array([Vector2(-21, 0), Vector2(21, 0), Vector2(21, 5), Vector2(-21, 5)])
		inner_bg.color = Color(0.16, 0.20, 0.24, 0.90)
		bar.add_child(inner_bg)
		var fill := Polygon2D.new()
		fill.name = "Fill"
		fill.polygon = PackedVector2Array([Vector2(-21, 0), Vector2(21, 0), Vector2(21, 5), Vector2(-21, 5)])
		fill.color = Color(0.92, 0.30, 0.25)
		bar.add_child(fill)
		actor.add_child(bar)
		return bar
	return actor.get_node_or_null("EnemyHealthBar")
