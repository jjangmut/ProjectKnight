extends CharacterBody2D
class_name QVBossCommander
## 쿼터뷰 1스테이지 보스 기사 지휘관 (Quarter-View Boss Commander)
## - 8방향 2.5D 전방위 기동 및 방패 돌진 (Shield Charge)
## - 360도 전방위 지진 충격파 링 (Quake Shockwave Ring)
## - 부채꼴 3단 대검 연속 베기 (Triple Cleave)
## - 페이즈 2 광폭화 (Enrage Burst)
## - 저스트 패링 시 1.5초 기절(Stun) 및 카운터 기회 제공

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_node: Node)
signal phase_changed(phase: int)

enum Pattern {
	IDLE,
	CHASE,
	TRIPLE_CLEAVE,
	SHIELD_CHARGE,
	QUAKE_RING,
	ENRAGE_ROAR,
	STUNNED
}

@export var max_hp: int = 24
@export var current_hp: int = 24
@export var move_speed: float = 120.0
@export var charge_speed: float = 400.0

var current_phase: int = 1
var current_pattern: Pattern = Pattern.IDLE
var pattern_timer: float = 0.0
var stun_timer: float = 0.0
var target_player: Node2D = null
var facing_direction: Vector2 = Vector2.LEFT

# Visuals
var visual_root: Node2D
var boss_sprite: Sprite2D
var shadow: Line2D
var weapon_slash_arc: Line2D
var aura_ring: Line2D
var attack_area: Area2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2 # Enemy Layer
	collision_mask = 1 | 4 # Player & Walls
	add_to_group("enemies")
	add_to_group("bosses")

	_build_components()
	emit_signal("boss_hp_changed", current_hp, max_hp)


func _build_components() -> void:
	# 1. Floor Drop Shadow (Large Ellipse)
	shadow = Line2D.new()
	shadow.name = "FloorShadow"
	shadow.width = 22.0
	shadow.default_color = Color(0.02, 0.02, 0.05, 0.55)
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.points = PackedVector2Array([Vector2(-26.0, 0.0), Vector2(26.0, 0.0)])
	add_child(shadow)

	# 2. Visual Root
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	# 3. Boss Sprite
	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossSprite"
	var tex = load("res://assets/enemy_frames/boss_commander_v2.png")
	if tex == null:
		tex = load("res://assets/player/knight_idle_v1.png")
	boss_sprite.texture = tex
	boss_sprite.position = Vector2(0.0, -36.0)
	boss_sprite.scale = Vector2(1.25, 1.25)
	visual_root.add_child(boss_sprite)

	# 4. Boss Aura Ring (Glowing Red HDR)
	aura_ring = Line2D.new()
	aura_ring.name = "AuraRing"
	aura_ring.width = 4.0
	aura_ring.default_color = Color(2.2, 0.4, 0.4, 0.8)
	var pts := PackedVector2Array()
	for i in range(13):
		var ang := (i / 12.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 42.0 + Vector2(0.0, -32.0))
	aura_ring.points = pts
	aura_ring.visible = false
	visual_root.add_child(aura_ring)

	# 5. Heavy Cleave Slash Arc
	weapon_slash_arc = Line2D.new()
	weapon_slash_arc.name = "WeaponSlashArc"
	weapon_slash_arc.width = 12.0
	weapon_slash_arc.default_color = Color(2.5, 0.8, 0.3, 0.95)
	weapon_slash_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	weapon_slash_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	var slash_pts := PackedVector2Array()
	for i in range(9):
		var ang := -PI * 0.4 + (i / 8.0) * PI * 0.8
		slash_pts.append(Vector2(cos(ang), sin(ang)) * 64.0 + Vector2(0.0, -32.0))
	weapon_slash_arc.points = slash_pts
	weapon_slash_arc.visible = false
	visual_root.add_child(weapon_slash_arc)

	# 6. Attack Area (Broad sweep)
	attack_area = Area2D.new()
	attack_area.name = "BossAttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = 1 # Player
	attack_area.monitoring = false
	attack_area.monitorable = false

	var atk_col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 62.0
	atk_col.shape = circ
	atk_col.position = Vector2(40.0, -10.0)
	attack_area.add_child(atk_col)
	visual_root.add_child(attack_area)

	# 7. Collision Shape
	var body_col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 20.0
	cap.height = 42.0
	body_col.shape = cap
	body_col.position = Vector2(0.0, -14.0)
	add_child(body_col)

	attack_area.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	if current_pattern == Pattern.STUNNED:
		stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		if stun_timer <= 0.0:
			modulate = Color.WHITE
			current_pattern = Pattern.CHASE
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

	pattern_timer -= delta

	match current_pattern:
		Pattern.IDLE, Pattern.CHASE:
			if pattern_timer <= 0.0:
				_pick_next_pattern(dist)
			else:
				velocity = facing_direction * (move_speed * (1.3 if current_phase == 2 else 1.0))
		Pattern.SHIELD_CHARGE:
			# Dash at charge speed
			velocity = facing_direction * charge_speed
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 0.8
		Pattern.TRIPLE_CLEAVE:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 1.0
		Pattern.QUAKE_RING:
			velocity = Vector2.ZERO
			if pattern_timer <= 0.0:
				current_pattern = Pattern.CHASE
				pattern_timer = 1.2

	move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0]
	else:
		for child in get_parent().get_children():
			if child.is_in_group("player"):
				target_player = child
				break


