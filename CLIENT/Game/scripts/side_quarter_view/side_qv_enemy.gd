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
var hp_bar_fill: MeshInstance3D = null

const MeleeTexture = preload("res://assets/enemy_frames/melee_v1.png")


var anim_timer: float = 0.0
var anim_frame: int = 0


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")

	_build_components()


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite Sheet 3x2, ~1.55m height)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "EnemySprite3D"
	sprite_3d.texture = MeleeTexture
	sprite_3d.hframes = 3
	sprite_3d.vframes = 2
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.0031 # 500px * 0.0031 = 1.55m height
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 0.78
	sprite_3d.flip_h = true # Faces Left towards player
	add_child(sprite_3d)

	# 2. Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.55
	col.shape = cap
	col.position.y = 0.78
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
	_build_overhead_hp_bar()


func _build_overhead_hp_bar() -> void:
	var bar_root := Node3D.new()
	bar_root.name = "OverheadHPBar"
	bar_root.position = Vector3(0.0, 1.85, 0.0)

	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(0.85, 0.09)
	var bg_inst := MeshInstance3D.new()
	bg_inst.name = "HPBarBG"
	bg_inst.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.12, 0.12, 0.14, 0.88)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_inst.material_override = bg_mat
	bar_root.add_child(bg_inst)

	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.81, 0.065)
	hp_bar_fill = MeshInstance3D.new()
	hp_bar_fill.name = "HPBarFill"
	hp_bar_fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.95, 0.22, 0.24, 0.95)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hp_bar_fill.material_override = fill_mat
	hp_bar_fill.position.z = 0.005
	bar_root.add_child(hp_bar_fill)

	add_child(bar_root)


func _update_hp_bar() -> void:
	if hp_bar_fill != null and is_instance_valid(hp_bar_fill):
		var ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
		hp_bar_fill.scale.x = ratio
		hp_bar_fill.position.x = (ratio - 1.0) * 0.405


var is_attacking: bool = false
var attack_timer: float = 0.0
const ATTACK_DURATION: float = 0.28


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if is_stunned:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		if stun_timer <= 0.0:
			is_stunned = false
		move_and_slide()
		_update_enemy_animation(delta)
		return

	if current_cooldown > 0.0:
		current_cooldown -= delta

	if is_attacking:
		attack_timer += delta
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		if attack_timer >= 0.08 and attack_timer < 0.22:
			attack_area_3d.monitoring = true
		else:
			attack_area_3d.monitoring = false

		if attack_timer >= ATTACK_DURATION:
			is_attacking = false
			attack_area_3d.monitoring = false
		move_and_slide()
		_update_enemy_animation(delta)
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_enemy_animation(delta)
		return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir := diff.normalized()

	if dir.x != 0.0:
		sprite_3d.flip_h = (dir.x < 0.0)

	var combat_standoff_distance := 1.25 # Standoff distance: clean stop without pushing
	if dist > combat_standoff_distance:
		# Pursue player in 3D isometric plane
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * (move_speed * 0.7)
		_prevent_player_pushing()
	else:
		# Firm stop in front of player (no pushing, no bouncing)
		velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
		if current_cooldown <= 0.0:
			_execute_attack()

	move_and_slide()
	_update_enemy_animation(delta)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.40 + 0.35 + 0.06
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


func _update_enemy_animation(delta: float) -> void:
	anim_timer += delta

	# Head-on mutual facing alignment
	if target_player != null and is_instance_valid(target_player):
		var diff_x := target_player.global_position.x - global_position.x
		if absf(diff_x) > 0.05:
			sprite_3d.flip_h = (diff_x < 0.0)

	if is_stunned:
		sprite_3d.frame = 3 # Staggered recoil
		return

	if is_attacking:
		# Row 1: Attack cycle (Frame 3 windup, Frame 4 strike, Frame 5 follow-through)
		var progress := attack_timer / ATTACK_DURATION
		if progress < 0.30:
			sprite_3d.frame = 3 # Windup
		elif progress < 0.75:
			sprite_3d.frame = 4 # Full strike
		else:
			sprite_3d.frame = 5 # Recovery
		return

	if velocity.length() > 0.3:
		# Row 0: Walk cycle (Frames 0, 1, 2)
		sprite_3d.frame = int(anim_timer * 8.0) % 3
	else:
		# Row 0: Idle frame 0
		sprite_3d.frame = 0


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _execute_attack() -> void:
	current_cooldown = attack_cooldown
	is_attacking = true
	attack_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var atk_dir := Vector3(1.0 if not sprite_3d.flip_h else -1.0, 0, 0)
			body.receive_incoming_attack(attack_damage, self, atk_dir)


func apply_parry_stun(duration: float = 2.0) -> void:
	is_stunned = true
	stun_timer = duration
	is_attacking = false
	attack_area_3d.monitoring = false
	velocity = Vector3.ZERO # Firm stop on parry clash; zero slide


func receive_hit(amount: int, _hit_dir: Vector3) -> void:
	current_hp -= amount
	_update_hp_bar()
	velocity = Vector3.ZERO # Hold ground firmly; no bounce

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
	var bar := get_node_or_null("OverheadHPBar") as Node3D
	if bar != null:
		bar.visible = false
	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
