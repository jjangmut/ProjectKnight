extends CharacterBody2D

@export_category("Movement")
const BASE_MOVE_SPEED: float = 230.0
@export var move_speed: float = BASE_MOVE_SPEED
var speed_level: int = 0
var attack_speed_level: int = 0
var attack_speed_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.65

@export_category("Jump")
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0
@export var jump_buffer: float = 0.14
@export var coyote_time: float = 0.12

@export_category("Attack")
@export var attack_duration: float = 0.18
@export var attack_cooldown: float = 0.24
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

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

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

# Combat Deepening (DEC-008, TASK-CL-012)
var combo_step: int = 0
var _combo_window_remaining: float = 0.0
const COMBO_WINDOW_MAX: float = 0.55
var counter_window: float = 0.18
var _counter_window_remaining: float = 0.0
var is_counter_attacking: bool = false
var is_down_thrusting: bool = false
var current_attack_damage: int = 1

# Economy & Reward (TASK-CL-019)
var soul_shards: int = 0
signal soul_shards_changed(new_count: int)
signal hp_changed(new_hp: int)

# Dash & Air Dash System (Milestone 4, TASK-CL-023)
signal dash_performed(is_air_dash: bool)
var has_shadow_dash: bool = true
var is_dashing: bool = false
var is_invulnerable: bool = false
var dash_speed: float = 540.0
var dash_duration: float = 0.22
var dash_cooldown: float = 0.60
var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _can_air_dash: bool = true
var _dash_ghost_timer: float = 0.0



func _ready() -> void:
	z_index = 10
	add_to_group("player")
	collision_layer = 8 # Player Body Layer
	collision_mask = 1 | 16  # Environment Layer (1) + Enemy Body Layer (16) -> cannot walk through enemies
	_base_visual_color = body_visual.color
	current_hp = max_hp
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_area.area_entered.connect(_on_attack_area_entered)
	_update_attack_geometry()
	_set_attack_active(false)

	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam != null:
		GameFeelManager.register_active_camera(cam)

	platform_on_leave = 2 # PLATFORM_ON_LEAVE_DO_NOT_ADD_VELOCITY
	platform_floor_layers = 0




func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_attack_state(delta)
	_update_guard_state(delta)
	_update_hurt_flash(delta)
	_update_combat_deepening_state(delta)
	_update_dash_state(delta)

	# Dash trigger (Shift / ui_cancel / dash)
	var dash_pressed := (InputMap.has_action("dash") and Input.is_action_just_pressed("dash")) or Input.is_action_just_pressed("ui_cancel")
	if dash_pressed and has_shadow_dash and _dash_cooldown_remaining <= 0.0 and not is_guarding and not is_dashing:
		dash()

	if is_dashing:
		move_and_slide()
		return

	var move_direction := Input.get_axis("move_left", "move_right")
	if not is_guarding and _guard_recovery_remaining <= 0.0 and not is_zero_approx(move_direction):
		facing_direction = signf(move_direction)
		$FacingMark.scale.x = facing_direction
		_update_attack_geometry()

	# Counter attack trigger: if counter window is active and attack is pressed during or right after guard
	if _counter_window_remaining > 0.0 and Input.is_action_just_pressed("attack"):
		_start_counter_attack()
	# Held guard starts at legal moment; never cancels an attack.
	elif Input.is_action_pressed("guard") and _can_start_guard():
		_start_guard()

	# Down thrust trigger: in air + down + attack
	var is_down_held := Input.is_action_pressed("ui_down") or (InputMap.has_action("move_down") and Input.is_action_pressed("move_down"))
	if not is_on_floor() and is_down_held and Input.is_action_just_pressed("attack") and not is_attacking:
		_start_down_thrust()
	elif Input.is_action_pressed("attack") and not is_attacking and not is_guarding and _guard_recovery_remaining <= 0.0 and _cooldown_time_remaining <= 0.0:
		_start_attack()

	if not is_on_floor():
		velocity.y += gravity * delta
		if is_down_thrusting:
			velocity.y = maxf(velocity.y, 420.0)
	else:
		if is_down_thrusting:
			_end_down_thrust()

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
		if is_down_thrusting:
			_end_down_thrust()

	# One-way platform drop down trigger: on floor + move_down
	var is_down_just_pressed := (InputMap.has_action("move_down") and Input.is_action_just_pressed("move_down")) or Input.is_action_just_pressed("ui_down")
	if is_on_floor() and is_down_just_pressed and not is_guarding:
		_try_drop_down_platform()

	# Pre-physics NaN & velocity sanity safeguard
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not position.is_finite():
		position = Vector2(500.0, 590.0)

	move_and_slide()

	# Post-physics NaN & world bounds rescue safeguard
	if not position.is_finite():
		position = Vector2(500.0, 590.0)
		velocity = Vector2.ZERO
	if not velocity.is_finite():
		velocity = Vector2.ZERO

	# Fall rescue fail-safe (prevents clipping through ground into bottomless void)
	if position.y > 640.0:
		position.y = 590.0
		velocity.y = 0.0
	elif position.y < -200.0:
		position.y = -200.0
		velocity.y = 0.0



