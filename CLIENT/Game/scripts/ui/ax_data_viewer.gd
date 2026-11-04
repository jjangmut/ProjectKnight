class_name AXDataViewer
extends Control
## AXDataViewer (Heroes War Tactical Codex Edition):
## 히어로즈 워(Heroes War) 택티컬 커맨드 UI 컨셉을 적용한 인게임 AX 기획 데이터 마스터 도감.
## - 사선/챔퍼 엣지 스타일 패널 + 네온 시안(#00E5FF) & 택티컬 앰버(#FFB800) & 크림슨(#FF3B5C) 하이라이트
## - 플레이어/몬스터/보스 실제 스프라이트 포트레이트 썸네일 & 등급 배지([SSR], [ELITE], [EX-BOSS])
## - 6대 전술 탭, 실시간 전술 코드 검색, RAW JSON 데이터 터미널 뷰 지원

signal viewer_closed
signal tab_changed(tab_index: int)

const AXDataRegistryClass := preload("res://scripts/data/ax_data_registry.gd")

const TAB_NAMES: Array[String] = [
	"◢ 01. 작전 총람",
	"◢ 02. 영웅 스펙",
	"◢ 03. 전장 구역",
	"◢ 04. 적성 개체",
	"◢ 05. 보스 파일",
	"◢ 06. 웨폰/유물"
]

var current_tab: int = 0
var show_raw_json: bool = false
var search_query: String = ""

var _tab_buttons: Array[Button] = []
var _search_input: LineEdit
var _json_toggle_btn: Button
var _close_btn: Button
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _status_footer_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell_ui()
	select_tab(0)


func _build_shell_ui() -> void:
	# 1. Heroes War Deep Tactical Backdrop
	var bg := ColorRect.new()
	bg.color = Color("060a10f8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top Tactical Amber Stripe
	var top_stripe := ColorRect.new()
	top_stripe.color = Color("ffb800")
	top_stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_stripe.custom_minimum_size = Vector2(0, 3)
	add_child(top_stripe)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# 2. Top Tactical Command Bar
	var header_panel := _create_tactical_panel(Color("0e1622"), Color("00e5ff"), 2, 10, 8)
	header_panel.custom_minimum_size = Vector2(0, 58)
	root_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	header_panel.add_child(header_hbox)

	var codex_badge := _create_badge("HEROES WAR CODEX", Color("ffb800"), Color("080c12"))
	codex_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(codex_badge)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	header_hbox.add_child(title_vbox)

	var meta := AXDataRegistryClass.get_meta_info()
	var title_lbl := Label.new()
	title_lbl.text = "AX TACTICAL DATA TERMINAL v%s — 전술 기획 데이터베이스" % str(meta.get("ax_schema_version", "2.0.0"))
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color("f8fafc"))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s  |  TACTICAL COMMAND INTERFACE" % str(meta.get("title_ko", ""))
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color("00e5ff"))
	title_vbox.add_child(sub_lbl)

	# Search Radar Input
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "🔍 전술 키워드 검색 (패링, 골렘, 심판관...)"
	_search_input.custom_minimum_size = Vector2(215, 34)
	_search_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_input.add_theme_font_size_override("font_size", 12)
	_search_input.text_changed.connect(_on_search_text_changed)
	header_hbox.add_child(_search_input)

	# Raw JSON Terminal Button
	_json_toggle_btn = Button.new()
	_json_toggle_btn.text = "{ } RAW JSON"
	_json_toggle_btn.custom_minimum_size = Vector2(102, 34)
	_json_toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_json_toggle_btn.add_theme_font_size_override("font_size", 12)
	_style_tactical_button(_json_toggle_btn, Color("122432"), Color("00e5ff"), 4)
	_json_toggle_btn.pressed.connect(_on_toggle_raw_json)
	header_hbox.add_child(_json_toggle_btn)

	# Close Button
	_close_btn = Button.new()
	_close_btn.name = "BtnCloseAXViewer"
	_close_btn.text = "✖ EXIT"
	_close_btn.custom_minimum_size = Vector2(82, 34)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_btn.add_theme_font_size_override("font_size", 13)
	_style_tactical_button(_close_btn, Color("32141e"), Color("ff3b5c"), 4)
	_close_btn.pressed.connect(_on_close_pressed)
	header_hbox.add_child(_close_btn)

	# 3. Heroes War Tactical Tab Deck
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	root_vbox.add_child(tab_bar)

	_tab_buttons.clear()
	for i in range(TAB_NAMES.size()):
		var tbtn := Button.new()
		tbtn.text = TAB_NAMES[i]
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.custom_minimum_size = Vector2(0, 38)
		tbtn.add_theme_font_size_override("font_size", 14)
		var idx := i
		tbtn.pressed.connect(func(): select_tab(idx))
		tab_bar.add_child(tbtn)
		_tab_buttons.append(tbtn)

	# 4. Main Tactical Dossier Content Area
	var content_panel := _create_tactical_panel(Color("090f17"), Color("1e3448"), 1, 8, 4)
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_panel)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(_content_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 10)
	_content_scroll.add_child(_content_vbox)

	# 5. Bottom Tactical Telemetry Bar
	var footer_hbox := HBoxContainer.new()
	root_vbox.add_child(footer_hbox)

	_status_footer_label = Label.new()
	_status_footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_footer_label.add_theme_font_size_override("font_size", 12)
	_status_footer_label.add_theme_color_override("font_color", Color("64748b"))
	footer_hbox.add_child(_status_footer_label)

	var path_lbl := Label.new()
	path_lbl.text = "● HEROES WAR UI SYSTEM  |  DB: res://data/ax_data/project_knight_ax_data.json"
	path_lbl.add_theme_font_size_override("font_size", 12)
	path_lbl.add_theme_color_override("font_color", Color("00e5ff"))
	footer_hbox.add_child(path_lbl)


