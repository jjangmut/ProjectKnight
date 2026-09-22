class_name BossCommander
extends CharacterBody2D
## Stage 1 Gate Boss: 'Corrupted Shield Commander' (타락한 방패 기사단장)
## Multi-phase encounter featuring Shield Bash, Bastion Guard, Enraged Shockwave Leap,
## and dynamic boss health bar synchronization.

signal boss_hp_changed(current: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated

enum State {
	IDLE,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	ATTACK_RECOVERY,
	BASTION_GUARD,
	LEAP_SLAM,
	STUNNED,
	PHASE_TRANSITION,
	DEAD
}

enum Pattern {
	SHIELD_BASH,
	COMBO_CLEAVE,
	BASTION_GUARD,
	SHOCKWAVE_LEAP,
	RAGING_THRUST
}

@export var max_hp: int = 12
var current_hp: int = 12
var current_phase: int = 1
var state: State = State.CHASE
var current_pattern: Pattern = Pattern.SHIELD_BASH

var move_speed: float = 120.0
var facing_direction: float = -1.0
var attack_range: float = 85.0
var detection_range: float = 9999.0
var gravity: float = 980.0
var is_dead: bool = false
var is_invulnerable: bool = false

var _phase_timer: float = 0.0
var _hit_stun_timer: float = 0.0
var _attack_cooldown: float = 0.8
var _cooldown_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _action_counter: int = 0

# Visual and Collision nodes
var visual: Node2D
var body_poly: Polygon2D
var shield_poly: Polygon2D
var eye_poly: Polygon2D
var aura_poly: Polygon2D
var boss_sprite: Sprite2D
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _walk_anim_timer: float = 0.0
var attack_area: Area2D
var attack_collision: CollisionShape2D
var attack_visual: Polygon2D
var hurt_area: Area2D
var _player: CharacterBody2D = null

const ShockwaveScene = preload("res://scripts/enemy/boss_shockwave.gd")
const ShardScene = preload("res://scripts/system/shard_drop.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")



func _ready() -> void:
	z_index = 5
	collision_layer = 16
	collision_mask = 1
	current_hp = max_hp
	add_to_group("enemies")
	add_to_group("boss")

	_build_visuals()
	_build_collisions()
	_find_player()
	boss_hp_changed.emit(current_hp, max_hp)


func _find_player() -> void:
	if not is_inside_tree():
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			_player = p as CharacterBody2D
			return



func _build_visuals() -> void:
	visual = Node2D.new()
	visual.name = "Visuals"
	add_child(visual)

	# Phase 2 Enrage Aura (starts hidden, kept hidden in favor of sprite modulation)
	aura_poly = Polygon2D.new()
	aura_poly.polygon = PackedVector2Array([
		Vector2(-48, -72), Vector2(48, -72), Vector2(62, 0),
		Vector2(48, 52), Vector2(-48, 52), Vector2(-62, 0)
	])
	aura_poly.color = Color(1.0, 0.15, 0.1, 0.0)
	aura_poly.visible = false
	visual.add_child(aura_poly)

	# Primitive placeholders (hidden in favor of high-res boss sprite)
	body_poly = Polygon2D.new()
	body_poly.polygon = PackedVector2Array([
		Vector2(-24, -42), Vector2(24, -42), Vector2(28, -10),
		Vector2(20, 36), Vector2(-20, 36), Vector2(-28, -10)
	])
	body_poly.color = Color(0.18, 0.22, 0.28, 1.0)
	body_poly.visible = false
	visual.add_child(body_poly)

	shield_poly = Polygon2D.new()
	shield_poly.polygon = PackedVector2Array([
		Vector2(8, -38), Vector2(32, -38), Vector2(32, 16),
		Vector2(20, 38), Vector2(8, 20)
	])
	shield_poly.color = Color(0.35, 0.40, 0.48, 1.0)
	shield_poly.visible = false
	visual.add_child(shield_poly)

	eye_poly = Polygon2D.new()
	eye_poly.polygon = PackedVector2Array([
		Vector2(6, -30), Vector2(18, -30), Vector2(16, -26), Vector2(8, -26)
	])
	eye_poly.color = Color(1.0, 0.82, 0.2, 1.0)
	eye_poly.visible = false
	visual.add_child(eye_poly)

	_build_boss_sprite()


func _build_boss_sprite() -> void:
	var dedicated_path := "res://assets/enemy_frames/boss_commander_v1.png"
	var file_path := dedicated_path if ResourceLoader.exists(dedicated_path) else "res://assets/enemy_frames/melee_v1.png"
	if ResourceLoader.exists(file_path):
		var sheet := load(file_path) as Texture2D
		if sheet != null:
			var is_dedicated := (file_path == dedicated_path)
			var regions: Array[Rect2] = []
			var pivots: Array[Vector2] = []
			if is_dedicated:
				regions = [
					Rect2(0, 0, 421, 424),
					Rect2(421, 0, 421, 424),
					Rect2(842, 0, 422, 424),
					Rect2(0, 424, 421, 424),
					Rect2(421, 424, 421, 424),
					Rect2(842, 424, 422, 424)
				]
				for i in range(6):
					pivots.append(Vector2(210, 410))
			else:
				regions = [
					Rect2(0, 0, 512, 500),
					Rect2(512, 0, 550, 500),
					Rect2(1062, 0, 474, 500),
					Rect2(0, 500, 512, 524),
					Rect2(512, 500, 585, 524),
					Rect2(1097, 500, 439, 524)
				]
				pivots = [
					Vector2(225, 484),
					Vector2(250, 486),
					Vector2(240, 486),
					Vector2(240, 483),
					Vector2(240, 480),
					Vector2(210, 480)
				]
			for i in range(6):
				var frame := AtlasTexture.new()
				frame.atlas = sheet
				frame.region = regions[i]
				_sprite_frames.append(frame)
				_sprite_pivots.append(pivots[i])

	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossSprite"
	boss_sprite.centered = false
	# Imposing boss scale: 0.19 (~96px tall, 1.4x larger than regular melee enemies)
	boss_sprite.scale = Vector2.ONE * 0.19
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.position = Vector2(0, 36)

	if not _sprite_frames.is_empty():
		boss_sprite.texture = _sprite_frames[0]
		var pivot: Vector2 = _sprite_pivots[0]
		boss_sprite.offset = -pivot
	elif ResourceLoader.exists("res://assets/stage_batch/melee.png"):
		var tex := load("res://assets/stage_batch/melee.png") as Texture2D
		boss_sprite.texture = tex
		boss_sprite.centered = true
		boss_sprite.position = Vector2(0, 0)
		boss_sprite.scale = Vector2.ONE * (96.0 / tex.get_height())

	visual.add_child(boss_sprite)


func _build_collisions() -> void:
	collision_layer = 16
	collision_mask = 1

	# Main body physics collision
	var body_col := CollisionShape2D.new()
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(48, 76)
	body_col.shape = body_shape
	body_col.position = Vector2(0, -2)
	add_child(body_col)

	# Dynamic Top Platform: allows player to jump and stand on top of Boss
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(52.0, 12.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -40.0)
	top_shape.one_way_collision = true
	top_platform.add_child(top_shape)
	add_child(top_platform)
	add_collision_exception_with(top_platform)
	top_platform.add_collision_exception_with(self)

	# Hurtbox
	hurt_area = Area2D.new()
	hurt_area.name = "HurtArea"
	hurt_area.collision_layer = 2
	hurt_area.collision_mask = 0
	var hurt_col := CollisionShape2D.new()
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = Vector2(52, 78)
	hurt_col.shape = hurt_shape
	hurt_col.position = Vector2(0, -2)
	hurt_area.add_child(hurt_col)
	add_child(hurt_area)

	# Attack Hitbox
	attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	attack_collision = CollisionShape2D.new()
	var at_shape := RectangleShape2D.new()
	at_shape.size = Vector2(80, 70)
	attack_collision.shape = at_shape
	attack_collision.position = Vector2(45, -5)
	attack_collision.disabled = true
	attack_area.add_child(attack_collision)

	# Telegraph / Attack arc visual
	attack_visual = Polygon2D.new()
	attack_visual.polygon = PackedVector2Array([
		Vector2(5, -40), Vector2(85, -25), Vector2(85, 30), Vector2(5, 35)
	])
	attack_visual.color = Color(1.0, 0.3, 0.1, 0.0)
	attack_area.add_child(attack_visual)
	add_child(attack_area)

	attack_area.area_entered.connect(_on_attack_area_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	if not is_instance_valid(_player):
		_find_player()
		return

	# Flash recovery
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_restore_base_color()

	# Cooldowns
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Facing logic
	if state in [State.IDLE, State.CHASE]:
		var dir_to_p := signf(_player.position.x - position.x)
		if dir_to_p != 0.0 and dir_to_p != facing_direction:
			facing_direction = dir_to_p
			visual.scale.x = facing_direction
			attack_area.scale.x = facing_direction

	match state:
		State.CHASE:
			_process_chase(delta)
		State.ATTACK_WINDUP:
			_process_attack_windup(delta)
		State.ATTACK_ACTIVE:
			_process_attack_active(delta)
		State.ATTACK_RECOVERY:
			_process_attack_recovery(delta)
		State.BASTION_GUARD:
			_process_bastion_guard(delta)
		State.LEAP_SLAM:
			_process_leap_slam(delta)
		State.STUNNED:
			_process_stunned(delta)
		State.PHASE_TRANSITION:
			_process_phase_transition(delta)

	move_and_slide()
	_update_boss_sprite(delta)


func _update_boss_sprite(delta: float) -> void:
	if boss_sprite == null:
		return

	if not _sprite_frames.is_empty():
		var frame_idx := 0
		match state:
			State.IDLE:
				frame_idx = 0
			State.CHASE:
				if absf(velocity.x) > 5.0:
					_walk_anim_timer += delta * 6.5
					frame_idx = 1 if int(_walk_anim_timer) % 2 == 0 else 2
				else:
					frame_idx = 0
			State.ATTACK_WINDUP:
				frame_idx = 3 # Threatening heavy weapon windup
			State.ATTACK_ACTIVE:
				frame_idx = 4 # Crushing shield bash / cleave strike
			State.ATTACK_RECOVERY:
				frame_idx = 5 # Recovery pose
			State.BASTION_GUARD:
				frame_idx = 0 # Fortified shield stance
			State.LEAP_SLAM:
				frame_idx = 4 if is_on_floor() else 3 # Airborne / slam
			State.STUNNED:
				frame_idx = 5
			State.PHASE_TRANSITION:
				frame_idx = 3
			State.DEAD:
				frame_idx = 5

		if frame_idx < _sprite_frames.size():
			boss_sprite.texture = _sprite_frames[frame_idx]
			var pivot: Vector2 = _sprite_pivots[frame_idx]
			boss_sprite.offset = -pivot

	# Hit flash & Phase 2 Enraged aura pulse
	if _hit_flash_timer > 0.0:
		boss_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	elif current_phase == 2:
		var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		boss_sprite.modulate = Color(1.0, 0.45, 0.42).lerp(Color(1.2, 0.25, 0.20), pulse)
	else:
		boss_sprite.modulate = Color.WHITE


func _process_chase(_delta: float) -> void:
	var dist_x := absf(_player.position.x - position.x)
	var dir := signf(_player.position.x - position.x)

	if dist_x <= attack_range and _cooldown_timer <= 0.0:
		velocity.x = 0.0
		_decide_next_pattern()
		return

	velocity.x = dir * move_speed


func _decide_next_pattern() -> void:
	_action_counter += 1
	if current_phase == 1:
		# Phase 1: Bash -> Cleave -> Bastion Guard
		var pick := _action_counter % 3
		match pick:
			0:
				_start_attack(Pattern.SHIELD_BASH, 0.65, 0.20, true)
			1:
				_start_attack(Pattern.COMBO_CLEAVE, 0.70, 0.25, true)
			2:
				_start_bastion_guard()
	else:
		# Phase 2: Shockwave Leap -> Raging Thrust -> Cleave
		var pick := _action_counter % 3
		match pick:
			0:
				_start_leap_slam()
			1:
				_start_attack(Pattern.RAGING_THRUST, 0.50, 0.30, false)
			2:
				_start_attack(Pattern.COMBO_CLEAVE, 0.55, 0.22, true)


func _start_attack(pattern: Pattern, windup: float, active_time: float, blockable: bool) -> void:
	state = State.ATTACK_WINDUP
	current_pattern = pattern
	_phase_timer = windup
	velocity.x = 0.0

	# Telegraph visual color: Gold (blockable) vs Crimson Red (unblockable)
	var color := Color(1.0, 0.85, 0.2, 0.8) if blockable else Color(1.0, 0.18, 0.12, 0.9)
	attack_visual.color = color
	body_poly.color = color
	AudioManager.play("slash_1", global_position)


func _process_attack_windup(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.ATTACK_ACTIVE
		attack_collision.disabled = false
		_phase_timer = 0.22
		var is_blockable := (current_pattern != Pattern.RAGING_THRUST)

		# Rush forward on bash/thrust
		if current_pattern == Pattern.SHIELD_BASH:
			velocity.x = facing_direction * 280.0
			AudioManager.play("smash_3", global_position)
		elif current_pattern == Pattern.RAGING_THRUST:
			velocity.x = facing_direction * 420.0
			AudioManager.play("smash_3", global_position)
		else:
			velocity.x = facing_direction * 120.0
			AudioManager.play("slash_2", global_position)

		# Visual Attack VFX: Spawn Boss Crescent Slash Arc
		_spawn_boss_attack_vfx(current_pattern, facing_direction)


func _process_attack_active(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		attack_collision.disabled = true
		state = State.ATTACK_RECOVERY
		_phase_timer = 0.35 if current_phase == 1 else 0.22
		velocity.x = 0.0
		_restore_base_color()


func _process_attack_recovery(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.CHASE
		_cooldown_timer = _attack_cooldown if current_phase == 1 else _attack_cooldown * 0.65


func _start_bastion_guard() -> void:
	state = State.BASTION_GUARD
	_phase_timer = 1.1
	velocity.x = 0.0
	shield_poly.color = Color(0.8, 0.9, 1.0, 1.0)
	shield_poly.scale = Vector2(1.2, 1.2)


func _process_bastion_guard(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		shield_poly.scale = Vector2.ONE
		_restore_base_color()
		state = State.CHASE
		_cooldown_timer = 0.4


func _start_leap_slam() -> void:
	state = State.LEAP_SLAM
	_phase_timer = 0.0
	velocity.y = -580.0 # High vertical leap
	velocity.x = facing_direction * 180.0
	body_poly.color = Color(1.0, 0.15, 0.1, 1.0)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.3)


func _process_leap_slam(delta: float) -> void:
	# While airborne, descends rapidly
	if velocity.y > 0.0:
		velocity.y += 600.0 * delta # Heavy slam acceleration

	if is_on_floor() and velocity.y >= 0.0:
		# SLAM LANDING: emit shockwaves!
		_emit_shockwaves()
		GameFeelManager.shake(0.55)
		GameFeelManager.trigger_hit_stop(0.08, 0.0)
		AudioManager.play("smash_3", global_position)
		state = State.ATTACK_RECOVERY
		_phase_timer = 0.40
		velocity.x = 0.0
		_restore_base_color()


func _emit_shockwaves() -> void:
	var wave_left := ShockwaveScene.new()
	wave_left.position = Vector2(position.x - 30.0, position.y + 30.0)
	wave_left.direction = -1.0
	get_parent().add_child(wave_left)

	var wave_right := ShockwaveScene.new()
	wave_right.position = Vector2(position.x + 30.0, position.y + 30.0)
	wave_right.direction = 1.0
	get_parent().add_child(wave_right)


func _process_stunned(delta: float) -> void:
	_hit_stun_timer -= delta
	velocity.x = 0.0
	if _hit_stun_timer <= 0.0:
		state = State.CHASE
		_restore_base_color()


func _process_phase_transition(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	if is_instance_valid(boss_sprite):
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.35
		boss_sprite.modulate = Color(1.35 * pulse, 0.4, 0.4, 1.0)
	if _phase_timer <= 0.0:
		is_invulnerable = false
		state = State.CHASE
		_start_leap_slam()


func receive_hit() -> void:
	if is_dead or is_invulnerable:
		return

	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_find_player()

	# Bastion Guard check: frontal hit is blocked!
	if state == State.BASTION_GUARD:
		var hit_dir := facing_direction
		if is_instance_valid(_player) and not _player.is_queued_for_deletion():
			hit_dir = signf(_player.position.x - position.x)
		if hit_dir == facing_direction:
			# Frontal block!
			AudioManager.play("guard_clang", global_position)
			GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -40), "BLOCKED!", Color(0.8, 0.85, 0.9))
			GameFeelManager.shake(0.15)
			# Knock player back
			if is_instance_valid(_player) and "velocity" in _player:
				_player.velocity.x = -facing_direction * 220.0
			return

	current_hp -= 1
	boss_hp_changed.emit(current_hp, max_hp)

	# Floating damage number
	var is_counter := has_meta("counter_stunned")
	var dmg_color := Color(0.3, 0.95, 1.0) if is_counter else Color(1.0, 0.9, 0.4)
	var dmg_text := "2! CRIT" if is_counter else "1"
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(randf_range(-15, 15), -45), dmg_text, dmg_color, is_counter)

	# Hitstop & Shake
	GameFeelManager.trigger_hit_stop(0.08 if is_counter else 0.05, 0.03)
	GameFeelManager.shake(0.35 if is_counter else 0.20)

	if current_hp <= 0:
		_die()
		return

	# Phase 2 Transition trigger at <= 50% HP (6 HP)
	if current_phase == 1 and current_hp <= max_hp / 2:
		_trigger_phase_two()
		return

	# Stun handling
	if is_counter:
		var dur: float = float(get_meta("counter_stunned"))
		remove_meta("counter_stunned")
		state = State.STUNNED
		_hit_stun_timer = dur
		attack_collision.disabled = true
		body_poly.color = Color(0.4, 0.85, 1.0)
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(0.4, 0.85, 1.0, 1.0)
	else:
		_hit_flash_timer = 0.12
		body_poly.color = Color.WHITE
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)


func _trigger_phase_two() -> void:
	current_phase = 2
	boss_phase_changed.emit(2)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.7
	is_invulnerable = true
	move_speed = 160.0
	attack_collision.disabled = true
	aura_poly.visible = true
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(1.4, 0.4, 0.4, 1.0)
	eye_poly.color = Color(1.0, 0.1, 0.1, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.45)
	GameFeelManager.trigger_hit_stop(0.12, 0.0)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -60), "ENRAGED!", Color(1.0, 0.1, 0.1), true)


