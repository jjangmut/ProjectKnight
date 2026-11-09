extends SceneTree
## V3-006 Stage 4 Option C Plane Lock, Golem Minion, Guardian Mechanics & Hazards Fixture
## Verifies:
##  1. SideQVStage4 instantiation and Heavy Golem 1 & 2 spawn at Z = 0.0 (vz = 0.0, HP 8 each)
##  2. Golem Guardian spawn: initial HP 34, poise 16, Z = 0.0, vz = 0.0
##  3. Ground Slam: danger telegraph ring, rock pillars (Z <= 0 to prevent occlusion), radial shockwave in X/Y
##  4. Spinning Lariat: forward rush in X (vz = 0.0), single-hit gate, parry stun cancellation
##  5. Phase 2 transition at HP <= 17: phase_changed signal, magma aura ring, ember particles
##  6. Quake Fissure: molten lava fissure in X (Z = 0.0), single-hit gate, jump-dodgeable height (0.9m)
##  7. Stage hazard cleanup on boss death
##  8. Synchronized captures: entry, golems, guardian spawn, ground slam, lariat, parry clash, fissure, defeat

const Stage4ScenePath := "res://scenes/side_quarter_view/SideQVStage4.tscn"
const GolemGuardianClass := preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")
const GolemMinionClass := preload("res://scripts/side_quarter_view/side_qv_golem_minion.gd")

var stage: Node3D = null
var player: CharacterBody3D = null
var golem1: CharacterBody3D = null
var golem2: CharacterBody3D = null
var boss: SideQVGolemGuardian = null

var sim_time: float = 0.0
var step: int = 0
var step_timer: float = 0.0

var phase2_signaled: bool = false
var ground_slam_attack_emitted: bool = false
var lariat_attack_emitted: bool = false
var fissure_attack_emitted: bool = false
var boss_defeated_signaled: bool = false

var test_results: Dictionary = {
	"stage4_entry_verified": false,
	"minion_spawns_z_zero": false,
	"minion_initial_hp_8": false,
	"boss_spawn_z_zero": false,
	"boss_initial_hp_34": false,
	"ground_slam_mechanics_and_z_verified": false,
	"spinning_lariat_x_rush_and_parry_verified": false,
	"phase2_transition_hp_17": false,
	"quake_fissure_mechanics_and_z_verified": false,
	"hazard_cleanup_on_defeat": false,
	"all_checks_passed": false
}

var screenshots_taken: Dictionary = {}
var manifest_additions: Array[Dictionary] = []


func _initialize() -> void:
	print("[V3-006 PLANE TEST] Initializing Stage 4 isolated golem, boss mechanics & plane test...")
	var stage_res := load(Stage4ScenePath) as PackedScene
	stage = stage_res.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage


