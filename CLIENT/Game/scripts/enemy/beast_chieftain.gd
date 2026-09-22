class_name BeastChieftain
extends CharacterBody2D
## Stage 2 Gate Boss: 'Abyssal Beast Chieftain' (심연의 맹수 우두머리)
## Fast predatory encounter featuring Triple Pounce, Wild Claws, Shockwave Leaps,
## and 2-Phase Blood Frenzy enrage at <= 50% HP.

signal boss_hp_changed(current: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated
signal emit_shockwave(pos: Vector2, dir: float)

enum State {
	IDLE,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_ACTIVE,
	ATTACK_RECOVERY,
	LEAP_SLAM,
	ROAR,
	STUNNED,
	PHASE_TRANSITION,
	DEAD
}

enum Pattern {
	POUNCE_CHARGE,
	WILD_CLAW,
	INTIMIDATING_ROAR,
	BLOOD_LEAP_SLAM,
	RAGING_RUSH
}

@export var max_hp: int = 14
var current_hp: int = 14
var current_phase: int = 1
var blood_frenzy: bool = false
var state: State = State.CHASE
var current_pattern: Pattern = Pattern.POUNCE_CHARGE

var move_speed: float = 140.0
var facing_direction: float = -1.0
var attack_range: float = 95.0
var detection_range: float = 9999.0
var gravity: float = 980.0
var is_dead: bool = false
var is_invulnerable: bool = false

var _phase_timer: float = 0.0
var _hit_stun_timer: float = 0.0
var _attack_cooldown: float = 0.70
var _cooldown_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _action_counter: int = 0

var visual: Node2D
var boss_sprite: Sprite2D = null
var _sprite_frames: Array[AtlasTexture] = []
var _sprite_pivots: Array[Vector2] = []
var _anim_timer: float = 0.0
var _walk_anim_timer: float = 0.0
var _current_frame_idx: int = 0
var _phase2_frames: Array[AtlasTexture] = []
var body_poly: Polygon2D
var fur_poly: Polygon2D
var eye_poly: Polygon2D
var aura_poly: Polygon2D
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

	# Enrage Blood Aura
	aura_poly = Polygon2D.new()
	aura_poly.polygon = PackedVector2Array([
		Vector2(-48, -40), Vector2(48, -40), Vector2(56, 0),
		Vector2(40, 30), Vector2(-40, 30), Vector2(-56, 0)
	])
	aura_poly.color = Color(1.0, 0.12, 0.1, 0.4)
	aura_poly.visible = false
	visual.add_child(aura_poly)

	# Primitive placeholders (hidden in favor of high-res beast sprite)
	body_poly = Polygon2D.new()
	body_poly.polygon = PackedVector2Array([
		Vector2(-36, -26), Vector2(24, -26), Vector2(42, -10),
		Vector2(32, 24), Vector2(-28, 24), Vector2(-42, 0)
	])
	body_poly.color = Color(0.24, 0.18, 0.22, 1.0)
	body_poly.visible = false
	visual.add_child(body_poly)

	fur_poly = Polygon2D.new()
	fur_poly.polygon = PackedVector2Array([
		Vector2(-30, -38), Vector2(-15, -26), Vector2(0, -42),
		Vector2(15, -26), Vector2(30, -36), Vector2(20, -20), Vector2(-25, -20)
	])
	fur_poly.color = Color(0.38, 0.25, 0.32, 1.0)
	fur_poly.visible = false
	visual.add_child(fur_poly)

	eye_poly = Polygon2D.new()
	eye_poly.polygon = PackedVector2Array([
		Vector2(22, -18), Vector2(32, -18), Vector2(30, -14), Vector2(24, -14)
	])
	eye_poly.color = Color(1.0, 0.85, 0.2, 1.0)
	eye_poly.visible = false
	visual.add_child(eye_poly)

	_build_boss_sprite()


func _build_boss_sprite() -> void:
	var dedicated_path := "res://assets/enemy_frames/beast_chief_v1.png"
	var file_path := dedicated_path if ResourceLoader.exists(dedicated_path) else "res://assets/enemy_frames/beast_v1.png"
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
					Rect2(512, 0, 512, 500),
					Rect2(1024, 0, 512, 500),
					Rect2(0, 500, 512, 524),
					Rect2(512, 500, 512, 524),
					Rect2(1024, 500, 512, 524)
				]
				for i in range(6):
					pivots.append(Vector2(256, 480))
			for i in range(6):
				var frame := AtlasTexture.new()
				frame.atlas = sheet
				frame.region = regions[i]
				_sprite_frames.append(frame)
				_sprite_pivots.append(pivots[i])

	var p2_path := "res://assets/enemy_frames/beast_v2.png"
	if ResourceLoader.exists(p2_path):
		var p2_sheet := load(p2_path) as Texture2D
		if p2_sheet != null:
			var regions := [
				Rect2(0, 0, 512, 500),
				Rect2(512, 0, 512, 500),
				Rect2(1024, 0, 512, 500),
				Rect2(0, 500, 512, 524),
				Rect2(512, 500, 512, 524),
				Rect2(1024, 500, 512, 524)
			]
			for i in range(6):
				var frame := AtlasTexture.new()
				frame.atlas = p2_sheet
				frame.region = regions[i]
				_phase2_frames.append(frame)

	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossSprite"
	boss_sprite.centered = false
	boss_sprite.scale = Vector2.ONE * 0.19
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.position = Vector2(0, 27)

	if not _sprite_frames.is_empty():
		boss_sprite.texture = _sprite_frames[0]
		boss_sprite.offset = -_sprite_pivots[0]

	visual.add_child(boss_sprite)