func select_tab(tab_idx: int) -> void:
	current_tab = clampi(tab_idx, 0, TAB_NAMES.size() - 1)
	show_raw_json = false
	_json_toggle_btn.text = "{ } RAW JSON"
	_update_tab_button_styles()
	_rebuild_content()
	tab_changed.emit(current_tab)


func set_search_query(query: String) -> void:
	if _search_input and _search_input.text != query:
		_search_input.text = query
	search_query = query.strip_edges()
	_rebuild_content()


func get_rendered_card_count() -> int:
	return _content_vbox.get_child_count() if _content_vbox else 0


func _on_search_text_changed(new_text: String) -> void:
	search_query = new_text.strip_edges()
	_rebuild_content()


func _on_toggle_raw_json() -> void:
	show_raw_json = not show_raw_json
	_json_toggle_btn.text = "📋 DOSSIER VIEW" if show_raw_json else "{ } RAW JSON"
	_rebuild_content()


func _on_close_pressed() -> void:
	viewer_closed.emit()
	queue_free()


func _update_tab_button_styles() -> void:
	for i in range(_tab_buttons.size()):
		var btn := _tab_buttons[i]
		if i == current_tab and not show_raw_json and search_query.is_empty():
			_style_tactical_button(btn, Color("2b200b"), Color("ffb800"), 6)
			btn.add_theme_color_override("font_color", Color("fffbeb"))
		else:
			_style_tactical_button(btn, Color("0f1824"), Color("283c50"), 3)
			btn.add_theme_color_override("font_color", Color("94a3b8"))


func _clear_content() -> void:
	if _content_vbox == null:
		return
	for child in _content_vbox.get_children():
		_content_vbox.remove_child(child)
		child.queue_free()
	if _content_scroll:
		_content_scroll.scroll_vertical = 0


func _rebuild_content() -> void:
	_clear_content()
	_update_tab_button_styles()

	var metrics := AXDataRegistryClass.get_summary_metrics()
	_status_footer_label.text = "TELEMETRY SYNC OK: 작전구역 %d개 · 적성개체 %d종 · 보스 %d기(전술패턴 %d종) · 영웅모션 %d종 · 웨폰/유물 %d종" % [
		int(metrics.get("stage_count", 5)),
		int(metrics.get("enemy_type_count", 5)),
		int(metrics.get("boss_count", 5)),
		int(metrics.get("boss_pattern_count", 17)),
		int(metrics.get("player_anim_count", 8)),
		int(metrics.get("shop_item_count", 5)) + int(metrics.get("relic_count", 5))
	]

	if show_raw_json:
		_build_raw_json_view()
		return

	if not search_query.is_empty():
		_build_search_results_view(search_query)
		return

	match current_tab:
		0:
			_build_overview_tab()
		1:
			_build_player_combat_tab()
		2:
			_build_stages_tab()
		3:
			_build_enemies_tab()
		4:
			_build_bosses_tab()
		5:
			_build_sanctuary_tab()


