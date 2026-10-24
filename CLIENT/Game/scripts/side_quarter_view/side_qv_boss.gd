extends CharacterBody3D
class_name SideQVBossCommander
## 사이드 쿼터뷰 2D 보스 기사 지휘관 (2D Sprite Boss in 3D Space)
## - 2D 고해상도 지휘관 스프라이트 (Sprite3D) 탑재 & 실시간 3D 그림자 투영
## - 12.0 m/s 사이드 방패 돌진, 360도 지진 충격파 링, 2페이즈 광폭화 오라

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)

enum Pattern {
	IDLE,
	CHASE,
	TRIPLE_CLEAVE,
	SHIELD_CHARGE,
	QUAKE_RING,
	STUNNED
}

@export var max_hp: int = 24
@export var current_hp: int = 24
@export var move_speed: float = 3.8
@export var charge_speed: float = 12.0
@export var charge_damage: int = 2

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var is_stunned: bool:
	get:
		return current_pattern == Pattern.STUNNED
var pattern_timer: float = 0.0
var stun_timer: float = 0.0
var target_player: Node3D = null
var facing_dir_x: float = -1.0 # Typically faces player to the left

var sprite_3d: Sprite3D
var aura_ring_3d: MeshInstance3D
var attack_area_3d: Area3D

const BossTextureNormal = preload("res://assets/enemy_frames/boss_commander_v2.png")
const BossTextureDefense = preload("res://assets/enemy_frames/boss_commander_v2_defense.png")


