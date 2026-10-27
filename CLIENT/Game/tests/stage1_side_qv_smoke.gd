extends SceneTree
## Project Knight - Stage 1 (성문 외곽 / Citadel Terrace Gate) Smoke Test Suite
## Automated headless test validating:
## 1. Stage 1 instantiation & inheritance from SideQVStageBase
## 2. 3D Environment elements (Backdrop, Floor, Runic Circle, Balustrade, Braziers with OmniLight3D, Pillars)
## 3. Side Quarter-View Camera setup (Pitch = -32.0 deg, Yaw = 0.0 deg, Roll = 0.0 deg)
## 4. Wave 1 minion spawn (SideQVEnemy 2 units at X=2.0, 4.0, Z=-1.0, 1.0)
## 5. Wave 1 clear -> Wave 2 transition & SideQVBossCommander spawn (HP 24, shield charge, shockwave)
## 6. Boss defeat -> _on_boss_defeated() -> stage_cleared signal emission

const Stage1Scene: PackedScene = preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const SideQVStageBaseClass = preload("res://scripts/side_quarter_view/side_qv_stage_base.gd")
const SideQVStage1Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_1.gd")
const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")

var checks: int = 0
var failures: int = 0
var stage: Node3D = null
var test_events: Dictionary = {
	"boss_encountered": false,
	"stage_cleared": false
}


func _initialize() -> void:
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	if not InputMap.has_action("guard"):
		InputMap.add_action("guard")
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")

	# 15s Watchdog Fail-Safe Timer (User Rule 3 Compliance)
	var watchdog: SceneTreeTimer = create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] Stage 1 smoke test exceeded 15.0s. Forcing exit.")
		quit(1)
	)

	_run_smoke_suite.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [STAGE1-PASS] %s" % msg)
	else:
		failures += 1
		printerr("  [STAGE1-FAIL] %s" % msg)


