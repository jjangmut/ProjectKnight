extends CharacterBody2D
class_name QVPlayer
## 쿼터뷰 2.5D 기사 플레이어 (Quarter-View 2.5D Knight Player)
## - 8방향 2.5D 평면 이동 물리 (중력 제거 및 전방위 기동)
## - Z축 가상 고도 점프 & 동적 바닥 그림자 분리
## - 8방향/360도 3단 콤보 공격 & 크레센트 검기 방출
## - 0.14초 저스트 패링 (Just Parry) 방패 바스티온 & 3배 카운터
## - 0.22초 무적 회피 대시/구르기
## - Y-Sort 깊이 정렬 완벽 호환 (발밑 피벗)

signal hp_changed(current: int, max_hp: int)
signal died
signal attack_swung(step: int)
signal just_parry_succeeded(enemy_node: Node)
signal state_changed(old_state: String, new_state: String)

enum State {
	IDLE,
	MOVE,
	DASH,
	ATTACK,
	AIR_ATTACK,
	GUARD,
	PARRY_STUN,
	HURT
}

@export var move_speed: float = 260.0
@export var dash_speed: float = 520.0
@export var max_hp: int = 5
@export var current_hp: int = 5

# Movement & Orientation
var current_state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var facing_angle: float = 0.0

# Z-Axis Virtual Elevation (Jump & Air Fall)
var z_height: float = 0.0
var z_velocity: float = 0.0
var z_gravity: float = 1400.0
var jump_strength: float = 350.0
var is_on_ground: bool = true

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

# Dash & Invulnerability
var dash_time_remaining: float = 0.0
const DASH_DURATION: float = 0.22
var is_invulnerable: bool = false
var dash_direction: Vector2 = Vector2.RIGHT

# Contact Knockback
var is_contact_knockback: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_duration: float = 0.0

# Node References
var visual_root: Node2D
var player_sprite: Sprite2D
var shadow: Line2D
var attack_area: Area2D
var guard_barrier: Line2D
var parry_sparks: CPUParticles2D
var weapon_slash_arc: Line2D

