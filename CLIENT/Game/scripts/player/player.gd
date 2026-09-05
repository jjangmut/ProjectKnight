extends CharacterBody2D

@export_category("Movement")
@export var move_speed: float = 320.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.65

@export_category("Jump")
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0


func _physics_process(delta: float) -> void:
	var move_direction := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(move_direction):
		$FacingMark.scale.x = move_direction

	if is_on_floor():
		velocity.x = move_direction * move_speed
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y += gravity * delta
		var air_target_speed := move_direction * move_speed
		var air_acceleration := move_speed * 8.0 * air_control
		velocity.x = move_toward(velocity.x, air_target_speed, air_acceleration * delta)

	move_and_slide()
