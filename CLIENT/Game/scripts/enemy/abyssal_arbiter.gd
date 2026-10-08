class_name AbyssalArbiter
extends CharacterBody2D
## Stage 5 Climax Final Boss: 'Abyssal Arbiter' (심연의 심판관)
## 3-Phase Climax Encounter featuring Void Greatsword Combos, Shadow Blinking,
## Spinning Void Blade Rings, and Phase 3 Final Judgment Black Wings.

signal boss_hp_changed(current: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated
signal teleported(to_pos: Vector2)
signal blade_ring_cast(pos: Vector2)

enum State {
	IDLE,
	CHASE,
	VOID_SLASH,
	SHADOW_BLINK,
	BLADE_RING,
	FINAL_JUDGMENT,
	PHASE_TRANSITION,
	DEAD
}

@export var max_hp: int = 24
var current_hp: int = 24
var current_phase: int = 1
var final_judgment: bool = false
var state: State = State.CHASE

var move_speed: float = 160.0
var facing_direction: float = -1.0
var detection_range: float = 9999.0
var gravity: float = 980.0
var is_dead: bool = false
var is_invulnerable: bool = false

var _phase_timer: float = 0.0
var _cooldown_timer: float = 0.5
var _action_counter: int = 0
var _blink_cooldown: float = 0.0

var visual: Node2D
var body_poly: Polygon2D
var cloak_poly: Polygon2D
var sword_poly: Polygon2D
var wing_left: Polygon2D
var wing_right: Polygon2D
var eye_poly: Polygon2D
var aura_poly: Polygon2D
var slash_area: Area2D
var slash_collision: CollisionShape2D
var slash_visual: Polygon2D
var boss_sprite: Sprite2D = null
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _walk_anim_timer: float = 0.0
var _hit_flash_timer: float = 0.0

var _player: CharacterBody2D = null

const BladeScene = preload("res://scripts/enemy/abyssal_blade.gd")
const ShockwaveScene = preload("res://scripts/enemy/boss_shockwave.gd")
const ShardScene = preload("res://scripts/system/shard_drop.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")


func _ready() -> void:
	z_index = 6
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

	# Abyssal Climax Champion Rim Aura
	aura_poly = Polygon2D.new()
	aura_poly.polygon = PackedVector2Array([
		Vector2(-95, -160), Vector2(95, -160), Vector2(120, 15),
		Vector2(90, 95), Vector2(-90, 95), Vector2(-120, 15)
	])
	aura_poly.color = Color(1.3, 0.35, 2.2, 0.0) # Transparent plate
	aura_poly.visible = false
	var aura_rim := Line2D.new()
	aura_rim.width = 2.6
	aura_rim.default_color = Color(2.6, 0.8, 3.5, 0.9)
	var closed_pts := aura_poly.polygon.duplicate()
	closed_pts.append(closed_pts[0])
	aura_rim.points = closed_pts
	aura_poly.add_child(aura_rim)
	visual.add_child(aura_poly)

	# Black Wings (Revealed in Phase 3)
	wing_left = Polygon2D.new()
	wing_left.polygon = PackedVector2Array([Vector2(-10, -20), Vector2(-60, -65), Vector2(-45, -10), Vector2(-20, 0)])
	wing_left.scale = Vector2.ONE * 1.5
	wing_left.color = Color(0.12, 0.05, 0.2, 0.95)
	wing_left.visible = false
	var wing_left_edge := Line2D.new()
	wing_left_edge.width = 2.2
	wing_left_edge.default_color = Color(2.8, 0.8, 3.6, 0.95)
	wing_left_edge.points = wing_left.polygon
	wing_left.add_child(wing_left_edge)
	visual.add_child(wing_left)

	wing_right = Polygon2D.new()
	wing_right.polygon = PackedVector2Array([Vector2(10, -20), Vector2(60, -65), Vector2(45, -10), Vector2(20, 0)])
	wing_right.scale = Vector2.ONE * 1.5
	wing_right.color = Color(0.12, 0.05, 0.2, 0.95)
	wing_right.visible = false
	var wing_right_edge := Line2D.new()
	wing_right_edge.width = 2.2
	wing_right_edge.default_color = Color(2.8, 0.8, 3.6, 0.95)
	wing_right_edge.points = wing_right.polygon
	wing_right.add_child(wing_right_edge)
	visual.add_child(wing_right)

	# Shadow Cloak - hidden in favor of high-res sprite
	cloak_poly = Polygon2D.new()
	cloak_poly.polygon = PackedVector2Array([
		Vector2(-24, -36), Vector2(24, -36), Vector2(32, 40),
		Vector2(0, 48), Vector2(-32, 40)
	])
	cloak_poly.color = Color(0.1, 0.08, 0.14, 1.0)
	cloak_poly.visible = false
	visual.add_child(cloak_poly)

	# Armor Body & Helm
	body_poly = Polygon2D.new()
	body_poly.polygon = PackedVector2Array([
		Vector2(-16, -48), Vector2(16, -48), Vector2(20, -15),
		Vector2(14, 15), Vector2(-14, 15), Vector2(-20, -15)
	])
	body_poly.color = Color(0.24, 0.20, 0.30, 1.0)
	body_poly.visible = false
	visual.add_child(body_poly)

	# Abyssal Greatsword
	sword_poly = Polygon2D.new()
	sword_poly.polygon = PackedVector2Array([
		Vector2(14, -10), Vector2(56, -10), Vector2(68, -6),
		Vector2(56, -2), Vector2(14, -2), Vector2(14, 8), Vector2(10, 8), Vector2(10, -16), Vector2(14, -16)
	])
	sword_poly.color = Color(0.7, 0.3, 1.0, 1.0)
	sword_poly.visible = false
	visual.add_child(sword_poly)

	# Void Eye Slit
	eye_poly = Polygon2D.new()
	eye_poly.polygon = PackedVector2Array([Vector2(-8, -40), Vector2(8, -40), Vector2(8, -36), Vector2(-8, -36)])
	eye_poly.color = Color(0.8, 0.2, 1.0, 1.0)
	eye_poly.visible = false
	visual.add_child(eye_poly)

	_build_boss_sprite()

	# Melee Slash Area
	slash_area = Area2D.new()
	slash_area.name = "SlashArea"
	slash_collision = CollisionShape2D.new()
	var s_shape := RectangleShape2D.new()
	s_shape.size = Vector2(105, 75)
	slash_collision.shape = s_shape
	slash_collision.position = Vector2(50, -35)
	slash_collision.disabled = true
	slash_area.add_child(slash_collision)
	slash_area.area_entered.connect(_on_slash_area_entered)
	visual.add_child(slash_area)

	slash_visual = Polygon2D.new()
	slash_visual.polygon = PackedVector2Array([Vector2(20, -50), Vector2(100, -20), Vector2(90, 35), Vector2(25, 15)])
	slash_visual.color = Color(0.8, 0.2, 1.0, 0.0)
	slash_visual.visible = false
	visual.add_child(slash_visual)


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
	var path_combat := "res://assets/enemy_frames/abyssal_arbiter_v2.png"
	var path_skills := "res://assets/enemy_frames/abyssal_arbiter_v2_skills.png"

	# 1. Combat Sprite Sheet (12 frames: Idle 0-3, Shadow Sprint 4-7, Void Greatsword Slash 8-11)
	var sheet := _load_texture_safe(path_combat)
	if sheet != null:
		var regions: Array[Rect2] = [
			Rect2(40, 62, 213, 229), Rect2(329, 62, 222, 230), Rect2(618, 62, 232, 230), Rect2(931, 61, 218, 231),
			Rect2(22, 370, 226, 215), Rect2(309, 370, 251, 216), Rect2(613, 370, 240, 216), Rect2(923, 370, 224, 216),
			Rect2(2, 606, 241, 279), Rect2(310, 607, 288, 280), Rect2(600, 670, 300, 215), Rect2(917, 617, 242, 268)
		]
		var pivots: Array[Vector2] = [
			Vector2(106, 224), Vector2(110, 225), Vector2(115, 225), Vector2(108, 226),
			Vector2(112, 210), Vector2(125, 211), Vector2(119, 211), Vector2(111, 211),
			Vector2(120, 274), Vector2(143, 275), Vector2(150, 210), Vector2(120, 263)
		]
		for i in range(12):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = regions[i]
			_sprite_frames.append(frame)
			_sprite_pivots.append(pivots[i])

	# 2. Skills Sprite Sheet (12 frames: Shadow Blink 12-15, Blade Ring 16-19, Defeat Vanish 20-23)
	var sheet_s := _load_texture_safe(path_skills)
	if sheet_s != null:
		var regions_s: Array[Rect2] = [
			Rect2(39, 61, 214, 231), Rect2(321, 61, 224, 231), Rect2(658, 84, 168, 208), Rect2(908, 60, 259, 232),
			Rect2(27, 323, 238, 265), Rect2(316, 336, 273, 252), Rect2(605, 355, 292, 233), Rect2(900, 356, 298, 232),
			Rect2(0, 652, 258, 233), Rect2(307, 676, 228, 218), Rect2(620, 675, 277, 219), Rect2(900, 727, 288, 167)
		]
		var pivots_s: Array[Vector2] = [
			Vector2(106, 226), Vector2(111, 226), Vector2(83, 203), Vector2(129, 227),
			Vector2(118, 260), Vector2(136, 247), Vector2(145, 228), Vector2(148, 227),
			Vector2(128, 228), Vector2(113, 215), Vector2(138, 216), Vector2(143, 166)
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
	# Imposing Chibi Void Champion Stature: 0.44 (~105px tall, 2.5-head Chibi dark knight proportion)
	boss_sprite.scale = Vector2.ONE * 0.44
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.position = Vector2.ZERO
	boss_sprite.modulate = Color.WHITE

	if not _sprite_frames.is_empty():
		boss_sprite.texture = _sprite_frames[0]
		boss_sprite.offset = -_sprite_pivots[0]
		print(">>> [ABYSSAL ARBITER] BossSprite initialized with %d frames! First frame size: %s" % [_sprite_frames.size(), _sprite_frames[0].get_size()])

	visual.add_child(boss_sprite)


func _build_collisions() -> void:
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 35.0
	shape.height = 100.0
	col.shape = shape
	col.position = Vector2(0, -50.0)
	add_child(col)

	# Dynamic Top Platform: allows player to stand and ride on top of Chibi Abyssal Arbiter head (~96px)
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(80.0, 16.0)
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

	_blink_cooldown = maxf(0.0, _blink_cooldown - delta)

	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_find_player()

	if is_instance_valid(_player) and not is_dead and state != State.SHADOW_BLINK:
		facing_direction = -1.0 if _player.global_position.x < global_position.x else 1.0
		visual.scale.x = facing_direction

	match state:
		State.CHASE:
			_process_chase(delta)
		State.VOID_SLASH:
			_process_void_slash(delta)
		State.SHADOW_BLINK:
			_process_shadow_blink(delta)
		State.BLADE_RING:
			_process_blade_ring(delta)
		State.FINAL_JUDGMENT:
			_process_final_judgment(delta)
		State.PHASE_TRANSITION:
			_process_phase_transition(delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if is_instance_valid(boss_sprite):
			boss_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	elif is_instance_valid(boss_sprite):
		if current_phase == 3:
			boss_sprite.modulate = Color(1.3, 0.4, 0.7, 1.0)
		elif current_phase == 2:
			boss_sprite.modulate = Color(0.9, 0.5, 1.3, 1.0)
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
				frame_idx = int(_walk_anim_timer) % 4
			State.CHASE:
				if absf(velocity.x) > 5.0:
					_walk_anim_timer += delta * 7.5
					frame_idx = 4 + (int(_walk_anim_timer) % 4)
				else:
					_walk_anim_timer += delta * 3.0
					frame_idx = int(_walk_anim_timer) % 4
			State.VOID_SLASH:
				if _phase_timer > 0.25:
					frame_idx = 8
				elif _phase_timer > 0.14:
					frame_idx = 9
				elif _phase_timer > 0.06:
					frame_idx = 10
				else:
					frame_idx = 11
			State.SHADOW_BLINK:
				if _phase_timer > 0.20:
					frame_idx = 12
				elif _phase_timer > 0.10:
					frame_idx = 13
				elif _phase_timer > 0.04:
					frame_idx = 14
				else:
					frame_idx = 15
			State.BLADE_RING:
				if _phase_timer > 0.30:
					frame_idx = 16
				elif _phase_timer > 0.20:
					frame_idx = 17
				elif _phase_timer > 0.10:
					frame_idx = 18
				else:
					frame_idx = 19
			State.FINAL_JUDGMENT:
				if _phase_timer > 0.45:
					frame_idx = 16
				elif _phase_timer > 0.30:
					frame_idx = 17
				elif _phase_timer > 0.15:
					frame_idx = 18
				else:
					frame_idx = 19
			State.PHASE_TRANSITION:
				var t_frame := int(floor(_phase_timer * 8.0)) % 2
				frame_idx = 12 if t_frame == 0 else 14
			State.DEAD:
				if _phase_timer > 0.75:
					frame_idx = 20
				elif _phase_timer > 0.50:
					frame_idx = 21
				elif _phase_timer > 0.25:
					frame_idx = 22
				else:
					frame_idx = 23

		if frame_idx < _sprite_frames.size():
			boss_sprite.texture = _sprite_frames[frame_idx]
			if frame_idx < _sprite_pivots.size():
				boss_sprite.offset = -_sprite_pivots[frame_idx]

	if state == State.DEAD:
		boss_sprite.modulate = Color(0.65, 0.45, 0.75, 0.9)
	elif _hit_flash_timer > 0.0:
		boss_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	elif current_phase == 3:
		var pulse := (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
		boss_sprite.modulate = Color(1.2, 0.25, 0.35).lerp(Color(1.5, 0.1, 0.1), pulse)
	elif current_phase == 2:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		boss_sprite.modulate = Color(0.7, 0.35, 1.1).lerp(Color(1.0, 0.2, 0.7), pulse)
	else:
		boss_sprite.modulate = Color.WHITE


func _process_chase(delta: float) -> void:
	_cooldown_timer -= delta
	if is_instance_valid(_player):
		var dist := absf(_player.global_position.x - global_position.x)
		if dist > 95.0:
			velocity.x = facing_direction * (move_speed if current_phase == 1 else move_speed * 1.3)
		else:
			velocity.x = 0.0

		if _cooldown_timer <= 0.0:
			_decide_action(dist)
	else:
		velocity.x = 0.0


func _decide_action(dist: float) -> void:
	_action_counter += 1

	if current_phase >= 2 and _action_counter % 3 == 0:
		_start_blade_ring()
		return

	if current_phase >= 3 and _action_counter % 4 == 0:
		_start_final_judgment()
		return

	if dist > 260.0 and _blink_cooldown <= 0.0:
		_start_shadow_blink()
	else:
		_start_void_slash()


func _start_void_slash() -> void:
	state = State.VOID_SLASH
	_phase_timer = 0.35 if current_phase == 1 else 0.22
	velocity.x = 0.0
	slash_visual.visible = false
	sword_poly.color = Color(1.0, 0.8, 0.2, 1.0)
	AudioManager.play("slash_2", global_position)


func _process_void_slash(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0 and not slash_collision.disabled:
		# End active attack
		slash_collision.disabled = true
		slash_visual.color = Color(0.8, 0.2, 1.0, 0.0)
		sword_poly.color = Color(0.7, 0.3, 1.0, 1.0)
		state = State.CHASE
		_cooldown_timer = 0.55 if current_phase == 1 else 0.30
	elif _phase_timer <= 0.0 and slash_collision.disabled:
		# Trigger active strike
		slash_collision.disabled = false
		velocity.x = facing_direction * 220.0
		_phase_timer = 0.18
		_spawn_void_slash_vfx()
		AudioManager.play("smash_3", global_position)
		GameFeelManager.shake(0.25)


func _start_shadow_blink() -> void:
	state = State.SHADOW_BLINK
	_phase_timer = 0.30
	_blink_cooldown = 3.0 if current_phase == 1 else 1.8
	velocity = Vector2.ZERO
	_spawn_shadow_blink_vfx(global_position)
	AudioManager.play("counter_hit", global_position)
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.25)


func _process_shadow_blink(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		if is_instance_valid(_player):
			# Reappear behind player
			var behind_x: float = _player.global_position.x + (70.0 if _player.facing_direction < 0.0 else -70.0)
			global_position.x = behind_x
		teleported.emit(global_position)
		_spawn_shadow_blink_vfx(global_position)
		visual.modulate.a = 1.0
		AudioManager.play("pogo_bounce", global_position)
		GameFeelManager.shake(0.20)
		_start_void_slash()


func _start_blade_ring() -> void:
	state = State.BLADE_RING
	_phase_timer = 0.40
	velocity.x = 0.0
	AudioManager.play("slash_1", global_position)


func _process_blade_ring(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_cast_blade_ring()
		state = State.CHASE
		_cooldown_timer = 0.60


func _cast_blade_ring() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	AudioManager.play("smash_3", global_position)
	GameFeelManager.shake(0.35)

	var angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	for a in angles:
		var blade := BladeScene.new()
		blade.position = global_position + Vector2(0, -15)
		blade.direction = Vector2(cos(a), sin(a))
		parent.add_child(blade)

	blade_ring_cast.emit(global_position)


func _start_final_judgment() -> void:
	state = State.FINAL_JUDGMENT
	_phase_timer = 0.60
	velocity = Vector2.ZERO
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.50)


func _process_final_judgment(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		# Emit ground dark wave shockwaves
		var parent := get_parent()
		if is_instance_valid(parent):
			var wave_l := ShockwaveScene.new()
			wave_l.position = position + Vector2(-30, 20)
			wave_l.direction = -1.0
			parent.add_child(wave_l)

			var wave_r := ShockwaveScene.new()
			wave_r.position = position + Vector2(30, 20)
			wave_r.direction = 1.0
			parent.add_child(wave_r)

		_spawn_judgment_cross_vfx()
		state = State.CHASE
		_cooldown_timer = 0.50


func _on_slash_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		if target.has_method("receive_attack"):
			target.receive_attack(global_position, true)
		elif target.has_method("receive_hit"):
			target.receive_hit()


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
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(randf_range(-15, 15), -45), "1", dmg_color, is_counter)
	GameFeelManager.trigger_hit_stop(0.06, 0.03)
	GameFeelManager.shake(0.25)
	AudioManager.play("counter_hit", global_position)
	_hit_flash_timer = 0.12

	if current_hp <= 0:
		_die()
		return

	# Phase Transitions: Phase 2 at <= 16 HP, Phase 3 at <= 8 HP
	if current_phase == 1 and current_hp <= 16:
		_trigger_phase_two()
	elif current_phase == 2 and current_hp <= 8:
		_trigger_phase_three()


func _trigger_phase_two() -> void:
	current_phase = 2
	boss_phase_changed.emit(2)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.6
	is_invulnerable = true
	aura_poly.visible = false
	body_poly.color = Color(0.35, 0.15, 0.45, 1.0)
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(0.9, 0.5, 1.3, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.55)
	GameFeelManager.trigger_hit_stop(0.12, 0.08)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "VOID RIFT OPENED!", Color(0.7, 0.2, 1.0), true)


func _trigger_phase_three() -> void:
	current_phase = 3
	final_judgment = true
	boss_phase_changed.emit(3)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.7
	is_invulnerable = true
	wing_left.visible = false
	wing_right.visible = false
	eye_poly.color = Color(1.0, 0.1, 0.1, 1.0)
	body_poly.color = Color(0.45, 0.10, 0.25, 1.0)
	aura_poly.visible = false
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(1.3, 0.4, 0.7, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.75)
	GameFeelManager.trigger_hit_stop(0.18, 0.08)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -60), "FINAL JUDGMENT!", Color(1.0, 0.1, 0.2), true)


func _process_phase_transition(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	if is_instance_valid(boss_sprite):
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.04) * 0.35
		var base_col := Color(1.3, 0.4, 0.7, 1.0) if current_phase == 3 else Color(0.9, 0.5, 1.3, 1.0)
		boss_sprite.modulate = base_col * pulse
	if _phase_timer <= 0.0:
		is_invulnerable = false
		state = State.CHASE
		_cooldown_timer = 0.2


func _die() -> void:
	is_dead = true
	state = State.DEAD
	_phase_timer = 1.0
	var top_plat: AnimatableBody2D = get_node_or_null("TopPlatform") as AnimatableBody2D
	if top_plat != null and top_plat.get_child_count() > 0:
		var shape: CollisionShape2D = top_plat.get_child(0) as CollisionShape2D
		if shape != null:
			shape.set_deferred("disabled", true)
	aura_poly.visible = false
	body_poly.color = Color(0.15, 0.15, 0.15, 0.8)
	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color(0.4, 0.4, 0.4, 0.8)

	GameFeelManager.trigger_hit_stop(0.80, 0.15)
	GameFeelManager.shake(0.85)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -60), "CAMPAIGN CONQUERED! ALL 5 REALMS CLEARED", Color(1.0, 0.85, 0.2), true)

	_spawn_shard_burst(25)
	boss_defeated.emit()

	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 2.0).set_delay(0.5)
	tween.tween_callback(queue_free)


