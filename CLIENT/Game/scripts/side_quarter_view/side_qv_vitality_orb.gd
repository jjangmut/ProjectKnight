class_name SideQVVitalityOrb
extends Node3D
## ProjectKnight V3-021-R1: Natural In-Game Vitality Orb / Soul Essence Pickup
## Floats naturally in 3D world space. When player walks over it, restores +2 HP.
## Provides authentic arcade sustain across the 100m corridor.

const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")

var heal_amount: int = 2
var is_collected: bool = false
var bob_timer: float = 0.0
var base_y: float = 0.45
var orb_mesh: MeshInstance3D = null
var light_3d: OmniLight3D = null


func _ready() -> void:
	base_y = position.y
	if base_y < 0.35:
		base_y = 0.45

	# Visual: Glowing green-gold vitality sphere
	orb_mesh = MeshInstance3D.new()
	orb_mesh.name = "OrbMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	orb_mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_mesh.material_override = mat
	add_child(orb_mesh)

	# Soft omni light
	light_3d = OmniLight3D.new()
	light_3d.name = "OrbLight"
	light_3d.light_color = Color(0.3, 1.0, 0.5)
	light_3d.light_energy = 1.8
	light_3d.omni_range = 2.5
	add_child(light_3d)


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	bob_timer += delta
	position.y = base_y + sin(bob_timer * 4.5) * 0.12
	rotation.y += 2.5 * delta

	# Check proximity to player
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not is_instance_valid(player):
		return

	var diff: Vector3 = player.global_position - global_position
	# 2.5D proximity check: within 1.3m horizontal and 1.2m depth
	var dist_h := Vector2(diff.x, diff.z).length()
	if dist_h <= 1.35 and absf(diff.y) <= 1.8:
		_collect(player)


func _collect(player: Node3D) -> void:
	if is_collected:
		return
	is_collected = true

	# Restore player health naturally
	if "current_hp" in player and "max_hp" in player:
		var old_hp: int = player.current_hp
		player.current_hp = mini(player.max_hp, player.current_hp + heal_amount)
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.current_hp, player.max_hp)

	var p := get_parent()
	if p != null:
		GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 0.8, 0.0), "+%d HP" % heal_amount, Color(0.2, 1.2, 0.4), true)

	AudioManager.play("player_slash_1", Vector2(global_position.x, global_position.z))

	# Pickup collection tween
	var tween := create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "position:y", position.y + 0.8, 0.25)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.25)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
