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

@export var max_hp: int = 28
@export var current_hp: int = 28
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
	if not is_on_floor():
		velocity.y -= 18.0 * delta

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
	if not is_acting:
		_update_movement_animation(delta)


func _process_movement_and_spacing(diff: Vector3, dist: float, delta: float) -> void:
	var spd := move_speed * (1.30 if current_phase == 2 else 1.0)
	var optimal_min := 4.2
	var optimal_max := 7.0

	if dist < optimal_min:
		# 플레이어가 너무 가까우면 뒤로 후퇴하여 사격 거리 확보
		var retreat_dir := -diff.normalized()
		velocity.x = retreat_dir.x * retreat_speed
		velocity.z = retreat_dir.z * (retreat_speed * 0.6)
	elif dist > optimal_max:
		# 너무 멀면 접근
		var advance_dir := diff.normalized()
		velocity.x = advance_dir.x * spd
		velocity.z = advance_dir.z * (spd * 0.7)
		_prevent_player_pushing()
	else:
		# 최적 거리에서는 좌우 견제 기동
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff := target_player.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		var min_dist: float = 0.60 + 0.35 + 0.15 # 사령관 + 플레이어 캡슐 여유 마진
		if dist < min_dist and dist > 0.001:
			var dir := diff / dist
			var forward_speed := velocity.dot(dir)
			if forward_speed > 0.0:
				velocity -= dir * forward_speed


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

	# 1. 조준 텔레그래프 (Row 2 Frame 8: 석궁 조준 자세)
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = 8
	var aim_marker := _create_aim_line()

	await get_tree().create_timer(0.40).timeout
	if is_instance_valid(aim_marker):
		aim_marker.queue_free()

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		is_acting = false
		return

	# 2. 발사 (Row 2 Frame 9: 머즐 플래시 발사 반동)
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = 9
	var base_dir := (target_player.global_position - global_position).normalized()
	base_dir.y = 0.0
	if base_dir.length_squared() < 0.001:
		base_dir = Vector3(facing_dir_x, 0.0, 0.0)
	base_dir = base_dir.normalized()

	var angles: Array[float] = [-22.0, 0.0, 22.0]
	for ang: float in angles:
		var dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(ang))
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

	# 뒤로 높이 도약 (공중 백스텝 회피)
	velocity.x = -facing_dir_x * 8.5
	velocity.y = 8.0
	velocity.z = randf_range(-1.5, 1.5)
	sprite_3d.texture = BossTextureSkills
	sprite_3d.frame = 6 # Jump / Backstep airborne frame

	# 도약 최고점(정점) 부근 대기
	await get_tree().create_timer(0.26).timeout

	if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
		is_acting = false
		return

	# 공중 저격 볼트 사출 (BossTextureMain Frame 9)
	sprite_3d.texture = BossTextureMain
	sprite_3d.frame = 9
	if target_player != null and is_instance_valid(target_player):
		var target_pos := target_player.global_position + Vector3(0.0, 0.8, 0.0)
		var muzzle_pos := global_position + Vector3(muzzle_point_3d.position.x, 1.35, 0.0)
		var shoot_dir := (target_pos - muzzle_pos).normalized()
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
	var offsets: Array[Vector3] = [
		Vector3(facing_dir_x * 2.2, 0.05, -1.4),
		Vector3(facing_dir_x * 3.2, 0.05, 0.0),
		Vector3(facing_dir_x * 2.2, 0.05, 1.4),
		Vector3(facing_dir_x * 4.2, 0.05, -0.6 * facing_dir_x)
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
func _execute_rapid_barrage() -> void:
	is_acting = true
	current_pattern = Pattern.RAPID_BARRAGE
	velocity.x = 0.0
	velocity.z = 0.0

	# 점사 준비 발광
	var tween := create_tween()
	if tween:
		aura_ring_3d.scale = Vector3(1.3, 1.3, 1.3)
		tween.tween_property(aura_ring_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.25)

	await get_tree().create_timer(0.25).timeout

	for shot in range(5):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break

		sprite_3d.texture = BossTextureMain
		sprite_3d.frame = 9 if (shot % 2 == 0) else 8
		if target_player != null and is_instance_valid(target_player):
			var aim_dir := (target_player.global_position + Vector3(0.0, 0.8, 0.0) - global_position).normalized()
			# 약간의 탄착군 편차(Spread) 적용
			aim_dir.z += randf_range(-0.06, 0.06)
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
	get_parent().add_child(bolt)
	bolt.launch(spawn_pos, dir, self, spd, dmg, explosive)


func _spawn_caltrop(pos: Vector3) -> void:
	var trap := CaltropTrapScene.new()
	get_parent().add_child(trap)
	trap.setup(pos, self)


func _create_aim_line() -> Node3D:
	var indicator := MeshInstance3D.new()
	indicator.name = "VolleyAimIndicator"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 6.0)
	indicator.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(2.5, 0.4, 0.2, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(2.5, 0.4, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	indicator.material_override = mat

	indicator.position = Vector3(muzzle_point_3d.position.x, 0.05, 0.0)
	indicator.rotation_degrees = Vector3(90.0, 0.0, 90.0 if facing_dir_x < 0.0 else -90.0)
	add_child(indicator)
	return indicator


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


func receive_hit(amount: int, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = Vector3.ZERO # 피격 시 넉백 밀림 없이 사령관다운 단단한 지탱

	var tween := create_tween()
	if tween:
		sprite_3d.modulate = Color(2.5, 0.3, 0.3, 1.0)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.16)

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
