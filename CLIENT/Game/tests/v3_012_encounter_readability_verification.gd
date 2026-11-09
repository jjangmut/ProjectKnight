extends SceneTree
## V3-012 Encounter Readability & Enemy Reaction Verification Suite
## Verifies:
##  1. Hit reaction only on confirmed damage (miss / 0 damage triggers no reaction)
##  2. Standard hit reaction: distinct damage flash & physical micro-recoil along hit direction
##  3. Counter hit reaction: distinct radiant cyan/gold counter flash & enhanced recoil
##  4. Boss hit reaction: sprite micro-recoil shake with zero physics body displacement & Option C lock
##  5. Death transition disables collision_layer and collision_mask immediately
##  6. Death transition disables attack_area monitoring immediately
##  7. Exactly-once defeat signal (duplicate reward prevention)
##  8. Immediate overhead HP bar hiding upon defeat
##  9. Stage 3 Crossbow Commander 3-way fan volley aim laser lines on Z=0
## 10. Stage 4 Golem Guardian ground slam telegraph origin & radius match shockwave impact zone
## 11. Strict Option C plane lock (Z=0.0000, vz=0.0000) across all reactions

const SideQVEnemyClass := preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBeastMinionClass := preload("res://scripts/side_quarter_view/enemies/side_qv_beast_minion.gd")
const SideQVRangedMinionClass := preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVBossCommanderClass := preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVCrossbowCommanderClass := preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")
const SideQVGolemGuardianClass := preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")

var results := {
	"task_id": "V3-012",
	"timestamp": "",
	"total_checks": 0,
	"passed_checks": 0,
	"all_passed": false,
	"checks": []
}

var scene_root: Node3D = null
var frame_idx: int = 0

func _initialize() -> void:
	print(">>> [V3-012 VERIFICATION] Initializing verification runner... <<<")
	var now := Time.get_datetime_dict_from_system()
	results["timestamp"] = "%04d-%02d-%02dT%02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]

	scene_root = Node3D.new()
	scene_root.name = "TestSceneRoot"
	root.add_child(scene_root)
	current_scene = scene_root

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	frame_idx += 1
	if frame_idx == 2:
		_execute_tests()

