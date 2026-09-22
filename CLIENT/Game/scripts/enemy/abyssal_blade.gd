class_name AbyssalBlade
extends Area2D
## Spinning void blade projectile cast by AbyssalArbiter.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 480.0
var lifetime: float = 4.0
var is_blockable: bool = true
var visual_poly: Polygon2D


func _ready() -> void:
	z_index = 8
	monitoring = true
	monitorable = true
	add_to_group("enemy_projectile")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	add_child(col)

	visual_poly = Polygon2D.new()
	visual_poly.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(-4, -14), Vector2(14, 0), Vector2(-4, 14)
	])
	visual_poly.color = Color(0.65, 0.2, 0.95, 0.9)
	add_child(visual_poly)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(30, 360, 290, 280)
			var spr := Sprite2D.new()
			spr.name = "BladeSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.14
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			visual_poly.add_child(spr)
			visual_poly.color = Color(0, 0, 0, 0)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	visual_poly.rotation += 15.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hit(body)
	elif not body.is_in_group("enemies") and not body.is_in_group("boss"):
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		_hit(target)


func _hit(target: Node) -> void:
	if target.has_method("receive_attack"):
		target.receive_attack(global_position, is_blockable)
	elif target.has_method("receive_hit"):
		target.receive_hit()
	queue_free()
