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
