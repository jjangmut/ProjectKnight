extends Node2D
## First playable stage skeleton. Combat actors retain their existing interfaces.

signal stage_finished(result: int)
@export_range(1, 5) var stage_number: int = 1
@export var campaign_mode: bool = false

const MELEE = preload("res://scenes/enemy/TestEnemy.tscn")
const RANGED = preload("res://scenes/enemy/RangedEnemy.tscn")
var WORLD_WIDTH: float
var EXIT_X: Array[float] = []
var ENTRY_X: Array[float] = []
var GOAL_X: float
var CHECKPOINT_POSITION: Vector2
var CHECKPOINT_POSITIONS: Array[Vector2] = []
var checkpoint_positions: Array[Vector2] = []
var checkpoint_required_counts: Array[int] = []
var required_count: int
var checkpoint_index: int = -1
var checkpoint_prefix: int = 0
var route_clusters: Array[Dictionary] = []
var checkpoint_signs: Array[Label] = []
var checkpoint_visuals: Array[Polygon2D] = []
enum StageState { PLAYING, CLEARED, FAILED }

var stage_state: StageState = StageState.PLAYING
var completed: Array[bool] = []
var encounter_index: int = 0
var encounter_active: bool = false
var enemies: Array[CharacterBody2D] = []
var defeated: Array[bool] = []
var gates: Array[Node2D] = []
var _judgment_pending: bool = false
var _reload_started: bool = false
var reload_count: int = 0
var checkpoint_active: bool = false
var _checkpoint_sign: Label
var _checkpoint_visual: Polygon2D
var encounter_wave: int = 0
var optional_groups: Array[Dictionary] = []
var optional_completed: Array[bool] = []
var route_status: String = "상층 선택 전투 완료 시 HP +1"

@onready var player: CharacterBody2D = $Player
@onready var status_label: Label = $HUD/Status
@onready var restart_timer: Timer = $RestartTimer


