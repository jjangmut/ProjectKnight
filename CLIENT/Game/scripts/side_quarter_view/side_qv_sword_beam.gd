extends Area3D
class_name SideQVSwordBeam
## 사이드 쿼터뷰 수직 초승달 참격 검기파 (Side Quarter-View Vertical Crescent Sword Wave)
## - 대검 종베기/사선 참격 궤적과 일치하는 수직 3D 초승달(Crescent Arc) 메쉬
## - 고휘도 백색 코어 + 외곽 황금빛 오라 2중 발광 구조 (HDR Bloom 4.0)
## - 비행 궤적을 가르는 3D 황금 스파크 파티클 & 지면 동적 옴니라이트 투영

@export var speed: float = 18.0
@export var damage: int = 1
@export var max_range: float = 6.2
@export var pierce_count: int = 0

var direction: Vector3 = Vector3.RIGHT
var traveled_distance: float = 0.0
var _hit_ids: Dictionary = {}

var core_mesh_inst: MeshInstance3D
var aura_mesh_inst: MeshInstance3D
var trail_particles: CPUParticles3D
var beam_light: OmniLight3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Enemies (Layer 2)
	monitoring = true
	monitorable = false

	_build_vertical_crescent_visuals()
	body_entered.connect(_on_body_entered)


func initialize(start_pos: Vector3, dir: Vector3, extra_dmg: int = 0) -> void:
	global_position = start_pos
	direction = dir.normalized()
	direction.y = 0.0
	direction = direction.normalized()

	damage = 1 + extra_dmg
	
	# Face forward in flight direction (full horizontal yaw alignment)
	if direction.length_squared() > 0.01:
		rotation.y = atan2(-direction.z, direction.x)


func _build_vertical_crescent_visuals() -> void:
	# 1. Procedural 3D Piercing Lance Mesh (Compact Spear Tip & Thin Wing Streak)
	var crescent_mesh := _generate_crescent_mesh(0.55, 0.35, 0.04, 16)
	var aura_mesh := _generate_crescent_mesh(0.62, 0.38, 0.06, 16)

	# 2. Outer Golden Aura Shell
	aura_mesh_inst = MeshInstance3D.new()
	aura_mesh_inst.name = "AuraMeshInstance3D"
	aura_mesh_inst.mesh = aura_mesh

	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(1.6, 1.2, 0.35, 0.52)
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(1.6, 1.2, 0.35, 1.0)
	aura_mat.emission_energy_multiplier = 2.4
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura_mesh_inst.material_override = aura_mat
	add_child(aura_mesh_inst)

	# 3. Inner Brilliant White-Gold Core Blade
	core_mesh_inst = MeshInstance3D.new()
	core_mesh_inst.name = "CoreMeshInstance3D"
	core_mesh_inst.mesh = crescent_mesh

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(2.4, 2.0, 1.0, 0.88)
	core_mat.emission_enabled = true
	core_mat.emission = Color(2.4, 2.0, 1.0, 1.0)
	core_mat.emission_energy_multiplier = 3.4
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core_mesh_inst.material_override = core_mat
	add_child(core_mesh_inst)

	# 4. Trailing Golden Sparks Particles
	trail_particles = CPUParticles3D.new()
	trail_particles.name = "TrailParticles3D"
	trail_particles.amount = 24
	trail_particles.lifetime = 0.35
	trail_particles.preprocess = 0.05
	trail_particles.speed_scale = 1.2
	trail_particles.explosiveness = 0.0
	trail_particles.randomness = 0.4
	trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	trail_particles.emission_box_extents = Vector3(0.2, 0.9, 0.15)
	trail_particles.direction = Vector3(-1.0, 0.0, 0.0) # Eject backward
	trail_particles.spread = 25.0
	trail_particles.gravity = Vector3(0.0, -1.5, 0.0)
	trail_particles.initial_velocity_min = 2.0
	trail_particles.initial_velocity_max = 5.0
	trail_particles.scale_amount_min = 0.06
	trail_particles.scale_amount_max = 0.14
	trail_particles.color = Color(3.0, 2.2, 0.8, 0.9)

	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.08, 0.08, 0.08)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(3.0, 2.2, 0.8, 1.0)
	pmat.emission_enabled = true
	pmat.emission = Color(3.0, 2.2, 0.8, 1.0)
	pmat.emission_energy_multiplier = 4.0
	pmesh.material = pmat
	trail_particles.mesh = pmesh
	add_child(trail_particles)

	# 5. Dynamic Ground Illuminating OmniLight3D
	beam_light = OmniLight3D.new()
	beam_light.name = "BeamLight3D"
	beam_light.light_color = Color(1.0, 0.85, 0.45)
	beam_light.light_energy = 2.2
	beam_light.omni_range = 4.2
	beam_light.omni_attenuation = 1.3
	add_child(beam_light)

	# 6. Accurate Vertical Crescent Collision Box
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.2, 0.6) # Vertical blade hit zone
	col.shape = box
	col.position = Vector3(0.2, 0.0, 0.0)
	add_child(col)


