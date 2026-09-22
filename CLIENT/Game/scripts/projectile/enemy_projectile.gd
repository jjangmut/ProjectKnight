extends Area2D

@export var speed: float = 400.0
@export var max_travel_distance: float = 640.0

var direction: float = 1.0
var traveled_distance: float = 0.0
var _consumed: bool = false



func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	var sheet_path := "res://assets/projectiles/projectiles_sheet.png"
	if ResourceLoader.exists(sheet_path):
		var sheet_tex := load(sheet_path) as Texture2D
		if sheet_tex != null and has_node("Visual"):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(360, 690, 310, 280)
			var spr := Sprite2D.new()
			spr.name = "OrbSprite"
			spr.texture = atlas
			spr.scale = Vector2.ONE * 0.12
			spr.rotation_degrees = -90.0
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			$Visual.add_child(spr)
			$Visual.color = Color(0, 0, 0, 0)


var velocity_vector: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	var frame_distance := speed * delta
	if velocity_vector != Vector2.ZERO:
		position += velocity_vector * delta
	else:
		position.x += direction * frame_distance
	traveled_distance += frame_distance
	if traveled_distance >= max_travel_distance:
		queue_free()


func configure(new_direction: float) -> void:
	direction = signf(new_direction) if not is_zero_approx(new_direction) else 1.0
	velocity_vector = Vector2(direction * speed, 0.0)
	$Visual.scale.x = direction
	rotation = 0.0


func configure_target(target_pos: Vector2) -> void:
	var diff := target_pos - global_position
	if diff.length_squared() > 1.0:
		var norm := diff.normalized()
		velocity_vector = norm * speed
		direction = signf(diff.x) if not is_zero_approx(diff.x) else 1.0
		$Visual.scale.x = 1.0
		rotation = norm.angle()
	else:
		configure(1.0)


func _on_area_entered(area: Area2D) -> void:
	if _consumed:
		return
	var target := area.get_parent()
	if target.has_method("receive_hit"):
		_consumed = true
		if target.has_method("receive_attack"):
			# Incoming direction remains reliable even if a fast step crosses the center.
			target.receive_attack(target.global_position - Vector2(direction * 100.0, 0), true)
		else:
			target.receive_hit()
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	queue_free()
