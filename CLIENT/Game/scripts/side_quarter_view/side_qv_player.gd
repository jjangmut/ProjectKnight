extends CharacterBody3D
class_name SideQVPlayer
## 사이드 쿼터뷰 2.5D 팔라딘 기사 (Side Quarter-View 2D Character in 3D World)
## - 2D 고해상도 스프라이트 (Sprite3D) 탑재 & 실시간 3D 그림자 투영
## - 사이드 쿼터뷰 벨트스크롤 3D 이동 (X: 좌우, Z: 안팎 깊이, Y: 점프)
## - 3단 콤보 검격 & 전방 관통 성광 찌르기 이펙트 & 3단 피니셔 검기 발출
## - 0.14초 저스트 패링 (Just Parry) 방패 바스티온 & 3배 카운터 어택
## - 피격 무적 시간(i-frame), 사망 상태 처리, 아레나 경계 추락 방지 완비

signal hp_changed(current: int, max_hp: int)
signal died
signal attack_swung(step: int)
signal sword_beam_fired(beam: Node3D)
signal just_parry_succeeded(enemy_node: Node)
signal enemy_hit(enemy_node: Node, damage: int, was_counter: bool)
signal pogo_bounced(player_node: Node)
signal dive_slammed(player_node: Node, hit_count: int)

enum State {
	IDLE,
	MOVE,
	DASH,
	ATTACK,
	GUARD,
	HURT,
	DEAD,
	DIVE_SLAM
}

@export var move_speed_x: float = 7.5
@export var move_speed_z: float = 4.8
@export var dash_speed: float = 14.0
@export var jump_velocity: float = 6.8
@export var gravity: float = 18.0
@export var max_hp: int = 8
@export var current_hp: int = 8

var current_state: State = State.IDLE
var move_direction: Vector3 = Vector3.ZERO
var facing_dir_x: float = 1.0 # 1.0 = Right, -1.0 = Left

# Combat & Combo
var combo_step: int = 0
var combo_reset_timer: float = 0.0
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var attack_duration_remaining: float = 0.0
const ATTACK_TOTAL_DURATION: float = 0.20
var base_attack_damage: int = 2
var current_attack_damage: int = 2

# Input Buffering & Coyote Time (Game Quality Director Standard)
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.14
const ATTACK_BUFFER_TIME: float = 0.12
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0
var was_on_floor: bool = true

# Sanctuary Upgrades & Boss Relics (Stages 1-5) & Runic Engravings
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")
var has_shadow_dash: bool = true
var active_relics: Array[String] = []
var active_engravings: Array[String] = []
var vampiric_cooldown: float = 0.0
const VAMPIRIC_COOLDOWN_TIME: float = 8.0
var dash_hit_enemies: Dictionary = {}

# Guard & Just Parry
var is_guarding: bool = false
var guard_elapsed_time: float = 0.0
const JUST_PARRY_WINDOW: float = 0.14
var counter_attack_buff: bool = false
var counter_buff_timer: float = 0.0

# Dash & Invulnerability & Death
var dash_time_remaining: float = 0.0
const DASH_DURATION: float = 0.22
var dash_buffer_timer: float = 0.0
const DASH_BUFFER_TIME: float = 0.16
var can_air_dash: bool = true
var ghost_timer: float = 0.0
const GHOST_INTERVAL: float = 0.045
var is_invulnerable: bool = false
var invuln_timer: float = 0.0
const HIT_INVULN_DURATION: float = 0.65
var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.16
var is_dead: bool = false

# Arena Bounds Safety
var stage_min_x: float = -18.0
var stage_max_x: float = 18.0
var stage_min_z: float = -5.2
var stage_max_z: float = 5.2

# Procedural animation parameters
var anim_timer: float = 0.0

# Visual & Collision references
var sprite_3d: Sprite3D
var guard_barrier_3d: MeshInstance3D
var slash_visual_3d: MeshInstance3D
var attack_area_3d: Area3D

# Multi-frame Spritesheets for Detailed Character Actions (Symmetric Centered & Ground-Aligned 780x780 Cells)
const TexIdle = preload("res://assets/player_frames/idle_v1_aligned.png")     # 2x2 = 4 frames (780x780 cells, Pivot: 390,700)
const TexRun = preload("res://assets/player_frames/run_v2_aligned.png")      # 3x2 = 6 frames (780x780 cells, Pivot: 390,700)
const TexAttack = preload("res://assets/player_frames/attack_v1_aligned.png")# 2x2 = 4 frames (780x780 cells, Pivot: 390,700)
const TexJump = preload("res://assets/player_frames/jump_v1.png")            # 3x1 = 3 frames (780x780 cells, Pivot: 390,700)
const TexGuard = preload("res://assets/player_frames/guard_v1_aligned.png")  # 3x1 = 3 frames (780x780 cells, Pivot: 390,700)
const TexDodge = preload("res://assets/player_frames/dodge_v1.png")          # 2x2 = 4 frames (780x780 cells, Pivot: 390,700)
const TexHurt = preload("res://assets/player_frames/hurt_v1.png")            # 3x1 = 3 frames (780x780 cells, Pivot: 390,700)
const TexDeath = preload("res://assets/player_frames/death_v1.png")          # 2x2 = 4 frames (780x780 cells, Pivot: 390,700)

# Backward compatibility aliases
const PaladinTexture = TexIdle
const AttackSheetTexture = TexAttack
const SwordBeamScene = preload("res://scripts/side_quarter_view/side_qv_sword_beam.gd")


