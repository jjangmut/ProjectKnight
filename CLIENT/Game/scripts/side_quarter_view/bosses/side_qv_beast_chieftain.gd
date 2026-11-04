extends CharacterBody3D
class_name SideQVBeastChieftain
## 사이드 쿼터뷰 스테이지 2 보스: 심연의 야수 우두머리 (Side QV Beast Chieftain)
## - 2D 고해상도 야수 보스 스프라이트 (Sprite3D, 4x3 시트, ~2.5m 높이) 및 실시간 3D 그림자 투영
## - 패턴 1: 맹수 도약 덮치기 (Pounce Leap: 플레이어를 향해 9.0m/s 포물선 도약 강습 및 착지 충격파)
## - 패턴 2: 3단 야수 발톱 참격 (Triple Claw Strike: 전진 3연격 근접 콤보)
## - 패턴 3: 분노 포효 (Enraged Roar: HP 50% 이하 2페이즈 돌입, 3D 에메랄드 쇼크웨이브 및 광폭화)
## - 피격/그로기/저스트 패링 스턴/상호 밀림 방지/플레이어 정면 응시 회전 완비

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)
signal boss_phase_changed(phase: int)

enum Pattern {
	IDLE,
	CHASE,
	POUNCE_LEAP,
	TRIPLE_CLAW_STRIKE,
	ENRAGED_ROAR,
	STUNNED
}

@export var max_hp: int = 28
@export var current_hp: int = 28
@export var max_poise: int = 14
var current_poise: int = 14
var is_groggy: bool = false
var groggy_timer: float = 0.0
var groggy_halo_3d: MeshInstance3D = null
@export var move_speed: float = 4.2
@export var leap_speed: float = 9.0
@export var leap_damage: int = 2
@export var claw_damage: int = 2

const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var is_stunned: bool:
	get:
		return current_pattern == Pattern.STUNNED

var pattern_timer: float = 0.0
var stun_timer: float = 0.0
var target_player: Node3D = null
var facing_dir_x: float = -1.0 # 1.0 = Right, -1.0 = Left

var is_leap_airborne: bool = false
var leap_has_landed: bool = false

var sprite_3d: Sprite3D
var aura_ring_3d: MeshInstance3D
var attack_area_3d: Area3D

