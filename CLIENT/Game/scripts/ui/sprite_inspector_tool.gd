class_name SpriteInspectorTool
extends Control
## Project Knight — 캐릭터·몬스터·보스 스프라이트 정밀 검증 스튜디오 (Sprite Inspector Studio)
## 주요 기능:
## 1. 카테고리별 에셋 브라우저 (플레이어 액션 8종 / 진화 일러스트 6종 / 일반 몬스터 4종 / 보스 시트 10종)
## 2. 실시간 애니메이션 프리뷰 캔버스:
##    - 체커보드 / 다크 아레나 배경 전환
##    - 발끝 베이스라인(Foot Baseline) & 피봇 십자선(Pivot Crosshair) 오버레이
##    - 셀 경계(Cell Rect) & 실제 픽셀 바운딩 박스(Used Rect) 실시간 표시
##    - 어니언 스킨(Onion Skin: 이전 프레임 반투명 잔상 비교) 및 좌우 반전(Flip H), 줌(0.5x ~ 2.0x)
## 3. 전체 스프라이트 시트 그리드 뷰어:
##    - Cols x Rows 분할 격자, 프레임 번호(F0..Fn), 셀 클릭 시 즉시 해당 프레임 점프
## 4. 픽셀 단위 자동 무결성 진단 패널:
##    - 셀 경계 침범(Border Bleed) 여부, 상하좌우 여백(Margin), 프레임별 발끝 Y좌표 편차 자동 계산

signal inspector_closed

