class_name PlayerEquipment
extends Node2D
## Dynamic Equipment Visual System for Project Knight:
## Visually transforms the player's character as stage relics and legendary boss items are acquired.

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

var shield_node: Node2D
var shield_mesh: Polygon2D
var shield_border: Line2D
var shield_crest: Polygon2D

var cape_node: Node2D
var cape_mesh: Polygon2D
var cape_inner: Polygon2D

var quiver_node: Node2D
var pauldrons_node: Node2D
var crown_node: Node2D

var _cleared_stages: Array[bool] = [false, false, false, false, false]
var _anim_time: float = 0.0

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")


func _ready() -> void:
	z_index = 1
	_build_equipment_nodes()
	refresh_equipment()


func _build_equipment_nodes() -> void:
	# -------------------------------------------------------------
	# 1. Stage 2 Relic: Flowing Shadow Cape (지휘관/맹수의 그림자 망토)
	# -------------------------------------------------------------
	cape_node = Node2D.new()
	cape_node.name = "CapeVisual"
	cape_node.position = Vector2(0, -16)
	cape_node.z_index = -1 # Behind character body
	add_child(cape_node)

	cape_mesh = Polygon2D.new()
	cape_mesh.polygon = PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0),
		Vector2(12, 34), Vector2(-12, 36), Vector2(-16, 20)
	])
	cape_mesh.color = Color(0.82, 0.16, 0.24, 0.95) # Deep vibrant crimson
	cape_node.add_child(cape_mesh)

	cape_inner = Polygon2D.new()
	cape_inner.polygon = PackedVector2Array([
		Vector2(-2, 2), Vector2(2, 2),
		Vector2(6, 28), Vector2(-8, 30)
	])
	cape_inner.color = Color(0.45, 0.06, 0.12, 0.90) # Shadow inner lining
	cape_node.add_child(cape_inner)

	# -------------------------------------------------------------
	# 2. Stage 1 Relic: Bastion Shield (타락한 사령관의 수호 방패)
	# -------------------------------------------------------------
	shield_node = Node2D.new()
	shield_node.name = "ShieldVisual"
	shield_node.position = Vector2(-8, -4)
	shield_node.z_index = 2 # In front of body
	add_child(shield_node)

	shield_mesh = Polygon2D.new()
	shield_mesh.polygon = PackedVector2Array([
		Vector2(-8, -14), Vector2(8, -14), Vector2(10, 4),
		Vector2(0, 16), Vector2(-10, 4)
	])
	shield_mesh.color = Color(0.22, 0.28, 0.38, 1.0) # Polished steel plate
	shield_node.add_child(shield_mesh)

	shield_border = Line2D.new()
	shield_border.width = 2.0
	shield_border.default_color = Color(1.0, 0.85, 0.25, 1.0) # Gilded gold rim
	shield_border.closed = true
	shield_border.points = shield_mesh.polygon
	shield_node.add_child(shield_border)

	shield_crest = Polygon2D.new()
	shield_crest.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(4, 0), Vector2(0, 8), Vector2(-4, 0)
	])
	shield_crest.color = Color(1.0, 0.85, 0.25, 0.95) # Radiant knight emblem
	shield_node.add_child(shield_crest)

	# -------------------------------------------------------------
	# 3. Stage 3 Relic: Piercing Quiver (폐허 저격수의 예기 화살깃)
	# -------------------------------------------------------------
	quiver_node = Node2D.new()
	quiver_node.name = "QuiverVisual"
	quiver_node.position = Vector2(-10, -12)
	quiver_node.z_index = -1
	quiver_node.rotation_degrees = -25.0
	add_child(quiver_node)

	var q_body := Polygon2D.new()
	q_body.polygon = PackedVector2Array([Vector2(-4, -14), Vector2(4, -14), Vector2(3, 16), Vector2(-3, 16)])
	q_body.color = Color(0.35, 0.24, 0.16) # Leather quiver
	quiver_node.add_child(q_body)

	var arrows := Line2D.new()
	arrows.width = 3.0
	arrows.default_color = Color(0.25, 0.95, 1.0, 1.0) # Glowing turquoise fletchings
	arrows.points = PackedVector2Array([Vector2(0, -14), Vector2(0, -22), Vector2(-3, -20), Vector2(3, -20)])
	quiver_node.add_child(arrows)

	# -------------------------------------------------------------
	# 4. Stage 4 Relic: Golem Runic Pauldrons (고대 수호자의 룬 견갑)
	# -------------------------------------------------------------
	pauldrons_node = Node2D.new()
	pauldrons_node.name = "PauldronsVisual"
	pauldrons_node.position = Vector2(0, -22)
	pauldrons_node.z_index = 3
	add_child(pauldrons_node)

	var p_plate := Polygon2D.new()
	p_plate.polygon = PackedVector2Array([Vector2(-10, -4), Vector2(10, -4), Vector2(12, 4), Vector2(-12, 4)])
	p_plate.color = Color(0.40, 0.44, 0.48) # Titan stone
	pauldrons_node.add_child(p_plate)

	var p_gem := Polygon2D.new()
	p_gem.polygon = PackedVector2Array([Vector2(0, -3), Vector2(4, 0), Vector2(0, 3), Vector2(-4, 0)])
	p_gem.color = Color(1.0, 0.70, 0.20, 1.0) # Pulsing core rune
	p_gem.name = "RuneGem"
	pauldrons_node.add_child(p_gem)

	# -------------------------------------------------------------
	# 5. Stage 5 Relic: Abyssal Void Crown (심연 심판관의 공허 날개깃)
	# -------------------------------------------------------------
	crown_node = Node2D.new()
	crown_node.name = "CrownVisual"
	crown_node.position = Vector2(0, -38)
	crown_node.z_index = 4
	add_child(crown_node)

	var halo := Line2D.new()
	halo.width = 2.5
	halo.default_color = Color(0.85, 0.45, 1.0, 0.95) # Ethereal violet halo
	var halo_pts := PackedVector2Array()
	for i in range(13):
		var ang := (float(i) / 12.0) * TAU
		halo_pts.append(Vector2(cos(ang) * 14.0, sin(ang) * 5.0))
	halo.points = halo_pts
	halo.closed = true
	crown_node.add_child(halo)

	var wings := Line2D.new()
	wings.width = 2.5
	wings.default_color = Color(0.95, 0.65, 1.0, 0.85)
	wings.points = PackedVector2Array([Vector2(-18, -4), Vector2(-12, 0), Vector2(0, 0), Vector2(12, 0), Vector2(18, -4)])
	crown_node.add_child(wings)


