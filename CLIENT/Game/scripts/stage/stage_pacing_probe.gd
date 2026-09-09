extends Node
## Read-only, local Output telemetry. Attach after checkpoint restoration.
## Wall-clock seconds, excluding pause; never infer human play duration from smoke tests.

var _stage: Node
var _last_usec: int
var _was_paused: bool = false
var _finished: bool = false
var _active_index: int = -1
var _completed: Array = []
var _data: Dictionary = {}


func attach(stage: Node) -> void:
	_stage = stage
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()
	_was_paused = get_tree().paused
	_completed = stage.completed.duplicate()
	_data = {"schema": "stage_pacing_v1", "run_time": 0.0,
		"active_combat_time": 0.0, "checkpoint_start": stage.checkpoint_active,
		"attack_count": 0, "hit_count": 0, "result": "playing", "events": []}
	_emit("run_started")
	_sample(0.0, false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_stage) or _finished:
		return
	var now := Time.get_ticks_usec()
	var paused := get_tree().paused
	# Use elapsed real time: fixed physics delta undercounts capped/slow frames.
	# Exclude the boundary sample too, so a resumed frame cannot include a pause.
	_sample(float(now - _last_usec) / 1000000.0, paused or _was_paused)
	_last_usec = now
	_was_paused = paused


func _sample(elapsed: float, paused: bool) -> void:
	if _finished or not is_instance_valid(_stage) or paused:
		return
	_data.run_time += maxf(elapsed, 0.0)
	if _active_index >= 0:
		_data.active_combat_time += maxf(elapsed, 0.0)
	_data.attack_count = _stage.player.attack_count
	_data.hit_count = _stage.player.hit_count
	for index in range(_completed.size()):
		if _stage.completed[index] and not _completed[index]:
			_emit("encounter_completed", index)
	_completed = _stage.completed.duplicate()
	var active: int = _stage.encounter_index if _stage.encounter_active else -1
	if active >= 0 and active != _active_index:
		_emit("encounter_entered", active)
	_active_index = active
	if _stage.stage_state != 0:
		_finished = true
		_data.result = "cleared" if _stage.stage_state == 1 else "failed"
		_emit("run_finished")


func _emit(event: String, index: int = -1) -> void:
	var record := {"event": event, "run_time": _data.run_time,
		"active_combat_time": _data.active_combat_time,
		"encounter": index + 1, "attack_count": _data.attack_count,
		"hit_count": _data.hit_count, "checkpoint_start": _data.checkpoint_start,
		"result": _data.result, "schema": _data.schema,
		"time_basis": "unpaused_wall_seconds_frame_sampled"}
	_data.events.append(record)
	print("STAGE_PACING " + JSON.stringify(record))


func get_snapshot() -> Dictionary:
	return _data.duplicate(true)
