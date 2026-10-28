extends SceneTree
## 정직한 실플레이 검증 봇 (Honest Input-Only Playtest Bot)
## 원칙:
##  - 게임 내부 메서드(receive_hit, _start_boss_wave, apply_parry_stun 등)를 절대 직접 호출하지 않는다.
##  - 오직 Input.action_press / action_release (키 입력)만 사용한다.
##  - 측정된 수치만 보고한다 (PASS/FAIL 판정이 아니라 관측 결과).
## 실행: --headless --fixed-fps 60 -s res://tests/side_qv_honest_playtest_bot.gd
##       (스크린샷: 비헤드리스 + 사용자 인자 `-- shots`)

const CampaignScene := preload("res://scenes/side_quarter_view/SideQVCampaign.tscn")

const STAGE_TIME_LIMIT := 90.0     # 스테이지당 최대 게임 시간(초)
const REAL_TIME_LIMIT_MS := 100000 # 실시간 워치독 (100초)
const MAX_ATTEMPTS := 3            # 같은 스테이지 연속 실패 허용 횟수

var attempt: int = 0
var single_mode := false

var campaign: Node = null
var stage: Node = null
var player: Node = null
var stage_idx: int = -1
var stage_time: float = 0.0
var total_time: float = 0.0
var start_ms: int = 0
var shots_mode := false
var shot_marks: Array = []

# 측정 지표 (스테이지별)
var m := {}
var report: Array = []
var last_enemy_hp := {}
var attack_cooldown_t := 0.0
var attack_held := false
var beams_fired := 0
var finished := false


func _initialize() -> void:
	start_ms = Time.get_ticks_msec()
	shots_mode = "shots" in OS.get_cmdline_user_args()
	single_mode = "single" in OS.get_cmdline_user_args()
	# 게임 시간 워치독
	create_timer(STAGE_TIME_LIMIT * 5.0 + 30.0).timeout.connect(func():
		_finish("GAME-TIME WATCHDOG"))
	campaign = CampaignScene.instantiate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("stage="):
			campaign.set("start_stage_index", int(a.substr(6)) - 1)
	root.add_child(campaign)
	current_scene = campaign


func _new_metrics() -> Dictionary:
	return {
		"attacks_pressed": 0, "melee_dmg": 0, "beam_dmg": 0, "beams": 0,
		"player_dmg_taken": 0, "deaths": 0, "boss_seen": false, "boss_hp_max": 0,
		"boss_hp_min": 9999, "cleared": false, "clear_time": -1.0,
		"wave1_clear_time": -1.0, "boss_spawn_time": -1.0, "stuck_frames": 0,
		"hud_boss_bars": 0, "hud_issue": "", "player_min_x": 999.0, "player_max_x": -999.0,
		"attempt": 1, "death_time": -1.0, "first_hit_time": -1.0, "first_hit_to_death": -1.0,
		"hit_events": 0, "dmg_after_death": 0, "min_player_hp": 99,
	}


func _physics_process(delta: float) -> bool:
	if finished:
		return true
	if Time.get_ticks_msec() - start_ms > REAL_TIME_LIMIT_MS:
		_finish("REAL-TIME WATCHDOG")
		return true
	total_time += delta

	var cur = campaign.get("current_stage_instance")
	if cur == null or not is_instance_valid(cur):
		return false
	var idx: int = int(campaign.get("current_stage_index"))
	if cur != stage:
		# 새 스테이지 인스턴스 = 새 시도(사망 후 재시작 포함)
		if stage_idx >= 0:
			_close_stage(false)
		attempt = attempt + 1 if idx == stage_idx else 1
		stage_idx = idx
		m = _new_metrics()
		m["attempt"] = attempt
		stage_time = 0.0
		shot_marks = []
		if attempt > MAX_ATTEMPTS:
			_finish("STAGE %d: %d회 연속 실패" % [stage_idx + 1, MAX_ATTEMPTS])
			return true
		stage = cur
		player = null
		last_enemy_hp.clear()
		if not stage.stage_cleared.is_connected(_on_cleared):
			stage.stage_cleared.connect(_on_cleared)
	if player == null or not is_instance_valid(player):
		player = stage.get("player")
		if player == null:
			return false
		player.died.connect(func():
			if m["death_time"] < 0.0:
				m["death_time"] = stage_time
				m["first_hit_to_death"] = stage_time - m["first_hit_time"])
		player.sword_beam_fired.connect(func(_b): m["beams"] += 1)
		_last_player_hp = player.current_hp

	stage_time += delta
	_measure(delta)
	_drive(delta)
	if shots_mode:
		_maybe_shot()

	if m["cleared"] and (stage_idx == 4 or single_mode):
		_close_stage(false)
		_finish("CAMPAIGN COMPLETE" if stage_idx == 4 else "STAGE %d CLEARED (single)" % (stage_idx + 1))
		return true
	if stage_time > STAGE_TIME_LIMIT and not m["cleared"]:
		_close_stage(true)
		_finish("STAGE %d TIME LIMIT" % (stage_idx + 1))
	return false


var _last_player_hp := 0