func _spawn_shard_burst(count: int) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	for i in range(count):
		var shard := ShardScene.new()
		shard.value = 1
		shard.position = position + Vector2(randf_range(-35, 35), randf_range(-30, 0))
		shard.init_velocity(Vector2(randf_range(-180.0, 180.0), randf_range(-280.0, -450.0)))
		shard.ground_y = position.y + 30.0
		parent.add_child(shard)


func _spawn_void_slash_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "ArbiterVoidSlashVFX"
	vfx.position = position + Vector2(facing_direction * 40.0, -5.0)
	vfx.z_index = 9
	parent.add_child(vfx)

	# 1. Outer Dark Violet Arc
	var outer_arc := Line2D.new()
	outer_arc.width = 7.0
	outer_arc.default_color = Color(0.8, 0.2, 1.0, 0.95) if current_phase < 3 else Color(1.2, 0.1, 0.3, 1.0)
	var pts := PackedVector2Array()
	for i in range(9):
		var ang := -PI * 0.38 + (float(i) / 8.0) * PI * 0.76
		pts.append(Vector2(cos(ang) * 58.0 * facing_direction, sin(ang) * 58.0))
	outer_arc.points = pts
	vfx.add_child(outer_arc)

	# 2. Inner Pure White Core Blade
	var inner_core := Line2D.new()
	inner_core.width = 3.5
	inner_core.default_color = Color.WHITE
	var core_pts := PackedVector2Array()
	for i in range(9):
		var ang := -PI * 0.35 + (float(i) / 8.0) * PI * 0.70
		core_pts.append(Vector2(cos(ang) * 50.0 * facing_direction, sin(ang) * 50.0))
	inner_core.points = core_pts
	vfx.add_child(inner_core)

	# 3. Void Blade Shards
	var shard_count := 8
	var shard_nodes: Array[Polygon2D] = []
	var shard_vels: Array[Vector2] = []
	for i in range(shard_count):
		var p := Polygon2D.new()
		var sz := randf_range(3.0, 6.0)
		p.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
		p.color = Color(0.7, 0.15, 0.95, 1.0)
		vfx.add_child(p)
		shard_nodes.append(p)
		var spd := randf_range(160.0, 340.0)
		var sp_ang := randf_range(-PI * 0.35, PI * 0.35)
		if facing_direction < 0.0:
			sp_ang = PI - sp_ang
		shard_vels.append(Vector2(cos(sp_ang), sin(sp_ang)) * spd)

	var duration := 0.25
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.3, 0.3)
	tween.tween_property(vfx, "scale", Vector2(1.35, 1.35), duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "position:x", vfx.position.x + facing_direction * 40.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(shard_nodes.size()):
		var p := shard_nodes[i]
		var v := shard_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.35)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(vfx.queue_free)


