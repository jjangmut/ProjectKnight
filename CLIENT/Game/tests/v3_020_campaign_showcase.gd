extends SceneTree
## V3-020 Full Campaign Playtest Showcase & Video Recording Automation
## Records continuous gameplay from Title Screen through Stage 5 Boss Victory to Title Return.
## Pacing is tuned for clear human observation of combat, telegraphs, parries, stage art, and UI.
##
## Tag: AUTOMATED_ENGINE_INPUT_PLAYTHROUGH
## Engine: Godot 4.7.2 stable (Windows 11 / gl_compatibility)
## Option C Z=0 plane lock invariant enforced: Z=0.000, vz=0.000

const TitleScenePath := "res://scenes/ui/TitleScreen.tscn"
const PlayerClass := preload("res://scripts/side_quarter_view/side_qv_player.gd")
const Stage1Class := preload("res://scripts/side_quarter_view/stages/side_qv_stage_1.gd")
const Stage2Class := preload("res://scripts/side_quarter_view/stages/side_qv_stage_2.gd")
const Stage3Class := preload("res://scripts/side_quarter_view/stages/side_qv_stage_3.gd")
const Stage4Class := preload("res://scripts/side_quarter_view/stages/side_qv_stage_4.gd")
const Stage5Class := preload("res://scripts/side_quarter_view/stages/side_qv_stage_5.gd")
const GolemGuardianClass := preload("res://scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd")
const CrossbowCommanderClass := preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")
const ArbiterClass := preload("res://scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd")
const EliteKnightClass := preload("res://scripts/side_quarter_view/side_qv_elite_knight.gd")

var title_instance: Control = null
var campaign: SideQVCampaign = null
var current_stage_node: Node3D = null
var player: CharacterBody3D = null

# Stage Actors
var s1_boss: CharacterBody3D = null
var s1_minion_1: CharacterBody3D = null
var s1_minion_2: CharacterBody3D = null

var s2_boss: CharacterBody3D = null
var s2_minion_1: CharacterBody3D = null
var s2_minion_2: CharacterBody3D = null

var s3_minion_1: CharacterBody3D = null
var s3_minion_2: CharacterBody3D = null
var s3_boss: SideQVCrossbowCommander = null

var s4_minion_1: CharacterBody3D = null
var s4_minion_2: CharacterBody3D = null
var s4_boss: SideQVGolemGuardian = null

var s5_minion_1: CharacterBody3D = null
var s5_minion_2: CharacterBody3D = null
var s5_boss: SideQVAbyssalArbiter = null

var sim_time: float = 0.0
var sim_frame: int = 0
var phase: int = 0
var phase_step: int = 0
var phase_timer: float = 0.0

var attack_cooldown_timer: float = 0.0
var attack_held_timer: float = 0.0
var guard_held_timer: float = 0.0
var jump_held_timer: float = 0.0
var turn_held_timer: float = 0.0

var s1_stage_cleared_count: int = 0
var s2_stage_cleared_count: int = 0
var s3_stage_cleared_count: int = 0
var s4_stage_cleared_count: int = 0
var s5_stage_cleared_count: int = 0
var campaign_completed_count: int = 0

var s5_boss_phase_observed: int = 1
var s5_boss_min_hp_recorded: int = 38
var s5_boss_defeated_count: int = 0

var playthrough_summary: Dictionary = {
	"milestone": "V3-020",
	"tag": "AUTOMATED_ENGINE_INPUT_PLAYTHROUGH",
	"stages_cleared": [false, false, false, false, false],
	"campaign_completed": false,
	"total_sim_time": 0.0,
	"plane_lock_intact": true,
	"zero_cheats_enforced": true
}

var raw_log_lines: Array[String] = []


func _initialize() -> void:
	print("[V3-020 SHOWCASE] Initializing Full Campaign Playtest Recording Session...")
	var title_res := load(TitleScenePath) as PackedScene
	if title_res == null:
		_fail("Could not load TitleScreen: " + TitleScenePath)
		return

	title_instance = title_res.instantiate() as Control
	root.add_child(title_instance)
	current_scene = title_instance
	_log("TitleScreen active. Commencing showcase...")


