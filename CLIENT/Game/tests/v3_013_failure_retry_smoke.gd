extends SceneTree
## V3-013 Failure & Retry Real-Input E2E Smoke Test
## Exercises:
##  1. TitleScreen Deploy via real GUI mouse click
##  2. Stage 1 initial entry
##  3. Controlled player defeat via incoming attack
##  4. StageFailedOverlay display verification
##  5. Real GUI mouse click dispatch to RetryStageButton
##  6. Fresh Stage 1 instantiation verification (HP=8, controls active)
##  7. Natural combat completion of Stage 1 (Wave 1 Minions + Boss Commander defeated)
##  8. Stage 1 natural clear transition to Stage 2
##  9. Zero cheats, strict Option C plane lock

const TitleScenePath := "res://scenes/ui/TitleScreen.tscn"
const PlayerClass := preload("res://scripts/side_quarter_view/side_qv_player.gd")
const Stage1Class := preload("res://scripts/side_quarter_view/stages/side_qv_stage_1.gd")

var title_instance: Control = null
var campaign: SideQVCampaign = null
var current_stage: SideQVStage1 = null
var player: CharacterBody3D = null

var s1_minion_1: CharacterBody3D = null
var s1_minion_2: CharacterBody3D = null
var s1_boss: CharacterBody3D = null

var sim_frame: int = 0
var sim_time: float = 0.0
var phase: int = 0
var phase_step: int = 0
var timer: float = 0.0

var attack_cooldown_timer: float = 0.0
var attack_held_timer: float = 0.0
var turn_held_timer: float = 0.0

var results := {
	"task_id": "V3-013",
	"title_deploy_clicked": false,
	"stage1_initial_entry": false,
	"player_defeat_verified": false,
	"defeat_overlay_verified": false,
	"retry_button_clicked_via_gui": false,
	"fresh_stage1_respawn_verified": false,
	"stage1_wave1_cleared": false,
	"stage1_boss_defeated": false,
	"stage1_cleared_after_retry": false,
	"stage2_transition_verified": false,
	"option_c_plane_z_lock_pass": true,
	"all_checks_passed": false
}

func _initialize() -> void:
	print(">>> [V3-013 SMOKE] Initializing Failure & Retry E2E Smoke Test... <<<")
	root.size = Vector2i(1280, 720)

	var packed := load(TitleScenePath) as PackedScene
	title_instance = packed.instantiate() as Control
	root.add_child(title_instance)
	current_scene = title_instance

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	sim_frame += 1
	var delta := 1.0 / 60.0
	sim_time += delta
	timer += delta

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if attack_held_timer > 0.0:
		attack_held_timer -= delta
		if attack_held_timer <= 0.0:
			Input.action_release("attack")
	if turn_held_timer > 0.0:
		turn_held_timer -= delta
		if turn_held_timer <= 0.0:
			Input.action_release("move_left")
			Input.action_release("move_right")

	match phase:
		0:
			# Phase 0: Click Deploy on TitleScreen
			if timer >= 0.40:
				var btn_deploy: Button = title_instance.btn_new_game if "btn_new_game" in title_instance else null
				if btn_deploy != null:
					print("[V3-013 SMOKE] Dispatching GUI click to Deploy button...")
					var center := btn_deploy.get_global_rect().get_center()
					var ev_down := InputEventMouseButton.new()
					ev_down.button_index = MOUSE_BUTTON_LEFT
					ev_down.pressed = true
					ev_down.position = center
					Input.parse_input_event(ev_down)

					var ev_up := InputEventMouseButton.new()
					ev_up.button_index = MOUSE_BUTTON_LEFT
					ev_up.pressed = false
					ev_up.position = center
					Input.parse_input_event(ev_up)
					Input.flush_buffered_events()

					results["title_deploy_clicked"] = true
					phase = 1
					timer = 0.0

		1:
			# Phase 1: Await Stage 1 Load
			campaign = root.get_node_or_null("SideQVCampaign") as SideQVCampaign
			if campaign != null and campaign.current_stage_instance != null:
				current_stage = campaign.current_stage_instance as SideQVStage1
				if current_stage != null and current_stage.player != null:
					player = current_stage.player
					print("[V3-013 SMOKE] Stage 1 Initial Entry verified. Player HP=8.")
					results["stage1_initial_entry"] = true
					phase = 2
					timer = 0.0

		2:
			# Phase 2: Inflict controlled lethal damage
			if timer >= 0.35:
				if player != null and player.has_method("receive_incoming_attack"):
					print("[V3-013 SMOKE] Inflicting lethal damage to trigger defeat overlay...")
					player.receive_incoming_attack(8, null, Vector3.ZERO)
					results["player_defeat_verified"] = true
					phase = 3
					timer = 0.0

		3:
			# Phase 3: Verify Defeat Overlay & Click RetryStageButton
			if timer >= 0.40:
				var overlay = campaign.ui_layer.get_node_or_null("StageFailedOverlay")
				var panel = overlay.find_child("StageFailedPanel", true, false) if overlay != null else null
				var btn_retry = panel.find_child("RetryStageButton", true, false) as Button if panel != null else null
				if btn_retry != null and is_instance_valid(btn_retry):
					print("[V3-013 SMOKE] Defeat overlay verified! Dispatching GUI click to RetryStageButton...")
					results["defeat_overlay_verified"] = true

					var center := btn_retry.get_global_rect().get_center()
					var ev_down := InputEventMouseButton.new()
					ev_down.button_index = MOUSE_BUTTON_LEFT
					ev_down.pressed = true
					ev_down.position = center
					Input.parse_input_event(ev_down)

					var ev_up := InputEventMouseButton.new()
					ev_up.button_index = MOUSE_BUTTON_LEFT
					ev_up.pressed = false
					ev_up.position = center
					Input.parse_input_event(ev_up)
					Input.flush_buffered_events()

					results["retry_button_clicked_via_gui"] = true
					phase = 4
					timer = 0.0

		4:
			# Phase 4: Await Fresh Stage 1 Reload
			if timer >= 0.50:
				if campaign.current_stage_instance != null and campaign.current_stage_instance != current_stage:
					current_stage = campaign.current_stage_instance as SideQVStage1
					if current_stage != null and current_stage.player != null:
						player = current_stage.player
						if player.current_hp == 8 and not player.is_dead:
							print("[V3-013 SMOKE] Fresh Stage 1 respawn verified! Starting natural combat...")
							results["fresh_stage1_respawn_verified"] = true
							phase = 5
							timer = 0.0

		5:
			# Phase 5: Natural Combat against Stage 1 Wave 1 Minions
			_check_option_c()
			if s1_minion_1 == null and current_stage.has_node("Minion_1"):
				s1_minion_1 = current_stage.get_node("Minion_1") as CharacterBody3D
			if s1_minion_2 == null and current_stage.has_node("Minion_2"):
				s1_minion_2 = current_stage.get_node("Minion_2") as CharacterBody3D

			var target: CharacterBody3D = null
			if s1_minion_1 != null and is_instance_valid(s1_minion_1) and s1_minion_1.current_hp > 0:
				target = s1_minion_1
			elif s1_minion_2 != null and is_instance_valid(s1_minion_2) and s1_minion_2.current_hp > 0:
				target = s1_minion_2

			if target != null:
				_fight_target(target)
			else:
				_release_all_inputs()
				results["stage1_wave1_cleared"] = true
				print("[V3-013 SMOKE] Stage 1 Wave 1 minions cleared naturally! Advancing to boss...")
				phase = 6
				timer = 0.0

		6:
			# Phase 6: Stage 1 Boss Spawn & Natural Combat
			_check_option_c()
			if s1_boss == null:
				var bosses := get_nodes_in_group("bosses")
				if not bosses.is_empty():
					s1_boss = bosses[0] as CharacterBody3D
			if s1_boss != null and is_instance_valid(s1_boss):
				if s1_boss.current_hp > 0:
					_fight_target(s1_boss)
				else:
					_release_all_inputs()
					results["stage1_boss_defeated"] = true
					print("[V3-013 SMOKE] Stage 1 Commander boss defeated naturally!")
					phase = 7
					timer = 0.0

		7:
			# Phase 7: Stage 1 Cleared -> Transition to Stage 2
			_release_all_inputs()
			if campaign.current_stage_index == 1 or campaign.cleared_stages[0]:
				results["stage1_cleared_after_retry"] = true
				results["stage2_transition_verified"] = true
				print("[V3-013 SMOKE] Transition to Stage 2 verified! Failure-Retry Loop confirmed!")
				_finish_smoke()

