extends CharacterBody3D
class_name SideQVRangedMinion
## 사이드 쿼터뷰 원거리 석궁병 미니언 (Side Quarter-View Crossbow Minion)
## - 2D 고해상도 석궁병 스프라이트 (ranged_v1.png 3x2)
## - 원거리 사격 간격 유지 AI 및 주기적 단발 볼트 사격
## - 피격 / 저스트 패링 스턴 / 상호 밀림 방지 / 정면 응시

signal enemy_defeated(enemy_node: Node)

@export var max_hp: int = 4
@export var current_hp: int = 4
@export var move_speed: float = 3.2
@export var shoot_interval: float = 2.4
@export var standoff_dist: float = 5.2

var target_player: Node3D = null
var shoot_timer: float = 1.0
var is_stunned: bool = false
var stun_timer: float = 0.0
var is_aiming: bool = false
var anim_timer: float = 0.0

var sprite_3d: Sprite3D
var hp_bar_fill: MeshInstance3D = null
var facing_dir_x: float = -1.0
var is_dead: bool = false
var _death_signaled: bool = false
var is_recoiling: bool = false
var recoil_timer: float = 0.0

const CrossbowBoltScene = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd")
const MinionTexture = preload("res://assets/enemy_frames/ranged_v1.png")


func _ready() -> void:
	collision_layer = 2 # Enemy Layer
	collision_mask = 1 | 4 # Player & World
	add_to_group("enemies")

	_build_components()


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite Sheet 3x2, ~1.55m height)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "MinionSprite3D"
	sprite_3d.texture = MinionTexture
	sprite_3d.hframes = 3
	sprite_3d.vframes = 2
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.0031 # 500px * 0.0031 = 1.55m
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 0.78
	sprite_3d.flip_h = true
	add_child(sprite_3d)

	# 2. Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.55
	col.shape = cap
	col.position.y = 0.78
	add_child(col)

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


func _physics_process(delta: float) -> void:
	# Option C: 엄격한 Z=0.0 평면 고정
	velocity.z = 0.0
	global_position.z = 0.0

	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if is_stunned:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = 0.0
		sprite_3d.frame = 4 # Hurt frame
		if stun_timer <= 0.0:
			is_stunned = false
		move_and_slide()
		velocity.z = 0.0
		global_position.z = 0.0
		return

	if is_recoiling:
		recoil_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = 0.0
		global_position.z = 0.0
		if recoil_timer <= 0.0:
			is_recoiling = false
		move_and_slide()
		velocity.z = 0.0
		global_position.z = 0.0
		_update_animation(delta)
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		velocity.z = 0.0
		global_position.z = 0.0
		return

	# 1D 수평 거리 및 방향 계산 (Z 성분 완전 배제)
	var dx := target_player.global_position.x - global_position.x
	var dist := absf(dx)
	var dir_x := signf(dx) if absf(dx) > 0.001 else facing_dir_x

	if not is_aiming and dir_x != 0.0:
		facing_dir_x = dir_x
		sprite_3d.flip_h = (facing_dir_x < 0.0)

	# 원거리 사격 사거리 조율 (1D 수평 이동)
	if not is_aiming:
		if dist < standoff_dist - 0.8:
			velocity.x = -dir_x * move_speed
			velocity.z = 0.0
		elif dist > standoff_dist + 1.2:
			velocity.x = dir_x * move_speed
			velocity.z = 0.0
			_prevent_player_pushing()
		else:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = 0.0

		shoot_timer -= delta
		if shoot_timer <= 0.0 and dist <= 12.0:
			_execute_shoot()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = 0.0

	move_and_slide()
	velocity.z = 0.0
	global_position.z = 0.0
	_update_animation(delta)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var dx := target_player.global_position.x - global_position.x
		var dist := absf(dx)
		var min_dist: float = 0.38 + 0.35 + 0.10
		if dist < min_dist and dist > 0.001:
			var dir_x := signf(dx)
			if velocity.x * dir_x > 0.0:
				velocity.x = 0.0