func _try_drop_down_platform() -> void:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		var is_one_way := false
		for child in collider.get_children():
			if child is CollisionShape2D and child.one_way_collision:
				is_one_way = true
				break
		if is_one_way:
			var parent: Node = collider.get_parent()
			if parent != null and (parent.is_in_group("enemy") or parent.is_in_group("boss") or parent is CharacterBody2D):
				# Safe dismount off monster shoulders: lateral slide clearing monster width (22px) cleanly onto ground
				position.x += facing_direction * 28.0
				velocity.x = facing_direction * 80.0
				velocity.y = 100.0
			else:
				position.y += 12.0
				velocity.y = 120.0
			break




func _start_attack() -> void:
	if is_dead or is_guarding or _guard_recovery_remaining > 0.0:
		return
	is_attacking = true
	attack_count += 1

	# Combo step progression
	if _combo_window_remaining > 0.0:
		combo_step = (combo_step % 3) + 1
	else:
		combo_step = 1

	match combo_step:
		1:
			_attack_time_remaining = 0.18 / attack_speed_multiplier
			_cooldown_time_remaining = 0.22 / attack_speed_multiplier
			current_attack_damage = 1
			AudioManager.play("slash_1", global_position)
		2:
			_attack_time_remaining = 0.20 / attack_speed_multiplier
			_cooldown_time_remaining = 0.24 / attack_speed_multiplier
			current_attack_damage = 1
			AudioManager.play("slash_2", global_position)
		3:
			_attack_time_remaining = 0.28 / attack_speed_multiplier
			_cooldown_time_remaining = 0.38 / attack_speed_multiplier
			current_attack_damage = 2
			AudioManager.play("smash_3", global_position)

	_combo_window_remaining = COMBO_WINDOW_MAX
	_hit_targets.clear()
	_update_attack_geometry()
	_set_attack_active(true)


func _start_counter_attack() -> void:
	if is_dead:
		return
	_end_guard()
	_counter_window_remaining = 0.0
	is_counter_attacking = true
	is_attacking = true
	attack_count += 1
	combo_step = 3
	_attack_time_remaining = 0.20 / attack_speed_multiplier
	_cooldown_time_remaining = 0.22 / attack_speed_multiplier
	current_attack_damage = 2
	AudioManager.play("counter_hit", global_position)
	_hit_targets.clear()
	_update_attack_geometry()
	_set_attack_active(true)
	_refresh_body_color()


func _start_down_thrust() -> void:
	if is_dead or is_on_floor():
		return
	is_down_thrusting = true
	is_attacking = true
	current_attack_damage = 1
	_attack_time_remaining = 0.50
	_hit_targets.clear()
	_update_attack_geometry()
	_set_attack_active(true)


func _end_down_thrust() -> void:
	is_down_thrusting = false
	if is_attacking and _attack_time_remaining > 0.0:
		_end_attack()


func _end_attack() -> void:
	is_attacking = false
	is_counter_attacking = false
	_set_attack_active(false)
	_refresh_body_color()


func _update_attack_state(delta: float) -> void:
	_cooldown_time_remaining = maxf(_cooldown_time_remaining - delta, 0.0)
	if is_dead or not is_attacking:
		return

	_attack_time_remaining -= delta
	if _attack_time_remaining <= 0.0:
		_end_attack()


func _update_combat_deepening_state(delta: float) -> void:
	_combo_window_remaining = maxf(_combo_window_remaining - delta, 0.0)
	_counter_window_remaining = maxf(_counter_window_remaining - delta, 0.0)


func _set_attack_active(active: bool) -> void:
	attack_visual.visible = active
	attack_collision.set_deferred("disabled", not active)