func _ready() -> void:
	collision_layer = 1 # Player Layer (1)
	collision_mask = 2 | 4 # Enemy Layer (2) & World Layer (4)
	add_to_group("player")

	_sync_stage_bounds()
	_build_components()
	emit_signal("hp_changed", current_hp, max_hp)


func _sync_stage_bounds() -> void:
	var p := get_parent()
	if p != null:
		if "arena_width" in p:
			var w: float = float(p.get("arena_width"))
			stage_min_x = -w * 0.5 + 1.0
			stage_max_x = w * 0.5 - 1.0
		# Option C: Enforce strictly 2D gameplay plane at Z = 0.0
		stage_min_z = 0.0
		stage_max_z = 0.0


func _build_components() -> void:
	# 1. 2D Sprite in 3D Space (Sprite3D, calibrated ~1.77m human scale)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "CharacterSprite3D"
	sprite_3d.texture = TexIdle
	sprite_3d.hframes = 2
	sprite_3d.vframes = 2
	sprite_3d.frame = 0
	# Stand vertically, facing camera in isometric-side view
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.00282 # 780x780 cells with 600px body = ~1.77m height
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_3d.position = Vector3(0.0, 0.874, 0.0) # Ground foot alignment at Y=0.0
	add_child(sprite_3d)

	# 2. 3D Collision Capsule
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	# 3. 3D Runic Shield Barrier (Just Parry visual)
	guard_barrier_3d = MeshInstance3D.new()
	guard_barrier_3d.name = "GuardBarrier3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.8
	guard_barrier_3d.mesh = torus

	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.8, 1.8, 0.85)
	bmat.emission_enabled = true
	bmat.emission = Color(0.2, 0.8, 2.0, 1.0)
	bmat.emission_energy_multiplier = 4.0
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_barrier_3d.material_override = bmat
	guard_barrier_3d.position = Vector3(0.45, 0.85, 0.0)
	guard_barrier_3d.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	guard_barrier_3d.visible = false
	add_child(guard_barrier_3d)

	# 4. 3D Melee Thrust VFX (Sleek Translucent Radiant Spear Streak)
	slash_visual_3d = MeshInstance3D.new()
	slash_visual_3d.name = "SlashVisual3D"
	var thrust_cyl := CylinderMesh.new()
	thrust_cyl.top_radius = 0.008
	thrust_cyl.bottom_radius = 0.085
	thrust_cyl.height = 1.75
	thrust_cyl.radial_segments = 8
	slash_visual_3d.mesh = thrust_cyl

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(3.2, 2.7, 1.4, 0.72) # Semi-transparent Golden-White Holy Thrust Streak
	smat.emission_enabled = true
	smat.emission = Color(3.2, 2.6, 1.2, 1.0)
	smat.emission_energy_multiplier = 4.2
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slash_visual_3d.material_override = smat
	slash_visual_3d.scale = Vector3(1.0, 1.0, 1.0)
	slash_visual_3d.position = Vector3(1.15, 0.92, 0.0)
	slash_visual_3d.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	slash_visual_3d.visible = false
	add_child(slash_visual_3d)

	# 5. Attack Hitbox Area3D (Keep monitoring active so overlaps are always fresh!)
	attack_area_3d = Area3D.new()
	attack_area_3d.name = "AttackArea3D"
	attack_area_3d.collision_layer = 0
	attack_area_3d.collision_mask = 2 # Enemy Layer (2)
	attack_area_3d.monitoring = true
	attack_area_3d.monitorable = false

	var atk_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.8, 1.8)
	atk_shape.shape = box
	atk_shape.position = Vector3(0.0, 0.85, 0.0)
	attack_area_3d.position = Vector3(1.0, 0.0, 0.0)
	attack_area_3d.add_child(atk_shape)
	add_child(attack_area_3d)


func _physics_process(delta: float) -> void:
	_update_timers(delta)

	# Apply Gravity in 3D & Track Floor Transitions (Coyote Time + Landing Buffs)
	var on_floor_now := is_on_floor()
	if not on_floor_now:
		velocity.y -= gravity * delta
		coyote_timer = maxf(0.0, coyote_timer - delta)
	else:
		coyote_timer = COYOTE_TIME
		if not was_on_floor:
			_on_landed_on_floor()
		if velocity.y < 0:
			velocity.y = 0.0
	was_on_floor = on_floor_now

	if is_dead or current_state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = 0.0
		global_position.z = 0.0
		move_and_slide()
		velocity.z = 0.0
		global_position.z = 0.0
		_clamp_arena_bounds()
		_update_character_animation(delta)
		return

	match current_state:
		State.IDLE, State.MOVE:
			_process_movement(delta)
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_process_attack_state(delta)
		State.GUARD:
			_process_guard_state(delta)
		State.DIVE_SLAM:
			_process_dive_slam_state(delta)
		State.HURT:
			_process_hurt_state(delta)

	# Option C: Enforce strict Z=0 before and after move_and_slide
	velocity.z = 0.0
	global_position.z = 0.0
	_prevent_enemy_pushing()
	move_and_slide()
	velocity.z = 0.0
	global_position.z = 0.0
	_clamp_arena_bounds()
	_update_character_animation(delta)


func _clamp_arena_bounds() -> void:
	_sync_stage_bounds()
	global_position.x = clampf(global_position.x, stage_min_x, stage_max_x)
	# Option C: Zero Z drift
	global_position.z = 0.0
	velocity.z = 0.0
	if global_position.y < 0.0:
		global_position.y = 0.0
		if velocity.y < 0.0:
			velocity.y = 0.0


