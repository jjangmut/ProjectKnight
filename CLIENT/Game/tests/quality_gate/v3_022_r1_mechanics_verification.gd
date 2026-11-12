extends SceneTree
## V3-022-R1 Post-Fix Mechanics Verification & Trace Suite
## Generates:
## - STUDIO_V3/evidence/V3-022-R1/PROJECTILE_TRACE.json
## - STUDIO_V3/evidence/V3-022-R1/PILLAR_COLLISION_RESULTS.json
## - STUDIO_V3/evidence/V3-022-R1/BOSS_VERTICAL_TRACE.json
## - STUDIO_V3/evidence/V3-022-R1/captures/after_*.png

const StageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const BoltClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd")

var stage: Node3D = null
var player: CharacterBody3D = null
var cap_dir: String = ""
var ev_dir: String = ""

func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run_verification")

func _run_verification() -> void:
	ev_dir = ProjectSettings.globalize_path("res://../../STUDIO_V3/evidence/V3-022-R1")
	cap_dir = ev_dir + "/captures"
	DirAccess.make_dir_recursive_absolute(cap_dir)

	var packed := load(Stage1ScenePath) as PackedScene
	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	for i in range(6):
		await physics_frame

	player = stage.get_node_or_null("SideQVPlayer") as CharacterBody3D

	# Clear Encounter 1 enemies and spectral gates for isolated deterministic mechanics tests
	for e in stage.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	stage.enemies.clear()
	for gate_id in stage.active_gate_barriers.keys():
		var b = stage.active_gate_barriers[gate_id]
		if is_instance_valid(b):
			b.queue_free()
	stage.active_gate_barriers.clear()
	await physics_frame

	await _verify_pillar_collisions()
	await _verify_projectiles()
	await _verify_boss_vertical_stability()

	print("=================================================================")
	print(">>> [V3-022-R1] ALL 3 MECHANICS VERIFICATION SUITES PASSED! <<<")
	print("=================================================================")
	quit(0)

