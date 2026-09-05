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

@export_category("Dodge")
@export var dodge_speed: float = 720.0
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.45

@export_category("Health")
@export var max_hp: int = 3

@onready var body_visual: Polygon2D = $Visual
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_visual: Polygon2D = $AttackArea/AttackVisual

var is_attacking: bool = false
var attack_count: int = 0
var facing_direction: float = 1.0
var _attack_time_remaining: float = 0.0
var _cooldown_time_remaining: float = 0.0
var _hit_targets: Dictionary = {}
var is_dodging: bool = false
var dodge_count: int = 0
var _dodge_direction: float = 1.0
var _dodge_time_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _base_visual_color: Color
var current_hp: int
var hit_count: int = 0
var _hurt_flash_remaining: float = 0.0


func _ready() -> void:
	_base_visual_color = body_visual.color
	current_hp = max_hp
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_area.area_entered.connect(_on_attack_area_entered)
	_update_attack_geometry()
	_set_attack_active(false)


func _physics_process(delta: float) -> void:
	_update_attack_state(delta)
	_update_dodge_state(delta)
	_update_hurt_flash(delta)

	var move_direction := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(move_direction):
		facing_direction = signf(move_direction)
		$FacingMark.scale.x = facing_direction
		_update_attack_geometry()

	if Input.is_action_just_pressed("attack") and not is_dodging and _cooldown_time_remaining <= 0.0:
		_start_attack()

	if Input.is_action_just_pressed("dodge") and _can_start_dodge():
		_start_dodge(move_direction)

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_dodging:
		velocity.x = _dodge_direction * dodge_speed
	elif is_on_floor():
		velocity.x = move_direction * move_speed
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
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


func _can_start_dodge() -> bool:
	return is_on_floor() and not is_dodging and not is_attacking and _dodge_cooldown_remaining <= 0.0


func _start_dodge(move_direction: float) -> void:
	_dodge_direction = signf(move_direction) if not is_zero_approx(move_direction) else facing_direction
	facing_direction = _dodge_direction
	$FacingMark.scale.x = facing_direction
	_update_attack_geometry()
	is_dodging = true
	dodge_count += 1
	_dodge_time_remaining = dodge_duration
	_dodge_cooldown_remaining = dodge_cooldown
	body_visual.color = Color(0.48, 1.0, 1.0, 0.55)


func _end_dodge() -> void:
	is_dodging = false
	_refresh_body_color()


func _update_dodge_state(delta: float) -> void:
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)
	if not is_dodging:
		return

	_dodge_time_remaining -= delta
	if _dodge_time_remaining <= 0.0:
		_end_dodge()


func receive_hit() -> void:
	hit_count += 1
	current_hp = maxi(current_hp - 1, 0)
	_hurt_flash_remaining = 0.12
	_refresh_body_color()
	print("PLAYER HIT")


func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash_remaining <= 0.0:
		return
	_hurt_flash_remaining = maxf(_hurt_flash_remaining - delta, 0.0)
	if _hurt_flash_remaining <= 0.0:
		_refresh_body_color()


func _refresh_body_color() -> void:
	if _hurt_flash_remaining > 0.0:
		body_visual.color = Color.WHITE
	elif is_dodging:
		body_visual.color = Color(0.48, 1.0, 1.0, 0.55)
	else:
		body_visual.color = _base_visual_color
