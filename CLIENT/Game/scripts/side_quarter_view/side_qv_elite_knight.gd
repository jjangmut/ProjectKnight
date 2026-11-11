extends SideQVEnemy
class_name SideQVEliteKnight
## 침묵의 성채 중장 방패 기사 (Heavy Shield Knight)
## - 칠흑의 대리석 갑주와 육중한 타워 실드를 장착한 정예 방패 기사
## - 전방 방패 방어(Frontal Shield Guard): 정면 공격 100% 가드 차단 및 튕겨냄 (버튼 연타 무력화)
## - 파훼법: Z축 깊이 우회(Flank), 등 뒤 기습(Backstab), 공중 찍기(Jump Attack), 공격 후딜레이 딜캐
## - 가드 차단 직후 위협적인 방패 밀치기(Shield Bash) 반격

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

var void_aura_ring: MeshInstance3D
var shield_mesh: MeshInstance3D
var is_shield_guarding: bool = true
var is_bashing: bool = false
var bash_timer: float = 0.0
var post_attack_recovery: float = 0.0


func _ready() -> void:
	max_hp = 8
	current_hp = 8
	move_speed = 3.2
	attack_damage = 2
	attack_cooldown = 1.4

	super._ready()
	_apply_elite_visuals()


func _apply_elite_visuals() -> void:
	# Obsidian-purple plate armor tint
	if sprite_3d != null:
		sprite_3d.modulate = Color(0.9, 0.8, 1.2, 1.0)
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

	# Heavy Bastion Greatshield Visual
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "TowerShieldMesh"
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.18, 1.35, 0.72)
	shield_mesh.mesh = s_box

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.25, 0.28, 0.38, 1.0)
	smat.metallic = 0.90
	smat.roughness = 0.30
	smat.emission_enabled = true
	smat.emission = Color(0.3, 0.6, 1.4, 1.0)
	smat.emission_energy_multiplier = 1.2
	shield_mesh.material_override = smat
	shield_mesh.position = Vector3(-0.45 if (sprite_3d != null and sprite_3d.flip_h) else 0.45, 0.80, 0.0)
	add_child(shield_mesh)


func _physics_process(delta: float) -> void:
	if post_attack_recovery > 0.0:
		post_attack_recovery -= delta
		if post_attack_recovery <= 0.0:
			is_shield_guarding = true

	# Update shield position to face outward in facing direction
	if shield_mesh != null and sprite_3d != null:
		var face_x: float = -1.0 if sprite_3d.flip_h else 1.0
		shield_mesh.position.x = face_x * 0.45

	super._physics_process(delta)


func _execute_attack() -> void:
	# Heavy Shield Bash attack
	current_cooldown = attack_cooldown
	is_attacking = true
	is_shield_guarding = false # Opening during attack!
	attack_timer = 0.0
	velocity = Vector3.ZERO
	if sprite_3d != null:
		var tw := create_tween()
		if tw:
			sprite_3d.modulate = Color(3.0, 1.2, 0.3, 1.0)
			tw.tween_property(sprite_3d, "modulate", Color.WHITE, 0.22)


func receive_hit(amount: int, hit_dir: Vector3 = Vector3.ZERO, is_counter: bool = false) -> void:
	if is_dead or current_hp <= 0 or amount <= 0:
		return

	# Frontal Shield Guard Check:
	# If knight is guarding and hit comes from front hemisphere, BLOCK IT!
	var face_x: float = -1.0 if (sprite_3d != null and sprite_3d.flip_h) else 1.0
	var incoming_x: float = hit_dir.x

	# Hit comes from the front if incoming_x opposes facing direction (or player is in front)
	var is_frontal_hit: bool = (incoming_x * face_x < -0.1) # hit pushes opposite to facing direction
	if target_player != null and is_instance_valid(target_player):
		var to_player: Vector3 = target_player.global_position - global_position
		if to_player.x * face_x > 0.2 and absf(to_player.z) < 1.0:
			is_frontal_hit = true

	if is_shield_guarding and is_frontal_hit and not is_stunned and post_attack_recovery <= 0.0:
		# FRONT BLOCKED: Clang! 0 damage (or 1 chip damage if counter), player attack bounces!
		_spawn_shield_block_sparks()
		AudioManager.play("guard_block")
		var p := get_parent()
		if p != null:
			GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 1.5, 0.0), "BLOCKED!", Color(0.4, 0.8, 1.4), true)

		# Retaliate with immediate heavy shield bash forward
		velocity.x = face_x * 3.5
		is_recoiling = false
		post_attack_recovery = 0.35
		return

	# If hit from flank, back, or during recovery/stun: Takes full damage!
	is_shield_guarding = false
	post_attack_recovery = 0.45 # vulnerable recovery
	super.receive_hit(amount, hit_dir, is_counter)


func _spawn_shield_block_sparks() -> void:
	var p := get_parent()
	if p == null:
		return
	var spark := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.55
	spark.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.5, 2.5, 4.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.5, 2.5, 4.0, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.material_override = mat
	p.add_child(spark)
	var face_x: float = -1.0 if (sprite_3d != null and sprite_3d.flip_h) else 1.0
	spark.global_position = global_position + Vector3(face_x * 0.5, 0.85, 0.0)
	var tw := spark.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(spark, "scale", Vector3(2.2, 2.2, 2.2), 0.18)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
		tw.chain().tween_callback(spark.queue_free)
