extends Control
## Stage presentation: observes campaign and combat state, never chooses outcomes.
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const TexAvatarFrame = preload("res://assets/ui/hud_player_avatar_frame.png")
const TexSoulGemFull = preload("res://assets/ui/hud_soul_gem_full.png")
const TexSoulGemEmpty = preload("res://assets/ui/hud_soul_gem_empty.png")
const TexBannerScroll = preload("res://assets/ui/hud_banner_scroll.png")
const TexComboFrame = preload("res://assets/ui/combo_banner_frame.png")
const TexParryBanner = preload("res://assets/ui/parry_burst_banner.png")
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
var _last_hp := -1
var _last_shards := -1
var _last_encounter := -1
var _last_checkpoint := -1
var _last_checkpoint_active := false
var _last_stage_state := -1
var _last_alive_enemies := -1
var _last_encounter_active := false
var _last_size := Vector2.ZERO
var _last_show_help := false
var _last_paused := false
var _last_has_boss_bar := false
var _last_touch_visible := false
var _last_route_status := ""
var _had_intro := false
var _had_toast := false
var _had_hit := false

# Third Blade Dynamic Combo & Just Parry System
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.4
var combo_scale: float = 1.0
var parry_banner_timer: float = 0.0
var parry_banner_scale: float = 1.0

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
	_connect_player_signals()
	initialized = true
	queue_redraw()

func _connect_player_signals() -> void:
	if not is_instance_valid(stage) or not is_instance_valid(stage.player):
		return
	if stage.player.has_signal("enemy_hit_registered") and not stage.player.enemy_hit_registered.is_connected(_on_enemy_hit):
		stage.player.enemy_hit_registered.connect(_on_enemy_hit)
	if stage.player.has_signal("perfect_parry_performed") and not stage.player.perfect_parry_performed.is_connected(_on_perfect_parry):
		stage.player.perfect_parry_performed.connect(_on_perfect_parry)

func _on_enemy_hit(_target: Node, _is_crit: bool, _dmg: int) -> void:
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	combo_scale = 1.35
	queue_redraw()

func _on_perfect_parry() -> void:
	parry_banner_timer = 1.4
	parry_banner_scale = 1.4
	combo_count += 2
	combo_timer = COMBO_TIMEOUT
	queue_redraw()

func _process(delta: float) -> void:
	if not initialized or not is_instance_valid(stage):
		return
	ui_scale = minf(size.x / 1280.0, size.y / 720.0)
	ui_offset = (size - Vector2(1280, 720) * ui_scale) * 0.5
	var is_paused := get_tree().paused
	if not is_paused:
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
	if stage.stage_state != 0 or is_paused:
		release_touches()

	var needs_redraw := false
	if intro_remaining > 0.0:
		needs_redraw = true
		_had_intro = true
	elif _had_intro:
		_had_intro = false
		needs_redraw = true

	if toast_remaining > 0.0:
		needs_redraw = true
		_had_toast = true
	elif _had_toast:
		_had_toast = false
		needs_redraw = true

	if hit_remaining > 0.0:
		needs_redraw = true
		_had_hit = true
	elif _had_hit:
		_had_hit = false
		needs_redraw = true

	if stage.stage_state != 0:
		needs_redraw = true

	var cur_shards: int = stage.player.soul_shards if "soul_shards" in stage.player else 0
	var cur_route: String = str(stage.get("route_status")) if stage.get("route_status") != null else ""
	var cur_has_boss_bar: bool = (stage.get_node_or_null("HUD/BossHealthBar") != null)
	var cur_alive := 0
	if stage.encounter_active and "enemies" in stage and stage.enemies != null:
		for enemy in stage.enemies:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.current_hp > 0:
				cur_alive += 1

	if stage.player.current_hp != _last_hp \
	or cur_shards != _last_shards \
	or stage.encounter_index != _last_encounter \
	or stage.checkpoint_index != _last_checkpoint \
	or stage.checkpoint_active != _last_checkpoint_active \
	or stage.stage_state != _last_stage_state \
	or size != _last_size \
	or show_help != _last_show_help \
	or is_paused != _last_paused \
	or cur_has_boss_bar != _last_has_boss_bar \
	or touch_visible != _last_touch_visible \
	or cur_route != _last_route_status \
	or cur_alive != _last_alive_enemies \
	or stage.encounter_active != _last_encounter_active:
		_last_hp = stage.player.current_hp
		_last_shards = cur_shards
		_last_encounter = stage.encounter_index
		_last_checkpoint = stage.checkpoint_index
		_last_checkpoint_active = stage.checkpoint_active
		_last_stage_state = stage.stage_state
		_last_size = size
		_last_show_help = show_help
		_last_paused = is_paused
		_last_has_boss_bar = cur_has_boss_bar
		_last_touch_visible = touch_visible
		_last_route_status = cur_route
		_last_alive_enemies = cur_alive
		_last_encounter_active = stage.encounter_active
		needs_redraw = true

	if needs_redraw:
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
	# High-Resolution Gothic Parchment Scroll Ribbon Texture
	draw_texture_rect(TexBannerScroll, rect, false, Color(1.0, 1.0, 1.0, 0.95))

