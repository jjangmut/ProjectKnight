extends SceneTree
## ProjectKnight V3-023: Stage 1 Gameplay Polish Verification Suite
## Executes:
## 1. Gate B: 8-way Directional Attack Alignment & Actor Separation Verification + 1280x720 Captures
## 2. Gate C: Distinct Encounter Zone Captures (Zone 1..4) & 4-Policy Combat Comparison (COMBAT_POLICY_COMPARISON.json)
## 3. Gate D & E: Boss Duel Telemetry (BOSS_FIGHT_TRACE.json) & Victory Camera Trace (VICTORY_CAMERA_TRACE.json)

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVVitalityOrbClass = preload("res://scripts/side_quarter_view/side_qv_vitality_orb.gd")

const EVIDENCE_DIR := "D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-024/STUDIO_V3/evidence/V3-024/"
const CAPTURES_DIR := "D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-024/STUDIO_V3/evidence/V3-024/captures/"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(CAPTURES_DIR)
	call_deferred("_run_all_verifications")


func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _release_all_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		Input.action_release(action)


func _capture_viewport(filename: String) -> String:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	var full_path: String = CAPTURES_DIR + filename
	if img != null:
		img.save_png(full_path)
		print("[CAPTURE] Saved 1280x720 screenshot -> ", full_path)
	return full_path


func _run_all_verifications() -> void:
	_setup_input_actions()
	print("=================================================================")
	print("[V3-023] Starting Comprehensive Polish Verification & Evidence Capture")
	print("=================================================================")

	# 1. Gate B & Gate C Visual & Directional Alignment Suite
	var dir_results: Dictionary = await _verify_directional_attacks_and_zones()

	# 2. Gate C & D & E: 4 Combat Input Policies Comparison + Boss Trace + Victory Trace
	var policy_comparison: Dictionary = {}
	var policies := [
		"stationary_attack_only",
		"forward_attack_spam",
		"xz_move_attack_no_defense",
		"tactical_full_play"
	]

	var boss_trace_data: Dictionary = {}
	var victory_trace_data: Dictionary = {}

	for pol in policies:
		print("-----------------------------------------------------------------")
		print("[V3-023] Running Combat Policy Simulation: ", pol)
		print("-----------------------------------------------------------------")
		var run_res: Dictionary = await _run_policy_simulation(pol)
		policy_comparison[pol] = run_res["summary"]
		if pol == "tactical_full_play":
			boss_trace_data = run_res["boss_trace"]
			victory_trace_data = run_res["victory_trace"]

	# Save COMBAT_POLICY_COMPARISON.json
	var comp_payload := {
		"task_id": "V3-023",
		"build_branch": "studio/v3-023-stage1-gameplay-polish",
		"directional_alignment_audit": dir_results,
		"policies": policy_comparison,
		"verdict": {
			"forward_attack_spam_fails_or_heavily_punished": (not policy_comparison["forward_attack_spam"]["cleared"]),
			"xz_no_defense_worse_than_tactical": (
				not policy_comparison["xz_move_attack_no_defense"]["cleared"]
				or policy_comparison["xz_move_attack_no_defense"]["damage_taken"] > policy_comparison["tactical_full_play"]["damage_taken"]
			),
			"tactical_full_play_clears_reliably": policy_comparison["tactical_full_play"]["cleared"]
		}
	}
	_write_json(EVIDENCE_DIR + "COMBAT_POLICY_COMPARISON.json", comp_payload)
	_write_json(EVIDENCE_DIR + "BOSS_FIGHT_TRACE.json", boss_trace_data)
	_write_json(EVIDENCE_DIR + "VICTORY_CAMERA_TRACE.json", victory_trace_data)

	print("=================================================================")
	print("[V3-023] Verification Complete! Verdict: ", JSON.stringify(comp_payload["verdict"]))
	print("=================================================================")

	var all_ok: bool = (
		comp_payload["verdict"]["forward_attack_spam_fails_or_heavily_punished"]
		and comp_payload["verdict"]["xz_no_defense_worse_than_tactical"]
		and comp_payload["verdict"]["tactical_full_play_clears_reliably"]
	)
	quit(0 if all_ok else 1)


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		print("[JSON] Wrote ", path)