func _spawn_shadow_blink_vfx(pos: Vector2) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "ArbiterBlinkVFX"
	vfx.position = pos
	vfx.z_index = 8
	parent.add_child(vfx)

	var puff_count := 8
	var puff_nodes: Array[Polygon2D] = []
	var puff_vels: Array[Vector2] = []
	for i in range(puff_count):
		var p := Polygon2D.new()
		var sz := randf_range(5.0, 10.0)
		p.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
		p.color = Color(0.2, 0.08, 0.3, 0.8)
		vfx.add_child(p)
		puff_nodes.append(p)
		var spd := randf_range(80.0, 200.0)
		var a := float(i) / float(puff_count) * TAU
		puff_vels.append(Vector2(cos(a), sin(a)) * spd)

	var duration := 0.30
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	for i in range(puff_nodes.size()):
		var p := puff_nodes[i]
		var v := puff_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.3)
	tween.chain().tween_callback(vfx.queue_free)


func _spawn_judgment_cross_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "ArbiterJudgmentCrossVFX"
	vfx.position = position
	vfx.z_index = 10
	parent.add_child(vfx)

	# Horizontal Beam
	var h_line := Line2D.new()
	h_line.width = 8.0
	h_line.default_color = Color(1.3, 0.15, 0.2, 1.0)
	h_line.points = PackedVector2Array([Vector2(-120, 0), Vector2(120, 0)])
	vfx.add_child(h_line)

	# Vertical Beam
	var v_line := Line2D.new()
	v_line.width = 8.0
	v_line.default_color = Color(1.3, 0.15, 0.2, 1.0)
	v_line.points = PackedVector2Array([Vector2(0, -90), Vector2(0, 90)])
	vfx.add_child(v_line)

	var duration := 0.40
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.2, 0.2)
	tween.tween_property(vfx, "scale", Vector2(1.8, 1.8), duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
	tween.chain().tween_callback(vfx.queue_free)
