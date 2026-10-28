extends CharacterBody3D
class_name SideQVAbyssalArbiter
## Stage 5 침묵의 성채(Silent Citadel) 최종 보스: '심연의 심판관' (Abyssal Arbiter)
## - 4x3 스프라이트 시트 (2.6m 신장, 심연의 대검 장착)
## - 3대 시그니처 패턴:
##   1) 심연 암흑 참격파 (Dark Crescent Wave): 흑자색 암흑 에너지 초승달 검기를 전방으로 사출
##   2) 그림자 텔레포트 기습 (Shadow Blink Strike): 플레이어 배후로 순간이동하여 급습 종베기
##   3) 2페이즈 심연의 심판 폭풍 (Abyssal Judgment Storm): HP 50% 이하 시 중앙 이동 후 전방위 보이드 펄스 방출
## - 피격/그로기/저스트 패링 스턴/상호 밀림 방지/플레이어 정면 응시 회전 완비

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)
signal dark_crescent_fired(wave: Node3D)
signal teleported(pos: Vector3)
signal judgment_storm_triggered

enum Pattern {
	IDLE,
	CHASE,
	MELEE_CLEAVE,
	DARK_CRESCENT_WAVE,
	SHADOW_BLINK_STRIKE,
	JUDGMENT_STORM,
	STUNNED
}

const DarkCrescentWaveClass = preload("res://scripts/side_quarter_view/bosses/side_qv_dark_crescent_wave.gd")
const TexNormal = preload("res://assets/enemy_frames/abyssal_arbiter_v2.png")
const TexSkills = preload("res://assets/enemy_frames/abyssal_arbiter_v2_skills.png")

@export var max_hp: int = 30
@export var current_hp: int = 30
@export var move_speed: float = 4.2
@export var cleave_damage: int = 2
@export var wave_damage: int = 2
@export var blink_strike_damage: int = 3
@export var storm_damage: int = 2

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var is_stunned: bool:
	get:
		return current_pattern == Pattern.STUNNED

var pattern_timer: float = 0.0
var stun_timer: float = 0.0
var target_player: Node3D = null
var facing_dir_x: float = -1.0 # 1.0 = Right, -1.0 = Left

var is_invulnerable: bool = false
var has_used_initial_storm: bool = false
var storm_cooldown: float = 0.0

var sprite_3d: Sprite3D
var aura_ring_3d: MeshInstance3D
var attack_area_3d: Area3D

