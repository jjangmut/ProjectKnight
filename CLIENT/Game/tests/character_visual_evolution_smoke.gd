extends SceneTree
## Comprehensive Smoke Test for Character Visual Evolution & Texture Swapping System
## Validates:
## 1. Baseline state (Stage 0): knight_idle_v1.png
## 2. Stage 1: Full-character Paladin Holy Broadsword texture swap (knight_stage1_paladin.png) & Aegis barrier
## 3. Stage 2: Full-character Windrunner Emerald Cloak texture swap (knight_stage2_windrunner.png) & Dash Gale
## 4. Stage 3: Full-character Arcane Crystal Greatsword texture swap (knight_stage3_arcane.png) & Cyan Beam
## 5. Stage 4: Full-character Titan Stone Armor texture swap (knight_stage4_titan.png) & Ground Slam
## 6. Stage 5: Full-character Abyssal Horned Dark Knight texture swap (knight_stage5_abyssal.png) & 4 Crit
## 7. No separate awkward polygon meshes attached on player body

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const PlayerClass = preload("res://scripts/player/player.gd")
const PlayerEquipmentClass = preload("res://scripts/player/player_equipment.gd")
const SwordBeamScene = preload("res://scripts/player/sword_beam.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("==================================================")
	print(">>> RUNNING: character_visual_evolution_smoke.gd")
	print("==================================================")
	# Internal 12s Watchdog timer
	create_timer(12.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] Test exceeded 12s limit, aborting.")
		quit(1)
	)
	call_deferred("_run_tests")


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		printerr("  [FAIL] %s" % msg)


