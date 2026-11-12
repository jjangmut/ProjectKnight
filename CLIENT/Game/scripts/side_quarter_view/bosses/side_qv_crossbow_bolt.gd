extends Area3D
class_name SideQVCrossbowBolt
## 사이드 쿼터뷰 폭발/관통 석궁 볼트 투사체 (Side Quarter-View Crossbow Bolt Projectile)
## - 고속 3D 탄도 궤적 및 화염/비전 발광(HDR Glow)
## - 플레이어 충돌 시 대미지 판정 및 피격/가드/저스트 패링 전달
## - 지형 충돌 및 사거리 소진 시 폭발 이펙트와 함께 소멸

const TexHitSpark = preload("res://assets/vfx/vfx_hit_spark_burst.png")
const TexShockwaveRing = preload("res://assets/vfx/vfx_shockwave_ring.png")

@export var speed: float = 18.0
@export var damage: int = 2
@export var is_explosive: bool = false
@export var max_range: float = 32.0

var direction: Vector3 = Vector3.RIGHT
var traveled_distance: float = 0.0
var shooter_ref: Node = null

var bolt_mesh: MeshInstance3D
var tip_glow: OmniLight3D
var is_active: bool = true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 # Player (1) & World (4)
	monitoring = true
	monitorable = false

	_build_visuals()
	body_entered.connect(_on_body_entered)


func launch(start_pos: Vector3, dir: Vector3, shooter: Node, spd: float = 18.0, dmg: int = 2, explosive: bool = false) -> void:
	global_position = start_pos
	direction = dir.normalized()
	speed = spd
	damage = dmg
	shooter_ref = shooter
	is_explosive = explosive

	# 방향 정렬 (3D)
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)


func _build_visuals() -> void:
	# 1. 3D 볼트 화살대 (Cylinder Mesh) — -Z 전방(look_at 방향)을 향해 뾰족한 촉(top_radius)이 향하도록 -90도 정렬
	bolt_mesh = MeshInstance3D.new()
	bolt_mesh.name = "BoltMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.085
	cyl.height = 0.85
	bolt_mesh.mesh = cyl
	bolt_mesh.rotation_degrees.x = -90.0

	var bmat := StandardMaterial3D.new()
	if is_explosive:
		bmat.albedo_color = Color(1.35, 0.7, 0.2, 1.0) # 불타는 주황 화염 코어
		bmat.emission_enabled = true
		bmat.emission = Color(1.35, 0.7, 0.2, 1.0)
		bmat.emission_energy_multiplier = 1.35
	else:
		bmat.albedo_color = Color(0.4, 0.9, 1.4, 1.0) # 코발트 비전 에너지 코어
		bmat.emission_enabled = true
		bmat.emission = Color(0.4, 0.9, 1.4, 1.0)
		bmat.emission_energy_multiplier = 1.35
	bolt_mesh.material_override = bmat
	add_child(bolt_mesh)

	# 1.2 볼트 촉 룬 고리 (비행 속도감이 눈으로 명확히 읽히도록 전방 촉 위치에 비전 링 부착)
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.name = "BoltHeadRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.07
	torus.outer_radius = 0.13
	ring_mesh.mesh = torus
	ring_mesh.rotation_degrees.x = 90.0
	ring_mesh.position = Vector3(0.0, 0.0, -0.25)
	ring_mesh.material_override = bmat
	add_child(ring_mesh)

	# 2. 볼트 촉 발광 라이트
	tip_glow = OmniLight3D.new()
	tip_glow.name = "TipGlow"
	tip_glow.light_color = Color(1.4, 0.75, 0.25) if is_explosive else Color(0.4, 0.85, 1.4)
	tip_glow.light_energy = 1.2
	tip_glow.omni_range = 2.0
	tip_glow.position = Vector3(0.0, 0.0, -0.35)
	add_child(tip_glow)

	# 3. 충돌 콜리전 캡슐
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 0.9
	col.shape = cap
	col.rotation_degrees.x = -90.0
	add_child(col)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var prev_pos := global_position
	var step := speed * delta
	global_position += direction * step
	traveled_distance += step

	# 고속 이동 시 터널링 방지용 레이캐스트 검증 (Mask 1=Player, 4=World)
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var query := PhysicsRayQueryParameters3D.create(prev_pos, global_position, 1 | 4)
		var result := space_state.intersect_ray(query)
		if not result.is_empty() and result.collider != shooter_ref:
			global_position = result.position
			_on_body_entered(result.collider)
			return

	if traveled_distance >= max_range:
		_impact_and_vanish(false)


func _on_body_entered(body: Node3D) -> void:
	if not is_active or body == null or not is_instance_valid(body):
		return

	if body == shooter_ref:
		return

	if body.is_in_group("player"):
		# 주의: _impact_and_vanish(true)가 내부에서 is_active = false 처리 및 queue_free()를 수행하므로
		# 여기서 먼저 is_active = false로 만들면 _impact_and_vanish가 조기 리턴되어 탄환이 공중에 정지한 채 남게 됨!
		_impact_and_vanish(true)
		if body.has_method("receive_incoming_attack"):
			# 플레이어 피격 / 패링 판정 처리 (단일 히트 보장)
			var valid_shooter: Node = shooter_ref if (shooter_ref != null and is_instance_valid(shooter_ref)) else self
			body.receive_incoming_attack(damage, valid_shooter, direction)
		return

	# 지형/기둥/벽 충돌 (World Layer 4 — StaticBody3D 및 CSGShape3D 모두 안전하게 처리)
	var body_layer: int = 0
	if "collision_layer" in body:
		body_layer = int(body.get("collision_layer"))
	if (body_layer & 4) != 0 or body is StaticBody3D or body is CSGShape3D:
		_impact_and_vanish(true)


func _impact_and_vanish(spark: bool) -> void:
	if not is_active:
		return
	is_active = false
	set_physics_process(false)

	if spark and get_parent() != null:
		_spawn_impact_burst()

	queue_free()


func _spawn_impact_burst() -> void:
	var burst := MeshInstance3D.new()
	burst.name = "BoltImpactBurst"
	var quad := QuadMesh.new()
	var sz: float = 1.2 if is_explosive else 0.8
	quad.size = Vector2(sz, sz)
	burst.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TexHitSpark
	var col := Color(1.35, 0.8, 0.3, 0.95) if is_explosive else Color(0.4, 0.95, 1.4, 0.95)
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission_texture = TexHitSpark
	mat.emission = col
	mat.emission_energy_multiplier = 1.35
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	burst.material_override = mat

	get_parent().add_child(burst)
	burst.global_position = global_position

	var tween := burst.create_tween()
	if tween:
		tween.parallel().tween_property(burst, "scale", Vector3(1.8, 1.8, 1.8), 0.16)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.16)
		tween.tween_callback(burst.queue_free)
	else:
		burst.queue_free()
