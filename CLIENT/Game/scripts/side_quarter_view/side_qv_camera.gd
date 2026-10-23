extends Camera3D
class_name SideQVCamera
## 사이드 쿼터뷰 3D 카메라 (Side Quarter-View 2.5D Tracking Camera)
## - 횡스크롤 느낌의 측면 시점(Side-View) + 3D 배경의 원근 깊이를 살린 쿼터뷰 각도 (Pitch -15도, Yaw 8도)
## - 플레이어 스무스 추적, 타격감 트라우마 셰이크 및 히트스탑 지원

@export var target: Node3D = null
@export var follow_smoothness: float = 6.0
@export var camera_offset: Vector3 = Vector3(0.0, 5.2, 7.8)

var trauma: float = 0.0
var trauma_power: float = 2.0
var max_offset: float = 0.35
var max_roll: float = 2.5
var time_counter: float = 0.0

var base_pos: Vector3 = Vector3.ZERO
var base_rot: Vector3 = Vector3(-32.0, 0.0, 0.0) # Horizontal Quarter-View (Immortal Warrior Style, Yaw=0, Pitch=-32)


func _ready() -> void:
	current = true
	fov = 42.0
	rotation_degrees = base_rot


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var dest := target.global_position + camera_offset
		# Smooth follow
		base_pos = base_pos.lerp(dest, follow_smoothness * delta)
	
	global_position = base_pos

	# Trauma camera shake
	if trauma > 0.0:
		time_counter += delta * 35.0
		trauma = maxf(trauma - delta * 1.5, 0.0)
		var shake := pow(trauma, trauma_power)
		var offset_x := max_offset * shake * sin(time_counter)
		var offset_y := max_offset * shake * cos(time_counter * 1.3)
		var roll := max_roll * shake * sin(time_counter * 0.7)

		global_position += Vector3(offset_x, offset_y, 0.0)
		rotation_degrees = base_rot + Vector3(0.0, 0.0, roll)
	else:
		rotation_degrees = base_rot


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func trigger_hitstop(duration: float = 0.06) -> void:
	var tree := get_tree()
	if tree:
		Engine.time_scale = 0.05
		await tree.create_timer(duration, true, false, true).timeout
		Engine.time_scale = 1.0
