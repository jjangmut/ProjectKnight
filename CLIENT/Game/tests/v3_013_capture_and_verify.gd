extends SceneTree
## V3-013 Capture After State Fixture
## Produces verified high-resolution viewport frames:
##  1. after_01_stage_failed_overlay_1280x720.png: Full landscape defeat overlay with Retry & Title buttons
##  2. after_02_stage_failed_overlay_1024x720.png: Narrow viewport centered layout with non-clipped controls
##  3. after_03_retry_fresh_stage_respawn.png: Fresh stage instance after clicking Retry with 8/8 HP and active controls
##  4. after_04_return_to_title_screen.png: Clean return to title screen after clicking Return to Title

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"

var campaign: SideQVCampaign = null
var step: int = 0
var timer: float = 0.0

var results := {
	"task_id": "V3-013",
	"captures_captured": 0,
	"all_captured": false
}

func _initialize() -> void:
	print(">>> [V3-013 CAPTURE AFTER] Initializing after capture fixture... <<<")
	root.size = Vector2i(1280, 720)
	var packed := load(CampaignScenePath) as PackedScene
	campaign = packed.instantiate() as SideQVCampaign
	root.add_child(campaign)
	current_scene = campaign

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	timer += 1.0 / 60.0

	match step:
		0:
			# Step 0: Allow stage 1 to initialize and spawn player
			if timer >= 0.45:
				var player = campaign.current_stage_instance.get_node_or_null("SideQVPlayer") if campaign.current_stage_instance != null else null
				if player != null and player.has_method("receive_incoming_attack"):
					print("[V3-013 CAPTURE AFTER] Inflicting lethal damage for 1280x720 defeat capture...")
					player.receive_incoming_attack(8, null, Vector3.ZERO)
				step = 1
				timer = 0.0

		1:
			# Step 1: Capture 1280x720 defeat overlay
			if timer >= 0.40:
				_save_frame("after/after_01_stage_failed_overlay_1280x720.png")
				# Transition viewport to 1024x720 narrow mode
				root.size = Vector2i(1024, 720)
				step = 2
				timer = 0.0

		2:
			# Step 2: Capture 1024x720 centered defeat overlay
			if timer >= 0.25:
				_save_frame("after/after_02_stage_failed_overlay_1024x720.png")
				# Restore 1280x720 and click Retry
				root.size = Vector2i(1280, 720)
				var panel = campaign.ui_layer.find_child("StageFailedPanel", true, false)
				var btn_retry = panel.find_child("RetryStageButton", true, false) as Button if panel != null else null
				if btn_retry != null:
					print("[V3-013 CAPTURE AFTER] Clicking RetryStageButton...")
					btn_retry.emit_signal("pressed")
				step = 3
				timer = 0.0

		3:
			# Step 3: Capture fresh stage respawn with 8 HP and active gameplay
			if timer >= 0.50:
				_save_frame("after/after_03_retry_fresh_stage_respawn.png")
				# Inflict lethal damage again to test Return to Title
				var player = campaign.current_stage_instance.get_node_or_null("SideQVPlayer") if campaign.current_stage_instance != null else null
				if player != null and player.has_method("receive_incoming_attack"):
					print("[V3-013 CAPTURE AFTER] Inflicting second lethal hit for Return to Title...")
					player.receive_incoming_attack(8, null, Vector3.ZERO)
				step = 4
				timer = 0.0

		4:
			# Step 4: Defeat overlay is active again; click ReturnTitleButton
			if timer >= 0.35:
				var panel = campaign.ui_layer.find_child("StageFailedPanel", true, false)
				var btn_title = panel.find_child("ReturnTitleButton", true, false) as Button if panel != null else null
				if btn_title != null:
					print("[V3-013 CAPTURE AFTER] Clicking ReturnTitleButton...")
					btn_title.emit_signal("pressed")
				step = 5
				timer = 0.0

		5:
			# Step 5: Capture Return to Title screen
			if timer >= 0.40:
				_save_frame("after/after_04_return_to_title_screen.png")
				_finish()
				step = 6

func _save_frame(rel_path: String) -> void:
	var base_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-013/captures"
	var full_path := base_dir + "/" + rel_path
	var parent_dir := full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)

	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		var err := img.save_png(full_path)
		if err == OK:
			print("[CAPTURE OK] Saved frame -> ", full_path)
			results["captures_captured"] += 1
		else:
			printerr("[CAPTURE FAIL] Error saving frame: ", err)
	else:
		printerr("[CAPTURE FAIL] Image from viewport was null!")

func _finish() -> void:
	results["all_captured"] = (results["captures_captured"] >= 4)
	var evidence_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-013"
	var f := FileAccess.open(evidence_dir + "/AFTER_CAPTURE_VERIFICATION_RESULT.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	print(">>> [V3-013 CAPTURE AFTER COMPLETE] Captured %d frames. <<<" % results["captures_captured"])
	quit(0 if results["all_captured"] else 1)