# ==============================================================================
# TAB 0: TACTICAL OVERVIEW (작전 총람)
# ==============================================================================
func _build_overview_tab() -> void:
	var meta := AXDataRegistryClass.get_meta_info()
	var metrics := AXDataRegistryClass.get_summary_metrics()
	var rules := AXDataRegistryClass.get_combat_rules()

	# Tactical Briefing Banner
	var hero := _create_tactical_panel(Color("101b28"), Color("ffb800"), 1, 8, 8)
	_content_vbox.add_child(hero)
	var hvbox := VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 4)
	hero.add_child(hvbox)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	hvbox.add_child(hrow)
	hrow.add_child(_create_badge("COMMAND BRIEFING", Color("ffb800"), Color("090d14")))

	var htitle := Label.new()
	htitle.text = "%s (%s)" % [str(meta.get("title_ko", "")), str(meta.get("project_id", ""))]
	htitle.add_theme_font_size_override("font_size", 17)
	htitle.add_theme_color_override("font_color", Color("ffb800"))
	hrow.add_child(htitle)

	var hdesc := Label.new()
	hdesc.text = str(meta.get("description", ""))
	hdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hdesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdesc.add_theme_font_size_override("font_size", 13)
	hdesc.add_theme_color_override("font_color", Color("cbd5e1"))
	hvbox.add_child(hdesc)

	# 6 Tactical KPI Modules
	var kpi_grid := GridContainer.new()
	kpi_grid.columns = 3
	kpi_grid.add_theme_constant_override("h_separation", 10)
	kpi_grid.add_theme_constant_override("v_separation", 10)
	_content_vbox.add_child(kpi_grid)

	_add_kpi_card(kpi_grid, "OP-ZONES (캠페인 전장)", "%d OPERATIONS" % int(metrics.get("stage_count", 5)), "OP-01 성문 외곽 ~ OP-05 침묵의 성채", Color("00e5ff"))
	_add_kpi_card(kpi_grid, "BOSS THREATS (보스전)", "5 BOSS / %d PATTERNS" % int(metrics.get("boss_pattern_count", 17)), "HP 50% 이하 2페이즈 오버드라이브 각성", Color("ff3b5c"))
	_add_kpi_card(kpi_grid, "HOSTILE UNITS (적성 개체)", "%d ARCHETYPES" % int(metrics.get("enemy_type_count", 5)), "보병 · 도약 맹수 · 저격수 · 중장갑 골렘 · 심연 기사", Color("34d399"))
	_add_kpi_card(kpi_grid, "SSR HERO SPEC (영웅 기동)", "%d ACTION STATES" % int(metrics.get("player_anim_count", 8)), "3단 성검 찌르기 · 관통창 검기 · 0.14s 패링", Color("ffb800"))
	_add_kpi_card(kpi_grid, "SANCTUARY LAB (연구소)", "5 UPGRADES / 5 RELICS", "영혼 파편 코어 강화 및 전설/신화 아티팩트", Color("c084fc"))
	_add_kpi_card(kpi_grid, "CAMERA & PHYSICS", "PITCH -32° / FOV 42°", "사이드 쿼터뷰 벨트스크롤 · 충돌 정지 및 4면 방벽", Color("38bdf8"))

	# Tactical Operation Protocol Card
	var flow_panel := _create_tactical_panel(Color("0e1722"), Color("00e5ff"), 1, 8, 6)
	_content_vbox.add_child(flow_panel)
	var fvbox := VBoxContainer.new()
	fvbox.add_theme_constant_override("separation", 6)
	flow_panel.add_child(fvbox)

	var ftitle := Label.new()
	ftitle.text = "◢ TACTICAL ENGAGEMENT PROTOCOL (전술 교전 및 물리 프로토콜)"
	ftitle.add_theme_font_size_override("font_size", 15)
	ftitle.add_theme_color_override("font_color", Color("00e5ff"))
	fvbox.add_child(ftitle)

	var pflow: Dictionary = rules.get("progression_flow", {})
	var cphys: Dictionary = rules.get("collision_and_physics", {})
	var lines := [
		"▸ [PHASE 1 : VANGUARD SWEEP] %s" % str(pflow.get("wave_1", "")),
		"▸ [TACTICAL SUPPLY DROP] %s" % str(pflow.get("wave_clear_reward", "")),
		"▸ [PHASE 2 : BOSS INTERCEPT] %s" % str(pflow.get("boss_trigger", "")),
		"▸ [OPERATION COMPLETE] %s" % str(pflow.get("stage_clear", "")),
		"▸ [COLLISION & ARENA LOCK] %s (X 정지거리 %.2fm, Z 정지거리 %.2fm)" % [
			str(cphys.get("rule_desc", "")),
			float(cphys.get("body_stop_distance_x", 0.92)),
			float(cphys.get("body_stop_distance_z", 0.65))
		]
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color("e2e8f0"))
		fvbox.add_child(lbl)


