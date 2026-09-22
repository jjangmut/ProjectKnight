extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

@export_category("Movement")
@export var move_speed: float = 130.0
@export var patrol_distance: float = 240.0
@export var detection_range: float = 560.0
@export var gravity: float = 1400.0
@export_category("Attack")
@export var attack_range: float = 90.0
@export var attack_windup: float = 0.5
@export var attack_active: float = 0.15
@export var attack_cooldown: float = 1.0
@export_category("Health")
@export var max_hp: int = 3
@export var hit_stun_duration: float = 0.20

@onready var visual: Polygon2D = $Visual
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var state: State = State.PATROL
var attack_phase: AttackPhase = AttackPhase.RECOVERY
var current_hp: int
var attack_count: int = 0
var is_attack_active: bool = false
var is_counter_stunned: bool = false
var is_stunned: bool:
	get:
		return _hit_stun_remaining > 0.0
var _hit_stun_remaining: float = 0.0
var _player: CharacterBody2D
var _origin_x: float
var _patrol_direction: float = -1.0
var _attack_direction: float = -1.0
var _phase_time_remaining: float = 0.0
var _hit_player_ids: Dictionary = {}
var _base_color := Color(0.92, 0.3, 0.28, 1)
var _hit_flash_remaining: float = 0.0

# Smart vertical traversal and autonomous combat jump
var _drop_down_timer: float = 0.0
var _stuck_timer: float = 0.0
var _jump_cooldown: float = 1.0

# High-resolution motion sprite setup
var enemy_sprite: Sprite2D = null
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _walk_anim_timer: float = 0.0
var _facing_right: bool = false
var _base_scale: float = 0.13


func _ready() -> void:
	z_index = 5
	collision_layer = 16 # Enemy Body Layer
	collision_mask = 1  # Environment / Terrain Layer only (no solid collision with player body)
	current_hp = max_hp
	_origin_x = position.x
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_area.area_entered.connect(_on_attack_area_entered)
	attack_collision.disabled = true
	visual.color = _base_color
	visual.visible = false

	# Dynamic Top Platform: allows player to stand and ride on top of monster
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(44.0, 10.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -30.0)
	top_shape.one_way_collision = true
	top_platform.add_child(top_shape)
	add_child(top_platform)
	add_collision_exception_with(top_platform)
	top_platform.add_collision_exception_with(self)

	_build_enemy_sprite()


