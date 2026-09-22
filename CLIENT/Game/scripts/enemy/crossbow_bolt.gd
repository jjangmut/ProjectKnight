class_name CrossbowBolt
extends Area2D
## High-velocity piercing bolt fired by CrossbowCommander.
## Can be guarded with a shield or avoided via Dash.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 620.0
var damage: int = 1
var is_blockable: bool = true
var lifetime: float = 3.5
var visual_poly: Polygon2D

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")


func _ready() -> void:
	z_index = 8
	monitoring = true
	monitorable = true
	add_to_group("enemy_projectile")

	# Collision Shape (Length 24, Width 6)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 6)
	col.shape = shape
	add_child(col)

	# Visual Shape (Sleek Iron Tipped Arrow)
	visual_poly = Polygon2D.new()
	visual_poly.polygon = PackedVector2Array([
		Vector2(-12, -3), Vector2(6, -3), Vector2(14, 0),
		Vector2(6, 3), Vector2(-12, 3), Vector2(-8, 0)
	])
	visual_poly.color = Color(1.0, 0.85, 0.3, 1.0) if is_blockable else Color(1.0, 0.2, 0.2, 1.0)
	add_child(visual_poly)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(20, 20, 300, 280)
			var spr := Sprite2D.new()
			spr.name = "BoltSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.12
			spr.rotation_degrees = 45.0
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(spr)
			visual_poly.visible = false

	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		_hit_player(target)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hit_player(body)
	elif not body.is_in_group("enemies") and not body.is_in_group("boss"):
		# Impact with solid world / floor
		queue_free()


func _hit_player(p: Node) -> void:
	if p.has_method("receive_attack"):
		p.receive_attack(global_position, is_blockable)
	elif p.has_method("receive_hit"):
		p.receive_hit()
	queue_free()