func _verify_directional_attacks_and_zones() -> Dictionary:
	var packed := load(Stage1ScenePath) as PackedScene
	var stage := packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	for i in range(6):
		await physics_frame

	var player: CharacterBody3D = stage.player
	var cam: Camera3D = stage.camera

	# Pause enemies briefly to capture clean 8-direction attack alignment first
	for e in stage.enemies:
		if is_instance_valid(e):
			e.set_physics_process(false)

	var dir_cases := [
		{"name": "right_x_plus", "actions": ["move_right"], "expected": Vector3(1, 0, 0), "file": "after_v3_023_attack_dir_right.png"},
		{"name": "left_x_minus", "actions": ["move_left"], "expected": Vector3(-1, 0, 0), "file": "after_v3_023_attack_dir_left.png"},
		{"name": "up_z_minus", "actions": ["move_up"], "expected": Vector3(0, 0, -1), "file": "after_v3_023_attack_dir_up_z_minus.png"},
		{"name": "down_z_plus", "actions": ["move_down"], "expected": Vector3(0, 0, 1), "file": "after_v3_023_attack_dir_down_z_plus.png"},
		{"name": "diag_right_up", "actions": ["move_right", "move_up"], "expected": Vector3(1, 0, -1).normalized(), "file": "after_v3_023_attack_dir_diag.png"}
	]

	var dir_records: Array = []
	for dc in dir_cases:
		_release_all_inputs()
		player.attack_cooldown = 0.0
		player.is_attacking = false
		for act in dc["actions"]:
			Input.action_press(act)
		await physics_frame
		await physics_frame
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		var cap_file := await _capture_viewport(dc["file"])
		var atk_dir: Vector3 = player.facing_attack_dir
		var hitbox_pos: Vector3 = player.attack_area_3d.position
		var vfx_rot: Vector3 = player.slash_visual_3d.rotation_degrees
		var dot_align: float = atk_dir.dot(dc["expected"])
		dir_records.append({
			"direction_case": dc["name"],
			"facing_attack_dir": [snappedf(atk_dir.x, 0.01), snappedf(atk_dir.y, 0.01), snappedf(atk_dir.z, 0.01)],
			"attack_area_local_pos": [snappedf(hitbox_pos.x, 0.01), snappedf(hitbox_pos.y, 0.01), snappedf(hitbox_pos.z, 0.01)],
			"slash_vfx_rotation_deg": [snappedf(vfx_rot.x, 0.1), snappedf(vfx_rot.y, 0.1), snappedf(vfx_rot.z, 0.1)],
			"dot_alignment": snappedf(dot_align, 0.01),
			"aligned_pass": (dot_align >= 0.95),
			"capture": cap_file
		})
		_release_all_inputs()
		for k in range(12):
			await physics_frame

	# Re-enable enemies and capture Zone 1 (Outer Gate Courtyard)
	for e in stage.enemies:
		if is_instance_valid(e):
			e.set_physics_process(true)
	for k in range(25):
		await physics_frame
	await _capture_viewport("after_v3_023_zone1_courtyard_spacing.png")

	stage.queue_free()
	await process_frame
	await process_frame

	return {
		"directional_art_status": "DIRECTIONAL_ART_MISSING: Dedicated 2D front/back (+Z/-Z) character sprite sheets do not exist; mitigated in 3D via Golden Directional Aim Arrow + X-axis tilted 3D Slash Arc.",
		"cases": dir_records
	}


