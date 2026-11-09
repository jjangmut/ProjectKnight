extends SceneTree
## V3-013 Capture Baseline Before Fixture
## Captures reproducible baseline shortcomings in 1280x720:
## 1. before_01_uncontrolled_auto_reload_defeat.png:
##    Upon player death, the game displays NO defeat overlay, NO retry button,
##    NO title button, leaving virtual controls lingering while automatically
##    reloading the stage after 2 seconds without player consent.

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"

var campaign: SideQVCampaign = null
var step: int = 0
var timer: float = 0.0

func _initialize() -> void:
	print(">>> [V3-013 CAPTURE BEFORE] Initializing baseline defeat capture fixture... <<<")
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
			# Allow stage 1 to load and spawn player
			if timer >= 0.40:
				var player = campaign.get_node_or_null("SideQVStage1/SideQVPlayer")
				if player == null and campaign.current_stage_instance != null:
					player = campaign.current_stage_instance.get_node_or_null("SideQVPlayer")
				if player != null and player.has_method("receive_incoming_attack"):
					print("[V3-013 CAPTURE BEFORE] Inflicting lethal damage on player...")
					player.receive_incoming_attack(8, null, Vector3.ZERO)
				step = 1
				timer = 0.0

		1:
			# 0.45s after death: player in death frame, stage_failed emitted, no overlay exists
			if timer >= 0.45:
				_save_frame("before/before_01_uncontrolled_auto_reload_defeat.png")
				step = 2
				timer = 0.0

		2:
			print(">>> [V3-013 CAPTURE BEFORE COMPLETE] Baseline capture finished. <<<")
			quit(0)

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
		else:
			printerr("[CAPTURE FAIL] Error saving frame: ", err)
	else:
		printerr("[CAPTURE FAIL] Image from viewport was null!")