const SwordBeamScene = preload("res://scripts/quarter_view/qv_sword_beam.gd")


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 # Player Body Layer
	collision_mask = 4 # World Static Obstacles/Walls

	_build_components()
	emit_signal("hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. Floor Drop Shadow (Dynamic Ellipse)
	shadow = Line2D.new()
	shadow.name = "FloorShadow"
	shadow.width = 14.0
	shadow.default_color = Color(0.02, 0.02, 0.05, 0.45)
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.points = PackedVector2Array([Vector2(-18.0, 0.0), Vector2(18.0, 0.0)])
	add_child(shadow)

	# 2. Visual Root (Offsets on Z-axis without moving physics position)
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	# 3. Player Sprite
	player_sprite = Sprite2D.new()
	player_sprite.name = "PlayerSprite"
	var tex = load("res://assets/player/knight_stage1_paladin.png")
	if tex == null:
		tex = load("res://assets/player/knight_idle_v1.png")
	player_sprite.texture = tex
	player_sprite.position = Vector2(0.0, -32.0) # Pivot at feet
	visual_root.add_child(player_sprite)

	# 4. Guard Barrier (Aegis Arc)
	guard_barrier = Line2D.new()
	guard_barrier.name = "GuardBarrier"
	guard_barrier.width = 6.0
	guard_barrier.default_color = Color(0.9, 1.8, 2.5, 0.95) # Runic Cyan Glow
	guard_barrier.begin_cap_mode = Line2D.LINE_CAP_ROUND
	guard_barrier.end_cap_mode = Line2D.LINE_CAP_ROUND
	var arc_pts := PackedVector2Array()
	for i in range(9):
		var angle := -PI * 0.4 + (i / 8.0) * PI * 0.8
		arc_pts.append(Vector2(cos(angle), sin(angle)) * 36.0 + Vector2(0.0, -28.0))
	guard_barrier.points = arc_pts
	guard_barrier.visible = false
	visual_root.add_child(guard_barrier)

	# 5. Weapon Slash Arc (Visible Swing)
	weapon_slash_arc = Line2D.new()
	weapon_slash_arc.name = "WeaponSlashArc"
	weapon_slash_arc.width = 8.0
	weapon_slash_arc.default_color = Color(2.0, 1.6, 0.6, 0.9)
	weapon_slash_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	weapon_slash_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	var slash_pts := PackedVector2Array()
	for i in range(7):
		var ang := -PI * 0.35 + (i / 6.0) * PI * 0.7
		slash_pts.append(Vector2(cos(ang), sin(ang)) * 48.0 + Vector2(0.0, -28.0))
	weapon_slash_arc.points = slash_pts
	weapon_slash_arc.visible = false
	visual_root.add_child(weapon_slash_arc)

	# 6. Attack Area (Quarter-View 360-rotatable sector)
	attack_area = Area2D.new()
	attack_area.name = "QVAttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2 # Enemies
	attack_area.monitoring = false
	attack_area.monitorable = false

	var atk_col := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 52.0
	atk_col.shape = circle_shape
	atk_col.position = Vector2(36.0, 0.0) # Forward offset
	attack_area.add_child(atk_col)
	visual_root.add_child(attack_area)

	# 7. Player Body Collision Shape
	var body_col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 36.0
	body_col.shape = cap
	body_col.position = Vector2(0.0, -12.0)
	add_child(body_col)

	# Connect attack area
	attack_area.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_z_physics(delta)

	match current_state:
		State.IDLE, State.MOVE:
			_process_movement(delta)
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_process_attack_state(delta)
		State.AIR_ATTACK:
			_process_air_attack_state(delta)
		State.GUARD:
			_process_guard_state(delta)
		State.PARRY_STUN, State.HURT:
			_process_knockback(delta)

	move_and_slide()


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


func _update_z_physics(delta: float) -> void:
	if not is_on_ground:
		z_velocity += z_gravity * delta
		z_height -= z_velocity * delta

		if z_height <= 0.0:
			# Touchdown on ground
			z_height = 0.0
			z_velocity = 0.0
			is_on_ground = true
			_on_ground_touchdown()

	# Apply visual Z-axis offset and scale dynamic shadow
	visual_root.position.y = -z_height

	if shadow != null:
		var factor := clampf(1.0 - (z_height / 350.0), 0.35, 1.0)
		shadow.scale = Vector2(factor, factor)
		shadow.default_color.a = 0.45 * factor


func _on_ground_touchdown() -> void:
	if current_state == State.AIR_ATTACK:
		_execute_ground_slam_impact()
		attack_cooldown = 0.0 # Instant air-to-ground combo chain
		_set_state(State.IDLE)


func _process_movement(delta: float) -> void:
	# Read 8-way directional inputs
	var input_vec := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vec.y += 1.0

	move_direction = input_vec.normalized()

	if move_direction != Vector2.ZERO:
		velocity = move_direction * move_speed
		facing_direction = move_direction
		facing_angle = facing_direction.angle()
		visual_root.rotation = 0.0 # Keep sprite upright

		# Horizontal flip for sprite
		if absf(facing_direction.x) > 0.1:
			player_sprite.scale.x = 1.0 if facing_direction.x > 0 else -1.0
			attack_area.scale.x = 1.0 if facing_direction.x > 0 else -1.0

		_set_state(State.MOVE)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 4800.0 * delta)
		if velocity.length() < 12.0:
			velocity = Vector2.ZERO
		_set_state(State.IDLE)

	# Action inputs
	if Input.is_action_just_pressed("jump") and is_on_ground:
		start_jump()
	elif Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0:
		start_attack()
	elif Input.is_action_just_pressed("dash") and is_on_ground:
		start_dash()
	elif Input.is_action_pressed("guard"):
		start_guard()


func start_jump() -> void:
	if not is_on_ground:
		return
	is_on_ground = false
	z_velocity = -jump_strength


func start_dash() -> void:
	dash_direction = move_direction if move_direction != Vector2.ZERO else facing_direction
	dash_time_remaining = DASH_DURATION
	is_invulnerable = true
	velocity = dash_direction * dash_speed
	_set_state(State.DASH)


func _process_dash(delta: float) -> void:
	dash_time_remaining -= delta
	velocity = dash_direction * dash_speed

	if dash_time_remaining <= 0.0:
		is_invulnerable = false
		_set_state(State.IDLE)


func start_attack() -> void:
	if not is_on_ground:
		# Aerial Down-Thrust / Air Attack
		_set_state(State.AIR_ATTACK)
		attack_duration_remaining = 0.35
		weapon_slash_arc.visible = true
		attack_area.monitoring = true
		return

	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.8
	is_attacking = true
	attack_cooldown = 0.22
	attack_duration_remaining = 0.2

	# Point attack area and slash arc in facing direction
	attack_area.rotation = facing_direction.angle()
	weapon_slash_arc.rotation = facing_direction.angle()
	weapon_slash_arc.visible = true
	attack_area.monitoring = true

	emit_signal("attack_swung", combo_step)
	_check_melee_hit()

	# Combo 3 Finisher: Fire 360-degree Sword Beam!
	if combo_step == 3:
		_fire_sword_beam()

	_set_state(State.ATTACK)