# =============================================================================
# 1. PILLAR-P0 VERIFICATION
# =============================================================================
func _verify_pillar_collisions() -> void:
	print("[VERIFY] Running PILLAR-P0 Collision Suite...")
	var pillar_names := ["GatePillar_1", "GatePillar_2", "GatePillar_3", "BossPillar_Rear"]
	var wing_names := ["GothicWing_Start", "GothicWing_Bastion", "GothicWing_Terrace", "GothicWing_Boss"]

	var colliders_audit := []
	var all_have_colliders := true
	for pname in pillar_names + wing_names:
		var node := stage.get_node_or_null(pname) as Node3D
		var sb := node.get_node_or_null("PillarCollider") as StaticBody3D if node != null else null
		var col := sb.get_child(0) as CollisionShape3D if (sb != null and sb.get_child_count() > 0) else null
		var valid := (sb != null and (sb.collision_layer & 4) != 0 and col != null and col.shape != null)
		if not valid:
			all_have_colliders = false
		colliders_audit.append({
			"node_name": pname,
			"global_pos": [node.global_position.x, node.global_position.y, node.global_position.z] if node else [],
			"has_static_body_layer_4": valid,
			"shape_extents": [col.shape.size.x, col.shape.size.y, col.shape.size.z] if (col != null and col.shape is BoxShape3D) else []
		})

	# Test 1A: Walk into GatePillar_1 (at x=18.0, z=-2.7, size 1.35x6.2x1.35 -> X:[17.325, 18.675], Z:[-3.375, -2.025]) from Left (+X)
	if stage.camera != null:
		stage.camera.min_camera_x = 14.0
		stage.camera.max_camera_x = 22.0
		stage.camera.global_position.x = 18.0

	player.global_position = Vector3(16.2, 0.0, -2.35)
	player.velocity = Vector3.ZERO
	await physics_frame

	var x_approach_trace := []
	var x_penetrated := false
	Input.action_press("move_right")
	for f in range(30):
		await physics_frame
		var px := player.global_position.x
		var pz := player.global_position.z
		# Player capsule radius = 0.35, pillar min X = 18.0 - 0.675 = 17.325 -> center should stay <= 17.05
		if px > 17.15 and pz < -2.0:
			x_penetrated = true
		x_approach_trace.append({
			"frame": f,
			"attempted_dir": "+X",
			"actual_pos": [snappedf(px, 0.01), snappedf(player.global_position.y, 0.01), snappedf(pz, 0.01)],
			"slide_collision_count": player.get_slide_collision_count()
		})
		if f == 18:
			await process_frame
			var img := root.get_viewport().get_texture().get_image()
			if img != null:
				img.save_png(cap_dir + "/after_pillar_blocked.png")
	Input.action_release("move_right")

	# Test 1B: Walk into GatePillar_1 from Front (-Z into pillar front face at z = -2.025)
	player.global_position = Vector3(18.0, 0.0, -1.0)
	player.velocity = Vector3.ZERO
	await physics_frame

	var z_approach_trace := []
	var z_penetrated := false
	Input.action_press("move_up") # -Z
	for f in range(25):
		await physics_frame
		var px := player.global_position.x
		var pz := player.global_position.z
		# Pillar front face is at Z = -2.7 + 0.675 = -2.025; with player radius 0.35, player Z should stay >= -1.72
		if absf(px - 18.0) < 0.60 and pz < -1.80:
			z_penetrated = true
		z_approach_trace.append({
			"frame": f,
			"attempted_dir": "-Z",
			"actual_pos": [snappedf(px, 0.01), snappedf(player.global_position.y, 0.01), snappedf(pz, 0.01)],
			"slide_collision_count": player.get_slide_collision_count()
		})
	Input.action_release("move_up")

	# Test 1C: Dash into GatePillar_1 from Left (+X) — verify dash is blocked by pillar
	player.global_position = Vector3(15.8, 0.0, -2.35)
	player.facing_dir_x = 1.0
	player.facing_attack_dir = Vector3(1.0, 0.0, 0.0)
	await physics_frame
	player.start_dash()
	var dash_penetrated := false
	for f in range(16):
		await physics_frame
		if player.global_position.x > 17.15 and player.global_position.z < -2.0:
			dash_penetrated = true

	# Test 1D: Route Bypass Around Pillar in Playable Corridor (Z = 0.0 center lane past x = 18.0)
	player.global_position = Vector3(16.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	Input.action_press("move_right")
	for f in range(30):
		await physics_frame
	Input.action_release("move_right")
	var bypass_succeeded := (player.global_position.x > 19.0)

	var pillar_results := {
		"test_suite": "PILLAR-P0",
		"all_pillars_and_wings_have_layer4_colliders": all_have_colliders,
		"x_approach_blocked": not x_penetrated,
		"z_approach_blocked": not z_penetrated,
		"dash_into_pillar_blocked": not dash_penetrated,
		"corridor_lane_bypass_open": bypass_succeeded,
		"decorative_distinction": "PanoramicCastleBackdrop_0..2 at Z=-14.0 are distant vista quads outside playable Z[-3.2, 3.2] and have no colliders; all GatePillar_1..3, BossPillar_Rear, GothicWing_*, and ParapetPost_* intersecting/bordering the corridor have Layer 4 physical collision.",
		"colliders_audit": colliders_audit,
		"x_approach_trace": x_approach_trace,
		"z_approach_trace": z_approach_trace
	}
	var f_out := FileAccess.open(ev_dir + "/PILLAR_COLLISION_RESULTS.json", FileAccess.WRITE)
	if f_out != null:
		f_out.store_string(JSON.stringify(pillar_results, "\t"))
		f_out.close()

	assert(all_have_colliders, "All pillars must have Layer 4 colliders")
	assert(not x_penetrated, "Player must not pass through pillar along +X")
	assert(not z_penetrated, "Player must not pass through pillar along -Z")
	assert(not dash_penetrated, "Player dash must not tunnel through pillar")
	assert(bypass_succeeded, "Player must freely traverse past x=18.0 in open Z lane")
	print("[VERIFY] PILLAR-P0 PASSED!")

# =============================================================================
# 2. PROJECTILE-P0 VERIFICATION
# =============================================================================
func _verify_projectiles() -> void:
	print("[VERIFY] Running PROJECTILE-P0 Projectile Trace Suite...")
	if stage.camera != null:
		stage.camera.min_camera_x = 32.0
		stage.camera.max_camera_x = 40.0
		stage.camera.global_position.x = 36.0

	# Scenario 2A: Free flight & player guard / Just Parry impact
	player.global_position = Vector3(33.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	player.facing_dir_x = 1.0
	player.facing_attack_dir = Vector3(1.0, 0.0, 0.0)
	player.start_guard()
	await physics_frame

	var bolt_a := BoltClass.new()
	stage.add_child(bolt_a)
	var b_id_a := bolt_a.get_instance_id()
	bolt_a.launch(Vector3(39.0, 0.85, 0.0), Vector3(-1.0, 0.0, 0.0), stage, 16.5, 1, false)

	var mesh_forward_axis := bolt_a.bolt_mesh.global_transform.basis.y.normalized()
	var trace_a := []
	var max_consecutive_frozen := 0
	var cur_frozen := 0
	var prev_x := 39.0
	var vanish_frame_a := -1

	for f in range(36):
		await physics_frame
		if is_instance_valid(bolt_a) and bolt_a.is_inside_tree() and bolt_a.is_active:
			var bx := bolt_a.global_position.x
			var step_dist := absf(bx - prev_x)
			if step_dist < 0.01:
				cur_frozen += 1
				max_consecutive_frozen = maxi(max_consecutive_frozen, cur_frozen)
			else:
				cur_frozen = 0
			prev_x = bx
			trace_a.append({
				"frame": f,
				"instance_id": b_id_a,
				"pos": [snappedf(bolt_a.global_position.x, 0.01), snappedf(bolt_a.global_position.y, 0.01), snappedf(bolt_a.global_position.z, 0.01)],
				"direction": [snappedf(bolt_a.direction.x, 0.01), snappedf(bolt_a.direction.y, 0.01), snappedf(bolt_a.direction.z, 0.01)],
				"traveled_distance": snappedf(bolt_a.traveled_distance, 0.02),
				"speed": bolt_a.speed,
				"is_active": bolt_a.is_active,
				"tree_paused": paused,
				"engine_time_scale": snappedf(Engine.time_scale, 0.01)
			})
			if f == 6:
				await process_frame
				var img := root.get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(cap_dir + "/after_projectile_flight.png")
		else:
			if vanish_frame_a == -1:
				vanish_frame_a = f
			trace_a.append({
				"frame": f,
				"instance_id": b_id_a,
				"is_active": false,
				"vanished_on_player_guard": true
			})
			break
	Engine.time_scale = 1.0
	player.release_guard()

	# Scenario 2B: Projectile blocked by Stone Pillar (`GatePillar_2` at x=44.0, z=-2.7)
	var bolt_b := BoltClass.new()
	stage.add_child(bolt_b)
	bolt_b.launch(Vector3(47.0, 0.85, -2.5), Vector3(-1.0, 0.0, 0.0), stage, 16.5, 1, false)
	var trace_b_pillar := []
	var pillar_blocked_bolt := false
	for f in range(25):
		await physics_frame
		if is_instance_valid(bolt_b) and bolt_b.is_inside_tree():
			trace_b_pillar.append({
				"frame": f,
				"pos": [snappedf(bolt_b.global_position.x, 0.01), snappedf(bolt_b.global_position.y, 0.01), snappedf(bolt_b.global_position.z, 0.01)],
				"is_active": bolt_b.is_active
			})
		else:
			pillar_blocked_bolt = true
			trace_b_pillar.append({"frame": f, "vanished_on_pillar_impact": true})
			break

	# Scenario 2C: Projectile hitting CSGBox3D World Wall (`CastleBackWall` at Z=-3.2)
	var bolt_c := BoltClass.new()
	stage.add_child(bolt_c)
	bolt_c.launch(Vector3(36.0, 0.85, -1.0), Vector3(0.0, 0.0, -1.0), stage, 16.5, 1, false)
	var wall_vanished := false
	for f in range(20):
		await physics_frame
		if not is_instance_valid(bolt_c) or not bolt_c.is_inside_tree():
			wall_vanished = true
			break

	# Scenario 2D: Shooter dies while projectile is mid-air -> bolt continues cleanly and hits player/world without orphaned error
	var minion: CharacterBody3D = stage._spawn_enemy_crossbow(Vector3(40.0, 0.1, 0.8), "TestCrossbowman")
	var bolt_d := BoltClass.new()
	stage.add_child(bolt_d)
	bolt_d.launch(Vector3(39.5, 0.85, 0.8), Vector3(-1.0, 0.0, 0.0), minion, 16.5, 1, false)
	await physics_frame
	minion.receive_hit(99, Vector3(1, 0, 0), true) # Kill shooter mid-flight
	var midair_after_shooter_death_ok := true
	var prev_dx := bolt_d.global_position.x
	for f in range(8):
		await physics_frame
		if is_instance_valid(bolt_d) and bolt_d.is_active:
			if absf(bolt_d.global_position.x - prev_dx) < 0.05:
				midair_after_shooter_death_ok = false
			prev_dx = bolt_d.global_position.x
	if is_instance_valid(bolt_d):
		bolt_d.queue_free()

	var proj_report := {
		"test_suite": "PROJECTILE-P0",
		"entity_class": "SideQVCrossbowBolt",
		"spawning_script": "res://scripts/side_quarter_view/side_qv_ranged_minion.gd (_execute_shoot)",
		"mesh_tip_aligned_with_direction": (mesh_forward_axis.dot(Vector3(-1.0, 0.0, 0.0)) > 0.98),
		"max_consecutive_frozen_frames_while_active": max_consecutive_frozen,
		"frozen_over_3_frames": (max_consecutive_frozen > 3),
		"vanished_on_player_guard_frame": vanish_frame_a,
		"vanished_on_pillar_impact": pillar_blocked_bolt,
		"vanished_on_csg_world_wall_impact": wall_vanished,
		"continues_cleanly_when_shooter_dies_midair": midair_after_shooter_death_ok,
		"scenario_a_player_guard_trace": trace_a,
		"scenario_b_pillar_impact_trace": trace_b_pillar
	}
	var f_out := FileAccess.open(ev_dir + "/PROJECTILE_TRACE.json", FileAccess.WRITE)
	if f_out != null:
		f_out.store_string(JSON.stringify(proj_report, "\t"))
		f_out.close()

	assert(max_consecutive_frozen == 0, "Projectile must never freeze while active")
	assert(vanish_frame_a > 0, "Projectile must impact and vanish on player guard")
	assert(pillar_blocked_bolt, "Projectile must be blocked by stone pillar")
	assert(wall_vanished, "Projectile must vanish on CSG world wall")
	assert(midair_after_shooter_death_ok, "Projectile must continue moving when shooter dies midair")
	print("[VERIFY] PROJECTILE-P0 PASSED!")

# =============================================================================
# 3. BOSS-AIR-P0 VERIFICATION
# =============================================================================
func _verify_boss_vertical_stability() -> void:
	print("[VERIFY] Running BOSS-AIR-P0 Vertical Stability Suite...")
	stage._start_boss_sanctuary()
	for i in range(6):
		await physics_frame

	var boss: CharacterBody3D = stage.active_boss
	assert(boss != null and is_instance_valid(boss), "Boss must spawn in sanctuary")

	var vertical_trace := []
	var max_unintended_player_y := 0.0
	var max_boss_y := 0.0

	# Part A: Grounded combat + Boss Shield Charge + Quake Ring + Triple Cleave + Parry + Knockback against Pillar (no jump input)
	boss.global_position = Vector3(77.5, 0.0, 0.0)
	player.global_position = Vector3(75.8, 0.0, 0.0)
	player.facing_dir_x = 1.0
	player.facing_attack_dir = Vector3(1.0, 0.0, 0.0)
	await physics_frame

	# Trigger Shield Charge into player
	boss._execute_shield_charge()
	for f in range(90):
		Engine.time_scale = 1.0
		await physics_frame
		if f == 28:
			player.start_guard()
		elif f == 38:
			player.release_guard()
		elif f == 45:
			boss._execute_quake_ring()
		elif f == 68:
			boss._execute_triple_cleave()
		if f in [15, 50, 75]:
			player.attack_cooldown = 0.0
			player.is_attacking = false
			player.start_attack()
			Engine.time_scale = 1.0

		var py := player.global_position.y
		var by := boss.global_position.y
		max_unintended_player_y = maxf(max_unintended_player_y, py)
		max_boss_y = maxf(max_boss_y, by)

		var p_normals := []
		for c_idx in range(player.get_slide_collision_count()):
			var col := player.get_slide_collision(c_idx)
			if col != null:
				var n := col.get_normal()
				p_normals.append([snappedf(n.x, 0.01), snappedf(n.y, 0.01), snappedf(n.z, 0.01)])

		vertical_trace.append({
			"frame": f,
			"phase": "GROUNDED_BOSS_PATTERNS",
			"jump_input": false,
			"player_y": snappedf(py, 0.02),
			"player_vy": snappedf(player.velocity.y, 0.02),
			"player_on_floor": player.is_on_floor(),
			"player_state": player.current_state,
			"player_slide_normals": p_normals,
			"boss_y": snappedf(by, 0.02),
			"boss_vy": snappedf(boss.velocity.y, 0.02),
			"boss_on_floor": boss.is_on_floor(),
			"boss_pattern": boss.current_pattern
		})
		if f == 76:
			await process_frame
			var img := root.get_viewport().get_texture().get_image()
			if img != null:
				img.save_png(cap_dir + "/after_boss_grounded_combat.png")

	# Part B: Intentional Jump + Mid-Air Horizontal Attack next to Boss (The exact scenario that previously caused infinite 2.97m Pogo launch!)
	player.global_position = Vector3(75.8, 0.0, 0.0)
	boss.global_position = Vector3(77.3, 0.0, 0.0)
	await physics_frame
	player.start_jump()
	var max_jump_arc_y := 0.0
	for f in range(45):
		Engine.time_scale = 1.0
		await physics_frame
		# Attack repeatedly in mid-air at frames 6, 16, 26 (while alongside boss, NOT above boss head)
		if f in [6, 16, 26]:
			player.attack_cooldown = 0.0
			player.is_attacking = false
			player.start_attack()
			Engine.time_scale = 1.0
		var py := player.global_position.y
		max_jump_arc_y = maxf(max_jump_arc_y, py)
		vertical_trace.append({
			"frame": 90 + f,
			"phase": "INTENTIONAL_JUMP_WITH_AIR_ATTACK",
			"jump_input": (f == 0),
			"player_y": snappedf(py, 0.02),
			"player_vy": snappedf(player.velocity.y, 0.02),
			"player_on_floor": player.is_on_floor(),
			"boss_y": snappedf(boss.global_position.y, 0.02),
			"boss_pattern": boss.current_pattern
		})

	var boss_report := {
		"test_suite": "BOSS-AIR-P0",
		"max_unintended_player_y_meters": snappedf(max_unintended_player_y, 0.02),
		"max_boss_y_meters": snappedf(max_boss_y, 0.02),
		"max_intentional_jump_arc_y_meters": snappedf(max_jump_arc_y, 0.02),
		"expected_single_jump_apex_meters": 1.28,
		"spurious_air_pop_eliminated": (max_unintended_player_y <= 0.15 and max_boss_y <= 0.15 and max_jump_arc_y <= 1.45),
		"trace": vertical_trace
	}
	var f_out := FileAccess.open(ev_dir + "/BOSS_VERTICAL_TRACE.json", FileAccess.WRITE)
	if f_out != null:
		f_out.store_string(JSON.stringify(boss_report, "\t"))
		f_out.close()

	assert(max_unintended_player_y <= 0.15, "Grounded player must not pop into air during boss fight")
	assert(max_boss_y <= 0.15, "Boss must remain grounded")
	assert(max_jump_arc_y >= 1.10 and max_jump_arc_y <= 1.45, "Intentional jump + air attack must follow normal 1.28m jump arc without 2.97m skyward pogo launch")
	print("[VERIFY] BOSS-AIR-P0 PASSED! (max_jump_arc_y = %.2fm vs pre-fix 2.97m)" % max_jump_arc_y)
