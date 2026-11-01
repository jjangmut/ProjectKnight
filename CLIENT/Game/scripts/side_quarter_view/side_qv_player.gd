extends CharacterBody3D
class_name SideQVPlayer
## 사이드 쿼터뷰 2.5D 팔라딘 기사 (Side Quarter-View 2D Character in 3D World)
## - 2D 고해상도 스프라이트 (Sprite3D) 탑재 & 실시간 3D 그림자 투영
## - 사이드 쿼터뷰 벨트스크롤 3D 이동 (X: 좌우, Z: 안팎 깊이, Y: 점프)
## - 3단 콤보 검격 & 전방 관통 성광 찌르기 이펙트 & 3단 피니셔 검기 발출
## - 0.14초 저스트 패링 (Just Parry) 방패 바스티온 & 3배 카운터 어택
## - 피격 무적 시간(i-frame), 사망 상태 처리, 아레나 경계 추락 방지 완비

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
	HURT,
	DEAD
}

@export var move_speed_x: float = 7.5
@export var move_speed_z: float = 4.8
@export var dash_speed: float = 14.0
@export var jump_velocity: float = 6.8
@export var gravity: float = 18.0
@export var max_hp: int = 8
@export var current_hp: int = 8

var current_state: State = State.IDLE
var move_direction: Vector3 = Vector3.ZERO
var facing_dir_x: float = 1.0 # 1.0 = Right, -1.0 = Left

# Combat & Combo
var combo_step: int = 0
var combo_reset_timer: float = 0.0
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var attack_duration_remaining: float = 0.0
const ATTACK_TOTAL_DURATION: float = 0.20

# Guard & Just Parry
var is_guarding: bool = false
var guard_elapsed_time: float = 0.0
const JUST_PARRY_WINDOW: float = 0.14
var counter_attack_buff: bool = false
var counter_buff_timer: float = 0.0

# Dash & Invulnerability & Death
var dash_time_remaining: float = 0.0
const DASH_DURATION: float = 0.22
var is_invulnerable: bool = false
var invuln_timer: float = 0.0
const HIT_INVULN_DURATION: float = 0.65
var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.16
var is_dead: bool = false

# Arena Bounds Safety
var stage_min_x: float = -18.0
var stage_max_x: float = 18.0
var stage_min_z: float = -5.2
var stage_max_z: float = 5.2

# Procedural animation parameters
var anim_timer: float = 0.0

# Visual & Collision references
var sprite_3d: Sprite3D
var guard_barrier_3d: MeshInstance3D
var slash_visual_3d: MeshInstance3D
var attack_area_3d: Area3D

# Multi-frame Spritesheets for Detailed Character Actions (Symmetric Centered & Ground-Aligned 780x780 Cells)
const TexIdle = preload("res://assets/player_frames/idle_v1_aligned.png")     # 2x2 = 4 frames (780x780 cells, Pivot: 390,700)
const TexRun = preload("res://assets/player_frames/run_v2_aligned.png")      # 3x2 = 6 frames (780x780 cells, Pivot: 390,700)
const TexAttack = preload("res://assets/player_frames/attack_v1_aligned.png")# 2x2 = 4 frames (780x780 cells, Pivot: 390,700)
const TexJump = preload("res://assets/player_frames/jump_v1.png")            # 3x1 = 3 frames (780x780 cells, Pivot: 390,700)
const TexGuard = preload("res://assets/player_frames/guard_v1_aligned.png")  # 3x1 = 3 frames (780x780 cells, Pivot: 390,700)
const TexDodge = preload("res://assets/player_frames/dodge_v1.png")          # 2x2 = 4 frames (780x780 cells, Pivot: 390,700)
const TexHurt = preload("res://assets/player_frames/hurt_v1.png")            # 3x1 = 3 frames (780x780 cells, Pivot: 390,700)
const TexDeath = preload("res://assets/player_frames/death_v1.png")          # 2x2 = 4 frames (780x780 cells, Pivot: 390,700)

# Backward compatibility aliases
const PaladinTexture = TexIdle
const AttackSheetTexture = TexAttack
const SwordBeamScene = preload("res://scripts/side_quarter_view/side_qv_sword_beam.gd")


func _ready() -> void:
	collision_layer = 1 # Player Layer (1)
	collision_mask = 2 | 4 # Enemy Layer (2) & World Layer (4)
	add_to_group("player")

	_sync_stage_bounds()
	_build_components()
	emit_signal("hp_changed", current_hp, max_hp)


