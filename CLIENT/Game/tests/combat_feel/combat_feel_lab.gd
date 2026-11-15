extends Node3D
## ProjectKnight V3-026-A: Combat Feel & Timeline Verification Lab
## Demonstrates:
## 1. Frame-exact Attack Timeline (WINDUP -> ACTIVE -> CONTACT -> RECOVERY)
## 2. Zero Startup Damage verification in live combat
## 3. Localized Hitstop / Hitpause without freezing global Engine.time_scale
## 4. 3-Hit Combo sequence against Grunt, Shield Knight, and Boss Dummies

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const HitPauseClass = preload("res://scripts/combat/hit_pause_coordinator.gd")

@export var auto_record_mode: bool = true
@export var record_duration_sec: float = 12.0

var player: CharacterBody3D = null
var grunt_dummy: CharacterBody3D = null
var shield_dummy: CharacterBody3D = null
var boss_dummy: CharacterBody3D = null

# HUD Elements
var hud_root: CanvasLayer = null
var title_label: Label = null
var phase_label: Label = null
var info_label: Label = null
var time_scale_label: Label = null
var timeline_bar_bg: ColorRect = null
var timeline_marker: ColorRect = null

var camera: Camera3D = null
var lab_timer: float = 0.0
var demo_step: int = 0
var demo_timer: float = 0.0


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_actors()
	_setup_hud()

	# Initialize hit pause coordinator
	HitPauseClass.get_instance()

	# Check command line flags
	for arg in OS.get_cmdline_user_args():
		if arg == "--manual":
			auto_record_mode = false


func _setup_environment() -> void:
	# Directional Sun
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_color = Color(1.0, 0.95, 0.88)
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)

	# WorldEnvironment with subtle glow
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

	# Ground Floor Mesh
	var floor_body := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(50.0, 1.0, 15.0)
	fcol.shape = fbox
	floor_body.add_child(fcol)
	floor_body.position.y = -0.5
	add_child(floor_body)

	var fmesh := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(50.0, 1.0, 15.0)
	fmesh.mesh = pbox
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.12, 0.14, 0.18)
	fmat.roughness = 0.8
	fmesh.material_override = fmat
	floor_body.add_child(fmesh)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "LabCamera"
	camera.position = Vector3(2.5, 3.8, 6.8)
	camera.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	camera.current = true
	add_child(camera)


func _setup_actors() -> void:
	# 1. Player
	player = SideQVPlayerClass.new()
	player.position = Vector3(-1.5, 0.0, 0.0)
	add_child(player)

	# 2. Grunt Dummy
	grunt_dummy = SideQVEnemyClass.new()
	grunt_dummy.position = Vector3(1.2, 0.0, 0.0)
	grunt_dummy.max_hp = 999
	grunt_dummy.current_hp = 999
	grunt_dummy.add_to_group("enemies")
	add_child(grunt_dummy)

	# 3. Shield Knight Dummy
	shield_dummy = SideQVEliteKnightClass.new()
	shield_dummy.position = Vector3(4.5, 0.0, 0.0)
	shield_dummy.max_hp = 999
	shield_dummy.current_hp = 999
	shield_dummy.add_to_group("enemies")
	add_child(shield_dummy)

	# 4. Boss Commander Dummy
	boss_dummy = SideQVBossClass.new()
	boss_dummy.position = Vector3(8.0, 0.0, 0.0)
	boss_dummy.max_hp = 9999
	boss_dummy.current_hp = 9999
	boss_dummy.add_to_group("enemies")
	add_child(boss_dummy)


func _setup_hud() -> void:
	hud_root = CanvasLayer.new()
	add_child(hud_root)

	# Title Banner
	title_label = Label.new()
	title_label.text = "[ProjectKnight V3-026-A] Combat Feel & Deterministic Timeline Lab"
	title_label.position = Vector2(24, 20)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.50))
	hud_root.add_child(title_label)

	# Timeline Phase Banner
	phase_label = Label.new()
	phase_label.text = "PHASE: IDLE | HITBOX: OFF | DAMAGE: 0"
	phase_label.position = Vector2(24, 52)
	phase_label.add_theme_font_size_override("font_size", 24)
	phase_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hud_root.add_child(phase_label)

	# Info Metrics Label
	info_label = Label.new()
	info_label.text = "Combo: 0 | Action: none | Elapsed: 0.00s | Frame: 0/0\nLocal Hitstop: ACTIVE | Camera Trauma: 0.00"
	info_label.position = Vector2(24, 90)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hud_root.add_child(info_label)

	# Speed readout
	time_scale_label = Label.new()
	time_scale_label.text = "Speed: 1.0x (Normal) | Controls: [1] 0.2x [2] 0.5x [3] 1.0x [J] Attack [K] Dash"
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
	if player == null:
		return

	var phase_str := "IDLE"
	var hitbox_str := "OFF"
	var dmg_str := "0"
	var phase_col := Color(0.6, 0.6, 0.6)

	if player.timeline_controller != null and player.timeline_controller.is_busy():
		match player.timeline_controller.current_phase:
			player.timeline_controller.Phase.WINDUP:
				phase_str = "WINDUP (ZERO-DAMAGE PRE-CONTACT)"
				hitbox_str = "OFF"
				dmg_str = "0"
				phase_col = Color(1.0, 0.8, 0.2)
			player.timeline_controller.Phase.ACTIVE:
				phase_str = "ACTIVE (BLADE ARC & CONTACT)"
				hitbox_str = "ON"
				dmg_str = str(player.timeline_controller.current_action.damage) if player.timeline_controller.current_action else "?"
				phase_col = Color(1.0, 0.2, 0.2)
			player.timeline_controller.Phase.RECOVERY:
				phase_str = "RECOVERY (CANCEL WINDOW OPEN)"
				hitbox_str = "OFF"
				dmg_str = "0"
				phase_col = Color(0.3, 0.8, 1.0)

	phase_label.text = "PHASE: %s | HITBOX: %s | DMG: %s" % [phase_str, hitbox_str, dmg_str]
	phase_label.add_theme_color_override("font_color", phase_col)

	var act_name := "none"
	var elapsed := 0.0
	var cur_frame := 0
	var tot_frames := 0
	if player.timeline_controller != null and player.timeline_controller.current_action != null:
		act_name = player.timeline_controller.current_action.action_id
		elapsed = player.timeline_controller.elapsed_time
		tot_frames = player.timeline_controller.current_action.total_frames
		cur_frame = player.timeline_controller.get_frame_for_time(elapsed) if player.timeline_controller.has_method("get_frame_for_time") else player.sprite_3d.frame

	info_label.text = "Combo Step: %d | Action: %s | Time: %.3fs | Frame: %d/%d\nHitstop: LOCAL_SCOPED | Player HP: %d/%d" % [
		player.combo_step, act_name, elapsed, cur_frame, tot_frames, player.current_hp, player.max_hp
	]


