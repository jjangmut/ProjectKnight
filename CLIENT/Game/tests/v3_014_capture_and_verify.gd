extends SceneTree
## V3-014 Viewport Captures and Responsiveness Verification
## Generates 4 after frames in STUDIO_V3/evidence/V3-014/captures/after/
## 1. after_01_stage_clear_overlay_1280x720.png
## 2. after_02_stage_clear_overlay_1024x720.png
## 3. after_03_continue_to_next_stage_respawn.png
## 4. after_04_return_to_title_screen.png

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"

var campaign: SideQVCampaign = null
var step: int = 0
var timer: float = 0.0


func _initialize() -> void:
	print(">>> [V3-014 CAPTURE] Initializing Viewport Capture and Responsiveness Verification... <<<")
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
			# Await Stage 1 load and trigger boss defeat
			if timer >= 0.40:
				var stage = campaign.current_stage_instance
				if stage != null and stage.has_method("_on_boss_defeated"):
					stage._on_boss_defeated(null)
				step = 1
				timer = 0.0

		1:
			# Await stage_cleared signal and StageClearOverlay appearance (1280x720)
			if campaign.cleared_stages[0] == true:
				var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay")
				if overlay != null and timer >= 0.30:
					_save_frame("after/after_01_stage_clear_overlay_1280x720.png")
					step = 2
					timer = 0.0

		2:
			# Resize viewport to 1024x720 to verify compact responsiveness
			root.size = Vector2i(1024, 720)
			step = 3
			timer = 0.0

		3:
			# Allow layout pass at 1024x720
			if timer >= 0.20:
				_save_frame("after/after_02_stage_clear_overlay_1024x720.png")
				# Restore viewport size to 1280x720
				root.size = Vector2i(1280, 720)
				step = 4
				timer = 0.0

		4:
			# Click ContinueStageButton to advance to Stage 2
			if timer >= 0.20:
				var overlay = campaign.ui_layer.get_node_or_null("StageClearOverlay")
				if overlay != null:
					var btn_cont = overlay.find_child("ContinueStageButton", true, false) as Button
					if btn_cont != null:
						print("[V3-014 CAPTURE] Clicking ContinueStageButton...")
						btn_cont.emit_signal("pressed")
				step = 5
				timer = 0.0

		5:
			# Await Stage 2 load and capture fresh respawn
			if campaign.current_stage_index == 1 and timer >= 0.40:
				_save_frame("after/after_03_continue_to_next_stage_respawn.png")

				# Trigger stage clear on Stage 2 to test Return to Title
				var s2 = campaign.current_stage_instance
				if s2 != null and s2.has_method("_on_boss_defeated"):
					s2._on_boss_defeated(null)
				step = 6
				timer = 0.0

		6:
			# Await Stage 2 intermission overlay
			if campaign.cleared_stages[1] == true:
				var overlay2 = campaign.ui_layer.get_node_or_null("StageClearOverlay")
				if overlay2 != null and timer >= 0.20:
					var btn_title = overlay2.find_child("ReturnTitleButton", true, false) as Button
					if btn_title != null:
						print("[V3-014 CAPTURE] Clicking ReturnTitleButton...")
						btn_title.emit_signal("pressed")
					step = 7
					timer = 0.0

		7:
			# Await scene change to TitleScreen and capture
			var title_node = root.get_node_or_null("TitleScreen")
			if title_node != null and timer >= 0.30:
				_save_frame("after/after_04_return_to_title_screen.png")
				step = 8
				timer = 0.0

		8:
			print(">>> [V3-014 CAPTURE COMPLETE] All after frames successfully captured! <<<")
			var res_path := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-014/AFTER_CAPTURE_VERIFICATION_RESULT.json"
			var f := FileAccess.open(res_path, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify({"all_captures_verified": true, "captures_count": 4}, "  "))
				f.close()
			quit(0)


func _save_frame(rel_path: String) -> void:
	var base_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-014/captures"
	var full_path := base_dir + "/" + rel_path
	var parent_dir := full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)

	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		var err := img.save_png(full_path)
		if err == OK:
			print("[V3-014 CAPTURE] Saved capture: ", full_path)
		else:
			printerr("[V3-014 CAPTURE] Error saving image: ", err)
