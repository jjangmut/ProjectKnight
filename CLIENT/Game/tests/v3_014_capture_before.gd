extends SceneTree
## V3-014 Capture Baseline Before Fixture
## Captures reproducible baseline shortcomings in 1280x720:
## 1. before_01_auto_advance_stage_clear.png:
##    Upon stage clear, the game displays only a fixed-position floating text label
##    ("STAGE CLEARED!\n+ 20 SOUL SHARDS"), leaves touch controls visible, provides
##    NO player-controlled Continue/Title buttons or intermission UI, and abruptly
##    auto-advances to the next stage after 1.8s without player consent.

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"

var campaign: SideQVCampaign = null
var step: int = 0
var timer: float = 0.0

func _initialize() -> void:
	print(">>> [V3-014 CAPTURE BEFORE] Initializing baseline stage clear capture fixture... <<<")
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
			# Allow stage 1 to load
			if timer >= 0.40:
				var stage = campaign.current_stage_instance
				if stage != null and stage.has_method("_on_boss_defeated"):
					print("[V3-014 CAPTURE BEFORE] Triggering boss defeat on Stage 1 to observe legacy fanfare...")
					stage._on_boss_defeated(null)
				step = 1
				timer = 0.0

		1:
			# Wait 0.5s for clear fanfare label to be displayed on screen
			if timer >= 0.50:
				_save_frame("before/before_01_auto_advance_stage_clear.png")
				step = 2
				timer = 0.0

		2:
			print(">>> [V3-014 CAPTURE BEFORE COMPLETE] Baseline capture finished. <<<")
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
			print("[V3-014 CAPTURE BEFORE] Successfully saved baseline capture: ", full_path)
		else:
			printerr("[V3-014 CAPTURE BEFORE] Failed to save screenshot: ", err)
	else:
		printerr("[V3-014 CAPTURE BEFORE] Viewport image is null!")