const SPRITE_CATALOG: Array[Dictionary] = [
	# --- 1. 플레이어 액션 시트 (8종) ---
	{
		"id": "player_idle",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 대기 호흡 (Idle)",
		"path": "res://assets/player_frames/idle_v1_aligned.png",
		"cols": 2, "rows": 2, "frames": 4, "fps": 8.0,
		"pivot": Vector2(390, 700),
		"desc": "기본 전투 대기 모션 (780×780 정규화 셀)"
	},
	{
		"id": "player_run",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 전술 질주 (Run)",
		"path": "res://assets/player_frames/run_v2_aligned.png",
		"cols": 3, "rows": 2, "frames": 6, "fps": 12.0,
		"pivot": Vector2(390, 700),
		"desc": "6프레임 달리기 사이클 (780×780 정규화 셀)"
	},
	{
		"id": "player_attack",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 3단 콤보 검격 (Attack)",
		"path": "res://assets/player_frames/attack_v1_aligned.png",
		"cols": 2, "rows": 2, "frames": 4, "fps": 10.0,
		"pivot": Vector2(390, 700),
		"desc": "1타 횡베기 · 2타 올려베기 · 3타 내려찍기 · 강공격"
	},
	{
		"id": "player_guard",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 방패 방어 & 패링 (Guard)",
		"path": "res://assets/player_frames/guard_v1_aligned.png",
		"cols": 3, "rows": 1, "frames": 3, "fps": 8.0,
		"pivot": Vector2(390, 700),
		"desc": "이지스 방패 전개 · 블록 유지 · 저스트 패링 카운터"
	},
	{
		"id": "player_jump",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 도약 및 체공 (Jump)",
		"path": "res://assets/player_frames/jump_v1.png",
		"cols": 3, "rows": 1, "frames": 3, "fps": 6.0,
		"pivot": Vector2(390, 700),
		"desc": "도약 상승 · 체공 정점 · 낙하 착지 모션"
	},
	{
		"id": "player_dodge",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 무적 회피 대시 (Dodge)",
		"path": "res://assets/player_frames/dodge_v1.png",
		"cols": 2, "rows": 2, "frames": 4, "fps": 12.0,
		"pivot": Vector2(390, 700),
		"desc": "전방 돌진 회피 및 자세 복귀 4프레임"
	},
	{
		"id": "player_hurt",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 피격 경직 (Hurt)",
		"path": "res://assets/player_frames/hurt_v1.png",
		"cols": 3, "rows": 1, "frames": 3, "fps": 8.0,
		"pivot": Vector2(390, 700),
		"desc": "피격 충격 및 자세 회복 3프레임"
	},
	{
		"id": "player_death",
		"category": "PLAYER_ACTION",
		"title": "성기사 — 전사 쓰러짐 (Death)",
		"path": "res://assets/player_frames/death_v1.png",
		"cols": 2, "rows": 2, "frames": 4, "fps": 6.0,
		"pivot": Vector2(390, 700),
		"desc": "체력 소진 시 무릎 꿇기 및 쓰러짐 연출"
	},

	# --- 2. 플레이어 스테이지 진화 일러스트 (6종) ---
	{
		"id": "evo_base",
		"category": "PLAYER_EVO",
		"title": "진화 0단계 — 기본 성기사 (Base Knight)",
		"path": "res://assets/player/knight_idle_v1.png",
		"cols": 1, "rows": 1, "frames": 1, "fps": 1.0,
		"pivot": Vector2(627, 1163),
		"desc": "2D 클래식 모드 기본 전신 스탠딩 아트워크"
	},
	{
		"id": "evo_stage1",
		"category": "PLAYER_EVO",
		"title": "진화 1단계 — 성소 팔라딘 (Stage 1 Paladin)",
		"path": "res://assets/player/knight_stage1_paladin.png",
		"cols": 1, "rows": 1, "frames": 1, "fps": 1.0,
		"pivot": Vector2(627, 1163),
		"desc": "1스테이지 외형 진화 일러스트"
	},
	{
		"id": "evo_stage2",
		"category": "PLAYER_EVO",
		"title": "진화 2단계 — 윈드러너 (Stage 2 Windrunner)",
		"path": "res://assets/player/knight_stage2_windrunner.png",
		"cols": 1, "rows": 1, "frames": 1, "fps": 1.0,
		"pivot": Vector2(627, 1163),
		"desc": "2스테이지 외형 진화 일러스트"
	},
	{
		"id": "evo_stage3",
		"category": "PLAYER_EVO",
		"title": "진화 3단계 — 아케인 마검사 (Stage 3 Arcane)",
		"path": "res://assets/player/knight_stage3_arcane.png",
		"cols": 1, "rows": 1, "frames": 1, "fps": 1.0,
		"pivot": Vector2(627, 1163),
		"desc": "3스테이지 외형 진화 일러스트"
	},
	{
		"id": "evo_stage4",
		"category": "PLAYER_EVO",
		"title": "진화 4단계 — 티탄 중갑기사 (Stage 4 Titan)",
		"path": "res://assets/player/knight_stage4_titan.png",
		"cols": 1, "rows": 1, "frames": 1, "fps": 1.0,
		"pivot": Vector2(627, 1163),
		"desc": "4스테이지 외형 진화 일러스트"
	},
	{
		"id": "evo_stage5",
		"category": "PLAYER_EVO",
		"title": "진화 5단계 — 심연 정복자 (Stage 5 Abyssal)",
		"path": "res://assets/player/knight_stage5_abyssal.png",
		"cols": 1, "rows": 1, "frames": 1, "fps": 1.0,
		"pivot": Vector2(627, 1163),
		"desc": "5스테이지 최종 외형 진화 일러스트"
	},

	# --- 3. 일반 몬스터 스프라이트 시트 (4종) ---
	{
		"id": "minion_melee",
		"category": "ENEMY_MINION",
		"title": "일반 몬스터 — 타락한 보병 (Melee Minion)",
		"path": "res://assets/enemy_frames/melee_v1.png",
		"cols": 3, "rows": 2, "frames": 6, "fps": 10.0,
		"pivot": Vector2(256, 490),
		"desc": "512×512 셀 정규화 · 보행(F0~F2) 및 근접 베기(F3~F5)"
	},
	{
		"id": "minion_ranged",
		"category": "ENEMY_MINION",
		"title": "일반 몬스터 — 중갑 석궁병 (Ranged Minion)",
		"path": "res://assets/enemy_frames/ranged_v1.png",
		"cols": 3, "rows": 2, "frames": 6, "fps": 10.0,
		"pivot": Vector2(256, 490),
		"desc": "512×512 셀 정규화 · 기동(F0~F2) 및 석궁 조준 발사(F3~F5)"
	},
	{
		"id": "minion_beast",
		"category": "ENEMY_MINION",
		"title": "일반 몬스터 — 그림자 야수 (Shadow Beast)",
		"path": "res://assets/enemy_frames/beast_v2.png",
		"cols": 3, "rows": 2, "frames": 6, "fps": 12.0,
		"pivot": Vector2(256, 490),
		"desc": "512×512 셀 정규화 · 질주(F0~F2) 및 도약 물어뜯기(F3~F5)"
	},
	{
		"id": "minion_golem",
		"category": "ENEMY_MINION",
		"title": "일반 몬스터 — 고대 바위 골렘 (Golem Minion)",
		"path": "res://assets/enemy_frames/golem_v1.png",
		"cols": 3, "rows": 2, "frames": 6, "fps": 8.0,
		"pivot": Vector2(256, 490),
		"desc": "512×512 셀 정규화 · 중량 보행(F0~F2) 및 내려찍기(F3~F5)"
	},

	# --- 4. 보스 메인 & 스킬 스프라이트 시트 (10종) ---
	{
		"id": "boss1_main",
		"category": "BOSS",
		"title": "Stage 1 보스 — 성소 수호자 (Main)",
		"path": "res://assets/enemy_frames/boss_commander_v2.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 8.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 대기/전진/대검 베기 메인 모션"
	},
	{
		"id": "boss1_def",
		"category": "BOSS",
		"title": "Stage 1 보스 — 성소 수호자 (Defense/Stun)",
		"path": "res://assets/enemy_frames/boss_commander_v2_defense.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 8.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 방패 가드, 반격, 그로기 경직 모션"
	},
	{
		"id": "boss2_main",
		"category": "BOSS",
		"title": "Stage 2 보스 — 야수 군주 (Main)",
		"path": "res://assets/enemy_frames/beast_chieftain_v2.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 10.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 야수 군주 추적 및 연속 할퀴기 모션"
	},
	{
		"id": "boss2_skills",
		"category": "BOSS",
		"title": "Stage 2 보스 — 야수 군주 (Skills/Roar)",
		"path": "res://assets/enemy_frames/beast_chieftain_v2_skills.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 10.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 광폭화 포효, 급습 덮치기, 그로기 모션"
	},
	{
		"id": "boss3_main",
		"category": "BOSS",
		"title": "Stage 3 보스 — 석궁 사령관 (Main)",
		"path": "res://assets/enemy_frames/crossbow_cmd_v2.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 9.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 기동 사격 및 3연발 연사 모션"
	},
	{
		"id": "boss3_skills",
		"category": "BOSS",
		"title": "Stage 3 보스 — 석궁 사령관 (Skills/Rain)",
		"path": "res://assets/enemy_frames/crossbow_cmd_v2_skills.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 9.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 강철 화살비 폭격, 후방 도약, 그로기 모션"
	},
	{
		"id": "boss4_main",
		"category": "BOSS",
		"title": "Stage 4 보스 — 고대 골렘 수호자 (Main)",
		"path": "res://assets/enemy_frames/golem_guardian_v2.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 7.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 거대 암석 보행 및 주먹 강타 모션"
	},
	{
		"id": "boss4_skills",
		"category": "BOSS",
		"title": "Stage 4 보스 — 고대 골렘 수호자 (Skills/Slam)",
		"path": "res://assets/enemy_frames/golem_guardian_v2_skills.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 7.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 대지 분쇄 충격파, 바위 보호막, 그로기 모션"
	},
	{
		"id": "boss5_main",
		"category": "BOSS",
		"title": "Stage 5 보스 — 심연의 재판관 (Main)",
		"path": "res://assets/enemy_frames/abyssal_arbiter_v2.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 9.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 심연의 낫 연속 베기 및 부유 이동 모션"
	},
	{
		"id": "boss5_skills",
		"category": "BOSS",
		"title": "Stage 5 보스 — 심연의 재판관 (Skills/Nova)",
		"path": "res://assets/enemy_frames/abyssal_arbiter_v2_skills.png",
		"cols": 4, "rows": 3, "frames": 12, "fps": 9.0,
		"pivot": Vector2(150, 285),
		"desc": "300×298 셀 (4×3) · 공간 베기, 보이드 노바 폭발, 그로기 모션"
	},
]

