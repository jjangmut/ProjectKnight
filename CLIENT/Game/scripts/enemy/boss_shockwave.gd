class_name BossShockwave
extends Area2D
## Ground Shockwave emitted by Boss Commander's leap slam.
## Travels horizontally along the ground and must be jumped over (unblockable).

@export var speed: float = 340.0
@export var direction: float = 1.0
@export var max_travel_distance: float = 340.0
@export var damage: int = 1

var _start_x: float = 0.0
var _hit_player: bool = false
var _visual: Polygon2D

func _ready() -> void:
	_start_x = position.x
	collision_layer = 0
	collision_mask = 4 # Player HurtArea
	add_to_group("enemy_projectile")

	# Collision shape (low ground wave)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 36)
	col.shape = shape
	col.position = Vector2(0, -18)
	add_child(col)

	# Spiky jagged wave visual
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-14, 0),
		Vector2(-8, -26),
		Vector2(0, -36),
		Vector2(8, -22),
		Vector2(14, 0)
	])
	_visual.color = Color(1.0, 0.28, 0.15, 0.95)
	add_child(_visual)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(700, 10, 300, 290)
			var spr := Sprite2D.new()
			spr.name = "WaveSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.15
			spr.position = Vector2(0, -22)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(spr)
			_visual.visible = false

	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	# Subtle flickering scale
	_visual.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.15

	if absf(position.x - _start_x) >= max_travel_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _hit_player:
		return
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		_hit_player = true
		if target.has_method("receive_attack"):
			# Shockwave is unblockable
			target.receive_attack(global_position, false)
		elif target.has_method("receive_hit"):
			target.receive_hit()
		queue_free()