func _center(at: Vector2, message: String, height: int, color: Color = WHITE) -> void:
	_text(at - Vector2(font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, height).x * 0.5, 0), message, height, color)

func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

func _draw_knight_avatar(at: Vector2) -> void:
	# High-Resolution Gothic Crest Shield & Knight Helmet Texture
	var avatar_size := Vector2(64, 64)
	var avatar_rect := Rect2(at - avatar_size * 0.5, avatar_size)
	var is_low_hp: bool = is_instance_valid(stage) and is_instance_valid(stage.player) and stage.player.current_hp <= 1
	var avatar_modulate := Color(1.3, 0.7, 0.7, 1.0) if is_low_hp else Color(1.0, 1.0, 1.0, 1.0)
	draw_texture_rect(TexAvatarFrame, avatar_rect, false, avatar_modulate)

	# Dynamic Visor Slit Soul Flare
	var visor_col := Color(1.8, 0.3, 0.2, 0.95) if is_low_hp else Color(0.4, 1.2, 1.5, 0.95)
	draw_line(at + Vector2(-9, -1), at + Vector2(9, -1), visor_col, 2.6, true)


func _draw_life_crystal(at: Vector2, full: bool) -> void:
	# High-Resolution 3D Faceted Ruby Soul Gem Texture (Full) or Fractured Obsidian (Empty)
	var gem_tex: Texture2D = TexSoulGemFull if full else TexSoulGemEmpty
	var gem_size := Vector2(38, 38)
	var gem_rect := Rect2(at - gem_size * 0.5, gem_size)
	draw_texture_rect(gem_tex, gem_rect, false)


func _heart(at: Vector2, full: bool) -> void:
	_draw_life_crystal(at, full)