var anim_frame_timer: float = 0.0
var anim_frame_idx: int = 0


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")
	add_to_group("bosses")

	_build_components()
	boss_hp_changed.emit(current_hp, max_hp)


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite Sheet 4x3 frames, 2.6m tall)
	# Cell: 300x298.66 px. 298.66 * 0.008705 = 2.6m height
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "ArbiterSprite3D"
	sprite_3d.texture = TexNormal
	sprite_3d.hframes = 4
	sprite_3d.vframes = 3
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.008705
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 1.30
	sprite_3d.flip_h = true # Initially face Left towards player
	add_child(sprite_3d)

	# 2. Glowing Void Crimson Aura Ring (Phase 2 & Skill Aura)
	aura_ring_3d = MeshInstance3D.new()
	aura_ring_3d.name = "VoidAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.8
	aura_ring_3d.mesh = torus

	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(2.4, 0.25, 3.2, 1.0)
	amat.emission_enabled = true
	amat.emission = Color(2.4, 0.25, 3.2, 1.0)
	amat.emission_energy_multiplier = 4.0
	aura_ring_3d.material_override = amat
	aura_ring_3d.position.y = 0.15
	aura_ring_3d.visible = false
	add_child(aura_ring_3d)

	# 3. Collision Capsule (2.6m height)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.65
	cap.height = 2.6
	col.shape = cap
	col.position.y = 1.30
	add_child(col)

	# 4. Melee Cleave Attack Area 3D
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "ArbiterAttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 1 # Player Layer (1)
	attack_area_3d.monitoring = false
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.4, 2.4)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 1.3, 0.0)
	attack_area_3d.position = Vector3(-1.4, 0.0, 0.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)

	attack_area_3d.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor() and current_pattern != Pattern.JUDGMENT_STORM:
		velocity.y -= 18.0 * delta

	if storm_cooldown > 0.0:
		storm_cooldown -= delta

	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if stun_timer <= 0.0:
			current_pattern = Pattern.CHASE
			pattern_timer = 0.5
		move_and_slide()
		_update_arbiter_animation(delta)
		return

	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_arbiter_animation(delta)
		return

	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir_x: float = signf(diff.x)

	# Mutual facing alignment towards player
	if dir_x != 0.0 and current_pattern != Pattern.JUDGMENT_STORM:
		facing_dir_x = dir_x
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		attack_area_3d.position.x = 1.4 * facing_dir_x

	pattern_timer -= delta

	match current_pattern:
		Pattern.IDLE, Pattern.CHASE:
			if pattern_timer <= 0.0:
				_pick_next_pattern(dist)
			else:
				var spd := move_speed * (1.30 if current_phase == 2 else 1.0)
				var combat_standoff := 2.2 # Heavy greatsword reach
				if dist > combat_standoff:
					velocity.x = facing_dir_x * spd
					velocity.z = diff.normalized().z * (spd * 0.75)
					_prevent_player_pushing()
				else:
					velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)

		Pattern.MELEE_CLEAVE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if pattern_timer <= 0.0:
				sprite_3d.texture = TexNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 0.85

		Pattern.DARK_CRESCENT_WAVE:
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
			if pattern_timer <= 0.0:
				sprite_3d.texture = TexNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 0.9

		Pattern.SHADOW_BLINK_STRIKE:
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
			if pattern_timer <= 0.0:
				sprite_3d.texture = TexNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 1.0

		Pattern.JUDGMENT_STORM:
			velocity = Vector3.ZERO
			if pattern_timer <= 0.0:
				sprite_3d.texture = TexNormal
				current_pattern = Pattern.CHASE
				pattern_timer = 1.2

	move_and_slide()
	_update_arbiter_animation(delta)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.65 + 0.35 + 0.12 # Collision radius sum
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


func _update_arbiter_animation(delta: float) -> void:
	anim_frame_timer += delta
	var fps := 8.0
	var start_frame := 0
	var frame_count := 4

	match current_pattern:
		Pattern.IDLE:
			sprite_3d.texture = TexNormal
			start_frame = 0 # Row 0 Idle
			fps = 6.0
		Pattern.CHASE:
			sprite_3d.texture = TexNormal
			start_frame = 4 # Row 1 Walk
			fps = 8.0
		Pattern.MELEE_CLEAVE:
			sprite_3d.texture = TexNormal
			start_frame = 8 # Row 2 Cleave
			fps = 10.0
		Pattern.DARK_CRESCENT_WAVE:
			sprite_3d.texture = TexSkills
			start_frame = 0 # Row 0 Wave Casting
			fps = 9.0
		Pattern.SHADOW_BLINK_STRIKE:
			sprite_3d.texture = TexSkills
			start_frame = 4 # Row 1 Shadow Dash / Slash
			fps = 12.0
		Pattern.JUDGMENT_STORM:
			sprite_3d.texture = TexSkills
			start_frame = 8 # Row 2 Storm Channelling
			fps = 7.0
		Pattern.STUNNED:
			sprite_3d.texture = TexNormal
			start_frame = 1 # Staggered hurt posture
			frame_count = 1
			fps = 1.0

	if anim_frame_timer >= (1.0 / fps):
		anim_frame_timer = 0.0
		anim_frame_idx = (anim_frame_idx + 1) % frame_count

	sprite_3d.frame = start_frame + anim_frame_idx


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


func _pick_next_pattern(dist: float) -> void:
	if current_phase == 2 and not has_used_initial_storm:
		_execute_judgment_storm()
		return

	if dist > 6.0:
		# Far range: Dark Crescent Wave or Shadow Blink
		if randf() > 0.45:
			_execute_dark_crescent_wave()
		else:
			_execute_shadow_blink_strike()
	elif dist <= 3.2:
		# Close range: Heavy Melee Cleave or Shadow Blink reposition
		if randf() > 0.35:
			_execute_melee_cleave()
		else:
			_execute_shadow_blink_strike()
	else:
		# Mid range: Mix all patterns
		var roll := randf()
		if roll < 0.40:
			_execute_dark_crescent_wave()
		elif roll < 0.70:
			_execute_melee_cleave()
		else:
			_execute_shadow_blink_strike()