func _prevent_enemy_pushing() -> void:
	# Avoid sliding into or pushing monsters; halt clean on contact boundary (Option C X-only)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
			continue
		var enemy_3d := enemy as Node3D
		var diff_x: float = enemy_3d.global_position.x - global_position.x
		var dist_x: float = absf(diff_x)
		var enemy_radius: float = 0.60 if enemy_3d.is_in_group("bosses") else 0.40
		var min_dist: float = 0.35 + enemy_radius + 0.06
		if dist_x < min_dist and dist_x > 0.001:
			var dir_x: float = signf(diff_x)
			if velocity.x * dir_x > 0.0:
				velocity.x = 0.0
	velocity.z = 0.0


func _update_timers(delta: float) -> void:
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0 and not is_attacking:
			combo_step = 0

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	if attack_buffer_timer > 0.0:
		attack_buffer_timer = maxf(0.0, attack_buffer_timer - delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	if Input.is_action_just_pressed("attack"):
		attack_buffer_timer = ATTACK_BUFFER_TIME
	if dash_buffer_timer > 0.0:
		dash_buffer_timer = maxf(0.0, dash_buffer_timer - delta)
	if Input.is_action_just_pressed("dash"):
		dash_buffer_timer = DASH_BUFFER_TIME

	if invuln_timer > 0.0:
		invuln_timer -= delta
		if invuln_timer <= 0.0:
			invuln_timer = 0.0
			if sprite_3d != null and not is_dead:
				sprite_3d.modulate = Color.WHITE
		elif sprite_3d != null and not is_dead:
			# Subtle hit i-frame flicker
			var flash := 1.0 if int(invuln_timer * 24.0) % 2 == 0 else 0.55
			sprite_3d.modulate = Color(1.4, 0.85, 0.85, flash)

	if is_guarding:
		guard_elapsed_time += delta

	if counter_attack_buff:
		counter_buff_timer -= delta
		if counter_buff_timer <= 0.0:
			counter_attack_buff = false

	if vampiric_cooldown > 0.0:
		vampiric_cooldown = maxf(0.0, vampiric_cooldown - delta)


func _process_movement(delta: float) -> void:
	var input_x := 0.0
	if Input.is_action_pressed("move_left"):
		input_x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_x += 1.0

	# Option C: Fixed 2D side-scroller movement on X/Y (Z strictly locked to 0)
	if input_x != 0.0:
		facing_dir_x = signf(input_x)
		attack_area_3d.position.x = 1.0 * facing_dir_x
		guard_barrier_3d.position.x = 0.6 * facing_dir_x
		slash_visual_3d.position.x = 1.15 * facing_dir_x
		velocity.x = input_x * move_speed_x
		velocity.z = 0.0
		move_direction = Vector3(facing_dir_x, 0.0, 0.0)
		_set_state(State.MOVE)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
		velocity.z = 0.0
		move_direction = Vector3.ZERO
		_set_state(State.IDLE)

	# Action inputs (with Coyote Time & Input Buffering)
	if (Input.is_action_just_pressed("jump") or jump_buffer_timer > 0.0) and (is_on_floor() or coyote_timer > 0.0):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		start_jump()
	elif (Input.is_action_just_pressed("attack") or attack_buffer_timer > 0.0) and attack_cooldown <= 0.0:
		attack_buffer_timer = 0.0
		if not is_on_floor() and (Input.is_action_pressed("move_down") or global_position.y >= 0.35 and Input.is_action_pressed("move_down")):
			start_dive_slam()
		else:
			start_attack()
	elif (Input.is_action_just_pressed("dash") or dash_buffer_timer > 0.0) and (is_on_floor() or can_air_dash):
		dash_buffer_timer = 0.0
		start_dash()
	elif Input.is_action_pressed("guard") and is_on_floor():
		start_guard()


func start_jump() -> void:
	if is_dead:
		return
	velocity.y = jump_velocity


func start_dash() -> void:
	if is_dead:
		return
	if not is_on_floor() or global_position.y > 0.35:
		can_air_dash = false
	dash_time_remaining = DASH_DURATION
	ghost_timer = 0.0
	is_invulnerable = true
	dash_hit_enemies.clear()
	var dash_dir := Vector3(facing_dir_x, 0.0, 0.0)
	velocity.x = dash_dir.x * dash_speed
	velocity.z = 0.0
	_set_state(State.DASH)
	_spawn_dash_ghost()
	if has_engraving("thunder_step"):
		_spawn_thunder_step_spark(global_position + Vector3(0.0, 0.7, 0.0))


func _process_dash(delta: float) -> void:
	dash_time_remaining -= delta
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		ghost_timer = GHOST_INTERVAL
		_spawn_dash_ghost()
	if has_engraving("thunder_step"):
		_check_thunder_step_hits()
	if dash_time_remaining <= 0.0:
		is_invulnerable = false
		_set_state(State.IDLE)


func _spawn_dash_ghost() -> void:
	var p := get_parent()
	if p == null or sprite_3d == null:
		return
	var ghost := Sprite3D.new()
	ghost.name = "DashGhost3D"
	ghost.texture = sprite_3d.texture
	ghost.hframes = sprite_3d.hframes
	ghost.vframes = sprite_3d.vframes
	ghost.frame = sprite_3d.frame
	ghost.flip_h = sprite_3d.flip_h
	ghost.pixel_size = sprite_3d.pixel_size
	ghost.billboard = sprite_3d.billboard
	ghost.modulate = Color(0.3, 0.9, 2.0, 0.65)
	ghost.no_depth_test = true
	p.add_child(ghost)
	ghost.global_position = global_position
	var gtw := ghost.create_tween()
	if gtw:
		gtw.tween_property(ghost, "modulate:a", 0.0, 0.22)
		gtw.chain().tween_callback(ghost.queue_free)


func start_dive_slam() -> void:
	if is_dead or is_on_floor() or current_state == State.DIVE_SLAM:
		return
	_set_state(State.DIVE_SLAM)
	velocity = Vector3(0.0, -22.0, 0.0)
	sprite_3d.texture = TexAttack
	sprite_3d.hframes = 2
	sprite_3d.vframes = 2
	sprite_3d.frame = 2
	slash_visual_3d.visible = true
	slash_visual_3d.rotation_degrees = Vector3(0.0, 0.0, 180.0)
	slash_visual_3d.position = Vector3(0.0, -0.6, 0.0)


func _process_dive_slam_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	velocity.y = -22.0
	if is_on_floor():
		_execute_dive_slam_landing()


func _execute_dive_slam_landing() -> void:
	_set_state(State.IDLE)
	velocity = Vector3.ZERO
	slash_visual_3d.visible = false
	_spawn_dive_shockwave_vfx()

	var hit_count := 0
	var slam_dmg: int = current_attack_damage * 2
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
			continue
		if not enemy.has_method("receive_hit"):
			continue
		var e3d := enemy as Node3D
		var diff := e3d.global_position - global_position
		diff.y = 0.0
		if diff.length() <= 3.8:
			hit_count += 1
			var push := diff.normalized() if diff.length() > 0.01 else Vector3(facing_dir_x, 0.0, 0.0)
			if "current_poise" in enemy and not enemy.is_groggy:
				enemy.current_poise = maxi(0, enemy.current_poise - 4)
				if enemy.current_poise <= 0 and enemy.has_method("_enter_groggy_state"):
					enemy._enter_groggy_state()
			enemy.receive_hit(slam_dmg, push)
			_spawn_hit_impact_vfx(e3d.global_position + Vector3(0.0, 0.85, 0.0), true)
			GameFeelManager.damage_popup_3d(get_parent(), e3d.global_position + Vector3(0.0, 1.4, 0.0), "%d STOMP!" % slam_dmg, Color(1.4, 0.9, 0.2), true)
			enemy_hit.emit(enemy, slam_dmg, true)

	var p := get_parent()
	if p != null and "camera" in p and p.camera != null and p.camera.has_method("add_trauma"):
		p.camera.add_trauma(0.42)
	GameFeelManager.hit_stop_3d(0.06, 0.05)
	dive_slammed.emit(self, hit_count)


func _spawn_dive_shockwave_vfx() -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "DiveShockwaveRing3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 1.05
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(3.6, 2.4, 0.5, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(3.6, 2.4, 0.5, 1.0)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.08, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(3.8, 3.8, 3.8), 0.32)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
		tw.chain().tween_callback(ring.queue_free)


func _check_thunder_step_hits() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
			continue
		if not enemy.has_method("receive_hit"):
			continue
		var eid := enemy.get_instance_id()
		if dash_hit_enemies.has(eid):
			continue
		var e3d := enemy as Node3D
		var dist := (e3d.global_position - global_position).length()
		if dist <= 1.8:
			dash_hit_enemies[eid] = true
			var hit_dir := Vector3(facing_dir_x, 0, 0)
			enemy.receive_hit(1, hit_dir)
			_spawn_thunder_step_spark(e3d.global_position + Vector3(0.0, 0.9, 0.0))


func _spawn_thunder_step_spark(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	var spark := MeshInstance3D.new()
	spark.name = "ThunderStepSpark3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.45
	spark.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 2.8, 4.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 2.8, 4.2, 1.0)
	mat.emission_energy_multiplier = 4.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.material_override = mat
	p.add_child(spark)
	spark.global_position = pos
	spark.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := spark.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(spark, "scale", Vector3(2.0, 2.0, 2.0), 0.16)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.16)
		tw.chain().tween_callback(spark.queue_free)


