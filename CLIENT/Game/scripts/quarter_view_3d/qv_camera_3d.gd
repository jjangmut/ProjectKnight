extends Camera3D
class_name QVCamera3D
## 쿼터뷰 3D 트래킹 카메라 (Quarter-View 3D Tracking Camera)
## 52도 쿼터뷰 아이소메트릭 투시 시점, 부드러운 플레이어 추적, 트라우마 셰이크 및 히트스탑 연동

@export var target: Node3D = null
@export var smooth_speed: float = 6.0
@export var camera_offset: Vector3 = Vector3(0.0, 9.2, 7.6) # Isometric pitch ~52 deg

var trauma: float = 0.0
var max_shake_offset: float = 0.6
var max_shake_angle: float = 0.03


func _ready() -> void:
	current = true
	# Fixed isometric pitch down
	rotation_degrees = Vector3(-51.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var target_pos := target.global_position + camera_offset
		global_position = global_position.lerp(target_pos, clampf(smooth_speed * delta, 0.0, 1.0))

	# Process Trauma Shake
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.8)
		var shake := trauma * trauma
		h_offset = randf_range(-1.0, 1.0) * max_shake_offset * shake
		v_offset = randf_range(-1.0, 1.0) * max_shake_offset * shake
	else:
		h_offset = 0.0
		v_offset = 0.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func trigger_hitstop(duration: float = 0.08) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
