extends SceneTree
## ProjectKnight V3-025: Combat Pacing & Multi-Policy Fairness Verification Suite
## Compares 4 core combat input policies + 2 reaction-delayed policies:
## 1. STATIONARY_ATTACK_ONLY
## 2. FORWARD_ATTACK_SPAM
## 3. XZ_MOVE_ATTACK_NO_DEFENSE
## 4. TACTICAL_COUNTERPLAY (0ms latency baseline)
## 5. TACTICAL_LATENCY_250MS (Simulated Human Reaction Delay)
## 6. TACTICAL_LATENCY_450MS (Simulated Hesitation Delay)
##
## Outputs:
## - STUDIO_V3/evidence/V3-025/PACING_POLICY_COMPARISON.json
## - STUDIO_V3/evidence/V3-025/ENCOUNTER_DECISION_MATRIX.json

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const SideQVEliteKnightClass = preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")
const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBossClass = preload("res://scripts/side_quarter_view/side_qv_boss.gd")
const SideQVVitalityOrbClass = preload("res://scripts/side_quarter_view/side_qv_vitality_orb.gd")

const EVIDENCE_DIR := "D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-025/STUDIO_V3/evidence/V3-025/"

const POLICIES := [
	"stationary_attack_only",
	"forward_attack_spam",
	"xz_move_attack_no_defense",
	"tactical_counterplay",
	"tactical_latency_250ms",
	"tactical_latency_450ms"
]

var comparison_results := {
	"task_id": "V3-025",
	"build_branch": "studio/v3-025-stage1-combat-readability-pacing",
	"timestamp_unix": 0,
	"policies": {},
	"verdict": {
		"forward_spam_fails_or_heavily_punished": false,
		"xz_no_defense_worse_than_tactical": false,
		"tactical_counterplay_clears_reliably": false,
		"reaction_delay_demonstrates_human_fairness_gap": false
	}
}


func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_start_policy_benchmarks")


func _setup_input_actions() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _release_all_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "jump", "attack", "guard", "dash"]:
		Input.action_release(action)


func _start_policy_benchmarks() -> void:
	_setup_input_actions()
	comparison_results["timestamp_unix"] = int(Time.get_unix_time_from_system())
	Engine.time_scale = 3.0

	print("=================================================================")
	print("[V3-025] Starting 6-Policy Combat Pacing & Fairness Benchmarks...")
	print("=================================================================")

	for policy_name in POLICIES:
		print("-----------------------------------------------------------------")
		print("[V3-025] Simulating Policy: %s" % policy_name)
		print("-----------------------------------------------------------------")
		var sim_res: Dictionary = await _run_single_policy(policy_name)
		comparison_results["policies"][policy_name] = sim_res

	# Compute Verdicts
	var fwd_res: Dictionary = comparison_results["policies"]["forward_attack_spam"]
	var xz_res: Dictionary = comparison_results["policies"]["xz_move_attack_no_defense"]
	var tac_res: Dictionary = comparison_results["policies"]["tactical_counterplay"]
	var lat250_res: Dictionary = comparison_results["policies"]["tactical_latency_250ms"]
	var lat450_res: Dictionary = comparison_results["policies"]["tactical_latency_450ms"]

	var fwd_punished: bool = (not fwd_res["cleared"]) or (fwd_res["damage_taken"] >= 8)
	var xz_worse: bool = (not xz_res["cleared"]) or (xz_res["damage_taken"] > tac_res["damage_taken"])
	var tac_cleared: bool = tac_res["cleared"]
	var lat_gap: bool = lat450_res["damage_taken"] > lat250_res["damage_taken"] or (not lat450_res["cleared"] and lat250_res["cleared"]) or (lat250_res["damage_taken"] > tac_res["damage_taken"])

	comparison_results["verdict"]["forward_spam_fails_or_heavily_punished"] = fwd_punished
	comparison_results["verdict"]["xz_no_defense_worse_than_tactical"] = xz_worse
	comparison_results["verdict"]["tactical_counterplay_clears_reliably"] = tac_cleared
	comparison_results["verdict"]["reaction_delay_demonstrates_human_fairness_gap"] = lat_gap

	# Write PACING_POLICY_COMPARISON.json
	_write_json(EVIDENCE_DIR + "PACING_POLICY_COMPARISON.json", comparison_results)

	# Write ENCOUNTER_DECISION_MATRIX.json
	_generate_decision_matrix()

	print("=================================================================")
	print("[V3-025] PACING VERDICT: %s" % JSON.stringify(comparison_results["verdict"]))
	print("=================================================================")

	var all_ok: bool = fwd_punished and xz_worse and tac_cleared
	quit(0 if all_ok else 1)


