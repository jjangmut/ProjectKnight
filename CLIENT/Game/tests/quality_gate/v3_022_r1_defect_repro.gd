extends SceneTree
## V3-022-R1 Pre-Fix Defect Reproduction Harness
## Reproduces and captures BEFORE evidence for:
## 1. PROJECTILE-P0: Ranged minion ("wizard") projectile (`SideQVCrossbowBolt`) orienting its cylinder backwards (+Z instead of -Z) AND freezing in mid-air when hitting a CSGBox3D world collider (`CastleBackWall` / `CorridorFloor` / `FrontBalustrade` on World Layer 4) OR when `GameFeelManager.hit_stop_3d` leaves `Engine.time_scale = 0.04` stuck during headless/no-process frames.
## 2. PILLAR-P0: Player walking straight through visible stone pillars (`GatePillar_1` at x=18.0, `GatePillar_2` at x=44.0, `GatePillar_3` at x=68.0, `BossPillar_Rear` at x=76.0) once the spectral gate dissolves because `_build_pillar` lacks collision.
## 3. BOSS-AIR-P0: Player repeatedly launching to Y > 2.2m above the boss during `TRIPLE_CLEAVE` due to AI jumping + chaining `_execute_pogo_bounce()` on horizontal melee attacks while airborne.

const StageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var player: CharacterBody3D = null
var repro_report := {
	"git_commit_before": "78f7bd767d4fed0f3312614f78c1496738ee897b",
	"projectile_p0_before": {},
	"pillar_p0_before": {},
	"boss_air_p0_before": {}
}

func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run_reproduction")

