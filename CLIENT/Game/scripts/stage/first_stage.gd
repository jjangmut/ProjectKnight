extends Node2D
## First playable stage skeleton. Combat actors retain their existing interfaces.

const MELEE = preload("res://scenes/enemy/TestEnemy.tscn")
const RANGED = preload("res://scenes/enemy/RangedEnemy.tscn")
const EXIT_X: Array[float] = [1450.0, 2750.0, 4300.0, 5900.0]
const ENTRY_X: Array[float] = [400.0, 1700.0, 3250.0, 4850.0]
const GOAL_X: float = 6300.0
enum StageState { PLAYING, CLEARED, FAILED }

var stage_state: StageState = StageState.PLAYING
var completed: Array[bool] = [false, false, false, false]
var encounter_index: int = 0
var encounter_active: bool = false
var enemies: Array[CharacterBody2D] = []
var defeated: Array[bool] = []
var gates: Array[StaticBody2D] = []
var _judgment_pending: bool = false
var _reload_started: bool = false
var reload_count: int = 0

@onready var player: CharacterBody2D = $Player
@onready var status_label: Label = $HUD/Status
@onready var restart_timer: Timer = $RestartTimer


func _ready() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_right = 6600
	_solid("Ground", Vector2(3300, 660), Vector2(6600, 80), Color(0.15, 0.19, 0.24))
	_solid("LeftWall", Vector2(0, 300), Vector2(40, 640), Color(0.22, 0.27, 0.34))
	_solid("RightWall", Vector2(6600, 300), Vector2(40, 640), Color(0.22, 0.27, 0.34))
	for index in range(4):
		gates.append(_solid("Gate%d" % index, Vector2(EXIT_X[index], 300), Vector2(24, 640), Color(0.8, 0.45, 0.15)))
		_sign("E%d — 전투 완료 후 통과" % (index + 1), Vector2(ENTRY_X[index], 400))
	_sign("시작 → 이동 A/D · 점프 Space · 공격 J · 회피 K", Vector2(80, 300))
	_sign("S05 — 체크포인트 후속 구현 예정", Vector2(2800, 400))
	_sign("GOAL → 모든 전투 완료 후 도착", Vector2(6050, 400))
	var goal := Polygon2D.new()
	goal.position = Vector2(GOAL_X, 560)
	goal.polygon = PackedVector2Array([Vector2(-30, -60), Vector2(30, -60), Vector2(30, 60), Vector2(-30, 60)])
	goal.color = Color(0.25, 0.9, 0.65)
	add_child(goal)
	restart_timer.timeout.connect(_restart_scene)
	_update_hud()


func _solid(label: String, at: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = label
	body.position = at
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := Polygon2D.new()
	var half := size * 0.5
	visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = color
	body.add_child(visual)
	add_child(body)
	return body


func _sign(message: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = message
	label.position = at
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)


func _physics_process(_delta: float) -> void:
	if stage_state != StageState.PLAYING or _judgment_pending:
		return
	_judgment_pending = true
	_evaluate_stage.call_deferred()


func _evaluate_stage() -> void:
	_judgment_pending = false
	if stage_state != StageState.PLAYING:
		return
	# Evaluate after physics callbacks, before queued deletion. Death wins
	# regardless of enemy death / player death callback order in this tick.
	if player.is_dead or player.current_hp <= 0:
		_finish(StageState.FAILED)
		return
	if encounter_index < 4:
		if not encounter_active and player.position.x >= ENTRY_X[encounter_index]:
			_start_encounter()
		if encounter_active and _all_defeated():
			completed[encounter_index] = true
			gates[encounter_index].queue_free()
			encounter_index += 1
			encounter_active = false
	# An encounter clear never ends the stage; the goal is a separate condition.
	if not completed.has(false) and absf(player.position.x - GOAL_X) <= 50.0 and absf(player.position.y - 580.0) <= 100.0:
		_finish(StageState.CLEARED)
		return
	_update_hud()


func _start_encounter() -> void:
	encounter_active = true
	enemies.clear()
	defeated.clear()
	var end := EXIT_X[encounter_index]
	match encounter_index:
		0:
			_spawn(MELEE, end - 500.0)
		1:
			_spawn(RANGED, end - 300.0)
		2:
			_spawn(MELEE, end - 650.0)
			_spawn(RANGED, end - 280.0)
		3:
			_spawn(MELEE, end - 750.0)
			_spawn(MELEE, end - 500.0)
			_spawn(RANGED, end - 250.0)


func _spawn(scene: PackedScene, x: float) -> void:
	var enemy := scene.instantiate() as CharacterBody2D
	enemy.position = Vector2(x, 580)
	# Siblings preserve combat actors' existing local-position assumptions.
	add_child(enemy)
	var slot := enemies.size()
	enemies.append(enemy)
	defeated.append(false)
	enemy.tree_exiting.connect(_enemy_exiting.bind(enemy, slot, encounter_index))


func _enemy_exiting(enemy: CharacterBody2D, slot: int, index: int) -> void:
	if index == encounter_index and enemy.current_hp <= 0:
		defeated[slot] = true


func _all_defeated() -> bool:
	if enemies.is_empty():
		return false
	for slot in range(enemies.size()):
		var enemy = enemies[slot]
		if not defeated[slot] and not (is_instance_valid(enemy) and enemy.current_hp <= 0 and enemy.is_queued_for_deletion()):
			return false
	return true


func _update_hud() -> void:
	var objective := "E%d 전투 구간으로 이동 →" % (encounter_index + 1)
	if encounter_active:
		objective = "E%d 적을 모두 제거하세요" % (encounter_index + 1)
	elif encounter_index == 4:
		objective = "모든 전투 완료 · 오른쪽 GOAL로 이동 →"
	status_label.text = "HP %d/3 · 전투 %d/4 완료\n%s" % [player.current_hp, encounter_index, objective]


func _finish(result: StageState) -> void:
	if stage_state != StageState.PLAYING:
		return
	stage_state = result
	status_label.text = "스테이지 성공 · CLEARED" if result == StageState.CLEARED else "실패 · FAILED"
	status_label.text += "\n1.5초 후 시작점에서 재시작"
	# Freeze combat during the terminal display. The timer stays active.
	for child in get_children():
		if child is CharacterBody2D or child is Area2D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)
	restart_timer.start()


func _restart_scene() -> void:
	if stage_state == StageState.PLAYING or _reload_started:
		return
	_reload_started = true
	reload_count += 1
	# Explicit scene path also supports launch via F6 or command-line scene.
	var error := get_tree().change_scene_to_file("res://scenes/stage/FirstStage.tscn")
	if error != OK:
		push_error("Stage restart failed: %s" % error_string(error))
