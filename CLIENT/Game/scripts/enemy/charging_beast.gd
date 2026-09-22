extends "res://scripts/enemy/test_enemy.gd"
## Shares the existing enemy damage/phase contract; adds a committed ground charge.
@export var charge_speed: float = 420.0
var is_attacking: bool:
	get:
		return state == State.ATTACK

func _ready() -> void:
	super._ready()
	add_to_group("enemy")
	set_meta("art_variant", "beast")
	attack_collision.shape.size = Vector2(44, 40)
	attack_area.position.y = 5.0
	_build_enemy_sprite()

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return
	super._physics_process(delta)
	if is_attack_active:
		if is_on_wall():
			_begin_recovery()
		else:
			for area in attack_area.get_overlapping_areas():
				_on_attack_area_entered(area)

func _begin_attack(horizontal_distance: float) -> void:
	super._begin_attack(horizontal_distance)
	# A short nose hitbox, separate from the distance that triggers the charge.
	attack_area.position.x = _attack_direction * 45.0
	_hit_player_ids.clear()
	is_attack_active = false
	attack_collision.set_deferred("disabled", true)

func _update_attack(delta: float) -> void:
	velocity.x = _attack_direction * charge_speed if is_attack_active else 0.0
	_phase_time_remaining -= delta
	if _phase_time_remaining > 0.0:
		return
	match attack_phase:
		AttackPhase.WINDUP:
			attack_phase = AttackPhase.ACTIVE
			_phase_time_remaining = attack_active
			is_attack_active = true
			velocity.x = _attack_direction * charge_speed
			attack_collision.set_deferred("disabled", false)
			_set_state_color(Color(1.0, 0.2, 0.12, 1.0))
		AttackPhase.ACTIVE:
			_begin_recovery()
		AttackPhase.RECOVERY:
			state = State.CHASE

func _begin_recovery() -> void:
	attack_phase = AttackPhase.RECOVERY
	_phase_time_remaining = attack_cooldown
	is_attack_active = false
	velocity.x = 0.0
	attack_collision.set_deferred("disabled", true)
	_set_state_color(_base_color)

func _on_attack_area_entered(area: Area2D) -> void:
	if current_hp <= 0 or not is_attack_active:
		return
	var target := area.get_parent()
	if not target.is_in_group("player") or not target.has_method("receive_hit"):
		return
	# The shared player owns post-hit immunity; committed charges cannot be blocked.
	if target.is_dead:
		return
	var target_id := target.get_instance_id()
	if _hit_player_ids.has(target_id):
		return
	_hit_player_ids[target_id] = true
	target.receive_attack(global_position, false)

func receive_hit() -> void:
	if current_hp <= 0:
		return
	super.receive_hit()
	if current_hp <= 0:
		is_attack_active = false
		attack_collision.set_deferred("disabled", true)
