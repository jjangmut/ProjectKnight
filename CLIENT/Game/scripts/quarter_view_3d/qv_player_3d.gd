extends CharacterBody3D
class_name QVPlayer3D
## 쿼터뷰 3D 팔라딘 기사 플레이어 (True Quarter-View 3D Paladin Player)
## - ProjectKnight_Paladin_Animated.glb 3D 모델 및 Mixamo 애니메이션 탑재
## - 360도 자유 3D 평면 기동 & 이동 방향 스무스 회전 (Slerp)
## - 3단 콤보 검격 & 360도 3D 크레센트 검기 (QVSwordBeam3D) 방출
## - 0.14초 저스트 패링 (Just Parry) 방패 바스티온 & 3배 카운터
## - 3D 점프 및 회피 대시

signal hp_changed(current: int, max_hp: int)
signal died
signal attack_swung(step: int)
signal sword_beam_fired(beam: Node3D)
signal just_parry_succeeded(enemy_node: Node)

enum State {
	IDLE,
	MOVE,
	DASH,
	ATTACK,
	GUARD,
	HURT
}

@export var move_speed: float = 7.0
@export var dash_speed: float = 14.0
@export var jump_velocity: float = 6.5
@export var gravity: float = 18.0
@export var max_hp: int = 5
@export var current_hp: int = 5

var current_state: State = State.IDLE
var move_direction: Vector3 = Vector3.ZERO
var facing_direction: Vector3 = Vector3.BACK # +Z in Godot 3D

# Combat & Combo
var combo_step: int = 0
var combo_reset_timer: float = 0.0
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var attack_duration_remaining: float = 0.0

# Guard & Just Parry
var is_guarding: bool = false
var guard_elapsed_time: float = 0.0
const JUST_PARRY_WINDOW: float = 0.14
var counter_attack_buff: bool = false
var counter_buff_timer: float = 0.0

# Dash
var dash_time_remaining: float = 0.0
const DASH_DURATION: float = 0.22
var is_invulnerable: bool = false

# 3D Model & AnimationPlayer
var model_root: Node3D
var anim_player: AnimationPlayer
var attack_area_3d: Area3D
var guard_mesh_3d: MeshInstance3D

const SwordBeam3DScene = preload("res://scripts/quarter_view_3d/qv_sword_beam_3d.gd")


func _ready() -> void:
	collision_layer = 1 # Player Body (Layer 1)
	collision_mask = 4  # World Obstacles (Layer 3: 4)
	add_to_group("player")

	_build_components()
	emit_signal("hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. Load 3D Animated Paladin Model
	var model_res := load("res://assets/models/ProjectKnight_Paladin_Animated.glb") as PackedScene
	if model_res != null:
		model_root = model_res.instantiate() as Node3D
		model_root.name = "PaladinModel"
		model_root.scale = Vector3(1.0, 1.0, 1.0)
		add_child(model_root)

		# Find AnimationPlayer
		for child in model_root.find_children("*", "", true, false):
			if child is AnimationPlayer:
				anim_player = child
				break
	else:
		# Fallback Capsule Mesh if GLB fails
		model_root = Node3D.new()
		var mesh_inst := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.4
		cap.height = 1.8
		mesh_inst.mesh = cap
		mesh_inst.position.y = 0.9
		model_root.add_child(mesh_inst)
		add_child(model_root)

	if anim_player != null:
		anim_player.play("Idle")

	# 2. 3D Body Collision Shape
	var body_col := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.45
	cap_shape.height = 1.8
	body_col.shape = cap_shape
	body_col.position.y = 0.9
	add_child(body_col)

	# 3. 3D Attack Hitbox Area (Frontal sweep)
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "AttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 2 # Enemies
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.5, 2.0)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 0.9, 1.2) # Forward offset
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	# 4. 3D Guard Barrier Mesh (Runic Cyan Arc)
	guard_mesh_3d = MeshInstance3D.new()
	guard_mesh_3d.name = "GuardBarrier3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.3
	torus.rings = 16
	torus.ring_segments = 8
	guard_mesh_3d.mesh = torus

	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.4, 1.8, 2.5, 0.9)
	gmat.emission_enabled = true
	gmat.emission = Color(0.4, 1.8, 2.5, 1.0)
	gmat.emission_energy_multiplier = 3.0
	guard_mesh_3d.material_override = gmat
	guard_mesh_3d.position = Vector3(0.0, 1.0, 0.8)
	guard_mesh_3d.rotation.x = PI * 0.5
	guard_mesh_3d.scale = Vector3(0.8, 0.8, 0.4)
	guard_mesh_3d.visible = false
	add_child(guard_mesh_3d)


func _physics_process(delta: float) -> void:
	_update_timers(delta)

	# Apply 3D Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	match current_state:
		State.IDLE, State.MOVE:
			_process_movement(delta)
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_process_attack_state(delta)
		State.GUARD:
			_process_guard_state(delta)
		State.HURT:
			_process_hurt_state(delta)

	move_and_slide()
	if global_position.y < 0.0:
		global_position.y = 0.0
		velocity.y = 0.0