# ==============================================================================
# 패턴 1: 심연 암흑 참격파 (Dark Crescent Wave)
# ==============================================================================
func _execute_dark_crescent_wave() -> void:
	current_pattern = Pattern.DARK_CRESCENT_WAVE
	pattern_timer = 1.15
	velocity = Vector3.ZERO
	sprite_3d.texture = TexSkills

	# Wind-up charge
	await get_tree().create_timer(0.32).timeout
	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		return

	# Fire Dark Crescent Wave projectile
	var spawn_pos := global_position + Vector3(facing_dir_x * 1.3, 1.3, 0.0)
	var fire_dir := Vector3(facing_dir_x, 0.0, 0.0)

	var wave := DarkCrescentWaveClass.new()
	get_parent().add_child(wave)
	wave.initialize(spawn_pos, fire_dir, self, wave_damage)
	dark_crescent_fired.emit(wave)

	# Slight recoil step
	velocity.x = -facing_dir_x * 2.5
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self):
		velocity.x = 0.0


# ==============================================================================
# 패턴 2: 그림자 텔레포트 기습 (Shadow Blink Strike)
# ==============================================================================
func _execute_shadow_blink_strike() -> void:
	current_pattern = Pattern.SHADOW_BLINK_STRIKE
	pattern_timer = 1.25
	velocity = Vector3.ZERO

	# Fade out into shadows
	var tween_out := create_tween()
	if tween_out:
		tween_out.tween_property(sprite_3d, "modulate:a", 0.05, 0.16)
	await get_tree().create_timer(0.18).timeout

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		if is_instance_valid(sprite_3d):
			sprite_3d.modulate.a = 1.0
		return

	# Calculate position behind player
	if target_player != null and is_instance_valid(target_player):
		var p_facing: float = 1.0
		if target_player.has_method("get") and target_player.get("facing_dir_x") != null:
			p_facing = float(target_player.get("facing_dir_x"))
		
		# Behind player is opposite of player's facing direction
		var behind_x: float = target_player.global_position.x - p_facing * 2.2
		behind_x = clampf(behind_x, -16.0, 16.0) # Within arena bounds
		var target_z: float = clampf(target_player.global_position.z, -4.5, 4.5)

		global_position = Vector3(behind_x, 0.1, target_z)
		facing_dir_x = signf(target_player.global_position.x - global_position.x)
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		attack_area_3d.position.x = 1.4 * facing_dir_x
		teleported.emit(global_position)

	# Fade in and immediately strike
	var tween_in := create_tween()
	if tween_in:
		tween_in.tween_property(sprite_3d, "modulate:a", 1.0, 0.12)
	await get_tree().create_timer(0.12).timeout

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		return

	# Downward shadow cleave attack window
	attack_area_3d.monitoring = true
	velocity.x = facing_dir_x * 5.0 # Swift forward dash slash
	await get_tree().create_timer(0.24).timeout

	if is_instance_valid(self):
		attack_area_3d.monitoring = false
		velocity.x = 0.0


# ==============================================================================
# 패턴 3: 2페이즈 심연의 심판 폭풍 (Abyssal Judgment Storm)
# ==============================================================================
func _execute_judgment_storm() -> void:
	current_pattern = Pattern.JUDGMENT_STORM
	pattern_timer = 2.8
	has_used_initial_storm = true
	storm_cooldown = 14.0
	velocity = Vector3.ZERO
	judgment_storm_triggered.emit()

	# Blink to hall center and levitate
	var center_x := global_position.x
	if target_player != null and is_instance_valid(target_player):
		center_x = clampf(target_player.global_position.x + facing_dir_x * 2.5, -14.0, 14.0)
	var center_pos := Vector3(center_x, 0.9, 0.0)
	var tween_pos := create_tween()
	if tween_pos:
		tween_pos.tween_property(self, "global_position", center_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.40).timeout

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		global_position.y = 0.1
		return

	# Pulse 2 consecutive void shockwave rings
	for pulse_idx in range(2):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break
		_spawn_void_shockwave_pulse(pulse_idx + 1)
		await get_tree().create_timer(0.65).timeout

	# Descend back to ground
	if is_instance_valid(self) and current_pattern != Pattern.STUNNED:
		var tween_down := create_tween()
		if tween_down:
			tween_down.tween_property(self, "global_position:y", 0.1, 0.30)
		await get_tree().create_timer(0.32).timeout


