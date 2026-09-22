class_name ShardDrop
extends Area2D
## Collectible Soul Shard: spawns with an arc physics burst,
## then smoothly magnetizes toward the player when within proximity.

signal shard_collected(value: int)

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

@export var value: int = 1
var velocity: Vector2 = Vector2.ZERO
var drop_gravity: float = 750.0
var ground_y: float = 610.0
var is_grounded: bool = false
var bounce_count: int = 0
var magnet_range: float = 240.0
var magnet_speed: float = 280.0
var max_magnet_speed: float = 850.0

var _visual: Polygon2D
var _sparkle: Polygon2D
var _player: CharacterBody2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Terrain collision
	z_index = 8

	# Diamond crystal visual
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(0, -10),
		Vector2(7, 0),
		Vector2(0, 10),
		Vector2(-7, 0)
	])
	_visual.color = Color(0.2, 0.9, 1.0, 0.95) if value == 1 else Color(1.0, 0.85, 0.2, 0.95)
	add_child(_visual)

	# Internal shine highlight
	_sparkle = Polygon2D.new()
	_sparkle.polygon = PackedVector2Array([
		Vector2(0, -5),
		Vector2(3, 0),
		Vector2(0, 5),
		Vector2(-3, 0)
	])
	_sparkle.color = Color.WHITE
	add_child(_sparkle)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(710, 360, 290, 280)
			var spr := Sprite2D.new()
			spr.name = "ShardSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.08
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			if value > 1:
				spr.modulate = Color(1.2, 1.0, 0.4)
			add_child(spr)
			_visual.visible = false
			_sparkle.visible = false

	_find_player()


func _find_player() -> void:
	if not is_inside_tree():
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			_player = p as CharacterBody2D
			return


func init_velocity(initial_vel: Vector2) -> void:
	velocity = initial_vel


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_find_player()

	if not is_grounded:
		velocity.y += drop_gravity * delta
		position += velocity * delta

		# Check ground hit
		if position.y >= ground_y:
			position.y = ground_y
			bounce_count += 1
			if bounce_count < 3:
				velocity.y = -velocity.y * 0.4
				velocity.x *= 0.5
			else:
				velocity = Vector2.ZERO
				is_grounded = true

	# Visual gentle hover & pulse
	_visual.rotation += delta * 3.5

	# Magnet attraction logic
	if is_instance_valid(_player) and not _player.is_queued_for_deletion():
		var to_player := _player.global_position - global_position
		var dist := to_player.length()

		if dist <= magnet_range or (is_grounded and dist <= magnet_range * 1.5):
			is_grounded = true
			velocity = Vector2.ZERO
			magnet_speed = move_toward(magnet_speed, max_magnet_speed, 900.0 * delta)
			var dir := to_player.normalized()
			position += dir * magnet_speed * delta

			# Collection distance threshold
			if dist <= 32.0:
				_collect()



func _collect() -> void:
	if _player != null and is_instance_valid(_player):
		if "soul_shards" in _player:
			_player.soul_shards += value
		if _player.has_method("on_shard_collected"):
			_player.on_shard_collected(value)

	shard_collected.emit(value)

	# Lightweight collection pop feedback
	AudioManager.play("pogo_bounce", global_position)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position, "+%d SHARD" % value, Color(0.3, 1.0, 0.8), false)
	queue_free()