# ==============================================================================
# TAB 1: SSR HERO & COMBAT FORMULA (영웅 스펙)
# ==============================================================================
func _build_player_combat_tab() -> void:
	var p := AXDataRegistryClass.get_player_data()
	var stats: Dictionary = p.get("base_stats", {})
	var combat: Dictionary = p.get("combat", {})
	var parry: Dictionary = p.get("defense_parry", {})
	var beam: Dictionary = combat.get("finisher_beam", {})

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	_content_vbox.add_child(top_hbox)

	# Left: Hero Unit Portrait + Base Stats
	var stat_panel := _create_tactical_panel(Color("0f1824"), Color("ffb800"), 1, 8, 6)
	stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(stat_panel)
	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 6)
	stat_panel.add_child(svbox)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	svbox.add_child(head_row)

	var pbox := _create_unit_portrait_box("res://assets/player_frames/idle_v1_aligned.png", 2, 2, Color("ffb800"), "SSR")
	head_row.add_child(pbox)

	var hinfo := VBoxContainer.new()
	hinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hinfo.alignment = BoxContainer.ALIGNMENT_CENTER
	head_row.add_child(hinfo)

	var stitle := Label.new()
	stitle.text = "🛡 %s (%s)" % [str(p.get("name_ko", "")), str(p.get("name_en", ""))]
	stitle.add_theme_font_size_override("font_size", 16)
	stitle.add_theme_color_override("font_color", Color("ffb800"))
	hinfo.add_child(stitle)

	var srole := Label.new()
	srole.text = "CLASS: VANGUARD PALADIN  |  CP: 14,850  |  WEAPON: HOLY LANCE & AEGIS"
	srole.add_theme_font_size_override("font_size", 12)
	srole.add_theme_color_override("font_color", Color("00e5ff"))
	hinfo.add_child(srole)

	_add_stat_bar_row(svbox, "최대 체력 (HP)", float(stats.get("max_hp", 8)), 12.0, "%d HP" % int(stats.get("max_hp", 8)), Color("ff3b5c"))
	_add_stat_bar_row(svbox, "횡기동 속도 (X)", float(stats.get("move_speed_x", 7.5)), 15.0, "%.1f m/s" % float(stats.get("move_speed_x", 7.5)), Color("00e5ff"))
	_add_stat_bar_row(svbox, "종기동 속도 (Z)", float(stats.get("move_speed_z", 4.8)), 15.0, "%.1f m/s" % float(stats.get("move_speed_z", 4.8)), Color("34d399"))
	_add_stat_bar_row(svbox, "택티컬 대시 (Dash)", float(stats.get("dash_speed", 14.0)), 20.0, "%.1f m/s (%.2fs)" % [float(stats.get("dash_speed", 14.0)), float(stats.get("dash_duration", 0.22))], Color("c084fc"))
	_add_stat_bar_row(svbox, "도약 추진력 (Jump)", float(stats.get("jump_velocity", 6.8)), 12.0, "%.1f m/s" % float(stats.get("jump_velocity", 6.8)), Color("ffb800"))
	_add_stat_bar_row(svbox, "피격 무적 (i-Frame)", float(stats.get("hit_invuln_duration", 0.65)), 1.5, "%.2f sec" % float(stats.get("hit_invuln_duration", 0.65)), Color("fde047"))

	# Right: Tactical Skill Deck & Parry Counter Formula
	var cpanel := _create_tactical_panel(Color("0f1824"), Color("00e5ff"), 1, 8, 6)
	cpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(cpanel)
	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 6)
	cpanel.add_child(cvbox)

	var ctitle := Label.new()
	ctitle.text = "◢ TACTICAL SKILL DECK & PARRY FORMULA (전술 스킬 & 패링 공식)"
	ctitle.add_theme_font_size_override("font_size", 15)
	ctitle.add_theme_color_override("font_color", Color("00e5ff"))
	cvbox.add_child(ctitle)

	var clines := [
		"▸ [SKILL 1 : 3-COMBO THRUST] 기본 피해 %d DMG (지속 %.2fs / 쿨타임 %.2fs / 콤보유지 %.2fs)" % [
			int(combat.get("base_attack_damage", 2)),
			float(combat.get("attack_duration", 0.20)),
			float(combat.get("attack_cooldown", 0.22)),
			float(combat.get("combo_reset_timer", 0.95))
		],
		"▸ [HYBRID HITBOX] 전방 X %.2fm × 깊이 Z ±%.2fm 전술 영역 100%% 적중 보장" % [
			float(combat.get("melee_reach_x", 2.9)),
			float(combat.get("melee_depth_z", 1.65))
		],
		"▸ [FINISHER : HOLY LANCE BEAM] 탄속 %.1f m/s · 사거리 %.1fm · 관통 피해 %d DMG" % [
			float(beam.get("speed", 20.0)),
			float(beam.get("max_range", 24.0)),
			int(beam.get("damage", 2))
		],
		"▸ [SKILL 2 : AEGIS JUST PARRY] %.2f초 이내 가드 시 피해 100%% 무효화 + 적 %.1f초 스턴" % [
			float(parry.get("just_parry_window", 0.14)),
			float(parry.get("parry_enemy_stun_sec", 2.0))
		],
		"▸ [COUNTER OVERDRIVE] 패링 성공 시 %.1f초간 다음 공격 %.0f배 피해 (%d DMG 황금 일격)" % [
			float(parry.get("counter_buff_duration", 3.5)),
			float(parry.get("counter_damage_multiplier", 3.0)),
			int(parry.get("counter_attack_damage", 6))
		],
		"▸ [STANDARD GUARD] 저스트 타이밍 이후 가드 유지 시 모든 피해 50% 경감",
		"▸ [AIR POGO BOUNCE] 공중 하단 적 적중 시 상향 반동 점프(Vy 6.52) & 공중 대시 즉시 리셋",
		"▸ [AIR DIVE SLAM] 공중 하향 스톰프 급강하(Vy -22.0) · 착지 시 3.8m 대지 충격파 2배 광역 피해 & 체간 4 파쇄",
		"▸ [DASH GHOST TRAIL] 대시 중 45ms 간격 3D 네온 시안 잔상 투영 및 0.22s 무적 회피",
		"▸ [INPUT BUFFERING] 코요테 타임 0.12s · 점프 선입력 0.14s · 공격 선입력 0.12s 공중-지상 무봉 연계"
	]
	for cl in clines:
		var l := Label.new()
		l.text = cl
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color("e2e8f0"))
		cvbox.add_child(l)

	# Bottom: Animation Frame Spec Matrix
	var anim_panel := _create_tactical_panel(Color("0c131d"), Color("334155"), 1, 8, 4)
	_content_vbox.add_child(anim_panel)
	var avbox := VBoxContainer.new()
	avbox.add_theme_constant_override("separation", 5)
	anim_panel.add_child(avbox)

	var atitle := Label.new()
	atitle.text = "◢ MOTION CAPTURE & SPRITE SHEET MATRIX (780×780 무게중심 정렬 규격)"
	atitle.add_theme_font_size_override("font_size", 14)
	atitle.add_theme_color_override("font_color", Color("ffb800"))
	avbox.add_child(atitle)

	for anim in p.get("animations", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		avbox.add_child(row)

		var badge := _create_badge(str(anim.get("state", "")), Color("162636"), Color("00e5ff"))
		badge.custom_minimum_size = Vector2(82, 0)
		row.add_child(badge)

		var sheet_lbl := Label.new()
		sheet_lbl.text = "%s (%s · %.0f FPS)" % [str(anim.get("sheet", "")), str(anim.get("grid", "")), float(anim.get("fps", 8.0))]
		sheet_lbl.custom_minimum_size = Vector2(270, 0)
		sheet_lbl.add_theme_font_size_override("font_size", 13)
		sheet_lbl.add_theme_color_override("font_color", Color("fde047"))
		row.add_child(sheet_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(anim.get("desc", ""))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color("cbd5e1"))
		row.add_child(desc_lbl)


# ==============================================================================
# TAB 2: OPERATION ZONES 1~5 (전장 구역)
# ==============================================================================
func _build_stages_tab() -> void:
	for s in AXDataRegistryClass.get_stages():
		var amb_hex := str(s.get("ambient_color", "#60a5fa"))
		var card := _create_tactical_panel(Color("0e1722"), Color(amb_hex), 2, 8, 8)
		_content_vbox.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		card.add_child(vbox)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 10)
		vbox.add_child(header)

		var op_badge := _create_badge("OP-0%d" % int(s.get("stage_num", 1)), Color(amb_hex), Color("080c12"))
		header.add_child(op_badge)

		var title := Label.new()
		title.text = "%s (%s)" % [str(s.get("name_ko", "")), str(s.get("name_en", ""))]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color("f8fafc"))
		header.add_child(title)

		var boss_badge := _create_badge("👑 TARGET: %s" % str(s.get("boss_name_ko", "")), Color("32141e"), Color("ff3b5c"))
		header.add_child(boss_badge)

		var arena_arr: Array = s.get("arena_size_m", [38.0, 12.0])
		var props_arr: Array = s.get("environment_props", [])
		var props_str := ", ".join(PackedStringArray(props_arr))

		var wave_strs := PackedStringArray()
		for w in s.get("wave_1_enemies", []):
			wave_strs.append("%s × %d기" % [str(w.get("name_ko", "")), int(w.get("count", 2))])

		var info_lbl := Label.new()
		info_lbl.text = "▸ 전장 환경: %s  |  작전 반경: %.0fm × %.0fm  |  대기 포그 밀도: %.3f\n▸ 전술 구조물: %s\n▸ 교전 시퀀스: WAVE 1 (%s) ➔ 영혼 보급(+%d HP 회복) ➔ 보스 결전 ➔ 전리품 유물 [%s]" % [
			str(s.get("theme", "")),
			float(arena_arr[0]),
			float(arena_arr[1]),
			float(s.get("fog_density", 0.01)),
			props_str,
			", ".join(wave_strs),
			int(s.get("wave_clear_heal", 2)),
			str(s.get("reward_relic_id", ""))
		]
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.add_theme_font_size_override("font_size", 13)
		info_lbl.add_theme_color_override("font_color", Color("cbd5e1"))
		vbox.add_child(info_lbl)


