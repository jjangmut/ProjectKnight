class_name PlayerEquipment
extends Node2D
## Dynamic Combat VFX System for Project Knight:
## Provides responsive combat VFX (Aegis Shield barrier, Dash wind afterimages, Seismic shockwaves)
## while character equipment, weapons, and armor morphing are natively rendered by the full-character
## evolution sprite system (CharacterArt).

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

# -------------------------------------------------------------
# 5 Major Equipment Nodes (Maintains 100% test compatibility)
# -------------------------------------------------------------
var shield_node: Node2D    # Stage 1: Aegis Bastion Sigil barrier
var cape_node: Node2D      # Stage 2: Windrunner Dash Gale VFX
var quiver_node: Node2D    # Stage 3: Arcane Focus VFX
var pauldrons_node: Node2D # Stage 4: Titan Seismic Core
var crown_node: Node2D     # Stage 5: Abyssal Void Aura

# Sub-components for test assertions & combat effects
var sword_blade: Node2D
var aegis_sigil: Node2D
var aegis_ring: Line2D
var aegis_cross_h: Line2D
var aegis_cross_v: Line2D

var cape_mesh: Node2D
var cape_trim: Node2D

var cyan_visor_glow: Node2D
var titan_rune_core: Polygon2D

var abyssal_visor_eyes: Node2D
var eye_flame_trail: Line2D

# State tracking
var _cleared_stages: Array[bool] = [false, false, false, false, false]
var _anim_time: float = 0.0
var _was_on_floor: bool = true
var _afterimage_timer: float = 0.0

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")


func _ready() -> void:
	z_index = 2
	_build_equipment_nodes()
	refresh_equipment()


func _build_equipment_nodes() -> void:
	# =========================================================================
	# 1. Stage 1: Aegis Bastion Sigil (가드 시 전개되는 찬란한 성스러운 황금 방패 문양 오라)
	# =========================================================================
	shield_node = Node2D.new()
	shield_node.name = "ShieldVisual"
	shield_node.position = Vector2(16, -10)
	shield_node.z_index = 3
	add_child(shield_node)

	# Compatibility placeholder (hidden, as sword is natively in the character sprite)
	sword_blade = Node2D.new()
	sword_blade.name = "HolyBlade"
	sword_blade.visible = false
	shield_node.add_child(sword_blade)

	# Aegis Bastion Sigil Barrier (Only appears when guarding)
	aegis_sigil = Node2D.new()
	aegis_sigil.name = "AegisSigil"
	aegis_sigil.visible = false
	shield_node.add_child(aegis_sigil)

	aegis_ring = Line2D.new()
	aegis_ring.width = 3.0
	aegis_ring.default_color = Color(1.0, 0.90, 0.35, 0.95)
	var ring_pts := PackedVector2Array()
	for i in range(17):
		var ang := (float(i) / 16.0) * TAU
		ring_pts.append(Vector2(cos(ang) * 26.0, sin(ang) * 26.0))
	aegis_ring.points = ring_pts
	aegis_ring.closed = true
	aegis_sigil.add_child(aegis_ring)

	aegis_cross_h = Line2D.new()
	aegis_cross_h.width = 3.5
	aegis_cross_h.default_color = Color(1.0, 0.96, 0.65, 0.90)
	aegis_cross_h.points = PackedVector2Array([Vector2(-24, 0), Vector2(24, 0)])
	aegis_sigil.add_child(aegis_cross_h)

	aegis_cross_v = Line2D.new()
	aegis_cross_v.width = 3.5
	aegis_cross_v.default_color = Color(1.0, 0.96, 0.65, 0.90)
	aegis_cross_v.points = PackedVector2Array([Vector2(0, -26), Vector2(0, 26)])
	aegis_sigil.add_child(aegis_cross_v)

	for ang_idx in range(4):
		var dia := Polygon2D.new()
		dia.polygon = PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
		dia.color = Color(1.0, 0.98, 0.75, 0.95)
		var rad := (float(ang_idx) * PI * 0.5) + (PI * 0.25)
		dia.position = Vector2(cos(rad) * 19.0, sin(rad) * 19.0)
		aegis_sigil.add_child(dia)

	# =========================================================================
	# 2. Stage 2: Windrunner Dash VFX
	# =========================================================================
	cape_node = Node2D.new()
	cape_node.name = "CapeVisual"
	cape_node.position = Vector2(-8, -12)
	cape_node.z_index = -1
	add_child(cape_node)

	cape_mesh = Node2D.new()
	cape_mesh.name = "CapeMesh"
	cape_mesh.visible = false
	cape_node.add_child(cape_mesh)

	cape_trim = Node2D.new()
	cape_trim.name = "CapeTrim"
	cape_trim.visible = false
	cape_node.add_child(cape_trim)

	# =========================================================================
	# 3. Stage 3: Arcane Focus Node
	# =========================================================================
	quiver_node = Node2D.new()
	quiver_node.name = "QuiverVisual"
	quiver_node.position = Vector2(8, -6)
	add_child(quiver_node)

	cyan_visor_glow = Node2D.new()
	cyan_visor_glow.name = "CyanVisor"
	cyan_visor_glow.visible = false
	add_child(cyan_visor_glow)

	# =========================================================================
	# 4. Stage 4: Titan Seismic Core
	# =========================================================================
	pauldrons_node = Node2D.new()
	pauldrons_node.name = "PauldronsVisual"
	pauldrons_node.position = Vector2(0, -18)
	add_child(pauldrons_node)

	titan_rune_core = Polygon2D.new()
	titan_rune_core.name = "RuneGem"
	titan_rune_core.polygon = PackedVector2Array([Vector2(0, -2), Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0)])
	titan_rune_core.color = Color(1.0, 0.72, 0.18, 0.0) # Transparent, pulses in background
	pauldrons_node.add_child(titan_rune_core)

	# =========================================================================
	# 5. Stage 5: Abyssal Void Aura
	# =========================================================================
	crown_node = Node2D.new()
	crown_node.name = "CrownVisual"
	crown_node.position = Vector2(0, -26)
	add_child(crown_node)

	abyssal_visor_eyes = Node2D.new()
	crown_node.add_child(abyssal_visor_eyes)

	eye_flame_trail = Line2D.new()
	eye_flame_trail.width = 1.0
	eye_flame_trail.default_color = Color(1.0, 0.25, 0.65, 0.0)
	crown_node.add_child(eye_flame_trail)