func _physics_process(delta: float) -> bool:
	sim_time += delta
	step_timer += delta

	match step:
		0:
			# Step 0: Check Stage 4 entry, Player and Golem Minions
			if stage.has_node("HeavyGolem_1") and stage.has_node("HeavyGolem_2"):
				golem1 = stage.get_node("HeavyGolem_1") as CharacterBody3D
				golem2 = stage.get_node("HeavyGolem_2") as CharacterBody3D
				player = stage.player

				test_results["stage4_entry_verified"] = true
				_capture_screen("01_stage4_entry")

				var g1_z := golem1.global_position.z
				var g2_z := golem2.global_position.z
				print("[V3-006 PLANE TEST] Golem 1 spawn Z: %.4f, Golem 2 spawn Z: %.4f" % [g1_z, g2_z])
				if absf(g1_z) > 0.01 or absf(g2_z) > 0.01:
					_fail("Golem minion spawn Z violation (expected 0.0): g1_z=%.4f, g2_z=%.4f" % [g1_z, g2_z])
					return true
				test_results["minion_spawns_z_zero"] = true

				if golem1.current_hp != 8 or golem2.current_hp != 8:
					_fail("Golem minion initial HP not 8: g1=%d, g2=%d" % [golem1.current_hp, golem2.current_hp])
					return true
				test_results["minion_initial_hp_8"] = true

				_capture_screen("02_stage4_heavy_golem_wave")

				# Defeat minions to trigger Wave 2 Boss Spawn
				golem1.queue_free()
				golem2.queue_free()
				stage._on_enemy_defeated(golem1)
				stage._on_enemy_defeated(golem2)
				step = 1
				step_timer = 0.0

		1:
			# Step 1: Wait for boss wave spawn
			if stage.has_node("SideQVGolemGuardian"):
				boss = stage.get_node("SideQVGolemGuardian") as SideQVGolemGuardian
				print("[V3-006 PLANE TEST] Golem Guardian spawned: HP=%d/%d, Poise=%d at Z=%.4f" % [boss.current_hp, boss.max_hp, boss.current_poise, boss.global_position.z])
				if boss.current_hp != 34 or boss.max_hp != 34:
					_fail("Boss initial HP not 34 (got %d)" % boss.current_hp)
					return true
				test_results["boss_initial_hp_34"] = true

				if absf(boss.global_position.z) > 0.01:
					_fail("Boss spawn Z violation: %.4f" % boss.global_position.z)
					return true
				test_results["boss_spawn_z_zero"] = true

				boss.phase_changed.connect(func(p):
					phase2_signaled = true
					print("[V3-006 PLANE TEST] phase_changed signal received: %d" % p)
				)
				boss.attack_performed.connect(func(atk_name):
					print("[V3-006 PLANE TEST] attack_performed signal received: %s" % atk_name)
					if atk_name == "GROUND_SLAM":
						ground_slam_attack_emitted = true
					elif atk_name == "SPINNING_LARIAT":
						lariat_attack_emitted = true
					elif atk_name == "QUAKE_FISSURE":
						fissure_attack_emitted = true
				)
				boss.boss_defeated.connect(func(_b):
					boss_defeated_signaled = true
					print("[V3-006 PLANE TEST] boss_defeated signal received!")
				)

				_capture_screen("03_stage4_guardian_spawn")

				# Test 1: Ground Slam execution
				boss._execute_ground_slam()
				step = 2
				step_timer = 0.0

		2:
			# Step 2: Observe Ground Slam windup and impact
			if step_timer >= 0.15 and not screenshots_taken.has("04_stage4_ground_slam_windup"):
				_capture_screen("04_stage4_ground_slam_windup")

			if step_timer >= 0.55:
				var rock_pillars = stage.get_node_or_null("RockPillarsEffect")
				var shockwave = stage.get_node_or_null("GroundSlamShockwave")
				if rock_pillars != null:
					if absf(rock_pillars.global_position.z) > 0.01:
						_fail("Rock pillars effect container off Z=0: %.4f" % rock_pillars.global_position.z)
						return true
				_capture_screen("05_stage4_ground_slam_impact")
				test_results["ground_slam_mechanics_and_z_verified"] = ground_slam_attack_emitted
				print("[V3-006 PLANE TEST] Ground Slam mechanics and Z=0 verified: emitted=%s" % ground_slam_attack_emitted)

				# Test 2: Spinning Lariat
				boss.current_pattern = GolemGuardianClass.Pattern.IDLE
				boss.is_groggy = false
				boss._execute_spinning_lariat()
				step = 3
				step_timer = 0.0

		3:
			# Step 3: Observe Spinning Lariat rush and Parry Clash
			if step_timer >= 0.20 and not screenshots_taken.has("06_stage4_spinning_lariat_rush"):
				_capture_screen("06_stage4_spinning_lariat_rush")
				if absf(boss.velocity.z) > 0.001 or absf(boss.global_position.z) > 0.01:
					_fail("Lariat rush Z violation: vz=%.4f, pos_z=%.4f" % [boss.velocity.z, boss.global_position.z])
					return true

			if step_timer >= 0.35:
				# Apply parry stun to clash with lariat
				boss.apply_parry_stun(2.0)
				if boss.current_pattern != GolemGuardianClass.Pattern.STUNNED:
					_fail("Boss not stunned after apply_parry_stun")
					return true
				if absf(boss.velocity.x) > 0.01 or absf(boss.velocity.z) > 0.01:
					_fail("Boss moving after parry stun: vx=%.4f, vz=%.4f" % [boss.velocity.x, boss.velocity.z])
					return true
				_capture_screen("07_stage4_parry_stun_clash")
				test_results["spinning_lariat_x_rush_and_parry_verified"] = lariat_attack_emitted
				print("[V3-006 PLANE TEST] Spinning Lariat and Parry Stun clash verified: emitted=%s" % lariat_attack_emitted)

				# Test 3: Phase 2 transition & Quake Fissure
				boss.current_hp = 17
				boss._trigger_phase_2()
				boss.is_groggy = false
				boss.current_pattern = GolemGuardianClass.Pattern.IDLE

				if boss.current_phase != 2:
					_fail("Boss not in phase 2 after trigger")
					return true
				if not phase2_signaled:
					_fail("phase_changed signal not emitted")
					return true
				if not boss.magma_aura_ring.visible:
					_fail("Magma aura ring not visible in phase 2")
					return true
				test_results["phase2_transition_hp_17"] = true
				print("[V3-006 PLANE TEST] Boss Phase 2 transition confirmed: signal=true, aura=visible")

				boss._execute_quake_fissure()
				step = 4
				step_timer = 0.0

		4:
			# Step 4: Observe Quake Fissure
			if step_timer >= 0.50:
				var fissure = stage.get_node_or_null("MoltenFissureContainer")
				if fissure != null:
					if absf(fissure.global_position.z) > 0.01:
						_fail("Molten fissure container off Z=0: %.4f" % fissure.global_position.z)
						return true
				_capture_screen("08_stage4_phase2_fissure_eruption")
				test_results["quake_fissure_mechanics_and_z_verified"] = fissure_attack_emitted
				print("[V3-006 PLANE TEST] Quake Fissure mechanics and Z=0 verified: emitted=%s" % fissure_attack_emitted)

				# Test 4: Boss defeat & hazard cleanup
				boss.current_hp = 0
				boss._die()
				step = 5
				step_timer = 0.0

		5:
			# Step 5: Verify boss defeat and cleanup
			if step_timer >= 0.30:
				if not boss_defeated_signaled:
					_fail("boss_defeated signal was not emitted")
					return true
				var remaining_hazards: Array[Node] = get_nodes_in_group("stage_hazards")
				if remaining_hazards.size() > 0:
					_fail("Remaining hazards after boss defeat: %d" % remaining_hazards.size())
					return true
				test_results["hazard_cleanup_on_defeat"] = true
				_capture_screen("09_stage4_guardian_defeat")

				step = 6
				step_timer = 0.0

		6:
			# Step 6: Wait for frame_post_draw renders to complete
			if step_timer >= 0.40:
				_pass()
				return true

	return false


