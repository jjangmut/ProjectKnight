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
	CHARGE_WINDUP,
	CHARGE_ACTIVE,
	QUAKE_RING,
	STUNNED
}

# Shield Charge Timing & State Machine Metrics
var charge_windup_timer: float = 0.0
var charge_windup_started_at: float = 0.0
var charge_motion_started_at: float = 0.0
var first_damage_at: float = 0.0

@export var max_hp: int = 38
@export var current_hp: int = 38
@export var max_poise: int = 36
var current_poise: int = 36
var is_groggy: bool = false
var groggy_timer: float = 0.0
var groggy_halo_3d: MeshInstance3D = null
var is_dead: bool = false
var pattern_cycle_count: int = 0
var _defeated_signaled: bool = false
@export var move_speed: float = 3.8
@export var charge_speed: float = 12.0
@export var charge_damage: int = 2

const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

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
var ground_shadow: MeshInstance3D = null

const BossTextureNormal = preload("res://assets/enemy_frames/boss_commander_v2.png")
const BossTextureDefense = preload("res://assets/enemy_frames/boss_commander_v2_defense.png")

# VIS-009 Boss Combat VFX Textures
const TexBossFissure = preload("res://assets/vfx/vfx_boss_fissure_magma.png")
const TexShockwaveRing = preload("res://assets/vfx/vfx_shockwave_ring.png")
const TexHitSpark = preload("res://assets/vfx/vfx_hit_spark_burst.png")


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

	# Boss Soft Ground Contact Shadow Decal
	var shadow_mesh := MeshInstance3D.new()
	shadow_mesh.name = "GroundContactShadow"
	ground_shadow = shadow_mesh
	var s_quad := QuadMesh.new()
	s_quad.size = Vector2(1.8, 0.75)
	shadow_mesh.mesh = s_quad
	shadow_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	shadow_mesh.position = Vector3(0.0, 0.015, 0.0)
	var sh_mat := StandardMaterial3D.new()
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.albedo_color = Color(0.02, 0.03, 0.05, 0.60)
	shadow_mesh.material_override = sh_mat
	add_child(shadow_mesh)

	# 2. Crimson Aura Ring (Phase 2 Enrage)
	aura_ring_3d = MeshInstance3D.new()
	aura_ring_3d.name = "CrimsonAuraRing"
	var aquad := QuadMesh.new()
	aquad.size = Vector2(3.2, 3.2)
	aura_ring_3d.mesh = aquad
	aura_ring_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var amat := StandardMaterial3D.new()
	amat.albedo_texture = TexShockwaveRing
	amat.albedo_color = Color(1.3, 0.35, 0.35, 0.85)
	amat.emission_enabled = true
	amat.emission_texture = TexShockwaveRing
	amat.emission = Color(1.3, 0.35, 0.35, 1.0)
	amat.emission_energy_multiplier = 1.35
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	amat.cull_mode = BaseMaterial3D.CULL_DISABLED
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_ring_3d.material_override = amat
	aura_ring_3d.position.y = 0.04
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
	atk_shape.position = Vector3(0.0, 1.2, 0.0)
	attack_area_3d.position = Vector3(-1.2, 0.0, 0.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	# Anchor ground shadow to floor level
	if ground_shadow != null and is_instance_valid(ground_shadow):
		if is_on_floor():
			ground_shadow.position = Vector3(0.0, 0.015, 0.0)
		else:
			ground_shadow.global_position.y = 0.015
			ground_shadow.global_position.x = global_position.x
			ground_shadow.global_position.z = global_position.z
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
					var chase_dir := diff.normalized()
					velocity.x = chase_dir.x * spd
					velocity.z = chase_dir.z * (spd * 0.70)
					_prevent_player_pushing()
				else:
					velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
		Pattern.CHARGE_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			attack_area_3d.monitoring = false
			charge_windup_timer -= delta
			if charge_windup_timer <= 0.0:
				current_pattern = Pattern.CHARGE_ACTIVE
				charge_motion_started_at = Time.get_ticks_msec() / 1000.0
				pattern_timer = 0.75
				sprite_3d.texture = BossTextureDefense
				attack_area_3d.monitoring = true

		Pattern.CHARGE_ACTIVE, Pattern.SHIELD_CHARGE:
			velocity.x = facing_dir_x * charge_speed
			velocity.z = 0.0
			# Stop charge upon contact with player
			if dist <= 0.60 + 0.35 + 0.15:
				if first_damage_at == 0.0:
					first_damage_at = Time.get_ticks_msec() / 1000.0
				_execute_charge_impact()
			if pattern_timer <= 0.0:
				sprite_3d.texture = BossTextureNormal
				attack_area_3d.monitoring = false
				current_pattern = Pattern.CHASE
				pattern_timer = 0.65
		Pattern.TRIPLE_CLEAVE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 0.65
		Pattern.QUAKE_RING:
			velocity.x = 0.0
			velocity.z = 0.0
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 0.65

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
	attack_area_3d.monitoring = false
	sprite_3d.texture = BossTextureNormal
	current_pattern = Pattern.CHASE
	pattern_timer = 0.65
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
		Pattern.CHARGE_WINDUP:
			sprite_3d.texture = BossTextureDefense
			start_frame = 0
			fps = 6.0
		Pattern.CHARGE_ACTIVE, Pattern.SHIELD_CHARGE:
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


func _pick_next_pattern(_dist: float) -> void:
	pattern_cycle_count += 1
	var choices := [Pattern.TRIPLE_CLEAVE, Pattern.SHIELD_CHARGE, Pattern.QUAKE_RING]
	var next_p: int = choices[(pattern_cycle_count - 1) % 3]
	print("[BOSS] Picked pattern cycle #", pattern_cycle_count, " pattern: ", next_p)

	match next_p:
		Pattern.TRIPLE_CLEAVE:
			_execute_triple_cleave()
		Pattern.SHIELD_CHARGE:
			_execute_shield_charge()
		Pattern.QUAKE_RING:
			_execute_quake_ring()


func _show_danger_telegraph(duration: float = 0.35) -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "DangerTelegraphRing3D"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	ring.mesh = quad
	ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = TexShockwaveRing
	rmat.albedo_color = Color(1.35, 0.35, 0.2, 0.95)
	rmat.emission_enabled = true
	rmat.emission_texture = TexShockwaveRing
	rmat.emission = Color(1.35, 0.35, 0.2, 1.0)
	rmat.emission_energy_multiplier = 1.35
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.04, 0.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(2.5, 2.5, 2.5), duration)
		tw.tween_property(rmat, "albedo_color:a", 0.0, duration)
		tw.chain().tween_callback(ring.queue_free)

	GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.6, 0.0), "!", Color(1.4, 0.3, 0.2), true)


