extends Node3D
## ProjectKnight V3-026-C: Enemy & Boss Combat Timeline Showcase Lab
## Demonstrates:
## 1. Melee Grunt: 0.28s Tell -> 0.14s Active Swipe -> 0.22s Whiff Recovery
## 2. Heavy Shield Knight: 0.35s Tell -> 0.18s Active Surge -> 0.42s Shield-Down Recovery
## 3. Boss Commander: 0.44s Stationary Runway Tell -> 12.0m/s Shield Charge -> Triple Cleave
## 4. Synchronized Localized Hitstop (HitPauseCoordinator) on all actors

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const HitPauseClass = preload("res://scripts/combat/hit_pause_coordinator.gd")

@export var auto_record_mode: bool = true

var player: CharacterBody3D = null
var grunt: CharacterBody3D = null
var elite_knight: CharacterBody3D = null
var boss: CharacterBody3D = null

# HUD Elements
var hud_root: CanvasLayer = null
var title_label: Label = null
var actor_label: Label = null
var phase_label: Label = null
var info_label: Label = null
var time_scale_label: Label = null

var camera: Camera3D = null
var demo_step: int = 0
var demo_timer: float = 0.0


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_actors()
	_setup_hud()

	HitPauseClass.get_instance()

	for arg in OS.get_cmdline_user_args():
		if arg == "--manual":
			auto_record_mode = false


func _setup_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_color = Color(1.0, 0.95, 0.88)
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.10, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.25, 0.32)
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var floor_body := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(60.0, 1.0, 15.0)
	fcol.shape = fbox
	floor_body.add_child(fcol)
	floor_body.position.y = -0.5
	add_child(floor_body)

	var fmesh := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(60.0, 1.0, 15.0)
	fmesh.mesh = pbox
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.12, 0.14, 0.18)
	fmat.roughness = 0.8
	fmesh.material_override = fmat
	floor_body.add_child(fmesh)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "LabCamera"
	camera.position = Vector3(1.5, 3.8, 6.8)
	camera.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	camera.current = true
	add_child(camera)


func _setup_actors() -> void:
	# Player
	player = SideQVPlayerClass.new()
	player.position = Vector3(-1.8, 0.0, 0.0)
	player.max_hp = 100
	player.current_hp = 100
	add_child(player)

	# Grunt
	grunt = SideQVEnemyClass.new()
	grunt.position = Vector3(1.2, 0.0, 0.0)
	grunt.max_hp = 999
	grunt.current_hp = 999
	grunt.add_to_group("enemies")
	add_child(grunt)

	# Elite Knight
	elite_knight = SideQVEliteKnightClass.new()
	elite_knight.position = Vector3(5.5, 0.0, 0.0)
	elite_knight.max_hp = 999
	elite_knight.current_hp = 999
	elite_knight.add_to_group("enemies")
	add_child(elite_knight)

	# Boss Commander
	boss = SideQVBossClass.new()
	boss.position = Vector3(10.5, 0.0, 0.0)
	boss.max_hp = 9999
	boss.current_hp = 9999
	boss.add_to_group("enemies")
	add_child(boss)


func _setup_hud() -> void:
	hud_root = CanvasLayer.new()
	add_child(hud_root)

	title_label = Label.new()
	title_label.text = "[ProjectKnight V3-026-C] Enemy & Boss Combat Timeline Verification"
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.50))
	hud_root.add_child(title_label)

	actor_label = Label.new()
	actor_label.text = "ACTOR: Melee Grunt | ACTION: Slash Attack"
	actor_label.position = Vector2(24, 46)
	actor_label.add_theme_font_size_override("font_size", 22)
	actor_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hud_root.add_child(actor_label)

	phase_label = Label.new()
	phase_label.text = "PHASE: IDLE | HITBOX: OFF | DAMAGE: 0"
	phase_label.position = Vector2(24, 76)
	phase_label.add_theme_font_size_override("font_size", 20)
	phase_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hud_root.add_child(phase_label)

	info_label = Label.new()
	info_label.text = "Tell: 0.28s | Active: 0.14s | Recovery: 0.22s | Hitstop: LOCAL_SCOPED"
	info_label.position = Vector2(24, 106)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hud_root.add_child(info_label)

	time_scale_label = Label.new()
	time_scale_label.text = "Speed: 1.0x (Normal) | Zero Startup Damage & Synchronized Hitstop"
	time_scale_label.position = Vector2(24, 680)
	time_scale_label.add_theme_font_size_override("font_size", 16)
	time_scale_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hud_root.add_child(time_scale_label)


func _process(delta: float) -> void:
	_update_hud()
	_update_camera_tracking()

	if auto_record_mode:
		_process_auto_demo(delta)


func _update_camera_tracking() -> void:
	if camera != null and player != null:
		var target_x := player.position.x + 1.8
		camera.position.x = lerpf(camera.position.x, target_x, 0.08)


