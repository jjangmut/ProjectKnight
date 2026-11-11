extends Area3D
class_name SideQVCaltropTrap
## 사이드 쿼터뷰 지면 마름쇠 트랩 (Side Quarter-View Caltrop Trap)
## - 보스 석궁 사령관이 살포하는 지면 가시 트랩
## - 플레이어가 밟으면 1 피해 및 2초간 40% 이동속도 둔화(Slow) 적용
## - 12초 경과 시 자동 소멸

@export var trap_damage: int = 1
@export var slow_duration: float = 2.0
@export var slow_ratio: float = 0.60 # 60% of original speed (40% slow)

var owner_ref: Node = null
var is_triggered: bool = false
var trap_lifetime: float = 12.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player (Layer 1)
	monitoring = true
	monitorable = false

	_build_caltrop_visuals()
	body_entered.connect(_on_body_entered)


func setup(pos: Vector3, owner_node: Node) -> void:
	global_position = pos
	global_position.y = 0.04 # 지면 살짝 위에 배치
	global_position.z = 0.0  # Option C: 전투 레인 Z=0.0 고정
	owner_ref = owner_node


func _process(delta: float) -> void:
	trap_lifetime -= delta
	if trap_lifetime <= 0.0 and not is_triggered:
		_fade_out_and_free()


func _build_caltrop_visuals() -> void:
	# 사각뿔/삼각뿔 가시 4개가 사방으로 뻗은 마름쇠 클러스터
	var cluster := Node3D.new()
	cluster.name = "SpikeCluster"
	add_child(cluster)

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.18, 0.22, 1.0)
	iron_mat.metallic = 0.95
	iron_mat.roughness = 0.35
	iron_mat.emission_enabled = true
	iron_mat.emission = Color(1.8, 0.3, 0.2, 1.0) # 위험 경고용 붉은빛 발광
	iron_mat.emission_energy_multiplier = 1.8

	# 중앙 베이스
	var center_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	center_mesh.mesh = sphere
	center_mesh.material_override = iron_mat
	cluster.add_child(center_mesh)

	# 4개의 날카로운 스파이크 (Prism / Cylinder)
	var angles: Array[float] = [0.0, 90.0, 180.0, 270.0]
	for ang: float in angles:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.08
		cone.height = 0.45
		spike.mesh = cone
		spike.material_override = iron_mat
		spike.position = Vector3(cos(deg_to_rad(ang)) * 0.18, 0.12, sin(deg_to_rad(ang)) * 0.18)
		spike.rotation_degrees = Vector3(15.0, ang, 25.0)
		cluster.add_child(spike)

	# 3D 충돌 실린더 (반경 0.55m)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 0.4
	col.shape = cyl
	col.position.y = 0.15
	add_child(col)


func _on_body_entered(body: Node3D) -> void:
	if is_triggered:
		return

	if body.is_in_group("player") and is_instance_valid(body):
		is_triggered = true
		set_deferred("monitoring", false)

		# 1. 플레이어 대미지 적용
		if body.has_method("receive_incoming_attack"):
			body.receive_incoming_attack(trap_damage, owner_ref, Vector3.ZERO)

		# 2. 이동속도 둔화(Slow) 적용
		_apply_slow_to_player(body)

		# 3. 마름쇠 파괴 스파크 연출 및 소멸
		_snap_burst_and_free()


func _apply_slow_to_player(player: Node3D) -> void:
	if "move_speed_x" in player:
		if not player.has_meta("base_move_speed_x"):
			player.set_meta("base_move_speed_x", player.move_speed_x)
		var base_speed: float = player.get_meta("base_move_speed_x", player.move_speed_x)
		var slow_count: int = player.get_meta("active_caltrop_slow_count", 0) + 1
		player.set_meta("active_caltrop_slow_count", slow_count)
		player.move_speed_x = base_speed * slow_ratio

		# 2초 둔화 후 복원 (중첩 카운트 관리로 안전한 속도 복원)
		var timer := get_tree().create_timer(slow_duration)
		timer.timeout.connect(func():
			if is_instance_valid(player):
				var cur_count: int = player.get_meta("active_caltrop_slow_count", 1) - 1
				player.set_meta("active_caltrop_slow_count", cur_count)
				if cur_count <= 0:
					player.move_speed_x = base_speed
		)


func _snap_burst_and_free() -> void:
	var flash := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	flash.mesh = box

	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(2.5, 0.5, 0.2, 1.0)
	fmat.emission_enabled = true
	fmat.emission = Color(2.5, 0.5, 0.2, 1.0)
	fmat.emission_energy_multiplier = 4.0
	flash.material_override = fmat
	if get_parent() != null:
		get_parent().add_child(flash)
		flash.global_position = global_position + Vector3(0, 0.2, 0)

	var tween := flash.create_tween()
	if tween:
		tween.tween_property(flash, "scale", Vector3(1.5, 1.5, 1.5), 0.12)
		tween.tween_callback(flash.queue_free)
	else:
		flash.queue_free()

	queue_free()


func _fade_out_and_free() -> void:
	is_triggered = true
	monitoring = false
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
