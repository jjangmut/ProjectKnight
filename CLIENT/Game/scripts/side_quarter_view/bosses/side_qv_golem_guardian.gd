extends CharacterBody3D
class_name SideQVGolemGuardian
## 사이드 쿼터뷰 Stage 4 보스: 골렘 가디언 (Side Quarter-View Golem Guardian)
## - 4x3 스프라이트 시트 (golem_guardian_v2.png), 신장 2.8m의 거대 고대 석상 수호자
## - 패턴 1: 대지 강타 그라운드 슬램 (3D 암석 파편 기둥 돌출 및 반경 충격파)
## - 패턴 2: 암석 회전 래리어트 (회전하며 전방 돌진 휘두르기)
## - 패턴 3: 지진파 대지 분쇄 (2페이즈 마그마 과부하 시 바닥에 붉은 용암 균열 방출)
## - 피격/그로기/저스트 패링 스턴/상호 밀림 방지/플레이어 정면 응시 회전 완비

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)
signal attack_performed(attack_name: String)

enum Pattern {
	IDLE,
	CHASE,
	GROUND_SLAM,
	SPINNING_LARIAT,
	QUAKE_FISSURE,
	STUNNED
}

@export var max_hp: int = 32
@export var current_hp: int = 32
@export var move_speed: float = 3.2
@export var lariat_speed: float = 11.5
@export var lariat_damage: int = 2
@export var ground_slam_damage: int = 3
@export var fissure_damage: int = 3

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var is_stunned: bool:
	get:
		return current_pattern == Pattern.STUNNED

var pattern_timer: float = 0.0
var stun_timer: float = 0.0
var target_player: Node3D = null
var facing_dir_x: float = -1.0 # Naturally faces left towards player

var sprite_3d: Sprite3D
var magma_aura_ring: MeshInstance3D
var attack_area_3d: Area3D
var ember_particles: CPUParticles3D
var lariat_dust_particles: CPUParticles3D

const GolemTextureNormal = preload("res://assets/enemy_frames/golem_guardian_v2.png")
const GolemTextureSkills = preload("res://assets/enemy_frames/golem_guardian_v2_skills.png")