func _measure(_delta: float) -> void:
	# 플레이어 피해
	if player.current_hp < _last_player_hp:
		var d: int = _last_player_hp - player.current_hp
		m["player_dmg_taken"] += d
		m["hit_events"] += 1
		if m["first_hit_time"] < 0.0:
			m["first_hit_time"] = stage_time
		if _last_player_hp <= 0:
			m["dmg_after_death"] += d
	_last_player_hp = player.current_hp
	m["min_player_hp"] = mini(m["min_player_hp"], player.current_hp)
	m["player_min_x"] = minf(m["player_min_x"], player.global_position.x)
	m["player_max_x"] = maxf(m["player_max_x"], player.global_position.x)

	# 적 피해 귀속 (빔 존재 여부로 근접/검기 구분)
	var beam_alive := false
	for c in stage.get_children():
		if c is Area3D and c.get_script() != null and str(c.get_script().resource_path).ends_with("side_qv_sword_beam.gd"):
			beam_alive = true
			break
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not ("current_hp" in e):
			continue
		var id := e.get_instance_id()
		var hp: int = e.current_hp
		if last_enemy_hp.has(id) and hp < last_enemy_hp[id]:
			var d: int = last_enemy_hp[id] - hp
			if beam_alive:
				m["beam_dmg"] += d
			else:
				m["melee_dmg"] += d
		last_enemy_hp[id] = hp
		if e.is_in_group("bosses"):
			if not m["boss_seen"]:
				m["boss_seen"] = true
				m["boss_spawn_time"] = stage_time
				m["boss_hp_max"] = e.max_hp
			m["boss_hp_min"] = mini(m["boss_hp_min"], hp)

	var wave: int = int(stage.get("current_wave"))
	if wave >= 2 and m["wave1_clear_time"] < 0.0:
		m["wave1_clear_time"] = stage_time

	# HUD 보스바 중복 검사 (보이는 보스바 개수)
	if m["boss_seen"] and m["hud_boss_bars"] == 0:
		var ui = stage.get("mobile_controls")
		if ui != null:
			var n := 0
			for c in ui.get_children():
				if c is Control and c.visible and ("Boss" in str(c.name)) and c.modulate.a > 0.05:
					n += 1
			m["hud_boss_bars"] = n


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		if "current_hp" in e and e.current_hp <= 0:
			continue
		var d: float = (e.global_position - player.global_position).length()
		if d < bd:
			bd = d
			best = e
	return best


func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _drive(delta: float) -> void:
	attack_cooldown_t -= delta
	if attack_held:
		Input.action_release("attack")
		attack_held = false

	var target := _nearest_enemy()
	if target == null:
		# 적이 없으면 오른쪽으로 전진
		_release_moves()
		Input.action_press("move_right")
		return

	var diff: Vector3 = target.global_position - player.global_position
	var want_x := 1.4
	_release_moves()
	var moving := false
	if absf(diff.x) > want_x:
		Input.action_press("move_right" if diff.x > 0.0 else "move_left")
		moving = true
	if absf(diff.z) > 0.45:
		Input.action_press("move_down" if diff.z > 0.0 else "move_up")
		moving = true
	if not moving:
		# 적을 바라보도록 한 프레임 탭
		var face := "move_right" if diff.x > 0.0 else "move_left"
		if signf(diff.x) != signf(player.facing_dir_x):
			Input.action_press(face)
	if absf(diff.x) < 2.2 and absf(diff.z) < 0.8 and attack_cooldown_t <= 0.0:
		Input.action_press("attack")
		attack_held = true
		attack_cooldown_t = 0.26
		m["attacks_pressed"] += 1

	if Vector2(player.velocity.x, player.velocity.z).length() < 0.05 and moving:
		m["stuck_frames"] += 1


func _on_cleared() -> void:
	if not m.is_empty() and not m["cleared"]:
		m["cleared"] = true
		m["clear_time"] = stage_time


func _close_stage(timeout: bool) -> void:
	if m.is_empty() or m.get("closed", false):
		return
	m["closed"] = true
	var r := m.duplicate()
	r["stage"] = stage_idx + 1
	r["timeout"] = timeout
	report.append(r)


func _maybe_shot() -> void:
	for t in [1.0, 4.0, 8.0, 14.0, 22.0]:
		if stage_time >= t and not (t in shot_marks):
			shot_marks.append(t)
			var img := root.get_viewport().get_texture().get_image()
			if img != null:
				var p := "user://playtest_s%d_t%02d.png" % [stage_idx + 1, int(t)]
				img.save_png(p)
				print("[SHOT] ", ProjectSettings.globalize_path(p))


func _finish(reason: String) -> void:
	if finished:
		return
	finished = true
	_release_moves()
	if stage_idx >= 0 and attempt <= MAX_ATTEMPTS:
		_close_stage(false)
	print("\n================ HONEST PLAYTEST REPORT ================")
	print("종료 사유: %s | 총 게임시간 %.1fs | 실시간 %.1fs" % [reason, total_time, (Time.get_ticks_msec() - start_ms) / 1000.0])
	for r in report:
		print("--- STAGE %d / 시도 %d ---" % [r["stage"], r["attempt"]])
		print("  클리어: %s (%.1fs) | 시간초과: %s | 사망 시각: %.1fs | 첫 피격→사망: %.2fs" % [r["cleared"], r["clear_time"], r["timeout"], r["death_time"], r["first_hit_to_death"]])
		print("  웨이브1 종료: %.1fs | 보스 등장: %s (%.1fs) | 보스 HP 최저 %d/%d" % [r["wave1_clear_time"], r["boss_seen"], r["boss_spawn_time"], r["boss_hp_min"] if r["boss_seen"] else -1, r["boss_hp_max"]])
		print("  공격 입력 %d회 | 근접 피해 %d | 검기 피해 %d (검기 %d발)" % [r["attacks_pressed"], r["melee_dmg"], r["beam_dmg"], r["beams"]])
		print("  받은 피해 %d (피격 %d회) | 최저 HP %d | 사망 후 추가 피해 %d" % [r["player_dmg_taken"], r["hit_events"], r["min_player_hp"], r["dmg_after_death"]])
		print("  플레이어 X 이동 범위: %.1f ~ %.1f | 이동 막힘 프레임: %d | 보이는 보스바 수: %d" % [r["player_min_x"], r["player_max_x"], r["stuck_frames"], r["hud_boss_bars"]])
	print("========================================================\n")
	quit(0)