func _die() -> void:
	is_dead = true
	state = State.DEAD
	attack_collision.set_deferred("disabled", true)
	var top_plat: AnimatableBody2D = get_node_or_null("TopPlatform") as AnimatableBody2D
	if top_plat != null and top_plat.get_child_count() > 0:
		var shape: CollisionShape2D = top_plat.get_child(0) as CollisionShape2D
		if shape != null:
			shape.set_deferred("disabled", true)
	aura_poly.visible = false
	body_poly.color = Color(0.2, 0.2, 0.2, 0.8)
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(0.4, 0.4, 0.4, 0.8)

	# Dramatic slow-mo & camera shake
	GameFeelManager.trigger_hit_stop(0.60, 0.15)
	GameFeelManager.shake(0.65)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "BOSS DEFEATED", Color(1.0, 0.85, 0.2), true)

	# Fountain burst of 10 Soul Shards
	_spawn_shard_burst(10)

	boss_defeated.emit()

	# Disappear after defeat fade
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(queue_free)


func _spawn_shard_burst(count: int) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	for i in range(count):
		var shard := ShardScene.new()
		shard.value = 1
		shard.position = position + Vector2(randf_range(-20, 20), randf_range(-30, 0))
		shard.init_velocity(Vector2(randf_range(-140.0, 140.0), randf_range(-220.0, -360.0)))
		shard.ground_y = position.y + 30.0
		parent.add_child(shard)