func refresh_equipment() -> void:
	_cleared_stages = SaveManagerClass.get_cleared_stages()
	if shield_node != null:
		shield_node.visible = _cleared_stages[0]
	if cape_node != null:
		cape_node.visible = _cleared_stages[1]
	if quiver_node != null:
		quiver_node.visible = _cleared_stages[2]
	if pauldrons_node != null:
		pauldrons_node.visible = _cleared_stages[3]
	if crown_node != null:
		crown_node.visible = _cleared_stages[4]


func set_equipment_active(slot: int, active: bool) -> void:
	match slot:
		1:
			if shield_node != null: shield_node.visible = active
		2:
			if cape_node != null: cape_node.visible = active
		3:
			if quiver_node != null: quiver_node.visible = active
		4:
			if pauldrons_node != null: pauldrons_node.visible = active
		5:
			if crown_node != null: crown_node.visible = active


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_anim_time += delta
	var facing: float = player.facing_direction if ("facing_direction" in player) else 1.0
	scale.x = facing

	# 1. Cape physics sway & dash flutter
	if cape_node != null and cape_node.visible:
		var speed_ratio: float = clampf(absf(player.velocity.x) / 240.0, 0.0, 1.2) if ("velocity" in player) else 0.0
		var is_dashing: bool = player.get("is_dashing") == true
		var target_angle: float = -0.55 * speed_ratio + sin(_anim_time * 8.0) * 0.10
		if is_dashing:
			target_angle = -0.95
			cape_node.scale = Vector2(1.4, 0.9)
		else:
			cape_node.scale = Vector2.ONE
		cape_node.rotation = lerpf(cape_node.rotation, target_angle, 12.0 * delta)

	# 2. Shield Guard & Combat stance
	if shield_node != null and shield_node.visible:
		var is_guard: bool = player.get("is_guarding") == true
		if is_guard:
			shield_node.position = shield_node.position.lerp(Vector2(18.0, -6.0), 16.0 * delta)
			shield_node.scale = Vector2.ONE * 1.25
			shield_crest.color = Color(1.0, 0.95, 0.4, 1.0)
		else:
			shield_node.position = shield_node.position.lerp(Vector2(-8.0, -4.0), 12.0 * delta)
			shield_node.scale = Vector2.ONE
			shield_crest.color = Color(1.0, 0.85, 0.25, 0.95)

	# 3. Pauldron Rune Gem pulse
	if pauldrons_node != null and pauldrons_node.visible:
		var gem: Polygon2D = pauldrons_node.get_node_or_null("RuneGem") as Polygon2D
		if gem != null:
			var pulse: float = (sin(_anim_time * 4.0) + 1.0) * 0.5
			gem.color = Color(1.0, 0.70, 0.20).lerp(Color(0.4, 0.95, 1.0), pulse)

	# 4. Crown floating bobbing
	if crown_node != null and crown_node.visible:
		crown_node.position.y = -38.0 + sin(_anim_time * 3.5) * 3.0