# ==============================================================================
# TAB 3: HOSTILE UNITS (적성 개체 도감)
# ==============================================================================
func _build_enemies_tab() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content_vbox.add_child(grid)

	for e in AXDataRegistryClass.get_enemies():
		var card := _create_tactical_panel(Color("0f1824"), Color("34d399"), 1, 8, 6)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		vbox.add_child(top_row)

		var sprite_path := str(e.get("sprite_sheet", ""))
		var pbox := _create_unit_portrait_box(sprite_path, 3, 2, Color("34d399"), "STG-%d" % int(e.get("stage_num", 1)))
		top_row.add_child(pbox)

		var title_box := VBoxContainer.new()
		title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_box.alignment = BoxContainer.ALIGNMENT_CENTER
		top_row.add_child(title_box)

		var title := Label.new()
		title.text = "%s (%s)" % [str(e.get("name_ko", "")), str(e.get("name_en", ""))]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color("6ee7b7"))
		title_box.add_child(title)

		var role_lbl := Label.new()
		role_lbl.text = "전술 분류: %s  |  CODE: %s" % [str(e.get("role", "")), str(e.get("id", ""))]
		role_lbl.add_theme_font_size_override("font_size", 12)
		role_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		title_box.add_child(role_lbl)

		_add_stat_bar_row(vbox, "내구도 (HP)", float(e.get("hp", 4)), 10.0, "%d HP" % int(e.get("hp", 4)), Color("ff3b5c"))
		_add_stat_bar_row(vbox, "기동력 (SPD)", float(e.get("move_speed", 3.5)), 10.0, "%.1f m/s" % float(e.get("move_speed", 3.5)), Color("00e5ff"))
		_add_stat_bar_row(vbox, "화력 / 주기", float(e.get("attack_damage", 1)), 4.0, "%d DMG (%.1fs)" % [int(e.get("attack_damage", 1)), float(e.get("attack_cooldown", 1.2))], Color("ffb800"))

		var mech := Label.new()
		mech.text = "⚡ 전술 기믹: %s" % str(e.get("special_mechanic", ""))
		mech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mech.add_theme_font_size_override("font_size", 12)
		mech.add_theme_color_override("font_color", Color("e2e8f0"))
		vbox.add_child(mech)