func _draw_combo_hud() -> void:
	if combo_count < 2 or combo_timer <= 0.0:
		return

	var pos := Vector2(1040, 160)
	var alpha := clampf(combo_timer / 0.4, 0.0, 1.0)
	var scale_factor := combo_scale

	# Rank configuration based on hits
	var rank_text := "NICE COMBO!"
	var rank_col := Color(0.35, 0.90, 1.0, alpha)
	var num_col := Color(1.0, 0.95, 0.60, alpha)
	if combo_count >= 15:
		rank_text = "⚡ LEGENDARY CHAMPION! ⚡"
		rank_col = Color(1.4, 0.6, 1.5, alpha)
		num_col = Color(1.4, 0.8, 1.0, alpha)
	elif combo_count >= 10:
		rank_text = "🔥 BERSERK KNIGHT! 🔥"
		rank_col = Color(1.2, 0.35, 0.15, alpha)
		num_col = Color(1.2, 0.6, 0.2, alpha)
	elif combo_count >= 5:
		rank_text = "★ GREAT COMBO! ★"
		rank_col = Color(1.0, 0.85, 0.25, alpha)
		num_col = Color(1.0, 0.85, 0.35, alpha)

	# 1. High-Resolution Third Blade Metallic Slash Frame Texture
	var frame_size := Vector2(220, 80)
	var frame_rect := Rect2(pos - frame_size * 0.5, frame_size)
	draw_texture_rect(TexComboFrame, frame_rect, false, Color(1.1, 1.05, 1.0, alpha))

	# 2. Combo Number & Text with Punch Scale
	var num_str := "%d" % combo_count
	var font_sz := int(38 * scale_factor)
	var num_sz := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
	var text_y := pos.y + 4.0

	# Shadow
	draw_string(font, Vector2(pos.x - 30 - num_sz.x * 0.5 + 2, text_y + 2), num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color(0, 0, 0, 0.85 * alpha))
	draw_string(font, Vector2(pos.x - 30 - num_sz.x * 0.5, text_y), num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, num_col)

	# "HITS!"
	draw_string(font, Vector2(pos.x + 10, text_y - 2), "HITS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 1.0, 1.0, 0.95 * alpha))

	# Rank Subtitle
	draw_string(font, Vector2(pos.x - font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x * 0.5, pos.y + 24), rank_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, rank_col)

	# 3. Combo Duration Progress Bar
	var bar_w := 170.0
	var bar_x := pos.x - bar_w * 0.5
	var bar_y := pos.y + 28.0
	var ratio := clampf(combo_timer / COMBO_TIMEOUT, 0.0, 1.0)
	draw_line(Vector2(bar_x, bar_y), Vector2(bar_x + bar_w, bar_y), Color(0.2, 0.25, 0.3, 0.5 * alpha), 3.0)
	draw_line(Vector2(bar_x, bar_y), Vector2(bar_x + bar_w * ratio, bar_y), Color(rank_col.r, rank_col.g, rank_col.b, 0.95 * alpha), 3.0)


func _draw_parry_banner() -> void:
	if parry_banner_timer <= 0.0:
		return

	var center := Vector2(640, 230)
	var alpha := clampf(parry_banner_timer / 0.5, 0.0, 1.0)
	var anim_t := 1.4 - parry_banner_timer

	# Expanding Shockwave Ring
	var wave_rad := 40.0 + anim_t * 90.0
	draw_arc(center, wave_rad, 0, TAU, 36, Color(1.0, 0.85, 0.2, 0.75 * alpha), 2.5, true)

	# High-Resolution Just Parry Golden Ribbon Banner Texture
	var banner_w := 420.0 * parry_banner_scale
	var banner_h := 80.0 * parry_banner_scale
	var banner_rect := Rect2(center.x - banner_w * 0.5, center.y - banner_h * 0.5, banner_w, banner_h)
	draw_texture_rect(TexParryBanner, banner_rect, false, Color(1.2, 1.15, 0.95, alpha))

	# Golden Emblem Text
	var parry_text := "⚡ PERFECT PARRY BREAK! ⚡"
	var font_sz := int(22 * parry_banner_scale)
	var str_sz := font.get_string_size(parry_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
	draw_string(font, center + Vector2(-str_sz.x * 0.5 + 2, str_sz.y * 0.35 + 2), parry_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color(0, 0, 0, 0.85 * alpha))
	draw_string(font, center + Vector2(-str_sz.x * 0.5, str_sz.y * 0.35), parry_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color(1.2, 1.0, 0.4, alpha))


func _draw() -> void:
	if not initialized or not is_instance_valid(stage):
		return
	draw_set_transform(ui_offset, 0, Vector2.ONE * ui_scale)
	# -------------------------------------------------------------------------
	# In-Game Combat HUD (rendered only during active gameplay)
	# -------------------------------------------------------------------------
	if stage.stage_state == 0 and not get_tree().paused and not show_help:
		draw_texture_rect(hud_shade, Rect2(0, 0, 1280, 185), false)

		var has_boss_bar := (stage.get_node_or_null("HUD/BossHealthBar") != null)

		# 1. Left Zone: Title, Avatar, Life Crystals, Soul Shards, Checkpoint, Traits
		if not has_boss_bar:
			_draw_knight_avatar(Vector2(52, 54))
			_text(Vector2(92, 38), "기사의 여정 · " + stage_label(), 22, GOLD)
			for index in range(3):
				var full: bool = stage.player.current_hp > index
				_heart(Vector2(110 + index * 42, 68), full)
			var shards: int = stage.player.soul_shards if "soul_shards" in stage.player else 0
			_diamond(Vector2(250, 68), 12, Color(0.2, 0.9, 1.0))
			_text(Vector2(270, 76), "%d" % shards, 24, Color(0.35, 0.95, 1.0))
			_draw_relic_bar(Vector2(102, 100))
			if stage.checkpoint_active:
				_diamond(Vector2(42, 128), 8, CYAN)
				_text(Vector2(58, 134), "휴식처 CP%d 저장됨" % (stage.checkpoint_index + 1), 18, CYAN)
			_text(Vector2(38, 148), trait_label(), 16, MUTED)
			_text(Vector2(38, 168), chapter_label(), 16, GOLD)
		else:
			# Compact left zone during boss battle
			_draw_knight_avatar(Vector2(44, 46))
			for index in range(3):
				var full: bool = stage.player.current_hp > index
				_heart(Vector2(96 + index * 40, 48), full)
			var shards: int = stage.player.soul_shards if "soul_shards" in stage.player else 0
			_diamond(Vector2(230, 48), 11, Color(0.2, 0.9, 1.0))
			_text(Vector2(248, 55), "%d" % shards, 22, Color(0.35, 0.95, 1.0))
			_draw_relic_bar(Vector2(102, 80))

		# 2. Center Zone: Encounter Track (Y: 30) & Objective (Y: 74)
		if not has_boss_bar:
			var track_spacing := 48.0
			var start_x: float = 640.0 - float(stage.required_count - 1) * track_spacing * 0.5
			for index in range(stage.required_count):
				var x: float = start_x + index * track_spacing
				if index < stage.required_count - 1:
					draw_line(Vector2(x + 10, 30), Vector2(x + track_spacing - 10, 30), Color(0.7, 0.64, 0.48, 0.40), 2.5)
				var done: bool = stage.completed[index]
				if index == stage.encounter_index:
					draw_circle(Vector2(x, 30), 16, Color(0.85, 0.72, 0.47, 0.22))
					draw_arc(Vector2(x, 30), 16, 0, TAU, 28, GOLD, 2.5, true)
				_diamond(Vector2(x, 30), 9, CYAN if done else GOLD if index == stage.encounter_index else Color("52606b"))

		var next_y: float = 74.0
		if has_boss_bar:
			if stage.encounter_active:
				var hint_text: String = encounter_hint()
				var hw := font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x + 36.0
				_pill(Rect2(640.0 - hw * 0.5, 144.0, hw, 28.0))
				_center(Vector2(640, 163.0), hint_text, 18, Color(1.0, 0.92, 0.78, 0.92))
				next_y = 184.0
			else:
				next_y = 144.0
		else:
			_center(Vector2(640, 74), objective(), 26, WHITE)
			next_y = 106.0
			if stage.encounter_active and stage.encounter_index < stage.required_count:
				_center(Vector2(640, next_y), encounter_hint(), 20, Color(1.0, 0.9, 0.75, 0.85))
				next_y += 32.0
			var in_boss: bool = (stage.encounter_index >= stage.required_count - 1 and stage.encounter_active)
			if not in_boss and stage.get("route_status") != null and str(stage.route_status) != "" and toast_remaining <= 0.0:
				var route_text: String = str(stage.route_status)
				var tw := font.get_string_size(route_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x + 36.0
				_pill(Rect2(640.0 - tw * 0.5, next_y - 16.0, tw, 28.0))
				_center(Vector2(640, next_y + 3.0), route_text, 18, CYAN)
				next_y += 34.0

		if intro_remaining > 0 and not stage.encounter_active:
			_center(Vector2(640, next_y + 12.0), region_intro(), 28, GOLD)
			_center(Vector2(640, next_y + 40.0), region_strategy(), 20, MUTED)
		elif toast_remaining > 0 and not has_boss_bar:
			var toast_w := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x + 44.0
			_pill(Rect2(640.0 - toast_w * 0.5, next_y + 6.0, toast_w, 36.0))
			_center(Vector2(640, next_y + 30.0), toast, 22, GOLD)

		# 3. Third Blade Dynamic Combo & Just Parry Display
		_draw_combo_hud()
		_draw_parry_banner()

		if touch_visible:
			_draw_touch()
		elif not _has_dedicated_mobile_controls():
			_center(Vector2(640, 693), "A/D 이동    Space 점프    J 누르고 연속 공격    K 누르고 막기    H 도움말", 20, MUTED)

		if touch_visible:
			_draw_touch()
		elif not _has_dedicated_mobile_controls():
			_center(Vector2(640, 693), "A/D 이동    Space 점프    J 누르고 연속 공격    K 누르고 막기    H 도움말", 20, MUTED)

		# Top Right: Pause button
		_pill(Rect2(1110, 18, 140, 44))
		_center(Vector2(1180, 47), "Ⅱ  쉬어가기", 22, WHITE)


	if hit_remaining > 0:
		var alpha := hit_remaining / 0.22 * 0.5
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.22, 0.18, alpha), false, 12.0)
	if stage.stage_state != 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.025, 0.04, 0.75))
		var cleared: bool = stage.stage_state == 1
		if cleared:
			_draw_stage_clear_reward_card()
		else:
			var accent := Color("e99589")
			_plate(Rect2(200, 140, 880, 440), accent)
			_center(Vector2(640, 200), stage_label(), 28, accent)
			_center(Vector2(640, 270), "다시 일어설 시간", 54, accent)
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


