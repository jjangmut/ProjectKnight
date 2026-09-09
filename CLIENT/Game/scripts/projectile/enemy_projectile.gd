extends Area2D

@export var speed: float = 400.0
@export var max_travel_distance: float = 640.0

var direction: float = 1.0
var traveled_distance: float = 0.0
var _consumed: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var frame_distance := speed * delta
	position.x += direction * frame_distance
	traveled_distance += frame_distance
	if traveled_distance >= max_travel_distance:
		queue_free()


func configure(new_direction: float) -> void:
	direction = signf(new_direction) if not is_zero_approx(new_direction) else 1.0
	$Visual.scale.x = direction


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
