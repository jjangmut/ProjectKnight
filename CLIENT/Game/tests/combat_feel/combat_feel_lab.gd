extends Node3D
## ProjectKnight V3-026-B: Combat Feel & A/B Pipeline Comparison Lab
## Side-by-side / Sequential comparison of:
## [A] Legacy Combat (V3-025): Immediate t=0s startup damage bug, single 4-frame sheet repeated for all combo steps
## [B] Rebuilt Combat (V3-026): Frame-exact deterministic timeline, zero startup damage, authored 3D->2D combos (6f/6f/8f), localized hitpause

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const HitPauseClass = preload("res://scripts/combat/hit_pause_coordinator.gd")
const TexLegacyAttack = preload("res://assets/player_frames/attack_v1_aligned.png")

@export var auto_record_mode: bool = true
@export var record_duration_sec: float = 14.0

var player: CharacterBody3D = null
var grunt_dummy: CharacterBody3D = null
var shield_dummy: CharacterBody3D = null
var boss_dummy: CharacterBody3D = null

# HUD Elements
var hud_root: CanvasLayer = null
var title_label: Label = null
var mode_banner: Label = null
var phase_label: Label = null
var info_label: Label = null
var diff_label: Label = null
var time_scale_label: Label = null

var camera: Camera3D = null
var lab_timer: float = 0.0
var demo_step: int = 0
var demo_timer: float = 0.0

var is_legacy_mode: bool = true
var legacy_attack_step: int = 0
var legacy_attack_timer: float = 0.0


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
	shield_dummy.position = Vector3(5.0, 0.0, 0.0)
	shield_dummy.max_hp = 999
	shield_dummy.current_hp = 999
	shield_dummy.add_to_group("enemies")
	add_child(shield_dummy)

	# 4. Boss Commander Dummy
	boss_dummy = SideQVBossClass.new()
	boss_dummy.position = Vector3(9.2, 0.0, 0.0)
	boss_dummy.max_hp = 9999
	boss_dummy.current_hp = 9999
	boss_dummy.add_to_group("enemies")
	add_child(boss_dummy)


func _setup_hud() -> void:
	hud_root = CanvasLayer.new()
	add_child(hud_root)

	# Title Banner
	title_label = Label.new()
	title_label.text = "[ProjectKnight V3-026-B] Combat Animation & Feel A/B Comparison"
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.50))
	hud_root.add_child(title_label)

	# Mode Banner (Phase A vs Phase B)
	mode_banner = Label.new()
	mode_banner.text = "MODE: [A] LEGACY COMBAT (V3-025)"
	mode_banner.position = Vector2(24, 46)
	mode_banner.add_theme_font_size_override("font_size", 22)
	mode_banner.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	hud_root.add_child(mode_banner)

	# Timeline Phase Banner
	phase_label = Label.new()
	phase_label.text = "PHASE: IDLE | HITBOX: OFF | DAMAGE: 0"
	phase_label.position = Vector2(24, 76)
	phase_label.add_theme_font_size_override("font_size", 20)
	phase_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hud_root.add_child(phase_label)

	# Info Metrics Label
	info_label = Label.new()
	info_label.text = "Combo: 0 | Action: none | Elapsed: 0.00s | Frame: 0/0\nHitstop: NONE | Camera Trauma: 0.00"
	info_label.position = Vector2(24, 106)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hud_root.add_child(info_label)

	# Differentiation explanation label
	diff_label = Label.new()
	diff_label.text = "FLAW: Instant t=0s damage on button press | Reusing same 4-frame sheet for all combos"
	diff_label.position = Vector2(24, 150)
	diff_label.add_theme_font_size_override("font_size", 15)
	diff_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	hud_root.add_child(diff_label)

	# Speed readout
	time_scale_label = Label.new()
	time_scale_label.text = "Speed: 1.0x (Normal) | Auto A/B Sequence Active"
	time_scale_label.position = Vector2(24, 680)
	time_scale_label.add_theme_font_size_override("font_size", 16)
	time_scale_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hud_root.add_child(time_scale_label)


func _process(delta: float) -> void:
	_update_hud()
	_update_camera_tracking()

	if is_legacy_mode and legacy_attack_step > 0:
		_process_legacy_attack(delta)

	if auto_record_mode:
		_process_auto_demo(delta)