func _draw_relic_bar(pos: Vector2) -> void:
	var cleared := SaveManagerClass.get_cleared_stages()
	for i in range(5):
		var st_num := i + 1
		var relic: Dictionary = SaveManagerClass.STAGE_RELICS.get(st_num, {})
		var is_unlocked: bool = cleared[i]
		var slot_pos := pos + Vector2(i * 38, 0)
		var base_color: Color = relic.get("icon_color", GOLD) if is_unlocked else Color(0.35, 0.42, 0.48, 0.4)
		
		# Slot background pill / circle
		var bg_color := Color(0.04, 0.08, 0.12, 0.75) if not is_unlocked else Color(0.08, 0.16, 0.22, 0.90)
		draw_circle(slot_pos, 16.0, bg_color)
		draw_arc(slot_pos, 16.0, 0, TAU, 24, base_color, 2.0 if is_unlocked else 1.0, true)
		
		if is_unlocked:
			_draw_relic_icon(slot_pos, st_num, base_color, 0.85)
		else:
			# Locked slot dot indicator
			draw_circle(slot_pos, 3.0, Color(0.4, 0.5, 0.55, 0.6))


func _draw_relic_icon(center: Vector2, st_num: int, color: Color, sz: float = 1.0) -> void:
	match st_num:
		1: # Bastion Shield
			var pts := PackedVector2Array([
				center + Vector2(-8, -10) * sz,
				center + Vector2(8, -10) * sz,
				center + Vector2(10, 2) * sz,
				center + Vector2(0, 12) * sz,
				center + Vector2(-10, 2) * sz
			])
			draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.35))
			draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0 * sz, true)
			# Cross / crest
			draw_line(center + Vector2(0, -6) * sz, center + Vector2(0, 8) * sz, color, 1.8 * sz)
			draw_line(center + Vector2(-5, -1) * sz, center + Vector2(5, -1) * sz, color, 1.8 * sz)

		2: # Shadow Cloak
			var cape_pts := PackedVector2Array([
				center + Vector2(-4, -10) * sz,
				center + Vector2(4, -10) * sz,
				center + Vector2(10, 11) * sz,
				center + Vector2(0, 7) * sz,
				center + Vector2(-10, 11) * sz
			])
			draw_colored_polygon(cape_pts, Color(color.r, color.g, color.b, 0.45))
			draw_polyline(cape_pts + PackedVector2Array([cape_pts[0]]), color, 2.0 * sz, true)
			draw_line(center + Vector2(-6, -10) * sz, center + Vector2(6, -10) * sz, Color.WHITE, 2.0 * sz)

		3: # Piercing Quiver
			var q_pts := PackedVector2Array([
				center + Vector2(-4, -8) * sz,
				center + Vector2(4, -8) * sz,
				center + Vector2(3, 11) * sz,
				center + Vector2(-3, 11) * sz
			])
			draw_colored_polygon(q_pts, Color(color.r, color.g, color.b, 0.35))
			draw_polyline(q_pts + PackedVector2Array([q_pts[0]]), color, 1.8 * sz, true)
			# Arrows
			draw_line(center + Vector2(0, -8) * sz, center + Vector2(0, -14) * sz, color, 2.0 * sz)
			draw_line(center + Vector2(-3, -12) * sz, center + Vector2(0, -14) * sz, color, 1.5 * sz)
			draw_line(center + Vector2(3, -12) * sz, center + Vector2(0, -14) * sz, color, 1.5 * sz)

		4: # Golem Pauldrons
			var paul_pts := PackedVector2Array([
				center + Vector2(-11, -5) * sz,
				center + Vector2(11, -5) * sz,
				center + Vector2(13, 6) * sz,
				center + Vector2(0, 11) * sz,
				center + Vector2(-13, 6) * sz
			])
			draw_colored_polygon(paul_pts, Color(color.r, color.g, color.b, 0.35))
			draw_polyline(paul_pts + PackedVector2Array([paul_pts[0]]), color, 2.0 * sz, true)
			_diamond(center + Vector2(0, 1) * sz, 4.0 * sz, Color(1.0, 0.85, 0.4))

		5: # Abyssal Crown
			var cr_pts := PackedVector2Array([
				center + Vector2(-11, 4) * sz,
				center + Vector2(-10, -5) * sz,
				center + Vector2(-5, 0) * sz,
				center + Vector2(0, -9) * sz,
				center + Vector2(5, 0) * sz,
				center + Vector2(10, -5) * sz,
				center + Vector2(11, 4) * sz
			])
			draw_colored_polygon(cr_pts, Color(color.r, color.g, color.b, 0.4))
			draw_polyline(cr_pts + PackedVector2Array([cr_pts[0]]), color, 2.0 * sz, true)
			draw_arc(center + Vector2(0, -11) * sz, 8.0 * sz, 0, TAU, 16, Color(1.0, 0.7, 1.0), 1.5 * sz, true)


