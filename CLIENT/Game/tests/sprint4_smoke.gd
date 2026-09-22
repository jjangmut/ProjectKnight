extends SceneTree
## Automated QA Smoke Test for Sprint 4:
## Hit Stun & Counter Stun, Attack Telegraphs, Local SaveManager, and 4-Layer Parallax.

const SaveManagerClass := preload("res://scripts/system/save_manager.gd")
const ParallaxStageBackdropClass := preload("res://scripts/art/parallax_stage_backdrop.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)


func _run() -> void:
	print("--- START SPRINT 4 SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	var enemy_scene := load("res://scenes/enemy/TestEnemy.tscn") as PackedScene
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	world.add_child(enemy)

	for i in range(5):
		await physics_frame

	# 1. Hit Stun Verification
	print("[Check 1: Hit Stun Mechanism]")
	check(not enemy.is_stunned, "Enemy starts unstunned")
	enemy.receive_hit()
	check(enemy.is_stunned, "Enemy enters hit stun on hit")
	check(enemy._hit_stun_remaining > 0.15, "Hit stun remaining initialized (~0.20s)")
	check(not enemy.is_counter_stunned, "Regular hit is not marked counter stunned")

	# 2. Counter Stun Verification
	print("[Check 2: Counter Stun Advantage]")
	var enemy2: CharacterBody2D = enemy_scene.instantiate()
	world.add_child(enemy2)
	for i in range(5):
		await physics_frame

	enemy2.set_meta("counter_stunned", 0.40)
	enemy2.receive_hit()
	check(enemy2.is_counter_stunned, "Enemy enters counter stun on counter hit")
	check(enemy2._hit_stun_remaining >= 0.38, "Counter stun duration is extended (>=0.38s)")

	# 3. Attack Cancel on Hit
	print("[Check 3: Attack Interruption by Stun]")
	var enemy3: CharacterBody2D = enemy_scene.instantiate()
	world.add_child(enemy3)
	for i in range(5):
		await physics_frame

	enemy3._begin_attack(40.0)
	check(enemy3.state == enemy3.State.ATTACK, "Enemy entered attack state")
	enemy3.receive_hit()
	check(enemy3.state == enemy3.State.CHASE, "Enemy attack canceled into chase/stun on hit")
	check(not enemy3.is_attack_active, "Enemy attack active flag turned off")

	# 4. Attack Telegraph Visualization
	print("[Check 4: Attack Telegraph Colors]")
	var enemy4: CharacterBody2D = enemy_scene.instantiate()
	world.add_child(enemy4)
	for i in range(5):
		await physics_frame

	enemy4._begin_attack(40.0)
	var enemy_visual: Polygon2D = enemy4.get_node("Visual")
	check(enemy_visual.color.is_equal_approx(Color(1.0, 0.82, 0.2, 1.0)), "Blockable attack shows gold telegraph")

	var golem_scene := load("res://scenes/enemy/GroundSlamGolem.tscn") as PackedScene
	var golem: CharacterBody2D = golem_scene.instantiate()
	world.add_child(golem)
	for i in range(5):
		await physics_frame

	golem._begin_attack(40.0)
	var golem_visual: Polygon2D = golem.get_node("Visual")
	check(golem_visual.color.is_equal_approx(Color(1.0, 0.28, 0.15, 1.0)), "Unblockable attack shows red telegraph")

	# 5. SaveManager Verification
	print("[Check 5: SaveManager Local Disk Persistence]")
	SaveManagerClass.clear_save()
	check(not SaveManagerClass.has_save_file(), "Save file cleared successfully")

	var save_success: bool = SaveManagerClass.save_game(2, "reach", [true, true, false, false, false], {"test_stat": 99})
	check(save_success, "SaveManager.save_game executed successfully")
	check(SaveManagerClass.has_save_file(), "SaveManager detected save file on disk")

	var loaded_data: Dictionary = SaveManagerClass.load_game()
	check(loaded_data.get("stage_index") == 2, "Loaded stage index matches (2)")
	check(loaded_data.get("selected_trait") == "reach", "Loaded selected trait matches ('reach')")
	var loaded_cleared: Array = loaded_data.get("cleared")
	check(loaded_cleared[0] == true and loaded_cleared[1] == true and loaded_cleared[2] == false, "Loaded clear flags match progression")
	check(loaded_data.get("stats", {}).get("test_stat") == 99, "Loaded extra stats match (99)")

	SaveManagerClass.clear_save()
	check(not SaveManagerClass.has_save_file(), "Save file cleaned up after test")

	# 6. 4-Layer Parallax Backdrop Verification
	print("[Check 6: 4-Layer Parallax Backdrop Structure]")
	var backdrop: ParallaxBackground = ParallaxStageBackdropClass.new()
	world.add_child(backdrop)
	backdrop.setup_parallax(1)

	var l_sky: ParallaxLayer = backdrop.get_node_or_null("LayerSky")
	var l_peaks: ParallaxLayer = backdrop.get_node_or_null("LayerDistantPeaks")
	var l_ruins: ParallaxLayer = backdrop.get_node_or_null("LayerMidRuins")
	var l_fog: ParallaxLayer = backdrop.get_node_or_null("LayerForegroundFog")

	check(l_sky != null and l_sky.motion_scale == Vector2(0.05, 0.05), "Parallax Layer 1: Sky scale 0.05")
	check(l_peaks != null and l_peaks.motion_scale == Vector2(0.20, 0.10), "Parallax Layer 2: Distant Peaks scale 0.20")
	check(l_ruins != null and l_ruins.motion_scale == Vector2(0.50, 0.20), "Parallax Layer 3: Mid Ruins scale 0.50")
	check(l_fog != null and l_fog.motion_scale == Vector2(1.15, 0.30), "Parallax Layer 4: Foreground Fog scale 1.15")

	print("--- SPRINT 4 SMOKE TEST SUMMARY ---")
	print("Checks: %d, Failures: %d" % [checks, failures])

	if failures > 0:
		print("TEST RESULT: FAILED")
		quit(1)
	else:
		print("TEST RESULT: ALL SPRINT 4 CHECKS PASSED")
		quit(0)
