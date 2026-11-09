extends CharacterBody3D
class_name SideQVCrossbowCommander
## 사이드 쿼터뷰 Stage 3 보스: 석궁 사령관 (Crossbow Commander)
## - 2D 고해상도 석궁병 스프라이트 (ranged_v1.png 3x2) 기반 3D 보스
## - 패턴 1: 3방향 부채꼴 폭발 볼트 사격 (Fan Crossbow Volley)
## - 패턴 2: 공중 백텀블링 회피 사격 (Acrobatic Backstep Shot)
## - 패턴 3: 지면 마름쇠 트랩 살포 (Caltrop Trap Cluster)
## - 패턴 4: 2페이즈 연사 폭풍 (Rapid Crossbow Barrage: 5연발 고속 점사)
## - 피격/그로기/저스트 패링 스턴, 상호 밀림 방지, 플레이어 정면 응시 회전 완비

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)

enum Pattern {
	IDLE,
	CHASE,
	FAN_VOLLEY,
	BACKSTEP_SHOT,
	CALTROP_TRAP,
	RAPID_BARRAGE,
	STUNNED
}

const CrossbowBoltScene = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd")
const CaltropTrapScene = preload("res://scripts/side_quarter_view/bosses/side_qv_caltrop_trap.gd")
const BossTextureMain = preload("res://assets/enemy_frames/crossbow_cmd_v2.png")
const BossTextureSkills = preload("res://assets/enemy_frames/crossbow_cmd_v2_skills.png")
const BossTexture = BossTextureMain
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

@export var max_hp: int = 30
@export var current_hp: int = 30
@export var max_poise: int = 12
var current_poise: int = 12
var is_groggy: bool = false
var groggy_timer: float = 0.0
var groggy_halo_3d: MeshInstance3D = null
@export var move_speed: float = 3.8
@export var retreat_speed: float = 4.5

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var is_stunned: bool:
	get:
		return current_pattern == Pattern.STUNNED

var pattern_timer: float = 1.0
var stun_timer: float = 0.0
var target_player: Node3D = null
var facing_dir_x: float = -1.0 # 플레이어를 향하는 수평 방향

var sprite_3d: Sprite3D
var aura_ring_3d: MeshInstance3D
var muzzle_point_3d: Marker3D

var is_acting: bool = false
var anim_timer: float = 0.0
var is_dead: bool = false
var _defeated_signaled: bool = false


func _ready() -> void:
	collision_layer = 2 # Enemy Layer (2)
	collision_mask = 1 | 4 # Player (1) & World (4)
	add_to_group("enemies")
	add_to_group("bosses")

	_build_components()
	emit_signal("boss_hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. 2D 고해상도 스프라이트 (crossbow_cmd_v2.png: 4x3 프레임 시트, 높이 약 2.5m 사령관 위엄)
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "CommanderSprite3D"
	sprite_3d.texture = BossTextureMain
	sprite_3d.hframes = 4
	sprite_3d.vframes = 3
	sprite_3d.frame = 0
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite_3d.pixel_size = 0.00835 # 298px * 0.00835 = ~2.5m tall
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_3d.position.y = 1.15
	sprite_3d.flip_h = true # 기본 왼쪽(플레이어 위치) 응시
	add_child(sprite_3d)

	# 2. 2페이즈 비전 에너지 오라 링 (Torus Mesh)
	aura_ring_3d = MeshInstance3D.new()
	aura_ring_3d.name = "CobaltAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.65
	aura_ring_3d.mesh = torus

	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.4, 0.8, 3.2, 0.9)
	amat.emission_enabled = true
	amat.emission = Color(0.4, 0.8, 3.2, 1.0)
	amat.emission_energy_multiplier = 4.2
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_ring_3d.material_override = amat
	aura_ring_3d.position.y = 0.15
	aura_ring_3d.visible = false
	add_child(aura_ring_3d)

	# 3. 3D 물리 충돌 캡슐
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.60
	cap.height = 2.40
	col.shape = cap
	col.position.y = 1.20
	add_child(col)

	# 4. 볼트 발사 기준점 (Crossbow Muzzle)
	muzzle_point_3d = Marker3D.new()
	muzzle_point_3d.name = "MuzzleMarker"
	muzzle_point_3d.position = Vector3(-0.9, 1.35, 0.0)
	add_child(muzzle_point_3d)


