extends SceneTree
## Automated QA Smoke Test for Data-Driven StageLoader and All 5 Stages JSON Balance Sheets.

const StageLoader = preload("res://scripts/stage/stage_loader.gd")

func _init() -> void:
	print("--- START COMPREHENSIVE DATA DRIVEN SMOKE TEST ---")
	var checks := 0
	var failures := 0

	# 1. Verify monsters.json
	var monsters := StageLoader.get_monsters_data()
	checks += 1
	if monsters.is_empty():
		push_error("FAIL: monsters.json is empty")
		failures += 1
	else:
		print("PASS: monsters.json loaded with %d monsters" % monsters.size())

	for expected_id in ["test_enemy", "ranged_enemy", "charging_beast", "ground_slam_golem", "shield_commander"]:
		checks += 1
		if not monsters.has(expected_id):
			push_error("FAIL: missing monster id %s" % expected_id)
			failures += 1

	# 2. Verify player_combat.json
	var combat_data := StageLoader.get_player_combat_data()
	checks += 1
	if combat_data.is_empty() or not combat_data.has("combo_system"):
		push_error("FAIL: player_combat.json invalid structure")
		failures += 1
	else:
		print("PASS: player_combat.json verified")

	# 3. Comprehensive Verification of All 5 Stages
	var expected_stages := [
		{ "id": 1, "width": 11000.0, "encounters": 6, "cp": 2, "optional": 3 },
		{ "id": 2, "width": 11600.0, "encounters": 6, "cp": 2, "optional": 3 },
		{ "id": 3, "width": 12000.0, "encounters": 8, "cp": 3, "optional": 4 },
		{ "id": 4, "width": 11200.0, "encounters": 8, "cp": 3, "optional": 4 },
		{ "id": 5, "width": 12600.0, "encounters": 8, "cp": 3, "optional": 4 }
	]

	var total_width := 0.0
	var total_encounters := 0
	var total_cp := 0
	var total_optional := 0

	for exp in expected_stages:
		var stage_num: int = exp["id"]
		var data := StageLoader.get_stage_data(stage_num)
		checks += 1
		if data.is_empty():
			push_error("FAIL: stage_%02d.json failed to load" % stage_num)
			failures += 1
			continue

		var w: float = float(data.get("world_width", 0.0))
		var enc_count: int = data.get("encounters", []).size()
		var cp_count: int = data.get("checkpoints", []).size()
		var opt_count: int = data.get("optional_routes", []).size()

		total_width += w
		total_encounters += enc_count
		total_cp += cp_count
		total_optional += opt_count

		checks += 4
		if w != exp["width"]:
			push_error("FAIL: Stage %d width mismatch: expected %.0f, got %.0f" % [stage_num, exp["width"], w])
			failures += 1
		if enc_count != exp["encounters"]:
			push_error("FAIL: Stage %d encounters mismatch: expected %d, got %d" % [stage_num, exp["encounters"], enc_count])
			failures += 1
		if cp_count != exp["cp"]:
			push_error("FAIL: Stage %d CP mismatch: expected %d, got %d" % [stage_num, exp["cp"], cp_count])
			failures += 1
		if opt_count != exp["optional"]:
			push_error("FAIL: Stage %d optional routes mismatch: expected %d, got %d" % [stage_num, exp["optional"], opt_count])
			failures += 1

		print("PASS: Stage %d JSON verified (width=%.0f, encounters=%d, CP=%d, optional=%d)" % [stage_num, w, enc_count, cp_count, opt_count])

	# Aggregate Specification Checks (DESIGN/STAGE_EXPANSION_003.md)
	checks += 4
	if total_width != 58400.0:
		push_error("FAIL: Total width mismatch: expected 58400, got %.0f" % total_width)
		failures += 1
	if total_encounters != 36:
		push_error("FAIL: Total encounters mismatch: expected 36, got %d" % total_encounters)
		failures += 1
	if total_cp != 13:
		push_error("FAIL: Total CP mismatch: expected 13, got %d" % total_cp)
		failures += 1
	if total_optional != 18:
		push_error("FAIL: Total optional mismatch: expected 18, got %d" % total_optional)
		failures += 1

	print("PASS: Aggregate campaign metrics verified (Total Width: %.0f, Encounters: %d, CP: %d, Optionals: %d)" % [total_width, total_encounters, total_cp, total_optional])

	# 4. Monster Instantiation & Injection Verification
	var beast := StageLoader.instantiate_monster("charging_beast")
	checks += 1
	if not beast or beast.max_hp != 3:
		push_error("FAIL: charging_beast instantiation failed")
		failures += 1
	else:
		beast.free()

	var boss := StageLoader.instantiate_monster("shield_commander")
	checks += 1
	if not boss or boss.max_hp != 6:
		push_error("FAIL: shield_commander instantiation failed")
		failures += 1
	else:
		boss.free()

	print("--- COMPREHENSIVE SMOKE SUMMARY: %d checks, %d failures ---" % [checks, failures])
	if failures == 0:
		print("ALL_STAGES_DATA_DRIVEN_SMOKE_PASS")
		quit(0)
	else:
		push_error("ALL_STAGES_DATA_DRIVEN_SMOKE_FAIL")
		quit(1)