func _execute_shoot() -> void:
	is_aiming = true
	shoot_timer = shoot_interval + randf_range(-0.3, 0.4)
	sprite_3d.frame = 1 # Aim frame

	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or is_stunned:
		is_aiming = false
		return

	sprite_3d.frame = 2 # Fire frame
	if target_player != null and is_instance_valid(target_player):
		var dy := (target_player.global_position.y + 0.7) - (global_position.y + 0.8)
		var aim_dir := Vector3(target_player.global_position.x - global_position.x, dy, 0.0).normalized()
		var bolt := CrossbowBoltScene.new()
		get_parent().add_child(bolt)
		bolt.launch(global_position + Vector3(facing_dir_x * 0.5, 0.8, 0.0), aim_dir, self, 15.0, 1, false)

	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self):
		is_aiming = false


func _update_animation(delta: float) -> void:
	if is_aiming:
		return
	if is_recoiling or is_stunned:
		sprite_3d.frame = 4 # Recoil / hurt frame
		return
	anim_timer += delta
	if velocity.length() > 0.3:
		sprite_3d.frame = int(anim_timer * 6.0) % 2
	else:
		sprite_3d.frame = 0


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func apply_parry_stun(duration: float = 2.0) -> void:
	is_stunned = true
	stun_timer = duration
	is_aiming = false
	velocity = Vector3.ZERO
	sprite_3d.frame = 4

	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(3.0, 2.5, 0.8, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.2)


func receive_hit(amount: int, hit_dir: Vector3 = Vector3.ZERO, is_counter: bool = false) -> void:
	if is_dead or current_hp <= 0 or amount <= 0:
		return
	current_hp -= amount
	_update_hp_bar()

	# 1. Distinct visual hit confirmation flash
	if sprite_3d != null:
		var tween := create_tween()
		if tween:
			if is_counter:
				sprite_3d.modulate = Color(1.5, 3.2, 4.0, 1.0) # Radiant cyan/gold counter resonance
				tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.18)
			else:
				sprite_3d.modulate = Color(3.5, 1.0, 1.0, 1.0) # Sharp white-hot damage flash
				tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.12)

	# 2. Confirmed damage micro-recoil (clamped, pure X impulse, Z=0 locked)
	var push_x := hit_dir.x
	if push_x == 0.0:
		push_x = -1.0 if (sprite_3d == null or not sprite_3d.flip_h) else 1.0
	var impulse: float = 3.6 if is_counter else 2.2
	velocity.x = push_x * impulse
	velocity.z = 0.0
	global_position.z = 0.0
	is_recoiling = true
	recoil_timer = 0.09

	if current_hp <= 0:
		_die(is_counter)


func _die(is_counter: bool = false) -> void:
	if is_dead:
		return
	is_dead = true
	is_recoiling = false
	is_aiming = false

	# Immediate collision de-registration & attack prevention
	collision_layer = 0
	collision_mask = 0

	# Atomic single reward/progress dispatch
	if not _death_signaled:
		_death_signaled = true
		emit_signal("enemy_defeated", self)

	set_physics_process(false)
	velocity = Vector3.ZERO
	global_position.z = 0.0

	var bar := get_node_or_null("OverheadHPBar") as Node3D
	if bar != null:
		bar.visible = false

	# Readable visual defeat transition: defeat stagger frame + upward dissolve + spark ring
	if sprite_3d != null:
		sprite_3d.frame = 5 # Defeat frame
	_spawn_defeat_burst(is_counter)

	if sprite_3d != null:
		var tween := create_tween()
		if tween:
			tween.set_parallel(true)
			var dissolve_color := Color(1.0, 2.8, 3.5, 0.0) if is_counter else Color(3.2, 0.8, 0.3, 0.0)
			tween.tween_property(sprite_3d, "modulate", dissolve_color, 0.28)
			tween.tween_property(sprite_3d, "position:y", sprite_3d.position.y + 0.20, 0.28)
			tween.tween_property(sprite_3d, "scale", sprite_3d.scale * 0.85, 0.28)
			tween.chain().tween_callback(queue_free)
		else:
			queue_free()
	else:
		queue_free()


func _spawn_defeat_burst(is_counter: bool = false) -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "DefeatBurstRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.45
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	var burst_col := Color(0.8, 2.6, 3.8, 1.0) if is_counter else Color(3.5, 1.2, 0.3, 1.0)
	mat.albedo_color = burst_col
	mat.emission_enabled = true
	mat.emission = burst_col
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat

	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.78, 0.0)
	ring.global_position.z = 0.0
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(2.2, 2.2, 2.2), 0.26)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.26)
		tw.chain().tween_callback(ring.queue_free)