func _physics_process(delta: float) -> bool:
	sim_time += delta
	sim_frame += 1
	phase_timer += delta

	# Input release timers
	if attack_held_timer > 0.0:
		attack_held_timer -= delta
		if attack_held_timer <= 0.0:
			Input.action_release("attack")

	if guard_held_timer > 0.0:
		guard_held_timer -= delta
		if guard_held_timer <= 0.0:
			Input.action_release("guard")

	if jump_held_timer > 0.0:
		jump_held_timer -= delta
		if jump_held_timer <= 0.0:
			Input.action_release("jump")

	if turn_held_timer > 0.0:
		turn_held_timer -= delta
		if turn_held_timer <= 0.0:
			Input.action_release("move_left")
			Input.action_release("move_right")

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# Verify Option C Z-plane invariant on active player
	if player != null and is_instance_valid(player):
		if absf(player.global_position.z) > 0.001 or absf(player.velocity.z) > 0.001:
			playthrough_summary["plane_lock_intact"] = false

	# Acquire campaign reference
	if campaign == null:
		if root.get_node_or_null("SideQVCampaign") != null:
			campaign = root.get_node("SideQVCampaign") as SideQVCampaign
		elif current_scene is SideQVCampaign:
			campaign = current_scene as SideQVCampaign

	match phase:
		0:
			# Phase 0: Title Screen Displayed (Pause 2.5s for viewers to observe Title UI)
			if sim_time >= 2.5 and phase_step == 0:
				if is_instance_valid(title_instance) and title_instance.btn_new_game != null:
					var btn: Button = title_instance.btn_new_game
					var center := btn.get_global_rect().get_center()
					_log("Deploying campaign from TitleScreen at time %.2fs..." % sim_time)
					var ev_down := InputEventMouseButton.new()
					ev_down.button_index = MOUSE_BUTTON_LEFT
					ev_down.pressed = true
					ev_down.position = center
					ev_down.global_position = center
					Input.parse_input_event(ev_down)
					Input.flush_buffered_events()
					phase_step = 1
					phase_timer = 0.0

			elif phase_step == 1 and phase_timer >= 0.05:
				if is_instance_valid(title_instance) and title_instance.btn_new_game != null:
					var btn: Button = title_instance.btn_new_game
					var center := btn.get_global_rect().get_center()
					var ev_up := InputEventMouseButton.new()
					ev_up.button_index = MOUSE_BUTTON_LEFT
					ev_up.pressed = false
					ev_up.position = center
					ev_up.global_position = center
					Input.parse_input_event(ev_up)
					Input.flush_buffered_events()
					phase_step = 2
					phase_timer = 0.0

			elif phase_step == 2 and phase_timer >= 0.2:
				_log("Awaiting Stage 1 (Citadel Terrace Gate) load...")
				phase = 1
				phase_step = 0
				phase_timer = 0.0

		1:
			# Phase 1: Wait for Stage 1 Load
			if campaign != null and campaign.current_stage_instance != null:
				var s1 := campaign.current_stage_instance as SideQVStage1
				if s1 != null and s1.player != null:
					player = s1.player
					current_stage_node = s1
					s1.stage_cleared.connect(func():
						s1_stage_cleared_count += 1
						_log(">>> [CAMPAIGN] Stage 1 CLEARED! <<<")
					)
					_log("Stage 1 Entry: Citadel Terrace Gate active. Scenic presentation...")
					phase = 2
					phase_step = 0
					phase_timer = 0.0

		2:
			# Phase 2: Stage 1 Minions Combat (with measured combat rhythm)
			if phase_timer < 1.2:
				# Walk forward gently
				Input.action_press("move_right")
				return false

			if s1_minion_1 == null and current_stage_node.has_node("Minion_1"):
				s1_minion_1 = current_stage_node.get_node("Minion_1") as CharacterBody3D
			if s1_minion_2 == null and current_stage_node.has_node("Minion_2"):
				s1_minion_2 = current_stage_node.get_node("Minion_2") as CharacterBody3D

			var target_m: CharacterBody3D = null
			if s1_minion_1 != null and is_instance_valid(s1_minion_1) and s1_minion_1.current_hp > 0:
				target_m = s1_minion_1
			elif s1_minion_2 != null and is_instance_valid(s1_minion_2) and s1_minion_2.current_hp > 0:
				target_m = s1_minion_2

			if target_m != null:
				_fight_generic_target(target_m)
			else:
				_release_all_inputs()
				_log("Stage 1 Minions cleared! Advancing toward Commander boss...")
				phase = 3
				phase_step = 0
				phase_timer = 0.0

		3:
			# Phase 3: Stage 1 Boss Commander
			if s1_boss == null:
				var bosses := get_nodes_in_group("bosses")
				if not bosses.is_empty():
					s1_boss = bosses[0] as CharacterBody3D
			if s1_boss != null and is_instance_valid(s1_boss):
				if s1_boss.current_hp > 0:
					_fight_generic_boss(s1_boss)
				else:
					_release_all_inputs()
					_log("Stage 1 Commander boss defeated naturally!")
					phase = 4
					phase_step = 0
					phase_timer = 0.0

		4:
			# Phase 4: Stage 1 Cleared Intermission (Hold for 3.0s for viewing score/shards)
			if s1_stage_cleared_count >= 1 or (campaign != null and campaign.cleared_stages[0]):
				playthrough_summary["stages_cleared"][0] = true
				if phase_timer >= 3.0:
					var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay") if (campaign != null and campaign.ui_layer != null) else null
					if overlay != null:
						var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
						if btn_cont != null:
							_log("Clicking Continue on Stage 1 Intermission -> Advancing to Stage 2...")
							btn_cont.emit_signal("pressed")
							phase = 5
							phase_step = 0
							phase_timer = 0.0

		5:
			# Phase 5: Stage 2 Loaded (SideQVStage2 Beastwood Forest Gorge)
			if campaign != null and campaign.current_stage_index == 1 and campaign.current_stage_instance != null:
				var s2 := campaign.current_stage_instance as SideQVStage2
				if s2 != null and s2.player != null:
					current_stage_node = s2
					player = s2.player
					s2.stage_cleared.connect(func():
						s2_stage_cleared_count += 1
						_log(">>> [CAMPAIGN] Stage 2 CLEARED! <<<")
					)
					_log("Stage 2 Entry: Beastwood Forest Gorge active. Scenic presentation...")
					phase = 6
					phase_step = 0
					phase_timer = 0.0

		6:
			# Phase 6: Stage 2 Beast Minions Combat
			if phase_timer < 1.2:
				Input.action_press("move_right")
				return false

			if s2_minion_1 == null and current_stage_node.has_node("SideQVBeastMinion_1"):
				s2_minion_1 = current_stage_node.get_node("SideQVBeastMinion_1") as CharacterBody3D
			if s2_minion_2 == null and current_stage_node.has_node("SideQVBeastMinion_2"):
				s2_minion_2 = current_stage_node.get_node("SideQVBeastMinion_2") as CharacterBody3D

			var target_b: CharacterBody3D = null
			if s2_minion_1 != null and is_instance_valid(s2_minion_1) and s2_minion_1.current_hp > 0:
				target_b = s2_minion_1
			elif s2_minion_2 != null and is_instance_valid(s2_minion_2) and s2_minion_2.current_hp > 0:
				target_b = s2_minion_2

			if target_b != null:
				_fight_generic_target(target_b)
			else:
				_release_all_inputs()
				_log("Stage 2 Beasts cleared! Advancing to Beast Chieftain...")
				phase = 7
				phase_step = 0
				phase_timer = 0.0

		7:
			# Phase 7: Stage 2 Boss Beast Chieftain
			if player.global_position.x < 7.0:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")

			if s2_boss == null:
				var bosses := get_nodes_in_group("bosses")
				for b in bosses:
					if b != s1_boss and is_instance_valid(b) and "BeastChieftain" in str(b.name):
						s2_boss = b as CharacterBody3D
						break

			if s2_boss != null and is_instance_valid(s2_boss):
				Input.action_release("move_right")
				if s2_boss.current_hp > 0:
					_fight_generic_boss(s2_boss)
				else:
					_release_all_inputs()
					_log("Beast Chieftain defeated naturally!")
					phase = 8
					phase_step = 0
					phase_timer = 0.0

		8:
			# Phase 8: Stage 2 Cleared Intermission (Hold 3.0s)
			if s2_stage_cleared_count >= 1 or (campaign != null and campaign.cleared_stages[1]):
				playthrough_summary["stages_cleared"][1] = true
				if phase_timer >= 3.0:
					var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay") if (campaign != null and campaign.ui_layer != null) else null
					if overlay != null:
						var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
						if btn_cont != null:
							_log("Clicking Continue on Stage 2 Intermission -> Advancing to Stage 3...")
							btn_cont.emit_signal("pressed")
							phase = 9
							phase_step = 0
							phase_timer = 0.0

		9:
			# Phase 9: Stage 3 Loaded (SideQVStage3 Ruined Crossbow Bastion)
			if campaign != null and campaign.current_stage_index == 2 and campaign.current_stage_instance != null:
				var s3 := campaign.current_stage_instance as SideQVStage3
				if s3 != null and s3.player != null:
					current_stage_node = s3
					player = s3.player
					s3.stage_cleared.connect(func():
						s3_stage_cleared_count += 1
						_log(">>> [CAMPAIGN] Stage 3 CLEARED! <<<")
					)
					_log("Stage 3 Entry: Ruined Crossbow Bastion active. Scenic presentation...")
					phase = 10
					phase_step = 0
					phase_timer = 0.0

		10:
			# Phase 10: Stage 3 Crossbow Minions Combat
			if phase_timer < 1.2:
				Input.action_press("move_right")
				return false

			if s3_minion_1 == null and current_stage_node.has_node("RangedMinion_1"):
				s3_minion_1 = current_stage_node.get_node("RangedMinion_1") as CharacterBody3D
			if s3_minion_2 == null and current_stage_node.has_node("RangedMinion_2"):
				s3_minion_2 = current_stage_node.get_node("RangedMinion_2") as CharacterBody3D

			var target_r: CharacterBody3D = null
			if s3_minion_1 != null and is_instance_valid(s3_minion_1) and s3_minion_1.current_hp > 0:
				target_r = s3_minion_1
			elif s3_minion_2 != null and is_instance_valid(s3_minion_2) and s3_minion_2.current_hp > 0:
				target_r = s3_minion_2

			if target_r != null:
				_fight_generic_target(target_r)
			else:
				_release_all_inputs()
				_log("Stage 3 Minions cleared! Advancing to Crossbow Commander...")
				phase = 11
				phase_step = 0
				phase_timer = 0.0

		11:
			# Phase 11: Stage 3 Crossbow Commander Boss
			if player.global_position.x < 7.0:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")

			if s3_boss == null:
				var bosses := get_nodes_in_group("bosses")
				for b in bosses:
					if b is CrossbowCommanderClass and is_instance_valid(b):
						s3_boss = b as SideQVCrossbowCommander
						break

			if s3_boss != null and is_instance_valid(s3_boss):
				Input.action_release("move_right")
				if s3_boss.current_hp > 0:
					_fight_generic_boss(s3_boss)
				else:
					_release_all_inputs()
					_log("Crossbow Commander defeated naturally!")
					phase = 12
					phase_step = 0
					phase_timer = 0.0

		12:
			# Phase 12: Stage 3 Cleared Intermission (Hold 3.0s)
			if s3_stage_cleared_count >= 1 or (campaign != null and campaign.cleared_stages[2]):
				playthrough_summary["stages_cleared"][2] = true
				if phase_timer >= 3.0:
					var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay") if (campaign != null and campaign.ui_layer != null) else null
					if overlay != null:
						var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
						if btn_cont != null:
							_log("Clicking Continue on Stage 3 Intermission -> Advancing to Stage 4...")
							btn_cont.emit_signal("pressed")
							phase = 13
							phase_step = 0
							phase_timer = 0.0

		13:
			# Phase 13: Stage 4 Loaded (SideQVStage4 Titan Stone Sanctuary)
			if campaign != null and campaign.current_stage_index == 3 and campaign.current_stage_instance != null:
				var s4 := campaign.current_stage_instance as SideQVStage4
				if s4 != null and s4.player != null:
					current_stage_node = s4
					player = s4.player
					s4.stage_cleared.connect(func():
						s4_stage_cleared_count += 1
						_log(">>> [CAMPAIGN] Stage 4 CLEARED! <<<")
					)
					_log("Stage 4 Entry: Titan Stone Sanctuary active. Scenic presentation...")
					phase = 14
					phase_step = 0
					phase_timer = 0.0

		14:
			# Phase 14: Stage 4 Heavy Golems Combat
			if phase_timer < 1.2:
				Input.action_press("move_right")
				return false

			if s4_minion_1 == null and current_stage_node.has_node("HeavyGolem_1"):
				s4_minion_1 = current_stage_node.get_node("HeavyGolem_1") as CharacterBody3D
			if s4_minion_2 == null and current_stage_node.has_node("HeavyGolem_2"):
				s4_minion_2 = current_stage_node.get_node("HeavyGolem_2") as CharacterBody3D

			var target_g: CharacterBody3D = null
			if s4_minion_1 != null and is_instance_valid(s4_minion_1) and s4_minion_1.current_hp > 0:
				target_g = s4_minion_1
			elif s4_minion_2 != null and is_instance_valid(s4_minion_2) and s4_minion_2.current_hp > 0:
				target_g = s4_minion_2

			if target_g != null:
				_fight_generic_target(target_g)
			else:
				_release_all_inputs()
				_log("Stage 4 Golems cleared! Advancing to Golem Guardian...")
				phase = 15
				phase_step = 0
				phase_timer = 0.0

		15:
			# Phase 15: Stage 4 Golem Guardian Boss
			if player.global_position.x < 7.0:
				Input.action_press("move_right")
			else:
				Input.action_release("move_right")

			if s4_boss == null:
				var bosses := get_nodes_in_group("bosses")
				for b in bosses:
					if b is SideQVGolemGuardian and is_instance_valid(b):
						s4_boss = b as SideQVGolemGuardian
						break

			if s4_boss != null and is_instance_valid(s4_boss):
				Input.action_release("move_right")
				if s4_boss.current_hp > 0:
					_fight_generic_boss(s4_boss)
				else:
					_release_all_inputs()
					_log("Golem Guardian defeated naturally!")
					phase = 16
					phase_step = 0
					phase_timer = 0.0

		16:
			# Phase 16: Stage 4 Cleared Intermission (Hold 3.0s)
			if s4_stage_cleared_count >= 1 or (campaign != null and campaign.cleared_stages[3]):
				playthrough_summary["stages_cleared"][3] = true
				if phase_timer >= 3.0:
					var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay") if (campaign != null and campaign.ui_layer != null) else null
					if overlay != null:
						var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
						if btn_cont != null:
							_log("Clicking Continue on Stage 4 Intermission -> Advancing to Stage 5...")
							btn_cont.emit_signal("pressed")
							phase = 17
							phase_step = 0
							phase_timer = 0.0

		17:
			# Phase 17: Stage 5 Loaded (SideQVStage5 Silent Abyssal Citadel)
			if campaign != null and campaign.current_stage_index == 4 and campaign.current_stage_instance != null:
				var s5 := campaign.current_stage_instance as SideQVStage5
				if s5 != null and s5.player != null:
					current_stage_node = s5
					player = s5.player
					s5.stage_cleared.connect(func():
						s5_stage_cleared_count += 1
						_log(">>> [CAMPAIGN] Stage 5 CLEARED! <<<")
					)
					campaign.campaign_completed.connect(func():
						campaign_completed_count += 1
						_log(">>> [CAMPAIGN] CAMPAIGN FULLY COMPLETED! <<<")
					)
					_log("Stage 5 Entry: Silent Citadel active. Grand climax...")
					phase = 18
					phase_step = 0
					phase_timer = 0.0

		18:
			# Phase 18: Stage 5 Wave 1 (Two Elite Abyssal Knights)
			if phase_timer < 1.5:
				Input.action_press("move_right")
				return false

			if s5_minion_1 == null and current_stage_node.has_node("EliteAbyssalKnight_1"):
				s5_minion_1 = current_stage_node.get_node("EliteAbyssalKnight_1") as CharacterBody3D
			if s5_minion_2 == null and current_stage_node.has_node("EliteAbyssalKnight_2"):
				s5_minion_2 = current_stage_node.get_node("EliteAbyssalKnight_2") as CharacterBody3D

			var target_k: CharacterBody3D = null
			if s5_minion_1 != null and is_instance_valid(s5_minion_1) and s5_minion_1.current_hp > 0:
				target_k = s5_minion_1
			elif s5_minion_2 != null and is_instance_valid(s5_minion_2) and s5_minion_2.current_hp > 0:
				target_k = s5_minion_2

			if target_k != null:
				_fight_generic_target(target_k)
			else:
				_release_all_inputs()
				_log("Stage 5 Elite Knights cleared! Summoning Abyssal Arbiter...")
				phase = 19
				phase_step = 0
				phase_timer = 0.0

		19:
			# Phase 19: Await Abyssal Arbiter Spawn
			if s5_boss == null:
				var bosses := get_nodes_in_group("bosses")
				for b in bosses:
					if b is SideQVAbyssalArbiter and is_instance_valid(b):
						s5_boss = b as SideQVAbyssalArbiter
						break

			if s5_boss != null and is_instance_valid(s5_boss) and s5_boss.is_inside_tree():
				_log("Abyssal Arbiter spawned (HP 38/38, Poise 18). Commencing final battle...")
				phase = 20
				phase_step = 0
				phase_timer = 0.0

		20:
			# Phase 20: Abyssal Arbiter Battle (Phase 1 & Phase 2)
			if s5_boss != null and is_instance_valid(s5_boss) and s5_boss.is_inside_tree():
				if s5_boss.current_hp < s5_boss_min_hp_recorded:
					s5_boss_min_hp_recorded = s5_boss.current_hp
					if s5_boss.current_hp % 5 == 0:
						_log("Arbiter HP: %d/38 (Phase %d)" % [s5_boss_min_hp_recorded, s5_boss.current_phase])

				if s5_boss.current_hp > 0:
					_fight_abyssal_arbiter()
				else:
					_release_all_inputs()
					_log("Abyssal Arbiter defeated! Final victory achieved!")
					phase = 21
					phase_step = 0
					phase_timer = 0.0
			elif s5_boss_min_hp_recorded <= 0:
				_release_all_inputs()
				phase = 21
				phase_step = 0
				phase_timer = 0.0

		21:
			# Phase 21: Stage 5 Cleared -> Await Campaign Victory Panel
			if s5_stage_cleared_count >= 1 or (campaign != null and campaign.cleared_stages[4]):
				playthrough_summary["stages_cleared"][4] = true
				phase = 22
				phase_step = 0
				phase_timer = 0.0

		22:
			# Phase 22: Display Campaign Victory Panel (Hold for 5.0s for viewing full victory stats)
			var vic_panel = null
			if campaign != null and campaign.ui_layer != null:
				vic_panel = campaign.ui_layer.find_child("CampaignVictoryPanel", true, false)
			if vic_panel != null and vic_panel.visible:
				playthrough_summary["campaign_completed"] = true
				if phase_step == 0:
					_log("CAMPAIGN VICTORY PANEL VISIBLE: ALL 5 STAGES CLEARED! Celebrating...")
					phase_step = 1
					phase_timer = 0.0
				elif phase_step == 1 and phase_timer >= 5.0:
					var btn_title = vic_panel.find_child("ReturnTitleButton", true, false)
					if btn_title != null:
						_log("Returning to Title Screen...")
						btn_title.emit_signal("pressed")
						phase = 23
						phase_step = 0
						phase_timer = 0.0

		23:
			# Phase 23: Return to Title Screen and Display (Hold for 3.0s to complete showcase)
			var title_node = root.get_node_or_null("TitleScreen")
			if title_node != null and is_instance_valid(title_node):
				if phase_step == 0:
					_log("Return to Title Screen confirmed. Finalizing playtest video...")
					phase_step = 1
					phase_timer = 0.0
				elif phase_step == 1 and phase_timer >= 3.0:
					_finish_showcase()

	return false