func _check_melee_hit() -> void:
	for body in attack_area.get_overlapping_bodies():
		_on_attack_body_entered(body)
	for area in attack_area.get_overlapping_areas():
		if area.is_in_group("enemy_hurtbox") and area.owner != null:
			_on_attack_body_entered(area.owner)


func _fire_sword_beam() -> void:
	var beam := QVSwordBeam.new()
	beam.initialize(global_position + Vector2(0, -18.0), facing_direction, false, 1 if counter_attack_buff else 0)
	get_parent().add_child(beam)


func _process_attack_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
	attack_duration_remaining -= delta

	if attack_duration_remaining <= 0.0:
		weapon_slash_arc.visible = false
		attack_area.monitoring = false
		is_attacking = false
		_set_state(State.IDLE)


func _process_air_attack_state(delta: float) -> void:
	# Keep moving forward in air while slashing
	velocity = facing_direction * (move_speed * 0.75)
	attack_duration_remaining -= delta
	if attack_duration_remaining <= 0.0:
		weapon_slash_arc.visible = false
		attack_area.monitoring = false


func _execute_ground_slam_impact() -> void:
	weapon_slash_arc.visible = false
	attack_area.monitoring = false
	# Radial seismic shockwave on ground impact
	var shock := Area2D.new()
	shock.collision_layer = 0
	shock.collision_mask = 2
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 80.0
	col.shape = circ
	shock.add_child(col)
	shock.global_position = global_position
	get_parent().add_child(shock)

	# Hit all nearby enemies
	await get_tree().process_frame
	for body in shock.get_overlapping_bodies():
		if body.has_method("receive_hit"):
			body.receive_hit(3, (body.global_position - global_position).normalized())
	shock.queue_free()


func start_guard() -> void:
	if not is_on_ground or is_guarding:
		return
	is_guarding = true
	guard_elapsed_time = 0.0
	guard_barrier.visible = true
	guard_barrier.rotation = facing_direction.angle()
	velocity = Vector2.ZERO
	_set_state(State.GUARD)


func release_guard() -> void:
	is_guarding = false
	guard_barrier.visible = false
	if current_state == State.GUARD:
		_set_state(State.IDLE)


func _process_guard_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	if not Input.is_action_pressed("guard"):
		release_guard()


func receive_incoming_attack(damage_amount: int, attacker: Node2D, attack_dir: Vector2) -> bool:
	if is_invulnerable:
		return false

	if is_guarding:
		# Check if attack is coming from front (facing direction angle difference < 90 deg)
		var angle_diff := absf(facing_direction.angle_to(-attack_dir))
		if angle_diff < PI * 0.55:
			# Guard successful!
			if guard_elapsed_time <= JUST_PARRY_WINDOW:
				# >>> JUST PARRY SUCCESS! <<<
				just_parry_succeeded.emit(attacker)
				counter_attack_buff = true
				counter_buff_timer = 2.0
				if attacker.has_method("apply_parry_stun"):
					attacker.apply_parry_stun(1.5)
				return false # 100% damage blocked
			else:
				# Normal Guard (80% damage reduced, min 1)
				current_hp -= maxi(1, int(damage_amount * 0.2))
				emit_signal("hp_changed", current_hp, max_hp)
				return false

	# Full Hit
	current_hp -= damage_amount
	emit_signal("hp_changed", current_hp, max_hp)
	if current_hp <= 0:
		_die()
	else:
		apply_contact_knockback(attack_dir * 320.0)
	return true


func apply_contact_knockback(knock_vel: Vector2) -> void:
	is_contact_knockback = true
	knockback_velocity = knock_vel
	knockback_duration = 0.25
	velocity = knockback_velocity
	_set_state(State.HURT)


func _process_knockback(delta: float) -> void:
	knockback_duration -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
	if knockback_duration <= 0.0:
		is_contact_knockback = false
		_set_state(State.IDLE)


func _on_attack_body_entered(body: Node2D) -> void:
	if body.has_method("receive_hit") and body != self:
		var dmg := 2
		if counter_attack_buff:
			dmg = 5 # 3x Counter strike
			counter_attack_buff = false
		body.receive_hit(dmg, facing_direction)


func _set_state(new_st: State) -> void:
	if current_state != new_st:
		var old_str: String = State.keys()[current_state]
		var new_str: String = State.keys()[new_st]
		current_state = new_st
		emit_signal("state_changed", old_str, new_str)


func _die() -> void:
	emit_signal("died")
	set_physics_process(false)