func _update_camera_tracking() -> void:
	if camera != null and player != null:
		var target_x := player.position.x + 1.8
		camera.position.x = lerpf(camera.position.x, target_x, 0.08)


func _trigger_legacy_attack(combo_num: int) -> void:
	legacy_attack_step = combo_num
	legacy_attack_timer = 0.0
	player.is_attacking = true
	# Set legacy texture
	if player.sprite_3d != null:
		player.sprite_3d.texture = TexLegacyAttack
		player.sprite_3d.hframes = 2
		player.sprite_3d.vframes = 2
		player.sprite_3d.frame = 0

	# BUG DEMONSTRATION: Legacy dealt damage IMMEDIATELY at t=0s on button press!
	if grunt_dummy != null and is_instance_valid(grunt_dummy):
		var dmg := 3
		grunt_dummy.current_hp = max(0, grunt_dummy.current_hp - dmg)
		AudioManager.play("enemy_hit_impact")
		GameFeelManager.damage_popup_3d(get_parent(), grunt_dummy.global_position + Vector3(0.0, 1.25, 0.0), "%d (IMMEDIATE)" % dmg, Color(1.0, 0.3, 0.3), false)


func _process_legacy_attack(delta: float) -> void:
	legacy_attack_timer += delta
	# Animate legacy 4 frames: 0.0s -> 0.08s -> 0.16s -> 0.24s -> end at 0.32s
	var frame_idx := mini(3, int(legacy_attack_timer / 0.08))
	if player.sprite_3d != null:
		player.sprite_3d.texture = TexLegacyAttack
		player.sprite_3d.hframes = 2
		player.sprite_3d.vframes = 2
		player.sprite_3d.frame = frame_idx

	if legacy_attack_timer >= 0.32:
		legacy_attack_step = 0
		player.is_attacking = false
		if player.sprite_3d != null:
			player.sprite_3d.frame = 0


func _update_hud() -> void:
	if player == null:
		return

	if is_legacy_mode:
		mode_banner.text = "MODE: [A] LEGACY COMBAT (V3-025)"
		mode_banner.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		diff_label.text = "CRITICAL FLAWS:\n* Damage dealt at t=0.00s on button press before blade moves\n* Identical 4-frame sheet (attack_v1_aligned.png) repeated for all 3 attacks\n* Global time scale freeze causes harsh stutter"
		diff_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.4))

		var cur_frame: int = player.sprite_3d.frame if player.sprite_3d else 0
		if legacy_attack_step > 0:
			phase_label.text = "PHASE: ACTIVE (LEGACY) | HITBOX: IMMEDIATE t=0 | DMG: 3"
			phase_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			info_label.text = "Combo Step: %d | Action: legacy_attack | Time: %.3fs | Frame: %d/4\nHitstop: GLOBAL_FREEZE | Target HP: %d" % [
				legacy_attack_step, legacy_attack_timer, cur_frame, grunt_dummy.current_hp if grunt_dummy else 0
			]
		else:
			phase_label.text = "PHASE: IDLE | HITBOX: OFF | DMG: 0"
			phase_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			info_label.text = "Combo Step: 0 | Action: none | Time: 0.000s | Frame: 0/4\nHitstop: NONE | Target HP: %d" % [
				grunt_dummy.current_hp if grunt_dummy else 0
			]
	else:
		mode_banner.text = "MODE: [B] REBUILT COMBAT PIPELINE (V3-026 Dead Cells / SoR4)"
		mode_banner.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		diff_label.text = "REBUILT PILLARS:\n* Deterministic Timeline: WINDUP (0 dmg) -> ACTIVE (contact sync) -> RECOVERY\n* 3 Distinct 3D->2D Actions: Combo 1 Slash (6f) | Combo 2 Rise (6f) | Combo 3 Cleave (8f)\n* Localized HitPauseCoordinator (scoped per-actor hitstop, no global freeze)"
		diff_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))

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
			cur_frame = player.sprite_3d.frame

		info_label.text = "Combo Step: %d | Action: %s | Time: %.3fs | Frame: %d/%d\nHitstop: LOCAL_SCOPED | Player HP: %d/%d" % [
			player.combo_step, act_name, elapsed, cur_frame, tot_frames, player.current_hp, player.max_hp
		]