func start_attack() -> void:
	if is_dead:
		return
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.95
	is_attacking = true
	attack_cooldown = 0.22
	attack_duration_remaining = ATTACK_TOTAL_DURATION

	# Symmetric Aligned 2D Attack Animation (Starts at windup frame 0)
	sprite_3d.texture = TexAttack
	sprite_3d.hframes = 2
	sprite_3d.vframes = 2
	sprite_3d.pixel_size = 0.00282
	sprite_3d.frame = 0

	attack_area_3d.position.x = 1.0 * facing_dir_x
	slash_visual_3d.visible = true
	slash_visual_3d.position = Vector3(facing_dir_x * 1.15, 0.92, 0.0)
	slash_visual_3d.rotation_degrees = Vector3(0.0, 0.0, -90.0 * facing_dir_x)
	slash_visual_3d.scale = Vector3(0.35, 0.35, 0.35)
	var thrust_tween := create_tween()
	if thrust_tween:
		thrust_tween.tween_property(slash_visual_3d, "scale", Vector3(0.85, 1.25, 0.85), 0.06)
		thrust_tween.tween_property(slash_visual_3d, "scale", Vector3(0.15, 0.5, 0.15), 0.12)
	attack_area_3d.monitoring = true
	emit_signal("attack_swung", combo_step)

	# Responsive melee hit check (Direct spatial + Area3D hybrid check)
	_check_melee_hit()

	# Combo 3 Finisher: Fire glowing 3D piercing sword wave!
	if combo_step == 3:
		_fire_sword_beam()

	_set_state(State.ATTACK)


