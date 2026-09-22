extends Control
## Stage presentation: observes campaign and combat state, never chooses outcomes.
const INK := Color("101b26")
const GOLD := Color("ddc18a")
const CYAN := Color("69d5dc")
const WHITE := Color("edf0ed")
const MUTED := Color("9aaeb8")
const ENCOUNTER_HINTS := ["정면 근접 공격을 검으로 막고 반격하세요", "정면의 탄은 막아서 소멸시킬 수 있어요", "정면은 막고 뒤쪽 공격은 위치를 바꿔 피하세요", "마지막 전투 · 막기 뒤 회복을 기다리고 반격하세요"]
const STAGE_TWO_HINTS := ["돌진은 막기 불가 · 점프나 거리 이탈로 피하세요", "주황 × 문양은 막기 불가 · 돌진 뒤 반격하세요", "탄은 막기 · 돌진은 점프나 거리 이탈", "돌진 뒤 회복 시간에 반격하며 길을 여세요"]
const ACTIONS := ["move_left", "move_right", "attack", "jump", "guard"]
const BUTTONS := [Vector2(82, 638), Vector2(200, 638), Vector2(964, 638), Vector2(1082, 556), Vector2(1200, 638)]
const TOUCH_RADIUS := 50.0
const TOUCH_HIT_RADIUS := 54.0
const KEYS := {"move_left": KEY_A, "move_right": KEY_D, "attack": KEY_J, "jump": KEY_SPACE, "guard": KEY_K}
var font := SystemFont.new()
var hud_shade := GradientTexture2D.new()
var stage: Node2D
var initialized := false
var elapsed := 0.0
var intro_remaining := 5.5
var toast_remaining := 0.0
var toast := ""
var hit_remaining := 0.0
var previous_hp := 3
var previous_completed := 0
var previous_checkpoint := -1
var touch_visible := false:
	set(value):
		touch_visible = value
		if is_instance_valid(stage) and stage.get("mobile_controls") != null:
			stage.mobile_controls.visible = not value
			stage.mobile_controls.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
var show_help := false
var pause_owned := false
var fingers: Dictionary = {}
var touch_actions: Dictionary = {}
var ui_scale := 1.0
var ui_offset := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR"])
	var shade := Gradient.new()
	shade.colors = PackedColorArray([Color(0.025, 0.04, 0.06, 0.68), Color(0.025, 0.04, 0.06, 0.0)])
	hud_shade.gradient = shade
	hud_shade.width = 8
	hud_shade.height = 256
	hud_shade.fill_from = Vector2(0, 0)
	hud_shade.fill_to = Vector2(0, 1)
	# Legacy prototype touch buttons disabled by default; replaced by dedicated MobileControls
	touch_visible = false
	_setup.call_deferred()

func _setup() -> void:
	if not is_inside_tree():
		return
	stage = get_parent().get_parent()
	stage.status_label.visible = false
	previous_hp = stage.player.current_hp
	previous_completed = stage.encounter_index
	previous_checkpoint = stage.checkpoint_index
	initialized = true

func _process(delta: float) -> void:
	if not initialized or not is_instance_valid(stage):
		return
	ui_scale = minf(size.x / 1280.0, size.y / 720.0)
	ui_offset = (size - Vector2(1280, 720) * ui_scale) * 0.5
	if not get_tree().paused:
		if stage.stage_state == 0:
			elapsed += delta
		intro_remaining = maxf(0, intro_remaining - delta)
		toast_remaining = maxf(0, toast_remaining - delta)
		hit_remaining = maxf(0, hit_remaining - delta)
	if stage.player.current_hp < previous_hp:
		hit_remaining = 0.22
	if stage.checkpoint_index > previous_checkpoint:
		toast = "휴식처 %d 저장  ·  체력 3으로 회복" % (stage.checkpoint_index + 1)
		toast_remaining = 3.0
	elif stage.encounter_index > previous_completed:
		toast = "%d구간 돌파  ·  다음 목표로 이동" % stage.encounter_index
		toast_remaining = 2.4
	previous_hp = stage.player.current_hp
	previous_completed = stage.encounter_index
	previous_checkpoint = stage.checkpoint_index
	if stage.stage_state != 0 or get_tree().paused:
		release_touches()
	queue_redraw()

