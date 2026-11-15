extends Node
class_name CombatTimelineController
## ProjectKnight V3-026: Combat Timeline Controller
## Manages frame-exact, deterministic physics stepping for combat actions.
## Guarantees: Input -> Windup (Hitbox OFF) -> Active (Hitbox ON) -> Contact -> Recovery.

enum Phase {
	IDLE,
	WINDUP,
	ACTIVE,
	RECOVERY
}

signal phase_changed(old_phase: Phase, new_phase: Phase)
signal hitbox_opened(action_id: String)
signal contact_frame_reached(action_id: String)
signal hitbox_closed(action_id: String)
signal action_finished(action_id: String)

var current_action: CombatActionDefinition = null
var current_phase: Phase = Phase.IDLE
var elapsed_time: float = 0.0
var contact_resolved: bool = false
var facing_dir_x: float = 1.0
var attack_dir: Vector3 = Vector3(1.0, 0.0, 0.0)


func is_busy() -> bool:
	return current_phase != Phase.IDLE


func is_in_windup() -> bool:
	return current_phase == Phase.WINDUP


func is_in_active() -> bool:
	return current_phase == Phase.ACTIVE


func is_in_recovery() -> bool:
	return current_phase == Phase.RECOVERY


func can_cancel() -> bool:
	if current_action == null or current_phase == Phase.IDLE:
		return true
	return current_action.is_cancelable(elapsed_time)


func can_buffer_combo() -> bool:
	if current_action == null or current_phase == Phase.IDLE:
		return true
	return elapsed_time >= current_action.combo_buffer_start


func start_action(action: CombatActionDefinition, p_facing_x: float, p_attack_dir: Vector3 = Vector3.ZERO) -> void:
	if action == null:
		return

	current_action = action
	elapsed_time = 0.0
	contact_resolved = false
	facing_dir_x = p_facing_x
	attack_dir = p_attack_dir if p_attack_dir.length_squared() > 0.01 else Vector3(facing_dir_x, 0.0, 0.0)

	var old_p := current_phase
	current_phase = Phase.WINDUP
	phase_changed.emit(old_p, current_phase)


func step(delta: float) -> int:
	if current_action == null or current_phase == Phase.IDLE:
		return -1

	elapsed_time += delta

	# 1. Check Windup -> Active Transition
	if current_phase == Phase.WINDUP and elapsed_time >= current_action.get_active_start_time():
		current_phase = Phase.ACTIVE
		phase_changed.emit(Phase.WINDUP, Phase.ACTIVE)
		hitbox_opened.emit(current_action.action_id)

	# 2. Check Active Contact Marker
	if current_phase == Phase.ACTIVE:
		if not contact_resolved and elapsed_time >= current_action.contact_time:
			contact_resolved = true
			contact_frame_reached.emit(current_action.action_id)

		# Check Active -> Recovery Transition
		if elapsed_time >= current_action.get_active_end_time():
			current_phase = Phase.RECOVERY
			phase_changed.emit(Phase.ACTIVE, Phase.RECOVERY)
			hitbox_closed.emit(current_action.action_id)

	# 3. Check Recovery -> Finished
	if current_phase == Phase.RECOVERY:
		if elapsed_time >= current_action.total_duration:
			var act_id: String = current_action.action_id
			current_phase = Phase.IDLE
			current_action = null
			action_finished.emit(act_id)
			return -1

	if current_action != null:
		return current_action.get_frame_for_time(elapsed_time)
	return -1


func cancel() -> void:
	if current_action != null:
		var act_id: String = current_action.action_id
		current_action = null
		current_phase = Phase.IDLE
		action_finished.emit(act_id)
