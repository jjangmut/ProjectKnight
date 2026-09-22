class_name FallingBoulder
extends Area2D
## Massive boulder dropped from the sanctuary ceiling by AncientGolemGuardian.

var speed: float = 560.0
var lifetime: float = 2.5
var is_falling: bool = false
var fall_delay: float = 0.45

var warning_marker: Polygon2D
var rock_visual: Polygon2D

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")


func _ready() -> void:
	z_index = 7
	monitoring = true
	monitorable = true
	add_to_group("enemy_projectile")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	add_child(col)

	# Warning Marker (Pulsing Red Cross on target)
	warning_marker = Polygon2D.new()
	warning_marker.polygon = PackedVector2Array([
		Vector2(-16, -3), Vector2(16, -3), Vector2(16, 3), Vector2(-16, 3)
	])
	warning_marker.color = Color(1.0, 0.2, 0.2, 0.7)
	add_child(warning_marker)

	# Heavy Boulder Polygon
	rock_visual = Polygon2D.new()
	rock_visual.polygon = PackedVector2Array([
		Vector2(-18, -14), Vector2(0, -22), Vector2(18, -12),
		Vector2(22, 6), Vector2(10, 20), Vector2(-12, 18), Vector2(-22, 2)
	])
	rock_visual.color = Color(0.48, 0.42, 0.38, 1.0)
	rock_visual.position = Vector2(0, -320.0) # Start high up
	add_child(rock_visual)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(360, 20, 300, 280)
			var spr := Sprite2D.new()
			spr.name = "BoulderSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.18
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			rock_visual.add_child(spr)
			rock_visual.color = Color(0, 0, 0, 0)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if fall_delay > 0.0:
		fall_delay -= delta
		if fall_delay <= 0.0:
			is_falling = true
			warning_marker.visible = false
			AudioManager.play("smash_3", global_position)
		return

	if is_falling:
		rock_visual.position.y += speed * delta
		if rock_visual.position.y >= 0.0:
			# Boulder hit ground
			rock_visual.position.y = 0.0
			is_falling = false
			GameFeelManager.shake(0.35)
			AudioManager.play("counter_hit", global_position)
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.25)
			tween.tween_callback(queue_free)

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if is_falling and body.is_in_group("player"):
		_hit(body)


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if is_falling and target != null and target.is_in_group("player"):
		_hit(target)


func _hit(target: Node) -> void:
	if target.has_method("receive_hit"):
		target.receive_hit()
	queue_free()