var anim_frame_timer: float = 0.0
var anim_frame_idx: int = 0


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")
	add_to_group("bosses")

	_build_components()
	emit_signal("boss_hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite Sheet 4x3 frames, ~2.45m height)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "BossSprite3D"
	sprite_3d.texture = BossTextureNormal
	sprite_3d.hframes = 4
	sprite_3d.vframes = 3
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.0082 # 298.66px * 0.0082 = 2.45m tall
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 1.22
	sprite_3d.flip_h = true # Initially face Left towards the player on the left
	add_child(sprite_3d)

	# 2. Crimson Aura Ring (Phase 2 Enrage)
	aura_ring_3d = MeshInstance3D.new()
	aura_ring_3d.name = "CrimsonAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.4
	torus.outer_radius = 1.65
	aura_ring_3d.mesh = torus

	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(2.5, 0.3, 0.3, 1.0)
	amat.emission_enabled = true
	amat.emission = Color(2.5, 0.3, 0.3, 1.0)
	amat.emission_energy_multiplier = 4.0
	aura_ring_3d.material_override = amat
	aura_ring_3d.position.y = 0.2
	aura_ring_3d.visible = false
	add_child(aura_ring_3d)

	# 3. Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.65
	cap.height = 2.4
	col.shape = cap
	col.position.y = 1.2
	add_child(col)

	# 4. Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "BossAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 2.0, 2.2)
	atk_shape.shape = box
	atk_shape.position = Vector3(-1.2, 1.2, 0.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		if stun_timer <= 0.0:
			current_pattern = Pattern.CHASE
		move_and_slide()
		_update_boss_animation(delta)
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_boss_animation(delta)
		return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir_x: float = signf(diff.x)
	if dir_x != 0.0:
		facing_dir_x = dir_x
		# Boss sprite natively faces Right; flip_h = true faces Left towards player!
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		attack_area_3d.position.x = 1.2 * facing_dir_x

	pattern_timer -= delta

	match current_pattern:
		Pattern.IDLE, Pattern.CHASE:
			if pattern_timer <= 0.0:
				_pick_next_pattern(dist)
			else:
				var spd := move_speed * (1.35 if current_phase == 2 else 1.0)
				var boss_combat_distance := 1.85 # Reach of heavy boss blade; halt to avoid pushing
				if dist > boss_combat_distance:
					velocity.x = facing_dir_x * spd
					velocity.z = diff.normalized().z * (spd * 0.7)
					_prevent_player_pushing()
				else:
					velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
		Pattern.SHIELD_CHARGE:
			velocity.x = facing_dir_x * charge_speed
			velocity.z = 0.0
			# Stop charge upon contact with player
			if dist <= 0.60 + 0.35 + 0.15:
				_execute_charge_impact()
			if pattern_timer <= 0.0:
				sprite_3d.texture = BossTextureNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 0.8
		Pattern.TRIPLE_CLEAVE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 1.0
		Pattern.QUAKE_RING:
			velocity.x = 0.0
			velocity.z = 0.0
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 1.2

	move_and_slide()
	_update_boss_animation(delta)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.60 + 0.35 + 0.10
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


func _execute_charge_impact() -> void:
	velocity = Vector3.ZERO
	if target_player != null and is_instance_valid(target_player):
		if target_player.has_method("receive_incoming_attack"):
			target_player.receive_incoming_attack(charge_damage, self, Vector3(facing_dir_x, 0, 0))


func _update_boss_animation(delta: float) -> void:
	anim_frame_timer += delta
	var fps := 8.0
	var start_frame := 0
	var frame_count := 4

	match current_pattern:
		Pattern.IDLE:
			sprite_3d.texture = BossTextureNormal
			start_frame = 0 # Row 0
			fps = 6.0
		Pattern.CHASE:
			sprite_3d.texture = BossTextureNormal
			start_frame = 4 # Row 1 Walk
			fps = 8.0
		Pattern.SHIELD_CHARGE:
			sprite_3d.texture = BossTextureDefense
			start_frame = 0 # Row 0 Guard
			fps = 10.0
		Pattern.TRIPLE_CLEAVE:
			sprite_3d.texture = BossTextureNormal
			start_frame = 8 # Row 2 Attack
			fps = 12.0
		Pattern.STUNNED:
			sprite_3d.texture = BossTextureDefense
			start_frame = 4 # Row 1 Hurt
			fps = 5.0
		Pattern.QUAKE_RING:
			sprite_3d.texture = BossTextureDefense
			start_frame = 8 # Row 2 Slam/Defense
			fps = 8.0

	if anim_frame_timer >= (1.0 / fps):
		anim_frame_timer = 0.0
		anim_frame_idx = (anim_frame_idx + 1) % frame_count

	sprite_3d.frame = start_frame + anim_frame_idx


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _pick_next_pattern(dist: float) -> void:
	if dist > 5.5:
		_execute_shield_charge()
	elif dist <= 3.0:
		if randf() > 0.5:
			_execute_triple_cleave()
		else:
			_execute_quake_ring()
	else:
		_execute_triple_cleave()


func _execute_shield_charge() -> void:
	current_pattern = Pattern.SHIELD_CHARGE
	pattern_timer = 0.75
	sprite_3d.texture = BossTextureDefense
	attack_area_3d.monitoring = true

	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self):
		attack_area_3d.monitoring = false
		sprite_3d.texture = BossTextureNormal


func _execute_triple_cleave() -> void:
	current_pattern = Pattern.TRIPLE_CLEAVE
	pattern_timer = 0.95

	for swing in range(3):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break
		attack_area_3d.monitoring = true
		velocity.x = facing_dir_x * 4.5
		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(self):
			attack_area_3d.monitoring = false
			await get_tree().create_timer(0.08).timeout


func _execute_quake_ring() -> void:
	current_pattern = Pattern.QUAKE_RING
	pattern_timer = 1.1

	# Expanding 360-degree shockwave ring in 3D
	var ring := Area3D.new()
	ring.collision_layer = 0
	ring.collision_mask = 1 # Player
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 4.2
	cyl.height = 0.8
	col.shape = cyl
	ring.add_child(col)
	get_parent().add_child(ring)
	ring.global_position = global_position

	await get_tree().process_frame
	for body in ring.get_overlapping_bodies():
		if body.is_in_group("player") and is_instance_valid(body):
			if body.has_method("receive_incoming_attack"):
				var push := (body.global_position - global_position).normalized()
				body.receive_incoming_attack(2, self, push)
	ring.queue_free()


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			body.receive_incoming_attack(2, self, Vector3(facing_dir_x, 0, 0))


func apply_parry_stun(duration: float = 2.0) -> void:
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	velocity = Vector3.ZERO # Firm stop on clash; no slide or bounce
	attack_area_3d.monitoring = false
	sprite_3d.texture = BossTextureDefense


func receive_hit(amount: int, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = Vector3.ZERO # Stand firm like a boss; no knockback slide

	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.5, 0.4, 0.4, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.15)

	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	aura_ring_3d.visible = true
	move_speed = 4.8
	charge_speed = 14.5
	emit_signal("phase_changed", 2)


func _die() -> void:
	emit_signal("boss_defeated", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()
