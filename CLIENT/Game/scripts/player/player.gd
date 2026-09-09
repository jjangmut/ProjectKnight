extends CharacterBody2D

@export_category("Movement")
@export var move_speed: float = 320.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.65

@export_category("Jump")
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0
@export var jump_buffer: float = 0.14
@export var coyote_time: float = 0.12

@export_category("Attack")
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.32
@export var attack_range: float = 72.0

@export_category("Guard")
@export var guard_recovery: float = 0.12
@export var guard_cooldown: float = 0.2

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
var is_guarding: bool = false
var guard_count: int = 0
var guard_block_count: int = 0
var _guard_direction: float = 1.0
var _guard_elapsed: float = 0.0
var _guard_recovery_remaining: float = 0.0
var _guard_cooldown_remaining: float = 0.0
var _guard_block_flash_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _coyote_remaining: float = 0.0
var _base_visual_color: Color
var current_hp: int
var hit_count: int = 0
var _hurt_flash_remaining: float = 0.0
const HIT_INVULNERABILITY_USEC: int = 500_000
var _hit_invulnerable_until_usec: int = 0
var is_dead: bool = false


func _ready() -> void:
	_base_visual_color = body_visual.color
	current_hp = max_hp
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_area.area_entered.connect(_on_attack_area_entered)
	_update_attack_geometry()
	_set_attack_active(false)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_attack_state(delta)
	_update_guard_state(delta)
	_update_hurt_flash(delta)

	var move_direction := Input.get_axis("move_left", "move_right")
	if not is_guarding and _guard_recovery_remaining <= 0.0 and not is_zero_approx(move_direction):
		facing_direction = signf(move_direction)
		$FacingMark.scale.x = facing_direction
		_update_attack_geometry()

	# A held guard starts at the next legal moment; it never cancels an attack.
	if Input.is_action_pressed("guard") and _can_start_guard():
		_start_guard()

	if Input.is_action_pressed("attack") and not is_attacking and not is_guarding and _guard_recovery_remaining <= 0.0 and _cooldown_time_remaining <= 0.0:
		_start_attack()

	if not is_on_floor():
		velocity.y += gravity * delta
	_coyote_remaining = coyote_time if is_on_floor() else maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = jump_buffer if Input.is_action_just_pressed("jump") else maxf(0.0, _jump_buffer_remaining - delta)

	if is_guarding or _guard_recovery_remaining > 0.0:
		velocity.x = 0.0
	elif is_on_floor():
		velocity.x = move_direction * move_speed
	else:
		var air_target_speed := move_direction * move_speed
		var air_acceleration := move_speed * 8.0 * air_control
		velocity.x = move_toward(velocity.x, air_target_speed, air_acceleration * delta)
	if not is_guarding and _guard_recovery_remaining <= 0.0 and _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0

	move_and_slide()


func _start_attack() -> void:
	if is_dead or is_guarding or _guard_recovery_remaining > 0.0:
		return
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
	if is_dead or not is_attacking:
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
	if is_dead or not is_attacking:
		return

	var target := area.get_parent()
	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true

	if target.has_method("receive_hit"):
		target.receive_hit()


func _can_start_guard() -> bool:
	return not is_dead and is_on_floor() and not is_guarding and not is_attacking and _cooldown_time_remaining <= 0.0 and _guard_cooldown_remaining <= 0.0


func _start_guard() -> void:
	if not _can_start_guard():
		return
	_guard_direction = facing_direction
	is_guarding = true
	guard_count += 1
	_guard_elapsed = 0.0
	velocity.x = 0.0
	_refresh_body_color()


func _end_guard() -> void:
	if not is_guarding:
		return
	is_guarding = false
	_guard_recovery_remaining = guard_recovery
	_guard_cooldown_remaining = guard_cooldown
	_refresh_body_color()


func _update_guard_state(delta: float) -> void:
	_guard_cooldown_remaining = maxf(_guard_cooldown_remaining - delta, 0.0)
	_guard_recovery_remaining = maxf(_guard_recovery_remaining - delta, 0.0)
	_guard_block_flash_remaining = maxf(_guard_block_flash_remaining - delta, 0.0)
	if is_dead or not is_guarding:
		return
	_guard_elapsed += delta
	if not Input.is_action_pressed("guard") or not is_on_floor():
		_end_guard()


func receive_attack(source_position: Vector2, blockable: bool = true) -> bool:
	if is_dead:
		return false
	# Source at exactly the player's center is not a frontal attack.
	var in_front := (source_position.x - global_position.x) * _guard_direction > 0.0
	if blockable and is_guarding and is_on_floor() and in_front:
		guard_block_count += 1
		_guard_block_flash_remaining = 0.14
		return true
	receive_hit()
	return false


func receive_hit() -> void:
	if is_dead:
		return
	var hit_time_usec := Time.get_ticks_usec()
	if hit_time_usec < _hit_invulnerable_until_usec:
		return
	_end_guard()
	hit_count += 1
	current_hp = maxi(current_hp - 1, 0)
	if current_hp == 0:
		_die()
		return
	_hit_invulnerable_until_usec = hit_time_usec + HIT_INVULNERABILITY_USEC
	_hurt_flash_remaining = 0.12
	_refresh_body_color()
	print("PLAYER HIT")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_end_attack()
	_hurt_flash_remaining = 0.0
	_end_guard()
	_attack_time_remaining = 0.0
	velocity = Vector2.ZERO
	print("PLAYER DEAD")


func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash_remaining <= 0.0:
		return
	_hurt_flash_remaining = maxf(_hurt_flash_remaining - delta, 0.0)
	if _hurt_flash_remaining <= 0.0:
		_refresh_body_color()


func _refresh_body_color() -> void:
	if _hurt_flash_remaining > 0.0:
		body_visual.color = Color.WHITE
	elif is_guarding:
		body_visual.color = Color(0.7, 0.85, 1.0, 1.0)
	else:
		body_visual.color = _base_visual_color
