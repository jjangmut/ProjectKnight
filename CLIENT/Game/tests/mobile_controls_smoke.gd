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
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(600, 40)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = 120
	world.add_child(floor_body)
	var p = load("res://scenes/player/Player.tscn").instantiate()
	world.add_child(p)
	await frames(35)
	check(p.is_on_floor(), "Real grounded fixture")
	Input.action_press("attack")
	await frames(65)
	check(p.attack_count >= 3 and p.attack_count <= 4, "Held attack repeats at normal cooldown")
	Input.action_release("attack")
	await frames(25)
	var count: int = p.attack_count
	await frames(25)
	check(p.attack_count == count, "Released attack stops repeat")
	Input.action_press("guard")
	await frames(100)
	check(p.is_guarding and p.guard_count == 1, "Guard held beyond old limit remains active")
	var guard_x: float = p.position.x
	Input.action_press("move_left")
	await frames(5)
	check(p.position.x == guard_x and p.facing_direction == 1, "Guard stationary and direction locked")
	Input.action_release("move_left")
	check(p.receive_attack(p.global_position + Vector2(50,0)) and p.current_hp == 3, "Ordinary front attack blocked")
	Input.action_release("guard")
	await frames(3)
	check(not p.is_guarding, "Release ends guard")
	Input.action_press("guard")
	await frames(15)
	check(p.is_guarding and p.guard_count == 2, "Held reinput activates after short cooldown")
	Input.action_release("guard")
	await frames(20)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	Input.action_press("guard")
	await frames(2)
	check(p.is_attacking and not p.is_guarding, "Guard cannot cancel active attack")
	await frames(22)
	check(p.is_guarding, "Held guard accepted when attack cooldown ends")
	Input.action_release("guard")
	await frames(20)
	# Walk off an actual ledge, then jump within the coyote window.
	p.position.x = 310
	Input.action_press("move_right")
	while p.is_on_floor():
		await frames(1)
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	check(p.velocity.y < -400, "Coyote jump works after real ledge departure")
	Input.action_release("jump")
	Input.action_release("move_right")
	# Fall onto the floor and press shortly before contact.
	p.position = Vector2(0, 25)
	p.velocity = Vector2(0, 220)
	await frames(3)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(8)
	check(p.velocity.y < 0, "Buffered jump fires on landing")
	check(p.max_hp == 3 and p.current_hp == 3, "Health contract retained")
	var ui = load("res://scripts/ui/stage_presentation.gd").new()
	for i in range(ui.BUTTONS.size()):
		check(ui._touch_action(ui.BUTTONS[i]) == ui.ACTIONS[i], "Touch center maps correctly")
		for j in range(i + 1, ui.BUTTONS.size()):
			check(ui.BUTTONS[i].distance_to(ui.BUTTONS[j]) > 2 * ui.TOUCH_HIT_RADIUS, "Touch targets do not overlap")
	ui.set_finger(0, ui.BUTTONS[0], true)
	ui.set_finger(1, ui.BUTTONS[2], true)
	check(Input.is_action_pressed("move_left") and Input.is_action_pressed("attack"), "Two fingers allow movement with held attack")
	ui.set_finger(1, ui.BUTTONS[3], true)
	check(not Input.is_action_pressed("attack") and Input.is_action_pressed("jump"), "Sliding finger changes action without stuck attack")
	ui.release_touches()
	check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("jump"), "Touch release clears held actions")
	ui.free()
	world.free()
	print("MOBILE_CONTROLS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