func _on_attack_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		var is_blockable := (current_pattern != Pattern.RAGING_THRUST)
		if target.has_method("receive_attack"):
			target.receive_attack(global_position, is_blockable)
		elif target.has_method("receive_hit"):
			target.receive_hit()


func _restore_base_color() -> void:
	if current_phase == 2:
		body_poly.color = Color(0.35, 0.18, 0.22, 1.0)
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(1.35, 0.45, 0.45, 1.0)
	else:
		body_poly.color = Color(0.18, 0.22, 0.28, 1.0)
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	shield_poly.color = Color(0.35, 0.40, 0.48, 1.0)
	attack_visual.color = Color(1.0, 0.3, 0.1, 0.0)


func _spawn_boss_attack_vfx(pattern: Pattern, facing_dir: float) -> void:
	var parent := get_parent() as Node2D
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.position = global_position + Vector2(facing_dir * 55.0, -10.0)
	vfx.z_index = 35
	parent.add_child(vfx)

	# 1. Crescent slash arc line
	var arc := Line2D.new()
	arc.width = 10.0 if current_phase == 2 else 7.5
	var arc_color := Color(1.0, 0.15, 0.1, 0.95) if pattern == Pattern.RAGING_THRUST else (Color(1.0, 0.8, 0.15, 0.95) if pattern == Pattern.SHIELD_BASH else Color(1.0, 0.45, 0.1, 0.95))
	arc.default_color = arc_color

	var points := PackedVector2Array()
	var arc_radius := 65.0
	for i in range(9):
		var ang := -PI * 0.45 + (float(i) / 8.0) * PI * 0.9
		var pt := Vector2(cos(ang) * arc_radius * facing_dir, sin(ang) * arc_radius)
		points.append(pt)
	arc.points = points
	vfx.add_child(arc)

	# 2. Inner bright core blade
	var inner := Line2D.new()
	inner.width = 4.0
	inner.default_color = Color.WHITE
	var inner_points := PackedVector2Array()
	for i in range(7):
		var ang := -PI * 0.35 + (float(i) / 6.0) * PI * 0.7
		var pt := Vector2(cos(ang) * (arc_radius * 0.85) * facing_dir, sin(ang) * (arc_radius * 0.85))
		inner_points.append(pt)
	inner.points = inner_points
	vfx.add_child(inner)

	# 3. Burst spark particles
	var spark_count := 8
	var spark_polys: Array[Polygon2D] = []
	var spark_vels: Array[Vector2] = []
	for i in range(spark_count):
		var p := Polygon2D.new()
		var psize := randf_range(3.0, 6.0)
		p.polygon = PackedVector2Array([Vector2(-psize, -psize), Vector2(psize, -psize), Vector2(psize, psize), Vector2(-psize, psize)])
		p.color = Color(1.0, 0.9, 0.3, 1.0) if pattern != Pattern.RAGING_THRUST else Color(1.0, 0.3, 0.2, 1.0)
		vfx.add_child(p)
		spark_polys.append(p)
		var spd := randf_range(180.0, 360.0)
		var sp_angle := randf_range(-PI * 0.35, PI * 0.35)
		if facing_dir < 0.0:
			sp_angle = PI - sp_angle
		spark_vels.append(Vector2(cos(sp_angle), sin(sp_angle)) * spd)

	# Tween animate forward slash burst & fade
	var duration := 0.25
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.3, 0.3)
	tween.tween_property(vfx, "scale", Vector2(1.35, 1.35), duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "position:x", vfx.position.x + facing_dir * 45.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(spark_polys.size()):
		var p := spark_polys[i]
		var v := spark_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.3)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(vfx.queue_free)

