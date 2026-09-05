extends CharacterBody2D

@export_category("Movement")
@export var move_speed: float = 320.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.65

@export_category("Jump")
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

@export_category("Attack")
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.32
@export var attack_range: float = 72.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_visual: Polygon2D = $AttackArea/AttackVisual

var is_attacking: bool = false
var attack_count: int = 0
var facing_direction: float = 1.0
var _attack_time_remaining: float = 0.0
var _cooldown_time_remaining: float = 0.0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_area.area_entered.connect(_on_attack_area_entered)
	_update_attack_geometry()
	_set_attack_active(false)


func _physics_process(delta: float) -> void:
	_update_attack_state(delta)

	var move_direction := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(move_direction):
		facing_direction = signf(move_direction)
		$FacingMark.scale.x = facing_direction
		_update_attack_geometry()

	if Input.is_action_just_pressed("attack") and _cooldown_time_remaining <= 0.0:
		_start_attack()

	if is_on_floor():
		velocity.x = move_direction * move_speed
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y += gravity * delta
		var air_target_speed := move_direction * move_speed
		var air_acceleration := move_speed * 8.0 * air_control
		velocity.x = move_toward(velocity.x, air_target_speed, air_acceleration * delta)

	move_and_slide()


func _start_attack() -> void:
	is_attacking = true
	attack_count += 1
	_attack_time_remaining = attack_duration
	_cooldown_time_remaining = attack_cooldown
	_hit_targets.clear()
	_set_attack_active(true)


func _end_attack() -> void:
	is_attacking = false
	_set_attack_active(false)


func _update_attack_state(delta: float) -> void:
	_cooldown_time_remaining = maxf(_cooldown_time_remaining - delta, 0.0)
	if not is_attacking:
		return

	_attack_time_remaining -= delta
	if _attack_time_remaining <= 0.0:
		_end_attack()


func _set_attack_active(active: bool) -> void:
	attack_visual.visible = active
	attack_collision.set_deferred("disabled", not active)


func _update_attack_geometry() -> void:
	attack_area.position.x = facing_direction * (20.0 + attack_range * 0.5)
	var attack_shape := attack_collision.shape as RectangleShape2D
	attack_shape.size = Vector2(attack_range, 52.0)
	var half_range := attack_range * 0.5
	attack_visual.polygon = PackedVector2Array([
		Vector2(-half_range, -26.0),
		Vector2(half_range, -18.0),
		Vector2(half_range, 18.0),
		Vector2(-half_range, 26.0),
	])


func _on_attack_area_entered(area: Area2D) -> void:
	if not is_attacking:
		return

	var target := area.get_parent()
	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true

	if target.has_method("receive_hit"):
		target.receive_hit()