func _process_auto_demo(delta: float) -> void:
	demo_timer += delta
	lab_timer += delta

	match demo_step:
		0:
			# Step 0: Brief initial pause
			if demo_timer >= 0.5:
				demo_step = 1
				demo_timer = 0.0
		1:
			# Step 1: Attack 1 against Grunt Dummy
			player.start_attack()
			demo_step = 2
			demo_timer = 0.0
		2:
			# Wait for Attack 1 recovery and show clean hitstop
			if demo_timer >= 0.45:
				demo_step = 3
				demo_timer = 0.0
		3:
			# Move to Shield Dummy
			player.position.x = lerpf(player.position.x, shield_dummy.position.x - 1.2, 0.12)
			if absf(player.position.x - (shield_dummy.position.x - 1.2)) < 0.1 or demo_timer >= 1.2:
				demo_step = 4
				demo_timer = 0.0
		4:
			# Attack 1 -> Attack 2 combo on Shield Dummy
			player.start_attack()
			demo_step = 5
			demo_timer = 0.0
		5:
			# Buffer Attack 2
			if demo_timer >= 0.20:
				player.start_attack()
				demo_step = 6
				demo_timer = 0.0
		6:
			# Wait for combo 2 recovery
			if demo_timer >= 0.50:
				demo_step = 7
				demo_timer = 0.0
		7:
			# Move to Boss Dummy
			player.position.x = lerpf(player.position.x, boss_dummy.position.x - 1.4, 0.10)
			if absf(player.position.x - (boss_dummy.position.x - 1.4)) < 0.1 or demo_timer >= 1.5:
				demo_step = 8
				demo_timer = 0.0
		8:
			# Full 3-Hit Combo Showcase on Boss Dummy
			player.start_attack() # Attack 1
			demo_step = 9
			demo_timer = 0.0
		9:
			if demo_timer >= 0.22:
				player.start_attack() # Attack 2
				demo_step = 10
				demo_timer = 0.0
		10:
			if demo_timer >= 0.24:
				player.start_attack() # Attack 3 Finisher
				demo_step = 11
				demo_timer = 0.0
		11:
			# Slow motion showcase (0.2x) to clearly illustrate blade trajectory sync
			if demo_timer >= 0.60:
				Engine.time_scale = 0.25
				time_scale_label.text = "Speed: 0.25x (Super Slowmo Inspection) - Visualizing zero startup damage and blade sync"
				player.combo_step = 0
				player.start_attack()
				demo_step = 12
				demo_timer = 0.0
		12:
			if demo_timer >= 0.80:
				Engine.time_scale = 1.0
				time_scale_label.text = "Speed: 1.0x (Normal) - Verification Showcase Complete"
				demo_step = 13
				demo_timer = 0.0
		13:
			if demo_timer >= 1.0:
				print("[CombatFeelLab] Automated showcase complete!")
				if auto_record_mode:
					get_tree().quit(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				Engine.time_scale = 0.2
				time_scale_label.text = "Speed: 0.2x (Slowmo)"
			KEY_2:
				Engine.time_scale = 0.5
				time_scale_label.text = "Speed: 0.5x"
			KEY_3:
				Engine.time_scale = 1.0
				time_scale_label.text = "Speed: 1.0x (Normal)"
			KEY_J:
				if player != null:
					player.start_attack()
			KEY_K:
				if player != null:
					player.start_dash()
			KEY_R:
				if grunt_dummy != null: grunt_dummy.current_hp = 999
				if shield_dummy != null: shield_dummy.current_hp = 999
				if boss_dummy != null: boss_dummy.current_hp = 9999
