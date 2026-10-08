class_name CrossbowCommander
extends CharacterBody2D
## Stage 3 Gate Boss: 'Crossbow Commander of the Ruins' (폐허의 석궁 사령관)
## Features High-Velocity Piercing Bolts, Sky Volley Arrow Showers, Backstep Evasion,
## and Phase 2 Dead-Eye Enrage with Caltrop Traps & Fan-Shot Barrages.

signal boss_hp_changed(current: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated
signal bolt_fired(pos: Vector2, dir: Vector2)

enum State {
	IDLE,
	CHASE,
	AIM_BOLT,
	FIRE_BOLT,
	AIM_VOLLEY,
	FIRE_VOLLEY,
	BACKSTEP,
	DAGGER_SLASH,
	PHASE_TRANSITION,
	DEAD
}

@export var max_hp: int = 16
var current_hp: int = 16
var current_phase: int = 1
var dead_eye_enrage: bool = false
var state: State = State.IDLE

var move_speed: float = 120.0
var facing_direction: float = -1.0
var detection_range: float = 9999.0
var gravity: float = 980.0
var is_dead: bool = false
var is_invulnerable: bool = false

var _phase_timer: float = 0.0
var _cooldown_timer: float = 0.5
var _action_counter: int = 0
var _backstep_cooldown: float = 0.0

var visual: Node2D
var body_poly: Polygon2D
var coat_poly: Polygon2D
var crossbow_poly: Polygon2D
var eye_poly: Polygon2D
var aura_poly: Polygon2D
var laser_line: Line2D
var boss_sprite: Sprite2D = null
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _walk_anim_timer: float = 0.0
var _hit_flash_timer: float = 0.0

var _player: CharacterBody2D = null

const BoltScene = preload("res://scripts/enemy/crossbow_bolt.gd")
const CaltropScene = preload("res://scripts/enemy/caltrop_trap.gd")
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

	# Enrage Aura
	aura_poly = Polygon2D.new()
	aura_poly.polygon = PackedVector2Array([
		Vector2(-70, -140), Vector2(70, -140), Vector2(90, 0),
		Vector2(70, 90), Vector2(-70, 90), Vector2(-90, 0)
	])
	aura_poly.color = Color(0.4, 0.9, 1.8, 0.0) # Transparent plate
	aura_poly.visible = false
	var aura_rim := Line2D.new()
	aura_rim.width = 2.2
	aura_rim.default_color = Color(1.2, 2.2, 3.2, 0.85)
	var closed_pts := aura_poly.polygon.duplicate()
	closed_pts.append(closed_pts[0])
	aura_rim.points = closed_pts
	aura_poly.add_child(aura_rim)
	visual.add_child(aura_poly)

	# Longcoat (Ruins Commander Coat) - hidden in favor of high-res sprite
	coat_poly = Polygon2D.new()
	coat_poly.polygon = PackedVector2Array([
		Vector2(-20, -32), Vector2(16, -32), Vector2(24, 32),
		Vector2(-24, 32), Vector2(-28, 0)
	])
	coat_poly.color = Color(0.18, 0.22, 0.28, 1.0)
	coat_poly.visible = false
	visual.add_child(coat_poly)

	# Armor Torso & Head
	body_poly = Polygon2D.new()
	body_poly.polygon = PackedVector2Array([
		Vector2(-14, -46), Vector2(14, -46), Vector2(18, -20),
		Vector2(14, 10), Vector2(-14, 10), Vector2(-18, -20)
	])
	body_poly.color = Color(0.32, 0.36, 0.44, 1.0)
	body_poly.visible = false
	visual.add_child(body_poly)

	# Mechanical Crossbow Arm
	crossbow_poly = Polygon2D.new()
	crossbow_poly.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(34, -22), Vector2(38, -18),
		Vector2(34, -14), Vector2(0, -14), Vector2(12, -30), Vector2(12, -6)
	])
	crossbow_poly.color = Color(0.65, 0.55, 0.4, 1.0)
	crossbow_poly.visible = false
	visual.add_child(crossbow_poly)

	# Aiming Laser Line (HDR Overdrive)
	laser_line = Line2D.new()
	laser_line.width = 3.2
	laser_line.default_color = Color(2.8, 0.4, 0.2, 0.95)
	laser_line.visible = false
	visual.add_child(laser_line)

	# Eye Glow
	eye_poly = Polygon2D.new()
	eye_poly.polygon = PackedVector2Array([
		Vector2(6, -40), Vector2(12, -40), Vector2(12, -36), Vector2(6, -36)
	])
	eye_poly.color = Color(0.3, 0.9, 1.0, 1.0)
	eye_poly.visible = false
	visual.add_child(eye_poly)

	_build_boss_sprite()


