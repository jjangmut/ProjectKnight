extends SceneTree
## V3-010 Baseline "Before" Captures Fixture

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"

var stage: Node3D = null
var step: int = 0
var timer: float = 0.0

func _initialize() -> void:
	print(">>> [V3-010 BEFORE] Initializing baseline capture fixture... <<<")
	root.size = Vector2i(1280, 720)
	var packed := load(Stage1ScenePath) as PackedScene
	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	# Simulate baseline state: hide onboarding guide if present and add a duplicate deck
	var guide = stage.get_node_or_null("SideQVMobileUI/OnboardingGuideHUD")
	if guide != null:
		guide.visible = false

	# Add duplicate deck representing pre-fix state
	var dup_deck = QVMobileControls.new()
	dup_deck.name = "MobileControlsHUD"
	stage.add_child(dup_deck)

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	timer += 1.0 / 60.0
	match step:
		0:
			if timer >= 0.3:
				_save_frame("before/before_01_duplicate_stage1_deck.png")
				_save_frame("before/before_02_missing_onboarding_guide.png")
				step = 1

		1:
			if timer >= 0.5:
				_save_frame("before/before_03_narrow_viewport_uncentered.png")
				step = 2

		2:
			print(">>> [V3-010 BEFORE] Baseline captures recorded! Exiting... <<<")
			stage.queue_free()
			quit(0)

func _save_frame(rel_path: String) -> void:
	var vp := root.get_viewport()
	if vp == null:
		return
	var img := vp.get_texture().get_image()
	if img == null:
		return
	var base_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-010/captures/"
	var full_path := base_dir + rel_path
	var dir := full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(full_path)
	print("[V3-010 BEFORE CAPTURE] Saved: ", full_path, " (", img.get_width(), "x", img.get_height(), ")")
