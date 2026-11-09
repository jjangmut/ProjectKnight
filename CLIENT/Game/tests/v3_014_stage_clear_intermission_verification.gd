extends SceneTree
## V3-014 Stage-Clear Intermission & Player-Controlled Next Stage Programmatic Verification
## Rigorously validates all requirements from STUDIO_V3/tasks/V3-014.md

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"
const SaveManagerClass := preload("res://scripts/system/save_manager.gd")

var campaign: SideQVCampaign = null
var current_step: int = 0
var timer: float = 0.0

var total_checks: int = 0
var passed_checks: int = 0
var failed_checks: int = 0
var check_details: Array[Dictionary] = []

var initial_shards: int = 0


func _initialize() -> void:
	print(">>> [V3-014 VERIFY] Initializing Stage-Clear Intermission Programmatic Verification... <<<")
	root.size = Vector2i(1280, 720)

	initial_shards = SaveManagerClass.get_shards()
	print("[V3-014 VERIFY] Baseline SaveManager Shards: %d" % initial_shards)

	var packed := load(CampaignScenePath) as PackedScene
	campaign = packed.instantiate() as SideQVCampaign
	root.add_child(campaign)
	current_scene = campaign

	process_frame.connect(_on_process_frame)


func _assert_check(check_name: String, condition: bool, detail: String = "") -> void:
	total_checks += 1
	if condition:
		passed_checks += 1
		print("[PASS] Check %d: %s%s" % [total_checks, check_name, (" - " + detail) if detail != "" else ""])
		check_details.append({"check": check_name, "status": "PASS", "detail": detail})
	else:
		failed_checks += 1
		printerr("[FAIL] Check %d: %s%s" % [total_checks, check_name, (" - " + detail) if detail != "" else ""])
		check_details.append({"check": check_name, "status": "FAIL", "detail": detail})