func _generate_crescent_mesh(r_out: float, r_in: float, thickness: float, _segments: int) -> ArrayMesh:
	# Forward Piercing Supersonic Thrust Lance Mesh (황금빛 신성 관통창 빔)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tip := Vector3(r_out * 1.35, 0.0, 0.0)      # Sharp forward piercing point
	var tail := Vector3(-r_in * 0.95, 0.0, 0.0)     # Streamlined rear exhaust point
	var half_t := thickness * 0.5
	var wing_h := (r_out - r_in) * 0.55             # Narrow horizontal piercing lance fin

	# Build a 6-sided double-ended diamond thrust lance
	var mid_pts: Array[Vector3] = [
		Vector3(0.0, wing_h, 0.0),           # Top fin
		Vector3(0.0, wing_h * 0.5, half_t),  # Top-right
		Vector3(0.0, -wing_h * 0.5, half_t), # Bottom-right
		Vector3(0.0, -wing_h, 0.0),          # Bottom fin
		Vector3(0.0, -wing_h * 0.5, -half_t),# Bottom-left
		Vector3(0.0, wing_h * 0.5, -half_t)  # Top-left
	]
	var n_pts: int = mid_pts.size()

	# Forward nose cone faces (Tip to perimeter)
	for i in range(n_pts):
		var p0 := mid_pts[i]
		var p1 := mid_pts[(i + 1) % n_pts]
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(tip)
		st.set_uv(Vector2(float(i) / n_pts, 1.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(float(i + 1) / n_pts, 1.0))
		st.add_vertex(p1)

	# Rear tail cone faces (Perimeter to tail)
	for i in range(n_pts):
		var p0 := mid_pts[i]
		var p1 := mid_pts[(i + 1) % n_pts]
		st.set_uv(Vector2(float(i) / n_pts, 0.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(tail)
		st.set_uv(Vector2(float(i + 1) / n_pts, 0.0))
		st.add_vertex(p1)

	st.generate_normals()
	return st.commit()


func _physics_process(delta: float) -> void:
	var move_vec := direction * speed * delta
	global_position += move_vec
	traveled_distance += move_vec.length()

	# Slight dynamic hum/pulse effect
	var pulse := sin(traveled_distance * 4.0) * 0.06
	core_mesh_inst.scale = Vector3(1.0 + pulse, 1.0 + pulse, 1.0)
	aura_mesh_inst.scale = Vector3(1.0 + pulse * 1.5, 1.0 + pulse * 1.5, 1.0)

	if traveled_distance >= max_range:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var bid := body.get_instance_id()
	if _hit_ids.has(bid):
		return
	if body.has_method("receive_hit"):
		_hit_ids[bid] = true
		body.receive_hit(damage, direction)
		_spawn_beam_impact_burst(global_position)
		if pierce_count > 0:
			pierce_count -= 1
		else:
			queue_free()


func _spawn_beam_impact_burst(hit_pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "BeamImpactBurst3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.36
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(3.2, 2.4, 0.8, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(3.2, 2.4, 0.8, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	p.add_child(ring)
	ring.global_position = hit_pos
	ring.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(2.4, 2.4, 2.4), 0.18)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
		tw.chain().tween_callback(ring.queue_free)
