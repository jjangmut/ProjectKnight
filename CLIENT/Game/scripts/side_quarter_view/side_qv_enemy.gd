extends CharacterBody3D
class_name SideQVEnemy
## 사이드 쿼터뷰 2D 적 미니언 (2D Sprite Enemy in 3D Space)
## - 2D 스프라이트 (Sprite3D) 탑재 & 실시간 3D 그림자 투영
## - 3D 벨트스크롤 추적 AI (X, Z 평면 기동) 및 근접 공격

signal enemy_defeated(enemy_node: Node)

@export var max_hp: int = 6
@export var current_hp: int = 6
@export var move_speed: float = 3.8
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.25

var target_player: Node3D = null
var current_cooldown: float = 0.0
var is_stunned: bool = false
var stun_timer: float = 0.0
var is_dead: bool = false
var _death_signaled: bool = false
var is_recoiling: bool = false
var recoil_timer: float = 0.0
var consecutive_hits_taken: int = 0
var hit_combo_reset_timer: float = 0.0
var is_counter_riposte: bool = false
var flank_z_bias: float = 0.0

var sprite_3d: Sprite3D
var attack_area_3d: Area3D
var ground_shadow: MeshInstance3D = null
var hp_bar_fill: MeshInstance3D = null

const MeleeTexture = preload("res://assets/enemy_frames/melee_v1.png")
const TexMeleeDirectional = preload("res://assets/enemy_frames/directional/melee_directional_aligned.png")
const TexHitSpark = preload("res://assets/vfx/vfx_hit_spark_burst.png")
const TexShockwaveRing = preload("res://assets/vfx/vfx_shockwave_ring.png")

enum FacingDir { SIDE_RIGHT, SIDE_LEFT, FRONT_SOUTH, BACK_NORTH }
var current_facing_dir: FacingDir = FacingDir.SIDE_LEFT


var anim_timer: float = 0.0
var anim_frame: int = 0


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")
	flank_z_bias = -0.85 if (get_instance_id() % 2 == 0) else 0.85

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
	attack_area_3d.position = Vector3(-0.6, 0.0, 0.0)
	attack_area_3d.add_child(atk_col)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)
	_build_overhead_hp_bar()

	# Soft Ground Contact Shadow Decal
	var shadow_mesh := MeshInstance3D.new()
	shadow_mesh.name = "GroundContactShadow"
	ground_shadow = shadow_mesh
	var s_quad := QuadMesh.new()
	s_quad.size = Vector2(0.85, 0.40)
	shadow_mesh.mesh = s_quad
	shadow_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	shadow_mesh.position = Vector3(0.0, 0.015, 0.0)
	var sh_mat := StandardMaterial3D.new()
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.albedo_color = Color(0.02, 0.03, 0.05, 0.50)
	shadow_mesh.material_override = sh_mat
	add_child(shadow_mesh)


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
var attack_phase: String = "IDLE"
const ATTACK_DURATION: float = 0.52


func _physics_process(delta: float) -> void:
	if sprite_3d != null and is_instance_valid(sprite_3d):
		sprite_3d.sorting_offset = clampf(global_position.z * 0.25, -2.0, 2.0)

	if hit_combo_reset_timer > 0.0:
		hit_combo_reset_timer -= delta
		if hit_combo_reset_timer <= 0.0:
			consecutive_hits_taken = 0

	# Anchor ground shadow to floor level
	if ground_shadow != null and is_instance_valid(ground_shadow):
		if is_on_floor():
			ground_shadow.position = Vector3(0.0, 0.015, 0.0)
		else:
			ground_shadow.global_position.y = 0.015
			ground_shadow.global_position.x = global_position.x
			ground_shadow.global_position.z = global_position.z
	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if is_recoiling:
		recoil_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)
		_apply_enemy_separation(delta)
		if recoil_timer <= 0.0:
			is_recoiling = false
		move_and_slide()
		_update_enemy_animation(delta)
		return

	if is_stunned:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		_apply_enemy_separation(delta)
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
		if attack_timer < 0.24:
			attack_phase = "TELL"
			attack_area_3d.monitoring = false
		elif attack_timer < 0.38:
			attack_phase = "ACTIVE"
			attack_area_3d.monitoring = true
		else:
			attack_phase = "RECOVERY"
			attack_area_3d.monitoring = false

		if attack_timer >= ATTACK_DURATION:
			is_attacking = false
			is_counter_riposte = false
			attack_phase = "IDLE"
			attack_area_3d.monitoring = false
		_apply_enemy_separation(delta)
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

	if absf(diff.x) >= absf(diff.z) * 1.05:
		current_facing_dir = FacingDir.SIDE_RIGHT if diff.x > 0.0 else FacingDir.SIDE_LEFT
	elif diff.z > 0.0:
		current_facing_dir = FacingDir.FRONT_SOUTH
	else:
		current_facing_dir = FacingDir.BACK_NORTH

	if current_facing_dir == FacingDir.SIDE_LEFT:
		sprite_3d.flip_h = true
	elif current_facing_dir == FacingDir.SIDE_RIGHT:
		sprite_3d.flip_h = false
	else:
		sprite_3d.flip_h = false

	attack_area_3d.position = Vector3(dir.x * 0.78, 0.0, dir.z * 0.78)

	var combat_standoff := 1.42
	if dist > combat_standoff:
		var z_target_diff := (target_player.global_position.z + flank_z_bias * 0.35) - global_position.z
		velocity.x = dir.x * move_speed
		velocity.z = clampf(z_target_diff * 2.2, -1.0, 1.0) * (move_speed * 0.80)
		_prevent_player_pushing()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
		if current_cooldown <= 0.0:
			_execute_attack()

	_apply_enemy_separation(delta)
	move_and_slide()
	_update_enemy_animation(delta)