func _pick_next_pattern(dist: float) -> void:
	if dist > 180.0:
		_execute_shield_charge()
	elif dist <= 90.0:
		if randf() > 0.5:
			_execute_triple_cleave()
		else:
			_execute_quake_ring()
	else:
		_execute_triple_cleave()


func _execute_shield_charge() -> void:
	current_pattern = Pattern.SHIELD_CHARGE
	pattern_timer = 0.7
	attack_area.monitoring = true

	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(self):
		attack_area.monitoring = false


func _execute_triple_cleave() -> void:
	current_pattern = Pattern.TRIPLE_CLEAVE
	pattern_timer = 0.9

	for swing in range(3):
		if not is_instance_valid(self) or current_pattern == Pattern.STUNNED:
			break
		weapon_slash_arc.visible = true
		attack_area.monitoring = true
		velocity = facing_direction * 140.0
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(self):
			weapon_slash_arc.visible = false
			attack_area.monitoring = false
			await get_tree().create_timer(0.08).timeout


func _execute_quake_ring() -> void:
	current_pattern = Pattern.QUAKE_RING
	pattern_timer = 1.0

	# 360-degree shockwave ring expanding outward
	var ring := Area2D.new()
	ring.collision_layer = 0
	ring.collision_mask = 1 # Player
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 110.0
	col.shape = circ
	ring.add_child(col)
	ring.global_position = global_position
	get_parent().add_child(ring)

	await get_tree().process_frame
	for body in ring.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and is_instance_valid(body):
			if body.has_method("receive_incoming_attack"):
				body.receive_incoming_attack(2, self, (body.global_position - global_position).normalized())
	ring.queue_free()


func _on_attack_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player") and is_instance_valid(body):
		if body.has_method("receive_incoming_attack"):
			body.receive_incoming_attack(2, self, facing_direction)


func apply_parry_stun(duration: float = 1.5) -> void:
	current_pattern = Pattern.STUNNED
	stun_timer = duration
	velocity = -facing_direction * 220.0
	weapon_slash_arc.visible = false
	attack_area.monitoring = false
	modulate = Color(2.0, 1.8, 0.4, 1.0) # Golden Stun


func receive_hit(amount: int, hit_dir: Vector2 = Vector2.ZERO) -> void:
	current_hp -= amount
	emit_signal("boss_hp_changed", current_hp, max_hp)

	velocity = hit_dir * 120.0

	# Phase 2 Enrage Check
	if current_phase == 1 and current_hp <= int(max_hp * 0.5):
		_trigger_phase_2()

	var tween := create_tween()
	if tween:
		modulate = Color(3.0, 1.0, 1.0, 1.0)
		tween.tween_property(self, "modulate", Color.WHITE if current_pattern != Pattern.STUNNED else Color(2.0, 1.8, 0.4, 1.0), 0.14)

	if current_hp <= 0:
		_die()


func _trigger_phase_2() -> void:
	current_phase = 2
	aura_ring.visible = true
	move_speed = 170.0
	charge_speed = 500.0
	emit_signal("phase_changed", 2)


func _die() -> void:
	emit_signal("boss_defeated", self)
	set_physics_process(false)
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		queue_free()