func _update_timers(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0 and not is_attacking:
			combo_step = 0

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if is_guarding:
		guard_elapsed_time += delta

	if counter_attack_buff:
		counter_buff_timer -= delta
		if counter_buff_timer <= 0.0:
			counter_attack_buff = false


func _process_movement(delta: float) -> void:
	# Read inputs in isometric X-Z plane
	var input_vec := Vector3.ZERO
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vec.z -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.z += 1.0

	move_direction = input_vec.normalized()

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * move_speed
		velocity.z = move_direction.z * move_speed
		facing_direction = move_direction

		# Smooth 3D Rotation towards movement direction
		var target_rot := atan2(move_direction.x, move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 14.0 * delta)

		if (is_on_floor() or global_position.y <= 0.15) and anim_player != null and not is_attacking:
			if anim_player.current_animation != "Walk":
				anim_player.play("Walk", 0.1)
		_set_state(State.MOVE)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 70.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 70.0 * delta)
		if Vector2(velocity.x, velocity.z).length() < 0.2:
			velocity.x = 0.0
			velocity.z = 0.0

		if is_on_floor() and anim_player != null and not is_attacking and current_state != State.IDLE:
			if anim_player.current_animation != "Idle":
				anim_player.play("Idle", 0.15)
		_set_state(State.IDLE)

	# Action inputs
	if Input.is_action_just_pressed("jump") and is_on_floor():
		start_jump()
	elif Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0:
		start_attack()
	elif Input.is_action_just_pressed("dash") and is_on_floor():
		start_dash()
	elif Input.is_action_pressed("guard") and is_on_floor():
		start_guard()


func start_jump() -> void:
	velocity.y = jump_velocity
	if anim_player != null:
		anim_player.play("Jump", 0.1)


func start_dash() -> void:
	dash_time_remaining = DASH_DURATION
	is_invulnerable = true
	var dash_dir := move_direction if move_direction != Vector3.ZERO else facing_direction
	velocity.x = dash_dir.x * dash_speed
	velocity.z = dash_dir.z * dash_speed
	_set_state(State.DASH)


func _process_dash(delta: float) -> void:
	dash_time_remaining -= delta
	if dash_time_remaining <= 0.0:
		is_invulnerable = false
		_set_state(State.IDLE)


func start_attack() -> void:
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.9
	is_attacking = true
	attack_cooldown = 0.24
	attack_duration_remaining = 0.22

	if anim_player != null:
		anim_player.stop()
		anim_player.play("Attack_Slash", 0.05)

	attack_area_3d.monitoring = true
	emit_signal("attack_swung", combo_step)

	# Immediate responsive melee hit check
	_check_melee_hit()

	# Combo 3 Finisher: Fire 360-degree 3D Sword Beam!
	if combo_step == 3:
		_fire_sword_beam()

	_set_state(State.ATTACK)


func _check_melee_hit() -> void:
	for body in attack_area_3d.get_overlapping_bodies():
		if body != self and body.has_method("receive_hit"):
			var dmg := 2
			if counter_attack_buff:
				dmg = 6 # 3x Counter strike
				counter_attack_buff = false
			body.receive_hit(dmg, facing_direction)


func _fire_sword_beam() -> void:
	var beam := SwordBeam3DScene.new()
	beam.name = "QVSwordBeam3D_Finisher"
	get_parent().add_child(beam)
	beam.initialize(global_position + Vector3(0.0, 0.9, 0.0) + facing_direction * 1.0, facing_direction, 1 if counter_attack_buff else 0)
	sword_beam_fired.emit(beam)


func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	attack_duration_remaining -= delta

	if attack_duration_remaining <= 0.0:
		attack_area_3d.monitoring = false
		is_attacking = false
		_set_state(State.IDLE)


func start_guard() -> void:
	if is_guarding:
		return
	is_guarding = true
	guard_elapsed_time = 0.0
	guard_mesh_3d.visible = true
	velocity.x = 0.0
	velocity.z = 0.0

	if anim_player != null:
		anim_player.play("Parry_Block", 0.08)
	_set_state(State.GUARD)


func release_guard() -> void:
	is_guarding = false
	guard_mesh_3d.visible = false
	if anim_player != null and anim_player.current_animation == "Parry_Block":
		anim_player.play("Idle", 0.15)
	if current_state == State.GUARD:
		_set_state(State.IDLE)


func _process_guard_state(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not Input.is_action_pressed("guard"):
		release_guard()


func receive_incoming_attack(damage_amount: int, attacker: Node3D, attack_dir: Vector3) -> bool:
	if is_invulnerable:
		return false

	if is_guarding:
		var dot := facing_direction.dot(-attack_dir)
		if dot > 0.0: # Frontal 180-degree guard
			if guard_elapsed_time <= JUST_PARRY_WINDOW:
				# >>> 3D JUST PARRY SUCCESS! <<<
				just_parry_succeeded.emit(attacker)
				counter_attack_buff = true
				counter_buff_timer = 2.0
				if attacker.has_method("apply_parry_stun"):
					attacker.apply_parry_stun(1.5)
				return false # 100% damage blocked
			else:
				current_hp -= maxi(1, int(damage_amount * 0.2))
				emit_signal("hp_changed", current_hp, max_hp)
				return false

	# Full Hit
	current_hp -= damage_amount
	emit_signal("hp_changed", current_hp, max_hp)

	if anim_player != null:
		anim_player.play("Hit_Hurt", 0.05)

	if current_hp <= 0:
		_die()
	else:
		velocity = attack_dir * 8.0
		_set_state(State.HURT)
	return true


func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	if velocity.length() < 0.5:
		_set_state(State.IDLE)


func _set_state(new_st: State) -> void:
	current_state = new_st


func _die() -> void:
	emit_signal("died")
	set_physics_process(false)