func _update_hud() -> void:
	var cur_actor: Node3D = grunt
	if demo_step >= 5 and demo_step < 10:
		cur_actor = elite_knight
		actor_label.text = "ACTOR: Elite Shield Knight | ACTION: Heavy Shield Bash"
		info_label.text = "Tell: 0.35s (Shield Back) | Active: 0.18s (Surge) | Recovery: 0.42s (Whiff Opening)"
	elif demo_step >= 10:
		cur_actor = boss
		actor_label.text = "ACTOR: Boss Commander | ACTION: Shield Charge & Triple Cleave"
		info_label.text = "Charge Tell: 0.44s Stationary Runway | Cleave: 3 Distinct Swings & Magma Fissure"

	var cur_phase: String = "IDLE"
	var hitbox_on: bool = false
	if cur_actor != null and is_instance_valid(cur_actor):
		if "attack_phase" in cur_actor:
			cur_phase = cur_actor.attack_phase
		elif "pattern_phase" in cur_actor:
			cur_phase = cur_actor.pattern_phase

		if "attack_area_3d" in cur_actor and cur_actor.attack_area_3d != null:
			hitbox_on = cur_actor.attack_area_3d.monitoring

	var phase_col := Color(0.6, 0.6, 0.6)
	match cur_phase:
		"TELL":
			phase_col = Color(1.0, 0.8, 0.2)
		"ACTIVE":
			phase_col = Color(1.0, 0.2, 0.2)
		"RECOVERY":
			phase_col = Color(0.3, 0.8, 1.0)

	phase_label.text = "PHASE: %s | HITBOX: %s | LOCAL HITSTOP: %s" % [
		cur_phase,
		"ON" if hitbox_on else "OFF",
		"ACTIVE" if (cur_actor != null and "is_hit_paused" in cur_actor and cur_actor.is_hit_paused) else "STANDBY"
	]
	phase_label.add_theme_color_override("font_color", phase_col)


func _process_auto_demo(delta: float) -> void:
	demo_timer += delta

	match demo_step:
		0:
			# Overview of Melee Grunt
			if demo_timer >= 0.8:
				demo_step = 1
				demo_timer = 0.0
		1:
			# Grunt attacks player
			grunt._execute_attack()
			demo_step = 2
			demo_timer = 0.0
		2:
			# Wait for grunt attack to complete and show whiff recovery window
			if demo_timer >= 0.80:
				demo_step = 3
				demo_timer = 0.0
		3:
			# Player punishes grunt with Combo 1 slash
			player.start_attack()
			demo_step = 4
			demo_timer = 0.0
		4:
			# Move to Elite Knight
			if demo_timer >= 0.60:
				demo_step = 5
				demo_timer = 0.0
		5:
			# Approach Elite Knight
			player.position.x = lerpf(player.position.x, elite_knight.position.x - 1.4, 0.10)
			if absf(player.position.x - (elite_knight.position.x - 1.4)) < 0.1 or demo_timer >= 1.2:
				demo_step = 6
				demo_timer = 0.0
		6:
			# Elite Knight executes Heavy Shield Bash
			elite_knight._execute_attack()
			demo_step = 7
			demo_timer = 0.0
		7:
			# Wait for bash active surge and recovery opening
			if demo_timer >= 0.85:
				demo_step = 8
				demo_timer = 0.0
		8:
			# Player counters during shield-down recovery with Combo 1 -> 2
			player.start_attack()
			demo_step = 9
			demo_timer = 0.0
		9:
			if demo_timer >= 0.22:
				player.start_attack()
				demo_step = 10
				demo_timer = 0.0
		10:
			# Move to Boss Commander
			if demo_timer >= 0.70:
				demo_step = 11
				demo_timer = 0.0
		11:
			player.position.x = lerpf(player.position.x, boss.position.x - 2.8, 0.10)
			if absf(player.position.x - (boss.position.x - 2.8)) < 0.15 or demo_timer >= 1.5:
				demo_step = 12
				demo_timer = 0.0
		12:
			# Boss executes Shield Charge (0.44s stationary runway tell)
			boss._execute_shield_charge()
			demo_step = 13
			demo_timer = 0.0
		13:
			# Player dashes past boss charge
			if demo_timer >= 0.50:
				player.start_dash()
				demo_step = 14
				demo_timer = 0.0
		14:
			# Boss turns and executes Triple Cleave
			if demo_timer >= 1.2:
				boss.facing_dir_x = -1.0 if player.position.x < boss.position.x else 1.0
				boss._execute_triple_cleave()
				demo_step = 15
				demo_timer = 0.0
		15:
			# Slowmo (0.25x) showing cleave strikes and magma fissure slam
			if demo_timer >= 0.35:
				Engine.time_scale = 0.25
				time_scale_label.text = "Speed: 0.25x (Slowmo) - Triple Cleave & Magma Fissure Inspection"
				demo_step = 16
				demo_timer = 0.0
		16:
			if demo_timer >= 1.4:
				Engine.time_scale = 1.0
				time_scale_label.text = "Speed: 1.0x (Normal) - Verification Showcase Complete"
				demo_step = 17
				demo_timer = 0.0
		17:
			if demo_timer >= 0.8:
				print("[EnemyCombatFeelLab] Enemy & Boss combat showcase complete!")
				if auto_record_mode:
					get_tree().quit(0)
