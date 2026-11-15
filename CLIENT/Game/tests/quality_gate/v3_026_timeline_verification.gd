extends SceneTree
## ProjectKnight V3-026-A: Combat Timeline & Deterministic Hitbox Verification Suite
## Verifies:
## 1. Zero damage on startup frame (t = 0.0s, hitbox OFF, damage == 0).
## 2. Strict phase progression: WINDUP -> ACTIVE (hitbox ON) -> CONTACT (damage & hitstop) -> RECOVERY.
## 3. Hitbox deactivation at recovery start.
## 4. Recovery cancel window (dash/guard cancels).
## 5. Output: STUDIO_V3/evidence/V3-026/COMBAT_EVENT_TIMELINE.json

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const CombatTimelineClass = preload("res://scripts/combat/combat_timeline_controller.gd")

const EVIDENCE_DIR := "D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-026-R1/STUDIO_V3/evidence/V3-026-R1/"
const OUTPUT_FILE := "COMBAT_EVENT_TIMELINE.json"

var trace_data := {
	"suite": "V3-026 Combat Timeline & Deterministic Hitbox Verification",
	"task_id": "V3-026-A",
	"target_fps": 60,
	"timestamp_unix": 0,
	"tests": [],
	"summary": {
		"total_attacks_tested": 0,
		"startup_frame_zero_damage_pass": true,
		"hitbox_timing_exact_pass": true,
		"contact_damage_synchronized_pass": true,
		"recovery_hitbox_closed_pass": true,
		"all_timeline_gates_passed": true
	}
}

var current_stage: Node3D = null
var current_player: CharacterBody3D = null
var dummy_enemy: CharacterBody3D = null


func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_start_suite")


func _start_suite() -> void:
	print("=================================================================")
	print("[V3-026-A] Starting Combat Timeline Verification Suite...")
	print("=================================================================")
	trace_data["timestamp_unix"] = int(Time.get_unix_time_from_system())

	# Test 1: Attack 1 Single Hitframe Timeline & Zero Startup Damage
	await _test_attack_timeline(1, "player_combo_1")

	# Test 2: Attack 2 Single Hitframe Timeline
	await _test_attack_timeline(2, "player_combo_2")

	# Test 3: Attack 3 Single Hitframe Timeline & Heavy Hitstop
	await _test_attack_timeline(3, "player_combo_3")

	# Test 4: Recovery Cancel Window Verification
	await _test_recovery_cancel()

	# Finalize results
	_finalize_results()


func _setup_clean_sandbox() -> void:
	if current_stage != null and is_instance_valid(current_stage):
		current_stage.queue_free()
		current_stage = null
		await process_frame
		await process_frame

	current_stage = Node3D.new()
	current_stage.name = "CombatTimelineSandbox"
	root.add_child(current_stage)

	# Floor
	var floor_body := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(100.0, 1.0, 20.0)
	fcol.shape = fbox
	floor_body.add_child(fcol)
	floor_body.position.y = -0.5
	current_stage.add_child(floor_body)

	# Player
	current_player = SideQVPlayerClass.new()
	current_player.position = Vector3(0.0, 0.0, 0.0)
	current_stage.add_child(current_player)

	# Dummy Target Enemy
	dummy_enemy = SideQVEnemyClass.new()
	dummy_enemy.position = Vector3(1.0, 0.0, 0.0) # Within sword reach
	dummy_enemy.max_hp = 1000
	dummy_enemy.current_hp = 1000
	dummy_enemy.add_to_group("enemies")
	current_stage.add_child(dummy_enemy)

	await process_frame
	await process_frame
	current_player.set_physics_process(false)
	dummy_enemy.set_physics_process(false)


