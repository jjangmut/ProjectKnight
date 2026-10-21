extends Area2D
class_name QVSwordBeam
## 쿼터뷰 360도 크레센트 검기 투사체 (Quarter-View 360-Degree Sword Beam)
## 8방향/360도 자유 조준 각도로 날아가며 적을 관통하거나 충돌 시 폭발

@export var speed: float = 640.0
@export var damage: int = 2
@export var max_range: float = 700.0
@export var pierce_count: int = 2

var direction: Vector2 = Vector2.RIGHT
var traveled_distance: float = 0.0
var hits_remaining: int = 2
var is_crystal_beam: bool = false

var visual_line: Line2D
var glow_line: Line2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Enemy Layer
	monitoring = true
	monitorable = false

	hits_remaining = pierce_count
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	_build_visuals()


func initialize(start_pos: Vector2, dir: Vector2, crystal: bool = false, extra_damage: int = 0) -> void:
	global_position = start_pos
	direction = dir.normalized()
	rotation = direction.angle()
	is_crystal_beam = crystal
	damage = 2 + extra_damage


func _build_visuals() -> void:
	# Outer glow crescent arc
	glow_line = Line2D.new()
	glow_line.width = 10.0
	glow_line.default_color = Color(0.4, 0.9, 1.8, 0.8) if is_crystal_beam else Color(1.8, 1.4, 0.5, 0.85) # Overdrive HDR Glow
	glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Inner core bright beam
	visual_line = Line2D.new()
	visual_line.width = 4.0
	visual_line.default_color = Color(1.0, 1.0, 1.0, 1.0)
	visual_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	visual_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Draw crescent shape in local space
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-12.0, -22.0),
		Vector2(14.0, -11.0),
		Vector2(20.0, 0.0),
		Vector2(14.0, 11.0),
		Vector2(-12.0, 22.0)
	])
	glow_line.points = points
	visual_line.points = points

	add_child(glow_line)
	add_child(visual_line)

	# Collision Shape (Capsule matching crescent width)
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 48.0
	col.shape = cap
	col.rotation = PI * 0.5
	add_child(col)


func _physics_process(delta: float) -> void:
	var move_vec := direction * speed * delta
	global_position += move_vec
	traveled_distance += move_vec.length()

	if traveled_distance >= max_range:
		_fade_and_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.owner
		if is_instance_valid(enemy) and enemy.has_method("receive_hit"):
			enemy.receive_hit(damage, direction)
			_register_hit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") or body.has_method("receive_hit"):
		body.receive_hit(damage, direction)
		_register_hit()
	elif body is TileMap or body is StaticBody2D:
		_fade_and_free()


func _register_hit() -> void:
	hits_remaining -= 1
	if hits_remaining <= 0:
		_fade_and_free()


func _fade_and_free() -> void:
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "modulate:a", 0.0, 0.08)
		tween.tween_callback(queue_free)
	else:
		queue_free()
