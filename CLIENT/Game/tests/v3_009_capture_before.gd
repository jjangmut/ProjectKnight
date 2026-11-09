extends SceneTree
## V3-009 Before State Capture Fixture (Windowed 1280x720)
## Captures baseline states before V3-009 combat cancel & mobile UI modifications.

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var sim_frame: int = 0
var shot_step: int = 0

func _initialize() -> void:
	print(">>> [V3-009 BEFORE] Initializing baseline capture fixture... <<<")
	root.size = Vector2i(1280, 720)

	var packed := load(Stage1ScenePath) as PackedScene
	if packed == null:
		printerr("Failed to load Stage 1 scene")
		quit(1)
		return
	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

func _physics_process(_delta: float) -> bool:
	sim_frame += 1

	match shot_step:
		0:
			if sim_frame > 25:
				# 1. Capture Stage 1 showing missing touch deck in MobileUI
				_save_viewport("before_02_mobile_ui_missing_in_stage")
				shot_step = 1

		1:
			if sim_frame > 45:
				# 2. Trigger player attack to capture attack recovery lock
				var player := stage.get_node_or_null("SideQVPlayer")
				if player != null and player.has_method("start_attack"):
					player.start_attack()
				shot_step = 2

		2:
			if sim_frame > 55:
				# Capture during attack recovery
				_save_viewport("before_01_attack_recovery_lock")
				shot_step = 3

		3:
			if sim_frame > 75:
				# 3. Resize root window to 1024x720 to capture narrow viewport baseline
				root.size = Vector2i(1024, 720)
				shot_step = 4

		4:
			if sim_frame > 95:
				_save_viewport("before_03_narrow_viewport_hud")
				shot_step = 5

		5:
			if sim_frame > 115:
				print(">>> [V3-009 BEFORE] All baseline captures recorded! Exiting... <<<")
				quit(0)
				return true

	return false

func _save_viewport(shot_name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		printerr("[V3-009 BEFORE] Viewport image was null for %s" % shot_name)
		return

	var out_dir := ProjectSettings.globalize_path("res://../../STUDIO_V3/evidence/V3-009/captures/before")
	var file_path := "%s/%s.png" % [out_dir, shot_name]
	img.save_png(file_path)
	print("[V3-009 BEFORE] Saved %s (%dx%d)" % [file_path, img.get_width(), img.get_height()])
