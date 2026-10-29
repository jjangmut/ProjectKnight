class_name AXDataViewer
extends Control
## AXDataViewer:
## Project Knight의 모든 기획 데이터(AX Data)를 인게임에서 탭/검색/시각화 카드로 열람할 수 있는 대시보드 페이지.

signal viewer_closed
signal tab_changed(tab_index: int)

const AXDataRegistryClass := preload("res://scripts/data/ax_data_registry.gd")

const TAB_NAMES: Array[String] = [
	"📊 전체 개요",
	"⚔ 플레이어 & 전투",
	"🏰 스테이지 1~5",
	"👾 몬스터 도감",
	"👑 보스 & 패턴",
	"🔥 성소 & 유물"
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
	# 1. Deep Gothic Backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.09, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer Margin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# 2. Top Header Bar
	var header_panel := _create_styled_panel(Color("101923"), Color("ddc18a"), 2, 10)
	header_panel.custom_minimum_size = Vector2(0, 62)
	root_vbox.add_child(header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	header_panel.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	var meta := AXDataRegistryClass.get_meta_info()
	var title_lbl := Label.new()
	title_lbl.text = "📘 PROJECT KNIGHT — AX 기획 데이터 마스터 뷰어 (v%s)" % str(meta.get("ax_schema_version", "2.0.0"))
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color("f0e6d2"))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s  |  %s" % [str(meta.get("title_ko", "")), str(meta.get("engine", ""))]
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color("9aaeb8"))
	title_vbox.add_child(sub_lbl)

	# Search Input
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "🔍 키워드 검색 (패링, 골렘, 심판관...)"
	_search_input.custom_minimum_size = Vector2(220, 34)
	_search_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_input.add_theme_font_size_override("font_size", 13)
	_search_input.text_changed.connect(_on_search_text_changed)
	header_hbox.add_child(_search_input)

	# Raw JSON Toggle Button
	_json_toggle_btn = Button.new()
	_json_toggle_btn.text = "{ } JSON 원본"
	_json_toggle_btn.custom_minimum_size = Vector2(104, 34)
	_json_toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_json_toggle_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_json_toggle_btn, Color("1b2b38"), Color("6ee7b7"))
	_json_toggle_btn.pressed.connect(_on_toggle_raw_json)
	header_hbox.add_child(_json_toggle_btn)

	# Close Button
	_close_btn = Button.new()
	_close_btn.name = "BtnCloseAXViewer"
	_close_btn.text = "✖ 닫기"
	_close_btn.custom_minimum_size = Vector2(88, 34)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_btn.add_theme_font_size_override("font_size", 14)
	_style_button(_close_btn, Color("381b24"), Color("f87171"))
	_close_btn.pressed.connect(_on_close_pressed)
	header_hbox.add_child(_close_btn)

	# 3. Category Tab Bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tab_bar)

	_tab_buttons.clear()
	for i in range(TAB_NAMES.size()):
		var tbtn := Button.new()
		tbtn.text = TAB_NAMES[i]
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.custom_minimum_size = Vector2(0, 42)
		tbtn.add_theme_font_size_override("font_size", 15)
		var idx := i
		tbtn.pressed.connect(func(): select_tab(idx))
		tab_bar.add_child(tbtn)
		_tab_buttons.append(tbtn)

	# 4. Main Content Scroll Area
	var content_panel := _create_styled_panel(Color("0b1118"), Color("2d4252"), 1, 8)
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_panel)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(_content_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 14)
	_content_scroll.add_child(_content_vbox)

	# 5. Footer Status Bar
	var footer_hbox := HBoxContainer.new()
	root_vbox.add_child(footer_hbox)

	_status_footer_label = Label.new()
	_status_footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_footer_label.add_theme_font_size_override("font_size", 13)
	_status_footer_label.add_theme_color_override("font_color", Color("7b93a4"))
	footer_hbox.add_child(_status_footer_label)

	var path_lbl := Label.new()
	path_lbl.text = "Source: res://data/ax_data/project_knight_ax_data.json  |  Web: DOCS/ax_data_viewer.html"
	path_lbl.add_theme_font_size_override("font_size", 13)
	path_lbl.add_theme_color_override("font_color", Color("6ee7b7"))
	footer_hbox.add_child(path_lbl)


