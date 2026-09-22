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
@export var hit_stun_duration: float = 0.25

@onready var visual: Polygon2D = $Visual
@onready var muzzle: Marker2D = $Muzzle

var state: State = State.PATROL
var attack_phase: AttackPhase = AttackPhase.RECOVERY
var current_hp: int
var projectile_count: int = 0
var is_counter_stunned: bool = false
var is_stunned: bool:
	get:
		return _hit_stun_remaining > 0.0
var _hit_stun_remaining: float = 0.0
var _player: CharacterBody2D
var _origin_x: float
var _patrol_direction: float = -1.0
var _phase_time_remaining: float = 0.0
var _base_color := Color(0.55, 0.3, 0.92, 1)
var _hit_flash_remaining: float = 0.0


var _drop_down_timer: float = 0.0
var _jump_cooldown: float = 1.0
var _attack_cooldown_remaining: float = 0.0
var _stuck_timer: float = 0.0

# High-resolution motion sprite setup
var enemy_sprite: Sprite2D = null
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _walk_anim_timer: float = 0.0
var _facing_right: bool = false
var _base_scale: float = 0.135


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	current_hp = max_hp
	_origin_x = position.x
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	visual.color = _base_color
	visual.visible = false

	# Dynamic Top Platform: allows player to stand and ride on top of ranged enemy
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(36.0, 10.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -28.0)
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

	var file_path := "res://assets/enemy_frames/ranged_v1.png"
	var regions: Array[Rect2] = [
		Rect2(0, 0, 535, 500), Rect2(535, 0, 520, 500), Rect2(1055, 0, 481, 500),
		Rect2(0, 500, 510, 524), Rect2(510, 500, 585, 524), Rect2(1095, 500, 441, 524)
	]
	var pivots: Array[Vector2] = [
		Vector2(250, 480), Vector2(255, 480), Vector2(240, 482),
		Vector2(260, 461), Vector2(225, 455), Vector2(220, 453)
	]

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
	enemy_sprite.position = Vector2(0, 26)

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

	if _attack_cooldown_remaining > 0.0:
		_attack_cooldown_remaining -= delta

	if _hit_stun_remaining > 0.0:
		_hit_stun_remaining = maxf(_hit_stun_remaining - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		move_and_slide()
		if _hit_stun_remaining <= 0.0:
			is_counter_stunned = false
			_restore_color()
		return

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
	_update_enemy_sprite(delta)
	if state == State.PATROL and is_on_wall():
		_patrol_direction *= -1.0


func _update_enemy_sprite(delta: float) -> void:
	if enemy_sprite == null:
		return

	if state == State.RANGED_ATTACK and is_instance_valid(_player):
		_facing_right = (_player.global_position.x > global_position.x)
	elif velocity.x > 5.0:
		_facing_right = true
	elif velocity.x < -5.0:
		_facing_right = false

	enemy_sprite.scale.x = _base_scale * (1.0 if _facing_right else -1.0)

	if not _sprite_frames.is_empty():
		var frame_idx := 0
		if is_stunned or is_counter_stunned:
			frame_idx = 5
		elif state == State.RANGED_ATTACK:
			match attack_phase:
				AttackPhase.WINDUP:
					frame_idx = 3
				AttackPhase.RECOVERY:
					frame_idx = 4
		elif absf(velocity.x) > 5.0:
			_walk_anim_timer += delta * 6.0
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
	elif state == State.RANGED_ATTACK and attack_phase == AttackPhase.WINDUP:
		var pulse := (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		enemy_sprite.modulate = Color(1.0, 0.5, 1.2).lerp(Color(1.5, 0.2, 0.5), pulse)
	else:
		enemy_sprite.modulate = Color.WHITE

	# Safeguard: Left world boundary lock
	if position.x < 40.0:
		position.x = 40.0
		if velocity.x < 0.0:
			velocity.x = 0.0

	# Safeguard: Fall rescue fail-safe
	if position.y > 640.0:
		position.y = 590.0
		velocity.y = 0.0
		_drop_down_timer = 0.0


func _perform_drop_down() -> void:
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
	var horizontal_distance := _player.position.x - position.x
	var vertical_distance := _player.position.y - position.y

	# Upper platform descent: if player is on lower floor/ground, descend to pursue
	if is_on_floor() and vertical_distance > 50.0 and position.y < 560.0 and absf(horizontal_distance) < 420.0:
		_perform_drop_down()

	# Evasive retreat jump when player closes in
	if is_on_floor() and _jump_cooldown <= 0.0 and absf(horizontal_distance) < 95.0:
		velocity.y = -460.0
		velocity.x = -signf(horizontal_distance) * (move_speed * 1.5)
		_jump_cooldown = 2.5
		return

	# Ledge/bumper safeguard in patrol: if blocked, reverse direction
	if absf(velocity.x) < 15.0 and is_on_floor():
		_stuck_timer += get_physics_process_delta_time()
		if _stuck_timer > 0.3:
			_stuck_timer = 0.0
			_patrol_direction *= -1.0
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - get_physics_process_delta_time())

	# Only attack when attack cooldown is ready; allows active patrol and relocation between shots
	if _attack_cooldown_remaining <= 0.0 and absf(horizontal_distance) <= detection_range and absf(vertical_distance) < 260.0:
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
		_attack_cooldown_remaining = randf_range(1.2, 2.0)


func _fire_projectile() -> void:
	if projectile_scene == null or not is_instance_valid(_player):
		return
	var projectile := projectile_scene.instantiate() as Area2D
	var fire_direction := signf(_player.global_position.x - global_position.x)
	get_parent().add_child(projectile)
	projectile.global_position = Vector2(global_position.x + fire_direction * 40.0, muzzle.global_position.y)
	if projectile.has_method("configure_target"):
		projectile.configure_target(_player.global_position)
	else:
		projectile.configure(fire_direction)
	projectile_count += 1


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
		_spawn_shards(2)
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

	if state == State.RANGED_ATTACK:
		state = State.PATROL

	_hit_flash_remaining = 0.12
	visual.color = Color(0.55, 0.85, 1.0, 1.0) if is_counter_stunned else Color.WHITE


func _update_hit_flash(delta: float) -> void:
	if _hit_flash_remaining <= 0.0:
		return
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	if _hit_flash_remaining <= 0.0:
		_restore_color()


func _restore_color() -> void:
	visual.color = Color(0.95, 0.75, 1.0, 1.0) if state == State.RANGED_ATTACK and attack_phase == AttackPhase.WINDUP else _base_color


func _set_color(color: Color) -> void:
	if _hit_flash_remaining <= 0.0:
		visual.color = color


func _spawn_shards(count: int) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	for i in range(count):
		var shard := ShardDropClass.new()
		shard.value = 1
		shard.position = position + Vector2(randf_range(-10, 10), randf_range(-15, 0))
		shard.init_velocity(Vector2(randf_range(-80.0, 80.0), randf_range(-180.0, -280.0)))
		shard.ground_y = position.y + 20.0
		parent.call_deferred("add_child", shard)