func _draw_stage_clear_reward_card() -> void:
	var relic: Dictionary = SaveManagerClass.STAGE_RELICS.get(stage.stage_number, {})
	var relic_color: Color = relic.get("icon_color", GOLD)
	
	# Modal Backdrop Dimmer (Scrim) to isolate stage clear reward presentation
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.65))

	# Main Outer Container
	_plate(Rect2(140, 75, 1000, 570), GOLD, Color(0.02, 0.05, 0.08, 0.96))
	
	# Corner Filigree Accents (Outer Plate)
	var corn_color := Color(GOLD.r, GOLD.g, GOLD.b, 0.72)
	draw_line(Vector2(146, 96), Vector2(146, 81), corn_color, 2.5)
	draw_line(Vector2(146, 81), Vector2(161, 81), corn_color, 2.5)
	draw_line(Vector2(1134, 96), Vector2(1134, 81), corn_color, 2.5)
	draw_line(Vector2(1134, 81), Vector2(1119, 81), corn_color, 2.5)
	draw_line(Vector2(146, 624), Vector2(146, 639), corn_color, 2.5)
	draw_line(Vector2(146, 639), Vector2(161, 639), corn_color, 2.5)
	draw_line(Vector2(1134, 624), Vector2(1134, 639), corn_color, 2.5)
	draw_line(Vector2(1134, 639), Vector2(1119, 639), corn_color, 2.5)

	# Header
	_center(Vector2(640, 126), "★  " + stage_label() + " 돌파 완료  ★", 38, GOLD)
	_center(Vector2(640, 166), "전설 보스 유물 획득 · 기사 장비 외형 장착 완료!", 24, CYAN)
	
	# Inner Card Frame
	_plate(Rect2(180, 190, 920, 310), relic_color, Color(0.04, 0.09, 0.14, 0.92))
	for corner in [Vector2(188, 198), Vector2(1092, 198), Vector2(188, 492), Vector2(1092, 492)]:
		_diamond(corner, 4.0, relic_color)
	
	# Left: Large Showcase Emblem
	var icon_center := Vector2(320, 335)
	draw_circle(icon_center, 72.0, Color(relic_color.r, relic_color.g, relic_color.b, 0.16))
	draw_arc(icon_center, 72.0, 0, TAU, 48, relic_color, 3.0, true)
	draw_arc(icon_center, 64.0, 0, TAU, 48, Color(1.0, 1.0, 1.0, 0.25), 1.5, true)
	_draw_relic_icon(icon_center, stage.stage_number, relic_color, 3.6)
	
	# Rarity Badge
	var rarity_text: String = relic.get("rarity", "전설 유물")
	var badge_w := font.get_string_size(rarity_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x + 36.0
	_pill(Rect2(icon_center.x - badge_w * 0.5, 435, badge_w, 36.0))
	_center(Vector2(icon_center.x, 460), rarity_text, 20, relic_color)
	
	# Right: Detailed Info Section
	var text_x := 440.0
	var relic_name: String = relic.get("name", "고대 사령관의 유물")
	_text(Vector2(text_x, 245), relic_name, 34, GOLD)
	
	# Ability / Effect
	_text(Vector2(text_x, 292), "▶ 유물 고유 지속 효과", 22, CYAN)
	_text(Vector2(text_x + 20, 326), relic.get("desc", ""), 22, WHITE)
	
	# Visual Equipment Transformation
	_text(Vector2(text_x, 376), "▶ 캐릭터 장비 외형 변화", 22, Color(1.0, 0.75, 0.35))
	_text(Vector2(text_x + 20, 410), relic.get("visual_name", "새로운 장비 외형 장착"), 22, WHITE)
	_text(Vector2(text_x + 20, 442), "인게임 플레이 및 대기 모션 시 캐릭터 모델에 실시간 반영됩니다.", 19, MUTED)
	
	# Bottom Status / Navigation
	var finished_count: int = stage.required_count if stage.stage_state == 1 else stage.encounter_index
	_center(Vector2(640, 545), "필수 전투 %d / %d 완료 · 영구 세이브 저장됨" % [finished_count, stage.required_count], 22, MUTED)
	_center(Vector2(640, 595), transition_message(), 26, CYAN)