func _check_melee_hit() -> void:
	var hit_targets: Dictionary = {}

	# 1. Check Area3D overlapping bodies
	if attack_area_3d != null and attack_area_3d.monitoring:
		for body in attack_area_3d.get_overlapping_bodies():
			if body != null and is_instance_valid(body) and body != self and body.has_method("receive_hit"):
				hit_targets[body.get_instance_id()] = body

	# 2. Direct spatial reach check (Fixes Godot same-frame Area3D monitoring delay)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
			continue
		if not enemy.has_method("receive_hit"):
			continue
		var e3d := enemy as Node3D
		var diff: Vector3 = e3d.global_position - global_position
		var forward_dist: float = diff.x * facing_dir_x
		var z_dist: float = absf(diff.z)
		var y_dist: float = absf(diff.y)
		var extra_r: float = 0.55 if e3d.is_in_group("bosses") else 0.25
		if forward_dist >= -0.35 and forward_dist <= (2.35 + extra_r) and z_dist <= (1.35 + extra_r * 0.5) and y_dist <= 2.2:
			hit_targets[e3d.get_instance_id()] = e3d

	var dmg: int = current_attack_damage
	var was_counter: bool = false
	if counter_attack_buff and not hit_targets.is_empty():
		dmg = current_attack_damage * 3 + (2 if has_relic("abyssal_crown") else 0)
		counter_attack_buff = false
		was_counter = true

	for id in hit_targets.keys():
		var target_node: Node = hit_targets[id]
		if is_instance_valid(target_node):
			target_node.receive_hit(dmg, Vector3(facing_dir_x, 0, 0))
			if target_node is Node3D:
				var t3d := target_node as Node3D
				_spawn_hit_impact_vfx(t3d.global_position + Vector3(0.0, 0.95, 0.0), was_counter)
				var pop_col := Color(0.2, 1.0, 1.4) if was_counter else Color(1.0, 0.95, 0.6)
				var pop_txt := "%d CRIT!" % dmg if was_counter else "%d" % dmg
				GameFeelManager.damage_popup_3d(get_parent(), t3d.global_position + Vector3(0.0, 1.25, 0.0), pop_txt, pop_col, was_counter)
			enemy_hit.emit(target_node, dmg, was_counter)

	if not hit_targets.is_empty():
		var p := get_parent()
		if was_counter:
			GameFeelManager.hit_stop_3d(0.08, 0.04)
			if p != null and "camera" in p and p.camera != null and p.camera.has_method("add_trauma"):
				p.camera.add_trauma(0.32)
		elif combo_step == 3:
			GameFeelManager.hit_stop_3d(0.05, 0.06)
			if p != null and "camera" in p and p.camera != null and p.camera.has_method("add_trauma"):
				p.camera.add_trauma(0.18)
		else:
			GameFeelManager.hit_stop_3d(0.025, 0.12)
			if p != null and "camera" in p and p.camera != null and p.camera.has_method("add_trauma"):
				p.camera.add_trauma(0.08)

		# Air Pogo Bounce (Hollow Knight style upward recoil when striking in air)
		if not is_on_floor():
			_execute_pogo_bounce()

	# Runic Engraving: Vampiric Edge (Combo 3 Finisher heals 1 HP on hit, 8s cooldown)
	if not hit_targets.is_empty() and combo_step == 3 and has_engraving("vampiric_edge") and vampiric_cooldown <= 0.0:
		vampiric_cooldown = VAMPIRIC_COOLDOWN_TIME
		current_hp = mini(max_hp, current_hp + 1)
		emit_signal("hp_changed", current_hp, max_hp)
		_spawn_vampiric_heal_vfx(global_position + Vector3(0.0, 0.9, 0.0))
		GameFeelManager.damage_popup_3d(get_parent(), global_position + Vector3(0.0, 1.5, 0.0), "+1 HP", Color(0.3, 1.0, 0.4), true)


func _fire_sword_beam() -> void:
	var beam := SwordBeamScene.new()
	beam.name = "SideQVSwordBeam_Finisher"
	if has_relic("piercing_quiver") or has_relic("wind_quiver"):
		beam.max_range = 24.0 * 1.4
		beam.speed = 20.0 * 1.2
		beam.pierce_count = 1
	get_parent().add_child(beam)
	var shoot_dir := Vector3(facing_dir_x, 0, 0)
	var extra_beam_dmg: int = (current_attack_damage - 2) + (2 if counter_attack_buff else 0)
	beam.initialize(global_position + Vector3(facing_dir_x * 0.9, 1.1, 0.0), shoot_dir, extra_beam_dmg)
	sword_beam_fired.emit(beam)


func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	attack_duration_remaining -= delta

	# Attack Recovery Cancel into Dash or Guard (fluid high-tier combat responsiveness)
	if attack_duration_remaining <= 0.14:
		if (Input.is_action_just_pressed("dash") or dash_buffer_timer > 0.0) and (is_on_floor() or can_air_dash):
			dash_buffer_timer = 0.0
			slash_visual_3d.visible = false
			is_attacking = false
			start_dash()
			return
		elif Input.is_action_pressed("guard") and is_on_floor():
			slash_visual_3d.visible = false
			is_attacking = false
			start_guard()
			return

	if attack_duration_remaining <= 0.0:
		slash_visual_3d.visible = false
		is_attacking = false
		_set_state(State.IDLE)
		if attack_buffer_timer > 0.0 and attack_cooldown <= 0.0:
			attack_buffer_timer = 0.0
			start_attack()