# State Variables
var current_category: String = "ALL"
var selected_entry: Dictionary = {}
var current_texture: Texture2D = null
var current_image: Image = null
var frame_metrics: Array[Dictionary] = []

var is_playing: bool = true
var current_frame: int = 0
var anim_fps: float = 8.0
var _anim_accum: float = 0.0

var show_checkerboard: bool = true
var show_pivot_baseline: bool = true
var show_bounding_box: bool = true
var show_onion_skin: bool = false
var flip_h: bool = false
var preview_zoom: float = 1.0

# UI References
var _cat_buttons: Dictionary = {}
var _asset_list_vbox: VBoxContainer
var _asset_buttons: Dictionary = {}
var _preview_canvas: _PreviewCanvas
var _sheet_canvas: _SheetGridCanvas
var _play_btn: Button
var _frame_label: Label
var _fps_slider: HSlider
var _fps_label: Label
var _zoom_label: Label
var _frame_strip_hbox: HBoxContainer
var _diag_title_lbl: Label
var _diag_path_lbl: Label
var _diag_sheet_lbl: Label
var _diag_frame_lbl: Label
var _diag_status_badge: Label
var _summary_banner_lbl: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_select_category("ALL")
	if not SPRITE_CATALOG.is_empty():
		select_sprite_by_id(SPRITE_CATALOG[0]["id"])


func _process(delta: float) -> void:
	if not is_playing or selected_entry.is_empty():
		return
	var total_frames: int = maxi(1, int(selected_entry.get("frames", 1)))
	if total_frames <= 1 or anim_fps <= 0.0:
		return
	_anim_accum += delta
	var frame_dur: float = 1.0 / anim_fps
	if _anim_accum >= frame_dur:
		_anim_accum = fmod(_anim_accum, frame_dur)
		set_frame((current_frame + 1) % total_frames)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_on_close_pressed()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_toggle_play()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				is_playing = false
				_update_play_button()
				var total := maxi(1, int(selected_entry.get("frames", 1)))
				set_frame((current_frame - 1 + total) % total)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				is_playing = false
				_update_play_button()
				var total := maxi(1, int(selected_entry.get("frames", 1)))
				set_frame((current_frame + 1) % total)
				get_viewport().set_input_as_handled()


# ==============================================================================
# PUBLIC API (For Automated Tests & Direct Invocation)
# ==============================================================================

func get_catalog_size() -> int:
	return SPRITE_CATALOG.size()


func select_sprite_by_id(sprite_id: String) -> bool:
	for entry in SPRITE_CATALOG:
		if entry["id"] == sprite_id:
			_load_sprite_entry(entry)
			return true
	return false


func set_frame(frame_idx: int) -> void:
	var total: int = maxi(1, int(selected_entry.get("frames", 1)))
	current_frame = clampi(frame_idx, 0, total - 1)
	_update_frame_ui()
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()
	if _sheet_canvas != null:
		_sheet_canvas.queue_redraw()


func get_current_sheet_bleed_count() -> int:
	var count: int = 0
	for m in frame_metrics:
		if bool(m.get("has_bleed", false)):
			count += 1
	return count