func _apply_enemy_separation(delta: float) -> void:
	var sep_vec := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or not (other is Node3D):
			continue
		var o3d := other as Node3D
		var diff := global_position - o3d.global_position
		diff.y = 0.0
		var d := diff.length()
		var min_sep := 1.25
		if d < min_sep:
			var push_dir := diff / d if d > 0.001 else Vector3(0.4, 0.0, flank_z_bias).normalized()
			sep_vec += push_dir * ((min_sep - d) / min_sep)
	if sep_vec.length_squared() > 0.0001:
		velocity.x += sep_vec.x * 16.0 * delta
		velocity.z += sep_vec.z * 20.0 * delta
		global_position.x += sep_vec.x * 2.2 * delta
		global_position.z = clampf(global_position.z + sep_vec.z * 2.8 * delta, -2.9, 2.9)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 1.12
		if dist < min_dist and dist > 0.001:
			var dir := diff.normalized()
			var speed_towards := velocity.dot(dir)
			if speed_towards > 0.0:
				velocity -= dir * speed_towards


func _update_enemy_animation(delta: float) -> void:
	anim_timer += delta

	var is_directional: bool = (current_facing_dir == FacingDir.FRONT_SOUTH or current_facing_dir == FacingDir.BACK_NORTH)
	var target_tex: Texture2D = TexMeleeDirectional if is_directional else MeleeTexture

	if sprite_3d.texture != target_tex:
		sprite_3d.texture = target_tex
		sprite_3d.hframes = 3
		sprite_3d.vframes = 2
		sprite_3d.pixel_size = 0.0031

	if is_directional:
		sprite_3d.flip_h = false
		var base_frame: int = 0 if current_facing_dir == FacingDir.FRONT_SOUTH else 3
		if is_recoiling or is_stunned:
			sprite_3d.frame = base_frame
			return
		if is_attacking:
			sprite_3d.frame = base_frame + 2
			return
		if velocity.length() > 0.3:
			sprite_3d.frame = base_frame + 1 if int(anim_timer * 6.0) % 2 == 0 else base_frame
		else:
			sprite_3d.frame = base_frame
		return

	# Side Facing (MeleeTexture)
	if current_facing_dir == FacingDir.SIDE_LEFT:
		sprite_3d.flip_h = true
	elif current_facing_dir == FacingDir.SIDE_RIGHT:
		sprite_3d.flip_h = false

	if is_recoiling or is_stunned:
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


func _execute_attack(as_riposte: bool = false) -> void:
	current_cooldown = attack_cooldown
	is_attacking = true
	is_counter_riposte = as_riposte
	attack_timer = 0.0
	attack_phase = "TELL"
	velocity.x = 0.0
	velocity.z = 0.0
	if sprite_3d != null:
		var tw := create_tween()
		if tw:
			sprite_3d.modulate = Color(2.4, 0.9, 0.3, 1.0) if as_riposte else Color(2.2, 1.6, 0.4, 1.0) # Weapon gleam telegraph
			tw.tween_property(sprite_3d, "modulate", Color.WHITE, 0.22)
	_spawn_windup_telegraph_ring()


func _spawn_windup_telegraph_ring() -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "EnemyWindupRing3D"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	ring.mesh = quad
	ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = TexShockwaveRing
	rmat.albedo_color = Color(1.4, 0.45, 0.18, 0.85)
	rmat.emission_enabled = true
	rmat.emission_texture = TexShockwaveRing
	rmat.emission = Color(1.4, 0.45, 0.18, 1.0)
	rmat.emission_energy_multiplier = 1.25
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.04, 0.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(1.65, 1.65, 1.65), 0.24)
		tw.tween_property(rmat, "albedo_color:a", 0.0, 0.24)
		tw.chain().tween_callback(ring.queue_free)


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var atk_dir := (body.global_position - global_position).normalized()
			if atk_dir.length_squared() < 0.01:
				atk_dir = Vector3(1.0 if not sprite_3d.flip_h else -1.0, 0, 0)
			var dmg := attack_damage + (1 if is_counter_riposte else 0)
			body.receive_incoming_attack(dmg, self, atk_dir)