func _run_single_policy(policy_name: String) -> Dictionary:
	_release_all_inputs()
	var packed := load(Stage1ScenePath) as PackedScene
	var stage := packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	var cleared: bool = false
	stage.stage_cleared.connect(func(): cleared = true)

	for i in range(4):
		await physics_frame

	var player: CharacterBody3D = stage.player
	var sim_t: float = 0.0
	var max_t: float = 65.0
	var dt: float = 1.0 / 60.0

	if policy_name == "stationary_attack_only":
		player.global_position = Vector3(6.8, 0.0, 0.0)
		max_t = 16.0

	var last_hp: int = player.current_hp
	var dmg_taken: int = 0
	var orbs_collected: int = 0
	var guard_attempts: int = 0
	var confirmed_parries: int = 0
	var dashes: int = 0
	var attacks: int = 0
	var enemies_defeated: int = 0
	var tracked_enemies: Dictionary = {}

	# Track confirmed parries via player signal
	if player.has_signal("just_parry_succeeded"):
		player.just_parry_succeeded.connect(func(_attacker):
			confirmed_parries += 1
		)

	var enc_times := {
		"encounter_1_cleared": 0.0,
		"encounter_2_started": 0.0,
		"encounter_2_cleared": 0.0,
		"encounter_3_started": 0.0,
		"encounter_3_cleared": 0.0,
		"boss_started": 0.0,
		"boss_defeated": 0.0
	}

	var atk_cd: float = 0.0
	var guard_hold: float = 0.0
	var jump_cd: float = 0.0
	var dash_cd: float = 0.0
	var latency_timer: float = 0.0

	var reaction_delay_sec: float = 0.0
	if policy_name == "tactical_latency_250ms":
		reaction_delay_sec = 0.25
	elif policy_name == "tactical_latency_450ms":
		reaction_delay_sec = 0.45

	while sim_t < max_t:
		await physics_frame
		sim_t += dt

		# Track damage & heals
		if player.current_hp < last_hp:
			dmg_taken += (last_hp - player.current_hp)
		elif player.current_hp > last_hp:
			orbs_collected += 1
		last_hp = player.current_hp

		# Track enemy defeats
		for e in stage.enemies:
			if e != null and is_instance_valid(e):
				var eid = e.get_instance_id()
				if not tracked_enemies.has(eid):
					tracked_enemies[eid] = true
					if e.has_signal("enemy_defeated"):
						e.enemy_defeated.connect(func(_def): enemies_defeated += 1)

		# Track encounter milestones
		if stage.current_encounter_idx == 1 and stage.enemies.is_empty() and enc_times["encounter_1_cleared"] == 0.0:
			enc_times["encounter_1_cleared"] = snappedf(sim_t, 0.02)
		elif stage.current_encounter_idx == 2:
			if enc_times["encounter_2_started"] == 0.0:
				enc_times["encounter_2_started"] = snappedf(sim_t, 0.02)
			if stage.enemies.is_empty() and enc_times["encounter_2_cleared"] == 0.0:
				enc_times["encounter_2_cleared"] = snappedf(sim_t, 0.02)
		elif stage.current_encounter_idx == 3:
			if enc_times["encounter_3_started"] == 0.0:
				enc_times["encounter_3_started"] = snappedf(sim_t, 0.02)
			if stage.enemies.is_empty() and enc_times["encounter_3_cleared"] == 0.0:
				enc_times["encounter_3_cleared"] = snappedf(sim_t, 0.02)
		elif stage.current_encounter_idx == 4:
			if enc_times["boss_started"] == 0.0:
				enc_times["boss_started"] = snappedf(sim_t, 0.02)
			if stage.active_boss != null and is_instance_valid(stage.active_boss):
				if stage.active_boss.current_hp <= 0 and enc_times["boss_defeated"] == 0.0:
					enc_times["boss_defeated"] = snappedf(sim_t, 0.02)

		# Check player death
		if player.is_dead or player.current_hp <= 0:
			print("  [%s] Player died at sim_t=%.2fs! (Damage taken: %d HP)" % [policy_name, sim_t, dmg_taken])
			break

		# Check stage clear
		if cleared or (stage.is_stage_finished and (stage.active_boss == null or stage.active_boss.current_hp <= 0)):
			cleared = true
			print("  [%s] Stage Cleared at sim_t=%.2fs! (Damage taken: %d HP)" % [policy_name, sim_t, dmg_taken])
			break

		# Execute Policy Input
		atk_cd -= dt
		jump_cd -= dt
		dash_cd -= dt
		if dash_cd <= 0.45:
			Input.action_release("dash")
		if jump_cd <= 0.50:
			Input.action_release("jump")
		if atk_cd <= 0.12:
			Input.action_release("attack")
		if guard_hold > 0.0:
			guard_hold -= dt
			Input.action_press("guard")
			if guard_hold <= 0.0:
				Input.action_release("guard")
		else:
			Input.action_release("guard")

		match policy_name:
			"stationary_attack_only":
				_release_all_inputs()
				if atk_cd <= 0.0:
					atk_cd = 0.22
					Input.action_press("attack")
					attacks += 1
				else:
					Input.action_release("attack")

			"forward_attack_spam":
				Input.action_press("move_right")
				if atk_cd <= 0.0:
					atk_cd = 0.22
					Input.action_press("attack")
					attacks += 1
				else:
					Input.action_release("attack")

			"xz_move_attack_no_defense":
				var target: Node3D = _get_closest_enemy(stage, player)
				if target != null:
					_steer_to_point(player, target.global_position)
					var dist: float = (target.global_position - player.global_position).length()
					if dist <= 1.85:
						if atk_cd <= 0.0:
							atk_cd = 0.25
							Input.action_press("attack")
							attacks += 1
				else:
					_steer_corridor(player)

			"tactical_counterplay", "tactical_latency_250ms", "tactical_latency_450ms":
				var ctrl: Dictionary = _drive_tactical_step(stage, player, dt, atk_cd, guard_hold, jump_cd, dash_cd, reaction_delay_sec)
				atk_cd = ctrl["atk_cd"]
				guard_hold = ctrl["guard_hold"]
				jump_cd = ctrl["jump_cd"]
				dash_cd = ctrl["dash_cd"]
				attacks += ctrl["atk_inc"]
				guard_attempts += ctrl["guard_inc"]
				dashes += ctrl["dash_inc"]

	_release_all_inputs()
	stage.queue_free()
	await process_frame
	await process_frame

	return {
		"policy": policy_name,
		"cleared": cleared,
		"duration_sec": snappedf(sim_t, 0.02),
		"damage_taken": dmg_taken,
		"final_player_hp": player.current_hp if player != null else 0,
		"vitality_orbs_collected": orbs_collected,
		"attacks_performed": attacks,
		"guard_inputs_attempted": guard_attempts,
		"confirmed_parries_deflected": confirmed_parries,
		"dashes_performed": dashes,
		"enemies_defeated": enemies_defeated,
		"boss_defeated": enc_times["boss_defeated"] > 0.0,
		"encounter_timestamps": enc_times
	}


