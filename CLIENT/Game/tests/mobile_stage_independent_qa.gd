extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func freeze(stage: Node) -> void:
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
func activate(stage: Node, index: int) -> void:
	stage.player.position = Vector2(stage.optional_groups[index].x, stage.optional_groups[index].y)
	stage._update_optional_routes()
	for actor in stage.optional_groups[index].actors:
		actor.set_physics_process(false)
func defeat(stage: Node, index: int) -> void:
	for actor in stage.optional_groups[index].actors:
		while actor.current_hp > 0:
			actor.receive_hit()
	stage._update_optional_routes()
func _run() -> void:
	for number in range(5):
		var campaign = load("res://scenes/stage/Campaign.tscn").instantiate()
		root.add_child(campaign)
		current_scene = campaign
		campaign._start_stage(number)
		var stage = campaign.stage
		freeze(stage)
		stage._resume_checkpoint()
		activate(stage, 0)
		stage.player.current_hp = 2
		defeat(stage, 0)
		check(stage.player.current_hp == 3 and stage.optional_completed[0], "Stage%d optional reward HP+1" % number)
		stage.player.current_hp = 2
		stage._update_optional_routes()
		check(stage.player.current_hp == 2, "Repeated poll cannot farm reward")
		activate(stage, 1)
		stage.player.current_hp = 3
		defeat(stage, 1)
		stage.player.current_hp = 2
		stage._update_optional_routes()
		check(stage.player.current_hp == 2 and stage.optional_completed[1], "Full-HP clear still consumes reward")
		stage.player._die()
		stage._evaluate_stage()
		await create_timer(1.65).timeout
		stage = campaign.stage
		freeze(stage)
		check(stage.optional_completed[0] and stage.optional_completed[1] and not stage.optional_completed.slice(2).has(true) and stage.player.current_hp == 3, "Campaign checkpoint reload preserves consumed branches and HP3")
		stage.player.current_hp = 1
		activate(stage, 0)
		activate(stage, 1)
		check(stage.player.current_hp == 1 and stage.optional_groups[0].actors.is_empty() and stage.optional_groups[1].actors.is_empty(), "Checkpoint replay neither respawns cleared branches nor farms heal")
		campaign._start_stage(number)
		stage = campaign.stage
		freeze(stage)
		check(not stage.optional_completed.has(true), "Fresh non-checkpoint run resets optional progress")
		activate(stage, 0)
		stage.player.current_hp = 1
		for actor in stage.optional_groups[0].actors:
			actor.queue_free()
		await process_frame
		stage._update_optional_routes()
		check(not stage.optional_completed[0] and stage.player.current_hp == 1, "Unexpected actor deletion cannot claim combat reward")
		campaign.free()
		await process_frame
	print("MOBILE_STAGE_INDEPENDENT_QA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