func _on_process_frame() -> void:
	timer += 1.0 / 60.0

	match current_step:
		0:
			# Step 0: Await Stage 1 spawn
			if timer >= 0.40:
				_assert_check("Campaign initialized with Stage 1", campaign != null and campaign.current_stage_index == 0)
				var stage = campaign.current_stage_instance
				_assert_check("Current stage instance active", stage != null)
				_assert_check("Stage has last_earned_shards property", "last_earned_shards" in stage)

				# Trigger boss defeat to simulate natural stage completion
				print("[V3-014 VERIFY] Triggering boss defeat on Stage 1...")
				stage._on_boss_defeated(null)

				current_step = 1
				timer = 0.0

		1:
			# Step 1: Wait until stage 1 cleared is signaled into campaign
			if campaign.cleared_stages[0] == true:
				_assert_check("Stage 1 recorded as cleared in campaign", campaign.cleared_stages[0] == true)
				_assert_check("Zero global pause during clear", paused == false)

				# Check that StageClearOverlay exists in campaign UILayer
				var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay")
				_assert_check("StageClearOverlay instantiated in CampaignUILayer", overlay != null)

				if overlay != null:
					_assert_check("StageClearOverlay is full rect", overlay.anchor_right == 1.0 and overlay.anchor_bottom == 1.0)
					_assert_check("StageClearOverlay ignores mouse filter on root", overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)

					var center = overlay.get_node_or_null("CenterContainer")
					_assert_check("CenterContainer child exists", center != null)
					if center != null:
						_assert_check("CenterContainer is full rect", center.anchor_right == 1.0 and center.anchor_bottom == 1.0)

					var panel = overlay.find_child("StageClearPanel", true, false) as PanelContainer
					_assert_check("StageClearPanel exists in CenterContainer", panel != null)
					if panel != null:
						_assert_check("StageClearPanel custom minimum size is (640, 360)", panel.custom_minimum_size == Vector2(640, 360))

					var title = overlay.find_child("ClearTitleLabel", true, false) as Label
					_assert_check("ClearTitleLabel exists", title != null)
					if title != null:
						_assert_check("ClearTitleLabel text is '★ STAGE COMPLETED ★'", title.text == "★ STAGE COMPLETED ★")

					var subtitle = overlay.find_child("ClearSubtitleLabel", true, false) as Label
					_assert_check("ClearSubtitleLabel exists", subtitle != null)
					if subtitle != null:
						_assert_check("ClearSubtitleLabel contains stage name and progress", "STAGE 1" in subtitle.text and "1 / 5" in subtitle.text)

					var reward_lbl = overlay.find_child("RewardLabel", true, false) as Label
					_assert_check("RewardLabel exists", reward_lbl != null)
					if reward_lbl != null:
						_assert_check("RewardLabel displays earned soul shards (+ 20)", "20 SOUL SHARDS" in reward_lbl.text)

					var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
					_assert_check("ContinueStageButton exists", btn_cont != null)
					if btn_cont != null:
						_assert_check("ContinueStageButton min size is at least (220, 48)", btn_cont.custom_minimum_size.x >= 220 and btn_cont.custom_minimum_size.y >= 48)
						_assert_check("ContinueStageButton has FOCUS_ALL", btn_cont.focus_mode == Control.FOCUS_ALL)
						_assert_check("ContinueStageButton text mentions Stage 2", "STAGE 2" in btn_cont.text)

					var btn_title = overlay.find_child("ReturnTitleButton", true, false) as Button
					_assert_check("ReturnTitleButton exists", btn_title != null)
					if btn_title != null:
						_assert_check("ReturnTitleButton min size is at least (210, 48)", btn_title.custom_minimum_size.x >= 210 and btn_title.custom_minimum_size.y >= 48)
						_assert_check("ReturnTitleButton has FOCUS_ALL", btn_title.focus_mode == Control.FOCUS_ALL)

				# Check touch controls neutralization on clear
				var stage = campaign.current_stage_instance
				if stage != null and stage.touch_controls != null:
					_assert_check("Touch controls deck hidden on stage clear", stage.touch_controls.visible == false)

				current_step = 2
				timer = 0.0
			elif timer >= 5.0:
				_assert_check("Stage 1 clear signaled within timeout", false, "Timed out after 5.0s")
				current_step = 8

		2:
			# Step 2: Verify NO UNINTENDED AUTO-ADVANCE!
			# In legacy code, after 1.8s the game auto-loaded stage 2.
			# We will wait 2.2s and confirm that current_stage_index is STILL 0!
			if timer >= 2.20:
				_assert_check("No automatic stage advance after 2.2s (awaits player click)", campaign.current_stage_index == 0)
				_assert_check("is_transitioning remains false during player decision", campaign.is_transitioning == false)

				# Check shard invariance: shards must NOT be awarded again while sitting in intermission
				var current_shards := SaveManagerClass.get_shards()
				_assert_check("Shards awarded exactly once (+20 shards)", current_shards == initial_shards + 20, "shards=%d, expected=%d" % [current_shards, initial_shards + 20])

				current_step = 3
				timer = 0.0

		3:
			# Step 3: Test Continue Button Click & Disable Guard
			var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay")
			if overlay != null:
				var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
				var btn_title = overlay.find_child("ReturnTitleButton", true, false) as Button
				if btn_cont != null:
					print("[V3-014 VERIFY] Clicking ContinueStageButton...")
					btn_cont.emit_signal("pressed")
					_assert_check("Continue button disabled immediately on click", btn_cont.disabled == true)
					if btn_title != null:
						_assert_check("Title button disabled immediately on continue click", btn_title.disabled == true)

			current_step = 4
			timer = 0.0

		4:
			# Step 4: Verify Clean Stage 2 Transition
			if campaign.current_stage_index == 1:
				_assert_check("Successfully advanced to Stage 2 (index 1)", campaign.current_stage_index == 1)
				_assert_check("Stage 1 remains marked cleared in campaign", campaign.cleared_stages[0] == true)
				_assert_check("StageClearOverlay cleanly freed after transition", campaign.clear_overlay == null)
				_assert_check("Old overlay node no longer in CampaignUILayer", campaign.ui_layer.get_node_or_null("StageClearOverlay") == null)

				# Check shard invariance: advancing stage must NOT award extra shards
				var shards_after_advance := SaveManagerClass.get_shards()
				_assert_check("Shard count unchanged after advancing (+20 total)", shards_after_advance == initial_shards + 20)

				current_step = 5
				timer = 0.0
			elif timer >= 3.0:
				_assert_check("Advanced to Stage 2 within timeout", false)
				current_step = 8

		5:
			# Step 5: Test Stage 5 Campaign Victory Exclusivity
			# We test that Stage 5 does NOT show StageClearOverlay, but shows CampaignVictoryPanel
			print("[V3-014 VERIFY] Testing Stage 5 Clear -> Campaign Victory exclusivity...")
			campaign.load_stage(4) # Load Stage 5 (index 4)
			current_step = 6
			timer = 0.0

		6:
			# Await Stage 5 load
			if campaign.current_stage_index == 4 and campaign.current_stage_instance != null:
				_assert_check("Stage 5 loaded", campaign.current_stage_index == 4)
				var s5 = campaign.current_stage_instance
				if s5 != null and s5.has_method("_on_boss_defeated"):
					s5._on_boss_defeated(null)

				current_step = 7
				timer = 0.0
			elif timer >= 3.0:
				_assert_check("Stage 5 loaded within timeout", false)
				current_step = 8

		7:
			# Await Stage 5 clear fanfare
			if campaign.cleared_stages[4] == true:
				_assert_check("Stage 5 marked cleared", campaign.cleared_stages[4] == true)
				var clear_ov = campaign.ui_layer.get_node_or_null("StageClearOverlay")
				_assert_check("Stage 5 does NOT show StageClearOverlay (intermission suppressed for final stage)", clear_ov == null)

				var vic_panel = campaign.ui_layer.find_child("CampaignVictoryPanel", true, false)
				_assert_check("Stage 5 shows CampaignVictoryPanel", vic_panel != null)

				# Check Stage 5 shard award (+50)
				var shards_final := SaveManagerClass.get_shards()
				_assert_check("Stage 5 shards (+50) awarded exactly once (+70 total)", shards_final == initial_shards + 20 + 50)

				current_step = 8
				timer = 0.0
			elif timer >= 5.0:
				_assert_check("Stage 5 clear completed within timeout", false)
				current_step = 8

		8:
			_conclude_test()


func _conclude_test() -> void:
	print("\n================================================================================")
	print("[V3-014 VERIFY SUMMARY] Total: %d | Passed: %d | Failed: %d" % [total_checks, passed_checks, failed_checks])
	print("================================================================================\n")

	var result_data := {
		"task_id": "V3-014",
		"timestamp": Time.get_datetime_string_from_system(),
		"total_checks": total_checks,
		"passed_checks": passed_checks,
		"failed_checks": failed_checks,
		"all_passed": (failed_checks == 0),
		"details": check_details
	}

	var json_str := JSON.stringify(result_data, "  ")
	var result_path := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-014/STAGE_CLEAR_INTERMISSION_VERIFICATION_RESULT.json"
	var f := FileAccess.open(result_path, FileAccess.WRITE)
	if f != null:
		f.store_string(json_str)
		f.close()
		print("[V3-014 VERIFY] Result saved to: %s" % result_path)

	if failed_checks == 0:
		print(">>> ALL V3-014 UNIT CHECKS PASSED SUCCESSFULLY! <<<")
		quit(0)
	else:
		printerr(">>> V3-014 UNIT CHECKS FAILED! <<<")
		quit(1)