const BossTextureMain = preload("res://assets/enemy_frames/beast_chieftain_v2.png")
const BossTextureSkills = preload("res://assets/enemy_frames/beast_chieftain_v2_skills.png")

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
	# 1. 2D Sprite in 3D Space (Sprite Sheet 4x3 frames, ~2.50m height)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "BeastChieftainSprite3D"
	sprite_3d.texture = BossTextureMain
	sprite_3d.hframes = 4
	sprite_3d.vframes = 3
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.00835 # 298.66px * 0.00835 = ~2.50m tall
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 1.25
	sprite_3d.flip_h = true # Initially face Left towards the player on the left
	add_child(sprite_3d)

	# 2. Emerald Aura Ring (Phase 2 Enrage)
	aura_ring_3d = MeshInstance3D.new()
	aura_ring_3d.name = "EmeraldAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.75
	aura_ring_3d.mesh = torus

	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.2, 2.5, 0.8, 1.0)
	amat.emission_enabled = true
	amat.emission = Color(0.2, 2.5, 0.8, 1.0)
	amat.emission_energy_multiplier = 4.2
	aura_ring_3d.material_override = amat
	aura_ring_3d.position.y = 0.15
	aura_ring_3d.visible = false
	add_child(aura_ring_3d)

	# 3. Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.70
	cap.height = 2.45
	col.shape = cap
	col.position.y = 1.22
	add_child(col)

	# 4. Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "BossAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player Layer (1)
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.2, 2.4)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 1.2, 0.0)
	attack_area_3d.position = Vector3(-1.3, 0.0, 0.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if is_groggy:
		groggy_timer -= delta
		if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
			groggy_halo_3d.rotation_degrees.y += 180.0 * delta
		if groggy_timer <= 0.0:
			_exit_groggy_state()
		velocity = Vector3.ZERO
		move_and_slide()
		_update_boss_animation(delta)
		return

	# Stunned state
	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		if stun_timer <= 0.0:
			current_pattern = Pattern.CHASE
			pattern_timer = 0.6
		move_and_slide()
		_update_boss_animation(delta)
		return

	# Search player
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
	var dir_x := signf(diff.x)

	# Face towards player (if not mid-leap)
	if dir_x != 0.0 and current_pattern != Pattern.POUNCE_LEAP:
		facing_dir_x = dir_x
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		attack_area_3d.position.x = 1.3 * facing_dir_x

	pattern_timer -= delta

	match current_pattern:
		Pattern.IDLE, Pattern.CHASE:
			if pattern_timer <= 0.0:
				_pick_next_pattern(dist, diff)
			else:
				var spd := move_speed * (1.35 if current_phase == 2 else 1.0)
				var combat_distance := 2.0
				if dist > combat_distance:
					velocity.x = facing_dir_x * spd
					velocity.z = diff.normalized().z * (spd * 0.7)
					_prevent_player_pushing()
				else:
					velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
					if pattern_timer <= 0.35:
						_pick_next_pattern(dist, diff)

		Pattern.POUNCE_LEAP:
			if is_leap_airborne:
				# Check landing
				if is_on_floor() and velocity.y <= 0.1:
					_on_pounce_landed()
			else:
				velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
				if pattern_timer <= 0.0:
					current_pattern = Pattern.CHASE
					pattern_timer = 0.8

		Pattern.TRIPLE_CLAW_STRIKE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 0.9

		Pattern.ENRAGED_ROAR:
			velocity.x = 0.0
			velocity.z = 0.0
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 0.6

	move_and_slide()
	_update_boss_animation(delta)


func _pick_next_pattern(dist: float, diff: Vector3) -> void:
	if dist >= 4.0:
		_execute_pounce_leap(diff)
	elif dist <= 2.8:
		_execute_triple_claw()
	else:
		if randf() > 0.45:
			_execute_pounce_leap(diff)
		else:
			_execute_triple_claw()


# ==============================================================================
# 패턴 1: 맹수 도약 덮치기 (Pounce Leap)
# ==============================================================================
func _show_danger_telegraph(duration: float = 0.35) -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "DangerTelegraphRing3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 1.0
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(3.8, 0.4, 0.2, 0.9)
	rmat.emission_enabled = true
	rmat.emission = Color(3.8, 0.4, 0.2, 1.0)
	rmat.emission_energy_multiplier = 4.5
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.08, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(2.5, 2.5, 2.5), duration)
		tw.tween_property(rmat, "albedo_color:a", 0.0, duration)
		tw.chain().tween_callback(ring.queue_free)

	GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.7, 0.0), "!", Color(3.8, 0.3, 0.2), true)


func _enter_groggy_state() -> void:
	is_groggy = true
	groggy_timer = 3.0
	current_pattern = Pattern.STUNNED
	velocity = Vector3.ZERO
	attack_area_3d.monitoring = false
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 8 # Hurt frame
	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.7, 0.0), "GROGGY!", Color(1.0, 0.7, 0.1), true)
		_spawn_groggy_halo()


func _spawn_groggy_halo() -> void:
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
	groggy_halo_3d = MeshInstance3D.new()
	groggy_halo_3d.name = "GroggyHalo3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.55
	groggy_halo_3d.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(3.2, 2.4, 0.4, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(3.2, 2.4, 0.4, 1.0)
	mat.emission_energy_multiplier = 4.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	groggy_halo_3d.material_override = mat
	add_child(groggy_halo_3d)
	groggy_halo_3d.position = Vector3(0.0, 2.7, 0.0)
	groggy_halo_3d.rotation_degrees = Vector3(75.0, 0.0, 0.0)


func _exit_groggy_state() -> void:
	is_groggy = false
	current_poise = max_poise
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
		groggy_halo_3d = null
	current_pattern = Pattern.CHASE
	pattern_timer = 0.8
	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.5, 0.0), "RECOVER!", Color(0.4, 0.8, 1.2), false)