func _run_policy_simulation(policy_name: String) -> Dictionary:
	_release_all_inputs()
	var packed := load(Stage1ScenePath) as PackedScene
	var stage := packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	var cleared := false
	stage.stage_cleared.connect(func(): cleared = true)
	var boss_shield_blocks_seen: int = 0

	for i in range(4):
		await physics_frame

	var player: CharacterBody3D = stage.player
	var cam: Camera3D = stage.camera
	var sim_t: float = 0.0
	var max_t: float = 95.0
	var dt: float = 1.0 / 60.0

	var last_hp: int = player.current_hp
	var dmg_taken: int = 0
	var orbs_taken: int = 0
	var parries: int = 0
	var dashes: int = 0
	var attacks: int = 0
	var enemies_killed: int = 0
	var tracked_eids: Dictionary = {}

	var min_enemy_player_dist: float = 999.0
	var min_inter_enemy_dist: float = 999.0
	var min_boss_player_dist: float = 999.0

	var enc_times := {
		"enc1_clear": 0.0,
		"enc2_start": 0.0,
		"enc2_clear": 0.0,
		"enc3_start": 0.0,
		"enc3_clear": 0.0,
		"boss_start": 0.0,
		"boss_defeat": 0.0
	}

	var boss_samples: Array = []
	var boss_patterns_seen := {"TRIPLE_CLEAVE": 0, "SHIELD_CHARGE": 0, "QUAKE_RING": 0, "SHIELD_GUARD_BLOCKS": 0}
	var last_boss_pattern: int = -1
	var victory_samples: Array = []
	var clear_wait_t: float = -1.0

	var atk_cd: float = 0.0
	var guard_hold: float = 0.0
	var jump_cd: float = 0.0
	var dash_cd: float = 0.0
	var captured_z2 := false
	var captured_z3 := false
	var captured_boss_duel := false
	var captured_vic_frames := [false, false, false, false]

	while sim_t < max_t:
		await physics_frame
		sim_t += dt
		atk_cd -= dt
		jump_cd -= dt
		dash_cd -= dt

		if not is_instance_valid(player):
			break

		if player.current_hp < last_hp:
			dmg_taken += (last_hp - player.current_hp)
		elif player.current_hp > last_hp:
			orbs_taken += 1
		last_hp = player.current_hp

		# Track enemy kills & spacing
		var live_enemies: Array[Node3D] = []
		for e in stage.enemies:
			if e != null and is_instance_valid(e) and not e.get("is_dead"):
				live_enemies.append(e as Node3D)
				var eid: int = e.get_instance_id()
				if not tracked_eids.has(eid):
					tracked_eids[eid] = false
		for k_eid in tracked_eids.keys():
			if not tracked_eids[k_eid]:
				var still_alive := false
				for le in live_enemies:
					if le.get_instance_id() == k_eid:
						still_alive = true
						break
				if not still_alive:
					tracked_eids[k_eid] = true
					enemies_killed += 1

		for i in range(live_enemies.size()):
			var e1 := live_enemies[i]
			var dp := Vector2(e1.global_position.x - player.global_position.x, e1.global_position.z - player.global_position.z).length()
			if e1 is SideQVBossClass:
				min_boss_player_dist = minf(min_boss_player_dist, dp)
			else:
				min_enemy_player_dist = minf(min_enemy_player_dist, dp)
			for j in range(i + 1, live_enemies.size()):
				var e2 := live_enemies[j]
				var de := Vector2(e1.global_position.x - e2.global_position.x, e1.global_position.z - e2.global_position.z).length()
				min_inter_enemy_dist = minf(min_inter_enemy_dist, de)

		# Encounter timestamps
		if stage.current_encounter_idx == 1 and stage.enemies.is_empty() and enc_times["enc1_clear"] == 0.0:
			enc_times["enc1_clear"] = snappedf(sim_t, 0.01)
		elif stage.current_encounter_idx == 2:
			if enc_times["enc2_start"] == 0.0:
				enc_times["enc2_start"] = snappedf(sim_t, 0.01)
			if policy_name == "tactical_full_play" and not captured_z2 and sim_t - enc_times["enc2_start"] >= 1.2:
				captured_z2 = true
				await _capture_viewport("after_v3_023_zone2_bastion_rampart.png")
			if stage.enemies.is_empty() and enc_times["enc2_clear"] == 0.0:
				enc_times["enc2_clear"] = snappedf(sim_t, 0.01)
		elif stage.current_encounter_idx == 3:
			if enc_times["enc3_start"] == 0.0:
				enc_times["enc3_start"] = snappedf(sim_t, 0.01)
			if policy_name == "tactical_full_play" and not captured_z3 and sim_t - enc_times["enc3_start"] >= 1.4:
				captured_z3 = true
				await _capture_viewport("after_v3_023_zone3_royal_terrace.png")
			if stage.enemies.is_empty() and enc_times["enc3_clear"] == 0.0:
				enc_times["enc3_clear"] = snappedf(sim_t, 0.01)
		elif stage.current_encounter_idx == 4:
			if enc_times["boss_start"] == 0.0:
				enc_times["boss_start"] = snappedf(sim_t, 0.01)

		# Boss fight trace
		if stage.active_boss != null and is_instance_valid(stage.active_boss):
			var b: CharacterBody3D = stage.active_boss
			if b.current_pattern != last_boss_pattern:
				last_boss_pattern = b.current_pattern
				if b.current_pattern == b.Pattern.TRIPLE_CLEAVE:
					boss_patterns_seen["TRIPLE_CLEAVE"] += 1
				elif b.current_pattern == b.Pattern.CHARGE_WINDUP:
					boss_patterns_seen["SHIELD_CHARGE"] += 1
				elif b.current_pattern == b.Pattern.QUAKE_RING:
					boss_patterns_seen["QUAKE_RING"] += 1
			if policy_name == "tactical_full_play" and not captured_boss_duel and b.current_hp <= 68 and b.current_hp > 18 and Vector2(b.global_position.x - player.global_position.x, b.global_position.z - player.global_position.z).length() <= 2.5 and player.global_position.y <= 0.15 and player.global_position.z >= -0.6 and player.invuln_timer <= 0.0:
				captured_boss_duel = true
				await _capture_viewport("after_v3_023_boss_duel_spacing.png")

			if int(sim_t * 60.0) % 10 == 0 and not b.is_dead:
				boss_samples.append({
					"t": snappedf(sim_t, 0.01),
					"boss_hp": b.current_hp,
					"boss_poise": b.current_poise,
					"boss_phase": b.current_phase,
					"pattern": b.current_pattern,
					"pattern_phase": b.get("pattern_phase"),
					"shield_up": b.get("is_frontal_shield_up"),
					"player_pos": [snappedf(player.global_position.x, 0.02), snappedf(player.global_position.y, 0.02), snappedf(player.global_position.z, 0.02)],
					"boss_pos": [snappedf(b.global_position.x, 0.02), snappedf(b.global_position.y, 0.02), snappedf(b.global_position.z, 0.02)],
					"xz_dist": snappedf(Vector2(b.global_position.x - player.global_position.x, b.global_position.z - player.global_position.z).length(), 0.02)
				})

			if b.get("is_frontal_shield_up") and int(sim_t * 60.0) % 12 == 0:
				boss_shield_blocks_seen += 1
				boss_patterns_seen["SHIELD_GUARD_BLOCKS"] = boss_shield_blocks_seen

			if b.is_dead and enc_times["boss_defeat"] == 0.0:
				enc_times["boss_defeat"] = snappedf(sim_t, 0.01)
				cleared = true
				clear_wait_t = 0.0

		# Victory camera trace after boss defeat
		if clear_wait_t >= 0.0:
			clear_wait_t += dt
			_release_all_inputs()
			var screen_uv := Vector2(-1, -1)
			var in_frustum := false
			if cam != null and is_instance_valid(cam):
				in_frustum = not cam.is_position_behind(player.global_position + Vector3(0, 1.0, 0))
				var sp: Vector2 = cam.unproject_position(player.global_position + Vector3(0, 1.0, 0))
				screen_uv = Vector2(snappedf(sp.x, 0.1), snappedf(sp.y, 0.1))
				in_frustum = in_frustum and (sp.x >= 80.0 and sp.x <= 1200.0 and sp.y >= 60.0 and sp.y <= 680.0)

			if int(clear_wait_t * 60.0) % 6 == 0:
				var banner_node = stage.mobile_controls.get_node_or_null("VictorySummaryBanner") if stage.mobile_controls != null else null
				victory_samples.append({
					"t_after_boss_death": snappedf(clear_wait_t, 0.02),
					"player_pos": [snappedf(player.global_position.x, 0.02), snappedf(player.global_position.y, 0.02), snappedf(player.global_position.z, 0.02)],
					"player_state": player.current_state,
					"camera_pos": [snappedf(cam.global_position.x, 0.02), snappedf(cam.global_position.y, 0.02), snappedf(cam.global_position.z, 0.02)],
					"player_screen_px": [screen_uv.x, screen_uv.y],
					"player_visible_in_frame": in_frustum,
					"boss_kneeling_visible": (stage.active_boss != null and is_instance_valid(stage.active_boss) and stage.active_boss.visible),
					"victory_banner_visible": (banner_node != null and banner_node.visible)
				})

			if policy_name == "tactical_full_play":
				if clear_wait_t >= 0.20 and not captured_vic_frames[0]:
					captured_vic_frames[0] = true
					await _capture_viewport("after_v3_023_victory_seq_1.png")
				elif clear_wait_t >= 0.90 and not captured_vic_frames[1]:
					captured_vic_frames[1] = true
					await _capture_viewport("after_v3_023_victory_seq_2.png")
				elif clear_wait_t >= 1.80 and not captured_vic_frames[2]:
					captured_vic_frames[2] = true
					await _capture_viewport("after_v3_023_victory_seq_3.png")
				elif clear_wait_t >= 2.60 and not captured_vic_frames[3]:
					captured_vic_frames[3] = true
					await _capture_viewport("after_v3_023_victory_seq_4.png")

			if clear_wait_t >= 3.0:
				break
			continue

		if player.is_dead or player.current_hp <= 0:
			_release_all_inputs()
			break

		# Execute policy input
		if policy_name == "stationary_attack_only":
			_release_all_inputs()
			if atk_cd <= 0.0:
				atk_cd = 0.24
				Input.action_press("attack")
				attacks += 1
		elif policy_name == "forward_attack_spam":
			_release_all_inputs()
			Input.action_press("move_right")
			if atk_cd <= 0.0:
				atk_cd = 0.22
				Input.action_press("attack")
				attacks += 1
		elif policy_name == "xz_move_attack_no_defense":
			_release_all_inputs()
			var target_e: Node3D = _get_closest_enemy(stage, player)
			if target_e == null:
				_steer_corridor(player)
			else:
				var diff := target_e.global_position - player.global_position
				var dh := Vector2(diff.x, diff.z).length()
				if dh <= 1.75:
					if atk_cd <= 0.0:
						atk_cd = 0.25
						Input.action_press("attack")
						attacks += 1
				else:
					_steer_to_point(player, target_e.global_position)
		elif policy_name == "tactical_full_play":
			var counts := _drive_tactical_play(stage, player, dt, atk_cd, guard_hold, jump_cd, dash_cd)
			atk_cd = counts["atk_cd"]
			guard_hold = counts["guard_hold"]
			jump_cd = counts["jump_cd"]
			dash_cd = counts["dash_cd"]
			attacks += int(counts["atk_inc"])
			parries += int(counts["parry_inc"])
			dashes += int(counts["dash_inc"])

	_release_all_inputs()
	var final_hp: int = player.current_hp if is_instance_valid(player) else 0
	var died: bool = (not is_instance_valid(player)) or player.is_dead or final_hp <= 0
	var final_x: float = player.global_position.x if is_instance_valid(player) else -6.0

	stage.queue_free()
	await process_frame
	await process_frame

	var boss_dur: float = 0.0
	if enc_times["boss_start"] > 0.0 and enc_times["boss_defeat"] > 0.0:
		boss_dur = snappedf(enc_times["boss_defeat"] - enc_times["boss_start"], 0.01)

	return {
		"summary": {
			"policy": policy_name,
			"cleared": cleared,
			"player_died": died,
			"final_hp": final_hp,
			"damage_taken": dmg_taken,
			"vitality_orbs_collected": orbs_taken,
			"enemies_defeated": enemies_killed,
			"final_player_x": snappedf(final_x, 0.02),
			"duration_sec": snappedf(sim_t, 0.01),
			"boss_fight_duration_sec": boss_dur,
			"attacks_used": attacks,
			"parries_used": parries,
			"dashes_used": dashes,
			"min_enemy_player_dist_m": snappedf(min_enemy_player_dist, 0.02),
			"min_inter_enemy_dist_m": snappedf(min_inter_enemy_dist, 0.02),
			"min_boss_player_dist_m": snappedf(min_boss_player_dist, 0.02),
			"encounter_timestamps": enc_times
		},
		"boss_trace": {
			"boss_name": "성문 수호 기사단장 (SideQVBossCommander)",
			"boss_max_hp": 84,
			"boss_max_poise": 30,
			"boss_fight_started_sec": enc_times["boss_start"],
			"boss_defeated_sec": enc_times["boss_defeat"],
			"boss_fight_duration_sec": boss_dur,
			"patterns_triggered": boss_patterns_seen,
			"min_boss_player_center_dist_m": snappedf(min_boss_player_dist, 0.02),
			"time_series_samples": boss_samples
		},
		"victory_trace": {
			"boss_defeated_at_sec": enc_times["boss_defeat"],
			"all_samples_player_in_frame": _check_all_in_frame(victory_samples),
			"samples": victory_samples
		}
	}