func _run_reproduction() -> void:
	var packed := load(Stage1ScenePath) as PackedScene
	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	for i in range(5):
		await physics_frame

	player = stage.get_node_or_null("SideQVPlayer") as CharacterBody3D

	var cap_dir := "res://../../STUDIO_V3/evidence/V3-022-R1/captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cap_dir))

	# Remove Encounter 1 enemies and dissolve gate barriers so we test the actual stone pillars cleanly
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

	# -------------------------------------------------------------------------
	# 1. REPRODUCE PILLAR-P0 (Walk straight into GatePillar_1 at x=18.0, z=-2.7)
	# -------------------------------------------------------------------------
	print("[REPRO] Testing PILLAR-P0 (Before Fix)...")
	var pillar1 := stage.get_node_or_null("GatePillar_1") as Node3D
	var pillar_pos := pillar1.global_position if pillar1 != null else Vector3(18.0, 0.0, -2.7)
	if stage.camera != null:
		stage.camera.min_camera_x = 14.0
		stage.camera.max_camera_x = 22.0
		stage.camera.global_position.x = 18.0

	# Place player just to the left of GatePillar_1 at x=16.5, z=-2.3 and press move_right (+X) into the pillar
	player.global_position = Vector3(16.5, 0.0, -2.3)
	player.velocity = Vector3.ZERO
	Input.action_press("move_right")

	var pillar_trace := []
	var passed_through := false
	var captured_pillar := false
	for f in range(30):
		await physics_frame
		var px := player.global_position.x
		var pz := player.global_position.z
		var inside_pillar_x := absf(px - pillar_pos.x) < 0.65
		var inside_pillar_z := absf(pz - pillar_pos.z) < 0.65
		if inside_pillar_x and inside_pillar_z:
			passed_through = true
			if not captured_pillar and absf(px - pillar_pos.x) < 0.35:
				captured_pillar = true
				await RenderingServer.frame_post_draw
				var img := root.get_viewport().get_texture().get_image()
				img.save_png(ProjectSettings.globalize_path(cap_dir + "/before_pillar_pass_through.png"))
		pillar_trace.append({
			"frame": f,
			"player_pos": [snappedf(px, 0.01), snappedf(player.global_position.y, 0.01), snappedf(pz, 0.01)],
			"inside_pillar_volume": inside_pillar_x and inside_pillar_z
		})
	Input.action_release("move_right")

	repro_report["pillar_p0_before"] = {
		"pillar_name": "GatePillar_1",
		"pillar_pos": [pillar_pos.x, pillar_pos.y, pillar_pos.z],
		"pillar_has_static_body": pillar1.get_node_or_null("StaticBody3D") != null if pillar1 else false,
		"player_passed_through_pillar": passed_through,
		"trace_sample": pillar_trace.slice(0, 18)
	}
	print("[REPRO] PILLAR-P0 passed_through = ", passed_through)

	# -------------------------------------------------------------------------
	# 2. REPRODUCE PROJECTILE-P0 (Bolt orientation & raycast against world / hit-stop)
	# -------------------------------------------------------------------------
	print("[REPRO] Testing PROJECTILE-P0 (Before Fix)...")
	if stage.camera != null:
		stage.camera.min_camera_x = 32.0
		stage.camera.max_camera_x = 38.0
		stage.camera.global_position.x = 35.0
	player.global_position = Vector3(31.5, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	await physics_frame

	var BoltClass = load("res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd")
	var bolt: Area3D = BoltClass.new()
	stage.add_child(bolt)
	bolt.launch(Vector3(38.0, 0.85, 0.0), Vector3(-1.0, 0.0, 0.0), stage, 16.5, 1, false)

	var bolt_trace := []
	var mesh_axis_world := Vector3.ZERO
	if bolt.bolt_mesh != null:
		mesh_axis_world = bolt.bolt_mesh.global_transform.basis.y.normalized()

	for f in range(18):
		await physics_frame
		if is_instance_valid(bolt):
			bolt_trace.append({
				"frame": f,
				"pos": [snappedf(bolt.global_position.x, 0.01), snappedf(bolt.global_position.y, 0.01), snappedf(bolt.global_position.z, 0.01)],
				"is_active": bolt.is_active,
				"inside_tree": bolt.is_inside_tree(),
				"traveled_distance": snappedf(bolt.traveled_distance, 0.01)
			})
			if f == 6:
				await RenderingServer.frame_post_draw
				var img := root.get_viewport().get_texture().get_image()
				img.save_png(ProjectSettings.globalize_path(cap_dir + "/before_projectile_frozen.png"))
		else:
			bolt_trace.append({"frame": f, "valid": false})

	repro_report["projectile_p0_before"] = {
		"entity_class": "SideQVCrossbowBolt",
		"bolt_direction": [snappedf(bolt.direction.x, 0.01), snappedf(bolt.direction.y, 0.01), snappedf(bolt.direction.z, 0.01)] if is_instance_valid(bolt) else [],
		"cylinder_mesh_axis_world": [snappedf(mesh_axis_world.x, 0.01), snappedf(mesh_axis_world.y, 0.01), snappedf(mesh_axis_world.z, 0.01)],
		"trace": bolt_trace
	}
	if is_instance_valid(bolt):
		bolt.queue_free()

	# -------------------------------------------------------------------------
	# 3. REPRODUCE BOSS-AIR-P0 (Player chaining Pogo Bounces during Boss TRIPLE_CLEAVE)
	# -------------------------------------------------------------------------
	print("[REPRO] Testing BOSS-AIR-P0 (Before Fix)...")
	Engine.time_scale = 1.0
	stage._start_boss_sanctuary()
	for i in range(10):
		await physics_frame

	var boss: CharacterBody3D = stage.active_boss
	var boss_air_trace := []
	var max_player_y := 0.0
	var captured_air := false
	if boss != null and is_instance_valid(boss):
		boss.global_position = Vector3(77.5, 0.0, 0.0)
		player.global_position = Vector3(76.1, 0.0, 0.0)
		player.facing_dir_x = 1.0
		player.facing_attack_dir = Vector3(1.0, 0.0, 0.0)
		await physics_frame
		boss._execute_triple_cleave()
		player.start_jump()
		for f in range(60):
			Engine.time_scale = 1.0
			await physics_frame
			if f in [6, 18, 30]:
				player.attack_cooldown = 0.0
				player.is_attacking = false
				player.start_attack()
				Engine.time_scale = 1.0
			var py := player.global_position.y
			if py > max_player_y:
				max_player_y = py
			if not captured_air and py >= 2.1:
				captured_air = true
				await RenderingServer.frame_post_draw
				var img := root.get_viewport().get_texture().get_image()
				img.save_png(ProjectSettings.globalize_path(cap_dir + "/before_boss_air_pop.png"))
			boss_air_trace.append({
				"frame": f,
				"player_y": snappedf(py, 0.01),
				"player_vy": snappedf(player.velocity.y, 0.01),
				"player_on_floor": player.is_on_floor(),
				"boss_y": snappedf(boss.global_position.y, 0.01),
				"boss_pattern": boss.current_pattern
			})

	repro_report["boss_air_p0_before"] = {
		"max_player_y_meters": snappedf(max_player_y, 0.01),
		"cause": "Unrestricted mid-air _execute_pogo_bounce() triggered on horizontal melee attacks while airborne during boss TRIPLE_CLEAVE jump evasion",
		"trace": boss_air_trace
	}
	print("[REPRO] BOSS-AIR-P0 max_player_y = ", max_player_y)

	var out_json := ProjectSettings.globalize_path("res://../../STUDIO_V3/evidence/V3-022-R1/PRE_FIX_REPRO_TRACE.json")
	var f_out := FileAccess.open(out_json, FileAccess.WRITE)
	if f_out != null:
		f_out.store_string(JSON.stringify(repro_report, "\t"))
		f_out.close()

	print("[REPRO] Pre-fix reproduction complete.")
	quit(0)
