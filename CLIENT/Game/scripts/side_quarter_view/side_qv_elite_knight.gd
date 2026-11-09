extends SideQVEnemy
class_name SideQVEliteKnight
## 침묵의 성채 엘리트 심연 기사 (Elite Abyssal Knight)
## - 칠흑의 대리석 갑주와 보이드 암흑 오라를 두른 근위 기사
## - 일반 미니언보다 강화된 내구도(HP 6) 및 빠른 기동성(4.0 m/s)
## - 발밑 핏빛/보이드 룬 링 투영 및 헤드온 정면 마주보기

var void_aura_ring: MeshInstance3D


func _ready() -> void:
	max_hp = 6
	current_hp = 6
	move_speed = 4.0
	attack_damage = 1
	attack_cooldown = 1.0

	super._ready()
	position.z = 0.0
	velocity.z = 0.0
	_apply_elite_visuals()


func _apply_elite_visuals() -> void:
	# Subtle obsidian-purple armor tint
	if sprite_3d != null:
		sprite_3d.modulate = Color(0.85, 0.75, 1.15, 1.0)
		sprite_3d.pixel_size = 0.0034 # ~1.7m imposing height
		sprite_3d.position.y = 0.85

	# Void Rune Aura Ring under feet
	void_aura_ring = MeshInstance3D.new()
	void_aura_ring.name = "EliteVoidRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.70
	torus.outer_radius = 0.85
	void_aura_ring.mesh = torus

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.8, 0.3, 2.2, 0.8)
	rmat.emission_enabled = true
	rmat.emission = Color(1.8, 0.3, 2.2, 1.0)
	rmat.emission_energy_multiplier = 2.5
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	void_aura_ring.material_override = rmat
	void_aura_ring.position.y = 0.06
	add_child(void_aura_ring)
