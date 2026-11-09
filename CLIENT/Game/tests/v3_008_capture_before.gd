extends SceneTree
## V3-008 Before State Capture Fixture (Windowed 1280x720)
## Captures baseline states prior to polish modifications.

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"
const ArbiterClass := preload("res://scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd")

var campaign: SideQVCampaign = null
var sim_frame: int = 0
var shot_step: int = 0

func _initialize() -> void:
	print(">>> [V3-008 BEFORE] Initializing baseline capture fixture... <<<")
	root.size = Vector2i(1280, 720)

	var packed := load(CampaignScenePath) as PackedScene
	if packed == null:
		printerr("Failed to load CampaignScenePath")
		quit(1)
		return
	campaign = packed.instantiate() as SideQVCampaign
	root.add_child(campaign)
	current_scene = campaign

func _physics_process(_delta: float) -> bool:
	sim_frame += 1

	match shot_step:
		0:
			if sim_frame > 25:
				if campaign != null and campaign.has_method("_show_campaign_victory"):
					campaign._show_campaign_victory()
				shot_step = 1

		1:
			if sim_frame > 50:
				_save_viewport("before_01_campaign_victory_panel")
				shot_step = 2

		2:
			if sim_frame > 75:
				if campaign != null:
					var vic := campaign.get_node_or_null("CampaignUILayer/CampaignVictoryPanel")
					if vic != null:
						vic.queue_free()
					if campaign.has_method("load_stage"):
						campaign.load_stage(4) # Stage 5
				shot_step = 3

		3:
			if sim_frame > 130:
				if campaign != null and campaign.current_stage_instance != null:
					var arbiter: Node3D = ArbiterClass.new()
					campaign.current_stage_instance.add_child(arbiter)
					arbiter.global_position = Vector3(2.5, 0.1, 0.0)
					if arbiter.has_method("_show_danger_telegraph"):
						arbiter._show_danger_telegraph(0.20)
				shot_step = 4

		4:
			if sim_frame > 150:
				_save_viewport("before_02_arbiter_blink_telegraph")
				shot_step = 5

		5:
			if sim_frame > 170:
				var stage5 := campaign.current_stage_instance
				if stage5 != null:
					var player := stage5.get_node_or_null("SideQVPlayer")
					if player != null and player.has_method("receive_incoming_attack"):
						player.is_guarding = true
						player.guard_elapsed_time = 0.05
						player.receive_incoming_attack(2, null, Vector3.LEFT)
				shot_step = 6

		6:
			if sim_frame > 185:
				_save_viewport("before_03_parry_hit_stop")
				shot_step = 7

		7:
			if sim_frame > 200:
				print(">>> [V3-008 BEFORE] All baseline captures recorded! Exiting... <<<")
				quit(0)
				return true

	return false

func _save_viewport(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		printerr("[V3-008 BEFORE] Viewport image was null for %s" % shot_name)
		return

	var out_dir := ProjectSettings.globalize_path("res://../../STUDIO_V3/evidence/V3-008/captures/before")
	var file_path := "%s/%s.png" % [out_dir, shot_name]
	img.save_png(file_path)
	print("[V3-008 BEFORE] Saved %s (%dx%d)" % [file_path, img.get_width(), img.get_height()])
