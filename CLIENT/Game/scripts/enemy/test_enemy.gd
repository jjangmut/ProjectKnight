extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

@export_category("Movement")
@export var move_speed: float = 130.0
@export var patrol_distance: float = 120.0
@export var detection_range: float = 420.0
@export var gravity: float = 1400.0
@export_category("Attack")
@export var attack_range: float = 90.0
@export var attack_windup: float = 0.5
@export var attack_active: float = 0.15
@export var attack_cooldown: float = 1.0
@export_category("Health")
@export var max_hp: int = 3

@onready var visual: Polygon2D = $Visual
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var state: State = State.PATROL
var attack_phase: AttackPhase = AttackPhase.RECOVERY
var current_hp: int
var attack_count: int = 0
var is_attack_active: bool = false
var _player: CharacterBody2D
var _origin_x: float
var _patrol_direction: float = -1.0
var _attack_direction: float = -1.0
var _phase_time_remaining: float = 0.0
var _hit_player_ids: Dictionary = {}
var _base_color := Color(0.92, 0.3, 0.28, 1)
var _hit_flash_remaining: float = 0.0


func _ready() -> void:
	current_hp = max_hp
	_origin_x = position.x
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_area.area_entered.connect(_on_attack_area_entered)
	attack_collision.disabled = true
	visual.color = _base_color


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	_update_hit_flash(delta)
	if not is_instance_valid(_player):
		velocity.x = 0.0
		move_and_slide()
		return
	match state:
		State.PATROL:
			_update_patrol()
		State.CHASE:
			_update_chase()
		State.ATTACK:
			_update_attack(delta)
	move_and_slide()
	if state == State.PATROL and is_on_wall():
		_patrol_direction *= -1.0


func _update_patrol() -> void:
	var distance_to_player := absf(_player.position.x - position.x)
	if distance_to_player <= detection_range:
		state = State.CHASE
		return
	if position.x <= _origin_x - patrol_distance:
		_patrol_direction = 1.0
	elif position.x >= _origin_x + patrol_distance:
		_patrol_direction = -1.0
	velocity.x = _patrol_direction * move_speed * 0.5


func _update_chase() -> void:
	var horizontal_distance := _player.position.x - position.x
	if absf(horizontal_distance) > detection_range * 1.25:
		state = State.PATROL
		return
	if absf(horizontal_distance) <= attack_range and absf(_player.position.y - position.y) < 72.0:
		_begin_attack(horizontal_distance)
		return
	velocity.x = signf(horizontal_distance) * move_speed


func _begin_attack(horizontal_distance: float) -> void:
	state = State.ATTACK
	attack_phase = AttackPhase.WINDUP
	attack_count += 1
	_attack_direction = signf(horizontal_distance) if not is_zero_approx(horizontal_distance) else _patrol_direction
	attack_area.position.x = _attack_direction * (22.0 + attack_range * 0.5)
	_phase_time_remaining = attack_windup
	velocity.x = 0.0
	_set_state_color(Color(1.0, 0.82, 0.2, 1.0))


func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	_phase_time_remaining -= delta
	if _phase_time_remaining > 0.0:
		return
	match attack_phase:
		AttackPhase.WINDUP:
			attack_phase = AttackPhase.ACTIVE
			_phase_time_remaining = attack_active
			is_attack_active = true
			_hit_player_ids.clear()
			attack_collision.set_deferred("disabled", false)
			_set_state_color(Color(1.0, 0.2, 0.12, 1.0))
		AttackPhase.ACTIVE:
			attack_phase = AttackPhase.RECOVERY
			_phase_time_remaining = attack_cooldown
			is_attack_active = false
			attack_collision.set_deferred("disabled", true)
			_set_state_color(_base_color)
		AttackPhase.RECOVERY:
			state = State.CHASE


func receive_hit() -> void:
	current_hp -= 1
	if current_hp <= 0:
		queue_free()
		return
	_hit_flash_remaining = 0.12
	visual.color = Color.WHITE


func _on_attack_area_entered(area: Area2D) -> void:
	if not is_attack_active:
		return
	var target := area.get_parent()
	var target_id := target.get_instance_id()
	if _hit_player_ids.has(target_id):
		return
	_hit_player_ids[target_id] = true
	if target.has_method("receive_attack"):
		target.receive_attack(global_position, _is_attack_blockable())
	elif target.has_method("receive_hit"):
		target.receive_hit()


func _is_attack_blockable() -> bool:
	return true


func _update_hit_flash(delta: float) -> void:
	if _hit_flash_remaining <= 0.0:
		return
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	if _hit_flash_remaining <= 0.0:
		_restore_state_color()


func _set_state_color(color: Color) -> void:
	if _hit_flash_remaining <= 0.0:
		visual.color = color


func _restore_state_color() -> void:
	if state != State.ATTACK or attack_phase == AttackPhase.RECOVERY:
		visual.color = _base_color
	elif attack_phase == AttackPhase.WINDUP:
		visual.color = Color(1.0, 0.82, 0.2, 1.0)
	else:
		visual.color = Color(1.0, 0.2, 0.12, 1.0)