func _process_auto_demo(delta: float) -> void:
	demo_timer += delta
	lab_timer += delta

	match demo_step:
		0:
			# Step 0: Initial overview of Legacy Mode
			is_legacy_mode = true
			if demo_timer >= 0.8:
				demo_step = 1
				demo_timer = 0.0
		1:
			# Step 1: Legacy Attack 1 (deals damage instantly at t=0)
			_trigger_legacy_attack(1)
			demo_step = 2
			demo_timer = 0.0
		2:
			# Wait for legacy attack 1 recovery
			if demo_timer >= 0.50:
				demo_step = 3
				demo_timer = 0.0
		3:
			# Step 3: Legacy Attack 2 (same 4-frame animation)
			_trigger_legacy_attack(2)
			demo_step = 4
			demo_timer = 0.0
		4:
			if demo_timer >= 0.50:
				demo_step = 5
				demo_timer = 0.0
		5:
			# Step 5: Legacy Attack 3 (same 4-frame animation again)
			_trigger_legacy_attack(3)
			demo_step = 6
			demo_timer = 0.0
		6:
			# Transition to Mode B (Rebuilt V3-026 Pipeline)
			if demo_timer >= 0.80:
				is_legacy_mode = false
				demo_step = 7
				demo_timer = 0.0
		7:
			# Move player towards Shield Knight Dummy
			player.position.x = lerpf(player.position.x, shield_dummy.position.x - 1.25, 0.10)
			if absf(player.position.x - (shield_dummy.position.x - 1.25)) < 0.1 or demo_timer >= 1.2:
				demo_step = 8
				demo_timer = 0.0
		8:
			# Rebuilt Combo 1: Horizontal Slash (6 frames, zero startup damage, contact sync)
			player.start_attack()
			demo_step = 9
			demo_timer = 0.0
		9:
			# Buffer Combo 2: Rising Slash (6 frames, distinct upward arc)
			if demo_timer >= 0.22:
				player.start_attack()
				demo_step = 10
				demo_timer = 0.0
		10:
			# Buffer Combo 3: Overhead Cleave (8 frames, heavy ground slam)
			if demo_timer >= 0.24:
				player.start_attack()
				demo_step = 11
				demo_timer = 0.0
		11:
			# Wait for combo 3 recovery and move to Boss Dummy
			if demo_timer >= 0.70:
				demo_step = 12
				demo_timer = 0.0
		12:
			# Move to Boss Dummy
			player.position.x = lerpf(player.position.x, boss_dummy.position.x - 1.5, 0.10)
			if absf(player.position.x - (boss_dummy.position.x - 1.5)) < 0.1 or demo_timer >= 1.2:
				demo_step = 13
				demo_timer = 0.0
		13:
			# Slow-motion inspection (0.25x) demonstrating frame-exact blade contact & localized hitpause
			Engine.time_scale = 0.25
			time_scale_label.text = "Speed: 0.25x (Super Slowmo) - Exact Blade Contact & Zero Startup Damage Inspection"
			player.combo_step = 0
			player.start_attack() # Combo 1 slowmo
			demo_step = 14
			demo_timer = 0.0
		14:
			# Buffer Combo 2 in slowmo
			if demo_timer >= 0.85:
				player.start_attack()
				demo_step = 15
				demo_timer = 0.0
		15:
			# Buffer Combo 3 in slowmo
			if demo_timer >= 0.90:
				player.start_attack()
				demo_step = 16
				demo_timer = 0.0
		16:
			# Restore normal speed
			if demo_timer >= 1.5:
				Engine.time_scale = 1.0
				time_scale_label.text = "Speed: 1.0x (Normal) - A/B Comparison Complete"
				demo_step = 17
				demo_timer = 0.0
		17:
			if demo_timer >= 0.8:
				print("[CombatFeelLab] A/B Comparison showcase completed successfully!")
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
			KEY_TAB:
				is_legacy_mode = not is_legacy_mode
			KEY_J:
				if is_legacy_mode:
					_trigger_legacy_attack((legacy_attack_step % 3) + 1)
				elif player != null:
					player.start_attack()
			KEY_K:
				if player != null:
					player.start_dash()
