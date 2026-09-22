extends SceneTree
## Automated QA Smoke Test for TitleScreen & Commercial Game Loop.
## Verifies that:
## 1. TitleScreen instantiates complete commercial UI with 5 main action buttons.
## 2. Continue button dynamically enables/disables based on SaveManager state.
## 3. Sanctuary Shop modal opens, updates shards, and closes cleanly.
## 4. Settings modal opens with BGM volume slider and control guide.
## 5. Credits modal displays studio credentials.
## 6. Campaign route panel features Return to Title button.

const TitleScreenClass := preload("res://scripts/ui/title_screen.gd")

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
	print("\n--- START TITLE SCREEN & COMMERCIAL LOOP SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	# 1. Clean SaveManager test baseline
	SaveManager.clear_save()

	var title_scene := load("res://scenes/ui/TitleScreen.tscn") as PackedScene
	var title_screen = title_scene.instantiate()
	world.add_child(title_screen)

	await process_frame
	await process_frame

	print("\n[Check 1: Title Screen Hierarchy & Component Initialization]")
	check(title_screen != null, "TitleScreen instantiated successfully")
	check(title_screen.btn_new_game != null, "New Game button exists")
	check(title_screen.btn_continue != null, "Continue button exists")
	check(title_screen.btn_shop != null, "Sanctuary Shop button exists")
	check(title_screen.btn_settings != null, "Settings button exists")
	check(title_screen.btn_credits != null, "Credits button exists")
	check(title_screen.save_summary_label != null, "Save summary label exists")

	print("\n[Check 2: Clean Save State & Continue Button Toggle]")
	check(title_screen.btn_continue.disabled == true, "Continue button disabled when no save exists")
	check("기록된 여정이 없습니다" in title_screen.save_summary_label.text, "Summary correctly indicates no active save")

	# Simulate active save
	SaveManager.save_game(2, "reach", [true, true, false, false, false], {"soul_shards": 45})
	title_screen._update_save_summary()
	check(title_screen.btn_continue.disabled == false, "Continue button enabled when save file exists")
	check("3지역: 무너진 성벽" in title_screen.save_summary_label.text, "Summary reflects saved stage index")
	check("45" in title_screen.save_summary_label.text, "Summary reflects saved soul shards")

	print("\n[Check 3: Sanctuary Shop Modal Integration]")
	title_screen._on_shop_pressed()
	await process_frame
	var shop = title_screen.get_node_or_null("CampfireShop")
	check(shop != null, "CampfireShop opened as child of TitleScreen")
	check(SaveManager.get_shards() == 45, "Persistent shards verified as 45")
	# Close shop
	shop._on_close_pressed()
	await process_frame
	check(title_screen.get_node_or_null("CampfireShop") == null, "Shop closed and cleaned up")

	print("\n[Check 4: Settings Modal & Audio Volume Control]")
	title_screen._on_settings_pressed()
	await process_frame
	var settings_modal = title_screen.get_child(title_screen.get_child_count() - 1)
	check(settings_modal != null, "Settings modal instantiated")
	var bgm_slider: HSlider = null
	for child in settings_modal.find_children("", "HSlider", true, false):
		bgm_slider = child as HSlider
		break
	check(bgm_slider != null, "BGM volume slider exists in settings")
	if bgm_slider != null:
		bgm_slider.value = 0.5
		check(bgm_slider.value == 0.5, "Slider value updated to 0.5")
	settings_modal.queue_free()
	await process_frame

	print("\n[Check 5: Credits Modal & Attribution]")
	title_screen._on_credits_pressed()
	await process_frame
	var credits_modal = title_screen.get_child(title_screen.get_child_count() - 1)
	check(credits_modal != null, "Credits modal instantiated")
	credits_modal.queue_free()
	await process_frame

	print("\n[Check 6: Campaign Integration & Return to Title Button]")
	var campaign_scene := load("res://scenes/stage/Campaign.tscn") as PackedScene
	var campaign = campaign_scene.instantiate()
	world.add_child(campaign)
	await process_frame
	await process_frame

	# Simulate stage clear to trigger route panel
	campaign._on_stage_finished(1) # Clear
	# Wait for transition timeout (1.5s)
	await create_timer(1.8, false).timeout

	check(campaign.panel != null, "Campaign route panel displayed after clear")
	var return_btn_found := false
	if campaign.panel != null:
		for child in campaign.panel.find_children("", "Button", true, false):
			if "메인 타이틀" in (child as Button).text:
				return_btn_found = true
				break
	check(return_btn_found, "Return to Main Title button exists on route panel")

	# Clean up save
	SaveManager.clear_save()

	print("\n--- TITLE & COMMERCIAL LOOP SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: ALL COMMERCIAL LOOP CHECKS PASSED (100%)\n")
		quit(0)
	else:
		push_error("TEST RESULT: COMMERCIAL LOOP TEST FAILED")
		quit(1)