func apply_parry_stun(duration: float = 1.6) -> void:
	is_stunned = true
	stun_timer = duration
	is_attacking = false
	is_counter_riposte = false
	consecutive_hits_taken = 0
	attack_phase = "IDLE"
	if attack_area_3d != null and is_instance_valid(attack_area_3d):
		attack_area_3d.set_deferred("monitoring", false)
	velocity = Vector3.ZERO # Firm stop on parry clash; zero slide


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

	# 2. Confirmed damage micro-recoil (in hit direction)
	var push := hit_dir.normalized()
	if push.length_squared() < 0.01:
		push = Vector3(-1.0 if (sprite_3d == null or not sprite_3d.flip_h) else 1.0, 0.0, 0.0)
	var impulse: float = 3.2 if is_counter else 1.8
	velocity.x = push.x * impulse
	velocity.z = push.z * impulse

	if current_hp <= 0:
		_die(is_counter)
		return

	# Tactical Poise & Riposte against mindless attack spam:
	# If hit twice without being parried/stunned, hyper-armor through the 2nd hit and launch a readable counter-slash!
	if not is_counter and not is_stunned:
		consecutive_hits_taken += 1
		hit_combo_reset_timer = 1.4
		if consecutive_hits_taken >= 2:
			consecutive_hits_taken = 0
			is_recoiling = false
			recoil_timer = 0.0
			_execute_attack(true)
			return

	is_recoiling = true
	recoil_timer = 0.09


func _die(is_counter: bool = false) -> void:
	if is_dead:
		return
	is_dead = true
	is_recoiling = false
	is_attacking = false
	is_stunned = false

	# Immediate collision de-registration & attack prevention
	collision_layer = 0
	collision_mask = 0
	if attack_area_3d != null and is_instance_valid(attack_area_3d):
		attack_area_3d.set_deferred("monitoring", false)
		attack_area_3d.set_deferred("monitorable", false)

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
		sprite_3d.frame = 3 # Stagger recoil frame
	_spawn_defeat_burst(is_counter)

	if sprite_3d != null:
		var tween := create_tween()
		if tween:
			tween.set_parallel(true)
			var dissolve_color := Color(1.0, 2.8, 3.5, 0.0) if is_counter else Color(3.2, 0.8, 0.3, 0.0)
			tween.tween_property(sprite_3d, "modulate", dissolve_color, 0.28)
			tween.tween_property(sprite_3d, "position:y", sprite_3d.position.y + 0.22, 0.28)
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

	var burst_pos := global_position + Vector3(0.0, 0.8, 0.0)
	var burst_col := Color(0.4, 1.15, 1.6, 0.95) if is_counter else Color(1.35, 0.85, 0.3, 0.95)

	# 1. 3D Textured Spark Burst (QuadMesh billboard)
	var spark := MeshInstance3D.new()
	spark.name = "DefeatSparkBurst3D"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	spark.mesh = quad
	var smat := StandardMaterial3D.new()
	smat.albedo_texture = TexHitSpark
	smat.albedo_color = burst_col
	smat.emission_enabled = true
	smat.emission_texture = TexHitSpark
	smat.emission = burst_col
	smat.emission_energy_multiplier = 1.35
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.material_override = smat
	p.add_child(spark)
	spark.global_position = burst_pos

	var stw := spark.create_tween()
	if stw:
		stw.set_parallel(true)
		stw.tween_property(spark, "scale", Vector3(2.2, 2.2, 2.2), 0.22)
		stw.tween_property(smat, "albedo_color:a", 0.0, 0.22)
		stw.chain().tween_callback(spark.queue_free)

	# 2. 3D Textured Shockwave Ring (QuadMesh billboard)
	var ring := MeshInstance3D.new()
	ring.name = "DefeatBurstRing"
	var rquad := QuadMesh.new()
	rquad.size = Vector2(1.4, 1.4)
	ring.mesh = rquad
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = TexShockwaveRing
	rmat.albedo_color = burst_col
	rmat.emission_enabled = true
	rmat.emission_texture = TexShockwaveRing
	rmat.emission = burst_col
	rmat.emission_energy_multiplier = 1.30
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = burst_pos

	var rtw := ring.create_tween()
	if rtw:
		rtw.set_parallel(true)
		rtw.tween_property(ring, "scale", Vector3(2.6, 2.6, 2.6), 0.26)
		rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.26)
		rtw.chain().tween_callback(ring.queue_free)