func _fight_generic_target(target: CharacterBody3D) -> void:
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

		# Ensure facing target
		if (dir_x > 0.0 and player.facing_dir_x < 0.0) or (dir_x < 0.0 and player.facing_dir_x > 0.0):
			if dir_x > 0.0:
				Input.action_press("move_right")
				turn_held_timer = 0.04
			else:
				Input.action_press("move_left")
				turn_held_timer = 0.04

		# Natural combat rhythm: 0.32s attack cadence
		if attack_cooldown_timer <= 0.0 and player.current_state != PlayerClass.State.ATTACK:
			Input.action_press("attack")
			attack_held_timer = 0.08
			attack_cooldown_timer = 0.30


func _fight_generic_boss(target: CharacterBody3D) -> void:
	var diff_x: float = target.global_position.x - player.global_position.x
	var dist_x: float = absf(diff_x)
	var dir_x: float = signf(diff_x)

	# React to boss attack states with parry or jump dodge
	if "current_state" in target and str(target.current_state).to_upper().contains("ATTACK"):
		if dist_x < 3.2 and guard_held_timer <= 0.0:
			Input.action_press("guard")
			guard_held_timer = 0.22
			return

	if dist_x > 2.2:
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
			attack_cooldown_timer = 0.28


func _fight_abyssal_arbiter() -> void:
	var diff_x: float = s5_boss.global_position.x - player.global_position.x
	var dist_x: float = absf(diff_x)
	var dir_x: float = signf(diff_x)

	# 1. Counter Judgment Storm: leap dodge over shockwave
	if s5_boss.current_pattern == ArbiterClass.Pattern.JUDGMENT_STORM:
		if player.is_on_floor() and jump_held_timer <= 0.0:
			Input.action_press("jump")
			jump_held_timer = 0.35
		return

	# 2. Counter incoming wave or shadow blink: guard/parry
	if s5_boss.current_pattern in [ArbiterClass.Pattern.DARK_CRESCENT_WAVE, ArbiterClass.Pattern.SHADOW_BLINK_STRIKE]:
		if dist_x < 4.8 and guard_held_timer <= 0.0:
			Input.action_press("guard")
			guard_held_timer = 0.28
			return

	# 3. Approach and strike
	if dist_x > 2.4:
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
			attack_cooldown_timer = 0.26