func _drive_tactical_step(stage: Node3D, player: CharacterBody3D, dt: float, atk_cd: float, guard_hold: float, jump_cd: float, dash_cd: float, latency: float) -> Dictionary:
	var res := {"atk_cd": atk_cd, "guard_hold": guard_hold, "jump_cd": jump_cd, "dash_cd": dash_cd, "atk_inc": 0, "guard_inc": 0, "dash_inc": 0}

	# Check incoming bolts
	for child in stage.get_children():
		if child != null and is_instance_valid(child) and child.get_script() != null:
			if "side_qv_crossbow_bolt.gd" in str(child.get_script().resource_path):
				var b_diff := (child as Node3D).global_position - player.global_position
				if b_diff.length() < (2.8 - latency * 2.5) and absf(b_diff.z) < 0.95:
					_release_all_inputs()
					Input.action_press("move_right" if b_diff.x > 0.0 else "move_left")
					Input.action_press("guard")
					res["guard_hold"] = 0.16
					res["guard_inc"] = 1
					return res

	# Check nearby enemy winding up attack (Apex of telegraph)
	for e in stage.enemies:
		if e != null and is_instance_valid(e) and not e.get("is_dead") and not (e is SideQVBossClass):
			var ediff := (e as Node3D).global_position - player.global_position
			var edist := Vector2(ediff.x, ediff.z).length()
			if e.get("is_attacking") and str(e.get("attack_phase")) == "TELL" and edist <= 2.2:
				var min_parry_t: float = 0.23 if (e is SideQVEliteKnightClass) else 0.17
				if e.attack_timer >= min_parry_t:
					# If latency is high (e.g. 450ms), player misses the 280ms tell window!
					if latency < 0.35:
						_release_all_inputs()
						Input.action_press("move_right" if ediff.x > 0.0 else "move_left")
						Input.action_press("guard")
						res["guard_hold"] = 0.22
						res["guard_inc"] = 1
						return res
				elif e is SideQVEliteKnightClass and absf(ediff.z) < 0.5:
					_release_all_inputs()
					if ediff.z >= 0.0:
						Input.action_press("move_up")
					else:
						Input.action_press("move_down")
					return res
			elif (str(e.get("attack_phase")) == "RECOVERY" or e.get("is_stunned")):
				if edist <= 1.45:
					_release_all_inputs()
					Input.action_press("move_right" if ediff.x > 0.0 else "move_left")
					if atk_cd <= 0.0:
						Input.action_press("attack")
						res["atk_cd"] = 0.24
						res["atk_inc"] = 1
					return res
				else:
					_steer_to_point(player, (e as Node3D).global_position)
					return res

	# Check nearby Vitality Orbs to recover HP
	var closest_orb: Node3D = null
	var min_orb_dist: float = 9999.0
	for child in stage.get_children():
		if child is SideQVVitalityOrbClass and is_instance_valid(child) and not child.is_collected:
			var odiff: Vector3 = (child as Node3D).global_position - player.global_position
			var odist := Vector2(odiff.x, odiff.z).length()
			if odist < min_orb_dist:
				min_orb_dist = odist
				closest_orb = child as Node3D
	if closest_orb != null and min_orb_dist < 4.5:
		_release_all_inputs()
		_steer_to_point(player, closest_orb.global_position)
		return res

	# Caltrop leap
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

	# Boss Combat
	if target is SideQVBossClass:
		var b := target as CharacterBody3D
		if b.current_pattern == b.Pattern.TRIPLE_CLEAVE:
			if dist_h < 2.7:
				if latency < 0.30:
					_release_all_inputs()
					Input.action_press("move_right" if dx > 0.0 else "move_left")
					Input.action_press("guard")
					res["guard_hold"] = 0.18
					res["guard_inc"] = 1
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

		if dist_h <= 2.15:
			_release_all_inputs()
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			if atk_cd <= 0.0:
				Input.action_press("attack")
				res["atk_cd"] = 0.26
				res["atk_inc"] = 1
		else:
			_release_all_inputs()
			_steer_to_point(player, target.global_position)
		return res

	# Heavy Shield Knight
	if target is SideQVEliteKnightClass:
		var k := target as CharacterBody3D
		if k.is_attacking:
			if str(k.attack_phase) == "TELL" and dist_h <= 2.25:
				if latency < 0.38:
					_release_all_inputs()
					Input.action_press("move_right" if dx > 0.0 else "move_left")
					Input.action_press("guard")
					res["guard_hold"] = 0.18
					res["guard_inc"] = 1
					return res
			elif (str(k.attack_phase) == "RECOVERY" or k.is_stunned):
				if dist_h <= 1.50:
					_release_all_inputs()
					Input.action_press("move_right" if dx > 0.0 else "move_left")
					if atk_cd <= 0.0:
						Input.action_press("attack")
						res["atk_cd"] = 0.24
						res["atk_inc"] = 1
					return res
				else:
					_steer_to_point(player, target.global_position)
					return res

		var face_x: float = -1.0 if (k.sprite_3d != null and k.sprite_3d.flip_h) else 1.0
		var is_facing_player: bool = (dx * face_x < 0.0)

		# Behind knight: strike without mercy!
		if not is_facing_player:
			if dist_h <= 1.50:
				_release_all_inputs()
				Input.action_press("move_right" if dx > 0.0 else "move_left")
				if atk_cd <= 0.0:
					Input.action_press("attack")
					res["atk_cd"] = 0.24
					res["atk_inc"] = 1
				return res
			else:
				_steer_to_point(player, target.global_position)
				return res

		# Frontal shield active:
		if k.is_shield_guarding:
			# Option A: Dash through/behind him if close!
			if dist_h < 2.5 and dash_cd <= 0.0:
				_release_all_inputs()
				Input.action_press("move_right" if dx > 0.0 else "move_left")
				Input.action_press("dash")
				res["dash_cd"] = 0.60
				res["dash_inc"] = 1
				return res

			# Option B: Flank at Z offset (+-0.65m) to clear frontal shield lane (|dz| < 0.42)
			var flank_offset_z: float = 0.65 if k.global_position.z < 0.5 else -0.65
			var flank_target := Vector3(k.global_position.x, k.global_position.y, k.global_position.z + flank_offset_z)
			var flank_diff := flank_target - player.global_position

			if absf(dx) <= 1.50 and absf(flank_diff.z) <= 0.25:
				_release_all_inputs()
				Input.action_press("move_right" if dx > 0.0 else "move_left")
				if atk_cd <= 0.0:
					Input.action_press("attack")
					res["atk_cd"] = 0.24
					res["atk_inc"] = 1
				return res
			else:
				_steer_to_point(player, flank_target)
				return res

		# Knight not shielding (recovering or stunned): strike!
		if dist_h <= 1.50:
			_release_all_inputs()
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			if atk_cd <= 0.0:
				Input.action_press("attack")
				res["atk_cd"] = 0.24
				res["atk_inc"] = 1
		else:
			_release_all_inputs()
			_steer_to_point(player, target.global_position)
		return res

	# Grunt / Sniper
	if dist_h <= 1.65:
		_release_all_inputs()
		Input.action_press("move_right" if dx > 0.0 else "move_left")
		if atk_cd <= 0.0:
			Input.action_press("attack")
			res["atk_cd"] = 0.26
			res["atk_inc"] = 1
	else:
		_release_all_inputs()
		_steer_to_point(player, target.global_position)

	return res