func _build_enemy_sprite() -> void:
	if enemy_sprite != null:
		enemy_sprite.queue_free()
		enemy_sprite = null
	_sprite_frames.clear()
	_sprite_pivots.clear()

	var variant: String = str(get_meta("art_variant", "melee"))
	var file_path := "res://assets/enemy_frames/melee_v1.png"
	var regions: Array[Rect2] = [
		Rect2(0, 0, 512, 500), Rect2(512, 0, 550, 500), Rect2(1062, 0, 474, 500),
		Rect2(0, 500, 512, 524), Rect2(512, 500, 585, 524), Rect2(1097, 500, 439, 524)
	]
	var pivots: Array[Vector2] = [
		Vector2(225, 484), Vector2(250, 486), Vector2(240, 486),
		Vector2(240, 483), Vector2(240, 480), Vector2(210, 480)
	]
	var sprite_y := 28.0
	_base_scale = 0.13

	if variant == "beast":
		file_path = "res://assets/enemy_frames/beast_v1.png"
		regions = [
			Rect2(0, 0, 512, 500), Rect2(512, 0, 512, 500), Rect2(1024, 0, 512, 500),
			Rect2(0, 500, 512, 524), Rect2(512, 500, 512, 524), Rect2(1024, 500, 512, 524)
		]
		pivots = [
			Vector2(255, 433), Vector2(275, 432), Vector2(295, 434),
			Vector2(260, 381), Vector2(285, 380), Vector2(290, 383)
		]
		_base_scale = 0.135
		sprite_y = 24.0
	elif variant == "golem":
		file_path = "res://assets/enemy_frames/golem_v1.png"
		regions = [
			Rect2(0, 0, 550, 495), Rect2(550, 0, 510, 495), Rect2(1060, 0, 476, 495),
			Rect2(0, 495, 535, 529), Rect2(535, 495, 585, 529), Rect2(1120, 495, 416, 529)
		]
		pivots = [
			Vector2(275, 481), Vector2(245, 491), Vector2(235, 492),
			Vector2(260, 502), Vector2(250, 500), Vector2(225, 502)
		]
		_base_scale = 0.15
		sprite_y = 30.0

	if ResourceLoader.exists(file_path):
		var sheet := load(file_path) as Texture2D
		if sheet != null:
			for i in range(6):
				var frame := AtlasTexture.new()
				frame.atlas = sheet
				frame.region = regions[i]
				_sprite_frames.append(frame)
				_sprite_pivots.append(pivots[i])

	enemy_sprite = Sprite2D.new()
	enemy_sprite.name = "EnemySprite"
	enemy_sprite.centered = false
	enemy_sprite.scale = Vector2.ONE * _base_scale
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	enemy_sprite.position = Vector2(0, sprite_y)

	if not _sprite_frames.is_empty():
		enemy_sprite.texture = _sprite_frames[0]
		enemy_sprite.offset = -_sprite_pivots[0]

	add_child(enemy_sprite)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	_update_hit_flash(delta)

	# Drop-down cooldown timer handling
	if _drop_down_timer > 0.0:
		_drop_down_timer -= delta

	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta

	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not position.is_finite():
		position = Vector2(500.0, 590.0)

	if _hit_stun_remaining > 0.0:
		_hit_stun_remaining = maxf(_hit_stun_remaining - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		if _hit_stun_remaining <= 0.0:
			is_counter_stunned = false
			_restore_state_color()
		return

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

	if not velocity.is_finite():
		velocity = Vector2.ZERO
	move_and_slide()
	if not position.is_finite():
		position = Vector2(500.0, 590.0)
		velocity = Vector2.ZERO

	_update_enemy_sprite(delta)
	if state == State.PATROL and is_on_wall():
		_patrol_direction *= -1.0


func _update_enemy_sprite(delta: float) -> void:
	if enemy_sprite == null:
		return

	# Orientation
	if velocity.x > 5.0:
		_facing_right = true
	elif velocity.x < -5.0:
		_facing_right = false
	enemy_sprite.scale.x = _base_scale * (1.0 if _facing_right else -1.0)

	if not _sprite_frames.is_empty():
		var frame_idx := 0
		if is_stunned or is_counter_stunned:
			frame_idx = 5
		elif state == State.ATTACK:
			match attack_phase:
				AttackPhase.WINDUP:
					frame_idx = 3
				AttackPhase.ACTIVE:
					frame_idx = 4
				AttackPhase.RECOVERY:
					frame_idx = 5
		elif absf(velocity.x) > 5.0:
			_walk_anim_timer += delta * 6.5
			frame_idx = 1 if int(_walk_anim_timer) % 2 == 0 else 2
		else:
			frame_idx = 0

		if frame_idx < _sprite_frames.size():
			enemy_sprite.texture = _sprite_frames[frame_idx]
			if frame_idx < _sprite_pivots.size():
				enemy_sprite.offset = -_sprite_pivots[frame_idx]

	if _hit_flash_remaining > 0.0:
		enemy_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	elif is_counter_stunned:
		enemy_sprite.modulate = Color(0.55, 0.85, 1.0, 1.0)
	elif state == State.ATTACK and attack_phase == AttackPhase.WINDUP:
		var pulse := (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		enemy_sprite.modulate = Color(1.0, 0.9, 0.4).lerp(Color(1.4, 0.3, 0.1), pulse)
	else:
		enemy_sprite.modulate = Color.WHITE

	# Safeguard: Left world boundary lock (cannot fall outside stage start)
	if position.x < 40.0:
		position.x = 40.0
		if velocity.x < 0.0:
			velocity.x = 0.0

	# Safeguard: Fall rescue fail-safe (if clipped below ground, instantly rescue to floor)
	if position.y > 640.0:
		position.y = 590.0
		velocity.y = 0.0
		_drop_down_timer = 0.0


func _perform_drop_down() -> void:
	# Main ground floor safety: Never drop down through solid ground floor (y >= 560.0)
	if position.y >= 560.0 or _drop_down_timer > 0.0:
		return
	var is_one_way := false
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		for child in collider.get_children():
			if child is CollisionShape2D and child.one_way_collision:
				is_one_way = true
				break
		if is_one_way:
			break
	if is_one_way or position.y < 550.0:
		position.y += 12.0
		velocity.y = 140.0
		_drop_down_timer = 0.35


func _update_patrol() -> void:
	var distance_x := absf(_player.position.x - position.x)
	var vertical_distance := _player.position.y - position.y
	var dist_2d := global_position.distance_to(_player.global_position)

	# Enhanced detection: Upper floor monsters actively detect player below and transition to CHASE
	if dist_2d <= detection_range or (distance_x <= detection_range * 0.9 and absf(vertical_distance) < 360.0):
		state = State.CHASE
		_stuck_timer = 0.0
		return

	# Ledge/bumper safeguard in patrol: if blocked by obstacles or another monster, reverse direction
	if absf(velocity.x) < 15.0 and is_on_floor():
		_stuck_timer += get_physics_process_delta_time()
		if _stuck_timer > 0.3:
			_stuck_timer = 0.0
			_patrol_direction *= -1.0
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - get_physics_process_delta_time())

	if position.x <= _origin_x - patrol_distance:
		_patrol_direction = 1.0
	elif position.x >= _origin_x + patrol_distance:
		_patrol_direction = -1.0
	velocity.x = _patrol_direction * move_speed * 0.85


func _update_chase() -> void:
	var horizontal_distance := _player.position.x - position.x
	var vertical_distance := _player.position.y - position.y
	var dist_2d := global_position.distance_to(_player.global_position)
	if dist_2d > detection_range * 1.5 and absf(horizontal_distance) > detection_range * 1.3:
		state = State.PATROL
		_stuck_timer = 0.0
		return

	# [1순위] 플레이어가 가까이서 공격을 휘두를 때 방어/회피 점프 (Evasive Retreat Jump)
	var player_attacking := false
	if "is_attacking" in _player and _player.is_attacking:
		player_attacking = true

	if _jump_cooldown <= 0.0 and player_attacking and absf(horizontal_distance) < 130.0 and absf(vertical_distance) < 60.0:
		velocity.y = -460.0
		velocity.x = -signf(horizontal_distance) * (move_speed * 1.3)
		_jump_cooldown = randf_range(2.0, 3.5)
		return

	# [2순위] 대공 회피 기동: 플레이어가 공중에서 덮쳐올 때 지상 헛스윙 대신 뒤로 백점프 회피
	if _jump_cooldown <= 0.0 and not _player.is_on_floor() and vertical_distance < -20.0 and absf(horizontal_distance) < 140.0:
		velocity.y = -360.0
		velocity.x = -signf(horizontal_distance) * 220.0
		_jump_cooldown = 1.6
		return

	# Only begin melee attack when settled on floor, preventing airborne attack locking
	if is_on_floor() and absf(horizontal_distance) <= attack_range and absf(vertical_distance) < 60.0:
		_begin_attack(horizontal_distance)
		return

	# Soft separation if overlapping player at zero distance
	if absf(horizontal_distance) < 20.0:
		var avoid_dir := 1.0 if position.x >= _player.position.x else -1.0
		velocity.x = avoid_dir * 80.0
	else:
		velocity.x = signf(horizontal_distance) * move_speed

	# 1. 상층 스턱 감지 및 아래층 드롭다운 (Drop down / Ledge Leap Down)
	if vertical_distance > 35.0 and position.y < 560.0:
		if is_on_wall() or absf(velocity.x) < 25.0:
			_stuck_timer += get_physics_process_delta_time()
		else:
			_stuck_timer = maxf(0.0, _stuck_timer - get_physics_process_delta_time() * 2.0)

		if _stuck_timer > 0.20:
			_stuck_timer = 0.0
			velocity.x = signf(horizontal_distance) * (move_speed * 1.6)
			velocity.y = -180.0
			_perform_drop_down()
		elif absf(horizontal_distance) < 380.0:
			_perform_drop_down()

	elif is_on_floor():
		_stuck_timer = 0.0
		# 플레이어가 실제로 상층 플랫폼에 착지해 있을 때만 지형 도약 (공중 점프 시 동기화 점프 완전 배제)
		if _player.is_on_floor() and vertical_distance < -65.0 and absf(horizontal_distance) < 260.0 and _jump_cooldown <= 0.0:
			velocity.y = -530.0
			velocity.x = signf(horizontal_distance) * (move_speed * 1.2)
			_jump_cooldown = 1.5

	# 2. 몬스터 지능형 자율 도약 (Autonomous Combat Mobility)
	if is_on_floor() and _jump_cooldown <= 0.0 and state == State.CHASE:
		# (A) 공격적 도약 강습(Pounce Attack): 플레이어와 중거리(70~230px) 지상 대치 시 주도적 도약 공격
		if absf(horizontal_distance) >= 70.0 and absf(horizontal_distance) <= 230.0 and absf(vertical_distance) < 55.0:
			velocity.y = -460.0
			velocity.x = signf(horizontal_distance) * (move_speed * 1.55)
			_jump_cooldown = randf_range(1.4, 2.2)
		# (B) 장애물 극복 점프: 벽에 부딪혔을 때 도약
		elif is_on_wall() and absf(horizontal_distance) > 35.0:
			velocity.y = -520.0
			velocity.x = signf(horizontal_distance) * move_speed
			_jump_cooldown = 1.2


func _begin_attack(horizontal_distance: float) -> void:
	state = State.ATTACK
	attack_phase = AttackPhase.WINDUP
	attack_count += 1
	_attack_direction = signf(horizontal_distance) if not is_zero_approx(horizontal_distance) else _patrol_direction
	attack_area.position.x = _attack_direction * (22.0 + attack_range * 0.5)
	_phase_time_remaining = attack_windup
	velocity.x = 0.0
	_set_state_color(Color(1.0, 0.82, 0.2, 1.0) if _is_attack_blockable() else Color(1.0, 0.28, 0.15, 1.0))


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
			_spawn_attack_slash_vfx()
		AttackPhase.ACTIVE:
			attack_phase = AttackPhase.RECOVERY
			_phase_time_remaining = attack_cooldown
			is_attack_active = false
			attack_collision.set_deferred("disabled", true)
			_set_state_color(_base_color)
		AttackPhase.RECOVERY:
			state = State.CHASE


const ShardDropClass = preload("res://scripts/system/shard_drop.gd")
var _is_dying: bool = false


func receive_hit() -> void:
	if _is_dying:
		return
	current_hp -= 1
	if current_hp <= 0:
		_is_dying = true
		var top_plat: AnimatableBody2D = get_node_or_null("TopPlatform") as AnimatableBody2D
		if top_plat != null and top_plat.get_child_count() > 0:
			var shape: CollisionShape2D = top_plat.get_child(0) as CollisionShape2D
			if shape != null:
				shape.set_deferred("disabled", true)
		_spawn_shards(randi_range(1, 2))
		queue_free()
		return


	if has_meta("counter_stunned"):

		var counter_dur: float = float(get_meta("counter_stunned"))
		_hit_stun_remaining = maxf(counter_dur, 0.40)
		is_counter_stunned = true
		remove_meta("counter_stunned")
	else:
		_hit_stun_remaining = hit_stun_duration
		is_counter_stunned = false

	if state == State.ATTACK:
		is_attack_active = false
		attack_collision.set_deferred("disabled", true)
		state = State.CHASE

	_hit_flash_remaining = 0.12
	visual.color = Color(0.55, 0.85, 1.0, 1.0) if is_counter_stunned else Color.WHITE


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
		visual.color = Color(1.0, 0.82, 0.2, 1.0) if _is_attack_blockable() else Color(1.0, 0.28, 0.15, 1.0)
	else:
		visual.color = Color(1.0, 0.2, 0.12, 1.0)


func _spawn_shards(count: int) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	for i in range(count):
		var shard := ShardDropClass.new()
		shard.value = 1
		shard.position = position + Vector2(randf_range(-10, 10), randf_range(-15, 0))
		shard.init_velocity(Vector2(randf_range(-90.0, 90.0), randf_range(-200.0, -320.0)))
		shard.ground_y = position.y + 20.0
		parent.call_deferred("add_child", shard)


func _spawn_attack_slash_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "EnemyAttackVFX"
	vfx.position = position + Vector2(_attack_direction * 24.0, 0.0)
	vfx.z_index = 8
	parent.add_child(vfx)

	var arc := Line2D.new()
	arc.width = 3.5
	arc.default_color = Color(1.0, 0.4, 0.2, 0.9) if not _is_attack_blockable() else Color(1.0, 0.85, 0.3, 0.9)
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := -PI * 0.25 + (float(i) / 5.0) * PI * 0.5
		pts.append(Vector2(cos(ang) * 28.0 * _attack_direction, sin(ang) * 28.0))
	arc.points = pts
	vfx.add_child(arc)

	var duration := 0.20
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.4, 0.4)
	tween.tween_property(vfx, "scale", Vector2(1.2, 1.2), duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "position:x", vfx.position.x + _attack_direction * 18.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(vfx.queue_free)

