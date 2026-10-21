extends CharacterBody2D
class_name QVEnemy
## 쿼터뷰 2.5D 적 유닛 (Quarter-View 2.5D Enemy)
## - 8방향 쿼터뷰 플레이어 추적 및 거리 유지
## - Y-Sort 깊이 정렬 완벽 호환 (발밑 피벗)
## - 바닥 그림자 및 부채꼴 근접 공격
## - 플레이어 저스트 패링 시 1.5초 기절(Stun)
## - 플레이어와 단순 접촉 시 ZERO-데미지 순수 넉백 분리

signal enemy_died(enemy_node: Node)
signal enemy_hp_changed(current: int, max_hp: int)

@export var move_speed: float = 140.0
@export var max_hp: int = 6
@export var current_hp: int = 6
@export var attack_damage: int = 1
@export var attack_range: float = 48.0
@export var attack_cooldown: float = 1.6

var target_player: QVPlayer = null
var is_stunned: bool = false
var stun_time_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var facing_direction: Vector2 = Vector2.LEFT

# Visual & Hitboxes
var visual_root: Node2D
var enemy_sprite: Sprite2D
var shadow: Line2D
var attack_area: Area2D
var hurtbox_area: Area2D
var slash_line: Line2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2 # Enemy Body
	collision_mask = 1 | 4 # Player (layer 1) & Walls (layer 4)
	add_to_group("enemies")

	_build_components()
	emit_signal("enemy_hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. Floor Drop Shadow
	shadow = Line2D.new()
	shadow.name = "FloorShadow"
	shadow.width = 12.0
	shadow.default_color = Color(0.02, 0.02, 0.05, 0.45)
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.points = PackedVector2Array([Vector2(-14.0, 0.0), Vector2(14.0, 0.0)])
	add_child(shadow)

	# 2. Visual Root
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	# 3. Enemy Sprite
	enemy_sprite = Sprite2D.new()
	enemy_sprite.name = "EnemySprite"
	var tex = load("res://assets/enemy_frames/boss_commander_v2.png")
	if tex == null:
		tex = load("res://assets/player/knight_idle_v1.png")
	enemy_sprite.texture = tex
	enemy_sprite.position = Vector2(0.0, -28.0)
	enemy_sprite.modulate = Color(1.2, 0.8, 0.8, 1.0) # Crimson tint
	visual_root.add_child(enemy_sprite)

	# 4. Weapon Slash Effect
	slash_line = Line2D.new()
	slash_line.name = "SlashLine"
	slash_line.width = 6.0
	slash_line.default_color = Color(2.0, 0.4, 0.4, 0.9)
	slash_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash_line.points = PackedVector2Array([Vector2(0, -20), Vector2(32, -28), Vector2(36, 0)])
	slash_line.visible = false
	visual_root.add_child(slash_line)

	# 5. Attack Area
	attack_area = Area2D.new()
	attack_area.name = "EnemyAttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = 1 # Player Layer
	attack_area.monitoring = false
	attack_area.monitorable = false

	var atk_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	atk_shape.shape = circle
	atk_shape.position = Vector2(28.0, 0.0)
	attack_area.add_child(atk_shape)
	visual_root.add_child(attack_area)

	# 6. Enemy Body Collision (Small circle at feet)
	var body_col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 28.0
	body_col.shape = cap
	body_col.position = Vector2(0.0, -10.0)
	add_child(body_col)

	# 7. Enemy Hurtbox
	hurtbox_area = Area2D.new()
	hurtbox_area.name = "EnemyHurtbox"
	hurtbox_area.collision_layer = 2
	hurtbox_area.collision_mask = 0
	hurtbox_area.add_to_group("enemy_hurtbox")

	var hurt_shape := CollisionShape2D.new()
	var hurt_cap := CapsuleShape2D.new()
	hurt_cap.radius = 16.0
	hurt_cap.height = 42.0
	hurt_shape.shape = hurt_cap
	hurt_shape.position = Vector2(0.0, -24.0)
	hurtbox_area.add_child(hurt_shape)
	add_child(hurtbox_area)

	attack_area.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta

	if is_stunned:
		stun_time_remaining -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		if stun_time_remaining <= 0.0:
			is_stunned = false
			modulate = Color.WHITE
		move_and_slide()
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := target_player.global_position - global_position
	var dist := to_player.length()
	facing_direction = to_player.normalized()

	# Flip sprite
	if absf(facing_direction.x) > 0.1:
		visual_root.scale.x = 1.0 if facing_direction.x > 0 else -1.0

	if dist <= attack_range:
		# Attack Player
		velocity = Vector2.ZERO
		if cooldown_remaining <= 0.0:
			_execute_attack()
	else:
		# Pursue Player in 8-direction 2.5D plane
		velocity = facing_direction * move_speed

	move_and_slide()

	# Pure contact check with player: zero damage, bounce away
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider = col.get_collider()
		if collider != null and collider.is_in_group("player"):
			# Zero damage pure knockback push
			var push_dir: Vector2 = (collider.global_position - global_position).normalized()
			if collider.has_method("apply_contact_knockback"):
				collider.apply_contact_knockback(push_dir * 280.0)
			velocity = -push_dir * 200.0


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0]
	else:
		# Fallback search by type
		for child in get_parent().get_children():
			if child.is_in_group("player"):
				target_player = child
				break


func _execute_attack() -> void:
	cooldown_remaining = attack_cooldown
	slash_line.visible = true
	attack_area.monitoring = true

	# Small forward lunge
	velocity = facing_direction * 220.0

	await get_tree().create_timer(0.18).timeout
	if is_instance_valid(self):
		slash_line.visible = false
		attack_area.monitoring = false


func _on_attack_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			body.receive_incoming_attack(attack_damage, self, facing_direction)


func apply_parry_stun(duration: float = 1.5) -> void:
	is_stunned = true
	stun_time_remaining = duration
	velocity = -facing_direction * 180.0
	slash_line.visible = false
	attack_area.monitoring = false
	modulate = Color(1.8, 1.8, 0.4, 1.0) # Golden Stun Glow


func receive_hit(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	current_hp -= amount
	emit_signal("enemy_hp_changed", current_hp, max_hp)

	# Knockback
	velocity = hit_direction * 260.0

	# Flash white
	var tween := create_tween()
	if tween:
		modulate = Color(2.5, 2.5, 2.5, 1.0)
		tween.tween_property(self, "modulate", Color.WHITE if not is_stunned else Color(1.8, 1.8, 0.4, 1.0), 0.12)

	if current_hp <= 0:
		_die()


func _die() -> void:
	emit_signal("enemy_died", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)
	else:
		queue_free()