# ==============================================================================
# UI CONSTRUCTION
# ==============================================================================

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("070b11")
	add_child(bg)

	var top_accent := ColorRect.new()
	top_accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_accent.custom_minimum_size = Vector2(0, 4)
	top_accent.color = Color("00e5ff")
	add_child(top_accent)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# --- 1. HEADER BAR ---
	var header_panel := _create_panel(Color("0f1722"), Color("00e5ff"), 2)
	header_panel.custom_minimum_size = Vector2(0, 50)
	root_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_panel.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎨 CHARACTER & BOSS SPRITE INSPECTOR STUDIO (스프라이트 정밀 검증 툴)"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color("ffb800"))
	header_hbox.add_child(title_lbl)

	_summary_banner_lbl = Label.new()
	_summary_banner_lbl.text = "총 28종 스프라이트 시트 로드 가능  |  Space: 재생/일시정지  ·  ◀/▶: 프레임 이동"
	_summary_banner_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary_banner_lbl.add_theme_font_size_override("font_size", 13)
	_summary_banner_lbl.add_theme_color_override("font_color", Color("94a3b8"))
	header_hbox.add_child(_summary_banner_lbl)

	var close_btn := _create_button("✕ 닫기 (ESC)", _on_close_pressed, Color("3b1219"), Color("ff3b5c"), 120, 34)
	header_hbox.add_child(close_btn)

	# --- 2. CATEGORY FILTER ROW ---
	var cat_hbox := HBoxContainer.new()
	cat_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(cat_hbox)

	var categories := [
		["ALL", "전체 보기 (28)"],
		["PLAYER_ACTION", "⚔ 플레이어 액션 시트 (8)"],
		["PLAYER_EVO", "👑 플레이어 진화 일러스트 (6)"],
		["ENEMY_MINION", "👾 일반 몬스터 시트 (4)"],
		["BOSS", "💀 보스 메인 & 스킬 시트 (10)"],
	]
	for cat in categories:
		var cid: String = cat[0]
		var ctitle: String = cat[1]
		var btn := _create_button(ctitle, func(): _select_category(cid), Color("111b27"), Color("334155"), 0, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat_hbox.add_child(btn)
		_cat_buttons[cid] = btn

	# --- 3. MAIN 3-COLUMN WORKSPACE ---
	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(main_hbox)

	# [LEFT COLUMN] Asset List Browser
	var left_panel := _create_panel(Color("0b121b"), Color("1e293b"), 1)
	left_panel.custom_minimum_size = Vector2(285, 0)
	main_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_vbox)

	var list_header := Label.new()
	list_header.text = "◢ 스프라이트 목록 (ASSET LIST)"
	list_header.add_theme_font_size_override("font_size", 14)
	list_header.add_theme_color_override("font_color", Color("00e5ff"))
	left_vbox.add_child(list_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_asset_list_vbox = VBoxContainer.new()
	_asset_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_list_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(_asset_list_vbox)

	# [CENTER COLUMN] Dual Viewport (Live Animation Preview + Full Sheet Grid) + Controls
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_stretch_ratio = 2.2
	center_vbox.add_theme_constant_override("separation", 8)
	main_hbox.add_child(center_vbox)

	# Overlay Toggle Toolbar
	var toolbar_panel := _create_panel(Color("0d1622"), Color("1e293b"), 1)
	center_vbox.add_child(toolbar_panel)

	var toolbar_hbox := HBoxContainer.new()
	toolbar_hbox.add_theme_constant_override("separation", 8)
	toolbar_panel.add_child(toolbar_hbox)

	toolbar_hbox.add_child(_create_toggle_button("🏁 체커보드 배경", show_checkerboard, func(v: bool):
		show_checkerboard = v
		_preview_canvas.queue_redraw()
		_sheet_canvas.queue_redraw()
	))
	toolbar_hbox.add_child(_create_toggle_button("🎯 피봇 & 발끝 기준선", show_pivot_baseline, func(v: bool):
		show_pivot_baseline = v
		_preview_canvas.queue_redraw()
		_sheet_canvas.queue_redraw()
	))
	toolbar_hbox.add_child(_create_toggle_button("📐 픽셀 바운딩 박스", show_bounding_box, func(v: bool):
		show_bounding_box = v
		_preview_canvas.queue_redraw()
	))
	toolbar_hbox.add_child(_create_toggle_button("👻 어니언 스킨 (잔상 비교)", show_onion_skin, func(v: bool):
		show_onion_skin = v
		_preview_canvas.queue_redraw()
	))
	toolbar_hbox.add_child(_create_toggle_button("↔ 좌우 반전 (Flip H)", flip_h, func(v: bool):
		flip_h = v
		_preview_canvas.queue_redraw()
	))

	var zoom_out_btn := _create_button("🔍-", func(): _change_zoom(-0.25), Color("162231"), Color("38bdf8"), 42, 30)
	toolbar_hbox.add_child(zoom_out_btn)

	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	_zoom_label.custom_minimum_size = Vector2(48, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.add_theme_font_size_override("font_size", 13)
	_zoom_label.add_theme_color_override("font_color", Color("ffb800"))
	toolbar_hbox.add_child(_zoom_label)

	var zoom_in_btn := _create_button("🔍+", func(): _change_zoom(0.25), Color("162231"), Color("38bdf8"), 42, 30)
	toolbar_hbox.add_child(zoom_in_btn)

	# Dual Canvas Area (Left: Live Frame Preview / Right: Full Sheet Atlas Grid)
	var canvases_hbox := HBoxContainer.new()
	canvases_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvases_hbox.add_theme_constant_override("separation", 10)
	center_vbox.add_child(canvases_hbox)

	var preview_frame := _create_panel(Color("090f17"), Color("00e5ff"), 1)
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_stretch_ratio = 1.05
	canvases_hbox.add_child(preview_frame)

	_preview_canvas = _PreviewCanvas.new(self)
	_preview_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_frame.add_child(_preview_canvas)

	var sheet_frame := _create_panel(Color("090f17"), Color("ffb800"), 1)
	sheet_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_frame.size_flags_stretch_ratio = 1.05
	canvases_hbox.add_child(sheet_frame)

	_sheet_canvas = _SheetGridCanvas.new(self)
	_sheet_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet_frame.add_child(_sheet_canvas)

	# Playback & Timeline Bar
	var playback_panel := _create_panel(Color("0d1622"), Color("1e293b"), 1)
	center_vbox.add_child(playback_panel)

	var playback_vbox := VBoxContainer.new()
	playback_vbox.add_theme_constant_override("separation", 6)
	playback_panel.add_child(playback_vbox)

	var ctrl_hbox := HBoxContainer.new()
	ctrl_hbox.add_theme_constant_override("separation", 8)
	playback_vbox.add_child(ctrl_hbox)

	var prev_btn := _create_button("⏮ 이전", func():
		is_playing = false
		_update_play_button()
		var total := maxi(1, int(selected_entry.get("frames", 1)))
		set_frame((current_frame - 1 + total) % total)
	, Color("142030"), Color("64748b"), 72, 32)
	ctrl_hbox.add_child(prev_btn)

	_play_btn = _create_button("⏸ 일시정지", _toggle_play, Color("133028"), Color("34d399"), 105, 32)
	ctrl_hbox.add_child(_play_btn)

	var next_btn := _create_button("다음 ⏭", func():
		is_playing = false
		_update_play_button()
		var total := maxi(1, int(selected_entry.get("frames", 1)))
		set_frame((current_frame + 1) % total)
	, Color("142030"), Color("64748b"), 72, 32)
	ctrl_hbox.add_child(next_btn)

	_frame_label = Label.new()
	_frame_label.text = "Frame: 0 / 0"
	_frame_label.custom_minimum_size = Vector2(105, 0)
	_frame_label.add_theme_font_size_override("font_size", 14)
	_frame_label.add_theme_color_override("font_color", Color("ffb800"))
	ctrl_hbox.add_child(_frame_label)

	var fps_title := Label.new()
	fps_title.text = "속도(FPS):"
	fps_title.add_theme_font_size_override("font_size", 13)
	ctrl_hbox.add_child(fps_title)

	_fps_slider = HSlider.new()
	_fps_slider.min_value = 1.0
	_fps_slider.max_value = 24.0
	_fps_slider.step = 1.0
	_fps_slider.value = 8.0
	_fps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fps_slider.value_changed.connect(func(v: float):
		anim_fps = v
		_fps_label.text = "%d FPS" % int(v)
	)
	ctrl_hbox.add_child(_fps_slider)

	_fps_label = Label.new()
	_fps_label.text = "8 FPS"
	_fps_label.custom_minimum_size = Vector2(58, 0)
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color("00e5ff"))
	ctrl_hbox.add_child(_fps_label)

	# Frame Quick-Select Strip
	_frame_strip_hbox = HBoxContainer.new()
	_frame_strip_hbox.add_theme_constant_override("separation", 4)
	playback_vbox.add_child(_frame_strip_hbox)

	# [RIGHT COLUMN] Automated Diagnostics & Pixel Metrics Panel
	var right_panel := _create_panel(Color("0b121b"), Color("1e293b"), 1)
	right_panel.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	var diag_head := Label.new()
	diag_head.text = "◢ 픽셀 무결성 진단 (DIAGNOSTICS)"
	diag_head.add_theme_font_size_override("font_size", 14)
	diag_head.add_theme_color_override("font_color", Color("ffb800"))
	right_vbox.add_child(diag_head)

	_diag_title_lbl = Label.new()
	_diag_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag_title_lbl.add_theme_font_size_override("font_size", 15)
	_diag_title_lbl.add_theme_color_override("font_color", Color("f8fafc"))
	right_vbox.add_child(_diag_title_lbl)

	_diag_path_lbl = Label.new()
	_diag_path_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_diag_path_lbl.add_theme_font_size_override("font_size", 11)
	_diag_path_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	right_vbox.add_child(_diag_path_lbl)

	_diag_status_badge = Label.new()
	_diag_status_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag_status_badge.add_theme_font_size_override("font_size", 13)
	_diag_status_badge.add_theme_color_override("font_color", Color("34d399"))
	right_vbox.add_child(_diag_status_badge)

	var sep1 := HSeparator.new()
	right_vbox.add_child(sep1)

	_diag_sheet_lbl = Label.new()
	_diag_sheet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag_sheet_lbl.add_theme_font_size_override("font_size", 12)
	_diag_sheet_lbl.add_theme_color_override("font_color", Color("cbd5e1"))
	right_vbox.add_child(_diag_sheet_lbl)

	var sep2 := HSeparator.new()
	right_vbox.add_child(sep2)

	_diag_frame_lbl = Label.new()
	_diag_frame_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diag_frame_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag_frame_lbl.add_theme_font_size_override("font_size", 12)
	_diag_frame_lbl.add_theme_color_override("font_color", Color("e2e8f0"))
	right_vbox.add_child(_diag_frame_lbl)


# ==============================================================================
# ASSET LOADING & PIXEL AUDIT LOGIC
# ==============================================================================

func _select_category(cat_id: String) -> void:
	current_category = cat_id
	for cid in _cat_buttons:
		var btn: Button = _cat_buttons[cid]
		btn.modulate = Color(1.2, 1.2, 1.2) if cid == cat_id else Color(0.85, 0.85, 0.85)

	for child in _asset_list_vbox.get_children():
		child.queue_free()
	_asset_buttons.clear()

	for entry in SPRITE_CATALOG:
		if cat_id != "ALL" and entry["category"] != cat_id:
			continue
		var sid: String = entry["id"]
		var btn := _create_button(entry["title"], func(): _load_sprite_entry(entry), Color("101926"), Color("334155"), 0, 34)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_asset_list_vbox.add_child(btn)
		_asset_buttons[sid] = btn


func _load_sprite_entry(entry: Dictionary) -> void:
	selected_entry = entry
	var res_path: String = entry["path"]
	current_texture = load(res_path) as Texture2D

	var global_path := ProjectSettings.globalize_path(res_path)
	current_image = Image.load_from_file(global_path)
	if current_image == null and current_texture != null:
		current_image = current_texture.get_image()

	anim_fps = float(entry.get("fps", 8.0))
	if _fps_slider != null:
		_fps_slider.value = anim_fps
	if _fps_label != null:
		_fps_label.text = "%d FPS" % int(anim_fps)

	_compute_sheet_metrics()
	_rebuild_frame_strip()
	set_frame(0)

	for sid in _asset_buttons:
		var b: Button = _asset_buttons[sid]
		b.modulate = Color("ffb800") if sid == entry["id"] else Color.WHITE


func _compute_sheet_metrics() -> void:
	frame_metrics.clear()
	if current_image == null:
		return

	var cols: int = maxi(1, int(selected_entry.get("cols", 1)))
	var rows: int = maxi(1, int(selected_entry.get("rows", 1)))
	var total: int = maxi(1, int(selected_entry.get("frames", cols * rows)))
	var cw: int = current_image.get_width() / cols
	var ch: int = current_image.get_height() / rows

	for idx in range(total):
		var c: int = idx % cols
		var r: int = idx / cols
		var cell_rect := Rect2i(c * cw, r * ch, cw, ch)
		var cell_img := current_image.get_region(cell_rect)
		var used := cell_img.get_used_rect()

		var left_m: int = used.position.x
		var top_m: int = used.position.y
		var right_m: int = cw - (used.position.x + used.size.x)
		var bot_m: int = ch - (used.position.y + used.size.y)
		var foot_y: int = used.position.y + used.size.y
		var has_bleed: bool = (cols * rows > 1) and (left_m <= 0 or top_m <= 0 or right_m <= 0 or bot_m <= 0)

		frame_metrics.append({
			"index": idx,
			"col": c,
			"row": r,
			"cell_w": cw,
			"cell_h": ch,
			"used_rect": used,
			"left_margin": left_m,
			"right_margin": right_m,
			"top_margin": top_m,
			"bottom_margin": bot_m,
			"foot_y": foot_y,
			"has_bleed": has_bleed,
		})


func _rebuild_frame_strip() -> void:
	if _frame_strip_hbox == null:
		return
	for child in _frame_strip_hbox.get_children():
		child.queue_free()

	var total: int = maxi(1, int(selected_entry.get("frames", 1)))
	for i in range(total):
		var f_idx := i
		var has_bleed := false
		if f_idx < frame_metrics.size():
			has_bleed = bool(frame_metrics[f_idx].get("has_bleed", false))
		var border_col := Color("ff3b5c") if has_bleed else Color("38bdf8")
		var btn := _create_button("F%d" % f_idx, func():
			is_playing = false
			_update_play_button()
			set_frame(f_idx)
		, Color("111b27"), border_col, 38, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_frame_strip_hbox.add_child(btn)


func _update_frame_ui() -> void:
	var total: int = maxi(1, int(selected_entry.get("frames", 1)))
	if _frame_label != null:
		_frame_label.text = "Frame: %d / %d" % [current_frame + 1, total]

	if _frame_strip_hbox != null:
		for i in range(_frame_strip_hbox.get_child_count()):
			var b := _frame_strip_hbox.get_child(i) as Button
			if b != null:
				b.modulate = Color("ffb800") if i == current_frame else Color.WHITE

	if _diag_title_lbl == null or selected_entry.is_empty():
		return

	_diag_title_lbl.text = selected_entry.get("title", "")
	_diag_path_lbl.text = "%s\n(%s)" % [selected_entry.get("path", ""), selected_entry.get("desc", "")]

	var cols: int = maxi(1, int(selected_entry.get("cols", 1)))
	var rows: int = maxi(1, int(selected_entry.get("rows", 1)))
	var pivot: Vector2 = selected_entry.get("pivot", Vector2.ZERO)
	var tex_w: int = current_image.get_width() if current_image else 0
	var tex_h: int = current_image.get_height() if current_image else 0
	var cw: int = tex_w / cols if cols > 0 else 0
	var ch: int = tex_h / rows if rows > 0 else 0

	var bleed_count := get_current_sheet_bleed_count()
	var min_foot: int = 99999
	var max_foot: int = -99999
	for m in frame_metrics:
		var fy: int = int(m.get("foot_y", 0))
		min_foot = mini(min_foot, fy)
		max_foot = maxi(max_foot, fy)
	var foot_spread: int = maxi(0, max_foot - min_foot)

	if bleed_count == 0:
		_diag_status_badge.text = "✅ 무결성 검증 통과: 셀 경계 침범 0건  |  발끝 편차 %dpx" % foot_spread
		_diag_status_badge.add_theme_color_override("font_color", Color("34d399"))
	else:
		_diag_status_badge.text = "⚠ 셀 경계 침범 감지: %d개 프레임" % bleed_count
		_diag_status_badge.add_theme_color_override("font_color", Color("ff3b5c"))

	_diag_sheet_lbl.text = (
		"• 시트 해상도: %d × %d px\n" % [tex_w, tex_h] +
		"• 그리드 규격: %d열 × %d행 (총 %d프레임)\n" % [cols, rows, total] +
		"• 단일 셀 크기: %d × %d px\n" % [cw, ch] +
		"• 기준 피봇(Pivot): (%.0f, %.0f)\n" % [pivot.x, pivot.y] +
		"• 시트 전체 발끝 Y 범위: %d ~ %d px" % [min_foot, max_foot]
	)

	if current_frame < frame_metrics.size():
		var fm: Dictionary = frame_metrics[current_frame]
		var used: Rect2i = fm["used_rect"]
		var foot_y: int = int(fm["foot_y"])
		var delta_pivot_y: int = foot_y - int(pivot.y)
		_diag_frame_lbl.text = (
			"[현재 프레임 F%d (열 %d, 행 %d) 상세 분석]\n" % [current_frame, fm["col"], fm["row"]] +
			"• 실제 픽셀 영역(Used Rect):\n  X=%d, Y=%d  |  W=%d × H=%d px\n" % [used.position.x, used.position.y, used.size.x, used.size.y] +
			"• 캐릭터 발끝(Foot Y): %d px (피봇 대비 %+d px)\n" % [foot_y, delta_pivot_y] +
			"• 셀 테두리 여유 마진(Margin):\n  좌 %dpx | 우 %dpx | 상 %dpx | 하 %dpx\n" % [fm["left_margin"], fm["right_margin"], fm["top_margin"], fm["bottom_margin"]] +
			"• 경계 침범 판정: %s" % ("⚠ 침범 있음 (BLEED)" if fm["has_bleed"] else "✅ 정상 (SAFE)")
		)


func _toggle_play() -> void:
	is_playing = not is_playing
	_update_play_button()


func _update_play_button() -> void:
	if _play_btn != null:
		_play_btn.text = "⏸ 일시정지" if is_playing else "▶ 재생"


func _change_zoom(delta_z: float) -> void:
	preview_zoom = clampf(preview_zoom + delta_z, 0.5, 2.5)
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % int(round(preview_zoom * 100.0))
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()


func _on_close_pressed() -> void:
	inspector_closed.emit()
	if get_tree().current_scene == self:
		if ResourceLoader.exists("res://scenes/ui/TitleScreen.tscn"):
			get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
		else:
			get_tree().quit()
	else:
		queue_free()


# ==============================================================================
# UI HELPERS
# ==============================================================================

func _create_panel(bg_col: Color, border_col: Color, border_w: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(border_w)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	return p


func _create_button(txt: String, cb: Callable, bg_col: Color, border_col: Color, min_w: float, min_h: float) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(min_w, min_h)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color("f8fafc"))

	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.corner_radius_top_right = 5
	s.corner_radius_bottom_left = 5
	s.content_margin_left = 8
	s.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", s)

	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = bg_col.lightened(0.18)
	h.border_color = Color("ffb800")
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)

	btn.pressed.connect(cb)
	return btn


func _create_toggle_button(txt: String, initial: bool, cb: Callable) -> CheckButton:
	var cb_btn := CheckButton.new()
	cb_btn.text = txt
	cb_btn.button_pressed = initial
	cb_btn.add_theme_font_size_override("font_size", 12)
	cb_btn.toggled.connect(cb)
	return cb_btn


# ==============================================================================
# INNER CLASS 1: LIVE ANIMATION PREVIEW CANVAS
# ==============================================================================

class _PreviewCanvas extends Control:
	var host: SpriteInspectorTool

	func _init(p_host: SpriteInspectorTool) -> void:
		host = p_host
		clip_contents = true

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("090f17"), true)

		# 1. Background Checkerboard or Arena Grid
		if host.show_checkerboard:
			var tile := 20.0
			var cols := int(ceil(size.x / tile))
			var rows := int(ceil(size.y / tile))
			for r in range(rows):
				for c in range(cols):
					if (r + c) % 2 == 0:
						draw_rect(Rect2(c * tile, r * tile, tile, tile), Color("111b27"), true)
		else:
			draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color("101824"), true)

		if host.current_texture == null or host.selected_entry.is_empty():
			return

		var cols: int = maxi(1, int(host.selected_entry.get("cols", 1)))
		var rows: int = maxi(1, int(host.selected_entry.get("rows", 1)))
		var cw: float = float(host.current_texture.get_width()) / float(cols)
		var ch: float = float(host.current_texture.get_height()) / float(rows)
		var pivot: Vector2 = host.selected_entry.get("pivot", Vector2(cw * 0.5, ch * 0.9))

		# Fit scale so cell fits nicely in preview viewport
		var base_fit: float = minf((size.x * 0.78) / cw, (size.y * 0.78) / ch)
		var draw_scale: float = base_fit * host.preview_zoom
		var draw_size := Vector2(cw, ch) * draw_scale

		# Anchor pivot near lower-center of preview canvas
		var anchor_pos := Vector2(size.x * 0.5, size.y * 0.80)
		var pivot_ratio := Vector2(pivot.x / cw, pivot.y / ch)
		if host.flip_h:
			pivot_ratio.x = 1.0 - pivot_ratio.x
		var top_left := anchor_pos - Vector2(draw_size.x * pivot_ratio.x, draw_size.y * pivot_ratio.y)
		var dst_rect := Rect2(top_left, draw_size)

		# 2. Onion Skin (Previous Frame Ghost)
		var total_frames: int = maxi(1, int(host.selected_entry.get("frames", 1)))
		if host.show_onion_skin and total_frames > 1:
			var prev_idx: int = (host.current_frame - 1 + total_frames) % total_frames
			var pc: int = prev_idx % cols
			var pr: int = prev_idx / cols
			var prev_src := Rect2(pc * cw, pr * ch, cw, ch)
			var ghost_dst := dst_rect
			if host.flip_h:
				ghost_dst.size.x = - dst_rect.size.x
			draw_texture_rect_region(host.current_texture, ghost_dst, prev_src, Color(0.2, 0.85, 1.0, 0.32))

		# 3. Current Frame Sprite
		var fc: int = host.current_frame % cols
		var fr: int = host.current_frame / cols
		var src_rect := Rect2(fc * cw, fr * ch, cw, ch)
		var render_dst := dst_rect
		if host.flip_h:
			render_dst.size.x = - dst_rect.size.x
		draw_texture_rect_region(host.current_texture, render_dst, src_rect, Color.WHITE)

		# 4. Bounding Box & Cell Box Overlay
		if host.show_bounding_box:
			# Cell Outer Border (Dashed/Thin Slate)
			draw_rect(dst_rect, Color(0.5, 0.65, 0.85, 0.45), false, 1.5)
			if host.current_frame < host.frame_metrics.size():
				var fm: Dictionary = host.frame_metrics[host.current_frame]
				var used: Rect2i = fm["used_rect"]
				var ux: float = float(used.position.x)
				if host.flip_h:
					ux = cw - float(used.position.x + used.size.x)
				var u_rect := Rect2(
					top_left + Vector2(ux, float(used.position.y)) * draw_scale,
					Vector2(used.size) * draw_scale
				)
				var box_col := Color("ff3b5c") if fm["has_bleed"] else Color("34d399")
				draw_rect(u_rect, box_col, false, 2.0)

		# 5. Ground Baseline & Pivot Crosshair Overlay
		if host.show_pivot_baseline:
			# Ground Baseline Horizontal Line through Pivot Y
			draw_line(Vector2(16, anchor_pos.y), Vector2(size.x - 16, anchor_pos.y), Color(1.0, 0.72, 0.0, 0.85), 2.0)
			# Vertical Center Line through Pivot X
			draw_line(Vector2(anchor_pos.x, 16), Vector2(anchor_pos.x, size.y - 16), Color(0.0, 0.9, 1.0, 0.45), 1.0)
			# Pivot Crosshair Circle
			draw_circle(anchor_pos, 5.0, Color("ff3b5c"))
			draw_arc(anchor_pos, 9.0, 0.0, TAU, 24, Color("ffb800"), 1.5)

		# Viewport Header Caption
		draw_string(ThemeDB.fallback_font, Vector2(12, 22), "▶ LIVE ANIMATION PREVIEW (F%d)" % host.current_frame, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("00e5ff"))


