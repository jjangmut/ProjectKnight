extends SceneTree

# Stage 1 Onboarding & Multi-Touch Rendered Verification Test for V3-010
const Stage1Class = preload("res://scripts/side_quarter_view/stages/side_qv_stage_1.gd")

var stage: SideQVStage1
var test_phase: int = 0
var sim_time: float = 0.0

func _init() -> void:
	print(">>> [V3-010 ONBOARDING] Initializing Stage 1 Onboarding & Multi-Touch test... <<<")
	call_deferred("_setup_test")

func _setup_test() -> void:
	stage = Stage1Class.new()
	root.add_child(stage)

	# Connect process
	physics_frame.connect(_on_physics_frame)

func _on_physics_frame() -> void:
	sim_time += 1.0 / 60.0

	match test_phase:
		0:
			# Verify Onboarding Guide existence and layout in Stage 1
			if sim_time >= 0.3:
				var mobile_ui = stage.get_node_or_null("SideQVMobileUI")
				assert(mobile_ui != null, "SideQVMobileUI must exist in Stage 1")

				var guide = mobile_ui.get_node_or_null("OnboardingGuideHUD")
				assert(guide != null, "OnboardingGuideHUD must exist in Stage 1")

				var plate = guide.get_node_or_null("GuidePlate") as Panel
				assert(plate != null, "GuidePlate must exist inside OnboardingGuideHUD")
				assert(plate.mouse_filter == Control.MOUSE_FILTER_IGNORE, "GuidePlate mouse_filter must be IGNORE")

				var title_lbl = plate.get_node_or_null("GuideTitle") as Label
				var text_lbl = plate.get_node_or_null("GuideText") as Label
				assert(title_lbl != null and title_lbl.text.contains("TACTICAL ACTION GUIDE"), "Guide title correct")
				assert(text_lbl != null and text_lbl.text.contains("이동"), "Guide text correct")

				print("[V3-010 ONBOARDING] Guide verified: pos=", plate.position, ", size=", plate.size)

				# Capture Screenshot of Stage 1 with Onboarding Guide
				_capture_viewport("01_stage1_onboarding_guide.png")
				test_phase = 1

		1:
			if sim_time >= 0.6:
				# Test Narrow Viewport (1024x720) Responsive Layout
				var guide = stage.get_node_or_null("SideQVMobileUI/OnboardingGuideHUD")
				var plate = guide.get_node_or_null("GuidePlate") as Panel
				var deck = stage.touch_controls
				assert(deck != null, "TouchControlsDeck must exist")

				# Emulate 1024x720
				root.size = Vector2i(1024, 720)
				deck._update_layout()
				stage._update_onboarding_guide_layout()

				var joy = deck.get_node_or_null("RootHUD/JoystickContainer")
				var act = deck.get_node_or_null("RootHUD/ActionContainer")
				print("[V3-010 ONBOARDING] At 1024x720: Guide pos=", plate.position, ", Action pos=", act.position)

				assert(plate.position.x == (1024.0 - plate.size.x) * 0.5, "Guide must be centered at 1024 width")
				assert(act.position.x <= 1024.0 - 240.0, "Action container must not clip past 1024 boundary")

				_capture_viewport("02_narrow_1024_onboarding_and_deck.png")

				# Restore 1280x720
				root.size = Vector2i(1280, 720)
				deck._update_layout()
				stage._update_onboarding_guide_layout()

				test_phase = 2

		2:
			if sim_time >= 1.0:
				# Test Auto-Dismiss on Player Input
				print("[V3-010 ONBOARDING] Simulating player attack action to trigger guide auto-dismiss...")
				Input.action_press("attack")
				# Allow stage _process to detect input
				test_phase = 3

		3:
			Input.action_release("attack")
			if sim_time >= 1.5:
				var guide = stage.get_node_or_null("SideQVMobileUI/OnboardingGuideHUD")
				print("[V3-010 ONBOARDING] Guide after attack input: ", guide)
				assert(guide == null or guide.modulate.a < 0.5, "Onboarding guide must fade out / dismiss on input")

				_capture_viewport("03_stage1_onboarding_dismissed.png")
				test_phase = 4

		4:
			print(">>> [V3-010 ONBOARDING] ALL ONBOARDING TESTS COMPLETED SUCCESSFULLY! <<<")
			stage.queue_free()
			quit(0)

func _capture_viewport(filename: String) -> void:
	var vp := root.get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var dir_path := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-010/captures/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var full_path := dir_path + filename
	img.save_png(full_path)
	print("[V3-010 CAPTURE] Saved frame: ", full_path, " (", img.get_width(), "x", img.get_height(), ")")
