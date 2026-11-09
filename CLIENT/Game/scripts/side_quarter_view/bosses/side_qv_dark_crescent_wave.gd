extends Area3D
class_name SideQVDarkCrescentWave
## 사이드 쿼터뷰 심연 암흑 참격파 (Side Quarter-View Abyssal Dark Crescent Wave)
## - 보스 '심연의 심판관(Abyssal Arbiter)' 전용 원거리 투사체
## - 흑자색 암흑 에너지 + 핏빛 룬 발광 코어 2중 구조 (HDR Bloom 4.5)
## - 비행 궤적을 가르는 3D 보이드 미스트 파티클 & 지면 동적 보이드 옴니라이트 투영
## - 플레이어 충돌 판정 및 저스트 패링 연동

signal wave_hit_target(target: Node)

@export var speed: float = 13.5
@export var damage: int = 2
@export var max_range: float = 32.0

var direction: Vector3 = Vector3.LEFT
var traveled_distance: float = 0.0
var boss_ref: Node3D = null

var core_mesh_inst: MeshInstance3D
var aura_mesh_inst: MeshInstance3D
var trail_particles: CPUParticles3D
var beam_light: OmniLight3D


var has_hit: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player (Layer 1)
	monitoring = true
	monitorable = false
	add_to_group("stage_hazards")

	_build_visuals()
	body_entered.connect(_on_body_entered)


func initialize(start_pos: Vector3, dir: Vector3, owner_boss: Node3D, dmg: int = 2) -> void:
	start_pos.z = 0.0
	global_position = start_pos
	boss_ref = owner_boss
	damage = dmg

	direction = dir.normalized()
	direction.y = 0.0
	direction.z = 0.0
	direction = direction.normalized()

	# Flight facing orientation
	if direction.x > 0.0:
		scale.x = -1.0
	else:
		scale.x = 1.0


func _physics_process(delta: float) -> void:
	var move_step := speed * delta
	global_position += direction * move_step
	global_position.z = 0.0
	traveled_distance += move_step

	if traveled_distance >= max_range:
		queue_free()


func _build_visuals() -> void:
	# 1. Procedural 3D Vertical Crescent Blade Mesh
	# Radius Outer: 1.35m, Radius Inner: 0.88m, Thickness: 0.12m, 16 Segments
	var crescent_mesh := _generate_crescent_mesh(1.35, 0.88, 0.12, 16)
	var aura_mesh := _generate_crescent_mesh(1.45, 0.82, 0.18, 16)

	# 2. Outer Void Crimson Aura Shell
	aura_mesh_inst = MeshInstance3D.new()
	aura_mesh_inst.name = "VoidAuraMesh"
	aura_mesh_inst.mesh = aura_mesh

	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(1.8, 0.15, 2.2, 0.75) # Abyssal Crimson-Purple
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(1.8, 0.15, 2.2, 1.0)
	aura_mat.emission_energy_multiplier = 3.6
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura_mesh_inst.material_override = aura_mat
	add_child(aura_mesh_inst)

	# 3. Inner Brilliant Abyssal Core Blade
	core_mesh_inst = MeshInstance3D.new()
	core_mesh_inst.name = "AbyssalCoreMesh"
	core_mesh_inst.mesh = crescent_mesh

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(2.6, 0.4, 3.4, 1.0) # Radiant Violet Core
	core_mat.emission_enabled = true
	core_mat.emission = Color(2.6, 0.4, 3.4, 1.0)
	core_mat.emission_energy_multiplier = 4.8
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core_mesh_inst.material_override = core_mat
	add_child(core_mesh_inst)

	# 4. Trailing Void Embers & Mist Particles
	trail_particles = CPUParticles3D.new()
	trail_particles.name = "VoidTrailParticles"
	trail_particles.amount = 32
	trail_particles.lifetime = 0.45
	trail_particles.preprocess = 0.05
	trail_particles.explosiveness = 0.0
	trail_particles.randomness = 0.4
	trail_particles.local_coords = false
	trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	trail_particles.emission_box_extents = Vector3(0.2, 1.1, 0.2)
	trail_particles.direction = Vector3(1.0, 0.0, 0.0)
	trail_particles.spread = 45.0
	trail_particles.initial_velocity_min = 2.0
	trail_particles.initial_velocity_max = 4.5
	trail_particles.gravity = Vector3(0.0, 0.5, 0.0)

	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.09, 0.09, 0.09)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(2.5, 0.3, 3.0, 1.0)
	pmat.emission_enabled = true
	pmat.emission = Color(2.5, 0.3, 3.0, 1.0)
	pmat.emission_energy_multiplier = 3.8
	pmesh.material = pmat
	trail_particles.mesh = pmesh
	add_child(trail_particles)

	# 5. Dynamic Ground Illuminating OmniLight3D (Void Glow)
	beam_light = OmniLight3D.new()
	beam_light.name = "BeamLight3D"
	beam_light.light_color = Color(1.8, 0.4, 2.5) # Void Purple
	beam_light.light_energy = 2.6
	beam_light.omni_range = 5.0
	beam_light.omni_attenuation = 1.2
	add_child(beam_light)

	# 6. Vertical Crescent Collision Box
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.4, 0.8)
	col.shape = box
	col.position = Vector3(0.1, 0.0, 0.0)
	add_child(col)


