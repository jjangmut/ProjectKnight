extends SceneTree
var checks := 0
var failures := 0
var stage: Node
var ui: Control

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("STAGE_UI_EVIDENCE")
	if not output.is_empty():
		check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Saved " + label)

func touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point * ui.ui_scale + ui.ui_offset
	event.pressed = down
	root.push_input(event, true)

func _run() -> void:
	stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	await settle()
	ui = stage.get_node("HUD/Presentation")
	stage.player.position.y = 592
	check(ui.initialized, "HUD initialized")
	check(not stage.status_label.visible, "Legacy HUD hidden but preserved")
	check(ui.objective().contains("1구간"), "Opening objective")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/stage/Campaign.tscn", "Default launch is campaign")
	await capture("01_start")
	ui.intro_remaining = 0
	stage.player.position = Vector2(720, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	stage._start_encounter()
	for enemy in stage.enemies:
		enemy.set_physics_process(false)
		enemy.position.y = 590
	await settle()
	check(ui.objective().contains("남은 적 1명"), "Live enemy count")
	await capture("02_combat")
	stage.player.receive_hit()
	await settle()
	check(ui.previous_hp == 2 and ui.hit_remaining > 0, "HP change and damage edge flash")
	await capture("03_hit")
	ui.touch_visible = true
	touch(1, ui.BUTTONS[1], true)
	touch(2, ui.BUTTONS[2], true)
	await settle()
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("attack"), "Two-finger move plus attack")
	touch(2, ui.BUTTONS[2], false)
	await settle()
	check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("attack"), "Independent finger release")
	touch(3, ui.BUTTONS[1], true)
	touch(1, ui.BUTTONS[1], false)
	await settle()
	check(Input.is_action_pressed("move_right"), "Two fingers share one action safely")
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(600, 400) * ui.ui_scale + ui.ui_offset
	root.push_input(drag, true)
	await settle()
	check(not Input.is_action_pressed("move_right"), "Drag outside releases action")
	touch(3, Vector2(600, 400), false)
	touch(4, ui.BUTTONS[3], true)
	touch(5, ui.BUTTONS[4], true)
	await settle()
	check(Input.is_action_pressed("jump") and Input.is_action_pressed("guard"), "Simultaneous action inputs exposed; gameplay chooses priority")
	await capture("04_touch")
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("guard"), "Focus loss clears virtual inputs")
	touch(6, ui.BUTTONS[0], true)
	var cancel := InputEventScreenTouch.new()
	cancel.index = 6
	cancel.position = ui.BUTTONS[0] * ui.ui_scale + ui.ui_offset
	cancel.pressed = false
	cancel.canceled = true
	root.push_input(cancel, true)
	await settle()
	check(not Input.is_action_pressed("move_left"), "Cancelled finger released")
	ui._toggle_pause(true)
	await settle()
	check(paused and ui.pause_owned, "Pause and help")
	await capture("05_pause")
	ui._ui_button(Vector2(640, 360))
	check(not paused, "Pause resumes")
	stage.player._update_hurt_flash(1)
	stage.player.current_hp = 3
	stage._resume_checkpoint()
	await settle()
	check(ui.previous_checkpoint == 0 and ui.objective().contains("3구간"), "First checkpoint restore objective")
	check(stage.completed[0] and stage.completed[1] and not stage.completed[2], "Checkpoint progress retained")
	await capture("06_checkpoint")
	stage.player.current_hp = 0
	stage.player._die()
	stage._evaluate_stage()
	stage.restart_timer.paused = true
	await settle()
	check(ui.objective().contains("휴식처 1"), "Failure restart target names checkpoint index")
	check(ui.touch_actions.is_empty(), "Terminal releases virtual inputs")
	check(is_equal_approx(stage.restart_timer.wait_time, 1.5), "Existing 1.5 second restart retained")
	await capture("07_failed")
	stage.free()
	await settle()
	stage = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	await settle()
	ui = stage.get_node("HUD/Presentation")
	ui.intro_remaining = 0
	stage.completed.fill(true)
	stage.encounter_index = stage.completed.size()
	for gate in stage.gates:
		if is_instance_valid(gate):
			gate.queue_free()
	stage.player.position = Vector2(6180, 592)
	stage.player.get_node("Camera2D").force_update_scroll()
	await settle()
	check(ui.objective().contains("황금"), "Goal objective after four encounters")
	check(stage.stage_state == 0, "All encounters alone do not clear stage")
	await capture("08_goal_ready")
	stage.player.position = Vector2(stage.GOAL_X, 580)
	stage._evaluate_stage()
	stage.restart_timer.paused = true
	await settle()
	check(stage.stage_state == 1, "Alive plus goal plus all encounters clears")
	await capture("09_cleared")
	stage.free()
	await settle()
	check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("attack"), "Scene exit leaves no virtual action")
	stage = load("res://scenes/stage/SecondStage.tscn").instantiate()
	stage.campaign_mode = true
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	stage.player.set_physics_process(false)
	await settle()
	ui = stage.get_node("HUD/Presentation")
	check(ui.stage_label() == "스테이지 02 · 야수숲", "Stage2 number and region reach HUD and result label")
	check(ui.encounter_hint().contains("막기 불가") and ui.encounter_hint().contains("점프"), "Stage2 unblockable attack and avoidance hint")
	stage.encounter_index = 1
	check(ui.encounter_hint().contains("반격") and ui.encounter_hint().contains("막기"), "Stage2 recovery and unblockable charge guidance")
	stage.player.set_meta("equipped_trait", "basic")
	check(ui.trait_label() == "특성 · 기본 검술", "Basic trait visible")
	stage.player.set_meta("equipped_trait", "reach")
	check(ui.trait_label().contains("긴 칼날") and ui.trait_label().contains("공격 간격 증가"), "Reach tradeoff visible")
	await capture("10_stage2_trait")
	stage.stage_state = 1
	check(stage.restart_timer.time_left == 0 and ui.transition_message() == "다음 여정을 준비합니다", "Campaign success avoids inactive timer countdown")
	await capture("11_campaign_clear")
	stage.stage_state = 2
	stage.checkpoint_active = false
	check(ui.transition_message() == "잠시 후 시작점으로 복귀합니다", "Campaign failure names starting point without false countdown")
	stage.checkpoint_active = true
	stage.checkpoint_index = 0
	check(ui.transition_message() == "잠시 후 휴식처 1로 복귀합니다", "Campaign checkpoint return text")
	stage.free()
	await settle()
	print("STAGE_PRESENTATION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
