class_name GameFeelManager
extends Node
## Central Game Feel & Juice Manager for Project Knight:
## Handles Hit Stop (freeze frame), Trauma-based Camera Shake, and Floating Combat Text.

static var _instance: GameFeelManager

var _hit_stop_end_msec: int = 0
var trauma: float = 0.0
var max_shake_offset: Vector2 = Vector2(10.0, 7.0)
var trauma_decay: float = 2.8
var _current_camera: Camera2D = null

func _enter_tree() -> void:
	if _instance == null:
		_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _instance == self:
		_instance = null
		Engine.time_scale = 1.0


static func get_instance() -> GameFeelManager:
	return _instance


func register_camera(cam: Camera2D) -> void:
	_current_camera = cam


func _find_fallback_camera() -> void:
	if get_tree() == null:
		return
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null:
		var cam := player_node.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			_current_camera = cam
			return
	var viewport := get_viewport()
	if viewport != null:
		_current_camera = viewport.get_camera_2d()


func _process(delta: float) -> void:
	# 1. Hit Stop time recovery using real-time ticks
	if _hit_stop_end_msec > 0:
		if Time.get_ticks_msec() >= _hit_stop_end_msec:
			_hit_stop_end_msec = 0
			Engine.time_scale = 1.0

	# 2. Camera Shake decay and application
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		if not is_instance_valid(_current_camera):
			_find_fallback_camera()
		if is_instance_valid(_current_camera):
			var shake_amount := pow(trauma, 1.25)
			var offset_x := randf_range(-1.0, 1.0) * max_shake_offset.x * shake_amount
			var offset_y := randf_range(-1.0, 1.0) * max_shake_offset.y * shake_amount
			if not is_finite(offset_x) or not is_finite(offset_y):
				_current_camera.offset = Vector2.ZERO
			else:
				_current_camera.offset = Vector2(offset_x, offset_y)
	elif is_instance_valid(_current_camera) and _current_camera.offset != Vector2.ZERO:
		_current_camera.offset = Vector2.ZERO


## Triggers a brief freeze frame (Hit Stop)
func hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = time_scale
	_hit_stop_end_msec = Time.get_ticks_msec() + int(duration * 1000.0)


## Adds camera trauma (0.0 to 1.0)
func add_camera_shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Spawns a floating combat text node in the world
func spawn_damage_number(parent_node: Node2D, world_pos: Vector2, text: String, color: Color = Color.WHITE, is_crit: bool = false) -> void:
	if not is_instance_valid(parent_node):
		return
	var label := Label.new()
	label.text = text
	label.z_index = 30
	label.position = world_pos + Vector2(-30.0, -20.0)
	var font_size := 38 if is_crit else 30
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	parent_node.add_child(label)

	# Lightweight script/tween animation without external dependencies
	var tween := label.create_tween()
	var target_pos := label.position + Vector2(randf_range(-12.0, 12.0), -36.0 if not is_crit else -50.0)
	var duration := 0.55 if not is_crit else 0.70

	if is_crit:
		label.scale = Vector2(1.3, 1.3)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)

	tween.tween_property(label, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.tween_callback(label.queue_free)


static func register_active_camera(cam: Camera2D) -> void:
	if cam == null:
		return
	var inst := get_instance()
	if inst == null and cam.get_tree() != null and cam.get_tree().root != null:
		var script_res: GDScript = load("res://scripts/system/game_feel_manager.gd")
		inst = script_res.new()
		inst.name = "GameFeelManager"
		cam.get_tree().root.add_child(inst)
	if inst != null:
		inst.register_camera(cam)


static func ensure_manager(tree: SceneTree):
	var inst := get_instance()
	if inst == null and tree != null and tree.root != null:
		var script_res: GDScript = load("res://scripts/system/game_feel_manager.gd")
		inst = script_res.new()
		inst.name = "GameFeelManager"
		tree.root.add_child(inst)
	return inst



static func trigger_hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.hit_stop(duration, time_scale)


static func shake(amount: float) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.add_camera_shake(amount)


static func damage_popup(parent_node: Node2D, world_pos: Vector2, text: String, color: Color = Color.WHITE, is_crit: bool = false) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.spawn_damage_number(parent_node, world_pos, text, color, is_crit)


## Spawns an energetic slash spark / hit burst at the point of impact
func spawn_slash_spark(parent_node: Node2D, world_pos: Vector2, facing_dir: float = 1.0, is_crit: bool = false) -> void:
	if not is_instance_valid(parent_node):
		return
	var spark_fx := Node2D.new()
	spark_fx.position = world_pos
	spark_fx.z_index = 32
	parent_node.add_child(spark_fx)

	# 1. Primary slash beam
	var line := Line2D.new()
	line.width = 6.0 if is_crit else 4.0
	line.default_color = Color(0.25, 0.95, 1.0, 1.0) if is_crit else Color(1.0, 0.85, 0.25, 1.0)
	var angle := randf_range(-0.4, 0.4) + (0.35 * facing_dir)
	var length := 52.0 if is_crit else 36.0
	var dir_vec := Vector2.RIGHT.rotated(angle)
	line.add_point(-dir_vec * length * 0.5)
	line.add_point(dir_vec * length * 0.5)
	spark_fx.add_child(line)

	# 2. Secondary cross slash
	var cross_line := Line2D.new()
	cross_line.width = 3.5 if is_crit else 2.2
	cross_line.default_color = Color.WHITE
	var cross_vec := dir_vec.orthogonal()
	var cross_len := length * 0.65
	cross_line.add_point(-cross_vec * cross_len * 0.5)
	cross_line.add_point(cross_vec * cross_len * 0.5)
	spark_fx.add_child(cross_line)

	# 3. Flying spark particles
	var spark_count := 8 if is_crit else 5
	var spark_polys: Array[Polygon2D] = []
	var spark_vels: Array[Vector2] = []
	for i in range(spark_count):
		var p := Polygon2D.new()
		var psize := randf_range(2.0, 4.0) if not is_crit else randf_range(3.0, 5.0)
		p.polygon = PackedVector2Array([Vector2(-psize, -psize), Vector2(psize, -psize), Vector2(psize, psize), Vector2(-psize, psize)])
		p.color = Color(1.0, 0.95, 0.4, 1.0) if not is_crit else Color(0.5, 0.95, 1.0, 1.0)
		spark_fx.add_child(p)
		spark_polys.append(p)
		var spd := randf_range(160.0, 340.0) if is_crit else randf_range(100.0, 240.0)
		var sp_angle := randf_range(-PI, PI)
		spark_vels.append(Vector2(cos(sp_angle), sin(sp_angle)) * spd)

	# Animate expansion and fade out
	var duration := 0.20 if is_crit else 0.15
	var tween := spark_fx.create_tween()
	tween.set_parallel(true)
	line.scale = Vector2(0.2, 0.2)
	cross_line.scale = Vector2(0.2, 0.2)
	tween.tween_property(line, "scale", Vector2(1.2, 1.2), duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cross_line, "scale", Vector2(1.2, 1.2), duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(spark_polys.size()):
		var p := spark_polys[i]
		var v := spark_vels[i]
		tween.tween_property(p, "position", v * duration, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "scale", Vector2.ZERO, duration).set_delay(duration * 0.3)
	tween.tween_property(spark_fx, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(spark_fx.queue_free)


static func slash_spark(parent_node: Node2D, world_pos: Vector2, facing_dir: float = 1.0, is_crit: bool = false) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.spawn_slash_spark(parent_node, world_pos, facing_dir, is_crit)



