extends SceneTree
## Independent scripted-input QA; this does not claim human play or physical-device testing.
var checks := 0
var failures := 0
var stage: Node
var p: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fixture(scene: String = "FirstStage") -> void:
	for action in ["guard", "jump", "attack", "move_left", "move_right"]:
		Input.action_release(action)
	if is_instance_valid(stage):
		stage.free()
	stage = load("res://scenes/stage/" + scene + ".tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	p = stage.player
	p.position = Vector2(200, 580)
	await ticks(15)
	check(p.is_on_floor() and p.current_hp == 3, scene + " grounded HP3 fixture")

func _run() -> void:
	await fixture()
	key(KEY_K, true)
	await ticks(2)
	check(p.is_guarding and p.guard_count == 1, "Physical K key mapping starts guard")
	var start_x: float = p.position.x
	key(KEY_A, true)
	key(KEY_SPACE, true)
	key(KEY_J, true)
	await ticks(5)
	check(p.is_guarding and p.facing_direction == 1 and p.position.x == start_x and p.is_on_floor() and p.attack_count == 0, "Guard locks movement/facing/jump/attack")
	for code in [KEY_A, KEY_SPACE, KEY_J]:
		key(code, false)
	check(p.receive_attack(p.global_position + Vector2(50, 0), true) and p.current_hp == 3, "Front normal attack blocks")
	check(p.receive_attack(p.global_position + Vector2(50, 0), true) and p.guard_block_count == 2 and p.current_hp == 3, "Independent same-frame frontal attacks both block without HP loss")
	check(not p.receive_attack(p.global_position - Vector2(50, 0), true) and p.current_hp == 2 and not p.is_guarding, "Rear attack damages and breaks guard")
	key(KEY_K, false)
	await fixture()
	key(KEY_K, true)
	await ticks(2)
	check(not p.receive_attack(p.global_position + Vector2(50, 0), false) and p.current_hp == 2, "Heavy attack bypasses front guard")
	key(KEY_K, false)
	await fixture()
	key(KEY_K, true)
	await ticks(2)
	var projectile = load("res://scenes/projectile/EnemyProjectile.tscn").instantiate()
	projectile.position = p.position + Vector2(50, 0)
	stage.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.configure(-1)
	projectile._on_area_entered(p.get_node("HurtArea"))
	projectile._on_area_entered(p.get_node("HurtArea"))
	check(projectile.is_queued_for_deletion() and p.current_hp == 3 and p.guard_block_count == 1, "Blocked projectile consumed once even with duplicate delivery")
	key(KEY_K, false)
	await fixture()
	key(KEY_K, true)
	await ticks(44)
	check(p.is_guarding, "Held guard remains active")
	await ticks(10)
	check(p.is_guarding and p.guard_count == 1, "Guard continues beyond 0.8 seconds")
	await ticks(50)
	check(p.is_guarding and p.guard_count == 1, "Continuous hold sustains defense without restarts")
	key(KEY_K, false)
	await ticks(15)
	key(KEY_K, true)
	await ticks(2)
	check(p.is_guarding and p.guard_count == 2, "Release and repress enables next guard")
	key(KEY_K, false)
	await ticks(2)
	key(KEY_J, true)
	await ticks(2)
	check(p.attack_count == 0, "Early recovery rejects attack")
	key(KEY_J, false)
	await ticks(12)
	key(KEY_J, true)
	await ticks(2)
	check(p.attack_count == 1, "Attack available after 0.12 second recovery")
	key(KEY_J, false)
	key(KEY_K, true)
	await ticks(2)
	check(p.is_attacking and not p.is_guarding, "Guard cannot cancel active attack")
	key(KEY_K, false)
	await fixture()
	key(KEY_SPACE, true)
	await ticks(5)
	key(KEY_SPACE, false)
	key(KEY_K, true)
	await ticks(2)
	check(not p.is_on_floor() and not p.is_guarding and p.guard_count == 0, "Airborne guard input is rejected")
	key(KEY_K, false)
	await fixture()
	key(KEY_K, true)
	await ticks(2)
	var guard_time: float = p._guard_elapsed
	paused = true
	await create_timer(0.15, true).timeout
	check(p.is_guarding and p._guard_elapsed == guard_time, "Pause freezes guard elapsed time")
	paused = false
	key(KEY_K, false)
	await ticks(24)
	key(KEY_K, true)
	await ticks(2)
	var presentation = stage.get_node("HUD/Presentation")
	presentation._toggle_pause(true)
	check(paused and not p.is_guarding and not Input.is_action_pressed("guard"), "Help pause explicitly releases held guard")
	presentation._toggle_pause(false)
	key(KEY_K, false)
	await ticks(24)
	key(KEY_K, true)
	await ticks(2)
	presentation._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not p.is_guarding and not Input.is_action_pressed("guard"), "Focus loss releases physical guard safely")
	key(KEY_K, false)
	for enemy_scene in ["TestEnemy", "ChargingBeast", "GroundSlamGolem"]:
		await fixture()
		key(KEY_K, true)
		await ticks(2)
		var attacker = load("res://scenes/enemy/" + enemy_scene + ".tscn").instantiate()
		attacker.position = p.position + Vector2(50, 0)
		stage.add_child(attacker)
		attacker.set_physics_process(false)
		attacker._begin_attack(-50)
		attacker._update_attack(attacker.attack_windup + 0.01)
		attacker._on_attack_area_entered(p.get_node("HurtArea"))
		attacker._on_attack_area_entered(p.get_node("HurtArea"))
		check(p.current_hp == (3 if enemy_scene == "TestEnemy" else 2), enemy_scene + " uses correct blockability through actual enemy callback")
		check(p.guard_block_count == (1 if enemy_scene == "TestEnemy" else 0) and p.hit_count == (0 if enemy_scene == "TestEnemy" else 1), enemy_scene + " repeated callback applies only one outcome")
		key(KEY_K, false)
	for scene in ["FirstStage", "SecondStage", "ThirdStage", "FourthStage", "FifthStage"]:
		await fixture(scene)
		var ui = stage.get_node("HUD/Presentation")
		ui.touch_visible = true
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = ui.BUTTONS[4] * ui.ui_scale + ui.ui_offset
		event.pressed = true
		root.push_input(event, true)
		await ticks(2)
		check(Input.is_action_pressed("guard") and p.is_guarding, scene + " touch guard reaches real player controller")
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
		await ticks(15)
		check(not Input.is_action_pressed("guard") and not p.is_guarding and p._guard_recovery_remaining <= 0, scene + " touch release and recovery")
	for reach in [false, true]:
		await fixture()
		p.attack_range = 90.0 if reach else 72.0
		p.attack_cooldown = 0.40 if reach else 0.32
		p._update_attack_geometry()
		key(KEY_K, true)
		await ticks(2)
		check(p.receive_attack(p.global_position + Vector2(40, 0)), "Trait has identical frontal defense")
		key(KEY_K, false)
		await ticks(16)
		var enemy = load("res://scenes/enemy/TestEnemy.tscn").instantiate()
		enemy.position = p.position + Vector2(65, 0)
		stage.add_child(enemy)
		enemy.set_physics_process(false)
		await ticks(2)
		var enemy_hp: int = enemy.current_hp
		key(KEY_J, true)
		await ticks(4)
		key(KEY_J, false)
		check(p.attack_count == 1 and enemy.current_hp == enemy_hp - 1, "Real block-to-counterattack overlap, trait=" + str(reach))
	stage.free()
	await process_frame
	print("GUARD_INDEPENDENT_QA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