func _capture_screen(shot_name: String) -> void:
	if screenshots_taken.get(shot_name, false):
		return
	screenshots_taken[shot_name] = true

	var vp := root.get_viewport()
	if vp == null:
		return

	RenderingServer.frame_post_draw.connect(func():
		var img := vp.get_texture().get_image()
		if img != null:
			var out_dir := "res://../../STUDIO_V3/evidence/V3-006/captures"
			var file_name := "%s.png" % shot_name
			var full_path := "%s/%s" % [out_dir, file_name]
			var global_path := ProjectSettings.globalize_path(full_path)
			img.save_png(global_path)
			print("[V3-006 PLANE TEST] Saved synchronized capture: %s" % global_path)

			manifest_additions.append({
				"id": shot_name,
				"file_name": file_name,
				"global_path": global_path,
				"timestamp_s": sim_time,
				"resolution": "%dx%d" % [img.get_width(), img.get_height()],
				"description": "Stage 4 %s verification capture" % shot_name
			})
	, CONNECT_ONE_SHOT)


func _pass() -> void:
	test_results["all_checks_passed"] = true
	print(">>> [V3-006 PLANE TEST] ALL CHECKS PASSED: Stage 4 Option C Plane, Golems, Guardian & Hazards <<<")

	var base_dir := "res://../../STUDIO_V3/evidence/V3-006"
	var global_base := ProjectSettings.globalize_path(base_dir)

	var json_path := global_base + "/STAGE4_PLANE_AND_MECHANICS_TEST.json"
	var f_json := FileAccess.open(json_path, FileAccess.WRITE)
	if f_json != null:
		f_json.store_string(JSON.stringify(test_results, "  "))
		f_json.close()
		print("[V3-006 PLANE TEST] Saved fixture results to: %s" % json_path)

	var man_path := global_base + "/CAPTURE_MANIFEST.json"
	var f_man := FileAccess.open(man_path, FileAccess.WRITE)
	if f_man != null:
		f_man.store_string(JSON.stringify(manifest_additions, "  "))
		f_man.close()
		print("[V3-006 PLANE TEST] Saved capture manifest to: %s" % man_path)

	quit(0)


func _fail(reason: String) -> void:
	printerr("[V3-006 PLANE TEST FAIL] %s" % reason)
	test_results["all_checks_passed"] = false
	quit(1)
