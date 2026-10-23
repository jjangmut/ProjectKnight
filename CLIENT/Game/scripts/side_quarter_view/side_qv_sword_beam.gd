extends Area3D
class_name SideQVSwordBeam
## 사이드 쿼터뷰 3D 발광 크레센트 검기 (Side Quarter-View Glowing Crescent Sword Beam)
## 2D 캐릭터가 3D 배경 공간으로 사출하는 입체 검기 투사체

@export var speed: float = 18.0
@export var damage: int = 2
@export var max_range: float = 24.0

var direction: Vector3 = Vector3.RIGHT
var traveled_distance: float = 0.0

var mesh_inst: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Enemies (Layer 2)
	monitoring = true
	monitorable = false

	_build_visuals()
	body_entered.connect(_on_body_entered)


func initialize(start_pos: Vector3, dir: Vector3, extra_dmg: int = 0) -> void:
	global_position = start_pos
	direction = dir.normalized()
	direction.y = 0.0
	direction = direction.normalized()

	damage = 2 + extra_dmg
	if direction.x < 0:
		scale.x = -1.0


func _build_visuals() -> void:
	mesh_inst = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.25
	torus.rings = 16
	torus.ring_segments = 8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(2.5, 1.8, 0.4, 1.0) # Golden Overdrive HDR
	mat.emission_enabled = true
	mat.emission = Color(2.5, 1.8, 0.4, 1.0)
	mat.emission_energy_multiplier = 3.5
	mesh_inst.mesh = torus
	mesh_inst.material_override = mat

	# Flatten into crescent blade
	mesh_inst.scale = Vector3(1.3, 0.25, 0.7)
	mesh_inst.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	add_child(mesh_inst)

	# 3D Collision Box
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.2, 1.8)
	col.shape = box
	add_child(col)


func _physics_process(delta: float) -> void:
	var move_vec := direction * speed * delta
	global_position += move_vec
	traveled_distance += move_vec.length()

	if traveled_distance >= max_range:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("receive_hit"):
		body.receive_hit(damage, direction)
		queue_free()