func _update_attack_geometry() -> void:
	if is_down_thrusting:
		attack_area.position = Vector2(0, 32.0)
		var attack_shape := attack_collision.shape as RectangleShape2D
		attack_shape.size = Vector2(44.0, 36.0)
		attack_visual.polygon = PackedVector2Array([
			Vector2(-22.0, -18.0),
			Vector2(22.0, -18.0),
			Vector2(0.0, 18.0)
		])
		attack_visual.color = Color(0.9, 0.8, 0.2)
		return

	var effective_range := attack_range
	if is_counter_attacking:
		effective_range = maxf(attack_range, 85.0)
	elif combo_step == 3:
		effective_range = maxf(attack_range, 88.0)
	elif combo_step == 1:
		effective_range = minf(attack_range, 68.0)

	# Position starts from body center forward to cover point-blank / overlapping targets
	attack_area.position.x = facing_direction * (effective_range * 0.5)
	attack_area.position.y = 0.0
	var attack_shape := attack_collision.shape as RectangleShape2D
	attack_shape.size = Vector2(effective_range, 52.0)
	var half_range := effective_range * 0.5
	attack_visual.polygon = PackedVector2Array([
		Vector2(-half_range, -26.0),
		Vector2(half_range, -18.0),
		Vector2(half_range, 18.0),
		Vector2(-half_range, 26.0),
	])
	if is_counter_attacking:
		attack_visual.color = Color(0.2, 0.9, 1.0, 0.9)
	elif combo_step == 3:
		attack_visual.color = Color(1.0, 0.75, 0.2, 0.9)
	else:
		attack_visual.color = Color(1.0, 0.9, 0.6, 0.7)


func _on_attack_area_entered(area: Area2D) -> void:
	if is_dead or not is_attacking:
		return

	var target := area.get_parent()
	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true

	var is_crit := is_counter_attacking or combo_step == 3
	var hit_pos: Vector2 = (global_position + target.global_position) * 0.5

	# 1. Auditory Feedback: Heavy physical hit impact SFX on target contact
	if is_counter_attacking:
		AudioManager.play("counter_impact", hit_pos)
	elif combo_step == 3:
		AudioManager.play("hit_heavy", hit_pos)
	elif is_down_thrusting:
		AudioManager.play("pogo_hit", hit_pos)
	else:
		AudioManager.play("hit_slash", hit_pos)

	# 2. Visual Feedback: Slash sparks & cross-burst VFX
	var parent_node := get_parent() as Node2D if get_parent() is Node2D else self
	GameFeelManager.slash_spark(parent_node, hit_pos, facing_direction, is_crit)

	# 3. Hit Feel (Juice): Subdued comfortable Camera Shake & Hit Stop
	if is_counter_attacking:
		GameFeelManager.trigger_hit_stop(0.12, 0.0)
		GameFeelManager.shake(0.50)
	elif combo_step == 3:
		GameFeelManager.trigger_hit_stop(0.09, 0.0)
		GameFeelManager.shake(0.35)
	elif is_down_thrusting:
		GameFeelManager.trigger_hit_stop(0.07, 0.02)
		GameFeelManager.shake(0.25)
	else:
		GameFeelManager.trigger_hit_stop(0.05, 0.03)
		GameFeelManager.shake(0.18)

	# 4. Floating damage indicator for regular enemies (Boss handles its own)
	if not target.is_in_group("boss") and get_parent() is Node2D:
		var text := "%d! CRIT" % current_attack_damage if is_crit else str(current_attack_damage)
		var col := Color(0.3, 0.95, 1.0) if is_counter_attacking else Color(1.0, 0.9, 0.4)
		GameFeelManager.damage_popup(parent_node, target.global_position + Vector2(randf_range(-10, 10), -35), text, col, is_crit)

	# 5. Down thrust pogo bounce
	if is_down_thrusting:
		velocity.y = -480.0
		AudioManager.play("pogo_bounce", global_position)
		_end_down_thrust()

	# 6. Counter attack stun
	if is_counter_attacking:
		target.set_meta("counter_stunned", 0.45)

	# 7. Physical knockback recoil on enemies (amplified for impactful pushback)
	if "velocity" in target:
		var is_boss: bool = target.is_in_group("boss")
		var is_above_target: bool = global_position.y < (target.global_position.y - 12.0)
		if is_counter_attacking:
			target.velocity.x = facing_direction * (220.0 if is_boss else 520.0)
			if not is_boss:
				target.velocity.y = 80.0 if is_above_target else -260.0
		elif combo_step == 3:
			target.velocity.x = facing_direction * (180.0 if is_boss else 420.0)
			if not is_boss:
				target.velocity.y = 60.0 if is_above_target else -220.0
		elif is_down_thrusting:
			if not is_boss:
				target.velocity.y = 160.0
		else:
			target.velocity.x = facing_direction * (100.0 if is_boss else 220.0)
			if not is_boss:
				target.velocity.y = 40.0 if is_above_target else -80.0

	# 8. Deal damage
	if target.has_method("receive_hit"):
		for _i in range(current_attack_damage):
			if is_instance_valid(target) and not target.is_queued_for_deletion():
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
	if is_dead or is_dashing or is_invulnerable:
		return false
	var in_front := (source_position.x - global_position.x) * _guard_direction > 0.0
	if blockable and is_guarding and is_on_floor() and in_front:
		guard_block_count += 1
		_guard_block_flash_remaining = 0.14
		_counter_window_remaining = counter_window
		AudioManager.play("guard_clang", global_position)
		if get_parent() is Node2D:
			GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -35), "BLOCKED!", Color(0.85, 0.9, 0.95), false)
		GameFeelManager.shake(0.15)
		return true
	receive_hit()
	return false


