extends CharacterBody3D
class_name SideQVPlayer
## 사이드 쿼터뷰 2.5D 팔라딘 기사 (Side Quarter-View 2D Character in 3D World)
## - 2D 고해상도 스프라이트 (Sprite3D) 탑재 & 실시간 3D 그림자 투영
## - 사이드 쿼터뷰 벨트스크롤 3D 이동 (X: 좌우, Z: 안팎 깊이, Y: 점프)
## - 3단 콤보 검격 & 360도 황금빛 사이드 쿼터뷰 크레센트 검기 발출
## - 0.14초 저스트 패링 (Just Parry) 방패 바스티온 & 3배 카운터 어택

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

@export var move_speed_x: float = 7.5
@export var move_speed_z: float = 4.8
@export var dash_speed: float = 14.0
@export var jump_velocity: float = 6.8
@export var gravity: float = 18.0
@export var max_hp: int = 5
@export var current_hp: int = 5

var current_state: State = State.IDLE
var move_direction: Vector3 = Vector3.ZERO
var facing_dir_x: float = 1.0 # 1.0 = Right, -1.0 = Left

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

# Procedural animation parameters
var anim_timer: float = 0.0

# Visual & Collision references
var sprite_3d: Sprite3D
var guard_barrier_3d: MeshInstance3D
var slash_visual_3d: MeshInstance3D
var attack_area_3d: Area3D

const PaladinTexture = preload("res://assets/player/knight_stage1_paladin.png")
const AttackSheetTexture = preload("res://assets/player_frames/attack_v1.png")
const SwordBeamScene = preload("res://scripts/side_quarter_view/side_qv_sword_beam.gd")


func _ready() -> void:
	collision_layer = 1 # Player Layer (1)
	collision_mask = 4  # World Layer (4)
	add_to_group("player")

	_build_components()
	emit_signal("hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite3D)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "CharacterSprite3D"
	sprite_3d.texture = PaladinTexture
	# Stand vertically, facing camera in isometric-side view
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.0028 # Calibrated height ~1.8m
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_3d.position.y = 0.95
	add_child(sprite_3d)

	# 2. 3D Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	# 3. 3D Runic Shield Barrier (Just Parry visual)
	guard_barrier_3d = MeshInstance3D.new()
	guard_barrier_3d.name = "GuardBarrier3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.95
	guard_barrier_3d.mesh = torus

	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.8, 1.8, 0.85)
	bmat.emission_enabled = true
	bmat.emission = Color(0.2, 0.8, 2.0, 1.0)
	bmat.emission_energy_multiplier = 4.0
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_barrier_3d.material_override = bmat
	guard_barrier_3d.position = Vector3(0.5, 0.9, 0.0)
	guard_barrier_3d.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	guard_barrier_3d.visible = false
	add_child(guard_barrier_3d)

	# 4. 3D Melee Slash Arc VFX
	slash_visual_3d = MeshInstance3D.new()
	slash_visual_3d.name = "SlashVisual3D"
	var arc_torus := TorusMesh.new()
	arc_torus.inner_radius = 0.85
	arc_torus.outer_radius = 1.15
	slash_visual_3d.mesh = arc_torus

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(2.5, 1.8, 0.5, 1.0) # Golden Holy Flash
	smat.emission_enabled = true
	smat.emission = Color(2.5, 1.8, 0.5, 1.0)
	smat.emission_energy_multiplier = 4.5
	slash_visual_3d.material_override = smat
	slash_visual_3d.scale = Vector3(1.1, 0.15, 0.7)
	slash_visual_3d.position = Vector3(0.8, 0.9, 0.0)
	slash_visual_3d.visible = false
	add_child(slash_visual_3d)

	# 5. Attack Hitbox Area3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "AttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 2 # Enemy Layer (2)
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.8, 1.8)
	atk_shape.shape = box
	atk_shape.position = Vector3(1.0, 0.9, 0.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)


func _physics_process(delta: float) -> void:
	_update_timers(delta)

	# Apply Gravity in 3D
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0.0

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
	_update_procedural_animations(delta)

	# Ground clamp safety
	if global_position.y < 0.0 and is_on_floor():
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
	var input_vec := Vector3.ZERO
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vec.z -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.z += 1.0

	# Side Quarter-View Movement
	if input_vec.x != 0.0:
		facing_dir_x = signf(input_vec.x)
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		# Flip attack and guard offsets
		attack_area_3d.position.x = 1.0 * facing_dir_x
		guard_barrier_3d.position.x = 0.6 * facing_dir_x
		slash_visual_3d.position.x = 0.8 * facing_dir_x

	if input_vec != Vector3.ZERO:
		var norm := input_vec.normalized()
		velocity.x = norm.x * move_speed_x
		velocity.z = norm.z * move_speed_z
		move_direction = norm
		_set_state(State.MOVE)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 45.0 * delta)
		move_direction = Vector3.ZERO
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


