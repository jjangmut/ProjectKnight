class_name AncientGolemGuardian
extends CharacterBody2D
## Stage 4 Gate Boss: 'Ancient Golem Guardian' (고대 골렘 수호자)
## Colossal 84x96 stone titan featuring Quake Slams, Falling Boulders,
## and Phase 2 Magma Core Overload with High-Speed Rolling Charges.

signal boss_hp_changed(current: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated
signal emit_shockwave(pos: Vector2, dir: float)
signal boulder_summoned(pos: Vector2)

enum State {
	IDLE,
	CHASE,
	QUAKE_SLAM,
	SUMMON_BOULDERS,
	ROLLING_CHARGE,
	PHASE_TRANSITION,
	DEAD
}

@export var max_hp: int = 18
var current_hp: int = 18
var current_phase: int = 1
var core_overload: bool = false
var state: State = State.CHASE

var move_speed: float = 90.0
var facing_direction: float = -1.0
var detection_range: float = 9999.0
var gravity: float = 980.0
var is_dead: bool = false
var is_invulnerable: bool = false

var _phase_timer: float = 0.0
var _cooldown_timer: float = 0.6
var _action_counter: int = 0

var visual: Node2D
var body_poly: Polygon2D
var head_poly: Polygon2D
var shoulder_left: Polygon2D
var shoulder_right: Polygon2D
var core_poly: Polygon2D
var aura_poly: Polygon2D
var boss_sprite: Sprite2D = null
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _walk_anim_timer: float = 0.0
var _hit_flash_timer: float = 0.0

var _player: CharacterBody2D = null

const ShockwaveScene = preload("res://scripts/enemy/boss_shockwave.gd")
const BoulderScene = preload("res://scripts/enemy/falling_boulder.gd")
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

	# Ancient Titan Magma Rim Aura
	aura_poly = Polygon2D.new()
	aura_poly.polygon = PackedVector2Array([
		Vector2(-120, -175), Vector2(120, -175), Vector2(145, 10),
		Vector2(110, 105), Vector2(-110, 105), Vector2(-145, 10)
	])
	aura_poly.color = Color(1.6, 0.75, 0.25, 0.0) # Transparent plate
	aura_poly.visible = false
	var aura_rim := Line2D.new()
	aura_rim.width = 2.8
	aura_rim.default_color = Color(3.5, 1.8, 0.5, 0.9)
	var closed_pts := aura_poly.polygon.duplicate()
	closed_pts.append(closed_pts[0])
	aura_rim.points = closed_pts
	aura_poly.add_child(aura_rim)
	visual.add_child(aura_poly)

	# Stone Torso (84x76) - hidden in favor of high-res sprite
	body_poly = Polygon2D.new()
	body_poly.polygon = PackedVector2Array([
		Vector2(-38, -42), Vector2(38, -42), Vector2(46, -10),
		Vector2(36, 42), Vector2(-36, 42), Vector2(-46, -10)
	])
	body_poly.color = Color(0.35, 0.36, 0.40, 1.0)
	body_poly.visible = false
	visual.add_child(body_poly)

	# Heavy Shoulders
	shoulder_left = Polygon2D.new()
	shoulder_left.polygon = PackedVector2Array([Vector2(-48, -46), Vector2(-30, -56), Vector2(-22, -34), Vector2(-44, -30)])
	shoulder_left.color = Color(0.28, 0.30, 0.34, 1.0)
	shoulder_left.visible = false
	visual.add_child(shoulder_left)

	shoulder_right = Polygon2D.new()
	shoulder_right.polygon = PackedVector2Array([Vector2(48, -46), Vector2(30, -56), Vector2(22, -34), Vector2(44, -30)])
	shoulder_right.color = Color(0.28, 0.30, 0.34, 1.0)
	shoulder_right.visible = false
	visual.add_child(shoulder_right)

	# Stone Head
	head_poly = Polygon2D.new()
	head_poly.polygon = PackedVector2Array([
		Vector2(-18, -66), Vector2(18, -66), Vector2(22, -44),
		Vector2(-22, -44)
	])
	head_poly.color = Color(0.42, 0.44, 0.48, 1.0)
	head_poly.visible = false
	visual.add_child(head_poly)

	# Magma Rune Core in Chest
	core_poly = Polygon2D.new()
	core_poly.polygon = PackedVector2Array([
		Vector2(0, -65), Vector2(40, -25), Vector2(0, 20), Vector2(-40, -25)
	])
	core_poly.color = Color(3.5, 2.0, 0.4, 0.95)
	core_poly.visible = false
	core_poly.z_index = 2
	visual.add_child(core_poly)

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
	var path_combat := "res://assets/enemy_frames/golem_guardian_v2.png"
	var path_skills := "res://assets/enemy_frames/golem_guardian_v2_skills.png"

	# 1. Combat Sprite Sheet (12 frames: Idle 0-3, Stomp Run 4-7, Quake Slam 8-11)
	var sheet := _load_texture_safe(path_combat)
	if sheet != null:
		var regions: Array[Rect2] = [
			Rect2(25, 31, 251, 258), Rect2(323, 31, 250, 258), Rect2(624, 31, 250, 258), Rect2(921, 31, 251, 258),
			Rect2(24, 314, 254, 282), Rect2(324, 314, 248, 282), Rect2(616, 313, 265, 264), Rect2(918, 314, 260, 259),
			Rect2(24, 596, 258, 298), Rect2(322, 596, 263, 297), Rect2(603, 657, 296, 237), Rect2(902, 656, 292, 238)
		]
		var pivots: Array[Vector2] = [
			Vector2(125, 253), Vector2(124, 253), Vector2(124, 253), Vector2(125, 253),
			Vector2(126, 281), Vector2(123, 281), Vector2(132, 259), Vector2(129, 254),
			Vector2(128, 294), Vector2(131, 292), Vector2(147, 233), Vector2(145, 237)
		]
		for i in range(12):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = regions[i]
			_sprite_frames.append(frame)
			_sprite_pivots.append(pivots[i])

	# 2. Skills Sprite Sheet (12 frames: Summon Boulders 12-15, Rolling Charge 16-19, Defeat Shatter 20-23)
	var sheet_s := _load_texture_safe(path_skills)
	if sheet_s != null:
		var regions_s: Array[Rect2] = [
			Rect2(21, 30, 255, 259), Rect2(308, 12, 291, 279), Rect2(621, 4, 253, 285), Rect2(913, 2, 281, 287),
			Rect2(19, 318, 259, 278), Rect2(327, 325, 247, 252), Rect2(619, 326, 262, 250), Rect2(920, 321, 259, 256),
			Rect2(20, 596, 264, 298), Rect2(308, 628, 284, 266), Rect2(615, 657, 277, 236), Rect2(900, 700, 296, 194)
		]
		var pivots_s: Array[Vector2] = [
			Vector2(127, 254), Vector2(145, 274), Vector2(126, 280), Vector2(140, 282),
			Vector2(129, 277), Vector2(123, 247), Vector2(130, 245), Vector2(129, 251),
			Vector2(131, 294), Vector2(141, 261), Vector2(138, 231), Vector2(147, 193)
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
	# Imposing Chibi Golem Stature: 0.44 (~115px tall, 2.5-head Chibi titan proportion)
	boss_sprite.scale = Vector2.ONE * 0.44
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.position = Vector2.ZERO

	if not _sprite_frames.is_empty():
		boss_sprite.texture = _sprite_frames[0]
		boss_sprite.offset = -_sprite_pivots[0]
		print(">>> [GOLEM GUARDIAN] BossSprite initialized with %d frames! First frame size: %s" % [_sprite_frames.size(), _sprite_frames[0].get_size()])

	visual.add_child(boss_sprite)


func _build_collisions() -> void:
	var body_col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 38.0
	shape.height = 110.0
	body_col.shape = shape
	body_col.position = Vector2(0, -55.0)
	add_child(body_col)

	# Dynamic Top Platform: allows player to stand and ride on top of Chibi Ancient Golem head (~106px)
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(80.0, 16.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -106.0)
	top_shape.one_way_collision = true
	top_platform.add_child(top_shape)
	add_child(top_platform)
	add_collision_exception_with(top_platform)
	top_platform.add_collision_exception_with(self)

	var hurt_area := Area2D.new()
	hurt_area.name = "HurtArea"
	var hurt_col := CollisionShape2D.new()
	var hurt_shape := CapsuleShape2D.new()
	hurt_shape.radius = 42.0
	hurt_shape.height = 115.0
	hurt_col.shape = hurt_shape
	hurt_col.position = Vector2(0, -55.0)
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

	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_find_player()

	if is_instance_valid(_player) and not is_dead and state != State.ROLLING_CHARGE:
		facing_direction = -1.0 if _player.global_position.x < global_position.x else 1.0
		visual.scale.x = facing_direction

	match state:
		State.CHASE:
			_process_chase(delta)
		State.QUAKE_SLAM:
			_process_quake_slam(delta)
		State.SUMMON_BOULDERS:
			_process_summon_boulders(delta)
		State.ROLLING_CHARGE:
			_process_rolling_charge(delta)
		State.PHASE_TRANSITION:
			_process_phase_transition(delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	elif is_instance_valid(boss_sprite):
		if current_phase == 2:
			boss_sprite.modulate = Color(1.3, 0.6, 0.4, 1.0)
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
					_walk_anim_timer += delta * 6.0
					frame_idx = 4 + (int(_walk_anim_timer) % 4) # frames 4..7 (Stomp advance)
				else:
					frame_idx = 0
			State.QUAKE_SLAM:
				if _phase_timer > 0.40:
					frame_idx = 8 # Windup raise fists
				elif _phase_timer > 0.20:
					frame_idx = 9 # Full overhead extension
				elif _phase_timer > 0.08:
					frame_idx = 10 # Downward impact smash
				else:
					frame_idx = 11 # Quake ground burst
			State.SUMMON_BOULDERS:
				if _phase_timer > 0.45:
					frame_idx = 12 # Hands to sky
				elif _phase_timer > 0.30:
					frame_idx = 13 # Roaring chest glow
				elif _phase_timer > 0.15:
					frame_idx = 14 # Boulders forming
				else:
					frame_idx = 15 # Cascade release
			State.ROLLING_CHARGE:
				_walk_anim_timer += delta * 12.0
				frame_idx = 16 + (int(_walk_anim_timer) % 4) # frames 16..19 (Rolling ball rotation)
			State.PHASE_TRANSITION:
				var t_frame := int(floor(_phase_timer * 8.0)) % 2
				frame_idx = 12 if t_frame == 0 else 13
			State.DEAD:
				if _phase_timer > 0.75:
					frame_idx = 20 # Hurt stun
				elif _phase_timer > 0.50:
					frame_idx = 21 # Cracking fissures
				elif _phase_timer > 0.25:
					frame_idx = 22 # Crumbling stagger
				else:
					frame_idx = 23 # Shattered stone pile on ground

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
		boss_sprite.modulate = Color(1.3, 0.65, 0.3).lerp(Color(1.6, 0.3, 0.1), pulse)
	else:
		boss_sprite.modulate = Color(1.15, 1.15, 1.15, 1.0) # High-contrast radiant ancient stone finish


func _process_chase(delta: float) -> void:
	_cooldown_timer -= delta
	if is_instance_valid(_player):
		var dist := absf(_player.global_position.x - global_position.x)
		if dist > 140.0:
			velocity.x = facing_direction * (move_speed if current_phase == 1 else move_speed * 1.35)
		else:
			velocity.x = 0.0

		if _cooldown_timer <= 0.0:
			_decide_action(dist)
	else:
		velocity.x = 0.0


func _decide_action(dist: float) -> void:
	_action_counter += 1
	if current_phase == 2 and _action_counter % 3 == 0:
		_start_rolling_charge()
		return

	if dist <= 220.0:
		_start_quake_slam()
	else:
		_start_summon_boulders()


func _start_quake_slam() -> void:
	state = State.QUAKE_SLAM
	_phase_timer = 0.55 if current_phase == 1 else 0.38
	velocity.x = 0.0
	body_poly.color = Color(0.9, 0.5, 0.2)
	AudioManager.play("smash_3", global_position)


func _process_quake_slam(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_emit_shockwaves()
		_spawn_quake_vfx()
		GameFeelManager.shake(0.60)
		GameFeelManager.trigger_hit_stop(0.08, 0.08)
		AudioManager.play("counter_hit", global_position)
		body_poly.color = Color(0.35, 0.36, 0.40, 1.0)
		state = State.CHASE
		_cooldown_timer = 0.85 if current_phase == 1 else 0.50


func _emit_shockwaves() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var wave_left := ShockwaveScene.new()
	wave_left.position = Vector2(position.x - 40.0, position.y + 35.0)
	wave_left.direction = -1.0
	parent.add_child(wave_left)
	emit_shockwave.emit(wave_left.position, -1.0)

	var wave_right := ShockwaveScene.new()
	wave_right.position = Vector2(position.x + 40.0, position.y + 35.0)
	wave_right.direction = 1.0
	parent.add_child(wave_right)
	emit_shockwave.emit(wave_right.position, 1.0)


func _start_summon_boulders() -> void:
	state = State.SUMMON_BOULDERS
	_phase_timer = 0.50
	velocity.x = 0.0
	AudioManager.play("smash_3", global_position)
	GameFeelManager.shake(0.30)


func _process_summon_boulders(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_spawn_boulders()
		state = State.CHASE
		_cooldown_timer = 0.90 if current_phase == 1 else 0.60


func _spawn_boulders() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var center_x := _player.global_position.x if is_instance_valid(_player) else global_position.x
	for offset_x in [-110.0, 0.0, 110.0]:
		var b := BoulderScene.new()
		b.position = Vector2(center_x + offset_x, position.y)
		parent.add_child(b)
		boulder_summoned.emit(b.position)


func _start_rolling_charge() -> void:
	state = State.ROLLING_CHARGE
	_phase_timer = 0.85
	core_poly.color = Color(1.0, 0.1, 0.1)
	AudioManager.play("smash_3", global_position)
	GameFeelManager.shake(0.40)


func _process_rolling_charge(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = facing_direction * 460.0
	visual.rotation += facing_direction * 18.0 * delta
	if randf() < 0.35:
		_spawn_rolling_dust_vfx()

	if is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist < 65.0:
			if _player.has_method("receive_attack"):
				_player.receive_attack(global_position, false) # Unblockable rush
			elif _player.has_method("receive_hit"):
				_player.receive_hit()

	if _phase_timer <= 0.0:
		visual.rotation = 0.0
		velocity.x = 0.0
		state = State.CHASE
		_cooldown_timer = 0.70


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
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(randf_range(-15, 15), -50), "1", dmg_color, is_counter)
	GameFeelManager.trigger_hit_stop(0.06, 0.03)
	GameFeelManager.shake(0.25)
	AudioManager.play("guard_clang", global_position)
	_hit_flash_timer = 0.12

	if current_hp <= 0:
		_die()
		return

	if current_phase == 1 and current_hp <= max_hp / 2:
		_trigger_phase_two()


func _trigger_phase_two() -> void:
	current_phase = 2
	core_overload = true
	boss_phase_changed.emit(2)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.6
	is_invulnerable = true
	aura_poly.visible = false
	core_poly.color = Color(1.0, 0.1, 0.1, 1.0)
	body_poly.color = Color(0.48, 0.28, 0.22, 1.0)
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(1.35, 0.55, 0.35, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.60)
	GameFeelManager.trigger_hit_stop(0.12, 0.08)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -60), "CORE OVERLOAD!", Color(1.0, 0.3, 0.1), true)


func _process_phase_transition(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	if is_instance_valid(boss_sprite):
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.3
		boss_sprite.modulate = Color(1.35 * pulse, 0.55, 0.35, 1.0)
	if _phase_timer <= 0.0:
		is_invulnerable = false
		state = State.CHASE
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
	GameFeelManager.shake(0.75)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -60), "STAGE 4 CONQUERED", Color(1.0, 0.85, 0.2), true)

	_spawn_shard_burst(18)
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
		shard.position = position + Vector2(randf_range(-30, 30), randf_range(-30, 0))
		shard.init_velocity(Vector2(randf_range(-170.0, 170.0), randf_range(-270.0, -420.0)))
		shard.ground_y = position.y + 35.0
		parent.add_child(shard)


func _spawn_quake_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "GolemQuakeVFX"
	vfx.position = position + Vector2(0, 35.0)
	vfx.z_index = 8
	parent.add_child(vfx)

	# 1. Rising Rock Shards
	var shard_count := 8
	var shards: Array[Polygon2D] = []
	var shard_vels: Array[Vector2] = []
	for i in range(shard_count):
		var p := Polygon2D.new()
		var sz := randf_range(5.0, 9.0)
		p.polygon = PackedVector2Array([
			Vector2(-sz, sz * 0.5), Vector2(0, -sz), Vector2(sz, sz * 0.5), Vector2(0, sz)
		])
		p.color = Color(0.5, 0.45, 0.4, 1.0) if current_phase == 1 else Color(0.9, 0.45, 0.15, 1.0)
		vfx.add_child(p)
		shards.append(p)
		var spd := randf_range(160.0, 320.0)
		var ang := randf_range(-PI * 0.85, -PI * 0.15) # upwards burst
		shard_vels.append(Vector2(cos(ang), sin(ang)) * spd)

	# 2. Ground Crack Shock Ring
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.6, 0.2, 0.9) if current_phase == 2 else Color(0.8, 0.7, 0.5, 0.85)
	var pts := PackedVector2Array()
	for i in range(15):
		var a := float(i) / 14.0 * TAU
		pts.append(Vector2(cos(a) * 60.0, sin(a) * 20.0))
	ring.points = pts
	vfx.add_child(ring)

	var duration := 0.35
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.3, 0.3)
	tween.tween_property(vfx, "scale", Vector2(1.6, 1.6), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(shards.size()):
		var p := shards[i]
		var v := shard_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "rotation", randf_range(-3.0, 3.0), duration)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.4)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(vfx.queue_free)


func _spawn_rolling_dust_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "GolemRollingDustVFX"
	vfx.position = position + Vector2(0, 32.0)
	vfx.z_index = 7
	parent.add_child(vfx)

	var dust_count := 4
	var dust_nodes: Array[Polygon2D] = []
	var dust_vels: Array[Vector2] = []
	for i in range(dust_count):
		var p := Polygon2D.new()
		var sz := randf_range(4.0, 7.0)
		p.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
		p.color = Color(0.8, 0.5, 0.2, 0.7) if current_phase == 2 else Color(0.65, 0.6, 0.55, 0.6)
		vfx.add_child(p)
		dust_nodes.append(p)
		dust_vels.append(Vector2(-facing_direction * randf_range(80.0, 180.0), randf_range(-60.0, -10.0)))

	var duration := 0.25
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	for i in range(dust_nodes.size()):
		var p := dust_nodes[i]
		var v := dust_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.3)
	tween.chain().tween_callback(vfx.queue_free)