func receive_hit() -> void:
	if is_dead or is_dashing or is_invulnerable:
		return
	var hit_time_usec := Time.get_ticks_usec()
	if hit_time_usec < _hit_invulnerable_until_usec:
		return
	_end_guard()
	if is_down_thrusting:
		_end_down_thrust()
	hit_count += 1
	current_hp = maxi(current_hp - 1, 0)
	AudioManager.play("player_hurt", global_position)

	# Hurt juice: Hit stop & trauma
	GameFeelManager.trigger_hit_stop(0.07, 0.05)
	GameFeelManager.shake(0.35)
	if get_parent() is Node2D:
		GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -35), "-1 HP", Color(1.0, 0.25, 0.2), true)

	if current_hp == 0:
		_die()
		return
	_hit_invulnerable_until_usec = hit_time_usec + HIT_INVULNERABILITY_USEC
	_hurt_flash_remaining = 0.12
	_refresh_body_color()


func on_shard_collected(_value: int) -> void:
	soul_shards_changed.emit(soul_shards)



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


func revive(heal_to_full: bool = true) -> void:
	is_dead = false
	current_hp = max_hp if heal_to_full else 1
	_hurt_flash_remaining = 0.0
	_hit_invulnerable_until_usec = Time.get_ticks_usec() + 2500000 # 2.5s golden I-Frame
	_refresh_body_color()
	velocity = Vector2.ZERO
	hp_changed.emit(current_hp)


func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash_remaining <= 0.0:
		return
	_hurt_flash_remaining = maxf(_hurt_flash_remaining - delta, 0.0)
	if _hurt_flash_remaining <= 0.0:
		_refresh_body_color()


func _refresh_body_color() -> void:
	if _hurt_flash_remaining > 0.0:
		body_visual.color = Color.WHITE
	elif is_counter_attacking or _counter_window_remaining > 0.0:
		body_visual.color = Color(0.3, 0.9, 1.0, 1.0) # Cyan counter glow
	elif is_guarding:
		body_visual.color = Color(0.7, 0.85, 1.0, 1.0)
	elif is_dashing:
		body_visual.color = Color(0.4, 0.9, 1.0, 0.9)
	else:
		body_visual.color = _base_visual_color


func dash() -> bool:
	if is_dead or is_dashing or not has_shadow_dash or _dash_cooldown_remaining > 0.0 or is_guarding:
		return false
	if not is_on_floor() and not _can_air_dash:
		return false

	var is_air := not is_on_floor()
	if is_air:
		_can_air_dash = false
	else:
		_can_air_dash = true

	is_dashing = true
	is_invulnerable = true
	_dash_time_remaining = dash_duration
	_dash_cooldown_remaining = dash_cooldown
	_dash_ghost_timer = 0.0

	velocity.x = facing_direction * dash_speed
	velocity.y = 0.0

	if is_down_thrusting:
		_end_down_thrust()
	if is_attacking:
		_end_attack()

	AudioManager.play("pogo_bounce", global_position)
	GameFeelManager.shake(0.12)
	_spawn_ghost_trail()
	_refresh_body_color()
	dash_performed.emit(is_air)
	return true


func _update_dash_state(delta: float) -> void:
	_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
	if is_on_floor():
		_can_air_dash = true

	if not is_dashing:
		return

	_dash_time_remaining -= delta
	_dash_ghost_timer -= delta
	if _dash_ghost_timer <= 0.0:
		_spawn_ghost_trail()
		_dash_ghost_timer = 0.05

	velocity.x = facing_direction * dash_speed
	velocity.y = 0.0

	if _dash_time_remaining <= 0.0:
		_end_dash()


func _end_dash() -> void:
	is_dashing = false
	is_invulnerable = false
	_dash_time_remaining = 0.0
	velocity.x = facing_direction * (move_speed * 0.5)
	_refresh_body_color()


func _spawn_ghost_trail() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or not is_instance_valid(body_visual):
		return
	var ghost := Polygon2D.new()
	ghost.polygon = body_visual.polygon
	ghost.position = global_position
	ghost.scale = $FacingMark.scale if has_node("FacingMark") else Vector2.ONE
	ghost.color = Color(0.25, 0.85, 1.0, 0.45)
	ghost.z_index = z_index - 1
	parent.add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


func update_stats_from_upgrades(spd_lvl: int, atk_spd_lvl: int) -> void:
	speed_level = spd_lvl
	attack_speed_level = atk_spd_lvl
	move_speed = BASE_MOVE_SPEED + float(speed_level) * 25.0
	attack_speed_multiplier = 1.0 + float(attack_speed_level) * 0.15