func _spawn_void_shockwave_pulse(pulse_num: int) -> void:
	# Expanding 360-degree cylindrical shockwave pulse on floor
	var pulse_area := Area3D.new()
	pulse_area.name = "VoidPulse_%d" % pulse_num
	pulse_area.collision_layer = 0
	pulse_area.collision_mask = 1 # Player

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 0.8
	col.shape = cyl
	pulse_area.add_child(col)

	# Glowing void visual ring
	var vmesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.08
	vmesh.mesh = torus
	vmesh.position.y = 0.15

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(2.6, 0.3, 3.5, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(2.6, 0.3, 3.5, 1.0)
	mat.emission_energy_multiplier = 4.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vmesh.material_override = mat
	pulse_area.add_child(vmesh)

	get_parent().add_child(pulse_area)
	pulse_area.global_position = Vector3(global_position.x, 0.1, global_position.z)

	# Expand outward rapidly across the hall
	var expand_tween := create_tween()
	if expand_tween:
		expand_tween.set_parallel(true)
		expand_tween.tween_property(pulse_area, "scale", Vector3(10.5, 1.0, 10.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		expand_tween.tween_property(mat, "albedo_color:a", 0.0, 0.55)
		expand_tween.chain().tween_callback(pulse_area.queue_free)

	# Check player contact during expansion
	pulse_area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and is_instance_valid(body):
			# Damage if player is on ground (can be avoided by jumping or parrying!)
			var is_grounded: bool = true
			if body.has_method("is_on_floor"):
				is_grounded = body.is_on_floor()
			if is_grounded and body.has_method("receive_incoming_attack"):
				var push_dir := (body.global_position - global_position).normalized()
				push_dir.y = 0.0
				body.receive_incoming_attack(storm_damage, self, push_dir)
	)


# ==============================================================================
# 기본 근접 공격: 심연 대검 2연격 (Melee Cleave Combo)
# ==============================================================================
func _execute_melee_cleave() -> void:
	current_pattern = Pattern.MELEE_CLEAVE
	pattern_timer = 1.15
	sprite_3d.texture = TexNormal

	for swing in range(2):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break
		attack_area_3d.monitoring = true
		velocity.x = facing_dir_x * 4.0
		await get_tree().create_timer(0.24).timeout
		if is_instance_valid(self):
			attack_area_3d.monitoring = false
			velocity.x = 0.0
			await get_tree().create_timer(0.12).timeout


func _on_attack_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			var dmg := blink_strike_damage if current_pattern == Pattern.SHADOW_BLINK_STRIKE else cleave_damage
			body.receive_incoming_attack(dmg, self, Vector3(facing_dir_x, 0.0, 0.0))


func apply_parry_stun(duration: float = 2.0) -> void:
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	velocity = Vector3.ZERO # Firm stop on clash
	attack_area_3d.monitoring = false
	sprite_3d.texture = TexNormal


func receive_hit(amount: int, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	boss_hp_changed.emit(current_hp, max_hp)

	velocity = Vector3.ZERO # Boss holds ground firmly

	# Visual flash (Void purple hit flash)
	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(3.0, 0.5, 3.2, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.15)

	# Phase 2 Transition Check (HP <= 50%)
	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	aura_ring_3d.visible = true
	move_speed = 5.2
	wave_damage = 3
	phase_changed.emit(2)
	# Trigger Abyssal Judgment Storm immediately upon entering Phase 2!
	_execute_judgment_storm()


func _die() -> void:
	boss_defeated.emit(self)
	set_physics_process(false)
	attack_area_3d.monitoring = false

	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.45)
		tween.tween_callback(queue_free)
	else:
		queue_free()