func _physics_process(delta: float) -> void:
	# Option C: 엄격한 Z=0.0 평면 고정
	velocity.z = 0.0
	global_position.z = 0.0

	if not is_on_floor():
		velocity.y -= 18.0 * delta

	if is_groggy:
		groggy_timer -= delta
		if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
			groggy_halo_3d.rotation_degrees.y += 180.0 * delta
		if groggy_timer <= 0.0:
			_exit_groggy_state()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# 스턴 / 그로기 상태 처리
	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		sprite_3d.texture = BossTextureSkills
		sprite_3d.frame = 8 # Stagger / Stunned frame
		if stun_timer <= 0.0:
			current_pattern = Pattern.CHASE
			is_acting = false
		move_and_slide()
		return

	# 플레이어 탐색
	if target_player == null or not is_instance_valid(target_player):
		_find_player()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_idle_animation(delta)
		return

	# 플레이어와 거리 및 방향 계산
	var diff := target_player.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var dir_x: float = signf(diff.x)

	if not is_acting and dir_x != 0.0:
		facing_dir_x = dir_x
		# ranged_v1 스프라이트는 기본 오른쪽 정면 -> 왼쪽을 보려면 flip_h = true
		sprite_3d.flip_h = (facing_dir_x < 0.0)
		muzzle_point_3d.position.x = 0.9 * facing_dir_x

	# 패턴 타이머 진행 (행동 중이 아닐 때만)
	if not is_acting:
		pattern_timer -= delta
		if pattern_timer <= 0.0:
			_pick_next_pattern(dist)
		else:
			_process_movement_and_spacing(diff, dist, delta)

	move_and_slide()
	velocity.z = 0.0
	global_position.z = 0.0
	if not is_acting:
		_update_movement_animation(delta)


func _process_movement_and_spacing(diff: Vector3, dist: float, delta: float) -> void:
	var spd := move_speed * (1.30 if current_phase == 2 else 1.0)
	var optimal_min := 4.2
	var optimal_max := 7.0

	var dx := target_player.global_position.x - global_position.x
	var h_dist := absf(dx)
	var dir_x := signf(dx) if absf(dx) > 0.001 else facing_dir_x

	if h_dist < optimal_min:
		# 플레이어가 너무 가까우면 뒤로 후퇴하여 사격 거리 확보 (1D 수평)
		velocity.x = -dir_x * retreat_speed
		velocity.z = 0.0
	elif h_dist > optimal_max:
		# 너무 멀면 접근 (1D 수평)
		velocity.x = dir_x * spd
		velocity.z = 0.0
		_prevent_player_pushing()
	else:
		# 최적 거리에서는 좌우 견제 기동
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = 0.0


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var dx := target_player.global_position.x - global_position.x
		var h_dist := absf(dx)
		var min_dist: float = 0.60 + 0.35 + 0.15
		if h_dist < min_dist and h_dist > 0.001:
			var dir_x := signf(dx)
			if velocity.x * dir_x > 0.0:
				velocity.x = 0.0


func _pick_next_pattern(dist: float) -> void:
	if current_phase == 2 and randf() < 0.40:
		# 2페이즈: 연사 폭풍 점사
		_execute_rapid_barrage()
		return

	if dist < 3.8:
		# 플레이어 근접 시: 공중 백텀블링 회피 사격 또는 마름쇠 트랩
		if randf() < 0.60:
			_execute_backstep_shot()
		else:
			_execute_caltrop_trap()
	else:
		# 원거리/중거리: 3방향 부채꼴 폭발 볼트 사격 또는 마름쇠 살포
		if randf() < 0.70:
			_execute_fan_volley()
		else:
			_execute_caltrop_trap()


# ==============================================================================
# 패턴 1: 3방향 부채꼴 폭발 볼트 사격 (Fan Crossbow Volley)
# ==============================================================================
func _execute_fan_volley() -> void:
	is_acting = true
	current_pattern = Pattern.FAN_VOLLEY
	velocity.x = 0.0
	velocity.z = 0.0

	var base_dir := Vector3(facing_dir_x, 0.0, 0.0)
	if target_player != null and is_instance_valid(target_player):
		var dy := (target_player.global_position.y + 0.8) - (global_position.y + 1.35)
		base_dir = Vector3(facing_dir_x * 2.0, dy, 0.0).normalized()

	# 1. 3방향 부채꼴 조준 텔레그래프 (Row 2 Frame 8: 석궁 조준 자세)
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = 8
	AudioManager.play("boss_tell_crossbow")
	var aim_marker := _create_fan_aim_lines(base_dir)

	await get_tree().create_timer(0.40).timeout
	if is_instance_valid(aim_marker):
		aim_marker.queue_free()

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		is_acting = false
		return

	# 2. 발사 (Row 2 Frame 9: 머즐 플래시 발사 반동)
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = 9

	var angles: Array[float] = [-18.0, 0.0, 18.0]
	for ang: float in angles:
		# Option C: 2D X/Y 평면 회전 (Vector3(0, 0, 1) 기준 회전으로 Z 이탈 방지)
		var dir: Vector3 = base_dir.rotated(Vector3(0.0, 0.0, 1.0), deg_to_rad(ang * facing_dir_x))
		dir.z = 0.0
		dir = dir.normalized()
		_spawn_bolt(dir, 17.0, 2, true)

	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(self) and current_pattern != Pattern.STUNNED:
		current_pattern = Pattern.CHASE
		pattern_timer = randf_range(1.2, 1.8)
	is_acting = false


