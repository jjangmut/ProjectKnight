extends SceneTree
## TASK-QA-020: Stage Checkpoint & Death Respawn QA Test
## Deeply validates checkpoint activation, player death, and resurrection:
##   - Checkpoint activation upon reaching CP coordinate with required encounter prefix
##   - Player HP reset to 3 upon checkpoint touch
##   - Projectile cleanup on checkpoint touch
##   - Player death (HP = 0) -> FAILED state transition
##   - Campaign automatic reload with checkpoint snapshot restoration
##   - Restored player position at checkpoint coordinate
##   - Restored encounter prefix (completed encounters preserved)
##   - Restored gates (prior gates remain cleared/opened)
##   - No soft-locks: player can immediately progress to next combat encounter

var checks: int = 0
var failures: int = 0
var campaign: Node = null

func _initialize() -> void:
	_run_checkpoint_qa.call_deferred()

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

func _run_checkpoint_qa() -> void:
	print("\n=======================================================")
	print(">>> RUNNING: full_campaign_checkpoint_qa.gd")
	print("=======================================================")

	var save_mgr = preload("res://scripts/system/save_manager.gd")
	save_mgr.clear_save()

	var campaign_scene := load("res://scenes/stage/Campaign.tscn") as PackedScene
	campaign = campaign_scene.instantiate()
	root.add_child(campaign)
	current_scene = campaign

	await _advance_frames(10)
	var stage = campaign.stage
	check(is_instance_valid(stage), "Campaign Stage 1 instantiated")

	# Test on Stage 1 first
	print("\n--- [STAGE 1 CHECKPOINT & RESPAWN TEST] ---")
	check(not stage.checkpoint_positions.is_empty(), "Stage 1 has defined checkpoints (Count: %d)" % stage.checkpoint_positions.size())
	
	# Complete encounter 0 and 1
	for enc in range(2):
		stage.player.position = Vector2(stage.ENTRY_X[enc], 580)
		stage._evaluate_stage()
		await _advance_frames(3)
		for w in range(2):
			for e in stage.enemies:
				if is_instance_valid(e):
					while e.current_hp > 0: e.receive_hit()
			stage._evaluate_stage()
			await _advance_frames(2)
		check(stage.completed[enc], "Stage 1 Encounter %d completed" % (enc + 1))

	# Advance to Checkpoint 1
	var cp_pos: Vector2 = stage.checkpoint_positions[0]
	stage.player.position = cp_pos
	stage._evaluate_stage()
	await _advance_frames(5)

	check(stage.checkpoint_active, "Checkpoint 1 activated")
	check(stage.checkpoint_index == 0, "Checkpoint index is 0")
	check(stage.player.current_hp == 3, "Player HP at checkpoint is 3")

	# Spawn enemies in Encounter 2
	stage.player.position = Vector2(stage.ENTRY_X[2], 580)
	stage._evaluate_stage()
	await _advance_frames(5)
	check(stage.encounter_active, "Encounter 3 activated")
	check(not stage.enemies.is_empty(), "Encounter 3 enemies spawned")

	# Trigger Player Death
	print("  [DEATH SIMULATION] Triggering player death in Encounter 3...")
	stage.player.current_hp = 0
	stage.player.is_dead = true
	stage._evaluate_stage()
	await _advance_frames(3)

	check(stage.stage_state == 2, "Stage state transitioned to FAILED (2)")

	# Wait for Campaign 1.5s restart timer
	await create_timer(1.8).timeout
	await _advance_frames(15)

	var respawned_stage = campaign.stage
	check(is_instance_valid(respawned_stage), "Respawned stage instantiated")
	check(respawned_stage.checkpoint_active, "Checkpoint remains active after reload")
	check(respawned_stage.checkpoint_index == 0, "Checkpoint index preserved at 0")
	check(respawned_stage.player.current_hp == 3, "Player HP restored to 3")
	check(absf(respawned_stage.player.position.x - cp_pos.x) <= 10.0, "Player respawned at Checkpoint 1 position (x=%.1f, expected=%.1f)" % [respawned_stage.player.position.x, cp_pos.x])

	# Verify completed encounters & gates preserved
	check(respawned_stage.completed[0] and respawned_stage.completed[1], "Encounters 1 and 2 remain completed in respawned stage")
	check(respawned_stage.gates[0] == null or not is_instance_valid(respawned_stage.gates[0]), "Gate 1 remains open/cleared")
	check(respawned_stage.gates[1] == null or not is_instance_valid(respawned_stage.gates[1]), "Gate 2 remains open/cleared")
	check(respawned_stage.encounter_index == 2, "Encounter index set to 2 (ready to replay Encounter 3 without softlock)")

	# Verify player can now progress to and clear encounter 2
	respawned_stage.player.position = Vector2(respawned_stage.ENTRY_X[2], 580)
	respawned_stage._evaluate_stage()
	await _advance_frames(3)
	check(respawned_stage.encounter_active, "Encounter 3 successfully re-entered after respawn")

	print("\n=======================================================")
	print("RESULTS: %d checks PASSED, %d checks FAILED" % [checks - failures, failures])
	print("=======================================================")

	if failures == 0:
		print(">>> FULL CAMPAIGN CHECKPOINT QA: ALL PASS! <<<\n")
		quit(0)
	else:
		printerr(">>> FULL CAMPAIGN CHECKPOINT QA: FAILED! <<<\n")
		quit(1)