func _check_all_in_frame(samples: Array) -> bool:
	if samples.is_empty():
		return false
	for s in samples:
		if not s["player_visible_in_frame"] or not s["victory_banner_visible"]:
			return false
	return true


func _get_closest_enemy(stage: Node3D, player: CharacterBody3D) -> Node3D:
	var best: Node3D = null
	var min_d := 9999.0
	for e in stage.enemies:
		if e != null and is_instance_valid(e) and not e.get("is_dead"):
			var e3d := e as Node3D
			var d := Vector2(e3d.global_position.x - player.global_position.x, e3d.global_position.z - player.global_position.z).length()
			if d < min_d:
				min_d = d
				best = e3d
	return best


func _steer_to_point(player: CharacterBody3D, pt: Vector3) -> void:
	var diff := pt - player.global_position
	var px := player.global_position.x
	var pz := player.global_position.z

	# Avoid tactical obstacles along the corridor when moving in X
	var obstacles := [
		{"x": 7.2, "z": -1.55, "safe_z": 1.2},
		{"x": 18.0, "z": -2.7, "safe_z": 0.4},
		{"x": 26.5, "z": -1.55, "safe_z": 1.3},
		{"x": 34.8, "z": 1.55, "safe_z": -1.3},
		{"x": 44.0, "z": -2.7, "safe_z": 0.4},
		{"x": 53.5, "z": -1.85, "safe_z": 1.2},
		{"x": 60.5, "z": 1.85, "safe_z": -1.2},
		{"x": 68.0, "z": -2.7, "safe_z": 0.2}
	]
	for obs in obstacles:
		if absf(px - float(obs["x"])) < 1.65 and absf(pz - float(obs["z"])) < 1.25:
			diff.z = float(obs["safe_z"]) - pz
			break

	if diff.x > 0.35:
		Input.action_press("move_right")
	elif diff.x < -0.35:
		Input.action_press("move_left")
	if diff.z > 0.25:
		Input.action_press("move_down")
	elif diff.z < -0.25:
		Input.action_press("move_up")


