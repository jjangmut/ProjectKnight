extends SceneTree
## Automated test suite for Stage 1 Boss (BossCommander) visual polish, size scaling, and skill sword beam VFX.

var total_checks: int = 0
var failed_checks: int = 0

const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")
const BossShockwaveClass = preload("res://scripts/enemy/boss_shockwave.gd")
const PlayerScene = preload("res://scenes/player/Player.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, message: String) -> void:
	total_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failed_checks += 1
		printerr("FAIL: %s" % message)


func _run_tests() -> void:
	print("\n--- START STAGE 1 BOSS VISUAL POLISH & SWORD BEAM SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	var boss := BossCommanderClass.new()
	world.add_child(boss)
	await process_frame
	await process_frame

	# [Check 1: Boss Scale and Height]
	print("\n[Check 1: Imposing Boss Stature & Visibility]")
	_check(boss.boss_sprite != null, "Boss sprite instantiated")
	_check(boss.boss_sprite.scale.x >= 0.28, "Boss scale expanded to imposing dimensions (Current: %.3f >= 0.28)" % boss.boss_sprite.scale.x)
	_check(boss.aura_poly != null and boss.aura_poly.visible, "Boss aura polygon visible with champion rim glow")
	_check(boss.attack_range >= 100.0, "Boss attack range calibrated to larger weapon reach (Current: %.1f)" % boss.attack_range)

	# [Check 2: Scaled Physics Collisions and Top Platform]
	print("\n[Check 2: Scaled Physics Collisions & Head Riding Platform]")
	var body_col: CollisionShape2D = null
	for child in boss.get_children():
		if child is CollisionShape2D:
			body_col = child
			break
	_check(body_col != null and body_col.shape is RectangleShape2D, "Main body collision shape exists")
	if body_col != null and body_col.shape is RectangleShape2D:
		var rect := body_col.shape as RectangleShape2D
		_check(rect.size.y >= 100.0, "Body collision height expanded for 106px boss (Height: %.1f)" % rect.size.y)

	var top_plat: AnimatableBody2D = boss.get_node_or_null("TopPlatform") as AnimatableBody2D
	_check(top_plat != null, "TopPlatform node exists for boss head jumping")
	if top_plat != null and top_plat.get_child_count() > 0:
		var top_col := top_plat.get_child(0) as CollisionShape2D
		_check(top_col != null and top_col.position.y <= -65.0, "TopPlatform elevated to boss head level (Y: %.1f <= -65)" % top_col.position.y)

	# [Check 3: Multi-Layered Boss Slash Arc VFX]
	print("\n[Check 3: Multi-Layered Melee Slash Arc VFX]")
	boss._spawn_boss_attack_vfx(BossCommanderClass.Pattern.COMBO_CLEAVE, 1.0)
	var slash_vfx: Node2D = null
	for child in world.get_children():
		if child != boss and child is Node2D and child.get_child_count() >= 3:
			slash_vfx = child
			break
	_check(slash_vfx != null, "Multi-layered crescent slash VFX spawned")
	if slash_vfx != null:
		var line_count := 0
		var poly_count := 0
		for c in slash_vfx.get_children():
			if c is Line2D:
				line_count += 1
			elif c is Polygon2D:
				poly_count += 1
		_check(line_count >= 2, "Slash VFX contains outer glow line and razor core line (Found: %d)" % line_count)
		_check(poly_count >= 1, "Slash VFX contains sweeping energy crescent polygon (Found: %d)" % poly_count)

	# [Check 4: Flying Sword Beam (BossShockwave) Emission on Skill]
	print("\n[Check 4: Flying Sword Beam Emission on Skill]")
	boss._emit_sword_beam(1.0)
	var sword_beams: Array[BossShockwave] = []
	for child in world.get_children():
		if child is BossShockwaveClass:
			sword_beams.append(child)
	_check(sword_beams.size() >= 1, "Boss unleashed flying sword wave upon COMBO_CLEAVE skill")
	if not sword_beams.is_empty():
		var beam := sword_beams[0]
		_check(beam.direction == 1.0, "Sword beam travels in facing direction")
		_check(beam.speed >= 400.0, "Sword beam has brisk, impactful flight velocity (%.1f px/s)" % beam.speed)
		_check(beam.get_node_or_null("VisualRoot") != null, "Sword beam contains multi-layer VisualRoot")
		var v_root := beam.get_node_or_null("VisualRoot")
		if v_root != null:
			_check(v_root.get_child_count() >= 3, "VisualRoot contains outer arc, core razor line, and filled blade body (Count: %d)" % v_root.get_child_count())

	# [Check 5: Leap Slam Dual Ground Shockwave Wave]
	print("\n[Check 5: Leap Slam Dual Ground Shockwaves]")
	var initial_count := sword_beams.size()
	boss._emit_shockwaves()
	var new_beams := 0
	for child in world.get_children():
		if child is BossShockwaveClass:
			new_beams += 1
	_check(new_beams == initial_count + 2, "Leap Slam emitted exactly 2 ground shockwaves (left & right)")

	# Clean up
	world.queue_free()
	await process_frame

	print("\n--- TEST SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [total_checks - failed_checks, failed_checks])
	if failed_checks == 0:
		print("TEST RESULT: ALL STAGE 1 BOSS VISUAL POLISH CHECKS PASSED (100%)\n")
		quit(0)
	else:
		printerr("TEST RESULT: TEST FAILED WITH %d FAILURES\n" % failed_checks)
		quit(1)