# ==============================================================================
# TAB 4: BOSS THREAT DOSSIERS (보스 전술 파일)
# ==============================================================================
func _build_bosses_tab() -> void:
	for b in AXDataRegistryClass.get_bosses():
		var card := _create_tactical_panel(Color("121624"), Color("ff3b5c"), 2, 8, 8)
		_content_vbox.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		vbox.add_child(hbox)

		var sprite_path := str(b.get("sprite_sheet", ""))
		var b_cols := 3 if int(b.get("stage_num", 1)) == 1 else 4
		var b_rows := 2 if int(b.get("stage_num", 1)) == 1 else 3
		var pbox := _create_unit_portrait_box(sprite_path, b_cols, b_rows, Color("ff3b5c"), "EX-BOSS")
		hbox.add_child(pbox)

		var binfo := VBoxContainer.new()
		binfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binfo.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(binfo)

		var title := Label.new()
		title.text = "👑 [OP-0%d BOSS] %s — %s" % [int(b.get("stage_num", 1)), str(b.get("name_ko", "")), str(b.get("title_ko", ""))]
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", Color("fca5a5"))
		binfo.add_child(title)

		var stat_badge := Label.new()
		stat_badge.text = "● THREAT LEVEL: EX  |  MAX HP: %d  |  PHASE 1 SPD: %.1f m/s ➔ PHASE 2 (HP 50%%↓) SPD: %.1f m/s" % [
			int(b.get("hp", 24)),
			float(b.get("move_speed_p1", 3.8)),
			float(b.get("move_speed_p2", 4.8))
		]
		stat_badge.add_theme_font_size_override("font_size", 13)
		stat_badge.add_theme_color_override("font_color", Color("ffb800"))
		binfo.add_child(stat_badge)

		# Signature Patterns Matrix
		var pats: Array = b.get("patterns", [])
		for pat in pats:
			var pbox_card := _create_tactical_panel(Color("0a0f18"), Color("00e5ff"), 1, 6, 4)
			vbox.add_child(pbox_card)
			var pvbox := VBoxContainer.new()
			pvbox.add_theme_constant_override("separation", 2)
			pbox_card.add_child(pvbox)

			var phead := Label.new()
			phead.text = "◢ [%s] %s (%s)   |   🔥 DAMAGE: %d   |   📐 %s" % [
				str(pat.get("id", "")),
				str(pat.get("name_ko", "")),
				str(pat.get("name_en", "")),
				int(pat.get("damage", 2)),
				str(pat.get("metrics", ""))
			]
			phead.add_theme_font_size_override("font_size", 13)
			phead.add_theme_color_override("font_color", Color("00e5ff"))
			pvbox.add_child(phead)

			var pdesc := Label.new()
			pdesc.text = "   ↳ %s" % str(pat.get("desc", ""))
			pdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pdesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pdesc.add_theme_font_size_override("font_size", 12)
			pdesc.add_theme_color_override("font_color", Color("cbd5e1"))
			pvbox.add_child(pdesc)