func start_guard() -> void:
	if is_guarding or is_dead:
		return
	is_guarding = true
	guard_elapsed_time = 0.0
	guard_barrier_3d.visible = true
	velocity.x = 0.0
	velocity.z = 0.0
	_set_state(State.GUARD)


func release_guard() -> void:
	is_guarding = false
	guard_barrier_3d.visible = false
	if current_state == State.GUARD:
		_set_state(State.IDLE)


func _process_guard_state(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not Input.is_action_pressed("guard"):
		release_guard()


func receive_incoming_attack(amount: int, attacker: Node, _attack_dir: Vector3) -> bool:
	if is_dead or current_hp <= 0:
		return false
	if is_invulnerable or invuln_timer > 0.0:
		return false

	if is_guarding:
		if guard_elapsed_time <= JUST_PARRY_WINDOW:
			# Just Parry! 100% damage blocked, attacker stunned, 3x counter buff!
			counter_attack_buff = true
			counter_buff_timer = 3.5
			invuln_timer = 0.35
			emit_signal("just_parry_succeeded", attacker)
			if attacker != null and attacker.has_method("apply_parry_stun"):
				attacker.apply_parry_stun(2.0)
			_trigger_parry_flash()
			GameFeelManager.damage_popup_3d(get_parent(), global_position + Vector3(0.0, 1.6, 0.0), "PARRIED!", Color(0.2, 1.0, 1.4), true)

			# Runic Engraving: Aegis Reflect (Reflects 2 instant damage back to attacker)
			if has_engraving("aegis_reflect") and attacker != null and is_instance_valid(attacker) and attacker is Node3D:
				if attacker.has_method("receive_hit"):
					var ref_push: Vector3 = ((attacker as Node3D).global_position - global_position).normalized()
					attacker.receive_hit(2, ref_push)
					_spawn_aegis_reflect_vfx((attacker as Node3D).global_position + Vector3(0.0, 0.9, 0.0))
					GameFeelManager.damage_popup_3d(get_parent(), (attacker as Node3D).global_position + Vector3(0.0, 1.3, 0.0), "REFLECT 2", Color(1.0, 0.85, 0.2), true)
			return false
		else:
			# Normal Guard: 50% damage reduction, solid halt + brief i-frame
			var reduced := maxi(1, int(amount * 0.5))
			current_hp = maxi(0, current_hp - reduced)
			invuln_timer = HIT_INVULN_DURATION * 0.8
			emit_signal("hp_changed", current_hp, max_hp)
			GameFeelManager.damage_popup_3d(get_parent(), global_position + Vector3(0.0, 1.4, 0.0), "GUARD -%d" % reduced, Color(0.9, 0.9, 0.5), false)
			velocity = Vector3.ZERO
			if current_hp <= 0:
				_enter_death_state()
			return true

	# Direct Hit: Damage taken, firm stop without launch bounce, grant hit i-frame
	current_hp = maxi(0, current_hp - amount)
	invuln_timer = HIT_INVULN_DURATION
	hurt_timer = HURT_DURATION
	emit_signal("hp_changed", current_hp, max_hp)
	GameFeelManager.damage_popup_3d(get_parent(), global_position + Vector3(0.0, 1.4, 0.0), "-%d" % amount, Color(1.0, 0.25, 0.25), false)
	velocity = Vector3.ZERO

	if current_hp <= 0:
		_enter_death_state()
	else:
		_set_state(State.HURT)
	return true


func _enter_death_state() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_guarding = false
	dash_buffer_timer = 0.0
	attack_buffer_timer = 0.0
	jump_buffer_timer = 0.0
	can_air_dash = true
	slash_visual_3d.visible = false
	guard_barrier_3d.visible = false
	velocity = Vector3.ZERO
	_set_state(State.DEAD)
	if sprite_3d != null:
		sprite_3d.modulate = Color.WHITE
		sprite_3d.texture = TexDeath
		sprite_3d.hframes = 2
		sprite_3d.vframes = 2
		sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 3
	emit_signal("died")


func _trigger_parry_flash() -> void:
	# Heavy Just Parry impact freeze-frame (Game Feel Juice)
	GameFeelManager.hit_stop_3d(0.08, 0.04)

	var tween := create_tween()
	if tween:
		guard_barrier_3d.scale = Vector3(1.6, 1.6, 1.6)
		tween.tween_property(guard_barrier_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.18)

	# 3D Golden-Cyan Parry Shockwave Ring + Burst Flash Light
	var p := get_parent()
	if p != null:
		var ring := MeshInstance3D.new()
		ring.name = "ParryShockwaveRing3D"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.45
		torus.outer_radius = 0.68
		ring.mesh = torus
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(1.2, 3.0, 4.5, 0.9)
		rmat.emission_enabled = true
		rmat.emission = Color(1.2, 3.0, 4.5, 1.0)
		rmat.emission_energy_multiplier = 4.5
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rmat
		p.add_child(ring)
		ring.global_position = global_position + Vector3(facing_dir_x * 0.5, 0.9, 0.0)
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		var rtw := ring.create_tween()
		if rtw:
			rtw.set_parallel(true)
			rtw.tween_property(ring, "scale", Vector3(2.8, 2.8, 2.8), 0.22)
			rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.22)
			rtw.chain().tween_callback(ring.queue_free)

		if "camera" in p and p.camera != null and p.camera.has_method("add_trauma"):
			p.camera.add_trauma(0.38)