func _sync_stage_bounds() -> void:
	var p := get_parent()
	if p != null:
		if "arena_width" in p:
			var w: float = float(p.get("arena_width"))
			stage_min_x = -w * 0.5 + 1.0
			stage_max_x = w * 0.5 - 1.0
		if "arena_depth" in p:
			var d: float = float(p.get("arena_depth"))
			stage_min_z = -d * 0.5 + 0.8
			stage_max_z = d * 0.5 - 0.8


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite3D, calibrated ~1.77m human scale)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "CharacterSprite3D"
	sprite_3d.texture = TexIdle
	sprite_3d.hframes = 2
	sprite_3d.vframes = 2
	sprite_3d.frame = 0
	# Stand vertically, facing camera in isometric-side view
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.00282 # 780x780 cells with 600px body = ~1.77m height
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_3d.position = Vector3(0.0, 0.874, 0.0) # Ground foot alignment at Y=0.0
	add_child(sprite_3d)

	# 2. 3D Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	# 3. 3D Runic Shield Barrier (Just Parry visual)
	guard_barrier_3d = MeshInstance3D.new()
	guard_barrier_3d.name = "GuardBarrier3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.8
	guard_barrier_3d.mesh = torus

	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.8, 1.8, 0.85)
	bmat.emission_enabled = true
	bmat.emission = Color(0.2, 0.8, 2.0, 1.0)
	bmat.emission_energy_multiplier = 4.0
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_barrier_3d.material_override = bmat
	guard_barrier_3d.position = Vector3(0.45, 0.85, 0.0)
	guard_barrier_3d.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	guard_barrier_3d.visible = false
	add_child(guard_barrier_3d)

	# 4. 3D Melee Thrust VFX (Sleek Translucent Radiant Spear Streak)
	slash_visual_3d = MeshInstance3D.new()
	slash_visual_3d.name = "SlashVisual3D"
	var thrust_cyl := CylinderMesh.new()
	thrust_cyl.top_radius = 0.008
	thrust_cyl.bottom_radius = 0.085
	thrust_cyl.height = 1.75
	thrust_cyl.radial_segments = 8
	slash_visual_3d.mesh = thrust_cyl

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(3.2, 2.7, 1.4, 0.72) # Semi-transparent Golden-White Holy Thrust Streak
	smat.emission_enabled = true
	smat.emission = Color(3.2, 2.6, 1.2, 1.0)
	smat.emission_energy_multiplier = 4.2
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slash_visual_3d.material_override = smat
	slash_visual_3d.scale = Vector3(1.0, 1.0, 1.0)
	slash_visual_3d.position = Vector3(1.15, 0.92, 0.0)
	slash_visual_3d.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	slash_visual_3d.visible = false
	add_child(slash_visual_3d)

	# 5. Attack Hitbox Area3D (Keep monitoring active so overlaps are always fresh!)
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "AttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 2 # Enemy Layer (2)
	attack_area_3d.monitoring = true
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.8, 1.8)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 0.85, 0.0)
	attack_area_3d.position = Vector3(1.0, 0.0, 0.0)
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

	if is_dead or current_state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		move_and_slide()
		_clamp_arena_bounds()
		_update_character_animation(delta)
		return

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

	# Prevent pushing into monsters: firm stop upon body contact without bouncing
	_prevent_enemy_pushing()
	move_and_slide()
	_clamp_arena_bounds()
	_update_character_animation(delta)


func _clamp_arena_bounds() -> void:
	_sync_stage_bounds()
	global_position.x = clampf(global_position.x, stage_min_x, stage_max_x)
	global_position.z = clampf(global_position.z, stage_min_z, stage_max_z)
	if global_position.y < 0.0:
		global_position.y = 0.0
		if velocity.y < 0.0:
			velocity.y = 0.0


func _prevent_enemy_pushing() -> void:
	# Avoid sliding into or pushing monsters; halt clean on contact boundary
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
			continue
		var enemy_3d := enemy as Node3D
		var diff: Vector3 = enemy_3d.global_position - global_position
		diff.y = 0.0
		var dist: float = diff.length()
		var enemy_radius: float = 0.60 if enemy_3d.is_in_group("bosses") else 0.40
		var min_dist: float = 0.35 + enemy_radius + 0.06
		if dist < min_dist and dist > 0.001:
			var dir: Vector3 = diff / dist
			var vel_towards: float = velocity.dot(dir)
			if vel_towards > 0.0:
				velocity -= dir * vel_towards