func _load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path) as Texture2D
		if res != null:
			return res
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func _build_boss_sprite() -> void:
	var path_combat := "res://assets/enemy_frames/crossbow_cmd_v2.png"
	var path_skills := "res://assets/enemy_frames/crossbow_cmd_v2_skills.png"

	# 1. Combat Sprite Sheet (12 frames: Idle 0-3, Move/Run 4-7, Snipe/Fire 8-11)
	var sheet := _load_texture_safe(path_combat)
	if sheet != null:
		var regions: Array[Rect2] = [
			Rect2(47, 35, 238, 250), Rect2(346, 35, 238, 250), Rect2(645, 35, 238, 250), Rect2(944, 35, 238, 250),
			Rect2(41, 328, 252, 252), Rect2(319, 327, 276, 253), Rect2(621, 327, 273, 253), Rect2(919, 327, 272, 253),
			Rect2(11, 622, 288, 255), Rect2(308, 622, 292, 255), Rect2(600, 622, 294, 255), Rect2(933, 622, 254, 255)
		]
		var pivots: Array[Vector2] = [
			Vector2(118, 249), Vector2(118, 249), Vector2(118, 249), Vector2(118, 249),
			Vector2(125, 251), Vector2(137, 252), Vector2(136, 252), Vector2(135, 252),
			Vector2(143, 254), Vector2(145, 254), Vector2(146, 254), Vector2(126, 254)
		]
		for i in range(12):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = regions[i]
			_sprite_frames.append(frame)
			_sprite_pivots.append(pivots[i])

	# 2. Skills Sprite Sheet (12 frames: Sky Volley 12-15, Backstep/Caltrops 16-19, Hurt/Defeat 20-23)
	var sheet_s := _load_texture_safe(path_skills)
	if sheet_s != null:
		var regions_s: Array[Rect2] = [
			Rect2(42, 41, 243, 242), Rect2(345, 25, 255, 262), Rect2(600, 22, 284, 263), Rect2(944, 35, 238, 252),
			Rect2(41, 328, 253, 253), Rect2(318, 327, 281, 256), Rect2(622, 327, 272, 253), Rect2(937, 350, 242, 233),
			Rect2(39, 608, 258, 271), Rect2(308, 633, 292, 244), Rect2(619, 727, 277, 152), Rect2(927, 764, 265, 115)
		]
		var pivots_s: Array[Vector2] = [
			Vector2(121, 241), Vector2(127, 261), Vector2(141, 262), Vector2(118, 251),
			Vector2(126, 252), Vector2(140, 255), Vector2(135, 252), Vector2(120, 232),
			Vector2(128, 270), Vector2(145, 243), Vector2(138, 151), Vector2(132, 114)
		]
		for i in range(12):
			var frame := AtlasTexture.new()
			frame.atlas = sheet_s
			frame.region = regions_s[i]
			_sprite_frames.append(frame)
			_sprite_pivots.append(pivots_s[i])

	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossSprite"
	boss_sprite.centered = false
	# Imposing Chibi Boss Stature: 0.42 (~105px tall, 2.5-head Chibi knight proportion)
	boss_sprite.scale = Vector2.ONE * 0.42
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.position = Vector2.ZERO

	if not _sprite_frames.is_empty():
		boss_sprite.texture = _sprite_frames[0]
		boss_sprite.offset = -_sprite_pivots[0]
		print(">>> [CROSSBOW COMMANDER] BossSprite initialized with %d frames! First frame size: %s" % [_sprite_frames.size(), _sprite_frames[0].get_size()])

	visual.add_child(boss_sprite)