func objective() -> String:
	if not initialized:
		return ""
	if stage.stage_state == 1:
		return "필수 전투를 마치고 목표에 도착했습니다"
	if stage.stage_state == 2:
		return "휴식처 %d에서 다시 도전" % (stage.checkpoint_index + 1) if stage.checkpoint_active else "시작 지점에서 다시 도전"
	if stage.encounter_index == stage.required_count:
		return "오른쪽의 황금 표식에 도착하세요"
	if stage.encounter_active:
		var alive := 0
		var has_boss := false
		for enemy in stage.enemies:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.current_hp > 0:
				alive += 1
				if enemy.is_in_group("boss"):
					has_boss = true
		if has_boss:
			return "관문 결전  ·  타락한 방패 기사단장을 격파하세요!"
		return "%d구간  ·  남은 적 %d명" % [stage.encounter_index + 1, alive]
	var next_checkpoint: int = stage.checkpoint_index + 1
	if next_checkpoint < stage.checkpoint_required_counts.size() and stage.encounter_index >= stage.checkpoint_required_counts[next_checkpoint] and stage.player.position.x <= stage.CHECKPOINT_POSITIONS[next_checkpoint].x + 70:
		return "청록색 휴식처 %d를 활성화하세요  →" % (next_checkpoint + 1)
	return "%d구간으로 이동하세요  →" % (stage.encounter_index + 1)


func stage_label() -> String:
	return "스테이지 %02d · %s" % [stage.stage_number, ["성문 외곽", "야수숲", "무너진 성벽", "돌의 성소", "침묵의 성채"][stage.stage_number - 1]]

func region_intro() -> String:
	return ["성문 너머, 갈림길을 따라", "돌진을 읽고 길을 여는 여정", "높이를 바꾸며 사선 돌파", "강타의 예고를 읽는 돌의 성소", "모든 경험을 모아 성채의 끝으로"][stage.stage_number - 1]

func chapter_label() -> String:
	var chapters := [["첫 발걸음", "갈림길", "마지막 문턱"], ["오르막", "엇갈린 길", "맞은편"], ["입구", "위쪽 길", "돌아가는 길", "출구"], ["좁은 틈", "열린 마당", "두 갈래", "끝자락"], ["경계", "상승", "교차점", "마지막 길"]]
	var names: Array = chapters[stage.stage_number - 1]
	return "%d장 · %s" % [mini(stage.encounter_index / 2 + 1, names.size()), names[mini(stage.encounter_index / 2, names.size() - 1)]]

func region_strategy() -> String:
	return ["적의 예고를 읽고 황금 표식까지", "예고 때 방향 고정 · 점프와 거리 이탈 · 멈추면 반격", "발판에 뛰어올라 사수 접근 · 공중에서도 공격 가능", "바닥 예고에서 점프나 이탈 · 강타 뒤 긴 빈틈에 반격", "돌진·사수·강타를 나누어 상대하고 마지막 목표에 도착"][stage.stage_number - 1]

func encounter_hint() -> String:
	if stage.stage_number >= 3:
		return region_strategy()
	var hints = STAGE_TWO_HINTS if stage.stage_number == 2 else ENCOUNTER_HINTS
	return hints[clampi(stage.encounter_index, 0, hints.size() - 1)]

func trait_label() -> String:
	return "특성 · 긴 칼날 / 공격 간격 증가" if stage.player.get_meta("equipped_trait", "basic") == "reach" else "특성 · 기본 검술"

func transition_message() -> String:
	if stage.campaign_mode:
		if stage.stage_state == 1:
			return "다음 여정을 준비합니다"
		return "잠시 후 휴식처 %d로 복귀합니다" % (stage.checkpoint_index + 1) if stage.checkpoint_active else "잠시 후 시작점으로 복귀합니다"
	return "%.1f초 후 %s" % [stage.restart_timer.time_left, "새 도전" if stage.stage_state == 1 else "체크포인트 복귀" if stage.checkpoint_active else "시작점 복귀"]

var _cached_pill_style: StyleBoxFlat = null
var _cached_plate_style: StyleBoxFlat = null

