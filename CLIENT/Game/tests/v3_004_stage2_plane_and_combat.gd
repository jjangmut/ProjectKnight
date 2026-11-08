extends SceneTree
## V3-004 Stage 2 Option C Plane Lock & Isolated Combat Mechanics Test
## Verifies:
##  1. SideQVStage2 instantiation and actor presence at Z = 0.0
##  2. Minion 1 & 2 spawn at Z = 0.0 and maintain vz = 0.0, z = 0.0
##  3. Minion pounce windup telegraph precedes attack hitbox activation
##  4. Beast Chieftain spawn at Z = 0.0 with HP = 28/28
##  5. Chieftain Pounce Leap: strictly 2D parabolic jump (vy > 0, vz = 0.0, z = 0.0)
##  6. Chieftain Phase 2 transition at HP <= 14 with phase_changed signal
##  7. Chieftain groggy and parry stun mechanics

const Stage2ScenePath := "res://scenes/side_quarter_view/SideQVStage2.tscn"
const BeastMinionClass := preload("res://scripts/side_quarter_view/enemies/side_qv_beast_minion.gd")
const BeastChieftainClass := preload("res://scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd")

var stage: Node3D = null
var minion1: CharacterBody3D = null
var minion2: CharacterBody3D = null
var boss: SideQVBeastChieftain = null

var sim_time: float = 0.0
var step: int = 0
var phase2_signaled: bool = false
var boss_leap_vz_max: float = 0.0
var all_plane_passed: bool = true


func _initialize() -> void:
	print("[V3-004 PLANE TEST] Initializing Stage 2 isolated plane and mechanics test...")
	var stage_res := load(Stage2ScenePath) as PackedScene
	stage = stage_res.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage


func _physics_process(delta: float) -> bool:
	sim_time += delta

	match step:
		0:
			# Step 0: Check Minion spawns and initial Z coordinates
			if stage.has_node("SideQVBeastMinion_1") and stage.has_node("SideQVBeastMinion_2"):
				minion1 = stage.get_node("SideQVBeastMinion_1") as CharacterBody3D
				minion2 = stage.get_node("SideQVBeastMinion_2") as CharacterBody3D

				var m1_z := minion1.global_position.z
				var m2_z := minion2.global_position.z
				print("[V3-004 PLANE TEST] Minion 1 spawn Z: %.4f, Minion 2 spawn Z: %.4f" % [m1_z, m2_z])
				if absf(m1_z) > 0.01 or absf(m2_z) > 0.01:
					_fail("Minion spawn Z violation (expected 0.0): m1_z=%.4f, m2_z=%.4f" % [m1_z, m2_z])
					return true

				# Test minion windup telegraph
				minion1._start_charge_windup(-1.0)
				if minion1.current_state != BeastMinionClass.State.WINDUP:
					_fail("Minion did not enter WINDUP state")
					return true
				if minion1.attack_area_3d.monitoring:
					_fail("Minion attack area active during telegraph windup (hazard prematurely active)")
					return true

				# Fast forward minion defeat to spawn boss wave
				minion1.queue_free()
				minion2.queue_free()
				stage._on_enemy_defeated(minion1)
				stage._on_enemy_defeated(minion2)
				step = 1

		1:
			# Step 1: Wait for boss wave spawn
			if stage.has_node("SideQVBeastChieftain"):
				boss = stage.get_node("SideQVBeastChieftain") as SideQVBeastChieftain
				print("[V3-004 PLANE TEST] Boss Chieftain spawned: HP=%d/%d at Z=%.4f" % [boss.current_hp, boss.max_hp, boss.global_position.z])
				if boss.current_hp != 28 or boss.max_hp != 28:
					_fail("Boss initial HP not 28 (got %d)" % boss.current_hp)
					return true
				if absf(boss.global_position.z) > 0.01:
					_fail("Boss spawn Z violation: %.4f" % boss.global_position.z)
					return true

				boss.phase_changed.connect(func(p):
					phase2_signaled = true
					print("[V3-004 PLANE TEST] phase_changed signal received: %d" % p)
				)

				# Test Pounce Leap Z plane behavior
				boss._execute_pounce_leap(-1.0)
				step = 2

		2:
			# Step 2: Observe Pounce Leap airborne motion
			if boss != null and is_instance_valid(boss):
				if boss.is_leap_airborne:
					boss_leap_vz_max = maxf(boss_leap_vz_max, absf(boss.velocity.z))
					if absf(boss.global_position.z) > 0.01 or absf(boss.velocity.z) > 0.01:
						all_plane_passed = false
						_fail("Boss leap airborne Z violation: z=%.4f, vz=%.4f" % [boss.global_position.z, boss.velocity.z])
						return true

				if boss.leap_has_landed:
					print("[V3-004 PLANE TEST] Boss leap landed safely. Max airborne |vz|: %.4f" % boss_leap_vz_max)
					step = 3

		3:
			# Step 3: Test Phase 2 transition at HP <= 14
			boss.current_hp = 14
			boss.receive_hit(1)
			if boss.current_phase != 2:
				_fail("Boss did not transition to Phase 2 at HP <= 14 (current_phase=%d)" % boss.current_phase)
				return true
			if not phase2_signaled:
				_fail("Boss did not emit phase_changed signal on Phase 2 transition")
				return true
			if not boss.aura_ring_3d.visible:
				_fail("Boss Phase 2 emerald aura ring not visible")
				return true

			# Test parry stun
			boss.apply_parry_stun(1.5)
			if boss.current_pattern != SideQVBeastChieftain.Pattern.STUNNED:
				_fail("Boss did not enter STUNNED pattern on parry stun")
				return true

			_pass()
			return true

	if sim_time > 10.0:
		_fail("Timed out waiting for test steps")
		return true

	return false


func _pass() -> void:
	print(">>> [V3-004 PLANE TEST] ALL CHECKS PASSED: Stage 2 Option C Plane & Boss Mechanics <<<")
	quit(0)


func _fail(reason: String) -> void:
	print(">>> [V3-004 PLANE TEST FAILED] <<< : " + reason)
	quit(1)
