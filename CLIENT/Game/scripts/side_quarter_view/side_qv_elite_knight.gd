extends "res://scripts/side_quarter_view/side_qv_enemy.gd"
class_name SideQVEliteKnight
## 침묵의 성채 중장 방패 기사 (Heavy Shield Knight)
## - 칠흑의 대리석 갑주와 육중한 타워 실드를 장착한 정예 방패 기사
## - 전방 방패 방어(Frontal Shield Guard): 정면 공격 100% 가드 차단 및 튕겨냄 (버튼 연타 무력화)
## - 파훼법: Z축 깊이 우회(Flank), 등 뒤 기습(Backstab), 공중 찍기(Jump Attack), 공격 후딜레이 딜캐
## - 가드 차단 직후 위협적인 방패 밀치기(Shield Bash) 반격

const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")

# VIS-010 Authentic 3D Shield PBR Textures (inherits TexHitSpark, TexShockwaveRing from SideQVEnemy)
const TexShieldAlbedo = preload("res://assets/props/heavy_shield_albedo.png")
const TexShieldNormal = preload("res://assets/props/heavy_shield_normal.png")
const TexShieldPBR = preload("res://assets/props/heavy_shield_metallic_roughness.png")

var void_aura_ring: MeshInstance3D
var shield_socket: Node3D
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

	# Void Rune Aura Ring under feet (controlled emission)
	void_aura_ring = MeshInstance3D.new()
	void_aura_ring.name = "EliteVoidRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.70
	torus.outer_radius = 0.85
	void_aura_ring.mesh = torus

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.3, 0.3, 1.6, 0.8)
	rmat.emission_enabled = true
	rmat.emission = Color(1.3, 0.3, 1.6, 1.0)
	rmat.emission_energy_multiplier = 1.35
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	void_aura_ring.material_override = rmat
	void_aura_ring.position.y = 0.06
	add_child(void_aura_ring)

	# Heavy Bastion Greatshield Visual (VIS-010 Curved 3D Heater Shield with PBR Textures & Arm Socket)
	shield_socket = Node3D.new()
	shield_socket.name = "ShieldSocket"
	add_child(shield_socket)

	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "HeavyHeaterShieldMesh"
	shield_mesh.mesh = _generate_heater_shield_mesh()

	var smat := StandardMaterial3D.new()
	smat.albedo_texture = TexShieldAlbedo
	smat.normal_enabled = true
	smat.normal_texture = TexShieldNormal
	smat.normal_scale = 1.0
	smat.metallic = 0.85
	smat.metallic_texture = TexShieldPBR
	smat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	smat.roughness = 0.35
	smat.roughness_texture = TexShieldPBR
	smat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = smat
	shield_socket.add_child(shield_mesh)