func _plate(rect: Rect2, accent: Color = Color("405563"), fill: Color = Color(0.035, 0.07, 0.10, 0.94)) -> void:
	if _cached_plate_style == null:
		_cached_plate_style = StyleBoxFlat.new()
		_cached_plate_style.set_corner_radius_all(12)
		_cached_plate_style.set_border_width_all(2)
	_cached_plate_style.bg_color = fill
	_cached_plate_style.border_color = accent
	draw_style_box(_cached_plate_style, rect)

func _text(at: Vector2, message: String, height: int = 18, color: Color = WHITE) -> void:
	draw_string_outline(font, at + Vector2(0, 1), message, HORIZONTAL_ALIGNMENT_LEFT, -1, height, 3, Color(0.035, 0.055, 0.075, 0.85))
	draw_string(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, height, color)

func _pill(rect: Rect2) -> void:
	if _cached_pill_style == null:
		_cached_pill_style = StyleBoxFlat.new()
		_cached_pill_style.bg_color = Color(0.035, 0.07, 0.10, 0.82)
		_cached_pill_style.set_corner_radius_all(20)
		_cached_pill_style.set_border_width_all(1)
		_cached_pill_style.border_color = Color(0.3, 0.5, 0.6, 0.5)
	draw_style_box(_cached_pill_style, rect)

func _center(at: Vector2, message: String, height: int, color: Color = WHITE) -> void:
	_text(at - Vector2(font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, height).x * 0.5, 0), message, height, color)

func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

func _heart(at: Vector2, full: bool) -> void:
	var color := Color("ed9c99") if full else Color("48545b")
	# Scaled 2x for crisp mobile readability: radius 16, tapered bottom 32px
	draw_circle(at + Vector2(-12, -6), 16, color)
	draw_circle(at + Vector2(12, -6), 16, color)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-26, 0), at + Vector2(26, 0), at + Vector2(0, 32)]), color)
	if full:
		draw_arc(at + Vector2(-12, -6), 8.0, PI, PI * 1.65, 12, Color("ffe0cc"), 3.5, true)

