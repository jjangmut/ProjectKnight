extends CharacterBody3D
class_name SideQVBeastMinion
## 사이드 쿼터뷰 숲의 맹수 미니언 (Beast Minion in 3D Space)
## - 2D 고해상도 맹수 스프라이트 (beast_v2.png, 3x2 프레임) 탑재 & 실시간 3D 그림자 투영
## - 3D 필드 추적 및 8.8m/s 저돌적 도약 돌진 공격 (Feral Charge Pounce)
## - 플레이어 상호 밀림 방지 및 저스트 패링 스턴 지원

signal enemy_defeated(enemy_node: Node)

@export var max_hp: int = 5
@export var current_hp: int = 5
@export var move_speed: float = 3.8
@export var charge_speed: float = 8.8
@export var attack_damage: int = 1
@export var charge_cooldown: float = 1.8

enum State {
	IDLE,
	CHASE,
	WINDUP,
	CHARGING,
	RECOVERY,
	STUNNED
}

var current_state: State = State.IDLE
var target_player: Node3D = null
var cooldown_timer: float = 0.0
var state_timer: float = 0.0
var stun_timer: float = 0.0
var is_stunned: bool:
	get:
		return current_state == State.STUNNED

var charge_dir: Vector3 = Vector3.LEFT
var facing_dir_x: float = -1.0

var sprite_3d: Sprite3D
var attack_area_3d: Area3D

const BeastTexture = preload("res://assets/enemy_frames/beast_v2.png")

var anim_timer: float = 0.0
var anim_frame: int = 0


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")

	_build_components()


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite Sheet 3x2, ~1.25m height)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "BeastSprite3D"
	sprite_3d.texture = BeastTexture
	sprite_3d.hframes = 3
	sprite_3d.vframes = 2
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.0035 # 380px * 0.0035 = ~1.33m height
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 0.65
	sprite_3d.flip_h = true # Faces Left towards player initially
	add_child(sprite_3d)

	# 2. Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.3
	col.shape = cap
	col.position.y = 0.65
	add_child(col)

	# 3. Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "BeastAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player Layer (1)
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.4, 1.4)
	atk_col.shape = box
	atk_col.position = Vector3(-0.5, 0.65, 0.0)
	attack_area_3d.add_child(atk_col)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if current_state == State.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		if stun_timer <= 0.0:
			current_state = State.CHASE
		move_and_slide()
		_update_beast_animation(delta)
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_beast_animation(delta)
		return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir_x := signf(diff.x)

	if dir_x != 0.0 and current_state != State.CHARGING:
		facing_dir_x = dir_x
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		attack_area_3d.position.x = 0.5 * facing_dir_x

	match current_state:
		State.IDLE, State.CHASE:
			state_timer += delta
			if cooldown_timer <= 0.0 and dist >= 2.4 and dist <= 7.0:
				_start_charge_windup(diff)
			elif dist > 1.3:
				var dir := diff.normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * (move_speed * 0.7)
				_prevent_player_pushing()
			else:
				velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
				if cooldown_timer <= 0.0:
					_start_charge_windup(diff)

		State.WINDUP:
			state_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
			if state_timer <= 0.0:
				_execute_charge()

		State.CHARGING:
			state_timer -= delta
			velocity = charge_dir * charge_speed
			if dist <= 0.45 + 0.35 + 0.1:
				_execute_impact()
			if state_timer <= 0.0:
				_enter_recovery()

		State.RECOVERY:
			state_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
			if state_timer <= 0.0:
				current_state = State.CHASE

	move_and_slide()
	_update_beast_animation(delta)


func _start_charge_windup(diff: Vector3) -> void:
	current_state = State.WINDUP
	state_timer = 0.32
	charge_dir = diff.normalized()
	velocity = Vector3.ZERO
	# Telegraph flash
	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.5, 0.6, 0.3, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.3)


func _execute_charge() -> void:
	current_state = State.CHARGING
	state_timer = 0.42
	attack_area_3d.monitoring = true


func _execute_impact() -> void:
	if target_player != null and is_instance_valid(target_player):
		if target_player.has_method("receive_incoming_attack"):
			target_player.receive_incoming_attack(attack_damage, self, charge_dir)
	_enter_recovery()


func _enter_recovery() -> void:
	current_state = State.RECOVERY
	state_timer = 0.35
	cooldown_timer = charge_cooldown
	attack_area_3d.monitoring = false
	velocity = Vector3.ZERO


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.45 + 0.35 + 0.08
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


func _update_beast_animation(delta: float) -> void:
	anim_timer += delta

	if current_state == State.STUNNED:
		# Stunned: Row 1 Frame 3 (recoil)
		sprite_3d.frame = 3
		return

	if current_state == State.WINDUP:
		# Windup: Row 1 Frame 3 (crouched pounce stance)
		sprite_3d.frame = 3
		return

	if current_state == State.CHARGING:
		# Charging: Row 1 Frames 4, 5 (lunging bite)
		sprite_3d.frame = 4 + (int(anim_timer * 12.0) % 2)
		return

	if current_state == State.RECOVERY:
		sprite_3d.frame = 3
		return

	# Idle or Chase: Row 0 Frames 0..2
	if velocity.length() > 0.3:
		sprite_3d.frame = int(anim_timer * 8.0) % 3
	else:
		sprite_3d.frame = 0


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var atk_dir := Vector3(facing_dir_x, 0, 0)
			body.receive_incoming_attack(attack_damage, self, atk_dir)


func apply_parry_stun(duration: float = 2.0) -> void:
	current_state = State.STUNNED
	stun_timer = duration
	attack_area_3d.monitoring = false
	velocity = Vector3.ZERO


func receive_hit(amount: int, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	velocity = Vector3.ZERO

	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.5, 0.4, 0.4, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.15)

	if current_hp <= 0:
		_die()


func _die() -> void:
	emit_signal("enemy_defeated", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
