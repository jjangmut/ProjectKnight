extends Sprite2D
## Visual-only adapter. The existing controller retains all gameplay ownership.

@onready var actor: CharacterBody2D = get_parent()
@onready var fallback: Polygon2D = get_parent().get_node("Visual")
var attack_frames: Array[AtlasTexture] = []
var attack_frame_index := -1
var idle_texture: Texture2D
var idle_offset: Vector2
var idle_scale: Vector2
var idle_centered := false
var motions: Dictionary = {}
var motion_name := ""
var motion_frame_index := -1
var idle_time := 0.0
var run_distance := 0.0
var death_time := 0.0
var was_dead := false
var previous_position := Vector2.ZERO
const ATTACK_PIVOTS := [Vector2(255, 599), Vector2(210, 599), Vector2(250, 569), Vector2(212, 568)]

func _ready() -> void:
	if texture == null:
		set_process(false)
		return
	material = material.duplicate()
	idle_texture = texture
	idle_offset = offset
	idle_scale = scale
	idle_centered = centered
	previous_position = actor.global_position
	var sheet: Texture2D = preload("res://assets/player_frames/attack_v1.png")
	for index in range(4):
		var cell := AtlasTexture.new()
		cell.atlas = sheet
		cell.region = Rect2((index % 2) * 627, (index / 2) * 627, 627, 627)
		attack_frames.append(cell)
	motions["attack"] = {"frames": attack_frames, "pivots": ATTACK_PIVOTS, "scale": 64.0 / 560.0}
	_load_motion_manifest()
	fallback.visible = false
	actor.get_node("FacingMark").visible = false
	_update_visual()

func _process(delta: float) -> void:
	update_motion(delta)

func _update_visual() -> void:
	update_motion(0.0)

func _load_motion_manifest() -> void:
	var path := "res://assets/player_frames/motion_manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Invalid motion manifest")
		return
	for key in parsed:
		var spec: Dictionary = parsed[key]
		var file: String = spec.get("file", "")
		if not file.begins_with("res://"):
			file = "res://assets/player_frames/" + file
		if not ResourceLoader.exists(file):
			continue
		var sheet := load(file) as Texture2D
		var columns := maxi(1, int(spec.get("columns", 1)))
		var rows := maxi(1, int(spec.get("rows", 1)))
		var raw_pivots: Array = spec.get("pivots", [])
		var regions: Array = spec.get("regions", [])
		if sheet == null or raw_pivots.is_empty():
			continue
		if (regions.is_empty() and raw_pivots.size() > columns * rows) or (not regions.is_empty() and regions.size() != raw_pivots.size()):
			continue
		var cell_size := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
		var frames: Array[AtlasTexture] = []
		var pivots: Array[Vector2] = []
		for index in range(raw_pivots.size()):
			var cell := AtlasTexture.new()
			cell.atlas = sheet
			cell.region = Rect2(Vector2(index % columns, floori(index / float(columns))) * cell_size, cell_size)
			if not regions.is_empty():
				var region: Array = regions[index]
				cell.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
			frames.append(cell)
			pivots.append(Vector2(raw_pivots[index][0], raw_pivots[index][1]))
		motions[key] = {"frames": frames, "pivots": pivots, "scale": float(spec.get("scale", 1.0))}
		if key == "attack":
			attack_frames = frames

func update_motion(delta: float) -> bool:
	if actor == null or not is_instance_valid(actor) or not "is_guarding" in actor:
		return false
	flip_h = (actor._guard_direction if actor.is_guarding else actor.facing_direction) < 0.0
	self_modulate = Color.WHITE
	material.set_shader_parameter("hurt_flash", 1.0 if actor._hurt_flash_remaining > 0 and not actor.is_dead else 0.0)
	var elapsed := 0.0 if get_tree().paused else maxf(delta, 0.0)
	if elapsed > 0.0:
		idle_time += elapsed
		var displacement := absf(actor.global_position.x - previous_position.x)
		# Ignore checkpoint/teleport jumps; only ground travel advances the gait.
		if actor.is_on_floor() and not actor.is_guarding and displacement < 100.0:
			run_distance += displacement
		previous_position = actor.global_position
	if actor.is_dead:
		if not was_dead:
			death_time = 0.0
		else:
			death_time += elapsed
		was_dead = true
		return _apply_motion("death", clampf(death_time / 0.48, 0.0, 0.99999))
	was_dead = false
	if actor._hurt_flash_remaining > 0.0:
		return _apply_motion("hurt", _phase(actor._hurt_flash_remaining, 0.12))
	if "is_dashing" in actor and actor.is_dashing:
		return _apply_motion("dodge", _phase(actor._dash_time_remaining, actor.DASH_DURATION))
	if actor.is_guarding:
		var pose := 2 if actor._guard_block_flash_remaining > 0.0 else 0 if actor._guard_elapsed < 0.08 else 1
		return _apply_motion("guard", float(pose) / 3.0)
	if actor._guard_recovery_remaining > 0.0:
		return _apply_motion("guard", 0.0)
	if actor.is_attacking:
		return _apply_motion("attack", _phase(actor._attack_time_remaining, actor.attack_duration))
	if not actor.is_on_floor():
		var frame := 1 if absf(actor.velocity.y) <= 60.0 else 0 if actor.velocity.y < 0.0 else 2
		return _apply_motion("jump", float(frame) / 3.0)
	if absf(actor.velocity.x) > 1.0:
		return _apply_motion("run", fposmod(run_distance / 96.0, 1.0))
	return _apply_motion("idle", fposmod(idle_time / 0.8, 1.0))

func _phase(remaining: float, duration: float) -> float:
	return clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 0.99999)

func _apply_motion(key: String, phase: float) -> bool:
	attack_frame_index = -1
	motion_name = key
	motion_frame_index = -1
	if not motions.has(key):
		texture = idle_texture
		offset = idle_offset
		scale = idle_scale
		centered = idle_centered
		return false
	var spec: Dictionary = motions[key]
	motion_frame_index = mini(spec.frames.size() - 1, int(phase * spec.frames.size()))
	texture = spec.frames[motion_frame_index]
	var pivot: Vector2 = spec.pivots[motion_frame_index]
	centered = false
	offset = Vector2(-(texture.get_width() - pivot.x) if flip_h else -pivot.x, -pivot.y)
	scale = Vector2.ONE * float(spec.scale)
	rotation = 0.0
	if key == "attack":
		attack_frame_index = motion_frame_index
	return true

func apply_attack_frame() -> bool:
	if actor.is_attacking and not actor.is_dead and actor._hurt_flash_remaining <= 0 and not actor.is_guarding:
		return _apply_motion("attack", _phase(actor._attack_time_remaining, actor.attack_duration))
	update_motion(0.0)
	return false