const StageLoader = preload("res://scripts/stage/stage_loader.gd")
const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")
const BeastChieftainClass = preload("res://scripts/enemy/beast_chieftain.gd")
const CrossbowCommanderClass = preload("res://scripts/enemy/crossbow_commander.gd")
const AncientGolemGuardianClass = preload("res://scripts/enemy/ancient_golem_guardian.gd")
const AbyssalArbiterClass = preload("res://scripts/enemy/abyssal_arbiter.gd")
const BossHealthBarClass = preload("res://scripts/ui/boss_health_bar.gd")
const SaveManager = preload("res://scripts/system/save_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const MobileControlsClass = preload("res://scripts/ui/mobile_controls.gd")
const GameFeelManagerClass = preload("res://scripts/system/game_feel_manager.gd")
var mobile_controls: CanvasLayer = null
var arena_entrance_gate: Node2D = null
var stage_json_data: Dictionary = {}




func _enter_tree() -> void:
	stage_json_data = StageLoader.get_stage_data(stage_number)
	if not stage_json_data.is_empty():
		WORLD_WIDTH = float(stage_json_data.get("world_width", 11000.0))
		GOAL_X = float(stage_json_data.get("goal_x", WORLD_WIDTH - 300.0))
		var encounters: Array = stage_json_data.get("encounters", [])
		required_count = encounters.size() if not encounters.is_empty() else (6 if stage_number <= 2 else 8)
		ENTRY_X.clear()
		EXIT_X.clear()
		completed.clear()
		for enc in encounters:
			ENTRY_X.append(float(enc.get("entry_x", 400.0)))
			EXIT_X.append(float(enc.get("gate_x", 1640.0)))
			completed.append(false)
		CHECKPOINT_POSITIONS.clear()
		checkpoint_required_counts.clear()
		for cp in stage_json_data.get("checkpoints", []):
			CHECKPOINT_POSITIONS.append(Vector2(float(cp.get("x", 0)), float(cp.get("y", 580))))
			checkpoint_required_counts.append(int(cp.get("required_encounter_prefix", 2)))
		route_clusters.clear()
		optional_completed.clear()
		for opt in stage_json_data.get("optional_routes", []):
			route_clusters.append({
				"left": float(opt.get("left_x", 0)),
				"right": float(opt.get("right_x", 0)),
				"rises": opt.get("rises", [60, 120, 180, 180, 120, 60])
			})
			optional_completed.append(false)
		checkpoint_positions = CHECKPOINT_POSITIONS
		if not CHECKPOINT_POSITIONS.is_empty():
			CHECKPOINT_POSITION = CHECKPOINT_POSITIONS[0]
		return

	# Fallback to algorithmic generation if JSON not loaded
	WORLD_WIDTH = [11000.0, 11600.0, 12000.0, 11200.0, 12600.0][stage_number - 1]
	required_count = 6 if stage_number <= 2 else 8
	GOAL_X = WORLD_WIDTH - 300.0
	var stride: float = (WORLD_WIDTH - 1000.0) / required_count
	for index in range(required_count):
		ENTRY_X.append(roundf(400.0 + stride * index))
		EXIT_X.append(roundf(400.0 + stride * (index + 1) - 420.0))
		completed.append(false)
		if index % 2 == 1:
			if index < required_count - 1:
				CHECKPOINT_POSITIONS.append(Vector2(EXIT_X[index] + 180.0, 580))
				checkpoint_required_counts.append(index + 1)
			var patterns := [
				[60, 120, 180, 180, 120, 60],
				[60, 120, 120, 180, 120, 60],
				[60, 120, 180, 240, 180, 120, 60],
				[60, 120, 180, 180, 180, 120, 60],
				[60, 120, 180, 240, 240, 180, 120, 60],
			]
			var branch: int = index / 2
			var rises: Array = patterns[(stage_number - 1 + branch) % patterns.size()].duplicate()
			if branch % 2 == 1:
				rises.reverse()
			route_clusters.append({"left": ENTRY_X[index] - 180.0, "right": EXIT_X[index] - 160.0, "rises": rises})
			optional_completed.append(false)
	checkpoint_positions = CHECKPOINT_POSITIONS
	CHECKPOINT_POSITION = CHECKPOINT_POSITIONS[0]


func _ready() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = -100
	camera.limit_bottom = 760
	_solid("Ground", Vector2(WORLD_WIDTH / 2.0, 700), Vector2(WORLD_WIDTH + 800.0, 160), Color(0.15, 0.19, 0.24))
	_build_traversal_terrain()
	_solid("LeftWall", Vector2(-40, 320), Vector2(80, 800), Color(0.22, 0.27, 0.34))
	_solid("RightWall", Vector2(WORLD_WIDTH + 40, 320), Vector2(80, 800), Color(0.22, 0.27, 0.34))
	for index in range(required_count):
		# Open Encounter Waypoint (No blocking solid gates: seamless natural traversal)
		var open_marker := Node2D.new()
		open_marker.name = "Gate%d" % index
		open_marker.position = Vector2(EXIT_X[index], 300)
		add_child(open_marker)
		gates.append(open_marker)
		_sign("E%d — 격전 구역" % (index + 1), Vector2(ENTRY_X[index], 400))
	_sign("시작 → 이동 A/D · 점프 Space · 공격 J · 검막기 K", Vector2(80, 300))
	for index in range(CHECKPOINT_POSITIONS.size()):
		var sign_node := _sign("CP%d — 체크포인트 · 최초 도달 시 HP 3" % (index + 1), CHECKPOINT_POSITIONS[index] + Vector2(-170, -180))
		checkpoint_signs.append(sign_node)
		var visual := Polygon2D.new()
		visual.position = CHECKPOINT_POSITIONS[index] + Vector2(0, 20)
		visual.color = Color(0.45, 0.5, 0.6)
		add_child(visual)
		var art := Sprite2D.new()
		art.name = "S05Art"
		art.z_index = -1
		art.texture = load("res://assets/checkpoints/s05_checkpoint_v1.png")
		art.scale = Vector2.ONE * (128.0 / art.texture.get_width())
		art.position = Vector2(0, -24.6061)
		art.modulate = Color(0.5, 0.5, 0.5, 1.0)
		visual.add_child(art)
		checkpoint_visuals.append(visual)
	_checkpoint_sign = checkpoint_signs[0]
	_checkpoint_visual = checkpoint_visuals[0]
	_sign("GOAL → 모든 전투 완료 후 도착", Vector2(GOAL_X - 250.0, 400))
	var goal := Polygon2D.new()
	goal.position = Vector2(GOAL_X, 560)
	goal.polygon = PackedVector2Array([Vector2(-30, -60), Vector2(30, -60), Vector2(30, 60), Vector2(-30, 60)])
	goal.color = Color(0.25, 0.9, 0.65)
	add_child(goal)
	restart_timer.timeout.connect(_restart_scene)
	SaveManager.apply_upgrades_to_player(player)
	if is_instance_valid(player):
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam != null:
			GameFeelManagerClass.register_active_camera(cam)
	AudioManager.bgm("exploration")
	_update_hud()
	_attach_pacing_probe.call_deferred()
	_attach_mobile_controls()


func _attach_mobile_controls() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if mobile_controls == null:
		mobile_controls = MobileControlsClass.new()
		mobile_controls.name = "MobileControls"
		add_child(mobile_controls)


func _attach_pacing_probe() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var probe := preload("res://scripts/stage/stage_pacing_probe.gd").new()
	probe.name = "PacingProbe"
	add_child(probe)
	probe.attach(self)
func _solid(label: String, at: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = label
	body.position = at
	body.z_index = 0
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


func _build_traversal_terrain() -> void:
	_build_route_loops()
	return


func _build_route_loops() -> void:
	# Wide, overlapping one-way stairs: every missed jump returns to safe ground.
	# Different terrace rhythms make each stage legible without precision gaps.
	for branch in range(route_clusters.size()):
		var cluster: Dictionary = route_clusters[branch]
		var rises: Array = cluster.rises
		var left: float = cluster.left
		var right: float = cluster.right
		var stride: float = (right - left) / rises.size()
		for step in range(rises.size()):
			var rise: float = rises[step]
			_jump_platform("Route%dStep%d" % [branch, step], Vector2(left + stride * (step + 0.5), 620.0 - rise), stride + 16.0)
		var middle: int = rises.size() / 2
		var height: float = rises[middle]
		var group_data := {
			"x": left + stride * (middle + 0.5),
			"y": 620.0 - height - 42.0,
			"started": false,
			"cleared": false,
			"actors": [],
			"defeated": [false, false]
		}
		optional_groups.append(group_data)
		_spawn_optional_group_actors(group_data)
		_sign("↑ 상층 선택 전투 · 아래 길 안전 / → 합류", Vector2(left, 320))




func _terrain_ridge(label: String, left: float, right: float, rise: float, run: float) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.add_to_group("stage_terrain")
	var outline := PackedVector2Array([
		Vector2(left, 620), Vector2(left + run, 620 - rise),
		Vector2(right - run, 620 - rise), Vector2(right, 620),
		Vector2(right, 660), Vector2(left, 660),
	])
	var collision := CollisionPolygon2D.new()
	collision.polygon = outline
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.name = "TerrainVisual"
	visual.polygon = outline
	visual.color = Color(0.25, 0.29, 0.30)
	body.add_child(visual)
	body.set_meta("surface_points", PackedVector2Array([outline[0], outline[1], outline[2], outline[3]]))
	add_child(body)


func _jump_platform(label: String, top_center: Vector2, width: float) -> void:
	var body := _solid(label, top_center + Vector2(0, 9), Vector2(width, 18), Color(0.38, 0.40, 0.36))
	body.add_to_group("stage_terrain")
	var collision := body.get_child(0) as CollisionShape2D
	collision.one_way_collision = true
	body.set_meta("surface_points", PackedVector2Array([Vector2(-width * 0.5, -9), Vector2(width * 0.5, -9)]))


func _sign(message: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = message
	label.position = at
	label.add_theme_font_size_override("font_size", 38)
	add_child(label)
	return label


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
	_update_optional_routes()
	if encounter_index < required_count:
		if not encounter_active and player.position.x >= ENTRY_X[encounter_index]:
			_start_encounter()
		if encounter_active and _all_defeated():
			if encounter_wave == 0:
				encounter_wave = 1
				_spawn_required_wave()
				_update_hud()
				return
			completed[encounter_index] = true
			if is_instance_valid(gates[encounter_index]):
				gates[encounter_index].queue_free()
			if is_instance_valid(arena_entrance_gate):
				arena_entrance_gate.queue_free()
				arena_entrance_gate = null
			encounter_index += 1
			encounter_active = false
	for index in range(checkpoint_positions.size()):
		if index <= checkpoint_index:
			continue
		var prefix: int = checkpoint_required_counts[index]
		var prefix_done := true
		for required in range(prefix):
			prefix_done = prefix_done and completed[required]
		if prefix_done and absf(player.position.x - checkpoint_positions[index].x) <= 70.0 and absf(player.position.y - checkpoint_positions[index].y) <= 100.0:
			checkpoint_index = index
			checkpoint_prefix = prefix
			checkpoint_active = true
			player.current_hp = 3
			for child in get_children():
				if child.is_in_group("enemy_projectile"):
					child.queue_free()
			_show_checkpoint_active()
	# An encounter clear never ends the stage; the goal is a separate condition.
	if not completed.has(false) and absf(player.position.x - GOAL_X) <= 50.0 and absf(player.position.y - 580.0) <= 100.0:
		_finish(StageState.CLEARED)
		return
	_update_hud()


func _start_encounter() -> void:
	encounter_active = true
	# Stage 1~5 Climax Boss Encounter at final encounter gate (in campaign mode or boss mode)
	if (campaign_mode or has_meta("boss_mode")) and (stage_number >= 1 and stage_number <= 5) and encounter_index == required_count - 1:
		encounter_wave = 1
		_spawn_boss_encounter()
		return
	encounter_wave = 0
	_spawn_required_wave()


func _spawn_boss_encounter() -> void:
	enemies.clear()
	defeated.clear()

	# Seamless boss encounter: no blocking gates behind the player
	if is_instance_valid(arena_entrance_gate):
		arena_entrance_gate.queue_free()
	arena_entrance_gate = null

	var boss: CharacterBody2D
	var boss_title: String
	if stage_number == 5:
		boss = AbyssalArbiterClass.new()
		boss_title = "심연의 심판관"
	elif stage_number == 4:
		boss = AncientGolemGuardianClass.new()
		boss_title = "고대 골렘 수호자"
	elif stage_number == 3:
		boss = CrossbowCommanderClass.new()
		boss_title = "폐허의 석궁 사령관"
	elif stage_number == 2:
		boss = BeastChieftainClass.new()
		boss_title = "심연의 맹수 우두머리"
	else:
		boss = BossCommanderClass.new()
		boss_title = "타락한 방패 기사단장"

	var spawn_x := clampf(player.position.x + 650.0, ENTRY_X[encounter_index] + 400.0, EXIT_X[encounter_index] - 180.0)
	boss.position = Vector2(spawn_x, 580.0)
	add_child(boss)
	enemies.append(boss)
	defeated.append(false)
	var slot := enemies.size() - 1

	boss.tree_exiting.connect(_enemy_exiting.bind(boss, slot, encounter_index))
	boss.boss_defeated.connect(func():
		if slot < defeated.size():
			defeated[slot] = true
		AudioManager.bgm("exploration")
	)

	# Switch to Boss BGM
	AudioManager.bgm("boss")

	# Attach cinematic boss bar to HUD
	var hud := get_node_or_null("HUD")
	if hud != null:
		var bar := BossHealthBarClass.new()
		bar.name = "BossHealthBar"
		bar.boss_name = boss_title
		bar.position = Vector2((1280.0 - bar.BAR_WIDTH) * 0.5, 72.0)
		hud.add_child(bar)
		bar.attach_boss(boss)



func _spawn_required_wave() -> void:
	enemies.clear()
	defeated.clear()
	var count: int = 1 if encounter_index < 2 and encounter_wave == 0 else 2
	var beast := load("res://scenes/enemy/ChargingBeast.tscn") as PackedScene
	var golem := load("res://scenes/enemy/GroundSlamGolem.tscn") as PackedScene
	for slot in range(count):
		var role: PackedScene = MELEE
		if slot == 0:
			if stage_number == 2 or (stage_number == 5 and encounter_index % 2 == 0):
				role = beast
			elif stage_number == 4 or stage_number == 5:
				role = golem
			elif stage_number == 3 or (encounter_index > 0 and encounter_wave == 1):
				role = RANGED

		var x: float
		if encounter_wave == 0:
			# 1차 웨이브: 화면 우측 바깥(720px 전방) 또는 인카운터 중간 구역에 미리 스폰되어 순찰
			var min_offscreen_x := player.position.x + 720.0
			var enc_mid_x := (ENTRY_X[encounter_index] + EXIT_X[encounter_index]) * 0.5
			var target_base_x := maxf(min_offscreen_x, enc_mid_x - 140.0)
			x = clampf(target_base_x + slot * 180.0, ENTRY_X[encounter_index] + 260.0, EXIT_X[encounter_index] - 140.0)
		else:
			# 2차 웨이브(증원군): 우측 닫힌 성문(게이트) 부근 또는 화면 우측 끝에서 달려나옴
			var gate_pos_x := EXIT_X[encounter_index] - 80.0
			var min_reinforce_x := maxf(player.position.x + 720.0, gate_pos_x - 200.0)
			x = clampf(min_reinforce_x + slot * 120.0, player.position.x + 480.0, EXIT_X[encounter_index] - 50.0)

		_spawn(role, x)
		var actor: CharacterBody2D = enemies.back()
		if encounter_wave == 1:
			actor.detection_range = 900.0
			if role != RANGED and "state" in actor:
				actor.set("state", 1)
		else:
			actor.detection_range = 560.0
		actor.attack_windup = maxf(actor.attack_windup, 0.75)


func _spawn_optional_group_actors(group: Dictionary) -> void:
	for offset in [-45.0, 45.0]:
		var role: PackedScene = MELEE
		if stage_number == 3 and offset > 0:
			role = RANGED
		elif stage_number >= 4 and offset > 0:
			role = load("res://scenes/enemy/GroundSlamGolem.tscn") as PackedScene
		var actor := role.instantiate() as CharacterBody2D
		actor.position = Vector2(group.x + offset, group.y)
		actor.detection_range = 460.0
		actor.patrol_distance = 180.0
		actor.attack_windup = 0.8
		add_child(actor)
		group.actors.append(actor)
		actor.tree_exiting.connect(_optional_enemy_exiting.bind(actor, group, group.actors.size() - 1))


func _update_optional_routes() -> void:
	for group in optional_groups:
		if not group.started:
			var near_x := absf(player.position.x - group.x) < 420.0
			var near_y := absf(player.position.y - group.y) < 160.0
			if near_x and near_y:
				group.started = true
		if group.started and not group.cleared:
			var all_dead: bool = not group.actors.is_empty()
			for slot in range(group.actors.size()):
				var actor = group.actors[slot]
				if is_instance_valid(actor) and actor.current_hp <= 0:
					group.defeated[slot] = true
				if not group.defeated[slot]:
					all_dead = false
			if all_dead:
				group.cleared = true
				optional_completed[optional_groups.find(group)] = true
				player.current_hp = mini(3, player.current_hp + 1)
				route_status = "선택 전투 완료 · HP +1 (최대 3)"


func _optional_enemy_exiting(actor: CharacterBody2D, group: Dictionary, slot: int) -> void:
	# Despawning a live actor is not a combat victory or a health reward.
	if actor.current_hp <= 0:
		group.defeated[slot] = true


func restore_optional_routes(saved: Array) -> void:
	for index in range(mini(saved.size(), optional_groups.size())):
		if saved[index]:
			optional_completed[index] = true
			optional_groups[index].started = true
			optional_groups[index].cleared = true
			if optional_groups[index].has("actors"):
				for actor in optional_groups[index].actors:
					if is_instance_valid(actor):
						actor.queue_free()




func _spawn(scene: PackedScene, x: float, y: float = 580.0) -> void:
	var enemy := scene.instantiate() as CharacterBody2D
	if stage_number == 2 and scene.resource_path.ends_with("ChargingBeast.tscn"):
		if encounter_index == 0:
			enemy.attack_windup = 0.90
		elif encounter_index == 3 and not enemies.is_empty():
			enemy.attack_windup = 1.0
	# Planning: E2 introduces a readable projectile before mixed encounters.
	if scene == RANGED and encounter_index == 1:
		enemy.detection_range = 450.0
		enemy.attack_windup = 0.70
	# Stage-local body variants reuse the existing combat role, not a new boss AI.
	if stage_number == 1 and scene == MELEE and encounter_index >= 2:
		var variant := "beast" if encounter_index == 2 else "golem" if enemies.is_empty() else "melee"
		enemy.set_meta("art_variant", variant)
		if variant != "melee":
			var dimensions := Vector2(70, 50) if variant == "beast" else Vector2(76, 96)
			for path in ["CollisionShape2D", "HurtArea/CollisionShape2D"]:
				var collision: CollisionShape2D = enemy.get_node(path)
				collision.shape = collision.shape.duplicate()
				collision.shape.size = dimensions
				collision.position.y = 30.0 - dimensions.y * 0.5
	enemy.position = Vector2(x, y)
	if y < 580 and scene == RANGED:
		# A stationary sentry stays on its reachable 80px perch; no new AI layer.
		enemy.move_speed = 0.0
		enemy.detection_range = 520.0
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
	elif encounter_index == required_count:
		objective = "모든 전투 완료 · 오른쪽 GOAL로 이동 →"
	status_label.text = "HP %d/3 · 전투 %d/%d 완료\n%s" % [player.current_hp, encounter_index, required_count, objective]
	if checkpoint_active:
		status_label.text += " · 체크포인트 CP%d 활성" % (checkpoint_index + 1)


func _show_checkpoint_active() -> void:
	for index in range(checkpoint_positions.size()):
		if index <= checkpoint_index:
			checkpoint_signs[index].text = "CP%d — 체크포인트 활성" % (index + 1)
			checkpoint_visuals[index].color = Color(0.2, 0.85, 1.0)
			checkpoint_visuals[index].get_node("S05Art").modulate = Color.WHITE


func get_checkpoint_snapshot() -> Dictionary:
	return {"checkpoint_index": checkpoint_index, "completed_prefix": checkpoint_prefix, "optional_completed": optional_completed.duplicate()}


func resume_snapshot(snapshot: Dictionary) -> void:
	# Fresh-scene restoration: only the prefix captured at checkpoint activation survives.
	var saved_index: int = clampi(int(snapshot.get("checkpoint_index", -1)), -1, checkpoint_positions.size() - 1)
	if saved_index >= 0:
		checkpoint_index = saved_index
		checkpoint_active = true
		checkpoint_prefix = mini(int(snapshot.get("completed_prefix", checkpoint_required_counts[saved_index])), checkpoint_required_counts[saved_index])
		completed.fill(false)
		for index in range(checkpoint_prefix):
			completed[index] = true
			if is_instance_valid(gates[index]):
				gates[index].queue_free()
		encounter_index = checkpoint_prefix
		encounter_active = false
		player.position = checkpoint_positions[saved_index]
		player.current_hp = 3
		player.velocity = Vector2.ZERO
		var camera: Camera2D = player.get_node("Camera2D")
		camera.reset_smoothing()
		camera.force_update_scroll()
		_show_checkpoint_active()
	restore_optional_routes(snapshot.get("optional_completed", []))
	_update_hud()


func _resume_checkpoint() -> void:
	# Compatibility helper for first-checkpoint callers.
	resume_snapshot({"checkpoint_index": 0, "completed_prefix": checkpoint_required_counts[0]})


func _finish(result: StageState) -> void:
	if stage_state != StageState.PLAYING:
		return
	stage_state = result
	if result == StageState.CLEARED:
		if is_instance_valid(player) and "soul_shards" in player and player.soul_shards > 0:
			SaveManager.add_shards(player.soul_shards)
	status_label.text = "스테이지 성공 · CLEARED" if result == StageState.CLEARED else "실패 · FAILED"
	status_label.text += "\n1.5초 후 CP%d에서 재시작" % (checkpoint_index + 1) if result == StageState.FAILED and checkpoint_active else "\n1.5초 후 시작점에서 재시작"
	# Freeze combat during the terminal display. The timer stays active.
	for child in get_children():
		if child is CharacterBody2D or child is Area2D:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)
	if mobile_controls != null and is_instance_valid(mobile_controls):
		mobile_controls.visible = false
		mobile_controls.release_all_touches()
		mobile_controls.process_mode = Node.PROCESS_MODE_DISABLED
	if not campaign_mode:
		restart_timer.start()
	stage_finished.emit(int(result))


func resume_from_ad_revive() -> void:
	stage_state = StageState.PLAYING
	set_physics_process(true)
	if mobile_controls != null and is_instance_valid(mobile_controls):
		mobile_controls.visible = mobile_controls.is_mobile_active
		mobile_controls.process_mode = Node.PROCESS_MODE_INHERIT
	_judgment_pending = false
	restart_timer.stop()
	for child in get_children():
		if child is CharacterBody2D or child is Area2D:
			child.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(player):
		player.revive(true)
	_update_hud()
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var diff := enemy.global_position.x - player.global_position.x
			if absf(diff) < 220.0:
				enemy.velocity.x = signf(diff) * 350.0


func _restart_scene() -> void:
	if stage_state == StageState.PLAYING or _reload_started:
		return
	_reload_started = true
	reload_count += 1
	var tree := get_tree()
	# A static one-shot callback survives the old scene being freed. No global
	# session object or per-actor reset is needed; success starts a new run.
	var restore := _restore_checkpoint_after_reload.bind(tree, get_checkpoint_snapshot())
	if stage_state == StageState.FAILED:
		tree.scene_changed.connect(restore, CONNECT_ONE_SHOT)
	var restart_path := scene_file_path
	if restart_path.is_empty():
		restart_path = "res://scenes/stage/SecondStage.tscn" if stage_number == 2 else "res://scenes/stage/FirstStage.tscn"
	var error := tree.change_scene_to_file(restart_path)
	if error != OK:
		if tree.scene_changed.is_connected(restore):
			tree.scene_changed.disconnect(restore)
		push_error("Stage restart failed: %s" % error_string(error))


static func _restore_checkpoint_after_reload(tree: SceneTree, saved: Dictionary) -> void:
	tree.current_scene.resume_snapshot(saved)
