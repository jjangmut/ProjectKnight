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

	# Void Aura
	aura_poly = Polygon2D.new()
	aura_poly.polygon = PackedVector2Array([
		Vector2(-42, -50), Vector2(42, -50), Vector2(50, 5),
		Vector2(38, 42), Vector2(-38, 42), Vector2(-50, 5)
	])
	aura_poly.color = Color(0.45, 0.1, 0.8, 0.4)
	aura_poly.visible = false
	visual.add_child(aura_poly)

	# Black Wings (Revealed in Phase 3)
	wing_left = Polygon2D.new()
	wing_left.polygon = PackedVector2Array([Vector2(-10, -20), Vector2(-60, -65), Vector2(-45, -10), Vector2(-20, 0)])
	wing_left.color = Color(0.12, 0.05, 0.2, 0.95)
	wing_left.visible = false
	visual.add_child(wing_left)

	wing_right = Polygon2D.new()
	wing_right.polygon = PackedVector2Array([Vector2(10, -20), Vector2(60, -65), Vector2(45, -10), Vector2(20, 0)])
	wing_right.color = Color(0.12, 0.05, 0.2, 0.95)
	wing_right.visible = false
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
	s_shape.size = Vector2(75, 45)
	slash_collision.shape = s_shape
	slash_collision.position = Vector2(38, -6)
	slash_collision.disabled = true
	slash_area.add_child(slash_collision)
	slash_area.area_entered.connect(_on_slash_area_entered)
	visual.add_child(slash_area)

	slash_visual = Polygon2D.new()
	slash_visual.polygon = PackedVector2Array([Vector2(10, -30), Vector2(78, -10), Vector2(70, 20), Vector2(15, 10)])
	slash_visual.color = Color(0.8, 0.2, 1.0, 0.0)
	visual.add_child(slash_visual)


func _build_boss_sprite() -> void:
	var dedicated_path := "res://assets/enemy_frames/arbiter_v1.png"
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
	boss_sprite.scale = Vector2.ONE * 0.20
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.position = Vector2(0, 36)
	boss_sprite.modulate = Color(0.85, 0.75, 1.0)

	if not _sprite_frames.is_empty():
		boss_sprite.texture = _sprite_frames[0]
		boss_sprite.offset = -_sprite_pivots[0]

	visual.add_child(boss_sprite)


func _build_collisions() -> void:
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 22.0
	shape.height = 76.0
	col.shape = shape
	col.position = Vector2(0, -2)
	add_child(col)

	# Dynamic Top Platform: allows player to stand and ride on top of Abyssal Arbiter
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(52.0, 10.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -38.0)
	top_shape.one_way_collision = true
	top_platform.add_child(top_shape)
	add_child(top_platform)
	add_collision_exception_with(top_platform)
	top_platform.add_collision_exception_with(self)

	var hurt_area := Area2D.new()
	hurt_area.name = "HurtArea"
	var hurt_col := CollisionShape2D.new()
	var hurt_shape := CapsuleShape2D.new()
	hurt_shape.radius = 26.0
	hurt_shape.height = 80.0
	hurt_col.shape = hurt_shape
	hurt_col.position = Vector2(0, -2)
	hurt_area.add_child(hurt_col)
	add_child(hurt_area)


func _physics_process(delta: float) -> void:
	if is_dead:
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
			State.VOID_SLASH:
				frame_idx = 4
			State.SHADOW_BLINK:
				frame_idx = 3
			State.BLADE_RING:
				frame_idx = 3
			State.FINAL_JUDGMENT:
				frame_idx = 4
			State.PHASE_TRANSITION:
				frame_idx = 3
			State.DEAD:
				frame_idx = 5

		if frame_idx < _sprite_frames.size():
			boss_sprite.texture = _sprite_frames[frame_idx]
			if frame_idx < _sprite_pivots.size():
				boss_sprite.offset = -_sprite_pivots[frame_idx]

	if _hit_flash_timer > 0.0:
		boss_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	elif current_phase == 3:
		var pulse := (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
		boss_sprite.modulate = Color(1.2, 0.25, 0.35).lerp(Color(1.5, 0.1, 0.1), pulse)
	elif current_phase == 2:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		boss_sprite.modulate = Color(0.7, 0.35, 1.1).lerp(Color(1.0, 0.2, 0.7), pulse)
	else:
		boss_sprite.modulate = Color(0.85, 0.75, 1.0)


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
	slash_visual.color = Color(0.8, 0.2, 1.0, 0.7)
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
	aura_poly.visible = true
	body_poly.color = Color(0.35, 0.15, 0.45, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.55)
	GameFeelManager.trigger_hit_stop(0.12, 0.0)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "VOID RIFT OPENED!", Color(0.7, 0.2, 1.0), true)


func _trigger_phase_three() -> void:
	current_phase = 3
	final_judgment = true
	boss_phase_changed.emit(3)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.7
	is_invulnerable = true
	wing_left.visible = true
	wing_right.visible = true
	eye_poly.color = Color(1.0, 0.1, 0.1, 1.0)
	body_poly.color = Color(0.45, 0.10, 0.25, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.75)
	GameFeelManager.trigger_hit_stop(0.18, 0.0)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -60), "FINAL JUDGMENT!", Color(1.0, 0.1, 0.2), true)


func _process_phase_transition(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	aura_poly.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.04) * 0.3)
	if _phase_timer <= 0.0:
		is_invulnerable = false
		state = State.CHASE
		_cooldown_timer = 0.2


func _die() -> void:
	is_dead = true
	state = State.DEAD
	var top_plat: AnimatableBody2D = get_node_or_null("TopPlatform") as AnimatableBody2D
	if top_plat != null and top_plat.get_child_count() > 0:
		var shape: CollisionShape2D = top_plat.get_child(0) as CollisionShape2D
		if shape != null:
			shape.set_deferred("disabled", true)
	aura_poly.visible = false
	body_poly.color = Color(0.15, 0.15, 0.15, 0.8)

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