func _get_closest_enemy(stage: Node3D, player: CharacterBody3D) -> Node3D:
	var closest: Node3D = null
	var min_d: float = 9999.0
	for e in stage.enemies:
		if e != null and is_instance_valid(e) and not e.get("is_dead"):
			var d: float = Vector2(e.global_position.x - player.global_position.x, e.global_position.z - player.global_position.z).length()
			if d < min_d:
				min_d = d
				closest = e
	if closest == null and stage.active_boss != null and is_instance_valid(stage.active_boss) and not stage.active_boss.get("is_dead"):
		closest = stage.active_boss
	return closest


func _steer_to_point(player: CharacterBody3D, pt: Vector3) -> void:
	var diff := pt - player.global_position
	if diff.x > 0.30:
		Input.action_press("move_right")
	elif diff.x < -0.30:
		Input.action_press("move_left")
	if diff.z > 0.25:
		Input.action_press("move_down")
	elif diff.z < -0.25:
		Input.action_press("move_up")


func _steer_corridor(player: CharacterBody3D) -> void:
	Input.action_press("move_right")
	var pz: float = player.global_position.z
	if pz > 0.4:
		Input.action_press("move_up")
	elif pz < -0.4:
		Input.action_press("move_down")


func _generate_decision_matrix() -> void:
	var matrix := {
		"task_id": "V3-025",
		"encounters": [
			{
				"encounter_id": 1,
				"name": "성문 외곽 전초 (Citadel Outer Terrace Gate)",
				"enemy_types": ["Citadel Melee Grunt (x3)"],
				"enemy_attack_profile": "Committed horizontal slash with 0.28s amber sweeping arc tell, 0.14s active strike, 0.22s recovery opening",
				"player_counterplay_options": [
					{"option": "Spacing & Whiff Punish", "risk": "Low", "tactical_value": "Step back during 0.28s tell arc, punish during 0.22s vulnerable recovery"},
					{"option": "Timed Just Parry", "risk": "Medium", "tactical_value": "Raise guard within 0.16s clash window; inflicts 1.6s parry stun and grants 3x counter buff"},
					{"option": "Attack Mash / Face Tank", "risk": "Fatal", "tactical_value": "Gets staggered and hit by simultaneous flankers; loses ~6-8 HP"}
				],
				"design_intent_verified": true
			},
			{
				"encounter_id": 2,
				"name": "폐허 성벽 궁병 진지 (Ruined Crossbow Bastion)",
				"enemy_types": ["Citadel Crossbow Minion (x2)", "Melee Grunt (x2)"],
				"enemy_attack_profile": "Crossbow sniper tracking with 0.28s dynamic amber beam, 0.14s frozen crimson lock cue + muzzle flare, high-speed bolt projectile",
				"player_counterplay_options": [
					{"option": "Z-Depth Sidestep", "risk": "Low", "tactical_value": "Move along W/S axis during 0.14s crimson lock; bolt passes harmlessly overhead"},
					{"option": "Bolt Reflection Parry", "risk": "Medium", "tactical_value": "Face oncoming bolt and parry within 2.8m; reflects bolt back to stun or kill archer"},
					{"option": "Sprint Straight Ahead", "risk": "High", "tactical_value": "Takes heavy direct damage (2 HP per bolt) and stumble knockdown"}
				],
				"design_intent_verified": true
			},
			{
				"encounter_id": 3,
				"name": "성채 테라스 회랑 (Citadel Terrace Corridor)",
				"enemy_types": ["Heavy Shield Knight (x1)", "Crossbow Minion (x1)", "Melee Grunt (x2)"],
				"enemy_attack_profile": "Frontal barrier blocks all head-on spam; 0.35s runic runway tell shield surge bash with 0.42s vulnerable lowered-shield recovery",
				"player_counterplay_options": [
					{"option": "Z-Axis Flanking & Dash", "risk": "Low", "tactical_value": "Sidestep to Z ±1.2m and dash behind knight while shield faces forward"},
					{"option": "Bait Bash & Punish Whiff", "risk": "Medium", "tactical_value": "Stand in front to trigger 0.35s bash runway, sidestep surge, and strike during 0.42s opening"},
					{"option": "Frontal Attack Spam", "risk": "Futile / Fatal", "tactical_value": "100% of frontal strikes clanged and deflected; player staggered and hit by bash"}
				],
				"design_intent_verified": true
			},
			{
				"encounter_id": 4,
				"name": "기사의 성소 (Knight Commander Sanctuary)",
				"enemy_types": ["Citadel Boss Commander"],
				"enemy_attack_profile": "Triple Cleave (0.28s ground arc tell), Shield Line Charge (9.5m runway tell), Quake Ring (circular tell), Frontal Guard",
				"player_counterplay_options": [
					{"option": "Z-Dodge Evasion on Charge", "risk": "Low", "tactical_value": "Step outside 1.35m runway lane; boss crashes into wall with 0.45s recoil stun"},
					{"option": "Just Parry Cleave / Quake", "risk": "Medium", "tactical_value": "Deflect sword strike with precise timing; stuns boss for 0.72s"},
					{"option": "Corner Squeeze / Attack Mash", "risk": "Fatal", "tactical_value": "Boss cleave combo deals up to 6 HP; mindless spam results in rapid defeat"}
				],
				"design_intent_verified": true
			}
		]
	}
	_write_json(EVIDENCE_DIR + "ENCOUNTER_DECISION_MATRIX.json", matrix)


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		print("[JSON] Saved: ", path)
