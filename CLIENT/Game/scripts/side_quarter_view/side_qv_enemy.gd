extends CharacterBody3D
class_name SideQVEnemy
## 사이드 쿼터뷰 2D 적 미니언 (2D Sprite Enemy in 3D Space)
## - 2D 스프라이트 (Sprite3D) 탑재 & 실시간 3D 그림자 투영
## - 3D 벨트스크롤 추적 AI (X, Z 평면 기동) 및 근접 공격

signal enemy_defeated(enemy_node: Node)

@export var max_hp: int = 4
@export var current_hp: int = 4
@export var move_speed: float = 3.6
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.2

var target_player: Node3D = null
var current_cooldown: float = 0.0
var is_stunned: bool = false
var stun_timer: float = 0.0

var sprite_3d: Sprite3D
var attack_area_3d: Area3D

const MeleeTexture = preload("res://assets/enemy_frames/melee_v1.png")


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")

	_build_components()


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "EnemySprite3D"
	sprite_3d.texture = MeleeTexture
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.003
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 0.9
	add_child(sprite_3d)

	# 2. Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	# 3. Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "EnemyAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player Layer (1)
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.4, 1.4)
	atk_col.shape = box
	atk_col.position = Vector3(0.0, 0.8, 0.0)
	attack_area_3d.add_child(atk_col)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if is_stunned:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		if stun_timer <= 0.0:
			is_stunned = false
		move_and_slide()
		return

	if current_cooldown > 0.0:
		current_cooldown -= delta

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir := diff.normalized()

	if dir.x != 0.0:
		sprite_3d.flip_h = (dir.x < 0.0)

	if dist > 1.6:
		# Pursue player in 3D isometric plane
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * (move_speed * 0.7)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if current_cooldown <= 0.0:
			_execute_attack()

	move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _execute_attack() -> void:
	current_cooldown = attack_cooldown
	attack_area_3d.monitoring = true

	# Visual strike lunge
	var dir_x := 1.0 if not sprite_3d.flip_h else -1.0
	velocity.x = dir_x * 4.0

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		attack_area_3d.monitoring = false


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var atk_dir := Vector3(1.0 if not sprite_3d.flip_h else -1.0, 0, 0)
			body.receive_incoming_attack(attack_damage, self, atk_dir)


func apply_parry_stun(duration: float = 2.0) -> void:
	is_stunned = true
	stun_timer = duration
	var push_back := -1.0 if not sprite_3d.flip_h else 1.0
	velocity = Vector3(push_back * 4.5, 0, 0)
	attack_area_3d.monitoring = false


func receive_hit(amount: int, hit_dir: Vector3) -> void:
	current_hp -= amount
	velocity = hit_dir * 3.5

	# Visual flash
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