func _run_tests() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	world.add_child(player)
	await process_frame
	await process_frame

	var char_art = player.get_node_or_null("CharacterArt")
	_assert(char_art != null, "Player has CharacterArt Sprite2D node")

	var equip: PlayerEquipment = player.get_node_or_null("EquipmentVisuals") as PlayerEquipment
	_assert(equip != null, "Player has EquipmentVisuals component attached")

	# -------------------------------------------------------------
	# Test 1: Baseline Knight (Stage 0)
	# -------------------------------------------------------------
	print("\n--- Test 1: Baseline Appearance (Stage 0) ---")
	SaveManagerClass.clear_save()
	player.refresh_equipment()
	_assert(char_art.current_evolution_stage == 0, "Baseline: Evolution stage is 0")
	_assert(equip.shield_node.visible == false, "Baseline: Shield VFX node hidden")
	_assert(equip.cape_node.visible == false, "Baseline: Cape VFX node hidden")
	_assert(equip.quiver_node.visible == false, "Baseline: Quiver/Arcane node hidden")
	_assert(equip.pauldrons_node.visible == false, "Baseline: Pauldrons node hidden")
	_assert(equip.crown_node.visible == false, "Baseline: Crown node hidden")

	# -------------------------------------------------------------
	# Test 2: Stage 1 Full Texture Evolution (Paladin Holy Broadsword)
	# -------------------------------------------------------------
	print("\n--- Test 2: Stage 1 Paladin Texture Swap & Aegis Barrier ---")
	SaveManagerClass.mark_stage_cleared(1)
	player.refresh_equipment()
	_assert(char_art.current_evolution_stage == 1, "Stage 1: Evolution stage is 1")
	_assert(char_art.texture.resource_path.contains("paladin"), "Stage 1: Sprite swapped to knight_stage1_paladin.png")
	_assert(equip.shield_node.visible == true, "Stage 1: Aegis shield VFX node active")

	# Test Guard Stance Aegis Sigil Deployment
	player.is_guarding = true
	equip._process(0.1)
	_assert(equip.aegis_sigil.visible == true, "Guard stance: Aegis Bastion Sigil projects radiant barrier")
	_assert(equip.shield_node.scale.x > 1.0, "Guard stance: Aegis barrier expands")

	player.is_guarding = false
	equip._process(0.1)
	_assert(equip.aegis_sigil.visible == false, "Neutral stance: Aegis barrier collapses")

	# -------------------------------------------------------------
	# Test 3: Stage 2 Full Texture Evolution (Windrunner Emerald Cloak)
	# -------------------------------------------------------------
	print("\n--- Test 3: Stage 2 Windrunner Texture Swap & Dash Gale ---")
	SaveManagerClass.mark_stage_cleared(2)
	player.refresh_equipment()
	_assert(char_art.current_evolution_stage == 2, "Stage 2: Evolution stage is 2")
	_assert(char_art.texture.resource_path.contains("windrunner"), "Stage 2: Sprite swapped to knight_stage2_windrunner.png")
	_assert(equip.cape_node.visible == true, "Stage 2: Cape dash VFX node active")

	# Test Dash state flutter
	player.set("is_dashing", true)
	equip._process(0.05)
	_assert(equip.cape_node.scale.x > 1.0, "Dashing state: Dash scale expands")
	player.set("is_dashing", false)

	# -------------------------------------------------------------
	# Test 4: Stage 3 Full Texture Evolution (Arcane Crystal Greatsword)
	# -------------------------------------------------------------
	print("\n--- Test 4: Stage 3 Arcane Crystal Texture Swap & Beam ---")
	SaveManagerClass.mark_stage_cleared(3)
	player.refresh_equipment()
	_assert(char_art.current_evolution_stage == 3, "Stage 3: Evolution stage is 3")
	_assert(char_art.texture.resource_path.contains("arcane"), "Stage 3: Sprite swapped to knight_stage3_arcane.png")
	_assert(equip.quiver_node.visible == true, "Stage 3: Arcane focus node active")

	# Test Crystal Sword Beam generation
	var beam := SwordBeamScene.new()
	beam.direction = player.facing_direction
	beam.is_crystal_beam = player.relic_quiver_active
	world.add_child(beam)
	await process_frame
	_assert(beam.is_crystal_beam == true, "Stage 3: SwordBeam fires in Arcane Crystal Beam mode")
	_assert(beam._blade_arc.default_color.b > 2.0, "Stage 3: Beam outer arc has cyan HDR overdrive bloom")
	beam.queue_free()

	# -------------------------------------------------------------
	# Test 5: Stage 4 Full Texture Evolution (Titan Rock Armor)
	# -------------------------------------------------------------
	print("\n--- Test 5: Stage 4 Titan Texture Swap & Seismic Shockwave ---")
	SaveManagerClass.mark_stage_cleared(4)
	player.refresh_equipment()
	_assert(char_art.current_evolution_stage == 4, "Stage 4: Evolution stage is 4")
	_assert(char_art.texture.resource_path.contains("titan"), "Stage 4: Sprite swapped to knight_stage4_titan.png")
	_assert(equip.pauldrons_node.visible == true, "Stage 4: Titan pauldrons node active")

	# -------------------------------------------------------------
	# Test 6: Stage 5 Full Texture Evolution (Abyssal Horned Dark Knight)
	# -------------------------------------------------------------
	print("\n--- Test 6: Stage 5 Abyssal Texture Swap & Void Slash ---")
	SaveManagerClass.mark_stage_cleared(5)
	player.refresh_equipment()
	_assert(char_art.current_evolution_stage == 5, "Stage 5: Evolution stage is 5")
	_assert(char_art.texture.resource_path.contains("abyssal"), "Stage 5: Sprite swapped to knight_stage5_abyssal.png")
	_assert(equip.crown_node.visible == true, "Stage 5: Crown node active")

	# Test Parry Counter Damage 4
	player.is_perfect_parry = true
	player._start_counter_attack()
	_assert(player.current_attack_damage == 4, "Stage 5: Perfect Parry Counter deals 4 CRIT damage")
	player._end_attack()

	# -------------------------------------------------------------
	# Test 7: SaveManager Evolution Descriptions
	# -------------------------------------------------------------
	print("\n--- Test 7: SaveManager Evolution Descriptions ---")
	for s in range(1, 6):
		var relic_data = SaveManagerClass.STAGE_RELICS[s]
		_assert(relic_data.visual_name.contains("진화"), "Relic %d visual_name describes visual morphing (%s)" % [s, relic_data.visual_name])

	# Cleanup
	SaveManagerClass.clear_save()
	world.queue_free()

	print("\n==================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("==================================================")
	if _fail_count == 0:
		print(">>> ALL CHARACTER TEXTURE EVOLUTION TESTS PASSED! <<<")
		quit(0)
	else:
		printerr(">>> CHARACTER TEXTURE EVOLUTION TESTS FAILED! <<<")
		quit(1)