# ==============================================================================
# 패턴 2: 공중 백텀블링 회피 사격 (Acrobatic Backstep Shot)
# ==============================================================================
func _execute_backstep_shot() -> void:
	is_acting = true
	current_pattern = Pattern.BACKSTEP_SHOT

	# 뒤로 높이 도약 (순수 2D X/Y 포물선 도약, Z 속도 완전 배제)
	velocity.x = -facing_dir_x * 8.5
	velocity.y = 8.0
	velocity.z = 0.0
	global_position.z = 0.0
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 6 # Jump / Backstep airborne frame

	# 도약 최고점(정점) 부근 대기
	await get_tree().create_timer(0.26).timeout

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		is_acting = false
		return

	# 공중 저격 볼트 사출 (순수 X/Y 조준)
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = 9
	if target_player != null and is_instance_valid(target_player):
		var target_pos := target_player.global_position + Vector3(0.0, 0.8, 0.0)
		var muzzle_pos := global_position + Vector3(muzzle_point_3d.position.x, 1.35, 0.0)
		var shoot_dir := Vector3(target_pos.x - muzzle_pos.x, target_pos.y - muzzle_pos.y, 0.0).normalized()
		_spawn_bolt(shoot_dir, 22.0, 2, false)

	# 착지 대기
	await get_tree().create_timer(0.40).timeout
	if is_instance_valid(self) and current_pattern != Pattern.STUNNED:
		current_pattern = Pattern.CHASE
		pattern_timer = randf_range(1.0, 1.6)
	is_acting = false


# ==============================================================================
# 패턴 3: 지면 마름쇠 트랩 살포 (Caltrop Trap Cluster)
# ==============================================================================
func _execute_caltrop_trap() -> void:
	is_acting = true
	current_pattern = Pattern.CALTROP_TRAP
	velocity.x = 0.0
	velocity.z = 0.0

	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 4 # 마름쇠 투척 준비
	await get_tree().create_timer(0.28).timeout

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		is_acting = false
		return

	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 5 # 마름쇠 살포 모션
	# Option C: 플레이어 전투 경로(Z=0.0)를 따라 X축 순차 살포
	var offsets: Array[Vector3] = [
		Vector3(facing_dir_x * 2.0, 0.05, 0.0),
		Vector3(facing_dir_x * 3.2, 0.05, 0.0),
		Vector3(facing_dir_x * 4.4, 0.05, 0.0),
		Vector3(facing_dir_x * 5.6, 0.05, 0.0)
	]

	for off: Vector3 in offsets:
		var trap_pos: Vector3 = global_position + off
		_spawn_caltrop(trap_pos)

	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(self) and current_pattern != Pattern.STUNNED:
		current_pattern = Pattern.CHASE
		pattern_timer = randf_range(1.2, 1.8)
	is_acting = false


# ==============================================================================
# 패턴 4: 2페이즈 연사 폭풍 (Rapid Crossbow Barrage: 5연발 고속 점사)
# ==============================================================================
func _show_danger_telegraph(duration: float = 0.35) -> void:
	AudioManager.play("boss_tell_crossbow")
	var p := get_parent()
	if p == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "DangerTelegraphRing3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.85
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(3.8, 0.4, 0.2, 0.9)
	rmat.emission_enabled = true
	rmat.emission = Color(3.8, 0.4, 0.2, 1.0)
	rmat.emission_energy_multiplier = 4.5
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = global_position + Vector3(0.0, 0.08, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := ring.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(2.5, 2.5, 2.5), duration)
		tw.tween_property(rmat, "albedo_color:a", 0.0, duration)
		tw.chain().tween_callback(ring.queue_free)

	GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.6, 0.0), "!", Color(3.8, 0.3, 0.2), true)


