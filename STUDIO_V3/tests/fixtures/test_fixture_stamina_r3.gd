# D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/tests/fixtures/test_fixture_stamina_r3.gd
# Independent QA Lead Comprehensive Test Suite: Advanced Stamina & Dash System (Cycle 2 Retest)
# Target: fixture_stamina_component_r3.gd
# Verification of Defect ISS-LIVE-003 Remediation
extends SceneTree

const FIXTURE_PATH := "res://STUDIO_V3/tests/fixtures/fixture_stamina_component_r3.gd"

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

var signal_log: Dictionary = {
	"stamina_changed": [],
	"stamina_depleted": 0,
	"stamina_recovered": 0,
	"dash_performed": [],
	"exhaustion_state_changed": []
}

func _initialize() -> void:
	_run_all_tests.call_deferred()

func _reset_signals() -> void:
	signal_log["stamina_changed"].clear()
	signal_log["stamina_depleted"] = 0
	signal_log["stamina_recovered"] = 0
	signal_log["dash_performed"].clear()
	signal_log["exhaustion_state_changed"].clear()

func _bind_signals(fixture: Node) -> void:
	_reset_signals()
	fixture.stamina_changed.connect(func(cur: float, max_v: float): signal_log["stamina_changed"].append(Vector2(cur, max_v)))
	fixture.stamina_depleted.connect(func(): signal_log["stamina_depleted"] += 1)
	fixture.stamina_recovered.connect(func(): signal_log["stamina_recovered"] += 1)
	fixture.dash_performed.connect(func(cost: float): signal_log["dash_performed"].append(cost))
	fixture.exhaustion_state_changed.connect(func(ex: bool): signal_log["exhaustion_state_changed"].append(ex))

