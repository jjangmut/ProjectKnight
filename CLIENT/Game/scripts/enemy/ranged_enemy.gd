extends CharacterBody2D

enum State { PATROL, RANGED_ATTACK }
enum AttackPhase { WINDUP, RECOVERY }

@export_category("Movement")
@export var move_speed: float = 80.0
@export var patrol_distance: float = 80.0
@export var detection_range: float = 700.0
@export var gravity: float = 1400.0
@export_category("Attack")
@export var attack_windup: float = 0.6
@export var attack_cooldown: float = 1.4
@export var projectile_scene: PackedScene
@export_category("Health")
@export var max_hp: int = 3

@onready var visual: Polygon2D = $Visual
@onready var muzzle: Marker2D = $Muzzle

var state: State = State.PATROL
var attack_phase: AttackPhase = AttackPhase.RECOVERY
var current_hp: int
var projectile_count: int = 0
var _player: CharacterBody2D
var _origin_x: float
var _patrol_direction: float = -1.0
var _phase_time_remaining: float = 0.0
var _base_color := Color(0.55, 0.3, 0.92, 1)
var _hit_flash_remaining: float = 0.0


func _ready() -> void:
	current_hp = max_hp
	_origin_x = position.x
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
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
		State.RANGED_ATTACK:
			_update_attack(delta)
	move_and_slide()
	if state == State.PATROL and is_on_wall():
		_patrol_direction *= -1.0


func _update_patrol() -> void:
	if absf(_player.position.x - position.x) <= detection_range:
		_begin_attack()
		return
	if position.x <= _origin_x - patrol_distance:
		_patrol_direction = 1.0
	elif position.x >= _origin_x + patrol_distance:
		_patrol_direction = -1.0
	velocity.x = _patrol_direction * move_speed


func _begin_attack() -> void:
	state = State.RANGED_ATTACK
	attack_phase = AttackPhase.WINDUP
	_phase_time_remaining = attack_windup
	velocity.x = 0.0
	_set_color(Color(0.95, 0.75, 1.0, 1.0))


func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	_phase_time_remaining -= delta
	if _phase_time_remaining > 0.0:
		return
	if attack_phase == AttackPhase.WINDUP:
		_fire_projectile()
		attack_phase = AttackPhase.RECOVERY
		_phase_time_remaining = attack_cooldown
		_set_color(_base_color)
	else:
		state = State.PATROL


func _fire_projectile() -> void:
	if projectile_scene == null or not is_instance_valid(_player):
		return
	var projectile := projectile_scene.instantiate() as Area2D
	var fire_direction := signf(_player.global_position.x - global_position.x)
	get_parent().add_child(projectile)
	projectile.global_position = Vector2(global_position.x + fire_direction * 40.0, muzzle.global_position.y)
	projectile.configure(fire_direction)
	projectile_count += 1


func receive_hit() -> void:
	current_hp -= 1
	if current_hp <= 0:
		queue_free()
		return
	_hit_flash_remaining = 0.12
	visual.color = Color.WHITE


func _update_hit_flash(delta: float) -> void:
	if _hit_flash_remaining <= 0.0:
		return
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	if _hit_flash_remaining <= 0.0:
		visual.color = Color(0.95, 0.75, 1.0, 1.0) if state == State.RANGED_ATTACK and attack_phase == AttackPhase.WINDUP else _base_color


func _set_color(color: Color) -> void:
	if _hit_flash_remaining <= 0.0:
		visual.color = color