func _enter_groggy_state() -> void:
	is_groggy = true
	groggy_timer = 3.0
	current_pattern = Pattern.STUNNED
	is_acting = false
	velocity = Vector3.ZERO
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 8 # Stagger frame
	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.6, 0.0), "GROGGY!", Color(1.0, 0.7, 0.1), true)
		_spawn_groggy_halo()


func _spawn_groggy_halo() -> void:
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
	groggy_halo_3d = MeshInstance3D.new()
	groggy_halo_3d.name = "GroggyHalo3D"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.55
	groggy_halo_3d.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(3.2, 2.4, 0.4, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(3.2, 2.4, 0.4, 1.0)
	mat.emission_energy_multiplier = 4.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	groggy_halo_3d.material_override = mat
	add_child(groggy_halo_3d)
	groggy_halo_3d.position = Vector3(0.0, 2.6, 0.0)
	groggy_halo_3d.rotation_degrees = Vector3(75.0, 0.0, 0.0)


func _exit_groggy_state() -> void:
	is_groggy = false
	current_poise = max_poise
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
		groggy_halo_3d = null
	current_pattern = Pattern.CHASE
	pattern_timer = 1.0
	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.4, 0.0), "RECOVER!", Color(0.4, 0.8, 1.2), false)


func _execute_rapid_barrage() -> void:
	is_acting = true
	current_pattern = Pattern.RAPID_BARRAGE
	velocity.x = 0.0
	velocity.z = 0.0

	_show_danger_telegraph(0.35)
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED or is_groggy:
		is_acting = false
		return

	# 점사 준비 발광
	var tween := create_tween()
	if tween:
		aura_ring_3d.scale = Vector3(1.3, 1.3, 1.3)
		tween.tween_property(aura_ring_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.25)

	await get_tree().create_timer(0.25).timeout

	for shot in range(5):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED or is_groggy:
			break

		sprite_3d.texture = BossTextureMain
		sprite_3d.frame = 9 if (shot % 2 == 0) else 8
		if target_player != null and is_instance_valid(target_player):
			var dy := (target_player.global_position.y + 0.8) - (global_position.y + 1.35)
			var aim_dir := Vector3(target_player.global_position.x - global_position.x, dy, 0.0).normalized()
			# Option C: Y축 수직 편차만 허용하고 Z축은 완전 0 고정
			aim_dir.y += randf_range(-0.10, 0.10)
			aim_dir.z = 0.0
			aim_dir = aim_dir.normalized()
			_spawn_bolt(aim_dir, 20.0, 1, false)

		await get_tree().create_timer(0.14).timeout

	await get_tree().create_timer(0.40).timeout
	if is_instance_valid(self) and current_pattern != Pattern.STUNNED:
		current_pattern = Pattern.CHASE
		pattern_timer = randf_range(1.4, 2.0)
	is_acting = false


# ==============================================================================
# 투사체 및 트랩 스폰 헬퍼
# ==============================================================================
func _spawn_bolt(dir: Vector3, spd: float, dmg: int, explosive: bool) -> void:
	var bolt := CrossbowBoltScene.new()
	var spawn_pos := global_position + Vector3(muzzle_point_3d.position.x, 1.35, 0.0)
	spawn_pos.z = 0.0
	dir.z = 0.0
	dir = dir.normalized()
	AudioManager.play("boss_crossbow_fire")
	get_parent().add_child(bolt)
	bolt.launch(spawn_pos, dir, self, spd, dmg, explosive)


func _spawn_caltrop(pos: Vector3) -> void:
	var trap := CaltropTrapScene.new()
	pos.z = 0.0
	get_parent().add_child(trap)
	trap.setup(pos, self)


func _create_aim_line() -> Node3D:
	return _create_fan_aim_lines(Vector3(facing_dir_x, 0.0, 0.0))