func _execute_pounce_leap(diff: Vector3) -> void:
	current_pattern = Pattern.POUNCE_LEAP
	pattern_timer = 2.5
	_show_danger_telegraph(0.35)
	velocity = Vector3.ZERO
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or is_stunned or is_groggy:
		return
	is_leap_airborne = true
	leap_has_landed = false

	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 0 # Skills Row 0 (Leap Start)

	var spd := leap_speed * (1.25 if current_phase == 2 else 1.0)
	velocity.y = 7.2
	velocity.x = facing_dir_x * spd
	velocity.z = clampf(diff.z * 1.5, -4.5, 4.5)
	attack_area_3d.monitoring = true


func _on_pounce_landed() -> void:
	is_leap_airborne = false
	leap_has_landed = true
	velocity = Vector3.ZERO
	pattern_timer = 0.55
	attack_area_3d.monitoring = false

	# Skills Row 0 Frame 2 (Ground Impact Slam)
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 2

	_spawn_ground_slam_shockwave()


func _spawn_ground_slam_shockwave() -> void:
	# 3D Ground Shockwave Area
	var slam_area := Area3D.new()
	slam_area.collision_layer = 0
	slam_area.collision_mask = 1 # Player Layer (1)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.6
	cyl.height = 1.0
	col.shape = cyl
	slam_area.add_child(col)
	get_parent().add_child(slam_area)
	slam_area.global_position = global_position

	# Emerald Shockwave Visual Mesh
	var slam_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.8
	slam_mesh.mesh = torus

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 2.5, 0.8, 1.0)
	smat.emission_enabled = true
	smat.emission = Color(0.2, 2.5, 0.8, 1.0)
	smat.emission_energy_multiplier = 4.0
	slam_mesh.material_override = smat
	slam_mesh.position.y = 0.15
	slam_area.add_child(slam_mesh)

	# Expand visual ring
	var tween := create_tween()
	if tween:
		tween.tween_property(slam_mesh, "scale", Vector3(4.5, 1.0, 4.5), 0.35)
		tween.parallel().tween_property(smat, "albedo_color:a", 0.0, 0.35)

	# Check player damage
	await get_tree().process_frame
	if is_instance_valid(slam_area):
		for body in slam_area.get_overlapping_bodies():
			if body.is_in_group("player") and is_instance_valid(body):
				if body.has_method("receive_incoming_attack"):
					var push := (body.global_position - global_position).normalized()
					body.receive_incoming_attack(leap_damage, self, push)

	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(slam_area):
		slam_area.queue_free()


# ==============================================================================
# 패턴 2: 3단 야수 발톱 참격 (Triple Claw Strike)
# ==============================================================================
func _execute_triple_claw() -> void:
	current_pattern = Pattern.TRIPLE_CLAW_STRIKE
	pattern_timer = 1.2
	sprite_3d.texture = BossTextureMain

	for swing in range(3):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break

		# Claw slash animation: Row 2 Frame 8 (windup), 9 (slash)
		sprite_3d.frame = 8
		await get_tree().create_timer(0.06).timeout
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break

		sprite_3d.frame = 9
		velocity.x = facing_dir_x * (4.2 + swing * 0.8)
		attack_area_3d.monitoring = true

		await get_tree().create_timer(0.20).timeout
		if is_instance_valid(self):
			attack_area_3d.monitoring = false
			await get_tree().create_timer(0.08).timeout

	if is_instance_valid(self) and current_pattern != Pattern.STUNNED:
		current_pattern = Pattern.CHASE
		pattern_timer = 0.8


# ==============================================================================
# 패턴 3: 분노 포효 (Enraged Roar - Phase 2 Transition)
# ==============================================================================
func _trigger_phase_2() -> void:
	current_phase = 2
	current_pattern = Pattern.ENRAGED_ROAR
	pattern_timer = 1.4
	velocity = Vector3.ZERO

	aura_ring_3d.visible = true
	move_speed = 5.6
	leap_speed = 11.5

	emit_signal("phase_changed", 2)
	emit_signal("boss_phase_changed", 2)

	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 4 # Row 1 Roar

	_spawn_roar_emerald_shockwave()