# ==============================================================================
# TAB 5: SANCTUARY LAB & RELICS (웨폰/유물 연구소)
# ==============================================================================
func _build_sanctuary_tab() -> void:
	# 1. Sanctuary Core Upgrades
	var shop_panel := _create_tactical_panel(Color("0f1824"), Color("ffb800"), 1, 8, 6)
	_content_vbox.add_child(shop_panel)
	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 6)
	shop_panel.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "◢ 🔥 SANCTUARY CORE UPGRADE LAB (화톳불 영혼 제단 영구 강화 모듈)"
	stitle.add_theme_font_size_override("font_size", 16)
	stitle.add_theme_color_override("font_color", Color("ffb800"))
	svbox.add_child(stitle)

	for item in AXDataRegistryClass.get_shop_items():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		svbox.add_child(row)

		var badge := _create_badge("MAX Lv.%d" % int(item.get("max_level", 1)), Color("1e293b"), Color("00e5ff"))
		badge.custom_minimum_size = Vector2(78, 0)
		row.add_child(badge)

		var name_lbl := Label.new()
		name_lbl.text = str(item.get("name_ko", ""))
		name_lbl.custom_minimum_size = Vector2(250, 0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color("f8fafc"))
		row.add_child(name_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "💎 %d SHARDS" % int(item.get("cost_shards", 0))
		cost_lbl.custom_minimum_size = Vector2(115, 0)
		cost_lbl.add_theme_font_size_override("font_size", 13)
		cost_lbl.add_theme_color_override("font_color", Color("ffb800"))
		row.add_child(cost_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(item.get("effect_desc", ""))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color("cbd5e1"))
		row.add_child(desc_lbl)

	# 2. Boss Relics & Gear Evolution
	var relic_panel := _create_tactical_panel(Color("111626"), Color("c084fc"), 1, 8, 6)
	_content_vbox.add_child(relic_panel)
	var rvbox := VBoxContainer.new()
	rvbox.add_theme_constant_override("separation", 8)
	relic_panel.add_child(rvbox)

	var rtitle := Label.new()
	rtitle.text = "◢ 🏆 TACTICAL RELIC & GEAR EVOLUTION (보스 정복 전설/신화 아티팩트)"
	rtitle.add_theme_font_size_override("font_size", 16)
	rtitle.add_theme_color_override("font_color", Color("e9d5ff"))
	rvbox.add_child(rtitle)

	for rel in AXDataRegistryClass.get_stage_relics():
		var c_hex := str(rel.get("color_hex", "#ffd940"))
		var rcard := _create_tactical_panel(Color("0a0f18"), Color(c_hex), 1, 6, 5)
		rvbox.add_child(rcard)
		var rhbox := HBoxContainer.new()
		rhbox.add_theme_constant_override("separation", 10)
		rcard.add_child(rhbox)

		var rbadge := _create_badge("OP-0%d · %s" % [int(rel.get("stage_num", 1)), str(rel.get("rarity", ""))], Color(c_hex), Color("080c12"))
		rhbox.add_child(rbadge)

		var rinfo := Label.new()
		rinfo.text = "%s (%s)  —  %s" % [
			str(rel.get("name_ko", "")),
			str(rel.get("title_ko", "")),
			str(rel.get("effect_desc", ""))
		]
		rinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rinfo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rinfo.add_theme_font_size_override("font_size", 13)
		rinfo.add_theme_color_override("font_color", Color("f1f5f9"))
		rhbox.add_child(rinfo)


# ==============================================================================
# SEARCH RESULTS & RAW JSON VIEWS
# ==============================================================================
func _build_search_results_view(query: String) -> void:
	var results := AXDataRegistryClass.search_entries(query)
	var header := Label.new()
	header.text = "🔍 TACTICAL SEARCH '%s' : %d MATCHES FOUND" % [query, results.size()]
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color("00e5ff"))
	_content_vbox.add_child(header)

	if results.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "일치하는 전술 데이터가 없습니다. 다른 키워드(예: 성기사, 골렘, 패링, Stage)를 입력해 보세요."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		_content_vbox.add_child(empty_lbl)
		return

	for item in results:
		var card := _create_tactical_panel(Color("0f1824"), Color("00e5ff"), 1, 8, 5)
		_content_vbox.add_child(card)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var t := Label.new()
		t.text = "◢ [%s] %s  (CODE: %s)" % [str(item.get("category", "")), str(item.get("title", "")), str(item.get("id", ""))]
		t.add_theme_font_size_override("font_size", 15)
		t.add_theme_color_override("font_color", Color("ffb800"))
		vbox.add_child(t)

		var s := Label.new()
		s.text = str(item.get("summary", ""))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", Color("cbd5e1"))
		vbox.add_child(s)


