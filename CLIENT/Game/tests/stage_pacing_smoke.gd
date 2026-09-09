extends SceneTree

const Probe = preload("res://scripts/stage/stage_pacing_probe.gd")
var failures: int = 0

class Actor extends Node:
	var attack_count: int = 0
	var hit_count: int = 0

class Stage extends Node:
	var player = Actor.new()
	var completed = [false, false, false, false]
	var checkpoint_active: bool = false
	var encounter_index: int = 0
	var encounter_active: bool = false
	var stage_state: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	for result in [1, 2]:
		var stage := Stage.new()
		root.add_child(stage)
		stage.add_child(stage.player)
		stage.checkpoint_active = result == 2
		var probe := Probe.new()
		stage.add_child(probe)
		probe.attach(stage)
		probe.set_process(false)
		probe._sample(1.0, false)
		stage.encounter_active = true
		probe._sample(0.0, false)
		probe._sample(2.0, false)
		probe._sample(100.0, true)
		stage.player.attack_count = 4
		stage.player.hit_count = 1
		stage.completed[0] = true
		stage.encounter_active = false
		probe._sample(0.0, false)
		stage.stage_state = result
		probe._sample(1.0, false)
		probe._sample(99.0, false)
		var data := probe.get_snapshot()
		check(is_equal_approx(data.run_time, 4.0), "Wall seconds, pauses and terminal freeze")
		check(is_equal_approx(data.active_combat_time, 2.0), "Only active encounter seconds")
		check(data.attack_count == 4 and data.hit_count == 1, "Player counters")
		check(data.checkpoint_start == (result == 2), "Checkpoint start identity")
		check(data.events.size() == 4, "Start, entry, completion, exactly one terminal")
		check(data.result == ("cleared" if result == 1 else "failed"), "Terminal outcome")
		data.events.clear()
		check(probe.get_snapshot().events.size() == 4, "Detached snapshot")
		check(stage.encounter_index == 0 and stage.player.hit_count == 1, "Observer preserves stage")
		stage.free()
	var live = load("res://scenes/stage/FirstStage.tscn").instantiate()
	root.add_child(live)
	live.set_physics_process(false)
	live.player.set_physics_process(false)
	live.encounter_index = 1
	live._start_encounter()
	check(is_equal_approx(live.enemies[0].detection_range, 360.0), "E2 bounded mobile approach detection")
	check(live.enemies[0].attack_windup >= 0.75, "E2 readable mobile windup")
	live.encounter_index = 2
	live._start_encounter()
	check(is_equal_approx(live.enemies[1].detection_range, 360.0), "E3 bounded mobile detection")
	check(live.enemies[1].attack_windup >= 0.75, "E3 readable mobile windup")
	live.free()
	print("PACING SMOKE: failures=%d; synthetic timing, not human play evidence" % failures)
	quit(1 if failures else 0)