func _build_collisions() -> void:
	var body_col := CollisionShape2D.new()
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(72, 54)
	body_col.shape = body_shape
	body_col.position = Vector2(0, 0)
	add_child(body_col)

	# Dynamic Top Platform: allows player to stand and ride on top of Beast
	var top_platform := AnimatableBody2D.new()
	top_platform.name = "TopPlatform"
	top_platform.collision_layer = 1
	top_platform.collision_mask = 0
	top_platform.sync_to_physics = false
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(64.0, 12.0)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0.0, -28.0)
	top_shape.one_way_collision = true
	top_platform.add_child(top_shape)
	add_child(top_platform)
	add_collision_exception_with(top_platform)
	top_platform.add_collision_exception_with(self)

	hurt_area = Area2D.new()
	hurt_area.name = "HurtArea"
	hurt_area.collision_layer = 2
	hurt_area.collision_mask = 0
	var hurt_col := CollisionShape2D.new()
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = Vector2(76, 58)
	hurt_col.shape = hurt_shape
	hurt_area.add_child(hurt_col)
	add_child(hurt_area)

	attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	attack_collision = CollisionShape2D.new()
	var at_shape := RectangleShape2D.new()
	at_shape.size = Vector2(90, 60)
	attack_collision.shape = at_shape
	attack_collision.position = Vector2(50, 0)
	attack_collision.disabled = true
	attack_area.add_child(attack_collision)

	attack_visual = Polygon2D.new()
	attack_visual.polygon = PackedVector2Array([
		Vector2(5, -30), Vector2(90, -20), Vector2(90, 25), Vector2(5, 30)
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

	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_find_player()
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_restore_base_color()

	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	if not is_on_floor():
		velocity.y += gravity * delta

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
		State.ROAR:
			_process_roar(delta)
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

	var frames := _phase2_frames if (current_phase == 2 and not _phase2_frames.is_empty()) else _sprite_frames
	if not frames.is_empty():
		var frame_idx := 0
		match state:
			State.IDLE:
				frame_idx = 0
			State.CHASE:
				if absf(velocity.x) > 5.0:
					_walk_anim_timer += delta * 7.0
					frame_idx = 1 if int(_walk_anim_timer) % 2 == 0 else 2
				else:
					frame_idx = 0
			State.ATTACK_WINDUP:
				frame_idx = 3
			State.ATTACK_ACTIVE:
				frame_idx = 4
			State.ATTACK_RECOVERY:
				frame_idx = 5
			State.ROAR:
				frame_idx = 3
			State.LEAP_SLAM:
				frame_idx = 4 if is_on_floor() else 3
			State.STUNNED:
				frame_idx = 5
			State.PHASE_TRANSITION:
				frame_idx = 3
			State.DEAD:
				frame_idx = 5

		if frame_idx < frames.size():
			boss_sprite.texture = frames[frame_idx]
			if frame_idx < _sprite_pivots.size():
				boss_sprite.offset = -_sprite_pivots[frame_idx]

	if _hit_flash_timer > 0.0:
		boss_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	elif current_phase == 2:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		boss_sprite.modulate = Color(1.0, 0.4, 0.35).lerp(Color(1.3, 0.2, 0.15), pulse)
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
		var pick := _action_counter % 3
		match pick:
			0:
				_start_attack(Pattern.POUNCE_CHARGE, 0.60, 0.25, true)
			1:
				_start_attack(Pattern.WILD_CLAW, 0.50, 0.20, true)
			2:
				_start_roar()
	else:
		var pick := _action_counter % 3
		match pick:
			0:
				_start_leap_slam()
			1:
				_start_attack(Pattern.RAGING_RUSH, 0.45, 0.30, false)
			2:
				_start_attack(Pattern.POUNCE_CHARGE, 0.45, 0.22, true)


func _start_attack(pattern: Pattern, windup: float, active_time: float, blockable: bool) -> void:
	state = State.ATTACK_WINDUP
	current_pattern = pattern
	_phase_timer = windup
	velocity.x = 0.0

	var color := Color(1.0, 0.82, 0.2, 0.8) if blockable else Color(1.0, 0.15, 0.1, 0.9)
	attack_visual.color = color
	body_poly.color = color
	AudioManager.play("slash_1", global_position)


func _process_attack_windup(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.ATTACK_ACTIVE
		attack_collision.disabled = false
		_phase_timer = 0.24

		if current_pattern == Pattern.POUNCE_CHARGE:
			velocity.x = facing_direction * 340.0
			AudioManager.play("smash_3", global_position)
		elif current_pattern == Pattern.RAGING_RUSH:
			velocity.x = facing_direction * 480.0
			AudioManager.play("smash_3", global_position)
		else:
			velocity.x = facing_direction * 160.0
			AudioManager.play("slash_2", global_position)

		_spawn_beast_attack_vfx(current_pattern, facing_direction)


func _process_attack_active(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		attack_collision.disabled = true
		state = State.ATTACK_RECOVERY
		_phase_timer = 0.30 if current_phase == 1 else 0.18
		velocity.x = 0.0
		_restore_base_color()


func _process_attack_recovery(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.CHASE
		_cooldown_timer = _attack_cooldown if current_phase == 1 else _attack_cooldown * 0.60


func _start_roar() -> void:
	state = State.ROAR
	_phase_timer = 0.55
	velocity.x = 0.0
	body_poly.color = Color(0.9, 0.4, 0.6)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.35)

	# Knock player back
	if is_instance_valid(_player) and not _player.is_queued_for_deletion():
		if "velocity" in _player:
			_player.velocity.x = -facing_direction * 260.0


func _process_roar(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		state = State.CHASE
		_cooldown_timer = 0.4
		_restore_base_color()


func _start_leap_slam() -> void:
	state = State.LEAP_SLAM
	_phase_timer = 0.0
	velocity.y = -620.0
	velocity.x = facing_direction * 200.0
	body_poly.color = Color(1.0, 0.1, 0.1)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.30)


func _process_leap_slam(delta: float) -> void:
	if velocity.y > 0.0:
		velocity.y += 700.0 * delta

	if is_on_floor() and velocity.y >= 0.0:
		_emit_shockwaves()
		_spawn_slam_impact_vfx()
		GameFeelManager.shake(0.60)
		GameFeelManager.trigger_hit_stop(0.08, 0.0)
		AudioManager.play("smash_3", global_position)
		state = State.ATTACK_RECOVERY
		_phase_timer = 0.35
		velocity.x = 0.0
		_restore_base_color()


func _emit_shockwaves() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	var wave_left := ShockwaveScene.new()
	wave_left.position = Vector2(position.x - 30.0, position.y + 20.0)
	wave_left.direction = -1.0
	parent.add_child(wave_left)
	emit_shockwave.emit(wave_left.position, -1.0)

	var wave_right := ShockwaveScene.new()
	wave_right.position = Vector2(position.x + 30.0, position.y + 20.0)
	wave_right.direction = 1.0
	parent.add_child(wave_right)
	emit_shockwave.emit(wave_right.position, 1.0)


func _trigger_blood_slam() -> void:
	_emit_shockwaves()


func take_damage(amount: int = 1, _from_dir: Vector2 = Vector2.ZERO) -> void:
	for i in range(amount):
		if is_dead:
			break
		receive_hit()


func _process_stunned(delta: float) -> void:
	_hit_stun_timer -= delta
	velocity.x = 0.0
	if _hit_stun_timer <= 0.0:
		state = State.CHASE
		_restore_base_color()


func _process_phase_transition(delta: float) -> void:
	_phase_timer -= delta
	velocity.x = 0.0
	aura_poly.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.04) * 0.3)
	if _phase_timer <= 0.0:
		is_invulnerable = false
		state = State.CHASE
		_start_leap_slam()


func receive_hit() -> void:
	if is_dead or is_invulnerable:
		return

	current_hp -= 1
	boss_hp_changed.emit(current_hp, max_hp)

	var is_counter := has_meta("counter_stunned")
	var dmg_color := Color(0.3, 0.95, 1.0) if is_counter else Color(1.0, 0.9, 0.4)
	var dmg_text := "2! CRIT" if is_counter else "1"
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(randf_range(-15, 15), -40), dmg_text, dmg_color, is_counter)

	GameFeelManager.trigger_hit_stop(0.08 if is_counter else 0.04, 0.03)
	GameFeelManager.shake(0.30 if is_counter else 0.18)

	if current_hp <= 0:
		_die()
		return

	if current_phase == 1 and current_hp <= max_hp / 2:
		_trigger_phase_two()
		return

	if is_counter:
		var dur: float = float(get_meta("counter_stunned"))
		remove_meta("counter_stunned")
		state = State.STUNNED
		_hit_stun_timer = dur
		attack_collision.disabled = true
		body_poly.color = Color(0.4, 0.85, 1.0)
	else:
		_hit_flash_timer = 0.12
		body_poly.color = Color.WHITE


func _trigger_phase_two() -> void:
	current_phase = 2
	blood_frenzy = true
	boss_phase_changed.emit(2)
	state = State.PHASE_TRANSITION
	_phase_timer = 0.6
	is_invulnerable = true
	move_speed = 195.0
	attack_collision.disabled = true
	aura_poly.visible = true
	eye_poly.color = Color(1.0, 0.1, 0.1, 1.0)

	AudioManager.play("counter_hit", global_position)
	GameFeelManager.shake(0.50)
	GameFeelManager.trigger_hit_stop(0.12, 0.0)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "BLOOD FRENZY!", Color(1.0, 0.1, 0.1), true)


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

	GameFeelManager.trigger_hit_stop(0.60, 0.15)
	GameFeelManager.shake(0.65)
	AudioManager.play("counter_hit", global_position)
	GameFeelManager.damage_popup(get_parent() as Node2D, global_position + Vector2(0, -50), "STAGE 2 CONQUERED", Color(1.0, 0.85, 0.2), true)

	_spawn_shard_burst(12)
	boss_defeated.emit()

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
		shard.position = position + Vector2(randf_range(-25, 25), randf_range(-20, 0))
		shard.init_velocity(Vector2(randf_range(-150.0, 150.0), randf_range(-240.0, -380.0)))
		shard.ground_y = position.y + 25.0
		parent.add_child(shard)