static func _generate_heater_shield_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rows := 12
	var cols := 8
	var h_top := 0.55
	var h_bot := -0.60
	var w_top := 0.52
	var curve_depth := 0.075

	# Front face curved surface vertices
	for r in range(rows - 1):
		var v_frac0 := float(r) / float(rows - 1)
		var v_frac1 := float(r + 1) / float(rows - 1)
		var y0 := lerpf(h_top, h_bot, v_frac0)
		var y1 := lerpf(h_top, h_bot, v_frac1)

		# Width tapers towards lower pointed tip
		var w0 := w_top if v_frac0 < 0.45 else lerpf(w_top, 0.04, (v_frac0 - 0.45) / 0.55)
		var w1 := w_top if v_frac1 < 0.45 else lerpf(w_top, 0.04, (v_frac1 - 0.45) / 0.55)

		for c in range(cols - 1):
			var u_frac0 := float(c) / float(cols - 1)
			var u_frac1 := float(c + 1) / float(cols - 1)
			var x00 := lerpf(-w0 * 0.5, w0 * 0.5, u_frac0)
			var x01 := lerpf(-w0 * 0.5, w0 * 0.5, u_frac1)
			var x10 := lerpf(-w1 * 0.5, w1 * 0.5, u_frac0)
			var x11 := lerpf(-w1 * 0.5, w1 * 0.5, u_frac1)

			var nx00 := (u_frac0 - 0.5) * 2.0
			var nx01 := (u_frac1 - 0.5) * 2.0
			var nx10 := (u_frac0 - 0.5) * 2.0
			var nx11 := (u_frac1 - 0.5) * 2.0

			var z00 := -curve_depth * (1.0 - nx00 * nx00)
			var z01 := -curve_depth * (1.0 - nx01 * nx01)
			var z10 := -curve_depth * (1.0 - nx10 * nx10)
			var z11 := -curve_depth * (1.0 - nx11 * nx11)

			var p00 := Vector3(x00, y0, z00)
			var p01 := Vector3(x01, y0, z01)
			var p10 := Vector3(x10, y1, z10)
			var p11 := Vector3(x11, y1, z11)

			# Front face quad
			st.set_uv(Vector2(u_frac0, v_frac0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u_frac1, v_frac0))
			st.add_vertex(p01)
			st.set_uv(Vector2(u_frac1, v_frac1))
			st.add_vertex(p11)

			st.set_uv(Vector2(u_frac0, v_frac0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u_frac1, v_frac1))
			st.add_vertex(p11)
			st.set_uv(Vector2(u_frac0, v_frac1))
			st.add_vertex(p10)

			# Back face quad (thickness +0.025m)
			var t_offset := Vector3(0, 0, 0.025)
			st.set_uv(Vector2(1.0 - u_frac0, v_frac0))
			st.add_vertex(p00 + t_offset)
			st.set_uv(Vector2(1.0 - u_frac1, v_frac1))
			st.add_vertex(p11 + t_offset)
			st.set_uv(Vector2(1.0 - u_frac1, v_frac0))
			st.add_vertex(p01 + t_offset)

			st.set_uv(Vector2(1.0 - u_frac0, v_frac0))
			st.add_vertex(p00 + t_offset)
			st.set_uv(Vector2(1.0 - u_frac0, v_frac1))
			st.add_vertex(p10 + t_offset)
			st.set_uv(Vector2(1.0 - u_frac1, v_frac1))
			st.add_vertex(p11 + t_offset)

	# Central raised umbo boss (8-sided diamond/octagon)
	var boss_y := 0.06
	var boss_r := 0.08
	var boss_depth := -curve_depth - 0.035
	var boss_sides := 8
	for i in range(boss_sides):
		var a0 := float(i) * TAU / float(boss_sides)
		var a1 := float(i + 1) * TAU / float(boss_sides)
		var bp0 := Vector3(cos(a0) * boss_r, boss_y + sin(a0) * boss_r, -curve_depth)
		var bp1 := Vector3(cos(a1) * boss_r, boss_y + sin(a1) * boss_r, -curve_depth)
		var tip := Vector3(0.0, boss_y, boss_depth)

		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(tip)
		st.set_uv(Vector2(0.5 + cos(a0) * 0.15, 0.5 + sin(a0) * 0.15))
		st.add_vertex(bp0)
		st.set_uv(Vector2(0.5 + cos(a1) * 0.15, 0.5 + sin(a1) * 0.15))
		st.add_vertex(bp1)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _physics_process(delta: float) -> void:
	if post_attack_recovery > 0.0:
		post_attack_recovery -= delta
		if post_attack_recovery <= 0.0:
			is_shield_guarding = true

	# Dynamic shield positioning & rotation based on combat state and facing direction
	if shield_socket != null and sprite_3d != null:
		var face_x: float = -1.0 if sprite_3d.flip_h else 1.0
		var target_pos: Vector3
		var target_rot: Vector3
		if is_attacking:
			# Shield Bash forward lunge
			target_pos = Vector3(face_x * 0.58, 0.82, 0.02)
			target_rot = Vector3(0.0, 90.0 if face_x > 0 else -90.0, 4.0 * face_x)
		elif is_shield_guarding:
			# Defensive frontal guard
			target_pos = Vector3(face_x * 0.44, 0.80, 0.04)
			target_rot = Vector3(0.0, 88.0 if face_x > 0 else -88.0, 0.0)
		else:
			# Relaxed forearm carry
			target_pos = Vector3(face_x * 0.38, 0.72, 0.14)
			target_rot = Vector3(6.0, 62.0 if face_x > 0 else -62.0, -8.0 * face_x)

		shield_socket.position = shield_socket.position.lerp(target_pos, delta * 12.0)
		shield_socket.rotation_degrees = shield_socket.rotation_degrees.lerp(target_rot, delta * 12.0)

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
		# FRONT BLOCKED: Clang! 0 damage, player attack bounces!
		_spawn_shield_block_sparks()
		AudioManager.play("guard_block")
		var p := get_parent()
		if p != null:
			GameFeelManager.damage_popup_3d(p, global_position + Vector3(0.0, 1.5, 0.0), "BLOCKED!", Color(0.4, 0.8, 1.4), true)

		# Shield recoil animation kickback
		if shield_socket != null:
			var rtw := shield_socket.create_tween()
			if rtw:
				var recoil_p := shield_socket.position - Vector3(face_x * 0.12, 0.0, 0.0)
				var recoil_r := shield_socket.rotation_degrees + Vector3(0.0, 0.0, 14.0 * face_x)
				rtw.tween_property(shield_socket, "position", recoil_p, 0.05)
				rtw.parallel().tween_property(shield_socket, "rotation_degrees", recoil_r, 0.05)
				rtw.chain().tween_property(shield_socket, "position", shield_socket.position, 0.12)
				rtw.parallel().tween_property(shield_socket, "rotation_degrees", shield_socket.rotation_degrees, 0.12)

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
	var face_x: float = -1.0 if (sprite_3d != null and sprite_3d.flip_h) else 1.0
	var spark_pos := global_position + Vector3(face_x * 0.5, 0.85, 0.0)

	# 1. Textured Spark Burst (QuadMesh billboard)
	var spark := MeshInstance3D.new()
	spark.name = "ShieldBlockSpark3D"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.95)
	spark.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TexHitSpark
	mat.albedo_color = Color(0.4, 1.15, 1.6, 0.95)
	mat.emission_enabled = true
	mat.emission_texture = TexHitSpark
	mat.emission = Color(0.4, 1.15, 1.6, 1.0)
	mat.emission_energy_multiplier = 1.35
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.material_override = mat
	p.add_child(spark)
	spark.global_position = spark_pos
	var tw := spark.create_tween()
	if tw:
		tw.set_parallel(true)
		tw.tween_property(spark, "scale", Vector3(2.0, 2.0, 2.0), 0.16)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.16)
		tw.chain().tween_callback(spark.queue_free)

	# 2. Textured Runic Shockwave Ring (QuadMesh billboard)
	var ring := MeshInstance3D.new()
	ring.name = "ShieldBlockRing3D"
	var rquad := QuadMesh.new()
	rquad.size = Vector2(1.2, 1.2)
	ring.mesh = rquad
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = TexShockwaveRing
	rmat.albedo_color = Color(0.35, 1.0, 1.5, 0.9)
	rmat.emission_enabled = true
	rmat.emission_texture = TexShockwaveRing
	rmat.emission = Color(0.35, 1.0, 1.5, 1.0)
	rmat.emission_energy_multiplier = 1.30
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ring.material_override = rmat
	p.add_child(ring)
	ring.global_position = spark_pos
	var rtw := ring.create_tween()
	if rtw:
		rtw.set_parallel(true)
		rtw.tween_property(ring, "scale", Vector3(2.4, 2.4, 2.4), 0.20)
		rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.20)
		rtw.chain().tween_callback(ring.queue_free)
