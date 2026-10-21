extends Camera2D
class_name QVCamera
## 쿼터뷰 2.5D 스무스 트래킹 카메라 (Quarter-View Smooth Tracking Camera)
## - 2.5D 시점 틸트 오프셋 (전방 시야 확보)
## - 트라우마 기반 감쇠 카메라 셰이크 (Trauma Camera Shake)
## - 히트스탑(Hitstop) 프레임 프리즈 연동

@export var target: Node2D = null
@export var smooth_speed: float = 7.5
@export var tilt_offset_y: float = -24.0 # Look slightly upward for 2.5D perspective

var trauma: float = 0.0
var max_shake_offset: float = 18.0
var max_shake_angle: float = 0.04
var shake_noise_y: float = 0.0


func _ready() -> void:
	position_smoothing_enabled = false # Custom smooth lerp for instant responsive hitstop


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var target_pos := target.global_position + Vector2(0.0, tilt_offset_y)
		global_position = global_position.lerp(target_pos, clampf(smooth_speed * delta, 0.0, 1.0))

	# Process Trauma Shake
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.8)
		var shake_amount := trauma * trauma
		shake_noise_y += delta * 45.0
		offset = Vector2(
			randf_range(-1.0, 1.0) * max_shake_offset * shake_amount,
			randf_range(-1.0, 1.0) * max_shake_offset * shake_amount
		)
		rotation = randf_range(-1.0, 1.0) * max_shake_angle * shake_amount
	else:
		offset = Vector2.ZERO
		rotation = 0.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func trigger_hitstop(duration: float = 0.08) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