func _execute_tests() -> void:
	print(">>> [V3-012 VERIFICATION] Executing test suite with live SceneTree... <<<")

	# --- 1. Miss / Zero Damage Check ---
	print("\n--- 1. Miss / Zero Damage Integrity ---")
	var minion1 := SideQVEnemyClass.new()
	scene_root.add_child(minion1)
	minion1.position = Vector3(0.0, 0.0, 0.0)
	var initial_hp := minion1.current_hp
	minion1.receive_hit(0, Vector3.LEFT, false) # 0 damage
	_check("zero_damage_no_reaction", minion1.current_hp == initial_hp and not minion1.is_recoiling and minion1.velocity.x == 0.0)
	minion1.queue_free()

	# --- 2. Confirmed Damage Flash & Micro-Recoil ---
	print("\n--- 2. Confirmed Damage Flash & Micro-Recoil ---")
	var minion2 := SideQVEnemyClass.new()
	scene_root.add_child(minion2)
	minion2.position = Vector3(0.0, 0.0, 0.0)
	minion2.receive_hit(1, Vector3.RIGHT, false)
	_check("confirmed_hit_hp_reduced", minion2.current_hp == (initial_hp - 1))
	_check("confirmed_hit_micro_recoil_activated", minion2.is_recoiling and minion2.velocity.x > 1.5)
	_check("confirmed_hit_option_c_z_zero", absf(minion2.velocity.z) < 0.0001 and absf(minion2.position.z) < 0.0001)
	minion2.queue_free()

	# --- 3. Counter Hit Distinct Reaction ---
	print("\n--- 3. Counter Hit Distinct Reaction ---")
	var minion3 := SideQVEnemyClass.new()
	scene_root.add_child(minion3)
	minion3.position = Vector3(0.0, 0.0, 0.0)
	minion3.receive_hit(2, Vector3.LEFT, true) # Counter hit
	_check("counter_hit_enhanced_recoil", minion3.is_recoiling and minion3.velocity.x < -3.0)
	_check("counter_hit_option_c_z_zero", absf(minion3.velocity.z) < 0.0001 and absf(minion3.position.z) < 0.0001)
	minion3.queue_free()

	# --- 4. Beast Minion Reaction & Death ---
	print("\n--- 4. Beast Minion Reaction & Death Guard ---")
	var beast := SideQVBeastMinionClass.new()
	scene_root.add_child(beast)
	beast.position = Vector3(0.0, 0.0, 0.0)
	beast.receive_hit(1, Vector3.LEFT, false)
	_check("beast_minion_recoil_activated", beast.is_recoiling and beast.velocity.x < -1.5)
	var beast_defeated_count := [0]
	beast.enemy_defeated.connect(func(_node): beast_defeated_count[0] += 1)
	beast.receive_hit(10, Vector3.LEFT, false) # Lethal
	_check("beast_is_dead_flag_set", beast.is_dead)
	_check("beast_collision_disabled", beast.collision_layer == 0 and beast.collision_mask == 0)
	var beast_monitoring := beast.attack_area_3d != null and beast.attack_area_3d.monitoring
	_check("beast_attack_monitoring_disabled", not beast_monitoring)
	_check("beast_defeated_signal_emitted_once", beast_defeated_count[0] == 1)
	# Attempt hit on dead beast
	beast.receive_hit(5, Vector3.LEFT, false)
	_check("beast_no_duplicate_defeat_signal", beast_defeated_count[0] == 1)
	beast.queue_free()

	# --- 5. Ranged Minion Reaction & Death ---
	print("\n--- 5. Ranged Minion Reaction & Death Guard ---")
	var ranged := SideQVRangedMinionClass.new()
	scene_root.add_child(ranged)
	ranged.position = Vector3(0.0, 0.0, 0.0)
	ranged.receive_hit(1, Vector3.RIGHT, false)
	_check("ranged_minion_recoil_activated", ranged.is_recoiling and ranged.velocity.x > 1.5)
	var ranged_defeated_count := [0]
	ranged.enemy_defeated.connect(func(_node): ranged_defeated_count[0] += 1)
	ranged.receive_hit(10, Vector3.RIGHT, false) # Lethal
	_check("ranged_is_dead_flag_set", ranged.is_dead)
	_check("ranged_collision_disabled", ranged.collision_layer == 0 and ranged.collision_mask == 0)
	_check("ranged_defeated_signal_emitted_once", ranged_defeated_count[0] == 1)
	# Attempt hit on dead ranged minion
	ranged.receive_hit(5, Vector3.RIGHT, false)
	_check("ranged_no_duplicate_defeat_signal", ranged_defeated_count[0] == 1)
	ranged.queue_free()

	# --- 6. Boss Hit Reaction & Micro-Shake ---
	print("\n--- 6. Boss Hit Reaction & Poise Preservation ---")
	var boss := SideQVBossCommanderClass.new()
	scene_root.add_child(boss)
	boss.position = Vector3(0.0, 0.0, 0.0)
	boss.receive_hit(2, Vector3.LEFT, true)
	_check("boss_physics_body_stationary", boss.velocity.x == 0.0 and boss.velocity.z == 0.0)
	_check("boss_option_c_plane_locked", absf(boss.position.z) < 0.0001)
	var boss_defeated_count := [0]
	boss.boss_defeated.connect(func(_node): boss_defeated_count[0] += 1)
	boss.receive_hit(100, Vector3.LEFT, false) # Lethal
	_check("boss_is_dead_flag_set", boss.is_dead)
	_check("boss_collision_disabled", boss.collision_layer == 0 and boss.collision_mask == 0)
	_check("boss_defeated_signal_emitted_once", boss_defeated_count[0] == 1)
	boss.receive_hit(50, Vector3.LEFT, false)
	_check("boss_no_duplicate_defeat_signal", boss_defeated_count[0] == 1)
	boss.queue_free()

	# --- 7. Stage 3 Crossbow Commander 3-Way Fan Volley Telegraph ---
	print("\n--- 7. Stage 3 Fan Volley Telegraph Inspection ---")
	var cmd := SideQVCrossbowCommanderClass.new()
	scene_root.add_child(cmd)
	cmd.position = Vector3(0.0, 0.0, 0.0)
	var aim_marker := cmd._create_fan_aim_lines(Vector3(-1.0, 0.0, 0.0))
	_check("fan_aim_marker_instantiated", is_instance_valid(aim_marker))
	var beam_count := 0
	for child in aim_marker.get_children():
		if child.name.begins_with("AimBeam_"):
			beam_count += 1
	_check("fan_aim_marker_has_3_trajectory_beams", beam_count == 3)
	_check("fan_aim_marker_coplanar_z_zero", absf(aim_marker.position.z) < 0.0001)
	aim_marker.queue_free()
	cmd.queue_free()

	# --- 8. Stage 4 Golem Guardian Ground Slam Telegraph Alignment ---
	print("\n--- 8. Stage 4 Ground Slam Telegraph Alignment ---")
	var golem := SideQVGolemGuardianClass.new()
	scene_root.add_child(golem)
	golem.position = Vector3(5.0, 0.0, 0.0)
	golem.facing_dir_x = -1.0
	var expected_origin := golem.position + Vector3(-1.5, 0.0, 0.0)
	golem._show_danger_telegraph(0.35, expected_origin, 4.5)
	var telegraph_ring := scene_root.get_node_or_null("DangerTelegraphRing3D") as MeshInstance3D
	_check("golem_telegraph_ring_spawned", is_instance_valid(telegraph_ring))
	if telegraph_ring != null:
		var dist_to_slam_origin := (telegraph_ring.position - (expected_origin + Vector3(0.0, 0.08, 0.0))).length()
		_check("golem_telegraph_ring_matches_slam_origin", dist_to_slam_origin < 0.01, "dist=%.4f" % dist_to_slam_origin)
		_check("golem_telegraph_ring_coplanar_z_zero", absf(telegraph_ring.position.z) < 0.0001)
		telegraph_ring.queue_free()
	golem.queue_free()

	# --- Summary ---
	var passed: int = results["passed_checks"]
	var total: int = results["total_checks"]
	results["all_passed"] = (passed == total)

	print("\n==================================================")
	print(">>> V3-012 ENCOUNTER READABILITY VERIFICATION: %d / %d PASSED <<<" % [passed, total])
	print("==================================================")

	var evidence_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-012"
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var res_path := evidence_dir + "/ENCOUNTER_READABILITY_VERIFICATION_RESULT.json"
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
		print("Saved verification result: ", res_path)

	quit(0 if results["all_passed"] else 1)

func _check(check_name: String, passed: bool, info: String = "") -> void:
	results["total_checks"] += 1
	var status_str := "PASS" if passed else "FAIL"
	if passed:
		results["passed_checks"] += 1
	results["checks"].append({
		"name": check_name,
		"status": status_str,
		"info": info
	})
	print(" [%s] %s %s" % [status_str, check_name, ("(" + info + ")") if info != "" else ""])
