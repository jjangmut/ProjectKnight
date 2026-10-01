class_name SwordBeam
extends Area2D
## Luminous Crescent Sword Wave unleashed by Combo Step 3 Finisher.
## Pierces through multiple enemies and flies horizontally with glowing trail VFX.

@export var speed: float = 540.0
@export var direction: float = 1.0
@export var max_distance: float = 320.0
@export var damage: int = 1
@export var max_pierce: int = 3

var _start_x: float = 0.0
var _hit_targets: Dictionary = {}
var _pierced: int = 0
var _visual: Node2D
var _blade_arc: Line2D
var _core_arc: Line2D

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

func _ready() -> void:
	_start_x = global_position.x
	collision_layer = 0
	collision_mask = 2 | 1 # Enemy HurtArea (2) + Terrain/Wall (1)

	# Collision Box
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28.0, 48.0)
	col.shape = rect
	add_child(col)

	# Visuals: Glowing Golden Crescent with HDR Overdrive for 2D Bloom Glow
	_visual = Node2D.new()
	_visual.name = "BladeVisual"
	add_child(_visual)

	# 1. Outer Golden Aura Arc (HDR Overdrive)
	_blade_arc = Line2D.new()
	_blade_arc.width = 8.0
	_blade_arc.default_color = Color(1.8, 1.4, 0.45, 0.98)
	var pts := PackedVector2Array()
	var radius := 26.0
	for i in range(7):
		var ang := -PI * 0.45 + (float(i) / 6.0) * PI * 0.9
		pts.append(Vector2(cos(ang) * radius * direction, sin(ang) * radius))
	_blade_arc.points = pts
	_visual.add_child(_blade_arc)

	# 2. Inner Radiant Core (Blinding White-Hot Core)
	_core_arc = Line2D.new()
	_core_arc.width = 3.5
	_core_arc.default_color = Color(2.0, 2.0, 1.8, 1.0)
	var core_pts := PackedVector2Array()
	for i in range(5):
		var ang := -PI * 0.35 + (float(i) / 4.0) * PI * 0.7
		core_pts.append(Vector2(cos(ang) * (radius * 0.8) * direction, sin(ang) * (radius * 0.8)))
	_core_arc.points = core_pts
	_visual.add_child(_core_arc)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta

	# Subtle pulsating energy scale
	if is_instance_valid(_visual):
		_visual.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.15

	if absf(global_position.x - _start_x) >= max_distance:
		_fade_and_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null:
		return
	var tid := target.get_instance_id()
	if _hit_targets.has(tid):
		return
	_hit_targets[tid] = true

	var hit_pos := global_position
	AudioManager.play("hit_heavy", hit_pos)

	var parent_node := get_parent() as Node2D if get_parent() is Node2D else self
	GameFeelManager.slash_spark(parent_node, hit_pos, direction, true)
	GameFeelManager.shake(0.25)
	GameFeelManager.trigger_hit_stop(0.06, 0.0)

	if not target.is_in_group("boss") and parent_node is Node2D:
		GameFeelManager.damage_popup(parent_node, target.global_position + Vector2(0, -32), "%d! BEAM" % damage, Color(1.0, 0.85, 0.3), true)

	if "velocity" in target:
		target.velocity.x += direction * 240.0

	if target.has_method("receive_hit"):
		for _i in range(damage):
			if is_instance_valid(target) and not target.is_queued_for_deletion():
				target.receive_hit()

	_pierced += 1
	if _pierced >= max_pierce:
		_fade_and_free()


func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D or body.is_in_group("stage_terrain"):
		var parent_node := get_parent() as Node2D if get_parent() is Node2D else self
		if parent_node is Node2D:
			GameFeelManager.slash_spark(parent_node, global_position, direction, false)
		AudioManager.play("guard_clang", global_position)
		_fade_and_free()


func _fade_and_free() -> void:
	set_physics_process(false)
	if is_connected("area_entered", _on_area_entered):
		disconnect("area_entered", _on_area_entered)
	if is_connected("body_entered", _on_body_entered):
		disconnect("body_entered", _on_body_entered)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