func select_tab(tab_idx: int) -> void:
	current_tab = clampi(tab_idx, 0, TAB_NAMES.size() - 1)
	show_raw_json = false
	_json_toggle_btn.text = "{ } JSON 원본"
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
	_json_toggle_btn.text = "📋 카드 뷰로 보기" if show_raw_json else "{ } JSON 원본"
	_rebuild_content()


func _on_close_pressed() -> void:
	viewer_closed.emit()
	queue_free()


func _update_tab_button_styles() -> void:
	for i in range(_tab_buttons.size()):
		var btn := _tab_buttons[i]
		if i == current_tab and not show_raw_json and search_query.is_empty():
			_style_button(btn, Color("294152"), Color("ddc18a"))
			btn.add_theme_color_override("font_color", Color("fff4d6"))
		else:
			_style_button(btn, Color("131e28"), Color("385060"))
			btn.add_theme_color_override("font_color", Color("9aaeb8"))


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
	_status_footer_label.text = "AX Data 검증 완료: 스테이지 %d개 · 몬스터 %d종 · 보스 %d종(패턴 %d개) · 플레이어 액션 %d종 · 성소/유물 %d종" % [
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
# TAB 0: OVERVIEW
# ==============================================================================
func _build_overview_tab() -> void:
	var meta := AXDataRegistryClass.get_meta_info()
	var metrics := AXDataRegistryClass.get_summary_metrics()
	var rules := AXDataRegistryClass.get_combat_rules()

	# Hero Summary Banner
	var hero := _create_styled_panel(Color("13202c"), Color("ddc18a"), 1, 8)
	_content_vbox.add_child(hero)
	var hvbox := VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 6)
	hero.add_child(hvbox)

	var htitle := Label.new()
	htitle.text = "🏛 %s (%s)" % [str(meta.get("title_ko", "")), str(meta.get("project_id", ""))]
	htitle.add_theme_font_size_override("font_size", 20)
	htitle.add_theme_color_override("font_color", Color("ddc18a"))
	hvbox.add_child(htitle)

	var hdesc := Label.new()
	hdesc.text = str(meta.get("description", ""))
	hdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hdesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdesc.add_theme_font_size_override("font_size", 13)
	hdesc.add_theme_color_override("font_color", Color("d0dde6"))
	hvbox.add_child(hdesc)

	# Metric KPI Grid (6 KPI Cards)
	var kpi_grid := GridContainer.new()
	kpi_grid.columns = 3
	kpi_grid.add_theme_constant_override("h_separation", 12)
	kpi_grid.add_theme_constant_override("v_separation", 12)
	_content_vbox.add_child(kpi_grid)

	_add_kpi_card(kpi_grid, "🏰 캠페인 스테이지", "%d 개 지역" % int(metrics.get("stage_count", 5)), "Stage 1 성문 외곽 ~ Stage 5 침묵의 성채", Color("60a5fa"))
	_add_kpi_card(kpi_grid, "👑 보스 & 시그니처 패턴", "보스 %d종 / 패턴 %d종" % [int(metrics.get("boss_count", 5)), int(metrics.get("boss_pattern_count", 17))], "전 보스 2페이즈 각성 및 전용 기믹 탑재", Color("f87171"))
	_add_kpi_card(kpi_grid, "👾 일반/엘리트 몬스터", "%d 종 아키타입" % int(metrics.get("enemy_type_count", 5)), "보병 · 도약 맹수 · 석궁병 · 거석 골렘 · 심연 기사", Color("34d399"))
	_add_kpi_card(kpi_grid, "⚔ 플레이어 액션 상태", "%d 종 애니메이션" % int(metrics.get("player_anim_count", 8)), "3단 성검 찌르기 · 신성 관통창 검기 · 저스트 패링", Color("fbbf24"))
	_add_kpi_card(kpi_grid, "🔥 성소 강화 & 유물", "강화 %d종 / 유물 %d종" % [int(metrics.get("shop_item_count", 5)), int(metrics.get("relic_count", 5))], "영혼 파편 영구 성장 및 보스 격파 전설/신화 유물", Color("c084fc"))
	_add_kpi_card(kpi_grid, "🎥 카메라 & 물리 규격", "Pitch -32° / FOV 42°", "사이드 쿼터뷰 벨트스크롤 · 충돌 정지 및 4면 경계벽", Color("38bdf8"))

	# Progression & Camera Rules Card
	var flow_panel := _create_styled_panel(Color("111b24"), Color("3b5568"), 1, 8)
	_content_vbox.add_child(flow_panel)
	var fvbox := VBoxContainer.new()
	fvbox.add_theme_constant_override("separation", 8)
	flow_panel.add_child(fvbox)

	var ftitle := Label.new()
	ftitle.text = "🧭 핵심 게임플레이 루프 및 물리 규칙 (Core Progression & Physics Rules)"
	ftitle.add_theme_font_size_override("font_size", 17)
	ftitle.add_theme_color_override("font_color", Color("6ee7b7"))
	fvbox.add_child(ftitle)

	var pflow: Dictionary = rules.get("progression_flow", {})
	var cphys: Dictionary = rules.get("collision_and_physics", {})
	var lines := [
		"• [Wave 1 전진 전투] %s" % str(pflow.get("wave_1", "")),
		"• [웨이브 클리어 보상] %s" % str(pflow.get("wave_clear_reward", "")),
		"• [보스 조우 트리거] %s" % str(pflow.get("boss_trigger", "")),
		"• [스테이지 클리어] %s" % str(pflow.get("stage_clear", "")),
		"• [충돌 및 경계 물리] %s (X 정지 거리 %.2fm, Z 정지 거리 %.2fm)" % [
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
		lbl.add_theme_color_override("font_color", Color("c8d6e0"))
		fvbox.add_child(lbl)


# ==============================================================================
# TAB 1: PLAYER & COMBAT
# ==============================================================================
func _build_player_combat_tab() -> void:
	var p := AXDataRegistryClass.get_player_data()
	var stats: Dictionary = p.get("base_stats", {})
	var combat: Dictionary = p.get("combat", {})
	var parry: Dictionary = p.get("defense_parry", {})
	var beam: Dictionary = combat.get("finisher_beam", {})

	# Player Base Stats & Combat Formula Split
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(top_hbox)

	# Left: Base Stats Card
	var stat_panel := _create_styled_panel(Color("121d28"), Color("60a5fa"), 1, 8)
	stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(stat_panel)
	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 8)
	stat_panel.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "🛡 %s (%s) 기본 기동 스탯" % [str(p.get("name_ko", "")), str(p.get("name_en", ""))]
	stitle.add_theme_font_size_override("font_size", 17)
	stitle.add_theme_color_override("font_color", Color("93c5fd"))
	svbox.add_child(stitle)

	_add_stat_bar_row(svbox, "최대 체력 (Max HP)", float(stats.get("max_hp", 8)), 12.0, "%d HP" % int(stats.get("max_hp", 8)), Color("ef4444"))
	_add_stat_bar_row(svbox, "횡이동 속도 (Speed X)", float(stats.get("move_speed_x", 7.5)), 15.0, "%.1f m/s" % float(stats.get("move_speed_x", 7.5)), Color("38bdf8"))
	_add_stat_bar_row(svbox, "종이동 속도 (Depth Z)", float(stats.get("move_speed_z", 4.8)), 15.0, "%.1f m/s" % float(stats.get("move_speed_z", 4.8)), Color("34d399"))
	_add_stat_bar_row(svbox, "회피 대시 속도 (Dash)", float(stats.get("dash_speed", 14.0)), 20.0, "%.1f m/s (%.2fs)" % [float(stats.get("dash_speed", 14.0)), float(stats.get("dash_duration", 0.22))], Color("a855f7"))
	_add_stat_bar_row(svbox, "도약 속도 (Jump)", float(stats.get("jump_velocity", 6.8)), 12.0, "%.1f m/s (중력 %.1f)" % [float(stats.get("jump_velocity", 6.8)), float(stats.get("gravity", 18.0))], Color("f59e0b"))
	_add_stat_bar_row(svbox, "피격 무적 (i-Frame)", float(stats.get("hit_invuln_duration", 0.65)), 1.5, "%.2f 초" % float(stats.get("hit_invuln_duration", 0.65)), Color("eab308"))

	# Right: Combat & Parry Card
	var cpanel := _create_styled_panel(Color("121d28"), Color("fbbf24"), 1, 8)
	cpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(cpanel)
	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 8)
	cpanel.add_child(cvbox)

	var ctitle := Label.new()
	ctitle.text = "⚔ 3단 성검 콤보 & 저스트 패링 판정 공식"
	ctitle.add_theme_font_size_override("font_size", 17)
	ctitle.add_theme_color_override("font_color", Color("fde68a"))
	cvbox.add_child(ctitle)

	var clines := [
		"• 기본 공격력: %d DMG (타격 지속 %.2fs / 쿨타임 %.2fs / 콤보 유지 %.2fs)" % [
			int(combat.get("base_attack_damage", 2)),
			float(combat.get("attack_duration", 0.20)),
			float(combat.get("attack_cooldown", 0.22)),
			float(combat.get("combo_reset_timer", 0.95))
		],
		"• 하이브리드 근접 판정 범위: 전방 X %.2fm × 깊이 Z ±%.2fm (100%% 적중 보장)" % [
			float(combat.get("melee_reach_x", 2.9)),
			float(combat.get("melee_depth_z", 1.65))
		],
		"• %s: 탄속 %.1f m/s · 사거리 %.1fm · 관통 피해 %d DMG" % [
			str(beam.get("name_ko", "3단 피니셔 검기")),
			float(beam.get("speed", 20.0)),
			float(beam.get("max_range", 24.0)),
			int(beam.get("damage", 2))
		],
		"• 저스트 패링 윈도우: %.2f초 이내 가드 시 피해 100%% 무효화 + 적 %.1f초 스턴" % [
			float(parry.get("just_parry_window", 0.14)),
			float(parry.get("parry_enemy_stun_sec", 2.0))
		],
		"• 패링 카운터 각성: %.1f초간 다음 공격 %.0f배 피해 (%d DMG 황금 강타)" % [
			float(parry.get("counter_buff_duration", 3.5)),
			float(parry.get("counter_damage_multiplier", 3.0)),
			int(parry.get("counter_attack_damage", 6))
		],
		"• 일반 가드 방어율: 패링 타이밍 이후 방패 유지 시 피해 50% 경감"
	]
	for cl in clines:
		var l := Label.new()
		l.text = cl
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color("e2e8f0"))
		cvbox.add_child(l)

	# Bottom: Animation Frame Sheet Table
	var anim_panel := _create_styled_panel(Color("101820"), Color("4b6a78"), 1, 8)
	_content_vbox.add_child(anim_panel)
	var avbox := VBoxContainer.new()
	avbox.add_theme_constant_override("separation", 6)
	anim_panel.add_child(avbox)

	var atitle := Label.new()
	atitle.text = "🎞 플레이어 상태별 스프라이트 시트 & 프레임 규격 (780×780 무게중심 정렬)"
	atitle.add_theme_font_size_override("font_size", 16)
	atitle.add_theme_color_override("font_color", Color("ddc18a"))
	avbox.add_child(atitle)

	for anim in p.get("animations", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		avbox.add_child(row)

		var badge := Label.new()
		badge.text = "[%s]" % str(anim.get("state", ""))
		badge.custom_minimum_size = Vector2(90, 0)
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color("6ee7b7"))
		row.add_child(badge)

		var sheet_lbl := Label.new()
		sheet_lbl.text = "%s (%s · %.0f FPS)" % [str(anim.get("sheet", "")), str(anim.get("grid", "")), float(anim.get("fps", 8.0))]
		sheet_lbl.custom_minimum_size = Vector2(290, 0)
		sheet_lbl.add_theme_font_size_override("font_size", 14)
		sheet_lbl.add_theme_color_override("font_color", Color("93c5fd"))
		row.add_child(sheet_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(anim.get("desc", ""))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color("cbd5e1"))
		row.add_child(desc_lbl)