func _build_raw_json_view() -> void:
	var raw_dict := AXDataRegistryClass.load_ax_data()
	var json_str := JSON.stringify(raw_dict, "  ")
	var panel := _create_tactical_panel(Color("060a10"), Color("00e5ff"), 1, 8, 4)
	_content_vbox.add_child(panel)

	var code_lbl := Label.new()
	code_lbl.text = json_str
	code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_lbl.add_theme_font_size_override("font_size", 12)
	code_lbl.add_theme_color_override("font_color", Color("6ee7b7"))
	panel.add_child(code_lbl)


# ==============================================================================
# HEROES WAR TACTICAL UI HELPERS
# ==============================================================================
func _create_unit_portrait_box(sprite_path: String, cols: int, rows: int, accent_col: Color, rank_str: String) -> PanelContainer:
	var box := _create_tactical_panel(Color("070c14"), accent_col, 1, 6, 3)
	box.custom_minimum_size = Vector2(68, 68)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	box.add_child(vbox)

	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var tex := load(sprite_path) as Texture2D
		if tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			var fw := float(tex.get_width()) / float(maxi(1, cols))
			var fh := float(tex.get_height()) / float(maxi(1, rows))
			atlas.region = Rect2(0, 0, fw, fh)

			var trect := TextureRect.new()
			trect.texture = atlas
			trect.custom_minimum_size = Vector2(44, 44)
			trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			vbox.add_child(trect)

	var rlbl := Label.new()
	rlbl.text = rank_str
	rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rlbl.add_theme_font_size_override("font_size", 10)
	rlbl.add_theme_color_override("font_color", accent_col)
	vbox.add_child(rlbl)

	return box


func _create_badge(text_str: String, bg_col: Color, fg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)

	var l := Label.new()
	l.text = text_str
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", fg_col)
	p.add_child(l)
	return p


func _add_kpi_card(parent: Control, title_text: String, value_text: String, sub_text: String, accent: Color) -> void:
	var card := _create_tactical_panel(Color("0e1722"), accent, 1, 8, 5)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var t := Label.new()
	t.text = "◢ " + title_text
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Color("94a3b8"))
	vbox.add_child(t)

	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 18)
	v.add_theme_color_override("font_color", accent)
	vbox.add_child(v)

	var s := Label.new()
	s.text = sub_text
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_theme_font_size_override("font_size", 11)
	s.add_theme_color_override("font_color", Color("cbd5e1"))
	vbox.add_child(s)


func _add_stat_bar_row(parent: Control, label_text: String, val: float, max_val: float, display_val: String, bar_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("cbd5e1"))
	row.add_child(lbl)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color("060a10")
	bar_bg.custom_minimum_size = Vector2(125, 12)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar_bg)

	var ratio := clampf(val / maxf(max_val, 0.001), 0.05, 1.0)
	var bar_fill := ColorRect.new()
	bar_fill.color = bar_color
	bar_fill.size = Vector2(125.0 * ratio, 12)
	bar_bg.add_child(bar_fill)

	var v_lbl := Label.new()
	v_lbl.text = display_val
	v_lbl.add_theme_font_size_override("font_size", 12)
	v_lbl.add_theme_color_override("font_color", Color("f8fafc"))
	row.add_child(v_lbl)


func _create_tactical_panel(bg_col: Color, border_col: Color, border_w: int, radius: int, left_accent_w: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(border_w)
	style.border_width_left = maxi(border_w, left_accent_w)
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _style_tactical_button(btn: Button, bg_col: Color, border_col: Color, left_w: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(1)
	normal.border_width_left = left_w
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_col.lightened(0.15)
	hover.border_color = Color("ffb800")
	hover.set_border_width_all(2)
	hover.border_width_left = left_w + 2
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
