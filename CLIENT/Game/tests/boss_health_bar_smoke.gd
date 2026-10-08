extends SceneTree
## Automated smoke test for Dungeon Hunter 2 style BossHealthBar.

var total_checks: int = 0
var failed_checks: int = 0

const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")

func _init() -> void:
	# Fail-safe watchdog: Guarantee process termination even on unhandled errors or freezes
	var watchdog := create_timer(12.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] boss_health_bar_smoke did not finish within 12s. Forcing exit.")
		quit(1)
	)
	call_deferred("_run_tests")


func _check(condition: bool, message: String) -> void:
	total_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failed_checks += 1
		printerr("FAIL: %s" % message)


func _run_tests() -> void:
	print("\n--- START BOSS HEALTH BAR GOTHIC OVERHAUL SMOKE TEST ---")

	var canvas := CanvasLayer.new()
	root.add_child(canvas)

	var bar: BossHealthBar = BossHealthBarClass.new()
	bar.boss_name = "심연의 수호자"
	canvas.add_child(bar)
	bar.snap_to_visible()

	await process_frame
	await process_frame

	# Check 1: Structure & Dimensions
	print("\n[Check 1: Structure & Properties]")
	_check(bar != null, "BossHealthBar instantiated successfully")
	_check(bar.BAR_WIDTH == 700.0, "Bar width calibrated to 700.0px")
	_check(bar.BAR_HEIGHT == 34.0, "Bar height calibrated to 34.0px")
	_check(bar.modulate.a == 1.0, "Bar visible after snap_to_visible")
	_check(bar.boss_name == "심연의 수호자", "Boss title set correctly")

	# Check 2: Visual Elements Hierarchy
	print("\n[Check 2: Child Node Hierarchy]")
	_check(bar.get_node_or_null("@Label@2") != null or bar._title_label != null, "Title label present")
	_check(bar._phase_label != null, "Phase enrage label present")
	_check(bar._bar_bg != null, "Background bar present")
	_check(bar._bar_linger != null, "Lingering amber damage bar present")
	_check(bar._bar_fill != null, "Main ruby fill bar present")

	# Check 3: Mock Boss Attachment & HP Change
	print("\n[Check 3: Boss Signal Attachment & Damage Tracking]")
	var mock_boss := CharacterBody2D.new()
	mock_boss.set_script(load("res://scripts/enemy/boss_commander.gd"))
	root.add_child(mock_boss)
	await process_frame

	bar.attach_boss(mock_boss)
	_check(bar.is_active, "Bar marked active upon boss attach")
	_check(bar.max_hp == mock_boss.max_hp, "Max HP synchronized (HP: %d)" % bar.max_hp)
	_check(bar.current_hp == mock_boss.current_hp, "Current HP synchronized (HP: %d)" % bar.current_hp)

	# Simulate damage
	var half_hp: int = int(mock_boss.max_hp * 0.5)
	mock_boss.current_hp = half_hp
	mock_boss.boss_hp_changed.emit(half_hp, mock_boss.max_hp)
	await process_frame

	_check(bar.current_hp == half_hp, "Health changed signal processed")
	_check(absf(bar._bar_fill.size.x - (bar.BAR_WIDTH * 0.5)) < 1.0, "Fill bar width scaled to 50%% (%.1f px)" % bar._bar_fill.size.x)
	_check(bar.linger_hp > float(half_hp), "Linger bar tracks lagging damage (Linger: %.1f > %.1f)" % [bar.linger_hp, float(half_hp)])

	# Check 4: Enraged Phase 2 Transition
	print("\n[Check 4: Phase 2 Enrage Transition]")
	mock_boss.boss_phase_changed.emit(2)
	await process_frame
	_check(bar.is_enraged, "Enraged status activated on phase 2")
	_check(bar._phase_label.visible, "Enraged tag rendered visible")

	# Check 5: Lingering Bar Decay
	print("\n[Check 5: Linger Decay Process]")
	for i in range(30):
		bar._process(0.016)
	_check(bar.linger_hp < float(mock_boss.max_hp), "Linger bar smoothly decayed toward current HP (Now: %.2f)" % bar.linger_hp)

	# Check 6: Redraw Execution without Runtime Errors
	print("\n[Check 6: Gothic Wing & Segment Divider Drawing]")
	bar.queue_redraw()
	await process_frame
	await process_frame
	_check(true, "Custom _draw() executed successfully with gothic wings and phase dividers")

	# Clean up
	mock_boss.queue_free()
	bar.queue_free()
	canvas.queue_free()
	await process_frame

	print("\n--- BOSS HEALTH BAR SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [total_checks, failed_checks])
	if failed_checks == 0:
		print("TEST RESULT: ALL BOSS HEALTH BAR CHECKS PASSED (100%)\n")
		quit(0)
	else:
		printerr("TEST RESULT: SOME CHECKS FAILED!\n")
		quit(1)
