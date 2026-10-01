class_name BossShockwave
extends Area2D
## Imposing Crimson Sword Beam & Ground Shockwave emitted by Boss Commander.
## Features multi-layered blazing crescent blade, razor core, trailing energy, and ground embers.

@export var speed: float = 400.0
@export var direction: float = 1.0
@export var max_travel_distance: float = 460.0
@export var damage: int = 1

var _start_x: float = 0.0
var _hit_player: bool = false
var _visual_root: Node2D
var _outer_arc: Line2D
var _inner_arc: Line2D
var _core_poly: Polygon2D
var _spark_timer: float = 0.0

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")


func _ready() -> void:
	_start_x = position.x
	collision_layer = 0
	collision_mask = 4 # Player HurtArea
	add_to_group("enemy_projectile")

	# Collision shape (tall slicing wave covering ground jumps)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 56)
	col.shape = shape
	col.position = Vector2(2, -28)
	add_child(col)

	_build_visuals()
	area_entered.connect(_on_area_entered)
	AudioManager.play("slash_2", global_position)


func _build_visuals() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	# Flip visual in flight direction
	_visual_root.scale.x = 1.0 if direction >= 0.0 else -1.0
	add_child(_visual_root)

	# 1. Filled crescent energy body
	_core_poly = Polygon2D.new()
	_core_poly.polygon = PackedVector2Array([
		Vector2(14.0, -56.0),
		Vector2(6.0, -42.0),
		Vector2(-4.0, -28.0),
		Vector2(4.0, -14.0),
		Vector2(16.0, 0.0),
		Vector2(6.0, -2.0),
		Vector2(-12.0, -28.0),
		Vector2(4.0, -52.0)
	])
	_core_poly.color = Color(1.0, 0.35, 0.1, 0.90)
	_visual_root.add_child(_core_poly)

	# 2. Outer glowing flaming blade arc
	_outer_arc = Line2D.new()
	_outer_arc.width = 16.0
	_outer_arc.default_color = Color(1.0, 0.18, 0.08, 0.95)
	_outer_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_outer_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	_outer_arc.points = PackedVector2Array([
		Vector2(15.0, -56.0),
		Vector2(5.0, -42.0),
		Vector2(-6.0, -28.0),
		Vector2(5.0, -14.0),
		Vector2(17.0, 0.0)
	])
	_visual_root.add_child(_outer_arc)

	# 3. Inner razor-sharp white hot core
	_inner_arc = Line2D.new()
	_inner_arc.width = 5.0
	_inner_arc.default_color = Color(1.0, 0.96, 0.88, 1.0)
	_inner_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_inner_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	_inner_arc.points = PackedVector2Array([
		Vector2(13.0, -52.0),
		Vector2(3.0, -40.0),
		Vector2(-4.0, -28.0),
		Vector2(4.0, -14.0),
		Vector2(14.0, -3.0)
	])
	_visual_root.add_child(_inner_arc)

	# 4. Trailing energy tail streamers
	var trail_top := Line2D.new()
	trail_top.width = 4.0
	trail_top.default_color = Color(1.0, 0.45, 0.1, 0.7)
	trail_top.points = PackedVector2Array([Vector2(14.0, -56.0), Vector2(-16.0, -50.0)])
	_visual_root.add_child(trail_top)

	var trail_bot := Line2D.new()
	trail_bot.width = 4.0
	trail_bot.default_color = Color(1.0, 0.45, 0.1, 0.7)
	trail_bot.points = PackedVector2Array([Vector2(16.0, 0.0), Vector2(-18.0, 4.0)])
	_visual_root.add_child(trail_bot)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta

	# Dynamic breathing oscillation
	var pulse := sin(Time.get_ticks_msec() * 0.025)
	if is_instance_valid(_visual_root):
		_visual_root.scale.y = 1.0 + pulse * 0.08
		_visual_root.modulate = Color(1.0 + pulse * 0.2, 0.9, 0.85, 1.0)

	# Emit ground scrape spark particles along flight path
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.04
		_spawn_ground_spark()

	if absf(position.x - _start_x) >= max_travel_distance:
		_fade_and_destroy()


func _spawn_ground_spark() -> void:
	var parent := get_parent() as Node2D
	if not is_instance_valid(parent):
		return
	var spark := Polygon2D.new()
	var sz := randf_range(2.5, 4.5)
	spark.polygon = PackedVector2Array([Vector2(-sz, -sz), Vector2(sz, -sz), Vector2(sz, sz), Vector2(-sz, sz)])
	spark.color = Color(1.0, randf_range(0.4, 0.85), 0.1, 0.9)
	spark.position = global_position + Vector2(randf_range(-8, 8), randf_range(-4, 2))
	parent.add_child(spark)

	var tween := spark.create_tween()
	var vel := Vector2(-direction * randf_range(40, 100), randf_range(-60, -120))
	tween.parallel().tween_property(spark, "position", spark.position + vel * 0.25, 0.25)
	tween.parallel().tween_property(spark, "scale", Vector2.ZERO, 0.25)
	tween.chain().tween_callback(spark.queue_free)


func _on_area_entered(area: Area2D) -> void:
	if _hit_player:
		return
	var target := area.get_parent()
	if target != null and target.is_in_group("player"):
		_hit_player = true
		if target.has_method("receive_attack"):
			target.receive_attack(global_position, false)
		elif target.has_method("receive_hit"):
			target.receive_hit()
		_spawn_impact_burst()
		queue_free()


func _spawn_impact_burst() -> void:
	var parent := get_parent() as Node2D
	if is_instance_valid(parent):
		GameFeelManager.slash_spark(parent, global_position + Vector2(0, -28), direction, true)
		GameFeelManager.shake(0.35)
		AudioManager.play("smash_3", global_position)


func _fade_and_destroy() -> void:
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)