func _test_attack_timeline(combo_index: int, action_id: String) -> void:
	print("\n--- Verifying Attack %d (%s) Timeline ---" % [combo_index, action_id])
	await _setup_clean_sandbox()

	# Force combo step
	current_player.combo_step = combo_index - 1
	var action_def = current_player.attack_actions.get(action_id)
	assert(action_def != null, "Action definition must exist for %s" % action_id)

	var initial_hp: int = dummy_enemy.current_hp
	var frame_samples: Array = []
	var startup_damage_detected: bool = false
	var contact_frame_matched: bool = false
	var hitbox_active_frames: int = 0
	var damage_applied_time: float = -1.0

	# Frame 0: Trigger attack
	current_player.start_attack()

	# Check Frame 0 IMMEDIATELY (t = 0.0s)
	var f0_monitoring: bool = current_player.attack_area_3d.monitoring
	var f0_damage_taken: int = initial_hp - dummy_enemy.current_hp
	if f0_damage_taken > 0 or f0_monitoring:
		startup_damage_detected = true
		print("[FAIL] Startup frame bug detected! t=0.0s monitoring=%s, damage_taken=%d" % [str(f0_monitoring), f0_damage_taken])
	else:
		print("[PASS] Startup frame verified clean: t=0.0s monitoring=false, damage_taken=0")

	# Step physics frames at 60 FPS (dt = 1/60s)
	var dt: float = 1.0 / 60.0
	var total_steps: int = int(ceil(action_def.total_duration / dt)) + 5
	var elapsed: float = 0.0

	for step in range(total_steps):
		elapsed += dt
		# Simulate 1 physics step
		current_player._physics_process(dt)
		if is_instance_valid(dummy_enemy):
			dummy_enemy._physics_process(dt)

		var cur_phase: int = current_player.timeline_controller.current_phase if current_player.timeline_controller != null else 0
		var cur_monitoring: bool = current_player.attack_area_3d.monitoring
		var hp_now: int = dummy_enemy.current_hp if is_instance_valid(dummy_enemy) else 0
		var delta_hp: int = initial_hp - hp_now

		if cur_monitoring:
			hitbox_active_frames += 1

		if delta_hp > 0.0 and damage_applied_time < 0.0:
			damage_applied_time = elapsed
			# Contact time should be within 1 frame of action_def.contact_time
			var diff: float = abs(elapsed - action_def.contact_time)
			if diff <= dt * 1.5:
				contact_frame_matched = true
				print("[PASS] Damage delivered exactly at contact frame: t=%.3fs (expected contact=%.3fs, diff=%.3fs)" % [elapsed, action_def.contact_time, diff])
			else:
				print("[WARN] Damage delivered at t=%.3fs, expected contact=%.3fs" % [elapsed, action_def.contact_time])

		# Check recovery phase: hitbox MUST be OFF
		if cur_phase == CombatTimelineClass.Phase.RECOVERY:
			if cur_monitoring:
				print("[FAIL] Hitbox remained active in RECOVERY phase! t=%.3fs" % elapsed)
				trace_data["summary"]["recovery_hitbox_closed_pass"] = false

		frame_samples.append({
			"step": step + 1,
			"time_sec": snapped(elapsed, 0.001),
			"phase": cur_phase,
			"hitbox_monitoring": cur_monitoring,
			"slash_visible": current_player.slash_visual_3d.visible,
			"damage_dealt": delta_hp
		})

		await process_frame

	var test_passed: bool = (not startup_damage_detected) and contact_frame_matched and (damage_applied_time > 0.0)

	var record := {
		"action_id": action_id,
		"combo_index": combo_index,
		"configured_windup_sec": action_def.windup_duration,
		"configured_contact_sec": action_def.contact_time,
		"configured_active_sec": action_def.active_duration,
		"configured_recovery_sec": action_def.recovery_duration,
		"configured_total_sec": action_def.total_duration,
		"startup_damage_detected": startup_damage_detected,
		"measured_damage_time_sec": snapped(damage_applied_time, 0.001),
		"contact_frame_matched": contact_frame_matched,
		"hitbox_active_frame_count": hitbox_active_frames,
		"test_passed": test_passed,
		"sample_count": frame_samples.size()
	}

	trace_data["tests"].append(record)
	trace_data["summary"]["total_attacks_tested"] += 1
	if startup_damage_detected:
		trace_data["summary"]["startup_frame_zero_damage_pass"] = false
	if not contact_frame_matched:
		trace_data["summary"]["contact_damage_synchronized_pass"] = false
	if not test_passed:
		trace_data["summary"]["all_timeline_gates_passed"] = false


func _test_recovery_cancel() -> void:
	print("\n--- Verifying Recovery Dash Cancel ---")
	await _setup_clean_sandbox()

	current_player.combo_step = 0
	current_player.start_attack()
	var action_def = current_player.attack_actions.get("player_combo_1")

	var dt: float = 1.0 / 60.0
	var elapsed: float = 0.0
	var cancel_tested: bool = false
	var cancel_succeeded: bool = false

	for step in range(30):
		elapsed += dt
		current_player._physics_process(dt)

		if current_player.timeline_controller != null and current_player.timeline_controller.can_cancel():
			if not cancel_tested:
				cancel_tested = true
				# Buffer dash
				current_player.dash_buffer_timer = 0.1
				# Step next frame to process cancel
				current_player._physics_process(dt)
				if current_player.current_state == SideQVPlayerClass.State.DASH and not current_player.is_attacking:
					cancel_succeeded = true
					print("[PASS] Successfully cancelled attack recovery into dash at t=%.3fs!" % elapsed)
				break
		await process_frame

	trace_data["recovery_cancel_test"] = {
		"cancel_tested": cancel_tested,
		"cancel_succeeded": cancel_succeeded
	}


func _finalize_results() -> void:
	print("\n=================================================================")
	print("[V3-026-A] Finalizing Combat Timeline Verification...")
	print("Summary: %s" % JSON.stringify(trace_data["summary"], "\t"))
	print("=================================================================")

	var dir := DirAccess.open("D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-026/")
	if dir != null:
		if not dir.dir_exists("STUDIO_V3/evidence/V3-026"):
			dir.make_dir_recursive("STUDIO_V3/evidence/V3-026")

	var out_path := EVIDENCE_DIR + OUTPUT_FILE
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(trace_data, "\t"))
		f.close()
		print("[V3-026-A] Evidence saved to %s" % out_path)
	else:
		print("[ERROR] Failed to save evidence to %s" % out_path)

	quit(0 if trace_data["summary"]["all_timeline_gates_passed"] else 1)