var anim_frame_timer: float = 0.0
var anim_frame_idx: int = 0


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")
	add_to_group("bosses")

	pattern_timer = 1.2 # Initial standoff delay
	_build_components()
	boss_hp_changed.emit(current_hp, max_hp)


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (4x3 Sheet, 2.8m Colossal Height)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "BossSprite3D"
	sprite_3d.texture = GolemTextureNormal
	sprite_3d.hframes = 4
	sprite_3d.vframes = 3
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.009375 # 298.67px * 0.009375 = 2.80m tall
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 1.40
	sprite_3d.flip_h = true # Faces Left towards player initially
	add_child(sprite_3d)

	# 2. Magma Core Aura Ring (Phase 2 Overload)
	magma_aura_ring = MeshInstance3D.new()
	magma_aura_ring.name = "MagmaAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 1.95
	magma_aura_ring.mesh = torus

	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(3.5, 0.8, 0.1, 1.0)
	mmat.emission_enabled = true
	mmat.emission = Color(3.5, 0.8, 0.1, 1.0)
	mmat.emission_energy_multiplier = 4.5
	magma_aura_ring.material_override = mmat
	magma_aura_ring.position.y = 0.25
	magma_aura_ring.visible = false
	add_child(magma_aura_ring)

	# 3. Phase 2 Magma Embers Particles
	ember_particles = CPUParticles3D.new()
	ember_particles.name = "GolemEmberParticles"
	ember_particles.emitting = false
	ember_particles.amount = 32
	ember_particles.lifetime = 1.2
	ember_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ember_particles.emission_sphere_radius = 1.5
	ember_particles.gravity = Vector3(0.0, 3.0, 0.0)
	ember_particles.initial_velocity_min = 1.0
	ember_particles.initial_velocity_max = 2.5
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(4.0, 1.2, 0.2, 1.0)
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var pmesh := QuadMesh.new()
	pmesh.size = Vector2(0.12, 0.12)
	pmesh.material = pmat
	ember_particles.mesh = pmesh
	ember_particles.position.y = 1.4
	add_child(ember_particles)

	# 4. Lariat Swirl Dust Particles
	lariat_dust_particles = CPUParticles3D.new()
	lariat_dust_particles.name = "LariatDustParticles"
	lariat_dust_particles.emitting = false
	lariat_dust_particles.amount = 24
	lariat_dust_particles.lifetime = 0.6
	lariat_dust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	lariat_dust_particles.emission_ring_radius = 1.8
	lariat_dust_particles.emission_ring_inner_radius = 1.2
	lariat_dust_particles.gravity = Vector3(0.0, 0.5, 0.0)
	lariat_dust_particles.initial_velocity_min = 2.0
	lariat_dust_particles.initial_velocity_max = 4.0
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(0.85, 0.65, 0.45, 0.8)
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var dmesh := QuadMesh.new()
	dmesh.size = Vector2(0.18, 0.18)
	dmesh.material = dmat
	lariat_dust_particles.mesh = dmesh
	lariat_dust_particles.position.y = 0.8
	add_child(lariat_dust_particles)

	# 5. Colossal Collision Capsule (radius 0.85, height 2.8)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.85
	cap.height = 2.8
	col.shape = cap
	col.position.y = 1.4
	add_child(col)

	# 6. Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "BossAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player Layer (1)
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.4, 2.6)
	atk_col.shape = box
	atk_col.position = Vector3(0.0, 1.4, 0.0)
	attack_area_3d.add_child(atk_col)
	attack_area_3d.position.x = -1.4 # Facing left initially
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if not is_node_ready() or attack_area_3d == null:
		return

	if not is_on_floor():
		velocity.y -= 18.0 * delta

	# Stunned state processing
	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if stun_timer <= 0.0:
			current_pattern = Pattern.CHASE
			pattern_timer = 0.6
		move_and_slide()
		_update_boss_animation(delta)
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		if target_player == null:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			_update_boss_animation(delta)
			return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir_x: float = signf(diff.x)
	if dir_x != 0.0 and current_pattern != Pattern.SPINNING_LARIAT:
		facing_dir_x = dir_x
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		attack_area_3d.position.x = 1.4 * facing_dir_x

	pattern_timer -= delta

	match current_pattern:
		Pattern.IDLE, Pattern.CHASE:
			if pattern_timer <= 0.0:
				_pick_next_pattern(dist)
			else:
				var spd := move_speed * (1.35 if current_phase == 2 else 1.0)
				var boss_combat_distance := 2.2 # Heavy golem reach
				if dist > boss_combat_distance:
					velocity.x = facing_dir_x * spd
					velocity.z = diff.normalized().z * (spd * 0.65)
					_prevent_player_pushing()
				else:
					velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)

		Pattern.SPINNING_LARIAT:
			var spd := lariat_speed * (1.25 if current_phase == 2 else 1.0)
			velocity.x = facing_dir_x * spd
			velocity.z = 0.0
			# Stop rush on direct player contact
			if dist <= 0.85 + 0.35 + 0.15:
				_execute_lariat_impact()
			if pattern_timer <= 0.0:
				attack_area_3d.monitoring = false
				lariat_dust_particles.emitting = false
				sprite_3d.texture = GolemTextureNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 0.9

		Pattern.GROUND_SLAM:
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
			if pattern_timer <= 0.0:
				sprite_3d.texture = GolemTextureNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 1.0

		Pattern.QUAKE_FISSURE:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			if pattern_timer <= 0.0:
				sprite_3d.texture = GolemTextureNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 1.2

	move_and_slide()
	_update_boss_animation(delta)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.85 + 0.35 + 0.12 # Colossal boss radius (0.85) + player (0.35)
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _update_boss_animation(delta: float) -> void:
	anim_frame_timer += delta
	var fps := 8.0
	var start_frame := 0
	var frame_count := 4

	match current_pattern:
		Pattern.IDLE:
			sprite_3d.texture = GolemTextureNormal
			start_frame = 0 # Row 0: Idle
			fps = 6.0
		Pattern.CHASE:
			sprite_3d.texture = GolemTextureNormal
			start_frame = 4 # Row 1: Heavy Walk
			fps = 7.0
		Pattern.SPINNING_LARIAT:
			sprite_3d.texture = GolemTextureSkills
			start_frame = 0 # Row 0: Spin / Whirlwind
			fps = 14.0
		Pattern.GROUND_SLAM:
			sprite_3d.texture = GolemTextureNormal
			start_frame = 8 # Row 2: Heavy Slam
			fps = 6.0
		Pattern.QUAKE_FISSURE:
			sprite_3d.texture = GolemTextureSkills
			start_frame = 8 # Row 2: Fissure Eruption
			fps = 8.0
		Pattern.STUNNED:
			sprite_3d.texture = GolemTextureSkills
			start_frame = 4 # Row 1: Groggy / Staggered
			fps = 4.0

	if anim_frame_timer >= (1.0 / fps):
		anim_frame_timer = 0.0
		anim_frame_idx = (anim_frame_idx + 1) % frame_count

	sprite_3d.frame = start_frame + anim_frame_idx