func _spawn_roar_emerald_shockwave() -> void:
	var roar_area := Area3D.new()
	roar_area.collision_layer = 0
	roar_area.collision_mask = 1 # Player

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.2
	cyl.height = 1.2
	col.shape = cyl
	roar_area.add_child(col)
	get_parent().add_child(roar_area)
	roar_area.global_position = global_position

	# Emerald Wave Torus Visual
	var wave_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 1.0
	wave_mesh.mesh = torus

	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 2.8, 0.9, 1.0)
	wmat.emission_enabled = true
	wmat.emission = Color(0.2, 2.8, 0.9, 1.0)
	wmat.emission_energy_multiplier = 4.5
	wave_mesh.material_override = wmat
	wave_mesh.position.y = 0.3
	roar_area.add_child(wave_mesh)

	var tween := create_tween()
	if tween:
		tween.tween_property(wave_mesh, "scale", Vector3(5.5, 1.0, 5.5), 0.45)
		tween.parallel().tween_property(wmat, "albedo_color:a", 0.0, 0.45)

	# Overlapping player damage & knockback
	await get_tree().process_frame
	if is_instance_valid(roar_area):
		for body in roar_area.get_overlapping_bodies():
			if body.is_in_group("player") and is_instance_valid(body):
				if body.has_method("receive_incoming_attack"):
					var push := (body.global_position - global_position).normalized()
					body.receive_incoming_attack(2, self, push)

	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(roar_area):
		roar_area.queue_free()


# ==============================================================================
# 애니메이션 & 공통 루틴
# ==============================================================================
func _update_boss_animation(delta: float) -> void:
	anim_frame_timer += delta

	match current_pattern:
		Pattern.IDLE:
			sprite_3d.texture = BossTextureMain
			if anim_frame_timer >= 0.16:
				anim_frame_timer = 0.0
				anim_frame_idx = (anim_frame_idx + 1) % 4
			sprite_3d.frame = 0 + anim_frame_idx

		Pattern.CHASE:
			sprite_3d.texture = BossTextureMain
			if anim_frame_timer >= 0.12:
				anim_frame_timer = 0.0
				anim_frame_idx = (anim_frame_idx + 1) % 4
			sprite_3d.frame = 4 + anim_frame_idx

		Pattern.POUNCE_LEAP:
			sprite_3d.texture = BossTextureSkills
			if is_leap_airborne:
				sprite_3d.frame = 0 if velocity.y > 0.0 else 1
			else:
				sprite_3d.frame = 2

		Pattern.TRIPLE_CLAW_STRIKE:
			sprite_3d.texture = BossTextureMain
			# Frame handled directly in attack sequence

		Pattern.ENRAGED_ROAR:
			sprite_3d.texture = BossTextureSkills
			if anim_frame_timer >= 0.12:
				anim_frame_timer = 0.0
				anim_frame_idx = (anim_frame_idx + 1) % 4
			sprite_3d.frame = 4 + anim_frame_idx

		Pattern.STUNNED:
			sprite_3d.texture = BossTextureSkills
			sprite_3d.frame = 8 # Hurt / Stun


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.70 + 0.35 + 0.10
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var dmg := claw_damage
			body.receive_incoming_attack(dmg, self, Vector3(facing_dir_x, 0, 0))


func apply_parry_stun(duration: float = 2.0) -> void:
	if not is_groggy:
		current_poise = maxi(0, current_poise - 4)
		if current_poise <= 0:
			_enter_groggy_state()
			return
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	velocity = Vector3.ZERO
	attack_area_3d.monitoring = false
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 8


func receive_hit(amount: int, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	if is_groggy:
		amount += 1 # Bonus shatter damage during groggy break
		var p := get_parent()
		if p != null:
			GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.3, 0.0), "SHATTER +1", Color(1.0, 0.8, 0.2), true)
	else:
		current_poise = maxi(0, current_poise - maxi(1, amount))
		if current_poise <= 0:
			_enter_groggy_state()

	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = Vector3.ZERO

	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.5, 0.4, 0.4, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.15)

	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _die() -> void:
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
		groggy_halo_3d = null
	emit_signal("boss_defeated", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()
