extends Node2D

enum SessionState { PLAYING, CLEARED, FAILED }

var session_state: SessionState = SessionState.PLAYING
var _judgment_pending: bool = false
var _reload_started: bool = false
var _test_enemy_removed: bool = false
var _ranged_enemy_removed: bool = false

@onready var _player: CharacterBody2D = $Player
@onready var _test_enemy: CharacterBody2D = $TestEnemy
@onready var _ranged_enemy: CharacterBody2D = $RangedEnemy
@onready var _status_label: Label = $SessionStatus
@onready var _restart_timer: Timer = $RestartTimer


func _ready() -> void:
	_test_enemy.tree_exiting.connect(_on_enemy_exiting.bind(_test_enemy, true))
	_ranged_enemy.tree_exiting.connect(_on_enemy_exiting.bind(_ranged_enemy, false))
	_restart_timer.timeout.connect(_restart_scene)
	_status_label.text = "PLAYING"


func _physics_process(_delta: float) -> void:
	if session_state != SessionState.PLAYING or _judgment_pending:
		return
	_judgment_pending = true
	# Existing damage callbacks are synchronous. Deferred evaluation runs after
	# collision signals and all node physics callbacks, before the next tick.
	# Observe queued deletion too: queue_free is flushed after deferred calls.
	_evaluate_session.call_deferred()


func _on_enemy_exiting(enemy: CharacterBody2D, is_test_enemy: bool) -> void:
	# Only combat deaths count; losing a reference alone is not a clear.
	if enemy.current_hp > 0:
		return
	if is_test_enemy:
		_test_enemy_removed = true
	else:
		_ranged_enemy_removed = true


func _is_defeated(enemy: CharacterBody2D, removed: bool) -> bool:
	return removed or (is_instance_valid(enemy) and enemy.current_hp <= 0 and enemy.is_queued_for_deletion())


func _evaluate_session() -> void:
	_judgment_pending = false
	if session_state != SessionState.PLAYING or not is_instance_valid(_player):
		return
	if _player.is_dead:
		_finish_session(SessionState.FAILED)
	elif _player.current_hp > 0 and _is_defeated(_test_enemy, _test_enemy_removed) and _is_defeated(_ranged_enemy, _ranged_enemy_removed):
		_finish_session(SessionState.CLEARED)


func _finish_session(result: SessionState) -> void:
	if session_state != SessionState.PLAYING or result == SessionState.PLAYING:
		return
	session_state = result
	_status_label.text = "CLEARED" if result == SessionState.CLEARED else "FAILED"
	set_physics_process(false)
	_restart_timer.start()


func _restart_scene() -> void:
	if session_state == SessionState.PLAYING or _reload_started:
		return
	_reload_started = true
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Combat scene reload failed: %s" % error_string(error))
