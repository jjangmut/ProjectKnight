class_name CaltropTrap
extends Area2D
## Ground hazard trap dropped by CrossbowCommander in Phase 2.
## Deals 1 damage when stepped on.

var lifetime: float = 8.0
var is_active: bool = true

func _ready() -> void:
	z_index = 4
	monitoring = true
	monitorable = true
	add_to_group("enemy_projectile")

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 10)
	col.shape = shape
	col.position = Vector2(0, -5)
	add_child(col)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(-10, -8), Vector2(-6, 0),
		Vector2(0, -10), Vector2(6, 0), Vector2(10, -8), Vector2(14, 0)
	])
	visual.color = Color(0.7, 0.2, 0.25, 0.9)
	add_child(visual)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(360, 360, 290, 280)
			var spr := Sprite2D.new()
			spr.name = "CaltropSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.09
			spr.position = Vector2(0, -6)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(spr)
			visual.visible = false

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if is_active and body.is_in_group("player"):
		_trigger(body)


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if is_active and target != null and target.is_in_group("player"):
		_trigger(target)


func _trigger(target: Node) -> void:
	is_active = false
	if target.has_method("receive_hit"):
		target.receive_hit()
	queue_free()