func _pick_next_pattern(dist: float) -> void:
	if dist > 5.5:
		_execute_spinning_lariat()
	elif current_phase == 2 and randf() > 0.45:
		_execute_quake_fissure()
	else:
		if randf() > 0.40:
			_execute_ground_slam()
		else:
			_execute_spinning_lariat()


# ==============================================================================
# 패턴 1: 대지 강타 그라운드 슬램 (Ground Slam)
# ==============================================================================
func _execute_ground_slam() -> void:
	current_pattern = Pattern.GROUND_SLAM
	pattern_timer = 1.45
	sprite_3d.texture = GolemTextureNormal
	sprite_3d.frame = 8 # Arms raised high in windup
	attack_performed.emit("GROUND_SLAM")

	# Windup delay
	await get_tree().create_timer(0.42).timeout
	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		return

	# Impact strike!
	sprite_3d.frame = 10
	var slam_origin := global_position + Vector3(facing_dir_x * 1.5, 0.0, 0.0)

	# 1. 3D Sharp Rock Shard Pillars Eruption
	_spawn_rock_pillars(slam_origin)

	# 2. Radial Shockwave Area3D
	_spawn_ground_shockwave(slam_origin)

	# 3. Camera Trauma Shake
	_shake_camera(0.60)


func _spawn_rock_pillars(origin: Vector3) -> void:
	var container := Node3D.new()
	container.name = "RockPillarsEffect"
	var parent_node := get_parent() if get_parent() != null else self
	parent_node.add_child(container)
	container.global_position = origin

	var pillar_count := 7
	var arc_radius := 2.6
	for i in range(pillar_count):
		var angle := -PI * 0.5 + (PI / float(pillar_count - 1)) * float(i)
		var offset := Vector3(cos(angle) * arc_radius * facing_dir_x, 0.0, sin(angle) * arc_radius * 0.7)

		var pillar := MeshInstance3D.new()
		pillar.name = "Pillar_%d" % i

		# Sharp Jagged Stone Spike Mesh
		var spike := CylinderMesh.new()
		spike.top_radius = 0.04
		spike.bottom_radius = 0.38
		spike.height = randf_range(1.6, 2.4)
		spike.radial_segments = 5
		pillar.mesh = spike

		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.28, 0.22, 0.18, 1.0) # Ancient Basalt
		pmat.roughness = 0.85
		pmat.emission_enabled = true
		pmat.emission = Color(2.8, 0.7, 0.15, 1.0) # Magma vein cracks
		pmat.emission_energy_multiplier = 2.0
		pillar.material_override = pmat

		pillar.position = offset + Vector3(0.0, -1.2, 0.0)
		pillar.rotation_degrees = Vector3(randf_range(-12, 12), randf_range(0, 360), randf_range(-15, 15))
		container.add_child(pillar)

		# Erupt upwards with violent Tween punch
		var tween := create_tween()
		if tween:
			var target_y := spike.height * 0.45
			tween.tween_property(pillar, "position:y", target_y, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.40)
			tween.tween_property(pillar, "position:y", -1.8, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Clean up container after eruption finishes
	get_tree().create_timer(0.95).timeout.connect(func():
		if is_instance_valid(container):
			container.queue_free()
	)


func _spawn_ground_shockwave(origin: Vector3) -> void:
	var shock_area := Area3D.new()
	shock_area.name = "GroundSlamShockwave"
	shock_area.collision_layer = 0
	shock_area.collision_mask = 1 # Player Layer (1)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 4.5
	cyl.height = 1.2
	col.shape = cyl
	shock_area.add_child(col)

	# Shockwave Visual Ring
	var ring_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.2
	torus.outer_radius = 4.5
	ring_mesh.mesh = torus

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(3.5, 0.9, 0.2, 1.0)
	rmat.emission_enabled = true
	rmat.emission = Color(3.5, 0.9, 0.2, 1.0)
	rmat.emission_energy_multiplier = 3.5
	ring_mesh.material_override = rmat
	ring_mesh.position.y = 0.15
	shock_area.add_child(ring_mesh)

	var parent_node := get_parent() if get_parent() != null else self
	parent_node.add_child(shock_area)
	shock_area.global_position = origin

	# Animate expanding ring
	ring_mesh.scale = Vector3(0.1, 1.0, 0.1)
	var tween := create_tween()
	if tween:
		tween.tween_property(ring_mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.25)
		tween.parallel().tween_property(rmat, "albedo_color:a", 0.0, 0.25)

	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(shock_area):
		for body in shock_area.get_overlapping_bodies():
			if body.is_in_group("player") and is_instance_valid(body):
				if body.has_method("receive_incoming_attack"):
					var push := (body.global_position - origin).normalized()
					body.receive_incoming_attack(ground_slam_damage, self, push)
		shock_area.queue_free()


# ==============================================================================
# 패턴 2: 암석 회전 래리어트 (Spinning Stone Lariat)
# ==============================================================================
func _execute_spinning_lariat() -> void:
	current_pattern = Pattern.SPINNING_LARIAT
	pattern_timer = 0.85
	sprite_3d.texture = GolemTextureSkills
	attack_area_3d.monitoring = true
	lariat_dust_particles.emitting = true
	attack_performed.emit("SPINNING_LARIAT")


func _execute_lariat_impact() -> void:
	velocity = Vector3.ZERO
	attack_area_3d.monitoring = false
	lariat_dust_particles.emitting = false
	sprite_3d.texture = GolemTextureNormal
	current_pattern = Pattern.CHASE
	pattern_timer = 1.0
	if target_player != null and is_instance_valid(target_player):
		if target_player.has_method("receive_incoming_attack"):
			target_player.receive_incoming_attack(lariat_damage, self, Vector3(facing_dir_x, 0, 0))


# ==============================================================================
# 패턴 3: 지진파 대지 분쇄 (Quake Fissure - 2페이즈 전용)
# ==============================================================================
func _execute_quake_fissure() -> void:
	current_pattern = Pattern.QUAKE_FISSURE
	pattern_timer = 1.35
	sprite_3d.texture = GolemTextureSkills
	sprite_3d.frame = 8 # Windup
	attack_performed.emit("QUAKE_FISSURE")

	await get_tree().create_timer(0.40).timeout
	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		return

	sprite_3d.frame = 11 # Slam fissure
	var fissure_origin := global_position + Vector3(facing_dir_x * 1.8, 0.0, 0.0)

	# Create Linear Molten Lava Fissure tearing across floor
	_spawn_molten_fissure_line(fissure_origin, facing_dir_x)
	_shake_camera(0.65)


func _spawn_molten_fissure_line(origin: Vector3, dir_x: float) -> void:
	var container := Node3D.new()
	container.name = "MoltenFissureContainer"
	var parent_node := get_parent() if get_parent() != null else self
	parent_node.add_child(container)
	container.global_position = origin

	var segments := 5
	var step_dist := 1.7
	var fissure_area := Area3D.new()
	fissure_area.name = "FissureArea3D"
	fissure_area.collision_layer = 0
	fissure_area.collision_mask = 1 # Player

	var fissure_col := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(segments * step_dist, 1.4, 2.0)
	fissure_col.shape = fbox
	fissure_col.position = Vector3(dir_x * (segments * step_dist * 0.5), 0.7, 0.0)
	fissure_area.add_child(fissure_col)
	container.add_child(fissure_area)

	for i in range(segments):
		var pos_x := dir_x * (float(i) * step_dist)
		var seg_mesh := MeshInstance3D.new()
		seg_mesh.name = "FissureSeg_%d" % i

		# Molten Lava Crack Slab Mesh
		var quad := QuadMesh.new()
		quad.size = Vector2(step_dist * 1.1, 0.8)
		seg_mesh.mesh = quad
		seg_mesh.rotation_degrees = Vector3(-90.0, 0.0, randf_range(-10, 10))
		seg_mesh.position = Vector3(pos_x, 0.03, randf_range(-0.15, 0.15))

		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(4.2, 0.9, 0.15, 1.0)
		lmat.emission_enabled = true
		lmat.emission = Color(4.2, 0.9, 0.15, 1.0)
		lmat.emission_energy_multiplier = 4.0
		seg_mesh.material_override = lmat
		container.add_child(seg_mesh)

		# Molten flame burst
		var tween := create_tween()
		if tween:
			seg_mesh.scale = Vector3(0.2, 0.2, 0.2)
			tween.tween_property(seg_mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
			tween.tween_interval(0.6)
			tween.tween_property(lmat, "albedo_color:a", 0.0, 0.35)

	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(fissure_area):
		for body in fissure_area.get_overlapping_bodies():
			if body.is_in_group("player") and is_instance_valid(body):
				if body.has_method("receive_incoming_attack"):
					body.receive_incoming_attack(fissure_damage, self, Vector3(dir_x, 0.4, 0.0))

	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(container):
			container.queue_free()
	)


# ==============================================================================
# 전투 피격 / 패링 스턴 / 2페이즈 및 사망 처리
# ==============================================================================
func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var dmg := lariat_damage if current_pattern == Pattern.SPINNING_LARIAT else ground_slam_damage
			body.receive_incoming_attack(dmg, self, Vector3(facing_dir_x, 0, 0))


func apply_parry_stun(duration: float = 2.0) -> void:
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	velocity = Vector3.ZERO # Absolute rock-firm stop on parry clash; zero slide
	attack_area_3d.monitoring = false
	lariat_dust_particles.emitting = false
	sprite_3d.texture = GolemTextureSkills
	sprite_3d.frame = 4 # Staggered recoil frame

	# Stun visual flash
	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.5, 2.2, 0.5, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.25)


func receive_hit(amount: int, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	boss_hp_changed.emit(current_hp, max_hp)

	velocity = Vector3.ZERO # Heavy colossus stands firm; zero knockback flinch

	# Hit flash
	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.8, 0.4, 0.4, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.15)

	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	magma_aura_ring.visible = true
	ember_particles.emitting = true
	move_speed = 4.2
	lariat_speed = 13.5
	phase_changed.emit(2)
	_shake_camera(0.70)


func _die() -> void:
	boss_defeated.emit(self)
	set_physics_process(false)
	attack_area_3d.monitoring = false
	lariat_dust_particles.emitting = false
	ember_particles.emitting = false
	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _shake_camera(amount: float) -> void:
	var stage := get_parent()
	if stage != null and "camera" in stage and stage.camera != null:
		if stage.camera.has_method("add_trauma"):
			stage.camera.add_trauma(amount)