func _advance_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _run_smoke_suite() -> void:
	print("\n===================================================================")
	print(">>> START STAGE 1 (성문 외곽) HEADLESS SMOKE TEST SUITE <<<")
	print("===================================================================\n")

	# --- 1. Scene & Inheritance Check ---
	print("--- Test 1: Instantiation & Inheritance ---")
	stage = Stage1Scene.instantiate() as Node3D
	check(stage != null, "SideQVStage1.tscn instantiated successfully")
	check(stage is SideQVStageBaseClass, "Stage inherits from SideQVStageBase")
	check(stage is SideQVStage1Class, "Stage is instance of SideQVStage1")
	check(stage.get("stage_index") == 1, "stage_index is 1: %s" % str(stage.get("stage_index")))
	check(stage.get("stage_title") == "성문 외곽", "stage_title is '성문 외곽': %s" % str(stage.get("stage_title")))

	stage.connect("boss_encountered", func(_b):
		test_events["boss_encountered"] = true
	)
	stage.connect("stage_cleared", func():
		test_events["stage_cleared"] = true
	)

	root.add_child(stage)
	current_scene = stage
	await _advance_frames(5)

	# --- 2. 3D Environment & Architecture Verification ---
	print("\n--- Test 2: 3D Environment & Architecture ---")
	var world_env := stage.get_node_or_null("WorldEnvironment3D") as WorldEnvironment
	check(world_env != null and world_env.environment != null, "WorldEnvironment3D exists with active Environment")
	if world_env and world_env.environment:
		check(world_env.environment.glow_enabled, "Environment 3D Glow is enabled")

	var sun_light := stage.get_node_or_null("SunLight3D") as DirectionalLight3D
	check(sun_light != null, "DirectionalLight3D (SunLight3D) exists")
	if sun_light:
		check(sun_light.shadow_enabled, "SunLight3D has shadows enabled")

	var backdrop := stage.get_node_or_null("PanoramicCastleBackdrop") as MeshInstance3D
	check(backdrop != null and backdrop.mesh is QuadMesh, "PanoramicCastleBackdrop exists with QuadMesh")
	if backdrop and backdrop.material_override is StandardMaterial3D:
		var bmat := backdrop.material_override as StandardMaterial3D
		check(bmat.albedo_texture != null, "Backdrop has albedo texture (background.png)")

	var floor_node := stage.get_node_or_null("ArenaFloor") as CSGBox3D
	check(floor_node != null and floor_node.use_collision, "ArenaFloor exists with 3D collision enabled")
	check(floor_node != null and floor_node.collision_layer == 4, "ArenaFloor is on collision layer 4")
	if floor_node and floor_node.material_override is StandardMaterial3D:
		var fmat := floor_node.material_override as StandardMaterial3D
		check(fmat.albedo_texture != null and fmat.uv1_triplanar, "ArenaFloor has triplanar flagstone texture")

	var runic_seal := stage.get_node_or_null("CentralRunicSeal") as MeshInstance3D
	check(runic_seal != null and runic_seal.mesh is QuadMesh, "CentralRunicSeal exists with QuadMesh")
	if runic_seal and runic_seal.material_override is StandardMaterial3D:
		var smat := runic_seal.material_override as StandardMaterial3D
		check(smat.albedo_texture != null and smat.emission_enabled, "CentralRunicSeal has emissive runic circle texture")

	var back_wall := stage.get_node_or_null("CastleBackWall") as CSGBox3D
	check(back_wall != null and back_wall.use_collision, "CastleBackWall exists with collision")

	var front_fence := stage.get_node_or_null("FrontBalustrade") as CSGBox3D
	check(front_fence != null and front_fence.use_collision, "FrontBalustrade exists with collision")

	var torches: Array[Node] = stage.get_tree().get_nodes_in_group("stage_torches")
	check(torches.size() == 4, "4 Castle Braziers spawned along terrace: count = %d" % torches.size())
	for i in range(torches.size()):
		var t: Node = torches[i]
		var light := t.get_node_or_null("TorchLight") as OmniLight3D
		check(light != null and light.light_energy > 0.0, "Brazier %d has active OmniLight3D" % i)

	var pillars: Array[String] = ["Pillar_BackLeft", "Pillar_BackRight", "Pillar_FrontLeft", "Pillar_FrontRight"]
	for p_name in pillars:
		var p_node: Node = stage.get_node_or_null(p_name)
		check(p_node != null, "Runic Monolith Pillar '%s' exists" % p_name)
		if p_node:
			var shaft := p_node.get_node_or_null("Shaft") as CSGCylinder3D
			check(shaft != null and shaft.use_collision, "Pillar '%s' has collision shaft" % p_name)

	var wing_left: Node = stage.get_node_or_null("GothicWing_Left")
	var wing_right: Node = stage.get_node_or_null("GothicWing_Right")
	check(wing_left != null and wing_right != null, "Left and Right Gothic Wings exist")
	if wing_left:
		var b_left := wing_left.get_node_or_null("CitadelBanner") as MeshInstance3D
		check(b_left != null, "GothicWing_Left has CitadelBanner")

	# --- 3. Camera Setup Verification ---
	print("\n--- Test 3: Side Quarter-View Tracking Camera ---")
	var camera: Camera3D = stage.get("camera") as Camera3D
	check(camera != null, "SideQVCamera attached to stage")
	if camera:
		check(camera.get("target") == stage.get("player"), "Camera target is player")
		var rot: Vector3 = camera.rotation_degrees
		check(is_equal_approx(rot.y, 0.0), "Camera Yaw is strictly 0.0 deg (Side-View horizontal): %.2f deg" % rot.y)
		check(is_equal_approx(rot.x, -32.0), "Camera Pitch is -32.0 deg (Quarter-View depth angle): %.2f deg" % rot.x)
		check(is_equal_approx(rot.z, 0.0), "Camera Roll is 0.0 deg: %.2f deg" % rot.z)

	# --- 4. Wave 1 Verification ---
	print("\n--- Test 4: Wave 1 Minion Spawns ---")
	check(int(stage.get("current_wave")) == 1, "Initial wave is Wave 1")
	var player: Node3D = stage.get("player") as Node3D
	check(player != null, "SideQVPlayer spawned")
	if player:
		check(is_equal_approx(player.position.x, -8.0), "Player spawned at X = -8.0: %.2f" % player.position.x)

	var enemy_list: Array = stage.get("enemies") as Array
	check(enemy_list.size() == 2, "Wave 1 spawned 2 enemies: count = %d" % enemy_list.size())
	if enemy_list.size() >= 2:
		var e1: Node3D = enemy_list[0] as Node3D
		var e2: Node3D = enemy_list[1] as Node3D
		check(e1 is SideQVEnemyClass, "Enemy 1 is SideQVEnemy")
		check(e2 is SideQVEnemyClass, "Enemy 2 is SideQVEnemy")

		var spawn_pos1: Vector3 = e1.get_meta("spawn_pos", Vector3.ZERO) as Vector3
		var spawn_pos2: Vector3 = e2.get_meta("spawn_pos", Vector3.ZERO) as Vector3
		check(spawn_pos1.is_equal_approx(Vector3(2.0, 0.1, -1.0)),
			"Enemy 1 spawn position registered at (2.0, 0.1, -1.0): (%.2f, %.2f, %.2f)" % [spawn_pos1.x, spawn_pos1.y, spawn_pos1.z])
		check(spawn_pos2.is_equal_approx(Vector3(4.0, 0.1, 1.0)),
			"Enemy 2 spawn position registered at (4.0, 0.1, 1.0): (%.2f, %.2f, %.2f)" % [spawn_pos2.x, spawn_pos2.y, spawn_pos2.z])
		check(e1.position.distance_to(spawn_pos1) < 0.5, "Enemy 1 close to spawn point: dist = %.2f m" % e1.position.distance_to(spawn_pos1))
		check(e2.position.distance_to(spawn_pos2) < 0.5, "Enemy 2 close to spawn point: dist = %.2f m" % e2.position.distance_to(spawn_pos2))

	# --- 5. Wave 1 Elimination -> Boss Wave Spawn ---
	print("\n--- Test 5: Wave 1 Clear & Boss Wave Transition ---")
	# Eliminate Wave 1 minions
	var minion_copy: Array = enemy_list.duplicate()
	for m in minion_copy:
		if is_instance_valid(m) and m.has_method("receive_hit"):
			m.receive_hit(10, Vector3.ZERO)

	await _advance_frames(5)
	var remaining_enemies: Array = stage.get("enemies") as Array
	check(remaining_enemies.is_empty(), "Wave 1 minions defeated and cleared from list")

	# Wait for 1.2s delay for boss wave
	print("  [STAGE1-INFO] Waiting for boss wave transition (1.5s)...")
	await create_timer(1.5).timeout
	await _advance_frames(5)

	check(int(stage.get("current_wave")) == 2, "Transitioned to Wave 2 (Boss Wave): %d" % int(stage.get("current_wave")))
	check(test_events["boss_encountered"], "boss_encountered signal emitted")
	var boss: Node3D = stage.get("active_boss") as Node3D
	check(boss != null, "active_boss is not null")
	check(boss is SideQVBossClass, "active_boss is SideQVBossCommander")
	if boss:
		check(int(boss.get("max_hp")) == 24, "Boss max HP is 24: %d" % int(boss.get("max_hp")))
		check(int(boss.get("current_hp")) == 24, "Boss current HP is 24: %d" % int(boss.get("current_hp")))
		check(float(boss.get("charge_speed")) == 12.0, "Boss charge speed is 12.0: %.1f" % float(boss.get("charge_speed")))
		check(stage.get("boss_ui") != null, "Boss Health Bar UI created on mobile HUD")

	# --- 6. Boss Defeat & Stage Clear ---
	print("\n--- Test 6: Boss Defeat & Stage Clear Emission ---")
	if boss:
		# Phase 1 -> Phase 2 test
		boss.receive_hit(12, Vector3.ZERO)
		check(int(boss.get("current_phase")) == 2, "Boss transitioned to Phase 2 at <= 50% HP")
		var aura: MeshInstance3D = boss.get("aura_ring_3d") as MeshInstance3D
		check(aura != null and aura.visible, "Boss crimson aura ring visible in Phase 2")

		# Fatal blow
		boss.receive_hit(15, Vector3.ZERO)
		check(int(boss.get("current_hp")) <= 0, "Boss HP reduced to 0 or below")
		check(bool(stage.get("is_stage_finished")), "stage.is_stage_finished set to true")

	print("  [STAGE1-INFO] Waiting for stage_cleared fanfare delay (2.5s)...")
	await create_timer(2.5).timeout
	await _advance_frames(5)

	check(test_events["stage_cleared"], "stage_cleared signal emitted successfully after fanfare")

	# --- Final Summary ---
	print("\n===================================================================")
	print("STAGE 1 SMOKE TEST RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("===================================================================")

	if failures == 0:
		print("\n>>> ALL STAGE 1 (성문 외곽) CHECKS PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> STAGE 1 CHECKS FAILED (%d failures) <<<\n" % failures)
		quit(1)