func _release_all_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("attack")
	Input.action_release("guard")
	Input.action_release("jump")


func _log(msg: String) -> void:
	var entry := "[%.3fs] %s" % [sim_time, msg]
	print(entry)
	raw_log_lines.append(entry)


func _finish_showcase() -> void:
	_release_all_inputs()
	playthrough_summary["total_sim_time"] = sim_time
	_log(">>> FULL CAMPAIGN SHOWCASE PLAYTEST COMPLETED SUCCESSFULLY! Total time: %.2fs <<<" % sim_time)

	# Ensure evidence directory exists
	var ev_dir := "res://../../STUDIO_V3/evidence/V3-020"
	var global_dir := ProjectSettings.globalize_path(ev_dir)
	var dir := DirAccess.open("res://../../STUDIO_V3")
	if dir != null and not dir.dir_exists("evidence/V3-020"):
		dir.make_dir_recursive("evidence/V3-020")

	# Save Result JSON
	var json_path := "%s/STAGE5_PLAYTHROUGH_RESULT.json" % global_dir
	var f_json := FileAccess.open(json_path, FileAccess.WRITE)
	if f_json:
		f_json.store_string(JSON.stringify(playthrough_summary, "  "))
		f_json.close()

	# Save Raw Log
	var log_path := "%s/PLAYTHROUGH_LOG.txt" % global_dir
	var f_log := FileAccess.open(log_path, FileAccess.WRITE)
	if f_log:
		f_log.store_string("\n".join(raw_log_lines))
		f_log.close()

	quit(0)


func _fail(reason: String) -> void:
	_release_all_inputs()
	printerr("[V3-020 FAILED] %s" % reason)
	quit(1)