# ==============================================================================
# INNER CLASS 2: FULL SPRITE SHEET GRID VIEWER (Interactive Cell Selector)
# ==============================================================================

class _SheetGridCanvas extends Control:
	var host: SpriteInspectorTool
	var _sheet_dst_rect: Rect2 = Rect2()

	func _init(p_host: SpriteInspectorTool) -> void:
		host = p_host
		clip_contents = true

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _sheet_dst_rect.has_point(event.position) and not host.selected_entry.is_empty():
				var cols: int = maxi(1, int(host.selected_entry.get("cols", 1)))
				var rows: int = maxi(1, int(host.selected_entry.get("rows", 1)))
				var total: int = maxi(1, int(host.selected_entry.get("frames", 1)))
				var mouse_pos: Vector2 = event.position
				var rel: Vector2 = (mouse_pos - _sheet_dst_rect.position) / _sheet_dst_rect.size
				var c := clampi(int(floor(rel.x * cols)), 0, cols - 1)
				var r := clampi(int(floor(rel.y * rows)), 0, rows - 1)
				var idx := r * cols + c
				if idx < total:
					host.is_playing = false
					host._update_play_button()
					host.set_frame(idx)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("090f17"), true)

		if host.show_checkerboard:
			var tile := 16.0
			var cols_bg := int(ceil(size.x / tile))
			var rows_bg := int(ceil(size.y / tile))
			for r in range(rows_bg):
				for c in range(cols_bg):
					if (r + c) % 2 == 0:
						draw_rect(Rect2(c * tile, r * tile, tile, tile), Color("101926"), true)

		if host.current_texture == null or host.selected_entry.is_empty():
			return

		var tex_w := float(host.current_texture.get_width())
		var tex_h := float(host.current_texture.get_height())
		var pad_top := 32.0
		var avail := Vector2(size.x - 24.0, size.y - pad_top - 16.0)
		var fit := minf(avail.x / tex_w, avail.y / tex_h)
		var draw_size := Vector2(tex_w, tex_h) * fit
		var top_left := Vector2((size.x - draw_size.x) * 0.5, pad_top + (avail.y - draw_size.y) * 0.5)
		_sheet_dst_rect = Rect2(top_left, draw_size)

		draw_texture_rect(host.current_texture, _sheet_dst_rect, false)

		var cols: int = maxi(1, int(host.selected_entry.get("cols", 1)))
		var rows: int = maxi(1, int(host.selected_entry.get("rows", 1)))
		var total: int = maxi(1, int(host.selected_entry.get("frames", 1)))
		var cell_w := draw_size.x / float(cols)
		var cell_h := draw_size.y / float(rows)
		var pivot: Vector2 = host.selected_entry.get("pivot", Vector2.ZERO)
		var raw_cw := tex_w / float(cols)
		var raw_ch := tex_h / float(rows)

		for idx in range(total):
			var c: int = idx % cols
			var r: int = idx / cols
			var cell_rect := Rect2(top_left + Vector2(c * cell_w, r * cell_h), Vector2(cell_w, cell_h))

			# Baseline tick inside each cell
			if host.show_pivot_baseline and raw_ch > 0.0:
				var base_y := cell_rect.position.y + (pivot.y / raw_ch) * cell_h
				draw_line(Vector2(cell_rect.position.x + 2, base_y), Vector2(cell_rect.end.x - 2, base_y), Color(1.0, 0.72, 0.0, 0.45), 1.0)

			var has_bleed := false
			if idx < host.frame_metrics.size():
				has_bleed = bool(host.frame_metrics[idx].get("has_bleed", false))

			var grid_col := Color("ff3b5c") if has_bleed else Color(0.22, 0.74, 0.97, 0.42)
			draw_rect(cell_rect, grid_col, false, 1.0)

			if idx == host.current_frame:
				draw_rect(cell_rect, Color(1.0, 0.72, 0.0, 0.14), true)
				draw_rect(cell_rect, Color("ffb800"), false, 2.5)

			draw_string(ThemeDB.fallback_font, cell_rect.position + Vector2(5, 14), "F%d" % idx, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffb800") if idx == host.current_frame else Color("94a3b8"))

		draw_string(ThemeDB.fallback_font, Vector2(12, 22), "⊞ FULL SPRITE SHEET ATLAS (%d×%d 클릭하여 프레임 선택)" % [cols, rows], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffb800"))
