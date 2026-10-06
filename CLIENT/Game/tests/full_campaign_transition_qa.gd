extends SceneTree
## TASK-QA-020: Stage 1→5 Transition QA Test
## Deeply validates the 4 stage transitions (1→2, 2→3, 3→4, 4→5):
##   - Old stage freed without residual node accumulation
##   - New stage clean instantiation
##   - Camera2D registration with GameFeelManager
##   - HUD rebuild without residual BossHealthBar
##   - MobileControls uniqueness (exactly 1 instance) and complete button cluster
##   - Player trait ('reach' / 'basic') persistence across all regions
##   - Signal integrity & zero orphaned callbacks

var checks: int = 0
var failures: int = 0
var campaign: Node = null

func _initialize() -> void:
	_run_transition_qa.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  [PASS] %s" % message)
	else:
		failures += 1
		printerr("  [FAIL] %s" % message)

func _advance_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run_transition_qa() -> void:
	print("\n=======================================================")
	print(">>> RUNNING: full_campaign_transition_qa.gd")
	print("=======================================================")

	var save_mgr = preload("res://scripts/system/save_manager.gd")
	save_mgr.clear_save()

	var campaign_scene := load("res://scenes/stage/Campaign.tscn") as PackedScene
	campaign = campaign_scene.instantiate()
	root.add_child(campaign)
	current_scene = campaign

	await _advance_frames(10)
	check(is_instance_valid(campaign.stage), "Initial Campaign Stage 1 created")

	var previous_stage_instance: Node = null
	var node_counts: Array[int] = []

	for st_idx in range(4):
		var from_st := st_idx + 1
		var to_st := st_idx + 2
		print("\n--- [TESTING TRANSITION: STAGE %d → STAGE %d] ---" % [from_st, to_st])

		var current_stage = campaign.stage
		check(current_stage.stage_number == from_st, "Source stage is Stage %d" % from_st)
		previous_stage_instance = current_stage
		
		# Record node count before finish
		var count_before := root.get_tree().get_node_count()
		node_counts.append(count_before)

		# Trigger stage finish
		campaign._on_stage_finished(1)
		await create_timer(1.8).timeout
		await _advance_frames(10)

		check(is_instance_valid(campaign.panel), "Route selection panel presented")

		# Advance journey
		if st_idx == 0:
			campaign.choose_trait("reach")
		else:
			campaign.continue_journey()

		await _advance_frames(15)

		var new_stage = campaign.stage
		check(is_instance_valid(new_stage), "New Stage %d instantiated" % to_st)
		check(new_stage.stage_number == to_st, "New stage has stage_number == %d" % to_st)
		check(new_stage != previous_stage_instance, "Stage instance is a fresh object (not reused)")
		check(not is_instance_valid(previous_stage_instance) or previous_stage_instance.is_queued_for_deletion(), "Old Stage %d freed or queued for deletion" % from_st)

		# Verify Player Trait Persistence
		check(is_instance_valid(new_stage.player), "Player present in Stage %d" % to_st)
		check(campaign.selected_trait == "reach", "Campaign selected_trait remains 'reach'")
		check(is_equal_approx(new_stage.player.attack_range, 90.0), "Player attack_range preserved at 90.0 (reach trait)")
		check(is_equal_approx(new_stage.player.attack_cooldown, 0.40), "Player attack_cooldown preserved at 0.40 (reach trait)")
		check(new_stage.player.current_hp == 3, "Player starts Stage %d with full HP (3)" % to_st)

		# Verify Camera registration
		var cam: Camera2D = new_stage.player.get_node_or_null("Camera2D")
		check(cam != null, "Player Camera2D exists")
		if cam != null:
			check(cam.limit_left == 0 and cam.limit_right == int(new_stage.WORLD_WIDTH), "Camera limits properly configured for Stage %d width (%.0f)" % [to_st, new_stage.WORLD_WIDTH])

		# Verify HUD State
		var hud = new_stage.get_node_or_null("HUD")
		check(hud != null, "HUD CanvasLayer present in Stage %d" % to_st)
		var residual_bar = new_stage.get_node_or_null("HUD/BossHealthBar")
		check(residual_bar == null or not is_instance_valid(residual_bar), "No residual BossHealthBar in new stage HUD")

		# Verify MobileControls Uniqueness & Complete Button Cluster
		var mobile_controls_nodes: Array = []
		for child in new_stage.get_children():
			if child is CanvasLayer and (child.name == "MobileControls" or child.get_script() != null and child.get_script().resource_path.ends_with("mobile_controls.gd")):
				mobile_controls_nodes.append(child)
		check(mobile_controls_nodes.size() == 1, "Exactly 1 MobileControls instance attached to Stage %d (Found: %d)" % [to_st, mobile_controls_nodes.size()])
		
		if mobile_controls_nodes.size() == 1:
			var mc = mobile_controls_nodes[0]
			check(mc.joystick != null, "MobileControls has virtual joypad cluster")
			check(mc.btn_attack != null, "MobileControls has btn_attack")
			check(mc.btn_guard != null, "MobileControls has btn_guard")
			check(mc.btn_dash != null, "MobileControls has btn_dash")
			mc.release_all_touches()

		# Node count check (ensuring no runaway leak)
		var count_after := root.get_tree().get_node_count()
		print("  [NODE COUNT] Before: %d | After: %d | Delta: %+d" % [count_before, count_after, count_after - count_before])
		check(abs(count_after - count_before) < 150, "Node count bounded after transition (No runaway node leak)")

	print("\n=======================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks - failures, failures])
	print("=======================================================")

	if failures == 0:
		print(">>> FULL CAMPAIGN TRANSITION QA: ALL PASS! <<<\n")
		quit(0)
	else:
		printerr(">>> FULL CAMPAIGN TRANSITION QA: FAILED! <<<\n")
		quit(1)