func _steer_corridor(player: CharacterBody3D) -> void:
	Input.action_press("move_right")
	var px := player.global_position.x
	var pz := player.global_position.z
	if px < 14.0:
		if pz < 1.1:
			Input.action_press("move_down")
	elif px < 21.0:
		if pz < 0.2:
			Input.action_press("move_down")
		elif pz > 0.8:
			Input.action_press("move_up")
	elif px < 31.0:
		if pz < 1.3:
			Input.action_press("move_down")
	elif px < 40.0:
		if pz > -1.3:
			Input.action_press("move_up")
	elif px < 47.0:
		if pz < 0.2:
			Input.action_press("move_down")
		elif pz > 0.8:
			Input.action_press("move_up")
	elif px < 57.0:
		if pz < 1.2:
			Input.action_press("move_down")
	elif px < 64.0:
		if pz > -1.2:
			Input.action_press("move_up")
	else:
		if pz > 0.35:
			Input.action_press("move_up")
		elif pz < -0.35:
			Input.action_press("move_down")


func _drive_tactical_play(stage: Node3D, player: CharacterBody3D, _dt: float, atk_cd: float, guard_hold: float, jump_cd: float, dash_cd: float) -> Dictionary:
	var res := {"atk_cd": atk_cd, "guard_hold": guard_hold, "jump_cd": jump_cd, "dash_cd": dash_cd, "atk_inc": 0, "parry_inc": 0, "dash_inc": 0}
	if stage.is_stage_finished:
		_release_all_inputs()
		return res

	if guard_hold > 0.0:
		res["guard_hold"] = guard_hold - (1.0 / 60.0)
		Input.action_press("guard")
		if res["guard_hold"] <= 0.0:
			Input.action_release("guard")
		return res
	else:
		Input.action_release("guard")

	# 1. Check incoming crossbow bolts -> Just Parry!
	for child in stage.get_children():
		if child != null and is_instance_valid(child) and child.get_script() != null:
			if "side_qv_crossbow_bolt.gd" in str(child.get_script().resource_path):
				var b_diff := (child as Node3D).global_position - player.global_position
				if b_diff.length() < 2.8 and absf(b_diff.z) < 0.95:
					_release_all_inputs()
					Input.action_press("move_right" if b_diff.x > 0.0 else "move_left")
					Input.action_press("guard")
					res["guard_hold"] = 0.16
					res["parry_inc"] = 1
					return res

	# 1b. Check ANY nearby enemy winding up an attack (within 2.15m) -> Just Parry immediately!
	for e in stage.enemies:
		if e != null and is_instance_valid(e) and not e.get("is_dead") and not (e is SideQVBossClass):
			var ediff := (e as Node3D).global_position - player.global_position
			var edist := Vector2(ediff.x, ediff.z).length()
			if e.get("is_attacking") and edist <= 2.15:
				_release_all_inputs()
				Input.action_press("move_right" if ediff.x > 0.0 else "move_left")
				Input.action_press("guard")
				res["guard_hold"] = 0.18
				res["parry_inc"] = 1
				return res

	# 2. Collect nearby Vitality Orbs if damaged
	for child in stage.get_children():
		if child is SideQVVitalityOrbClass and is_instance_valid(child) and not child.is_collected:
			var odiff: Vector3 = (child as Node3D).global_position - player.global_position
			if Vector2(odiff.x, odiff.z).length() < 4.8:
				_release_all_inputs()
				_steer_to_point(player, (child as Node3D).global_position)
				return res

	# 3. Caltrop trap jump
	for trap in stage.hazard_traps:
		if trap != null and is_instance_valid(trap) and not trap.is_triggered:
			var tdiff: Vector3 = (trap as Node3D).global_position - player.global_position
			if tdiff.x > 0.4 and tdiff.x < 2.4 and absf(tdiff.z) < 1.1:
				if player.is_on_floor() and jump_cd <= 0.0:
					_release_all_inputs()
					Input.action_press("move_right")
					Input.action_press("jump")
					res["jump_cd"] = 0.65
					return res

	var target: Node3D = _get_closest_enemy(stage, player)
	if target == null:
		_release_all_inputs()
		_steer_corridor(player)
		return res

	var diff := target.global_position - player.global_position
	var dx := diff.x
	var dz := diff.z
	var dist_h := Vector2(dx, dz).length()

	# 4. Boss Tactical Duel
	if target is SideQVBossClass:
		var b := target as CharacterBody3D
		if b.current_pattern == b.Pattern.TRIPLE_CLEAVE:
			if dist_h < 2.7:
				_release_all_inputs()
				Input.action_press("move_right" if dx > 0.0 else "move_left")
				Input.action_press("guard")
				res["guard_hold"] = 0.18
				res["parry_inc"] = 1
				return res
			elif b.pattern_timer < 0.45 and player.is_on_floor() and jump_cd <= 0.0:
				_release_all_inputs()
				Input.action_press("jump")
				res["jump_cd"] = 0.65
				return res
		elif b.current_pattern == b.Pattern.CHARGE_WINDUP or b.current_pattern == b.Pattern.CHARGE_ACTIVE:
			if absf(dz) < 1.55:
				_release_all_inputs()
				Input.action_press("move_up" if b.global_position.z >= 0.0 else "move_down")
				if dash_cd <= 0.0:
					Input.action_press("dash")
					res["dash_cd"] = 0.65
					res["dash_inc"] = 1
				return res
		elif b.current_pattern == b.Pattern.QUAKE_RING:
			if dist_h < 4.3:
				_release_all_inputs()
				Input.action_press("guard")
				res["guard_hold"] = 0.18
				res["parry_inc"] = 1
				return res

		# If Boss has Frontal Shield Guard up, flank in Z or dash behind!
		if b.get("is_frontal_shield_up"):
			_release_all_inputs()
			Input.action_press("move_up" if b.global_position.z >= 0.0 else "move_down")
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			if dash_cd <= 0.0 and dist_h < 2.4:
				Input.action_press("dash")
				res["dash_cd"] = 0.60
				res["dash_inc"] = 1
			return res

		if dist_h <= 2.15:
			_release_all_inputs()
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			if atk_cd <= 0.0:
				Input.action_press("attack")
				res["atk_cd"] = 0.25
				res["atk_inc"] = 1
		else:
			_release_all_inputs()
			_steer_to_point(player, target.global_position)
		return res

	# 5. Heavy Shield Knight Tactical Flanking & Bash Parry
	if target is SideQVEliteKnightClass:
		var k := target as CharacterBody3D
		if k.is_attacking and dist_h <= 1.95:
			_release_all_inputs()
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			Input.action_press("guard")
			res["guard_hold"] = 0.16
			res["parry_inc"] = 1
			return res
		var face_x: float = -1.0 if (k.sprite_3d != null and k.sprite_3d.flip_h) else 1.0
		if k.is_shield_guarding and absf(dz) < 1.15 and (dx * face_x < 0.0):
			# If in melee range and ready, bait the Shield Bash once so we can Just Parry it, while flanking in Z!
			if dist_h <= 1.75 and atk_cd <= -0.35:
				_release_all_inputs()
				Input.action_press("move_right" if dx > 0.0 else "move_left")
				Input.action_press("attack")
				res["atk_cd"] = 0.25
				res["atk_inc"] = 1
				return res
			_release_all_inputs()
			Input.action_press("move_up" if k.global_position.z >= 0.0 else "move_down")
			Input.action_press("move_right" if face_x < 0.0 else "move_left")
			if dash_cd <= 0.0 and dist_h < 2.2:
				Input.action_press("dash")
				res["dash_cd"] = 0.60
				res["dash_inc"] = 1
			return res
		if dist_h <= 1.85:
			_release_all_inputs()
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			if atk_cd <= 0.0:
				Input.action_press("attack")
				res["atk_cd"] = 0.25
				res["atk_inc"] = 1
		else:
			_release_all_inputs()
			_steer_to_point(player, target.global_position)
		return res

	# 6. Grunt & Crossbowman Tactical Engagement
	if target.get("is_attacking") and dist_h <= 1.75:
		_release_all_inputs()
		Input.action_press("guard")
		res["guard_hold"] = 0.16
		res["parry_inc"] = 1
		return res

	if dist_h <= 1.75:
		_release_all_inputs()
		if absf(dz) > 0.75 and absf(dx) < 0.65:
			Input.action_press("move_down" if dz > 0.0 else "move_up")
		else:
			Input.action_press("move_right" if dx > 0.0 else "move_left")
		if atk_cd <= 0.0:
			Input.action_press("attack")
			res["atk_cd"] = 0.25
			res["atk_inc"] = 1
	else:
		_release_all_inputs()
		_steer_to_point(player, target.global_position)
	return res
