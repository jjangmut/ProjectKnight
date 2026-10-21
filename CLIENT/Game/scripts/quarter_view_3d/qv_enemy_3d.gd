extends CharacterBody3D
class_name QVEnemy3D
## 쿼터뷰 3D 적 유닛 (Quarter-View 3D Enemy)
## 360도 자유 추적 AI, 근접 부채꼴 타격, 피격 넉백 및 패링 스턴 지원

signal enemy_died(enemy_node: Node)
signal enemy_hp_changed(current: int, max_hp: int)

@export var move_speed: float = 4.2
@export var max_hp: int = 6
@export var current_hp: int = 6
@export var attack_damage: int = 1
@export var attack_range: float = 2.2
@export var attack_cooldown: float = 1.6

var target_player: Node3D = null
var is_stunned: bool = false
var stun_time_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var facing_direction: Vector3 = Vector3.BACK

var model_mesh: MeshInstance3D
var attack_area_3d: Area3D


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (Layer 2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")

	_build_components()
	emit_signal("enemy_hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. 3D Body Mesh (Armored Crimson Goblin/Skeleton Style)
	model_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.6
	model_mesh.mesh = cap

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.25, 0.25, 1.0) # Crimson armor
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.2, 0.2, 1.0)
	mat.emission_energy_multiplier = 0.8
	model_mesh.material_override = mat
	model_mesh.position.y = 0.8
	add_child(model_mesh)

	# 2. Collision Shape
	var col := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.4
	cap_shape.height = 1.6
	col.shape = cap_shape
	col.position.y = 0.8
	add_child(col)

	# 3. Attack Area
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "EnemyAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.4, 1.8)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 0.8, 1.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta

	if is_stunned:
		stun_time_remaining -= delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		if stun_time_remaining <= 0.0:
			is_stunned = false
			model_mesh.material_override.emission = Color(0.9, 0.2, 0.2, 1.0)
		move_and_slide()
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	facing_direction = diff.normalized()

	# Rotate towards player
	if facing_direction.length_squared() > 0.001:
		var target_rot := atan2(facing_direction.x, facing_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 10.0 * delta)

	if dist <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if cooldown_remaining <= 0.0:
			_execute_attack()
	else:
		velocity.x = facing_direction.x * move_speed
		velocity.z = facing_direction.z * move_speed

	move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _execute_attack() -> void:
	cooldown_remaining = attack_cooldown
	attack_area_3d.monitoring = true

	# Small forward lunge
	velocity = facing_direction * 4.0

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		attack_area_3d.monitoring = false


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			body.receive_incoming_attack(attack_damage, self, facing_direction)


func apply_parry_stun(duration: float = 1.5) -> void:
	is_stunned = true
	stun_time_remaining = duration
	velocity = -facing_direction * 6.0
	attack_area_3d.monitoring = false
	model_mesh.material_override.emission = Color(2.5, 2.0, 0.2, 1.0) # Golden Stun


func receive_hit(amount: int, hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	emit_signal("enemy_hp_changed", current_hp, max_hp)

	velocity = hit_dir * 7.0

	if current_hp <= 0:
		_die()


func _die() -> void:
	emit_signal("enemy_died", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "scale", Vector3.ZERO, 0.25)
		tween.tween_callback(queue_free)
	else:
		queue_free()