func _spawn_hit_impact_vfx(hit_pos: Vector3, is_counter: bool) -> void:
	var p := get_parent()
	if p == null:
		return
	var spark := MeshInstance3D.new()
	spark.name = "MeleeHitImpact3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.28 if is_counter else 0.18
	sphere.height = sphere.radius * 2.0
	spark.mesh = sphere
	var smat := StandardMaterial3D.new()
	var col := Color(1.4, 3.2, 4.6, 0.9) if is_counter else Color(3.4, 2.6, 1.0, 0.85)
	smat.albedo_color = col
	smat.emission_enabled = true
	smat.emission = col
	smat.emission_energy_multiplier = 4.2
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.material_override = smat
	p.add_child(spark)
	spark.global_position = hit_pos
	var stw := spark.create_tween()
	if stw:
		stw.set_parallel(true)
		stw.tween_property(spark, "scale", Vector3(2.2, 2.2, 2.2), 0.14)
		stw.tween_property(smat, "albedo_color:a", 0.0, 0.14)
		stw.chain().tween_callback(spark.queue_free)


func _execute_pogo_bounce() -> void:
	# Hollow Knight style vertical recoil upon hitting enemy from mid-air
	velocity.y = jump_velocity * 0.96
	jump_buffer_timer = 0.0
	coyote_timer = COYOTE_TIME
	dash_time_remaining = 0.0 # Refresh air dash so player can maneuver dynamically
	AudioManager.play("pogo_bounce", Vector2(global_position.x, global_position.z))
	_spawn_pogo_shockwave_vfx(global_position)
	GameFeelManager.damage_popup_3d(get_parent(), global_position + Vector3(0.0, 0.5, 0.0), "POGO!", Color(0.3, 0.95, 1.2), true)
	pogo_bounced.emit(self)


func _spawn_pogo_shockwave_vfx(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "PogoShockwaveRing3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.55
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.8, 2.5, 3.8, 0.9)
	rmat.emission_enabled = true
	rmat.emission = Color(0.8, 2.5, 3.8, 1.0)
	rmat.emission_energy_multiplier = 4.2
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = pos + Vector3(0.0, -0.05, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(2.4, 2.4, 2.4), 0.20)
		tw.tween_property(rmat, "albedo_color:a", 0.0, 0.20)
		tw.chain().tween_callback(ring.queue_free)


func _on_landed_on_floor() -> void:
	can_air_dash = true
	# Air-to-ground buffered attack execution
	if attack_buffer_timer > 0.0 and attack_cooldown <= 0.0 and not is_dead:
		attack_buffer_timer = 0.0
		start_attack()
	# Stage 4 Relic (Titan/Golem Pauldrons): Ground Slam Shockwave on Landing
	if has_relic("golem_pauldrons") or has_relic("titan_pauldrons"):
		_trigger_titan_landing_shockwave()


func _trigger_titan_landing_shockwave() -> void:
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "TitanLandingShockwave3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.85
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(3.2, 1.8, 0.4, 0.85)
	rmat.emission_enabled = true
	rmat.emission = Color(3.2, 1.8, 0.4, 1.0)
	rmat.emission_energy_multiplier = 3.8
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.08, 0.0)
	var rtw := ring.create_tween()
	if rtw:
		rtw.set_parallel(true)
		rtw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.24)
		rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.24)
		rtw.chain().tween_callback(ring.queue_free)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != self and enemy is Node3D and enemy.has_method("receive_hit"):
			var e3d := enemy as Node3D
			var dist := Vector2(e3d.global_position.x - global_position.x, e3d.global_position.z - global_position.z).length()
			if dist <= 3.2:
				var dir_x := signf(e3d.global_position.x - global_position.x)
				if dir_x == 0.0:
					dir_x = facing_dir_x
				enemy.receive_hit(1, Vector3(dir_x, 0.0, 0.0))


func has_relic(relic_id: String) -> bool:
	return active_relics.has(relic_id)


func grant_relic(relic_id: String) -> void:
	var alias_pairs := {
		"bastion_shield": "fortress_shield",
		"fortress_shield": "bastion_shield",
		"piercing_quiver": "wind_quiver",
		"wind_quiver": "piercing_quiver",
		"golem_pauldrons": "titan_pauldrons",
		"titan_pauldrons": "golem_pauldrons",
	}
	if not active_relics.has(relic_id):
		active_relics.append(relic_id)
	if alias_pairs.has(relic_id):
		var alt: String = alias_pairs[relic_id]
		if not active_relics.has(alt):
			active_relics.append(alt)
	_recalculate_relic_and_upgrade_stats()


func has_engraving(engraving_id: String) -> bool:
	return active_engravings.has(engraving_id)


func grant_engraving(engraving_id: String) -> void:
	if not active_engravings.has(engraving_id):
		active_engravings.append(engraving_id)


func apply_studio_upgrades_and_relics() -> void:
	for rid in SaveManagerClass.get_unlocked_relic_ids():
		if not active_relics.has(rid):
			active_relics.append(rid)
	for eid in SaveManagerClass.get_unlocked_engravings():
		if not active_engravings.has(eid):
			active_engravings.append(eid)
	_recalculate_relic_and_upgrade_stats()