func _update_timers(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0 and not is_attacking:
			combo_step = 0

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if invuln_timer > 0.0:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			invuln_timer = 0.0
			if sprite_3d != null and not is_dead:
				sprite_3d.modulate = Color.WHITE
		elif sprite_3d != null and not is_dead:
			# Subtle hit i-frame flicker
			var flash := 1.0 if int(invuln_timer * 24.0) % 2 == 0 else 0.55
			sprite_3d.modulate = Color(1.4, 0.85, 0.85, flash)

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
		# Flip attack and guard offsets
		attack_area_3d.position.x = 1.0 * facing_dir_x
		guard_barrier_3d.position.x = 0.6 * facing_dir_x
		slash_visual_3d.position.x = 1.15 * facing_dir_x

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
	if is_dead:
		return
	velocity.y = jump_velocity


func start_dash() -> void:
	if is_dead:
		return
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
	if is_dead:
		return
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.95
	is_attacking = true
	attack_cooldown = 0.22
	attack_duration_remaining = ATTACK_TOTAL_DURATION

	# Symmetric Aligned 2D Attack Animation (Starts at windup frame 0)
	sprite_3d.texture = TexAttack
	sprite_3d.hframes = 2
	sprite_3d.vframes = 2
	sprite_3d.pixel_size = 0.00282
	sprite_3d.frame = 0

	attack_area_3d.position.x = 1.0 * facing_dir_x
	slash_visual_3d.visible = true
	slash_visual_3d.position = Vector3(facing_dir_x * 1.15, 0.92, 0.0)
	slash_visual_3d.rotation_degrees = Vector3(0.0, 0.0, -90.0 * facing_dir_x)
	slash_visual_3d.scale = Vector3(0.35, 0.35, 0.35)
	var thrust_tween := create_tween()
	if thrust_tween:
		thrust_tween.tween_property(slash_visual_3d, "scale", Vector3(0.85, 1.25, 0.85), 0.06)
		thrust_tween.tween_property(slash_visual_3d, "scale", Vector3(0.15, 0.5, 0.15), 0.12)
	attack_area_3d.monitoring = true
	emit_signal("attack_swung", combo_step)

	# Responsive melee hit check (Direct spatial + Area3D hybrid check)
	_check_melee_hit()

	# Combo 3 Finisher: Fire glowing 3D piercing sword wave!
	if combo_step == 3:
		_fire_sword_beam()

	_set_state(State.ATTACK)


func _check_melee_hit() -> void:
	var hit_targets: Dictionary = {}

	# 1. Check Area3D overlapping bodies
	if attack_area_3d != null and attack_area_3d.monitoring:
		for body in attack_area_3d.get_overlapping_bodies():
			if body != null and is_instance_valid(body) and body != self and body.has_method("receive_hit"):
				hit_targets[body.get_instance_id()] = body

	# 2. Direct spatial reach check (Fixes Godot same-frame Area3D monitoring delay)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
			continue
		if not enemy.has_method("receive_hit"):
			continue
		var e3d := enemy as Node3D
		var diff: Vector3 = e3d.global_position - global_position
		var forward_dist: float = diff.x * facing_dir_x
		var z_dist: float = absf(diff.z)
		var y_dist: float = absf(diff.y)
		var extra_r: float = 0.55 if e3d.is_in_group("bosses") else 0.25
		if forward_dist >= -0.35 and forward_dist <= (2.35 + extra_r) and z_dist <= (1.35 + extra_r * 0.5) and y_dist <= 2.2:
			hit_targets[e3d.get_instance_id()] = e3d

	var dmg := 2
	if counter_attack_buff and not hit_targets.is_empty():
		dmg = 6 # 3x Counter strike
		counter_attack_buff = false

	for id in hit_targets.keys():
		var target_node: Node = hit_targets[id]
		if is_instance_valid(target_node):
			target_node.receive_hit(dmg, Vector3(facing_dir_x, 0, 0))


func _fire_sword_beam() -> void:
	var beam := SwordBeamScene.new()
	beam.name = "SideQVSwordBeam_Finisher"
	get_parent().add_child(beam)
	var shoot_dir := Vector3(facing_dir_x, 0, 0)
	beam.initialize(global_position + Vector3(facing_dir_x * 0.9, 1.1, 0.0), shoot_dir, 2 if counter_attack_buff else 0)
	sword_beam_fired.emit(beam)


func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	attack_duration_remaining -= delta

	if attack_duration_remaining <= 0.0:
		slash_visual_3d.visible = false
		is_attacking = false
		_set_state(State.IDLE)


func start_guard() -> void:
	if is_guarding or is_dead:
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


func _process_guard_state(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not Input.is_action_pressed("guard"):
		release_guard()


func receive_incoming_attack(amount: int, attacker: Node, _attack_dir: Vector3) -> bool:
	if is_dead or current_hp <= 0:
		return false
	if is_invulnerable or invuln_timer > 0.0:
		return false

	if is_guarding:
		if guard_elapsed_time <= JUST_PARRY_WINDOW:
			# Just Parry! 100% damage blocked, attacker stunned, 3x counter buff!
			counter_attack_buff = true
			counter_buff_timer = 3.5
			invuln_timer = 0.35
			emit_signal("just_parry_succeeded", attacker)
			if attacker != null and attacker.has_method("apply_parry_stun"):
				attacker.apply_parry_stun(2.0)
			_trigger_parry_flash()
			return false
		else:
			# Normal Guard: 50% damage reduction, solid halt + brief i-frame
			var reduced := maxi(1, int(amount * 0.5))
			current_hp = maxi(0, current_hp - reduced)
			invuln_timer = HIT_INVULN_DURATION * 0.8
			emit_signal("hp_changed", current_hp, max_hp)
			velocity = Vector3.ZERO
			if current_hp <= 0:
				_enter_death_state()
			return true

	# Direct Hit: Damage taken, firm stop without launch bounce, grant hit i-frame
	current_hp = maxi(0, current_hp - amount)
	invuln_timer = HIT_INVULN_DURATION
	hurt_timer = HURT_DURATION
	emit_signal("hp_changed", current_hp, max_hp)
	velocity = Vector3.ZERO

	if current_hp <= 0:
		_enter_death_state()
	else:
		_set_state(State.HURT)
	return true


func _enter_death_state() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_guarding = false
	slash_visual_3d.visible = false
	guard_barrier_3d.visible = false
	velocity = Vector3.ZERO
	_set_state(State.DEAD)
	if sprite_3d != null:
		sprite_3d.modulate = Color.WHITE
		sprite_3d.texture = TexDeath
		sprite_3d.hframes = 2
		sprite_3d.vframes = 2
		sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 3
	emit_signal("died")


func _trigger_parry_flash() -> void:
	var tween := create_tween()
	if tween:
		guard_barrier_3d.scale = Vector3(1.6, 1.6, 1.6)
		tween.tween_property(guard_barrier_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.18)


func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_set_state(State.IDLE)


func _update_character_animation(delta: float) -> void:
	anim_timer += delta

	# Head-on mutual facing alignment
	sprite_3d.flip_h = (facing_dir_x < 0.0)

	# 0. Dead State
	if is_dead or current_state == State.DEAD:
		if sprite_3d.texture != TexDeath:
			sprite_3d.texture = TexDeath
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 3
		return

	# 1. Airborne Jump Action
	if not is_on_floor() and not is_attacking:
		if sprite_3d.texture != TexJump:
			sprite_3d.texture = TexJump
			sprite_3d.hframes = 3
			sprite_3d.vframes = 1
			sprite_3d.pixel_size = 0.00282
		if velocity.y > 1.2:
			sprite_3d.frame = 0 # Ascent
		elif absf(velocity.y) <= 1.2:
			sprite_3d.frame = 1 # Apex float
		else:
			sprite_3d.frame = 2 # Descent
		return

	# 2. Attack Action (Multi-frame sequence across attack duration: 0 -> 1 -> 2 -> 3)
	if is_attacking:
		if sprite_3d.texture != TexAttack:
			sprite_3d.texture = TexAttack
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		var progress: float = clampf(1.0 - (attack_duration_remaining / ATTACK_TOTAL_DURATION), 0.0, 0.999)
		sprite_3d.frame = clampi(int(progress * 4.0), 0, 3)
		return

	# 3. Guard / Parry Stance Action
	if is_guarding:
		if sprite_3d.texture != TexGuard:
			sprite_3d.texture = TexGuard
			sprite_3d.hframes = 3
			sprite_3d.vframes = 1
			sprite_3d.pixel_size = 0.00282
		if counter_attack_buff:
			sprite_3d.frame = 2 # Parry counter spark
		elif guard_elapsed_time < 0.06:
			sprite_3d.frame = 0 # Shield raise
		else:
			sprite_3d.frame = 1 # Fortified fortress brace
		return

	# 4. Dodge Dash Action
	if current_state == State.DASH:
		if sprite_3d.texture != TexDodge:
			sprite_3d.texture = TexDodge
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		var dash_progress := 1.0 - (dash_time_remaining / DASH_DURATION)
		sprite_3d.frame = clampi(int(dash_progress * 4.0), 0, 3)
		return

	# 5. Hurt Action
	if current_state == State.HURT:
		if sprite_3d.texture != TexHurt:
			sprite_3d.texture = TexHurt
			sprite_3d.hframes = 3
			sprite_3d.vframes = 1
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 1
		return

	# 6. Run / Sprint Action (6-frame detailed loop, Unified 780x780 Aligned)
	if current_state == State.MOVE and is_on_floor():
		if sprite_3d.texture != TexRun:
			sprite_3d.texture = TexRun
			sprite_3d.hframes = 3
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = int(anim_timer * 10.0) % 6
		return

	# 7. Idle Stance (4-frame detailed breathing loop)
	if sprite_3d.texture != TexIdle:
		sprite_3d.texture = TexIdle
		sprite_3d.hframes = 2
		sprite_3d.vframes = 2
		sprite_3d.pixel_size = 0.00282
	sprite_3d.frame = int(anim_timer * 4.0) % 4


func _set_state(new_state: State) -> void:
	if is_dead and new_state != State.DEAD:
		return
	current_state = new_state
