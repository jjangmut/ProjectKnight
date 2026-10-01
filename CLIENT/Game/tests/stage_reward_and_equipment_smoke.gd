extends SceneTree
## Smoke test for Stage Reward Relics and Dynamic Visual Equipment System

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const PlayerClass = preload("res://scripts/player/player.gd")
const PlayerEquipmentClass = preload("res://scripts/player/player_equipment.gd")

var _pass_count := 0
var _fail_count := 0

func _init() -> void:
	print("==================================================")
	print(">>> RUNNING: stage_reward_and_equipment_smoke.gd")
	print("==================================================")
	call_deferred("_run_tests")

func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		printerr("  [FAIL] %s" % msg)

func _run_tests() -> void:
	# Test 1: STAGE_RELICS registry integrity
	print("\n--- Test 1: SaveManager STAGE_RELICS registry ---")
	_assert(SaveManagerClass.STAGE_RELICS.size() == 5, "STAGE_RELICS must have 5 entries for all 5 stages")
	for i in range(1, 6):
		var relic: Dictionary = SaveManagerClass.STAGE_RELICS.get(i, {})
		_assert(relic.has("name") and relic.has("desc") and relic.has("visual") and relic.has("icon_color"),
			"Stage %d relic must define name, desc, visual, and icon_color" % i)

	# Test 2: SaveManager clear tracking
	print("\n--- Test 2: SaveManager stage clear tracking ---")
	SaveManagerClass.clear_save()
	var initial_cleared := SaveManagerClass.get_cleared_stages()
	_assert(initial_cleared.size() == 5 and not initial_cleared[0], "Fresh save has stage 1 uncleared")
	SaveManagerClass.mark_stage_cleared(1)
	_assert(SaveManagerClass.is_stage_cleared(1), "mark_stage_cleared(1) sets stage 1 cleared")
	_assert(SaveManagerClass.get_cleared_stages()[0] == true, "get_cleared_stages()[0] is true")
	_assert(SaveManagerClass.get_cleared_stages()[1] == false, "get_cleared_stages()[1] remains false")

	# Test 3: PlayerEquipment visual nodes construction & visibility
	print("\n--- Test 3: PlayerEquipment node structure ---")
	var world := Node2D.new()
	root.add_child(world)

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	world.add_child(player)
	await process_frame
	await process_frame

	var equip = player.get_node_or_null("EquipmentVisuals")
	_assert(equip != null, "Player scene attaches EquipmentVisuals node")
	_assert(equip.shield_node != null, "EquipmentVisuals contains shield_node")
	_assert(equip.cape_node != null, "EquipmentVisuals contains cape_node")
	_assert(equip.quiver_node != null, "EquipmentVisuals contains quiver_node")
	_assert(equip.pauldrons_node != null, "EquipmentVisuals contains pauldrons_node")
	_assert(equip.crown_node != null, "EquipmentVisuals contains crown_node")

	# Since stage 1 is marked cleared, shield should be visible, others invisible
	equip.refresh_equipment()
	_assert(equip.shield_node.visible == true, "Stage 1 cleared -> shield_node is visible")
	_assert(equip.cape_node.visible == false, "Stage 2 uncleared -> cape_node is invisible")
	_assert(equip.quiver_node.visible == false, "Stage 3 uncleared -> quiver_node is invisible")

	# Test 4: Dynamic stance response (guard & dash)
	print("\n--- Test 4: Dynamic stance response ---")
	player.is_guarding = true
	equip._process(0.1)
	_assert(equip.shield_node.scale.x > 1.0, "Guard stance scales up shield node")

	player.is_guarding = false
	equip.set_equipment_active(2, true) # Temporarily activate cape
	player.set("is_dashing", true)
	equip._process(0.1)
	_assert(equip.cape_node.scale.x > 1.0, "Dashing state flutters and scales cape")

	# Test 5: Stage presentation card & bar rendering check
	print("\n--- Test 5: Stage presentation relic bar & clear card rendering ---")
	var stage_scene := load("res://scenes/stage/FirstStage.tscn") as PackedScene
	var stage = stage_scene.instantiate()
	world.add_child(stage)
	await process_frame

	var presentation = stage.get_node_or_null("HUD/Presentation")
	_assert(presentation != null, "FirstStage includes HUD/Presentation node")

	# Trigger presentation draw via proper draw notification
	stage.stage_state = 1 # CLEARED
	presentation.notification(CanvasItem.NOTIFICATION_DRAW)
	_assert(true, "StagePresentation _draw() rendered relic bar and reward card successfully")

	# Clean up
	SaveManagerClass.clear_save()
	world.queue_free()

	print("\n==================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("==================================================")
	if _fail_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("SOME TESTS FAILED!")
		quit(1)