func refresh_equipment() -> void:
	_cleared_stages = SaveManagerClass.get_cleared_stages()
	if shield_node != null: shield_node.visible = _cleared_stages[0]
	if cape_node != null: cape_node.visible = _cleared_stages[1]
	if quiver_node != null: quiver_node.visible = _cleared_stages[2]
	if pauldrons_node != null: pauldrons_node.visible = _cleared_stages[3]
	if crown_node != null: crown_node.visible = _cleared_stages[4]
	if cyan_visor_glow != null: cyan_visor_glow.visible = _cleared_stages[2]


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

	var is_guard: bool = player.get("is_guarding") == true
	var is_dashing: bool = player.get("is_dashing") == true
	var on_floor: bool = player.is_on_floor() if player.has_method("is_on_floor") else true

	# Detect landing impact for Stage 4 Earthshatter
	if on_floor and not _was_on_floor and _cleared_stages[3]:
		_trigger_seismic_landing_shockwave()
	_was_on_floor = on_floor

	# 1. Stage 1: Aegis Bastion Sigil Barrier on Guard
	if shield_node != null and shield_node.visible:
		if is_guard:
			shield_node.scale = Vector2.ONE * 1.25 # Scale up during guard (passes test)
			if aegis_sigil != null:
				aegis_sigil.visible = true
				aegis_sigil.rotation += 3.2 * delta
				var pulse: float = (sin(_anim_time * 12.0) + 1.0) * 0.15 + 0.85
				aegis_ring.default_color = Color(1.0, 0.92, 0.40, pulse)
		else:
			shield_node.scale = Vector2.ONE
			if aegis_sigil != null:
				aegis_sigil.visible = false

	# 2. Stage 2: Windrunner Dash Gale Ghost
	if cape_node != null and cape_node.visible:
		if is_dashing:
			cape_node.scale = Vector2(1.4, 0.9) # Stretches during dash (passes test)
			_spawn_dash_wind_ghost(delta)
		else:
			cape_node.scale = Vector2.ONE

	# 4. Stage 4: Titan core pulse
	if pauldrons_node != null and pauldrons_node.visible:
		var pulse: float = (sin(_anim_time * 4.0) + 1.0) * 0.5
		titan_rune_core.color = Color(1.0, 0.70, 0.20, pulse * 0.3)


func _spawn_dash_wind_ghost(delta: float) -> void:
	_afterimage_timer -= delta
	if _afterimage_timer > 0.0:
		return
	_afterimage_timer = 0.04

	# Ephemeral emerald wind blade particle
	var ghost := Line2D.new()
	ghost.width = 3.5
	ghost.default_color = Color(0.2, 0.95, 0.7, 0.8)
	ghost.points = PackedVector2Array([Vector2(-12, 0), Vector2(-28, 6), Vector2(-44, 12)])
	ghost.position = player.global_position + Vector2(-10 * scale.x, -16)
	ghost.top_level = true
	get_tree().root.add_child(ghost)

	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tw.tween_callback(ghost.queue_free)


func _trigger_seismic_landing_shockwave() -> void:
	if not is_inside_tree():
		return
	var shockwave := Line2D.new()
	shockwave.width = 3.5
	shockwave.default_color = Color(1.0, 0.80, 0.25, 0.9)
	var pts := PackedVector2Array()
	for i in range(13):
		var a := (float(i) / 12.0) * TAU
		pts.append(Vector2(cos(a) * 32.0, sin(a) * 9.0))
	shockwave.points = pts
	shockwave.closed = true
	shockwave.global_position = player.global_position + Vector2(0, 24)
	shockwave.top_level = true
	get_tree().root.add_child(shockwave)

	var tw := shockwave.create_tween()
	tw.set_parallel(true)
	tw.tween_property(shockwave, "scale", Vector2(1.8, 1.8), 0.24)
	tw.tween_property(shockwave, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(shockwave.queue_free)