func start_dash() -> void:
	dash_time_remaining = DASH_DURATION
	is_invulnerable = true
	var dash_dir := move_direction if move_direction != Vector3.ZERO else Vector3(facing_dir_x, 0, 0)
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
	combo_reset_timer = 0.95
	is_attacking = true
	attack_cooldown = 0.22
	attack_duration_remaining = 0.20

	slash_visual_3d.visible = true
	slash_visual_3d.rotation.y = randf_range(-0.3, 0.3)
	attack_area_3d.monitoring = true
	emit_signal("attack_swung", combo_step)

	# Responsive melee hit check
	_check_melee_hit()

	# Combo 3 Finisher: Fire glowing 3D sword beam in side-quarter direction!
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
			body.receive_hit(dmg, Vector3(facing_dir_x, 0, 0))


func _fire_sword_beam() -> void:
	var beam := SwordBeamScene.new()
	beam.name = "SideQVSwordBeam_Finisher"
	get_parent().add_child(beam)
	var shoot_dir := Vector3(facing_dir_x, 0, 0)
	beam.initialize(global_position + Vector3(facing_dir_x * 0.9, 0.9, 0.0), shoot_dir, 2 if counter_attack_buff else 0)
	sword_beam_fired.emit(beam)


func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
	attack_duration_remaining -= delta

	if attack_duration_remaining <= 0.0:
		slash_visual_3d.visible = false
		attack_area_3d.monitoring = false
		is_attacking = false
		_set_state(State.IDLE)


func start_guard() -> void:
	if is_guarding:
		return
	is_guarding = true
	guard_elapsed_time = 0.0
	guard_barrier_3d.visible = true
	velocity.x = 0.0
	velocity.z = 0.0
	_set_state(State.GUARD)


func release_guard() -> void:
	is_guarding = false
	guard_barrier_3d.visible = false
	if current_state == State.GUARD:
		_set_state(State.IDLE)


func _process_guard_state(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not Input.is_action_pressed("guard"):
		release_guard()


func receive_incoming_attack(amount: int, attacker: Node, attack_dir: Vector3) -> bool:
	if is_invulnerable:
		return false

	if is_guarding:
		if guard_elapsed_time <= JUST_PARRY_WINDOW:
			# Just Parry! 100% damage blocked, attacker stunned, 3x counter buff!
			counter_attack_buff = true
			counter_buff_timer = 3.5
			emit_signal("just_parry_succeeded", attacker)
			if attacker != null and attacker.has_method("apply_parry_stun"):
				attacker.apply_parry_stun(2.0)
			_trigger_parry_flash()
			return false
		else:
			# Normal Guard: 50% damage reduction
			current_hp -= maxi(1, int(amount * 0.5))
			emit_signal("hp_changed", current_hp, max_hp)
			velocity = attack_dir * 3.0
			return true

	# Direct Hit
	current_hp -= amount
	emit_signal("hp_changed", current_hp, max_hp)
	velocity = attack_dir * 5.0
	_set_state(State.HURT)

	if current_hp <= 0:
		emit_signal("died")
	return true


func _trigger_parry_flash() -> void:
	var tween := create_tween()
	if tween:
		guard_barrier_3d.scale = Vector3(1.6, 1.6, 1.6)
		tween.tween_property(guard_barrier_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.18)


func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if Vector2(velocity.x, velocity.z).length() < 0.2:
		_set_state(State.IDLE)


func _update_procedural_animations(delta: float) -> void:
	anim_timer += delta * 12.0

	# 2D Sprite procedural bobbing and breathing in 3D world
	if current_state == State.MOVE:
		# Dynamic running bounce & lean
		sprite_3d.position.y = 0.95 + abs(sin(anim_timer)) * 0.08
		sprite_3d.rotation.z = -facing_dir_x * 0.06
	elif current_state == State.IDLE:
		# Idle breathing
		sprite_3d.position.y = 0.95 + sin(anim_timer * 0.3) * 0.02
		sprite_3d.rotation.z = 0.0
	elif current_state == State.ATTACK:
		# Slash forward surge
		sprite_3d.rotation.z = facing_dir_x * 0.12
	elif current_state == State.GUARD:
		# Firm braced stance
		sprite_3d.position.y = 0.92
		sprite_3d.rotation.z = -facing_dir_x * 0.08


func _set_state(new_state: State) -> void:
	current_state = new_state