func _build_collisions() -> void:
	var body_col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 35.0
	shape.height = 100.0
	body_col.shape = shape
	body_col.position = Vector2(0, -50.0)
	add_child(body_col)

	# Dynamic Top Platform: elevated to grand boss head level (~96px)
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(70.0, 14.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -96.0)
	top_shape.one_way_collision = true
	top_platform.add_child(top_shape)
	add_child(top_platform)
	add_collision_exception_with(top_platform)
	top_platform.add_collision_exception_with(self)

	var hurt_area := Area2D.new()
	hurt_area.name = "HurtArea"
	var hurt_col := CollisionShape2D.new()
	var hurt_shape := CapsuleShape2D.new()
	hurt_shape.radius = 38.0
	hurt_shape.height = 105.0
	hurt_col.shape = hurt_shape
	hurt_col.position = Vector2(0, -50.0)
	hurt_area.add_child(hurt_col)
	add_child(hurt_area)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		if state == State.DEAD:
			_phase_timer = maxf(0.0, _phase_timer - delta)
			_update_boss_sprite(delta)
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	_backstep_cooldown = maxf(0.0, _backstep_cooldown - delta)

	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_find_player()

	if is_instance_valid(_player) and not is_dead and state != State.BACKSTEP:
		facing_direction = -1.0 if _player.global_position.x < global_position.x else 1.0
		visual.scale.x = facing_direction

	match state:
		State.IDLE:
			_process_idle(delta)
		State.AIM_BOLT:
			_process_aim_bolt(delta)
		State.FIRE_BOLT:
			_process_fire_bolt(delta)
		State.AIM_VOLLEY:
			_process_aim_volley(delta)
		State.FIRE_VOLLEY:
			_process_fire_volley(delta)
		State.BACKSTEP:
			_process_backstep(delta)
		State.DAGGER_SLASH:
			_process_dagger_slash(delta)
		State.PHASE_TRANSITION:
			_process_phase_transition(delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	elif is_instance_valid(boss_sprite):
		if current_phase == 2:
			boss_sprite.modulate = Color(1.3, 0.45, 0.45, 1.0)
		else:
			boss_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	move_and_slide()
	_update_boss_sprite(delta)


func _update_boss_sprite(delta: float) -> void:
	if boss_sprite == null:
		return

	if not _sprite_frames.is_empty():
		var frame_idx := 0
		match state:
			State.IDLE:
				_walk_anim_timer += delta * 4.0
				frame_idx = int(_walk_anim_timer) % 4 # frames 0..3 (Idle breathing)
			State.CHASE:
				if absf(velocity.x) > 5.0:
					_walk_anim_timer += delta * 7.5
					frame_idx = 4 + (int(_walk_anim_timer) % 4) # frames 4..7 (Tactical Run)
				else:
					frame_idx = 0
			State.AIM_BOLT:
				frame_idx = 8 # Aiming tension
			State.FIRE_BOLT:
				if _phase_timer > 0.16:
					frame_idx = 9 # Muzzle spark
				elif _phase_timer > 0.08:
					frame_idx = 10 # Recoil
				else:
					frame_idx = 11 # Reload
			State.AIM_VOLLEY:
				frame_idx = 12 # Aim up to sky
			State.FIRE_VOLLEY:
				if _phase_timer > 0.22:
					frame_idx = 13 # Volley arrows into sky
				elif _phase_timer > 0.11:
					frame_idx = 14 # Watching arrows
				else:
					frame_idx = 15 # Reload
			State.BACKSTEP:
				if _phase_timer > 0.24:
					frame_idx = 16 # Scatter caltrops
				elif _phase_timer > 0.14:
					frame_idx = 17 # Leap away
				elif _phase_timer > 0.06:
					frame_idx = 18 # Airborne backstep
				else:
					frame_idx = 19 # Landing
			State.DAGGER_SLASH:
				if _phase_timer > 0.15:
					frame_idx = 9
				else:
					frame_idx = 10
			State.PHASE_TRANSITION:
				var t_frame := int(floor(_phase_timer * 8.0)) % 2
				frame_idx = 12 if t_frame == 0 else 13
			State.DEAD:
				if _phase_timer > 0.75:
					frame_idx = 20 # Hurt stun
				elif _phase_timer > 0.50:
					frame_idx = 21 # Falling
				elif _phase_timer > 0.25:
					frame_idx = 22 # Collapsing
				else:
					frame_idx = 23 # Defeated collapse on ground

		if frame_idx < _sprite_frames.size():
			boss_sprite.texture = _sprite_frames[frame_idx]
			if frame_idx < _sprite_pivots.size():
				boss_sprite.offset = -_sprite_pivots[frame_idx]

	if state == State.DEAD:
		boss_sprite.modulate = Color(0.75, 0.75, 0.8, 0.95)
	elif _hit_flash_timer > 0.0:
		boss_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	elif current_phase == 2:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		boss_sprite.modulate = Color(1.2, 0.7, 0.4).lerp(Color(1.5, 0.3, 0.3), pulse)
	else:
		boss_sprite.modulate = Color(1.15, 1.15, 1.15, 1.0) # High-contrast radiant finish


func _process_idle(delta: float) -> void:
	_cooldown_timer -= delta
	velocity.x = 0.0

	if not is_instance_valid(_player):
		return

	var dist := absf(_player.global_position.x - global_position.x)

	# Backstep evasion when player gets too close
	if dist < 110.0 and _backstep_cooldown <= 0.0 and is_on_floor():
		_start_backstep()
		return

	if _cooldown_timer <= 0.0:
		_decide_next_action()


func _decide_next_action() -> void:
	_action_counter += 1
	var pick: int = _action_counter % (4 if current_phase == 2 else 3)
	match pick:
		0:
			_start_aim_bolt()
		1:
			_start_aim_volley()
		2:
			_start_aim_bolt()
		3:
			_start_fan_barrage()


var _is_fan_barrage: bool = false


func _start_aim_bolt() -> void:
	state = State.AIM_BOLT
	_is_fan_barrage = false
	_phase_timer = 0.45 if current_phase == 1 else 0.30
	laser_line.visible = true
	laser_line.default_color = Color(2.8, 0.4, 0.2, 0.95)
	_update_laser_targeting()
	AudioManager.play("slash_1", global_position)


func _update_laser_targeting() -> void:
	if not is_instance_valid(laser_line) or not laser_line.visible:
		return
	var muzzle_local := Vector2(40.0, -35.0)
	var muzzle_global := visual.to_global(muzzle_local)
	var target_global := _player.global_position + Vector2(0, -24.0) if is_instance_valid(_player) else muzzle_global + Vector2(facing_direction * 600.0, 0.0)
	var dir_global := (target_global - muzzle_global).normalized()
	var end_local := visual.to_local(muzzle_global + dir_global * 900.0)
	laser_line.clear_points()
	laser_line.add_point(muzzle_local)
	laser_line.add_point(end_local)


func _process_aim_bolt(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	_update_laser_targeting()
	if _phase_timer <= 0.0:
		laser_line.visible = false
		var aim_dir := _get_aim_direction_to_player()
		if _is_fan_barrage:
			_fire_fan_barrage(aim_dir)
		else:
			_fire_bolt(aim_dir)
		state = State.FIRE_BOLT
		_phase_timer = 0.25


func _get_aim_direction_to_player() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2(facing_direction, 0.0)
	var muzzle_global := global_position + Vector2(facing_direction * 50.0, -35.0)
	var target_global := _player.global_position + Vector2(0.0, -24.0)
	var diff := target_global - muzzle_global
	if diff.length_squared() < 4.0:
		return Vector2(facing_direction, 0.0)
	return diff.normalized()


func _fire_bolt(dir: Vector2) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var bolt := BoltScene.new()
	bolt.position = global_position + Vector2(facing_direction * 50.0, -35.0)
	bolt.direction = dir.normalized()
	parent.add_child(bolt)
	_spawn_muzzle_flash_vfx(bolt.position, bolt.direction)
	AudioManager.play("smash_3", global_position)
	GameFeelManager.shake(0.20)
	bolt_fired.emit(bolt.position, bolt.direction)


func _fire_fan_barrage(center_dir: Vector2) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var spread_angles := [-0.22, 0.0, 0.22]
	var muzzle_pos := global_position + Vector2(facing_direction * 50.0, -35.0)
	for ang_offset in spread_angles:
		var bolt := BoltScene.new()
		bolt.position = muzzle_pos
		bolt.direction = center_dir.rotated(ang_offset).normalized()
		bolt.speed = 640.0
		parent.add_child(bolt)
		bolt_fired.emit(bolt.position, bolt.direction)
	_spawn_muzzle_flash_vfx(muzzle_pos, center_dir)
	AudioManager.play("smash_3", global_position)
	GameFeelManager.shake(0.35)


func _process_fire_bolt(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.IDLE
		_cooldown_timer = 0.65 if current_phase == 1 else 0.38


func _start_aim_volley() -> void:
	state = State.AIM_VOLLEY
	_phase_timer = 0.50
	crossbow_poly.rotation = -PI * 0.45
	AudioManager.play("counter_hit", global_position)


func _process_aim_volley(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	if _phase_timer <= 0.0:
		_phase_timer = 0.30
		state = State.FIRE_VOLLEY
		_fire_volley()


func _fire_volley() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	AudioManager.play("smash_3", global_position)
	GameFeelManager.shake(0.30)

	var target_x := _player.global_position.x if is_instance_valid(_player) else global_position.x + facing_direction * 200.0
	for offset_x in [-120.0, -60.0, 0.0, 60.0, 120.0]:
		var bolt := BoltScene.new()
		bolt.position = Vector2(target_x + offset_x, global_position.y - 420.0)
		bolt.direction = Vector2(0.0, 1.0)
		bolt.speed = 520.0
		bolt.is_blockable = false
		parent.add_child(bolt)
		bolt_fired.emit(bolt.position, bolt.direction)


func _process_fire_volley(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		crossbow_poly.rotation = 0.0
		state = State.IDLE
		_cooldown_timer = 0.70 if current_phase == 1 else 0.45


func _start_fan_barrage() -> void:
	# Phase 2: Rapid 3-directional fan bolt shot directed at player
	state = State.AIM_BOLT
	_is_fan_barrage = true
	_phase_timer = 0.35
	laser_line.visible = true
	laser_line.default_color = Color(3.0, 0.2, 0.2, 0.95)
	_update_laser_targeting()


func _start_backstep() -> void:
	state = State.BACKSTEP
	_phase_timer = 0.35
	_backstep_cooldown = 2.2
	velocity = Vector2(-facing_direction * 280.0, -320.0)
	_spawn_backstep_dust_vfx()
	AudioManager.play("pogo_bounce", global_position)
	GameFeelManager.shake(0.15)

	# Drop Caltrops when backstepping in Phase 2
	if current_phase == 2:
		_spawn_caltrop()


func _process_backstep(delta: float) -> void:
	_phase_timer -= delta
	if is_on_floor() and velocity.y >= 0.0:
		velocity.x = 0.0
		state = State.IDLE
		_cooldown_timer = 0.25


func _process_dagger_slash(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.IDLE
		_cooldown_timer = 0.4


func _spawn_caltrop() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var trap := CaltropScene.new()
	trap.position = global_position + Vector2(0, 10)
	parent.add_child(trap)


func take_damage(amount: int = 1, _from_dir: Vector2 = Vector2.ZERO) -> void:
	for i in range(amount):
		if is_dead:
			break
		receive_hit()


func receive_hit() -> void:
	if is_dead or is_invulnerable:
		return

	current_hp -= 1
	boss_hp_changed.emit(current_hp, max_hp)

	var is_counter := has_meta("counter_stunned")
	var dmg_color := Color(0.3, 0.95, 1.0) if is_counter else Color(1.0, 0.9, 0.4)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(randf_range(-15, 15), -40), "1", dmg_color, is_counter)
	GameFeelManager.trigger_hit_stop(0.06, 0.03)
	GameFeelManager.shake(0.22)
	AudioManager.play("counter_hit", global_position)
	_hit_flash_timer = 0.12

	if current_hp <= 0:
		_die()
		return

	if current_phase == 1 and current_hp <= max_hp / 2:
		_trigger_phase_two()


func _trigger_phase_two() -> void:
	current_phase = 2
	dead_eye_enrage = true
	boss_phase_changed.emit(2)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.6
	is_invulnerable = true
	aura_poly.visible = false
	eye_poly.color = Color(1.0, 0.1, 0.2, 1.0)
	body_poly.color = Color(0.48, 0.22, 0.32, 1.0)
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(1.3, 0.45, 0.45, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.55)
	GameFeelManager.trigger_hit_stop(0.12, 0.08)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "DEAD-EYE ENRAGE!", Color(1.0, 0.2, 0.2), true)


func _process_phase_transition(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	if is_instance_valid(boss_sprite):
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.3
		boss_sprite.modulate = Color(1.3 * pulse, 0.45, 0.45, 1.0)
	if _phase_timer <= 0.0:
		is_invulnerable = false
		state = State.IDLE
		_cooldown_timer = 0.2


func _die() -> void:
	is_dead = true
	state = State.DEAD
	_phase_timer = 1.0 # Progress through defeat animation frames (20 -> 21 -> 22 -> 23)
	var top_plat: AnimatableBody2D = get_node_or_null("TopPlatform") as AnimatableBody2D
	if top_plat != null and top_plat.get_child_count() > 0:
		var shape: CollisionShape2D = top_plat.get_child(0) as CollisionShape2D
		if shape != null:
			shape.set_deferred("disabled", true)
	aura_poly.visible = false
	body_poly.color = Color(0.2, 0.2, 0.2, 0.8)
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(0.75, 0.75, 0.8, 0.95)

	GameFeelManager.trigger_hit_stop(0.65, 0.15)
	GameFeelManager.shake(0.70)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "STAGE 3 CONQUERED", Color(1.0, 0.85, 0.2), true)

	_spawn_shard_burst(15)
	boss_defeated.emit()

	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 1.2).set_delay(1.2)
	tween.tween_callback(queue_free)


func _spawn_shard_burst(count: int) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	for i in range(count):
		var shard := ShardScene.new()
		shard.value = 1
		shard.position = position + Vector2(randf_range(-25, 25), randf_range(-20, 0))
		shard.init_velocity(Vector2(randf_range(-160.0, 160.0), randf_range(-260.0, -400.0)))
		shard.ground_y = position.y + 25.0
		parent.add_child(shard)


func _spawn_muzzle_flash_vfx(pos: Vector2, dir: Vector2) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "CrossbowMuzzleVFX"
	vfx.position = pos
	vfx.z_index = 9
	parent.add_child(vfx)

	# 1. Concentrated Crossbow Flash Sparks
	var spark_count := 6
	var spark_nodes: Array[Polygon2D] = []
	var spark_vels: Array[Vector2] = []
	for i in range(spark_count):
		var p := Polygon2D.new()
		var sz := randf_range(2.0, 4.0)
		p.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
		p.color = Color(1.0, 0.9, 0.4, 1.0)
		vfx.add_child(p)
		spark_nodes.append(p)
		var spd := randf_range(140.0, 260.0)
		var sp_ang := dir.angle() + randf_range(-PI * 0.25, PI * 0.25)
		spark_vels.append(Vector2(cos(sp_ang), sin(sp_ang)) * spd)

	# 2. Expanding Muzzle Pressure Ring
	var ring := Line2D.new()
	ring.width = 3.5
	ring.default_color = Color(1.0, 0.8, 0.2, 0.85)
	var pts := PackedVector2Array()
	for i in range(9):
		var a := float(i) / 8.0 * TAU
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 14.0))
	ring.points = pts
	vfx.add_child(ring)

	var duration := 0.20
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.3, 0.3)
	tween.tween_property(vfx, "scale", Vector2(1.2, 1.2), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(spark_nodes.size()):
		var p := spark_nodes[i]
		var v := spark_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(vfx.queue_free)


func _spawn_backstep_dust_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "CrossbowBackstepVFX"
	vfx.position = position + Vector2(0, 25.0)
	vfx.z_index = 7
	parent.add_child(vfx)

	var dust_count := 5
	var dust_nodes: Array[Polygon2D] = []
	var dust_vels: Array[Vector2] = []
	for i in range(dust_count):
		var p := Polygon2D.new()
		var sz := randf_range(3.0, 6.0)
		p.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
		p.color = Color(0.7, 0.65, 0.6, 0.6)
		vfx.add_child(p)
		dust_nodes.append(p)
		var spd := randf_range(60.0, 160.0)
		var dir_x := facing_direction # dust blows forward as commander steps back
		dust_vels.append(Vector2(dir_x * spd, randf_range(-40.0, -10.0)))

	var duration := 0.30
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	for i in range(dust_nodes.size()):
		var p := dust_nodes[i]
		var v := dust_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.3)
	tween.chain().tween_callback(vfx.queue_free)