func _enter_groggy_state() -> void:
	is_groggy = true
	groggy_timer = 1.2
	current_pattern = Pattern.STUNNED
	charge_windup_timer = 0.0
	velocity = Vector3.ZERO
	attack_area_3d.monitoring = false
	sprite_3d.texture = BossTextureDefense
	sprite_3d.frame = 4 # Hurt frame
	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.6, 0.0), "GROGGY!", Color(1.0, 0.7, 0.1), true)
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
	mat.albedo_color = Color(1.3, 1.0, 0.3, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.3, 1.0, 0.3, 1.0)
	mat.emission_energy_multiplier = 1.35
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	groggy_halo_3d.material_override = mat
	add_child(groggy_halo_3d)
	groggy_halo_3d.position = Vector3(0.0, 2.6, 0.0)
	groggy_halo_3d.rotation_degrees = Vector3(75.0, 0.0, 0.0)


func _exit_groggy_state() -> void:
	is_groggy = false
	current_poise = max_poise
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
		groggy_halo_3d = null
	current_pattern = Pattern.CHASE
	pattern_timer = 0.25
	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.4, 0.0), "RECOVER!", Color(0.4, 0.8, 1.2), false)


func _execute_shield_charge() -> void:
	current_pattern = Pattern.CHARGE_WINDUP
	charge_windup_timer = 0.42
	pattern_timer = 1.25
	charge_windup_started_at = Time.get_ticks_msec() / 1000.0
	charge_motion_started_at = 0.0
	first_damage_at = 0.0
	# PK_GameDesign standard: 0.42s stationary windup telegraph before any rush motion
	_show_danger_telegraph(0.42)
	velocity = Vector3.ZERO
	attack_area_3d.monitoring = false


func _execute_triple_cleave() -> void:
	current_pattern = Pattern.TRIPLE_CLEAVE
	pattern_timer = 1.15

	for swing in range(3):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED or is_groggy:
			break
		attack_area_3d.monitoring = true
		velocity.x = facing_dir_x * 4.2

		# On 3rd swing: Slam the floor with ground fissure shockwave!
		if swing == 2:
			_spawn_fissure_shockwave()

		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(self):
			attack_area_3d.monitoring = false
			await get_tree().create_timer(0.10).timeout


func _spawn_fissure_shockwave() -> void:
	var p := get_parent()
	if p == null:
		return
	var fissure := Area3D.new()
	fissure.name = "CommanderFissureWave"
	fissure.collision_layer = 0
	fissure.collision_mask = 1 # Player
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 1.2)
	col.shape = box
	fissure.add_child(col)

	var fmesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 1.3)
	fmesh.mesh = quad
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = TexBossFissure
	fmat.albedo_color = Color(1.35, 0.85, 0.35, 0.95)
	fmat.emission_enabled = true
	fmat.emission_texture = TexBossFissure
	fmat.emission = Color(1.35, 0.75, 0.2, 1.0)
	fmat.emission_energy_multiplier = 1.35
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fmesh.material_override = fmat
	fissure.add_child(fmesh)

	p.add_child(fissure)
	var spawn_pos := global_position + Vector3(facing_dir_x * 1.2, 0.6, 0.0)
	fissure.global_position = spawn_pos

	var target_x := spawn_pos.x + facing_dir_x * 12.0
	var tw := fissure.create_tween()
	if tw:
		tw.tween_property(fissure, "global_position:x", target_x, 0.65)
		tw.parallel().tween_property(fmat, "albedo_color:a", 0.0, 0.65)
		tw.chain().tween_callback(fissure.queue_free)

	fissure.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and is_instance_valid(body):
			if body.has_method("receive_incoming_attack"):
				body.receive_incoming_attack(2, self, Vector3(facing_dir_x, 0, 0))
	)