func _spawn_vampiric_heal_vfx(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	var aura := MeshInstance3D.new()
	aura.name = "VampiricHealAura3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.65
	aura.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(3.8, 0.4, 0.6, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(3.8, 0.4, 0.6, 1.0)
	mat.emission_energy_multiplier = 4.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura.material_override = mat
	p.add_child(aura)
	aura.global_position = pos
	aura.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := aura.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(aura, "scale", Vector3(2.4, 2.4, 2.4), 0.28)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
		tw.chain().tween_callback(aura.queue_free)


func _spawn_aegis_reflect_vfx(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	var spark := MeshInstance3D.new()
	spark.name = "AegisReflectBurst3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	spark.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(3.5, 2.8, 0.4, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(3.5, 2.8, 0.4, 1.0)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.material_override = mat
	p.add_child(spark)
	spark.global_position = pos
	var tw := spark.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(spark, "scale", Vector3(2.6, 2.6, 2.6), 0.18)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
		tw.chain().tween_callback(spark.queue_free)


func _recalculate_relic_and_upgrade_stats() -> void:
	var hp_boost: int = SaveManagerClass.get_upgrade_level("hp_boost")
	var dmg_boost: int = SaveManagerClass.get_upgrade_level("dmg_boost")
	var relic_hp: int = 1 if (has_relic("golem_pauldrons") or has_relic("titan_pauldrons")) else 0
	var relic_dmg: int = 1 if has_relic("abyssal_crown") else 0

	var new_max_hp: int = 8 + hp_boost + relic_hp
	if new_max_hp > max_hp:
		current_hp += (new_max_hp - max_hp)
	max_hp = new_max_hp
	current_hp = clampi(current_hp, 0, max_hp)

	base_attack_damage = 2 + dmg_boost + relic_dmg
	current_attack_damage = base_attack_damage

	if has_relic("shadow_cloak"):
		move_speed_x = 7.5 * 1.12
		dash_speed = 14.0 * 1.15
	emit_signal("hp_changed", current_hp, max_hp)


func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_set_state(State.IDLE)


func _update_character_animation(delta: float) -> void:
	anim_timer += delta

	# Head-on mutual facing alignment
	sprite_3d.flip_h = (facing_dir_x < 0.0)

	# 0. Dead State
	if is_dead or current_state == State.DEAD:
		if sprite_3d.texture != TexDeath:
			sprite_3d.texture = TexDeath
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 3
		return

	# 0.5 Dive Slam Stomp Action
	if current_state == State.DIVE_SLAM:
		if sprite_3d.texture != TexAttack:
			sprite_3d.texture = TexAttack
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 2
		return

	# 1. Airborne Jump Action
	if not is_on_floor() and not is_attacking:
		if sprite_3d.texture != TexJump:
			sprite_3d.texture = TexJump
			sprite_3d.hframes = 3
			sprite_3d.vframes = 1
			sprite_3d.pixel_size = 0.00282
		if velocity.y > 1.2:
			sprite_3d.frame = 0 # Ascent
		elif absf(velocity.y) <= 1.2:
			sprite_3d.frame = 1 # Apex float
		else:
			sprite_3d.frame = 2 # Descent
		return

	# 2. Attack Action (Multi-frame sequence across attack duration: 0 -> 1 -> 2 -> 3)
	if is_attacking:
		if sprite_3d.texture != TexAttack:
			sprite_3d.texture = TexAttack
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		var progress: float = clampf(1.0 - (attack_duration_remaining / ATTACK_TOTAL_DURATION), 0.0, 0.999)
		sprite_3d.frame = clampi(int(progress * 4.0), 0, 3)
		return

	# 3. Guard / Parry Stance Action
	if is_guarding:
		if sprite_3d.texture != TexGuard:
			sprite_3d.texture = TexGuard
			sprite_3d.hframes = 3
			sprite_3d.vframes = 1
			sprite_3d.pixel_size = 0.00282
		if counter_attack_buff:
			sprite_3d.frame = 2 # Parry counter spark
		elif guard_elapsed_time < 0.06:
			sprite_3d.frame = 0 # Shield raise
		else:
			sprite_3d.frame = 1 # Fortified fortress brace
		return

	# 4. Dodge Dash Action
	if current_state == State.DASH:
		if sprite_3d.texture != TexDodge:
			sprite_3d.texture = TexDodge
			sprite_3d.hframes = 2
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		var dash_progress := 1.0 - (dash_time_remaining / DASH_DURATION)
		sprite_3d.frame = clampi(int(dash_progress * 4.0), 0, 3)
		return

	# 5. Hurt Action
	if current_state == State.HURT:
		if sprite_3d.texture != TexHurt:
			sprite_3d.texture = TexHurt
			sprite_3d.hframes = 3
			sprite_3d.vframes = 1
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = 1
		return

	# 6. Run / Sprint Action (6-frame detailed loop, Unified 780x780 Aligned)
	if current_state == State.MOVE and is_on_floor():
		if sprite_3d.texture != TexRun:
			sprite_3d.texture = TexRun
			sprite_3d.hframes = 3
			sprite_3d.vframes = 2
			sprite_3d.pixel_size = 0.00282
		sprite_3d.frame = int(anim_timer * 10.0) % 6
		return

	# 7. Idle Stance (4-frame detailed breathing loop)
	if sprite_3d.texture != TexIdle:
		sprite_3d.texture = TexIdle
		sprite_3d.hframes = 2
		sprite_3d.vframes = 2
		sprite_3d.pixel_size = 0.00282
	sprite_3d.frame = int(anim_timer * 4.0) % 4


func _set_state(new_state: State) -> void:
	if is_dead and new_state != State.DEAD:
		return
	current_state = new_state