func _draw() -> void:
	if not initialized or not is_instance_valid(stage):
		return
	draw_set_transform(ui_offset, 0, Vector2.ONE * ui_scale)
	# Expanded HUD band (245px) for 2x mobile legibility
	draw_texture_rect(hud_shade, Rect2(0, 0, 1280, 245), false)

	# 1. Left Zone: Title, Hearts, Soul Shards, Checkpoint, Traits (Scaled 2x)
	_text(Vector2(38, 44), "기사의 여정 · " + stage_label(), 36, GOLD)
	for index in range(3):
		var full: bool = stage.player.current_hp > index
		_heart(Vector2(60 + index * 68, 92), full)
	var shards: int = stage.player.soul_shards if "soul_shards" in stage.player else 0
	_diamond(Vector2(296, 92), 16, Color(0.2, 0.9, 1.0))
	_text(Vector2(322, 102), "%d" % shards, 32, Color(0.35, 0.95, 1.0))
	if stage.checkpoint_active:
		_diamond(Vector2(48, 144), 10, CYAN)
		_text(Vector2(68, 152), "휴식처 %d / %d 저장됨" % [stage.checkpoint_index + 1, stage.CHECKPOINT_POSITIONS.size()], 28, CYAN)
	_text(Vector2(38, 188), trait_label(), 24, MUTED)
	_text(Vector2(38, 220), chapter_label(), 24, GOLD)

	# 2. Center Zone: Encounter Track, Objective, Hints (Scaled 2x)
	for index in range(stage.required_count):
		var x: float = 640 - (stage.required_count - 1) * 32 + index * 64
		if index < stage.required_count - 1:
			draw_line(Vector2(x + 16, 36), Vector2(x + 48, 36), Color(0.7, 0.64, 0.48, 0.45), 4)
		var done: bool = stage.completed[index]
		if index == stage.encounter_index:
			draw_circle(Vector2(x, 36), 20, Color(0.85, 0.72, 0.47, 0.20))
			draw_arc(Vector2(x, 36), 20, 0, TAU, 32, GOLD, 3.5, true)
		_diamond(Vector2(x, 36), 12, CYAN if done else GOLD if index == stage.encounter_index else Color("52606b"))
	var has_boss_bar := (stage.get_node_or_null("HUD/BossHealthBar") != null)
	var next_y: float = 92.0
	if has_boss_bar:
		# When boss bar is active at top center (y=72~140), show only compact hint below it to prevent overlap
		if stage.stage_state == 0 and stage.encounter_active:
			_center(Vector2(640, 168), encounter_hint(), 26, Color(1.0, 0.9, 0.75, 0.9))
			next_y = 205.0
		else:
			next_y = 168.0
	else:
		_center(Vector2(640, 92), objective(), 36, WHITE)
		next_y = 136.0
		if stage.stage_state == 0 and stage.encounter_active and stage.encounter_index < stage.required_count:
			_center(Vector2(640, next_y), encounter_hint(), 26, Color(1.0, 0.9, 0.75, 0.9))
			next_y += 38.0
		if stage.stage_state == 0 and stage.get("route_status") != null and str(stage.route_status) != "":
			var route_text: String = str(stage.route_status)
			var tw := font.get_string_size(route_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24).x + 44.0
			_pill(Rect2(640.0 - tw * 0.5, next_y - 20.0, tw, 36.0))
			_center(Vector2(640, next_y + 4.0), route_text, 24, CYAN)
			next_y += 44.0
	if intro_remaining > 0 and stage.stage_state == 0 and not stage.encounter_active and not get_tree().paused:
		_center(Vector2(640, next_y + 16.0), region_intro(), 36, GOLD)
		_center(Vector2(640, next_y + 52.0), region_strategy(), 24, MUTED)
	elif toast_remaining > 0 and stage.stage_state == 0:
		var toast_w := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x + 56.0
		_pill(Rect2(640.0 - toast_w * 0.5, next_y + 8.0, toast_w, 48.0))
		_center(Vector2(640, next_y + 38.0), toast, 30, GOLD)

	if touch_visible and stage.stage_state == 0 and not get_tree().paused:
		_draw_touch()
	elif not _has_dedicated_mobile_controls():
		_center(Vector2(640, 693), "A/D 이동    Space 점프    J 누르고 연속 공격    K 누르고 막기    H 도움말", 22, MUTED)
	# Compact dark pills retain contrast against bright scenery and existing hit regions.
	if not _has_dedicated_mobile_controls():
		_pill(Rect2(1070, 130, 180, 52))
		_center(Vector2(1160, 164), "터치 " + ("켜짐" if touch_visible else "꺼짐"), 24, CYAN if touch_visible else WHITE)
	_pill(Rect2(1070, 48, 180, 56))
	_center(Vector2(1160, 84), "Ⅱ  쉬어가기", 26, WHITE)

	if hit_remaining > 0:
		var alpha := hit_remaining / 0.22 * 0.5
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.22, 0.18, alpha), false, 12.0)
	if stage.stage_state != 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.025, 0.04, 0.75))
		var cleared: bool = stage.stage_state == 1
		var accent := GOLD if cleared else Color("e99589")
		_plate(Rect2(200, 140, 880, 440), accent)
		_center(Vector2(640, 200), stage_label(), 28, accent)
		_center(Vector2(640, 270), "스테이지 완료" if cleared else "다시 일어설 시간", 54, accent)
		_center(Vector2(640, 345), objective(), 34)
		_center(Vector2(640, 410), "필수 전투 %d / %d 완료" % [stage.encounter_index, stage.required_count], 28, MUTED)
		_center(Vector2(640, 485), transition_message(), 28)
	elif get_tree().paused or show_help:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.025, 0.04, 0.75))
		_plate(Rect2(160, 110, 960, 500), GOLD)
		_center(Vector2(640, 175), "잠시 숨 고르기" if get_tree().paused else "플레이 안내", 46, GOLD)
		_center(Vector2(640, 240), "A/D 이동   ·   Space 점프   ·   J 공격   ·   K 막기   ·   Shift 대시", 28)
		_center(Vector2(640, 300), "필수 전투 %d구간 · 휴식처 %d곳 · 위쪽 갈림길은 선택" % [stage.required_count, stage.CHECKPOINT_POSITIONS.size()], 28)
		_center(Vector2(640, 355), "공격은 누르고 연속 · 막기는 누르는 동안 지상 정면 방어", 24, MUTED)
		_center(Vector2(640, 405), "주황 × 문양의 돌진·지면 강타는 막기 불가 · 점프로 피하세요", 24, MUTED)
		_center(Vector2(640, 455), "체크포인트 HP 3 회복 · 선택 전투는 각 1회 HP +1 (최대 3)", 24, CYAN)
		_center(Vector2(640, 530), "Esc 또는 화면 클릭으로 계속", 28, CYAN)
	draw_set_transform(Vector2.ZERO)

