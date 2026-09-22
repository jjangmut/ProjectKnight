extends "res://scripts/enemy/test_enemy.gd"
## One committed, ground-level slam; existing HP/damage contract is unchanged.
@export var slam_width: float = 220.0
@export var slam_height: float = 30.0
var is_attacking: bool:
	get:
		return state == State.ATTACK

func _ready() -> void:
	super._ready()
	set_meta("art_variant", "golem")
	set_meta("ground_slam", true)
	attack_collision.shape.size = Vector2(slam_width, slam_height)
	attack_area.position = Vector2(0, 30.0 - slam_height * 0.5)
	_build_enemy_sprite()

func _begin_attack(horizontal_distance: float) -> void:
	super._begin_attack(horizontal_distance)
	# The warning and collision share this exact centered ground footprint.
	attack_area.position = Vector2(0, 30.0 - slam_height * 0.5)

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return
	super._physics_process(delta)
	if is_attack_active:
		for area in attack_area.get_overlapping_areas():
			_on_attack_area_entered(area)

func _on_attack_area_entered(area: Area2D) -> void:
	if current_hp <= 0 or not is_attack_active:
		return
	var target := area.get_parent()
	if not target.is_in_group("player") or target.is_dead:
		return
	super._on_attack_area_entered(area)

func _is_attack_blockable() -> bool:
	return false


func _spawn_attack_slash_vfx() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vfx := Node2D.new()
	vfx.name = "GolemGroundSlamVFX"
	vfx.position = position + Vector2(0, 26.0)
	vfx.z_index = 8
	parent.add_child(vfx)

	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(1.0, 0.45, 0.15, 0.9)
	var pts := PackedVector2Array()
	for i in range(11):
		var ang := float(i) / 10.0 * TAU
		pts.append(Vector2(cos(ang) * (slam_width * 0.45), sin(ang) * 12.0))
	ring.points = pts
	vfx.add_child(ring)

	var tween := vfx.create_tween()
	tween.set_parallel(true)
	vfx.scale = Vector2(0.3, 0.3)
	tween.tween_property(vfx, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(vfx, "modulate:a", 0.0, 0.25).set_delay(0.1)
	tween.chain().tween_callback(vfx.queue_free)
