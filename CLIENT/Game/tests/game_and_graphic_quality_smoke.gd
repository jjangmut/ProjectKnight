extends SceneTree
## Autonomous verification suite for Game and Graphic Quality Upgrades.

var checks_passed := 0
var checks_failed := 0

const SaveManager = preload("res://scripts/system/save_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")
const SwordBeamScene = preload("res://scripts/player/sword_beam.gd")
const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")
const BeastChieftainClass = preload("res://scripts/enemy/beast_chieftain.gd")
const CrossbowCommanderClass = preload("res://scripts/enemy/crossbow_commander.gd")
const AncientGolemGuardianClass = preload("res://scripts/enemy/ancient_golem_guardian.gd")
const AbyssalArbiterClass = preload("res://scripts/enemy/abyssal_arbiter.gd")

func _initialize() -> void:
	_run_suite.call_deferred()

func _check(condition: bool, description: String) -> void:
	if condition:
		checks_passed += 1
		print("PASS: %s" % description)
	else:
		checks_failed += 1
		push_error("FAIL: %s" % description)
		print("FAIL: %s" % description)

func _run_suite() -> void:
	print("\n--- START GAME & GRAPHIC QUALITY POLISH VERIFICATION SUITE ---")

	# =========================================================================
	# [Check 1: WorldEnvironment 2D HDR Glow & Atmospheric Ambiance]
	# =========================================================================
	print("\n[Check 1: WorldEnvironment 2D HDR Glow, CanvasModulate & Atmospheric Motes]")
	var stage_scene = load("res://scenes/stage/FirstStage.tscn")
	var stage: Node2D = stage_scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	var stage_art: Node2D = stage.get_node_or_null("StageArt")
	_check(stage_art != null, "StageArt node instantiated in FirstStage")

	var world_env: WorldEnvironment = stage_art.get_node_or_null("StageWorldEnvironment")
	_check(world_env != null, "StageWorldEnvironment node exists under StageArt")
	if world_env != null:
		var env: Environment = world_env.environment
		_check(env != null and env.glow_enabled, "Environment glow is actively enabled")
		_check(env.glow_blend_mode == Environment.GLOW_BLEND_MODE_SCREEN, "Environment glow blend mode is SCREEN")
		_check(env.glow_hdr_threshold <= 1.0, "HDR glow threshold calibrated for luminous bloom")

	var canvas_mod: CanvasModulate = stage_art.get_node_or_null("StageCanvasModulate")
	_check(canvas_mod != null, "StageCanvasModulate node exists for thematic ambiance")

	var motes: CPUParticles2D = stage_art.get_node_or_null("AtmosphericMotes")
	_check(motes != null and motes.amount >= 20, "Atmospheric floating motes active with sufficient density")

	stage.queue_free()
	await process_frame

	# =========================================================================
	# [Check 2: Relic In-Game Passive Buff Integration]
	# =========================================================================
	print("\n[Check 2: Relic In-Game Passive Buffs Integration]")
	SaveManager.clear_save()
	var player_scene = load("res://scenes/player/Player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	player.position = Vector2(200, 580)
	await process_frame

	# Default baseline without relics
	_check(player.relic_shield_active == false, "Baseline: Shield relic inactive on fresh save")
	_check(player.relic_cloak_active == false, "Baseline: Cloak relic inactive on fresh save")
	_check(player.guard_recovery >= 0.11, "Baseline: Normal guard recovery duration (0.12s)")
	_check(player.dash_cooldown >= 0.55, "Baseline: Normal dash cooldown (0.60s)")
	_check(player.dash_speed <= 550.0, "Baseline: Normal dash speed (540 px/s)")

	# Stage 1 Relic: Bastion Shield (+knockback resistance & -25% recovery)
	SaveManager.mark_stage_cleared(1)
	player.refresh_relic_buffs()
	_check(player.relic_shield_active == true, "Stage 1 Relic (Bastion Shield) activated")
	_check(player.guard_recovery <= 0.10, "Bastion Shield: Guard recovery reduced to 0.09s")

	# Stage 2 Relic: Shadow Cloak (-25% dash cooldown & +15% dash speed)
	SaveManager.mark_stage_cleared(2)
	player.refresh_relic_buffs()
	_check(player.relic_cloak_active == true, "Stage 2 Relic (Shadow Cloak) activated")
	_check(player.dash_cooldown <= 0.50, "Shadow Cloak: Dash cooldown reduced to 0.45s")
	_check(player.dash_speed >= 600.0, "Shadow Cloak: Dash speed boosted to 620 px/s")

	# Stage 3 Relic: Piercing Quiver (+100px sword beam range & +1 pierce)
	SaveManager.mark_stage_cleared(3)
	player.refresh_relic_buffs()
	_check(player.relic_quiver_active == true, "Stage 3 Relic (Wind Quiver) activated")

	# Stage 4 Relic: Titan Pauldrons (down thrust shockwave debris)
	SaveManager.mark_stage_cleared(4)
	player.refresh_relic_buffs()
	_check(player.relic_pauldrons_active == true, "Stage 4 Relic (Titan Pauldrons) activated")

	# Stage 5 Relic: Abyssal Crown (perfect parry counter crit deals 4 damage!)
	SaveManager.mark_stage_cleared(5)
	player.refresh_relic_buffs()
	_check(player.relic_crown_active == true, "Stage 5 Relic (Abyssal Crown) activated")

	# Test Crown 4-Crit Damage
	player.is_perfect_parry = true
	player._start_counter_attack()
	_check(player.current_attack_damage == 4, "Abyssal Crown: Perfect Parry Counter delivers 4 CRIT damage")

	# [Check 3: Responsive Air-to-Ground Attack Input Buffering]
	print("\n[Check 3: Responsive Air-to-Ground Attack Input Buffering]")
	player._end_attack()
	player._cooldown_time_remaining = 0.0

	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcol := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(1000.0, 40.0)
	fcol.shape = frect
	floor_body.position = Vector2(200.0, 600.0)
	floor_body.add_child(fcol)
	root.add_child(floor_body)

	player.position = Vector2(200.0, 400.0) # in air
	player.velocity.y = 200.0
	player._attack_buffer_remaining = 0.14
	player._physics_process(0.016)
	_check(player._attack_buffer_remaining > 0.0, "Attack buffer maintained during descent")

	# Settle onto floor
	player.position = Vector2(200.0, 570.0)
	player.velocity = Vector2(0, 100.0)
	player.move_and_slide()
	_check(player.is_on_floor(), "Player grounded on test floor")

	player._end_attack()
	player._cooldown_time_remaining = 0.0
	player._attack_buffer_remaining = 0.10
	player._physics_process(0.016)
	_check(player.is_attacking == true, "Buffered attack immediately unleashed upon landing")

	floor_body.queue_free()
	player.queue_free()
	await process_frame

	# =========================================================================
	# [Check 4: Sword Beam Terrain Impact & HDR Bloom]
	# =========================================================================
	print("\n[Check 4: Sword Beam Terrain Impact & HDR Bloom]")
	var beam = SwordBeamScene.new()
	root.add_child(beam)
	beam.position = Vector2(300, 300)
	await process_frame

	_check((beam.collision_mask & 1) != 0, "SwordBeam collides with Layer 1 (Terrain/Walls)")
	_check(beam._blade_arc != null and beam._blade_arc.default_color.r > 1.2, "SwordBeam blade arc utilizes HDR overdrive color (> 1.2)")
	_check(beam._core_arc != null and beam._core_arc.default_color.r > 1.5, "SwordBeam core arc utilizes blinding white HDR color (> 1.5)")

	# Simulate wall hit
	var test_wall = StaticBody2D.new()
	test_wall.add_to_group("stage_terrain")
	beam._on_body_entered(test_wall)
	_check(beam.is_physics_processing() == false, "SwordBeam immediately halts physics and triggers fade on wall collision")

	beam.queue_free()
	test_wall.queue_free()
	await process_frame

	# =========================================================================
	# [Check 5: All 5 Boss Visual Rim Aura & Polish Parity]
	# =========================================================================
	print("\n[Check 5: All 5 Boss Visual Rim Aura & Polish Parity]")
	var b1 = BossCommanderClass.new()
	root.add_child(b1)
	_check(b1.aura_poly != null and b1.aura_poly.visible, "Boss 1 (Commander): Champion Rim Aura is visible")
	b1.queue_free()

	var b2 = BeastChieftainClass.new()
	root.add_child(b2)
	_check(b2.aura_poly != null and b2.aura_poly.visible, "Boss 2 (Beast Chieftain): Predator Champion Rim Aura is visible")
	b2.queue_free()

	var b3 = CrossbowCommanderClass.new()
	root.add_child(b3)
	_check(b3.aura_poly != null and b3.aura_poly.visible, "Boss 3 (Crossbow Commander): Ruins Champion Rim Aura is visible")
	_check(b3.laser_line != null and b3.laser_line.default_color.r > 1.5, "Boss 3: Sniper aiming laser has HDR intensity (> 1.5)")
	b3.queue_free()

	var b4 = AncientGolemGuardianClass.new()
	root.add_child(b4)
	_check(b4.aura_poly != null and b4.aura_poly.visible, "Boss 4 (Golem Guardian): Titan Magma Rim Aura is visible")
	_check(b4.core_poly != null and b4.core_poly.visible, "Boss 4: Radiant Magma Rune Core is visibly glowing in chest")
	b4.queue_free()

	var b5 = AbyssalArbiterClass.new()
	root.add_child(b5)
	_check(b5.aura_poly != null and b5.aura_poly.visible, "Boss 5 (Abyssal Arbiter): Climax Champion Rim Aura is visible")
	_check(b5.wing_left != null and b5.wing_left.get_child_count() > 0, "Boss 5: Wings equipped with radiant violet neon edge Line2D")
	b5.queue_free()

	# =========================================================================
	# [Check 6: Player Crescent Arc Geometry & Dash Ghost Neon Edge]
	# =========================================================================
	print("\n[Check 6: Player Crescent Arc Geometry & Dash Ghost Neon Edge]")
	var p2 = player_scene.instantiate()
	root.add_child(p2)
	p2.position = Vector2(250, 580)
	await process_frame

	# Check Combo 1 Crescent Arc
	p2.combo_step = 1
	p2.is_counter_attacking = false
	p2.is_air_attacking = false
	p2.is_down_thrusting = false
	p2._update_attack_geometry()
	_check(p2.attack_visual.polygon.size() >= 12, "Combo 1: Attack visual uses smooth crescent arc polygon (>= 12 vertices)")

	# Check Combo 2 Crescent Arc
	p2.combo_step = 2
	p2._update_attack_geometry()
	_check(p2.attack_visual.polygon.size() >= 12, "Combo 2: Rising attack visual uses crescent arc polygon (>= 12 vertices)")

	# Check Combo 3 Heavy Wave Crescent Arc
	p2.combo_step = 3
	p2._update_attack_geometry()
	_check(p2.attack_visual.polygon.size() >= 16, "Combo 3: Heavy finish uses wide crescent wave polygon (>= 16 vertices)")

	# Check Air Spin Wheel Arc
	p2.is_air_attacking = true
	p2._update_attack_geometry()
	_check(p2.attack_visual.polygon.size() >= 16, "Air Attack: Uses circular whirlwind blade polygon (>= 16 vertices)")
	p2.is_air_attacking = false

	# Check Down Thrust Spike
	p2.is_down_thrusting = true
	p2._update_attack_geometry()
	_check(p2.attack_visual.polygon.size() == 6, "Down Thrust: Uses piercing directional spike polygon (6 vertices)")
	p2.is_down_thrusting = false

	# Check Ghost Trail with Neon Contour
	var initial_children := root.get_child_count()
	p2._spawn_ghost_trail()
	await process_frame
	var new_children := root.get_child_count()
	_check(new_children > initial_children, "Dash Ghost Trail: Spawned ghost polygon node in parent")
	var ghost_node := root.get_child(root.get_child_count() - 1) as Polygon2D
	if ghost_node != null:
		var has_line := false
		for c in ghost_node.get_children():
			if c is Line2D:
				has_line = true
				break
		_check(has_line, "Dash Ghost Trail: Equipped with glowing neon silhouette Line2D")

	p2.queue_free()
	await process_frame

	# =========================================================================
	# [Check 7: GameFeelManager HDR Overdrive Sparks & Critical Shockwave Ring]
	# =========================================================================
	print("\n[Check 7: GameFeelManager HDR Overdrive Sparks & Critical Shockwave Ring]")
	var gfm = GameFeelManager.ensure_manager(self)
	var spark_holder := Node2D.new()
	root.add_child(spark_holder)
	gfm.spawn_slash_spark(spark_holder, Vector2(300, 300), 1.0, true)
	await process_frame

	_check(spark_holder.get_child_count() > 0, "Slash spark root effect node spawned")
	if spark_holder.get_child_count() > 0:
		var fx_root := spark_holder.get_child(0)
		var line_count := 0
		var has_hdr := false
		for c in fx_root.get_children():
			if c is Line2D:
				line_count += 1
				if c.default_color.r > 1.2 or c.default_color.g > 1.2 or c.default_color.b > 1.2:
					has_hdr = true
		_check(line_count >= 3, "Critical hit effect spawns at least 3 Line2D elements (beam, cross, shockwave ring)")
		_check(has_hdr, "Slash spark lines utilize intense HDR Overdrive bloom colors")

	spark_holder.queue_free()
	SaveManager.clear_save()
	await process_frame

	print("\n--- SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks_passed, checks_failed])
	if checks_failed == 0:
		print("TEST RESULT: ALL GAME & GRAPHIC QUALITY CHECKS PASSED (100%)\n")
		quit(0)
	else:
		push_error("TEST RESULT: SOME CHECKS FAILED")
		quit(1)