# ==============================================================================
# TAB 2: STAGES 1~5
# ==============================================================================
func _build_stages_tab() -> void:
	for s in AXDataRegistryClass.get_stages():
		var amb_hex := str(s.get("ambient_color", "#60a5fa"))
		var card := _create_styled_panel(Color("111b24"), Color(amb_hex), 2, 8)
		_content_vbox.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 12)
		vbox.add_child(header)

		var swatch := ColorRect.new()
		swatch.color = Color(amb_hex)
		swatch.custom_minimum_size = Vector2(22, 22)
		header.add_child(swatch)

		var title := Label.new()
		title.text = "STAGE %d — %s (%s)" % [int(s.get("stage_num", 1)), str(s.get("name_ko", "")), str(s.get("name_en", ""))]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("f0e6d2"))
		header.add_child(title)

		var boss_badge := Label.new()
		boss_badge.text = "👑 보스: %s" % str(s.get("boss_name_ko", ""))
		boss_badge.add_theme_font_size_override("font_size", 15)
		boss_badge.add_theme_color_override("font_color", Color("fca5a5"))
		header.add_child(boss_badge)

		var arena_arr: Array = s.get("arena_size_m", [38.0, 12.0])
		var props_arr: Array = s.get("environment_props", [])
		var props_str := ", ".join(PackedStringArray(props_arr))

		var wave_strs := PackedStringArray()
		for w in s.get("wave_1_enemies", []):
			wave_strs.append("%s × %d기" % [str(w.get("name_ko", "")), int(w.get("count", 2))])

		var info_lbl := Label.new()
		info_lbl.text = "• 테마: %s  |  아레나 크기: %.0fm × %.0fm  |  포그 밀도: %.3f\n• 환경 프롭: %s\n• Wave 1 구성: %s  ➔  웨이브 정리 시 +%d HP 성스러운 회복  ➔  클리어 유물: [%s]" % [
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
# TAB 3: ENEMIES
# ==============================================================================
func _build_enemies_tab() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content_vbox.add_child(grid)

	for e in AXDataRegistryClass.get_enemies():
		var card := _create_styled_panel(Color("121d27"), Color("34d399"), 1, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		var title := Label.new()
		title.text = "[Stage %d] %s (%s)" % [int(e.get("stage_num", 1)), str(e.get("name_ko", "")), str(e.get("name_en", ""))]
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", Color("6ee7b7"))
		vbox.add_child(title)

		var role_lbl := Label.new()
		role_lbl.text = "역할군: %s  |  ID: %s" % [str(e.get("role", "")), str(e.get("id", ""))]
		role_lbl.add_theme_font_size_override("font_size", 13)
		role_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		vbox.add_child(role_lbl)

		_add_stat_bar_row(vbox, "체력 (HP)", float(e.get("hp", 4)), 10.0, "%d HP" % int(e.get("hp", 4)), Color("ef4444"))
		_add_stat_bar_row(vbox, "이동 속도", float(e.get("move_speed", 3.5)), 10.0, "%.1f m/s" % float(e.get("move_speed", 3.5)), Color("38bdf8"))
		_add_stat_bar_row(vbox, "공격력 / 주기", float(e.get("attack_damage", 1)), 4.0, "%d DMG (%.1fs 쿨타임)" % [int(e.get("attack_damage", 1)), float(e.get("attack_cooldown", 1.2))], Color("f59e0b"))

		var mech := Label.new()
		mech.text = "💡 고유 행동: %s" % str(e.get("special_mechanic", ""))
		mech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mech.add_theme_font_size_override("font_size", 13)
		mech.add_theme_color_override("font_color", Color("e2e8f0"))
		vbox.add_child(mech)


# ==============================================================================
# TAB 4: BOSSES & PATTERNS
# ==============================================================================
func _build_bosses_tab() -> void:
	for b in AXDataRegistryClass.get_bosses():
		var card := _create_styled_panel(Color("161926"), Color("f87171"), 2, 8)
		_content_vbox.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		vbox.add_child(hbox)

		var title := Label.new()
		title.text = "👑 [Stage %d 보스] %s — %s" % [int(b.get("stage_num", 1)), str(b.get("name_ko", "")), str(b.get("title_ko", ""))]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("fca5a5"))
		hbox.add_child(title)

		var stat_badge := Label.new()
		stat_badge.text = "HP %d  |  1페이즈 속도 %.1f ➔ 2페이즈(HP 50%%↓) 속도 %.1f" % [
			int(b.get("hp", 24)),
			float(b.get("move_speed_p1", 3.8)),
			float(b.get("move_speed_p2", 4.8))
		]
		stat_badge.add_theme_font_size_override("font_size", 14)
		stat_badge.add_theme_color_override("font_color", Color("fde68a"))
		hbox.add_child(stat_badge)

		# Patterns List
		var pats: Array = b.get("patterns", [])
		for pat in pats:
			var pbox := _create_styled_panel(Color("0f141d"), Color("334155"), 1, 6)
			vbox.add_child(pbox)
			var pvbox := VBoxContainer.new()
			pvbox.add_theme_constant_override("separation", 2)
			pbox.add_child(pvbox)

			var phead := Label.new()
			phead.text = "⚡ [%s] %s (%s)  —  피해량: %d DMG  |  %s" % [
				str(pat.get("id", "")),
				str(pat.get("name_ko", "")),
				str(pat.get("name_en", "")),
				int(pat.get("damage", 2)),
				str(pat.get("metrics", ""))
			]
			phead.add_theme_font_size_override("font_size", 14)
			phead.add_theme_color_override("font_color", Color("93c5fd"))
			pvbox.add_child(phead)

			var pdesc := Label.new()
			pdesc.text = "   ↳ %s" % str(pat.get("desc", ""))
			pdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pdesc.add_theme_font_size_override("font_size", 13)
			pdesc.add_theme_color_override("font_color", Color("cbd5e1"))
			pvbox.add_child(pdesc)


# ==============================================================================
# TAB 5: SANCTUARY SHOP & RELICS
# ==============================================================================
func _build_sanctuary_tab() -> void:
	# 1. Sanctuary Shop Upgrades
	var shop_panel := _create_styled_panel(Color("121d26"), Color("ddc18a"), 1, 8)
	_content_vbox.add_child(shop_panel)
	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 8)
	shop_panel.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "🔥 화톳불의 영혼 제단 (Campfire Soul Altar) 영구 강화 테이블"
	stitle.add_theme_font_size_override("font_size", 18)
	stitle.add_theme_color_override("font_color", Color("ddc18a"))
	svbox.add_child(stitle)

	for item in AXDataRegistryClass.get_shop_items():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		svbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = "• %s" % str(item.get("name_ko", ""))
		name_lbl.custom_minimum_size = Vector2(290, 0)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color("f0e6d2"))
		row.add_child(name_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "%d 파편 (최대 %dLv)" % [int(item.get("cost_shards", 0)), int(item.get("max_level", 1))]
		cost_lbl.custom_minimum_size = Vector2(160, 0)
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.add_theme_color_override("font_color", Color("38bdf8"))
		row.add_child(cost_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(item.get("effect_desc", ""))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color("cbd5e1"))
		row.add_child(desc_lbl)

	# 2. Stage Relics
	var relic_panel := _create_styled_panel(Color("141824"), Color("c084fc"), 1, 8)
	_content_vbox.add_child(relic_panel)
	var rvbox := VBoxContainer.new()
	rvbox.add_theme_constant_override("separation", 10)
	relic_panel.add_child(rvbox)

	var rtitle := Label.new()
	rtitle.text = "🏆 스테이지 보스 정복 유물 & 외형 진화 (Stage Relics & Visual Evolution)"
	rtitle.add_theme_font_size_override("font_size", 18)
	rtitle.add_theme_color_override("font_color", Color("e9d5ff"))
	rvbox.add_child(rtitle)

	for rel in AXDataRegistryClass.get_stage_relics():
		var c_hex := str(rel.get("color_hex", "#ffd940"))
		var rcard := _create_styled_panel(Color("0e131d"), Color(c_hex), 1, 6)
		rvbox.add_child(rcard)
		var rhbox := HBoxContainer.new()
		rhbox.add_theme_constant_override("separation", 12)
		rcard.add_child(rhbox)

		var swatch := ColorRect.new()
		swatch.color = Color(c_hex)
		swatch.custom_minimum_size = Vector2(18, 18)
		rhbox.add_child(swatch)

		var rinfo := Label.new()
		rinfo.text = "[Stage %d · %s] %s (%s)  —  %s" % [
			int(rel.get("stage_num", 1)),
			str(rel.get("rarity", "")),
			str(rel.get("name_ko", "")),
			str(rel.get("title_ko", "")),
			str(rel.get("effect_desc", ""))
		]
		rinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rinfo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rinfo.add_theme_font_size_override("font_size", 14)
		rinfo.add_theme_color_override("font_color", Color("f1f5f9"))
		rhbox.add_child(rinfo)


# ==============================================================================
# SEARCH RESULTS & RAW JSON VIEWS
# ==============================================================================
func _build_search_results_view(query: String) -> void:
	var results := AXDataRegistryClass.search_entries(query)
	var header := Label.new()
	header.text = "🔍 '%s' 검색 결과: 총 %d 건 일치" % [query, results.size()]
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color("6ee7b7"))
	_content_vbox.add_child(header)

	if results.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "일치하는 AX 기획 데이터가 없습니다. 다른 키워드(예: 성기사, 골렘, 패링, Stage)를 입력해 보세요."
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color("94a3b8"))
		_content_vbox.add_child(empty_lbl)
		return

	for item in results:
		var card := _create_styled_panel(Color("121d28"), Color("38bdf8"), 1, 8)
		_content_vbox.add_child(card)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var t := Label.new()
		t.text = "[%s] %s  (ID: %s)" % [str(item.get("category", "")), str(item.get("title", "")), str(item.get("id", ""))]
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color("f0e6d2"))
		vbox.add_child(t)

		var s := Label.new()
		s.text = str(item.get("summary", ""))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override("font_size", 14)
		s.add_theme_color_override("font_color", Color("cbd5e1"))
		vbox.add_child(s)