func _draw_touch() -> void:
	var titles := ["◀", "▶", "공격", "점프", "막기"]
	for index in range(ACTIONS.size()):
		var down := Input.is_action_pressed(ACTIONS[index])
		draw_circle(BUTTONS[index], TOUCH_RADIUS, Color(0.05, 0.12, 0.17, 0.84) if not down else Color(0.12, 0.38, 0.43, 0.96))
		draw_arc(BUTTONS[index], TOUCH_RADIUS, 0, TAU, 48, CYAN if down else GOLD if index >= 2 else Color("6c858d"), 4 if down else 2, true)
		_center(BUTTONS[index] + Vector2(0, 7), titles[index], 23, WHITE)
		if index == 2 or index == 4:
			_center(BUTTONS[index] + Vector2(0, 29), "누르기 유지", 11, CYAN if down else MUTED)

func _touch_action(point: Vector2) -> String:
	for index in range(ACTIONS.size()):
		if point.distance_to(BUTTONS[index]) <= TOUCH_HIT_RADIUS:
			return ACTIONS[index]
	return ""

func set_finger(index: int, point: Vector2, pressed: bool) -> void:
	if pressed:
		fingers[index] = _touch_action(point)
	else:
		fingers.erase(index)
	var wanted: Dictionary = {}
	for action in fingers.values():
		if not action.is_empty():
			wanted[action] = true
	for action in touch_actions:
		if not wanted.has(action):
			Input.action_release(action)
			# Preserve a physical key still held when a touch ends.
			if Input.is_physical_key_pressed(KEYS[action]) or (action == "move_left" and Input.is_key_pressed(KEY_LEFT)) or (action == "move_right" and Input.is_key_pressed(KEY_RIGHT)):
				Input.action_press(action)
	for action in wanted:
		if not touch_actions.has(action):
			Input.action_press(action)
	touch_actions = wanted

func release_touches() -> void:
	for action in touch_actions:
		Input.action_release(action)
	fingers.clear()
	touch_actions.clear()

func _has_dedicated_mobile_controls() -> bool:
	return is_instance_valid(stage) and (stage.get("mobile_controls") != null or stage.has_node("MobileControls"))

func _ui_button(point: Vector2) -> bool:
	if pause_owned:
		_toggle_pause()
		return true
	if not _has_dedicated_mobile_controls() and Rect2(1090, 146, 166, 40).has_point(point):
		touch_visible = not touch_visible
		release_touches()
		return true
	if Rect2(1090, 60, 180, 160).has_point(point):
		_toggle_pause()
		return true
	return false

func _toggle_pause(help: bool = false) -> void:
	if stage.stage_state != 0:
		return
	release_touches()
	_release_guard()
	pause_owned = not pause_owned
	get_tree().paused = pause_owned
	show_help = help and pause_owned

func _input(event: InputEvent) -> void:
	if not initialized:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_H:
			_toggle_pause(event.physical_keycode == KEY_H)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = (event.position - ui_offset) / maxf(ui_scale, 0.01)
		_ui_button(point)
	if event is InputEventScreenTouch:
		var point: Vector2 = (event.position - ui_offset) / maxf(ui_scale, 0.01)
		if event.pressed and _ui_button(point):
			return
		if touch_visible and stage.stage_state == 0 and not get_tree().paused:
			set_finger(event.index, point, event.pressed and not event.canceled)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		set_finger(event.index, (event.position - ui_offset) / maxf(ui_scale, 0.01), true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_touches()
		_release_guard()

func _release_guard() -> void:
	Input.action_release("guard")
	if initialized and is_instance_valid(stage) and is_instance_valid(stage.player):
		stage.player._end_guard()

func _exit_tree() -> void:
	release_touches()
	if pause_owned and get_tree() != null:
		get_tree().paused = false