func assert_true(condition: bool, test_name: String, details: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		var err_msg = "  [FAIL] %s - %s" % [test_name, details]
		push_error(err_msg)
		print(err_msg)

func assert_float_eq(actual: float, expected: float, test_name: String, tolerance: float = 0.001) -> void:
	total_tests += 1
	var diff = absf(actual - expected)
	if diff <= tolerance:
		passed_tests += 1
		print("  [PASS] %s (actual: %.2f == expected: %.2f)" % [test_name, actual, expected])
	else:
		failed_tests += 1
		var err_msg = "  [FAIL] %s - Expected %.2f (+/- %.3f), got %.2f" % [test_name, expected, tolerance, actual]
		push_error(err_msg)
		print(err_msg)

func _run_all_tests() -> void:
	print("================================================================================")
	print("PROJECTKNIGHT QA: INDEPENDENT HEADLESS RETEST SUITE FOR ISS-LIVE-003 (CYCLE 2)")
	print("Engine: Godot 4.7.2 Headless")
	print("Fixture: %s" % FIXTURE_PATH)
	print("================================================================================")

	var fixture_script = load(FIXTURE_PATH)
	if not fixture_script:
		push_error("CRITICAL: Failed to load fixture script from %s" % FIXTURE_PATH)
		quit(1)
		return

	var fixture = fixture_script.new()
	_bind_signals(fixture)

	# --------------------------------------------------------------------------
	# TEST 1: Initialization & Initial Values
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 1: Initialization & Initial Values ---")
	fixture.init(100.0)
	assert_float_eq(fixture.max_stamina, 100.0, "Init: max_stamina initialized to 100.0")
	assert_float_eq(fixture.current_stamina, 100.0, "Init: current_stamina initialized to 100.0")
	assert_float_eq(fixture.dash_cooldown_remaining, 0.0, "Init: dash_cooldown_remaining initialized to 0.0")
	assert_true(not fixture.is_exhausted, "Init: is_exhausted initialized to false")
	assert_true(fixture.can_dash(), "Init: can_dash() is true")
	assert_true(signal_log["stamina_changed"].size() == 1 and signal_log["stamina_changed"][0] == Vector2(100.0, 100.0), "Init: stamina_changed(100.0, 100.0) emitted")
	assert_true(signal_log["exhaustion_state_changed"].size() == 1 and signal_log["exhaustion_state_changed"][0] == false, "Init: exhaustion_state_changed(false) emitted")

	# --------------------------------------------------------------------------
	# TEST 2: Basic Consumption & Clamping
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 2: Basic Consumption & Clamping ---")
	_reset_signals()
	var consume_res: bool = fixture.consume_stamina(40.0)
	assert_true(consume_res, "Consume: consume_stamina(40.0) returns true")
	assert_float_eq(fixture.current_stamina, 60.0, "Consume: current_stamina decremented to 60.0")
	assert_true(not fixture.is_exhausted, "Consume: character remains unexhausted at 60.0")
	assert_true(signal_log["stamina_changed"].size() == 1 and signal_log["stamina_changed"][0] == Vector2(60.0, 100.0), "Consume: stamina_changed emitted with 60.0")

	# Invalid consumption inputs
	var neg_res: bool = fixture.consume_stamina(-10.0)
	assert_true(not neg_res, "Consume: negative amount (-10.0) rejected")
	var zero_res: bool = fixture.consume_stamina(0.0)
	assert_true(not zero_res, "Consume: zero amount (0.0) rejected")
	assert_float_eq(fixture.current_stamina, 60.0, "Consume: stamina unaffected by invalid amounts")

	# --------------------------------------------------------------------------
	# TEST 3: Exhaustion Trigger on Reaching 0.0 Stamina
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 3: Exhaustion Trigger on Reaching 0.0 Stamina ---")
	_reset_signals()
	var drain_res: bool = fixture.consume_stamina(60.0)
	assert_true(drain_res, "Exhaustion: consume_stamina(60.0) drained stamina to zero")
	assert_float_eq(fixture.current_stamina, 0.0, "Exhaustion: current_stamina is exactly 0.0")
	assert_true(fixture.is_exhausted, "Exhaustion: is_exhausted transitioned to true")
	assert_true(signal_log["stamina_depleted"] == 1, "Exhaustion: stamina_depleted signal fired")
	assert_true(signal_log["exhaustion_state_changed"].size() == 1 and signal_log["exhaustion_state_changed"][0] == true, "Exhaustion: exhaustion_state_changed(true) fired")
	assert_true(not fixture.can_dash(), "Exhaustion: can_dash() returns false when exhausted")

	# --------------------------------------------------------------------------
	# TEST 4: Dash Rejection While Exhausted (ISS-LIVE-003 Remediation Verification)
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 4: Dash Rejection While Exhausted (ISS-LIVE-003 Core) ---")
	_reset_signals()
	var dash_while_exhausted: bool = fixture.consume_dash()
	assert_true(not dash_while_exhausted, "ISS-LIVE-003: consume_dash() MUST return false while exhausted")
	assert_float_eq(fixture.current_stamina, 0.0, "ISS-LIVE-003: current_stamina remains clamped at 0.0 (NO UNDERFLOW)")
	assert_float_eq(fixture.dash_cooldown_remaining, 0.0, "ISS-LIVE-003: dash cooldown remaining remains 0.0")
	assert_true(signal_log["dash_performed"].is_empty(), "ISS-LIVE-003: NO dash_performed signal emitted")
	assert_true(signal_log["stamina_changed"].is_empty(), "ISS-LIVE-003: NO stamina_changed signal emitted")

	# --------------------------------------------------------------------------
	# TEST 5: Overconsumption Rejection (Cannot Consume More Than Current)
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 5: Overconsumption Rejection ---")
	fixture.init(20.0)
	_reset_signals()
	assert_float_eq(fixture.current_stamina, 20.0, "Overconsumption: initialized to 20.0")
	var over_res: bool = fixture.consume_stamina(25.0)
	assert_true(not over_res, "Overconsumption: consume_stamina(25.0) rejected when current is 20.0")
	assert_float_eq(fixture.current_stamina, 20.0, "Overconsumption: current_stamina unchanged at 20.0")
	assert_true(not fixture.can_dash(), "Overconsumption: can_dash() returns false when stamina (20.0) < dash_cost (25.0)")
	var over_dash: bool = fixture.consume_dash()
	assert_true(not over_dash, "Overconsumption: consume_dash() rejected when stamina < dash_cost")
	assert_float_eq(fixture.current_stamina, 20.0, "Overconsumption: stamina unchanged at 20.0 (NO underflow to -5.0)")

	# --------------------------------------------------------------------------
	# TEST 6: Dash Consumption Deduction Accuracy & Signal Emissions
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 6: Dash Consumption Deduction Accuracy & Signals ---")
	fixture.init(100.0)
	_reset_signals()
	var legal_dash: bool = fixture.consume_dash()
	assert_true(legal_dash, "Dash Accuracy: consume_dash() returns true with full stamina")
	assert_float_eq(fixture.current_stamina, 75.0, "Dash Accuracy: current_stamina accurately decremented by 25.0 to 75.0")
	assert_float_eq(fixture.dash_cooldown_remaining, 0.5, "Dash Accuracy: dash_cooldown_remaining set to 0.5")
	assert_true(signal_log["dash_performed"].size() == 1 and signal_log["dash_performed"][0] == 25.0, "Dash Signals: dash_performed emitted with cost 25.0")
	assert_true(signal_log["stamina_changed"].size() == 1 and signal_log["stamina_changed"][0] == Vector2(75.0, 100.0), "Dash Signals: stamina_changed emitted with (75.0, 100.0)")
	assert_true(not fixture.can_dash(), "Dash Accuracy: can_dash() is false while cooldown is active")

	# --------------------------------------------------------------------------
	# TEST 7: Dash Cooldown Enforcement and Recovery (ISS-LIVE-003 Remediation)
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 7: Dash Cooldown Enforcement and Recovery ---")
	_reset_signals()
	var cd_spam: bool = fixture.consume_dash()
	assert_true(not cd_spam, "ISS-LIVE-003 Cooldown: consume_dash() rejected during active cooldown (0.5s)")
	assert_float_eq(fixture.current_stamina, 75.0, "ISS-LIVE-003 Cooldown: stamina preserved at 75.0 on rejection")

	# Decrement cooldown by 0.2s
	fixture.update_cooldown(0.2)
	assert_float_eq(fixture.dash_cooldown_remaining, 0.3, "Cooldown Update: remaining decremented to 0.3s")
	assert_true(not fixture.can_dash(), "Cooldown Update: can_dash() still false at 0.3s")
	assert_true(not fixture.consume_dash(), "Cooldown Update: consume_dash() still rejected at 0.3s")

	# Decrement cooldown past zero by 0.35s
	fixture.update_cooldown(0.35)
	assert_float_eq(fixture.dash_cooldown_remaining, 0.0, "Cooldown Update: remaining expired and clamped to 0.0s")
	assert_true(fixture.can_dash(), "Cooldown Update: can_dash() restored to true")
	var dash_post_cd: bool = fixture.consume_dash()
	assert_true(dash_post_cd, "Cooldown Update: second dash succeeded after cooldown expiration")
	assert_float_eq(fixture.current_stamina, 50.0, "Cooldown Update: stamina decremented to 50.0")
	assert_float_eq(fixture.dash_cooldown_remaining, 0.5, "Cooldown Update: cooldown re-engaged to 0.5s")

	# --------------------------------------------------------------------------
	# TEST 8: Exhaustion Recovery Threshold (Recovers Only At Or Above 30.0)
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 8: Exhaustion Recovery Threshold (Threshold >= 30.0) ---")
	fixture.update_cooldown(1.0) # Ensure cooldown from previous test group is fully elapsed
	# Drain remaining 50.0 stamina to enter exhausted state
	fixture.consume_stamina(50.0)
	assert_true(fixture.is_exhausted, "Threshold: fixture successfully placed into exhausted state")
	assert_float_eq(fixture.current_stamina, 0.0, "Threshold: stamina is 0.0")

	_reset_signals()
	# Step 8.1: Regenerate 1.0s (15.0 stamina/sec -> 15.0 stamina)
	fixture.regenerate(1.0)
	assert_float_eq(fixture.current_stamina, 15.0, "Threshold: current_stamina is 15.0 after 1.0s")
	assert_true(fixture.is_exhausted, "Threshold: STILL exhausted at 15.0 stamina (below 30.0 threshold)")
	assert_true(not fixture.can_dash(), "Threshold: can_dash() is false while exhausted below threshold")
	assert_true(not fixture.consume_dash(), "Threshold: consume_dash() rejected while exhausted below threshold")
	assert_true(signal_log["stamina_recovered"] == 0, "Threshold: stamina_recovered NOT emitted at 15.0")

	# Step 8.2: Regenerate 0.9s (+13.5 stamina -> 28.5 stamina)
	fixture.regenerate(0.9)
	assert_float_eq(fixture.current_stamina, 28.5, "Threshold: current_stamina is 28.5 after +0.9s")
	assert_true(fixture.is_exhausted, "Threshold: STILL exhausted at 28.5 stamina (below 30.0 threshold)")
	assert_true(signal_log["stamina_recovered"] == 0, "Threshold: stamina_recovered NOT emitted at 28.5")

	# Step 8.3: Regenerate 0.15s (+2.25 stamina -> 30.75 stamina >= 30.0 threshold)
	fixture.regenerate(0.15)
	assert_float_eq(fixture.current_stamina, 30.75, "Threshold: current_stamina reached 30.75 (>= 30.0 threshold)")
	assert_true(not fixture.is_exhausted, "Threshold: is_exhausted CLEARED upon reaching recovery threshold")
	assert_true(signal_log["stamina_recovered"] == 1, "Threshold: stamina_recovered emitted exactly once")
	assert_true(signal_log["exhaustion_state_changed"].size() == 1 and signal_log["exhaustion_state_changed"][0] == false, "Threshold: exhaustion_state_changed(false) emitted")
	assert_true(fixture.can_dash(), "Threshold: can_dash() restored upon exhaustion recovery")

	# --------------------------------------------------------------------------
	# TEST 9: Delta Regeneration Rates & Max Clamping
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 9: Delta Regeneration Rates & Max Clamping ---")
	var baseline_stamina: float = fixture.current_stamina
	fixture.regenerate(-1.0)
	assert_float_eq(fixture.current_stamina, baseline_stamina, "Regen Bounds: negative delta ignored")
	fixture.regenerate(0.0)
	assert_float_eq(fixture.current_stamina, baseline_stamina, "Regen Bounds: zero delta ignored")

	# 1.0s regeneration adds exactly 15.0 stamina
	fixture.regenerate(1.0)
	assert_float_eq(fixture.current_stamina, baseline_stamina + 15.0, "Regen Rate: 1.0s delta adds exactly regen_rate (15.0)")

	# Exceed max stamina with large delta
	fixture.regenerate(10.0)
	assert_float_eq(fixture.current_stamina, 100.0, "Regen Clamping: stamina clamped at max_stamina (100.0)")

	# --------------------------------------------------------------------------
	# TEST 10: Dash Directly Triggering Exhaustion
	# --------------------------------------------------------------------------
	print("\n--- TEST GROUP 10: Dash Directly Triggering Exhaustion ---")
	fixture.init(25.0)
	_reset_signals()
	assert_true(fixture.can_dash(), "Dash to Exhaustion: can_dash() is true with exactly 25.0 stamina")
	var terminal_dash: bool = fixture.consume_dash()
	assert_true(terminal_dash, "Dash to Exhaustion: consume_dash() succeeded with 25.0 stamina")
	assert_float_eq(fixture.current_stamina, 0.0, "Dash to Exhaustion: current_stamina is exactly 0.0")
	assert_true(fixture.is_exhausted, "Dash to Exhaustion: is_exhausted transitioned to true")
	assert_true(signal_log["stamina_depleted"] == 1, "Dash to Exhaustion: stamina_depleted emitted")
	assert_true(signal_log["exhaustion_state_changed"].size() == 1 and signal_log["exhaustion_state_changed"][0] == true, "Dash to Exhaustion: exhaustion_state_changed(true) emitted")

	# Follow-up dash must be rejected
	var follow_up: bool = fixture.consume_dash()
	assert_true(not follow_up, "Dash to Exhaustion: immediate follow-up dash rejected")
	assert_float_eq(fixture.current_stamina, 0.0, "Dash to Exhaustion: stamina remains 0.0 without underflow")

	# Cleanup
	fixture.free()

	print("\n================================================================================")
	print("TEST EXECUTION COMPLETE")
	print("Total Checks: %d | Passed: %d | Failed: %d" % [total_tests, passed_tests, failed_tests])
	print("================================================================================")

	if failed_tests == 0:
		print("RESULT: QA PASS - All test cases satisfied. ISS-LIVE-003 fully resolved.")
		quit(0)
	else:
		push_error("RESULT: QA FAIL - %d test failures detected." % failed_tests)
		quit(1)