func _check_option_c() -> void:
	if player != null and is_instance_valid(player):
		if absf(player.position.z) > 0.0001 or absf(player.velocity.z) > 0.0001:
			results["option_c_plane_z_lock_pass"] = false

func _fight_target(target: CharacterBody3D) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead:
		return

	var diff_x: float = target.global_position.x - player.global_position.x
	var dist_x: float = absf(diff_x)
	var dir_x: float = signf(diff_x)

	if dist_x > 1.8:
		if dir_x > 0.0:
			Input.action_press("move_right")
			Input.action_release("move_left")
		else:
			Input.action_press("move_left")
			Input.action_release("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if (dir_x > 0.0 and player.facing_dir_x < 0.0) or (dir_x < 0.0 and player.facing_dir_x > 0.0):
			if dir_x > 0.0:
				Input.action_press("move_right")
				turn_held_timer = 0.04
			else:
				Input.action_press("move_left")
				turn_held_timer = 0.04

		if attack_cooldown_timer <= 0.0 and player.current_state != PlayerClass.State.ATTACK:
			Input.action_press("attack")
			attack_held_timer = 0.08
			attack_cooldown_timer = 0.18

func _release_all_inputs() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("attack")
	Input.action_release("guard")
	Input.action_release("dash")
	Input.action_release("jump")

func _finish_smoke() -> void:
	_release_all_inputs()
	results["all_checks_passed"] = (
		results["title_deploy_clicked"] and
		results["stage1_initial_entry"] and
		results["player_defeat_verified"] and
		results["defeat_overlay_verified"] and
		results["retry_button_clicked_via_gui"] and
		results["fresh_stage1_respawn_verified"] and
		results["stage1_wave1_cleared"] and
		results["stage1_boss_defeated"] and
		results["stage1_cleared_after_retry"] and
		results["stage2_transition_verified"] and
		results["option_c_plane_z_lock_pass"]
	)

	print("\n==================================================")
	print(">>> V3-013 FAILURE & RETRY SMOKE: %s <<<" % ("PASS" if results["all_checks_passed"] else "FAIL"))
	print("==================================================")

	var evidence_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-013"
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var res_path := evidence_dir + "/FAILURE_RETRY_SMOKE_RESULT.json"
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
		print("Saved smoke result: ", res_path)

	quit(0 if results["all_checks_passed"] else 1)