func _generate_crescent_mesh(r_out: float, r_in: float, thickness: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_t := thickness * 0.5
	var u_max := PI * 0.42 # ~75 degree vertical arc curve

	var outer_pts: Array[Vector3] = []
	var inner_pts: Array[Vector3] = []

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var u := lerpf(-u_max, u_max, t)

		# Convex leading edge (Forward blade)
		var fx := r_out * cos(u)
		var fy := r_out * sin(u)
		outer_pts.append(Vector3(fx, fy, 0.0))

		# Concave trailing spine
		var bx := r_in * cos(u * 1.05) - (r_out - r_in) * 0.65
		var by := r_in * sin(u * 1.05)
		inner_pts.append(Vector3(bx, by, 0.0))

	# Construct double-sided 3D volume
	for i in range(segments):
		var f0 := outer_pts[i]
		var f1 := outer_pts[i + 1]
		var b0 := inner_pts[i]
		var b1 := inner_pts[i + 1]

		var t0 := (1.0 - absf(float(i) / segments * 2.0 - 1.0)) * half_t
		var t1 := (1.0 - absf(float(i + 1) / segments * 2.0 - 1.0)) * half_t

		var f0_r := f0 + Vector3(0, 0, t0)
		var f0_l := f0 - Vector3(0, 0, t0)
		var f1_r := f1 + Vector3(0, 0, t1)
		var f1_l := f1 - Vector3(0, 0, t1)

		var b0_r := b0 + Vector3(0, 0, t0)
		var b0_l := b0 - Vector3(0, 0, t0)
		var b1_r := b1 + Vector3(0, 0, t1)
		var b1_l := b1 - Vector3(0, 0, t1)

		# Right Face
		st.add_vertex(f0_r); st.add_vertex(f1_r); st.add_vertex(b0_r)
		st.add_vertex(b0_r); st.add_vertex(f1_r); st.add_vertex(b1_r)

		# Left Face
		st.add_vertex(f1_l); st.add_vertex(f0_l); st.add_vertex(b0_l)
		st.add_vertex(b1_l); st.add_vertex(f1_l); st.add_vertex(b0_l)

		# Leading Edge
		st.add_vertex(f0_l); st.add_vertex(f1_l); st.add_vertex(f1_r)
		st.add_vertex(f0_l); st.add_vertex(f1_r); st.add_vertex(f0_r)

		# Trailing Spine Edge
		st.add_vertex(b1_l); st.add_vertex(b0_l); st.add_vertex(b0_r)
		st.add_vertex(b1_l); st.add_vertex(b0_r); st.add_vertex(b1_r)

	st.generate_normals()
	return st.commit()


func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return
	if body.is_in_group("player") and is_instance_valid(body):
		has_hit = true
		emit_signal("wave_hit_target", body)
		if body.has_method("receive_incoming_attack"):
			var atk_dir := Vector3(direction.x, 0.0, 0.0)
			var damage_dealt = body.receive_incoming_attack(damage, boss_ref, atk_dir)
			if not damage_dealt and boss_ref != null and boss_ref.has_method("apply_parry_stun"):
				# Parry clash success!
				boss_ref.apply_parry_stun(2.0)
		set_deferred("monitoring", false)
		queue_free()
