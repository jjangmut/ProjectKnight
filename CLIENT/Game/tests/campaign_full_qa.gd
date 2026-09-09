extends SceneTree
## Independent real-physics traversal fixtures, not human pacing evidence.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func _run() -> void:
	for number in [3, 4, 5]:
		var path: String = ["ThirdStage", "FourthStage", "FifthStage"][number - 3]
		var stage: Node = load("res://scenes/stage/%s.tscn" % path).instantiate()
		stage.campaign_mode = true
		root.add_child(stage)
		current_scene = stage
		stage.set_physics_process(false)
		var player: Node = stage.player
		for gate in stage.gates:
			gate.queue_free()
		await frames(3)
		# No teleport during traversal: ordinary input across every mandatory ridge.
		for start_x in [1420.0, 4330.0]:
			player.position = Vector2(start_x, 580)
			player.velocity = Vector2.ZERO
			await frames(15)
			Input.action_press("move_right")
			await frames(130)
			Input.action_release("move_right")
			check(player.position.x > start_x + 470, "Stage%d ridge traversable by normal input at %s" % [number, start_x])
			check(player.position.y < 625 and not player.is_dead, "Stage%d ridge no fall softlock" % number)
		if number == 3 or number == 5:
			player.position = Vector2(stage.route_clusters[1].left + 40, 580)
			player.velocity = Vector2.ZERO
			await frames(15)
			Input.action_press("jump")
			await frames(1)
			Input.action_release("jump")
			await frames(52)
			check(player.is_on_floor() and absf(player.position.y - 532.0) < 3.0, "Stage%d second upper route entry reachable (y=%s)" % [number, player.position.y])
			var target_x: float = stage.route_clusters[0].left + 40.0
			player.position = Vector2(target_x, 580)
			player.velocity = Vector2.ZERO
			await frames(15)
			Input.action_press("jump")
			await frames(1)
			Input.action_release("jump")
			await frames(52)
			check(player.is_on_floor() and absf(player.position.y - 532.0) < 3.0, "Stage%d first upper route entry reachable by normal single jump (y=%s)" % [number, player.position.y])
			Input.action_press("move_right")
			await frames(60)
			Input.action_release("move_right")
			check(player.is_on_floor() and player.position.y < 625, "Stage%d missed perch safely lands" % number)
		# Same-tick death must win even with every encounter already complete.
		player.set_physics_process(false)
		stage.completed.fill(true)
		stage.encounter_index = stage.completed.size()
		player.position = Vector2(stage.GOAL_X, 580)
		player.current_hp = 0
		stage._evaluate_stage()
		check(stage.stage_state == 2, "Stage%d simultaneous goal and death FAILED" % number)
		stage._finish(1)
		check(stage.stage_state == 2, "Stage%d late clear cannot replace FAILED" % number)
		stage.free()
		await process_frame
	var arena: Node = load("res://scenes/stage/FourthStage.tscn").instantiate()
	arena.campaign_mode = true
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena._start_encounter()
	var golem: Node = arena.enemies[0]
	arena.player.position = Vector2(golem.position.x + 75, 580)
	await frames(31)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(34)
	check(golem.attack_count >= 1, "Golem naturally starts attack on nearby player")
	check(arena.player.current_hp == 3, "Ordinary timed single jump evades actual golem slam")
	check(golem.attack_phase == 2, "Golem reaches punishable recovery after ordinary jump")
	arena.free()
	print("FULL CAMPAIGN INDEPENDENT QA: %d checks, %d failures; fixtures not human duration" % [checks, failures])
	quit(1 if failures else 0)