func _build_raw_json_view() -> void:
	var raw_dict := AXDataRegistryClass.load_ax_data()
	var json_str := JSON.stringify(raw_dict, "  ")
	var panel := _create_styled_panel(Color("090d12"), Color("6ee7b7"), 1, 8)
	_content_vbox.add_child(panel)

	var code_lbl := Label.new()
	code_lbl.text = json_str
	code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_lbl.add_theme_font_size_override("font_size", 13)
	code_lbl.add_theme_color_override("font_color", Color("a7f3d0"))
	panel.add_child(code_lbl)


# ==============================================================================
# UI HELPERS
# ==============================================================================
func _add_kpi_card(parent: Control, title_text: String, value_text: String, sub_text: String, accent: Color) -> void:
	var card := _create_styled_panel(Color("121c26"), accent, 1, 8)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color("94a3b8"))
	vbox.add_child(t)

	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 20)
	v.add_theme_color_override("font_color", accent)
	vbox.add_child(v)

	var s := Label.new()
	s.text = sub_text
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color("cbd5e1"))
	vbox.add_child(s)


func _add_stat_bar_row(parent: Control, label_text: String, val: float, max_val: float, display_val: String, bar_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(145, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("cbd5e1"))
	row.add_child(lbl)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.08, 0.12, 0.18, 1.0)
	bar_bg.custom_minimum_size = Vector2(130, 14)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar_bg)

	var ratio := clampf(val / maxf(max_val, 0.001), 0.05, 1.0)
	var bar_fill := ColorRect.new()
	bar_fill.color = bar_color
	bar_fill.size = Vector2(130.0 * ratio, 14)
	bar_bg.add_child(bar_fill)

	var v_lbl := Label.new()
	v_lbl.text = display_val
	v_lbl.add_theme_font_size_override("font_size", 13)
	v_lbl.add_theme_color_override("font_color", Color("f8fafc"))
	row.add_child(v_lbl)


func _create_styled_panel(bg_col: Color, border_col: Color, border_w: int, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _style_button(btn: Button, bg_col: Color, border_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_col.lightened(0.15)
	hover.border_color = Color("ddc18a")
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