func _on_attack_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		var is_blockable := (current_pattern != Pattern.RAGING_RUSH)
		if target.has_method("receive_attack"):
			target.receive_attack(global_position, is_blockable)
		elif target.has_method("receive_hit"):
			target.receive_hit()


func _restore_base_color() -> void:
	body_poly.color = Color(0.38, 0.18, 0.25, 1.0) if current_phase == 2 else Color(0.24, 0.18, 0.22, 1.0)
	attack_visual.color = Color(1.0, 0.3, 0.1, 0.0)


func _spawn_beast_attack_vfx(pattern: Pattern, facing_dir: float) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "BeastClawVFX"
	vfx.position = position + Vector2(facing_dir * 35.0, 5.0)
	vfx.z_index = 8
	parent.add_child(vfx)

	# 3-Slash Beast Claw Arcs
	var claw_offsets := [-14.0, 0.0, 14.0]
	var claw_color := Color(1.0, 0.25, 0.1, 0.95) if current_phase == 2 else Color(1.0, 0.65, 0.2, 0.9)
	if pattern == Pattern.RAGING_RUSH:
		claw_color = Color(1.2, 0.15, 0.1, 1.0)

	for off_y in claw_offsets:
		var line := Line2D.new()
		line.width = 4.5
		line.default_color = claw_color
		var pts := PackedVector2Array()
		for i in range(6):
			var t := float(i) / 5.0
			var ang := -PI * 0.25 + t * PI * 0.5
			var r := 48.0 if pattern == Pattern.RAGING_RUSH else 40.0
			var pt := Vector2(cos(ang) * r * facing_dir, sin(ang) * r + off_y)
			pts.append(pt)
		line.points = pts
		vfx.add_child(line)

	# Blood Spark Particles
	var spark_count := 8
	var spark_nodes: Array[Polygon2D] = []
	var spark_vels: Array[Vector2] = []
	for i in range(spark_count):
		var p := Polygon2D.new()
		var sz := randf_range(3.0, 5.0)
		p.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
		p.color = Color(1.0, 0.2, 0.1, 1.0)
		vfx.add_child(p)
		spark_nodes.append(p)
		var spd := randf_range(160.0, 320.0)
		var sp_ang := randf_range(-PI * 0.3, PI * 0.3)
		if facing_dir < 0.0:
			sp_ang = PI - sp_ang
		spark_vels.append(Vector2(cos(sp_ang), sin(sp_ang)) * spd)

	var duration := 0.25
	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.4, 0.4)
	tween.tween_property(vfx, "scale", Vector2(1.25, 1.25), duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "position:x", vfx.position.x + facing_dir * 35.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(spark_nodes.size()):
		var p := spark_nodes[i]
		var v := spark_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.4)
	tween.tween_property(vfx, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(vfx.queue_free)


func _spawn_slam_impact_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "BeastSlamVFX"
	vfx.position = position + Vector2(0, 20.0)
	vfx.z_index = 8
	parent.add_child(vfx)

	# Shockwave Impact Dust Ring
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.3, 0.15, 0.9)
	var pts := PackedVector2Array()
	for i in range(13):
		var ang := float(i) / 12.0 * TAU
		pts.append(Vector2(cos(ang) * 45.0, sin(ang) * 16.0))
	ring.points = pts
	vfx.add_child(ring)

	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.2, 0.2)
	tween.tween_property(vfx, "scale", Vector2(1.8, 1.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(vfx.queue_free)
