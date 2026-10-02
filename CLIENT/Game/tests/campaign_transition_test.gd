extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- START CAMPAIGN TRANSITION TEST ---")
	var campaign_scene := load("res://scenes/stage/Campaign.tscn") as PackedScene
	var campaign = campaign_scene.instantiate()
	root.add_child(campaign)

	for i in range(10):
		await physics_frame

	print("Campaign loaded, stage_index: ", campaign.stage_index)

	# Stage transition must never carry held mobile actions into the next stage.
	Input.action_press("move_down")
	Input.action_press("dash")
	campaign._start_stage(0)
	await physics_frame
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("dash"):
		push_error("FAIL: Stage transition leaked held move_down/dash input")
		campaign.queue_free()
		quit(1)
		return
	print("PASS: Stage transition releases move_down/dash input")

	# Trigger stage 0 clear
	campaign._on_stage_finished(1)

	# Wait for transition timeout (1.5s)
	await create_timer(1.8).timeout
	for i in range(5):
		await physics_frame

	print("Route panel shown, panel valid: ", is_instance_valid(campaign.panel))
	if not is_instance_valid(campaign.panel):
		push_error("FAIL: Route panel not visible")
		quit(1)
		return

	# Simulate choosing trait
	print("Simulating choose_trait('reach')...")
	campaign.choose_trait("reach")

	for i in range(10):
		await physics_frame

	print("Stage index after transition: ", campaign.stage_index)
	print("Selected trait: ", campaign.selected_trait)

	if campaign.stage_index == 1 and campaign.selected_trait == "reach":
		print("PASS: Successfully transitioned to Stage 2 without signal/free errors!")
		campaign.queue_free()
		quit(0)
	else:
		push_error("FAIL: Transition failed")
		quit(1)