func _create_fan_aim_lines(base_dir: Vector3) -> Node3D:
	var root_indicator := Node3D.new()
	root_indicator.name = "VolleyAimIndicator"
	root_indicator.position = Vector3(muzzle_point_3d.position.x, 1.35, 0.0)

	var angles: Array[float] = [-18.0, 0.0, 18.0]
	var beam_length: float = 9.0
	var beam_thickness: float = 0.05

	for i in range(angles.size()):
		var ang: float = angles[i]
		var dir: Vector3 = base_dir.rotated(Vector3(0.0, 0.0, 1.0), deg_to_rad(ang * facing_dir_x))
		dir.z = 0.0
		dir = dir.normalized()

		# Laser tracer quad facing camera in X/Y plane
		var beam := MeshInstance3D.new()
		beam.name = "AimBeam_%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(beam_thickness if i != 1 else beam_thickness * 1.4, beam_length)
		beam.mesh = quad

		var mat := StandardMaterial3D.new()
		var col := Color(4.2, 0.45, 0.15, 0.85) if i == 1 else Color(3.6, 0.75, 0.2, 0.72)
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 4.2
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = mat

		var angle_rad := atan2(dir.y, dir.x) - PI * 0.5
		beam.rotation = Vector3(0.0, 0.0, angle_rad)
		beam.position = dir * (beam_length * 0.5)
		beam.position.z = 0.0
		root_indicator.add_child(beam)

	add_child(root_indicator)

	var tw := root_indicator.create_tween()
	if tw:
		tw.set_loops(3)
		tw.tween_property(root_indicator, "scale", Vector3(1.05, 1.05, 1.0), 0.06)
		tw.tween_property(root_indicator, "scale", Vector3(0.96, 0.96, 1.0), 0.06)

	return root_indicator


# ==============================================================================
# 애니메이션 헬퍼
# ==============================================================================
func _update_idle_animation(delta: float) -> void:
	anim_timer += delta
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = int(anim_timer * 5.0) % 4


func _update_movement_animation(delta: float) -> void:
	anim_timer += delta
	sprite_3d.texture = BossTextureMain
	if velocity.length() > 0.4:
		# Row 1: 사령관 전진/기동 프레임 순환 (4, 5, 6, 7)
		sprite_3d.frame = 4 + (int(anim_timer * 7.0) % 4)
	else:
		# Row 0: 대기 호흡 프레임 순환 (0, 1, 2, 3)
		sprite_3d.frame = int(anim_timer * 5.0) % 4


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0] as Node3D


# ==============================================================================
# 피격 / 저스트 패링 스턴 / 2페이즈 / 사망 처리
# ==============================================================================
func apply_parry_stun(duration: float = 2.0) -> void:
	if not is_groggy:
		current_poise = maxi(0, current_poise - 4)
		if current_poise <= 0:
			_enter_groggy_state()
			return
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	is_acting = false
	velocity = Vector3.ZERO
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 8 # Stagger / Stunned frame

	# 패링 성공 시 번쩍이는 황금빛 스턴 플래시
	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(3.5, 3.0, 1.0, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.22)


func receive_hit(amount: int, hit_dir: Vector3 = Vector3.ZERO, is_counter: bool = false) -> void:
	if is_dead or current_hp <= 0 or amount <= 0:
		return
	if is_groggy:
		amount += 1 # Bonus shatter damage during groggy break
		var p := get_parent()
		if p != null:
			GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 2.3, 0.0), "SHATTER +1", Color(1.0, 0.8, 0.2), true)
	else:
		current_poise = maxi(0, current_poise - maxi(1, amount))
		if current_poise <= 0:
			_enter_groggy_state()

	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = Vector3.ZERO
	global_position.z = 0.0

	# 1. Distinct visual hit confirmation flash
	var tween := create_tween()
	if tween:
		if is_counter:
			sprite_3d.modulate = Color(1.5, 3.2, 4.0, 1.0)
			tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.18)
		else:
			sprite_3d.modulate = Color(3.5, 0.8, 0.8, 1.0)
			tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.12)

	# 2. Boss sprite micro-recoil shake
	var push_x := hit_dir.x
	if push_x == 0.0:
		push_x = -facing_dir_x
	var offset_x: float = push_x * (0.08 if is_counter else 0.04)
	sprite_3d.position.x = offset_x
	var rtw := create_tween()
	if rtw:
		rtw.tween_property(sprite_3d, "position:x", 0.0, 0.08)

	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	aura_ring_3d.visible = true
	move_speed = 5.2
	retreat_speed = 5.8
	emit_signal("phase_changed", 2)

	# 페이즈 전환 충격파 링 연출
	var tween := create_tween()
	if tween:
		aura_ring_3d.scale = Vector3(2.0, 2.0, 2.0)
		tween.tween_property(aura_ring_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.35)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	if groggy_halo_3d != null and is_instance_valid(groggy_halo_3d):
		groggy_halo_3d.queue_free()
		groggy_halo_3d = null
	if not _defeated_signaled:
		_defeated_signaled = true
		emit_signal("boss_defeated", self)
	set_physics_process(false)
	is_acting = true
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 11 # Defeat / Knockdown frame

	var tween := create_tween()
	if tween:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()