func _execute_quake_ring() -> void:
	current_pattern = Pattern.QUAKE_RING
	pattern_timer = 1.45
	_show_danger_telegraph(0.35)
	velocity = Vector3.ZERO
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or is_stunned or is_groggy:
		return

	# Visual 3D Expanding Crimson Shockwave Ring
	var p := get_parent()
	if p != null:
		var vring := MeshInstance3D.new()
		vring.name = "QuakeShockwaveRing3D"
		var quad := QuadMesh.new()
		quad.size = Vector2(2.5, 2.5)
		vring.mesh = quad
		vring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		var vmat := StandardMaterial3D.new()
		vmat.albedo_texture = TexShockwaveRing
		vmat.albedo_color = Color(1.4, 0.45, 0.2, 0.95)
		vmat.emission_enabled = true
		vmat.emission_texture = TexShockwaveRing
		vmat.emission = Color(1.4, 0.45, 0.2, 1.0)
		vmat.emission_energy_multiplier = 1.30
		vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		vmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vring.material_override = vmat
		p.add_child(vring)
		vring.global_position = global_position + Vector3(0.0, 0.05, 0.0)
		var vtw := vring.create_tween()
		if vtw:
			vtw.set_parallel(true)
			vtw.tween_property(vring, "scale", Vector3(3.8, 3.8, 3.8), 0.36)
			vtw.tween_property(vmat, "albedo_color:a", 0.0, 0.36)
			vtw.chain().tween_callback(vring.queue_free)

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
	if not is_groggy:
		current_poise = maxi(0, current_poise - 4)
		if current_poise <= 0:
			_enter_groggy_state()
			return
	current_pattern = Pattern.STUNNED
	charge_windup_timer = 0.0
	stun_timer = duration
	velocity = Vector3.ZERO # Firm stop on clash; no slide or bounce
	attack_area_3d.monitoring = false
	sprite_3d.texture = BossTextureDefense
	var stw := create_tween()
	if stw:
		sprite_3d.modulate = Color(3.2, 2.8, 1.0, 1.0)
		stw.tween_property(sprite_3d, "modulate", Color.WHITE, 0.25)


func receive_hit(amount: int, hit_dir: Vector3 = Vector3.ZERO, is_counter: bool = false) -> void:
	if is_dead or current_hp <= 0 or amount <= 0:
		return

	if current_pattern == Pattern.CHARGE_WINDUP:
		amount = maxi(1, int(amount * 0.5))
		var p := get_parent()
		if p != null:
			GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.2, 0.0), "GUARDED", Color(0.6, 0.8, 1.2), false)

	if is_groggy:
		amount += 1 # Bonus shatter damage during groggy break
		var p := get_parent()
		if p != null:
			GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.2, 0.0), "SHATTER +1", Color(1.0, 0.8, 0.2), true)
	else:
		current_poise = maxi(0, current_poise - maxi(1, amount))
		if current_poise <= 0:
			_enter_groggy_state()

	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = Vector3.ZERO # Stand firm like a boss; no knockback slide

	# 1. Distinct visual hit confirmation flash
	var tween := create_tween()
	if tween:
		if is_counter:
			sprite_3d.modulate = Color(1.5, 3.2, 4.0, 1.0)
			tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.18)
		else:
			sprite_3d.modulate = Color(3.5, 0.8, 0.8, 1.0)
			tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.12)

	# 2. Boss sprite micro-recoil shake
	var push_x := hit_dir.x
	if push_x == 0.0:
		push_x = -facing_dir_x
	var offset_x: float = push_x * (0.08 if is_counter else 0.04)
	sprite_3d.position.x = offset_x
	var rtw := create_tween()
	if rtw:
		rtw.tween_property(sprite_3d, "position:x", 0.0, 0.08)

	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	aura_ring_3d.visible = true
	aura_ring_3d.scale = Vector3(0.4, 1.0, 0.4)
	var atw := create_tween()
	if atw:
		atw.tween_property(aura_ring_3d, "scale", Vector3(1.2, 1.0, 1.2), 0.35)
	move_speed = 4.8
	charge_speed = 14.5
	emit_signal("phase_changed", 2)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	if attack_area_3d != null and is_instance_valid(attack_area_3d):
		attack_area_3d.set_deferred("monitoring", false)
		attack_area_3d.set_deferred("monitorable", false)
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
		groggy_halo_3d = null
	if not _defeated_signaled:
		_defeated_signaled = true
		emit_signal("boss_defeated", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()
