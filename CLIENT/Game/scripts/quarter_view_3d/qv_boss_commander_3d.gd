extends CharacterBody3D
class_name QVBossCommander3D
## 쿼터뷰 3D 보스 기사 지휘관 (Quarter-View 3D Boss Commander)
## 3D 방패 돌진, 360도 지진 충격파 링, 3단 대검격, 광폭화 각성 지원

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)

enum Pattern {
	IDLE,
	CHASE,
	TRIPLE_CLEAVE,
	SHIELD_CHARGE,
	QUAKE_RING,
	STUNNED
}

@export var max_hp: int = 24
@export var current_hp: int = 24
@export var move_speed: float = 3.6
@export var charge_speed: float = 12.0

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var pattern_timer: float = 0.0
var stun_timer: float = 0.0
var target_player: Node3D = null
var facing_direction: Vector3 = Vector3.BACK

var model_mesh: MeshInstance3D
var aura_ring_mesh: MeshInstance3D
var attack_area_3d: Area3D


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")
	add_to_group("bosses")

	_build_components()
	emit_signal("boss_hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. Armored Boss 3D Mesh
	model_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.65
	cap.height = 2.4
	model_mesh.mesh = cap

	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.25, 0.35, 1.0) # Dark Knight Iron
	bmat.metallic = 0.8
	bmat.roughness = 0.3
	bmat.emission_enabled = true
	bmat.emission = Color(0.8, 0.6, 0.2, 1.0) # Gold Inlays
	bmat.emission_energy_multiplier = 0.6
	model_mesh.material_override = bmat
	model_mesh.position.y = 1.2
	add_child(model_mesh)

	# 2. Crimson Aura Ring (Phase 2 Enrage)
	aura_ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.4
	torus.outer_radius = 1.6
	aura_ring_mesh.mesh = torus

	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(2.5, 0.3, 0.3, 1.0)
	amat.emission_enabled = true
	amat.emission = Color(2.5, 0.3, 0.3, 1.0)
	amat.emission_energy_multiplier = 3.5
	aura_ring_mesh.material_override = amat
	aura_ring_mesh.position.y = 0.2
	aura_ring_mesh.visible = false
	add_child(aura_ring_mesh)

	# 3. Collision Shape
	var col := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.65
	cap_shape.height = 2.4
	col.shape = cap_shape
	col.position.y = 1.2
	add_child(col)

	# 4. Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "BossAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 1.8, 2.5)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 1.2, 1.4)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		if stun_timer <= 0.0:
			current_pattern = Pattern.CHASE
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

	if facing_direction.length_squared() > 0.001:
		var target_rot := atan2(facing_direction.x, facing_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)

	pattern_timer -= delta

	match current_pattern:
		Pattern.IDLE, Pattern.CHASE:
			if pattern_timer <= 0.0:
				_pick_next_pattern(dist)
			else:
				var spd := move_speed * (1.35 if current_phase == 2 else 1.0)
				velocity.x = facing_direction.x * spd
				velocity.z = facing_direction.z * spd
		Pattern.SHIELD_CHARGE:
			velocity.x = facing_direction.x * charge_speed
			velocity.z = facing_direction.z * charge_speed
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 0.8
		Pattern.TRIPLE_CLEAVE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 1.0
		Pattern.QUAKE_RING:
			velocity.x = 0.0
			velocity.z = 0.0
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 1.2

	move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _pick_next_pattern(dist: float) -> void:
	if dist > 6.0:
		_execute_shield_charge()
	elif dist <= 3.2:
		if randf() > 0.5:
			_execute_triple_cleave()
		else:
			_execute_quake_ring()
	else:
		_execute_triple_cleave()


func _execute_shield_charge() -> void:
	current_pattern = Pattern.SHIELD_CHARGE
	pattern_timer = 0.75
	attack_area_3d.monitoring = true

	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self):
		attack_area_3d.monitoring = false


func _execute_triple_cleave() -> void:
	current_pattern = Pattern.TRIPLE_CLEAVE
	pattern_timer = 0.95

	for swing in range(3):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break
		attack_area_3d.monitoring = true
		velocity = facing_direction * 4.5
		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(self):
			attack_area_3d.monitoring = false
			await get_tree().create_timer(0.08).timeout


func _execute_quake_ring() -> void:
	current_pattern = Pattern.QUAKE_RING
	pattern_timer = 1.1

	# Expanding 360-degree shockwave ring in 3D
	var ring := Area3D.new()
	ring.collision_layer = 0
	ring.collision_mask = 1 # Player
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 4.2
	cyl.height = 0.8
	col.shape = cyl
	ring.add_child(col)
	get_parent().add_child(ring)
	ring.global_position = global_position

	await get_tree().process_frame
	for body in ring.get_overlapping_bodies():
		if body.is_in_group("player") and is_instance_valid(body):
			if body.has_method("receive_incoming_attack"):
				var push := (body.global_position - global_position).normalized()
				body.receive_incoming_attack(2, self, push)
	ring.queue_free()


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			body.receive_incoming_attack(2, self, facing_direction)


func apply_parry_stun(duration: float = 1.5) -> void:
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	velocity = -facing_direction * 5.0
	attack_area_3d.monitoring = false


func receive_hit(amount: int, hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = hit_dir * 3.0

	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	aura_ring_mesh.visible = true
	move_speed = 4.8
	charge_speed = 14.5
	emit_signal("phase_changed", 2)


func _die() -> void:
	emit_signal("boss_defeated", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()
