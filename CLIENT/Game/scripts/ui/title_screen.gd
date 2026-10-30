class_name TitleScreen
extends Control
## Heroes War Concept — Tactical Command Lobby & Main Title Screen for Project Knight.
## Features:
## - Top Tactical Status Header (Commander Rank, Combat Power, Soul Shards, AP)
## - Left Hero Showcase Briefing Card (Live Paladin Atlas Portrait, Class Badge, Skill Tags, Save Status)
## - Right Slanted Tactical Operation Deck (Continue, Deploy New Campaign, Sanctuary Lab, AX Tactical Codex, Config, Credits)

const SaveManagerClass := preload("res://scripts/system/save_manager.gd")
const CampfireShopClass := preload("res://scripts/ui/campfire_shop.gd")
const AXDataViewerClass := preload("res://scripts/ui/ax_data_viewer.gd")
const TexPaladinIdle := preload("res://assets/player_frames/idle_v1_aligned.png")
const TexAvatarFrame := preload("res://assets/ui/hud_player_avatar_frame.png")

const CAMPAIGN_SCENE_PATH := "res://scenes/side_quarter_view/SideQVCampaign.tscn"
const LEGACY_2D_CAMPAIGN_SCENE_PATH := "res://scenes/stage/Campaign.tscn"

var btn_new_game: Button
var btn_continue: Button
var btn_shop: Button
var btn_ax_data: Button
var btn_settings: Button
var btn_credits: Button

var save_summary_label: Label
var _header_shards_label: Label
var _cp_label: Label
var modal_container: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_update_save_summary()
	AudioManager.ensure_manager(self)
	AudioManager.bgm("exploration")


func _build_ui() -> void:
	# 1. Deep Tactical Gunmetal Backdrop
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("070b11")
	add_child(bg)

	# Tactical Diagonal Grid / Accent Stripe Overlay
	var top_glow := ColorRect.new()
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.custom_minimum_size = Vector2(0, 4)
	top_glow.color = Color("ffb800")
	add_child(top_glow)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# ==========================================================================
	# 2. TOP TACTICAL COMMAND STATUS BAR (Heroes War Top Bar)
	# ==========================================================================
	var top_bar := _create_tactical_panel(Color("0f1722"), Color("00e5ff"), 2, 6, 4)
	top_bar.custom_minimum_size = Vector2(0, 56)
	root_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_hbox)

	var cmd_badge := _create_tag_badge("◢ COMMAND HQ", Color("ffb800"), Color("090d14"))
	top_hbox.add_child(cmd_badge)

	var game_title_box := VBoxContainer.new()
	game_title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_title_box.add_theme_constant_override("separation", 0)
	top_hbox.add_child(game_title_box)

	var title_lbl := Label.new()
	title_lbl.text = "PROJECT KNIGHT : COUNTERATTACK"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color("f8fafc"))
	game_title_box.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "HEROES WAR TACTICAL ACTION EDITION  ·  SIDE QUARTER-VIEW 3D"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color("00e5ff"))
	game_title_box.add_child(sub_lbl)

	# Resource & Combat Power Pills
	_cp_label = _create_resource_pill("⚔ 작전 전투력 (CP): 14,850", Color("ffb800"))
	top_hbox.add_child(_cp_label)

	_header_shards_label = _create_resource_pill("💎 영혼 파편: 0", Color("38bdf8"))
	top_hbox.add_child(_header_shards_label)

	var ap_pill := _create_resource_pill("⚡ 행동력 (AP): 120 / 120", Color("34d399"))
	top_hbox.add_child(ap_pill)

	# ==========================================================================
	# 3. MAIN SPLIT BODY: LEFT HERO SHOWCASE + RIGHT TACTICAL OPERATION DECK
	# ==========================================================================
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 18)
	root_vbox.add_child(body_hbox)

	# --- LEFT: HERO SHOWCASE & UNIT BRIEFING PANEL ---
	var hero_panel := _create_tactical_panel(Color("0d1520"), Color("ffb800"), 2, 10, 6)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_stretch_ratio = 1.08
	body_hbox.add_child(hero_panel)

	var hero_vbox := VBoxContainer.new()
	hero_vbox.add_theme_constant_override("separation", 10)
	hero_panel.add_child(hero_vbox)

	# Hero Header Row
	var hero_head := HBoxContainer.new()
	hero_head.add_theme_constant_override("separation", 10)
	hero_vbox.add_child(hero_head)

	var ssr_badge := _create_tag_badge("SSR · VANGUARD", Color("ff3b5c"), Color("ffffff"))
	hero_head.add_child(ssr_badge)

	var hero_name_lbl := Label.new()
	hero_name_lbl.text = "결의의 성기사 (RESOLUTE PALADIN)"
	hero_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_name_lbl.add_theme_font_size_override("font_size", 19)
	hero_name_lbl.add_theme_color_override("font_color", Color("ffb800"))
	hero_head.add_child(hero_name_lbl)

	# Hero Center Showcase (Portrait + Tactical Specs)
	var showcase_hbox := HBoxContainer.new()
	showcase_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_hbox.add_theme_constant_override("separation", 14)
	hero_vbox.add_child(showcase_hbox)

	# Portrait Frame with Paladin Idle Frame 0
	var portrait_card := _create_tactical_panel(Color("080d14"), Color("00e5ff"), 1, 8, 3)
	portrait_card.custom_minimum_size = Vector2(210, 230)
	showcase_hbox.add_child(portrait_card)

	var portrait_vbox := VBoxContainer.new()
	portrait_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_card.add_child(portrait_vbox)

	var paladin_tex_rect := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = TexPaladinIdle
	atlas.region = Rect2(0, 0, float(TexPaladinIdle.get_width()) * 0.5, float(TexPaladinIdle.get_height()) * 0.5)
	paladin_tex_rect.texture = atlas
	paladin_tex_rect.custom_minimum_size = Vector2(180, 180)
	paladin_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paladin_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_vbox.add_child(paladin_tex_rect)

	var pedestal_lbl := Label.new()
	pedestal_lbl.text = "▲ ACTIVE UNIT : PALADIN-01 ▲"
	pedestal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pedestal_lbl.add_theme_font_size_override("font_size", 11)
	pedestal_lbl.add_theme_color_override("font_color", Color("00e5ff"))
	portrait_vbox.add_child(pedestal_lbl)

	# Right side of Hero Panel: Tactical Spec Bars & Skill Deck Preview
	var spec_vbox := VBoxContainer.new()
	spec_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spec_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	spec_vbox.add_theme_constant_override("separation", 8)
	showcase_hbox.add_child(spec_vbox)

	var spec_title := Label.new()
	spec_title.text = "◢ TACTICAL COMBAT PARAMETERS"
	spec_title.add_theme_font_size_override("font_size", 13)
	spec_title.add_theme_color_override("font_color", Color("00e5ff"))
	spec_vbox.add_child(spec_title)

	_add_tactical_stat_row(spec_vbox, "DURABILITY (HP)", "8 SOUL GEMS", 0.82, Color("ff3b5c"))
	_add_tactical_stat_row(spec_vbox, "MOBILITY (SPD)", "7.5 m/s (DASH 14.0)", 0.78, Color("00e5ff"))
	_add_tactical_stat_row(spec_vbox, "3-COMBO LANCE", "2 DMG + HOLY BEAM", 0.88, Color("ffb800"))
	_add_tactical_stat_row(spec_vbox, "AEGIS PARRY", "0.14s (300% COUNTER)", 0.95, Color("34d399"))

	var skill_chips_box := HBoxContainer.new()
	skill_chips_box.add_theme_constant_override("separation", 6)
	spec_vbox.add_child(skill_chips_box)
	skill_chips_box.add_child(_create_tag_badge("⚔ 성검 3연격", Color("1e293b"), Color("fbbf24")))
	skill_chips_box.add_child(_create_tag_badge("⚡ 관통창 검기", Color("1e293b"), Color("38bdf8")))
	skill_chips_box.add_child(_create_tag_badge("🛡 이지스 반격", Color("1e293b"), Color("6ee7b7")))

	# Save Status Readout Banner inside Hero Panel
	var save_banner := _create_tactical_panel(Color("091018"), Color("334155"), 1, 6, 3)
	hero_vbox.add_child(save_banner)

	save_summary_label = Label.new()
	save_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_summary_label.add_theme_font_size_override("font_size", 14)
	save_summary_label.add_theme_color_override("font_color", Color("6ee7b7"))
	save_banner.add_child(save_summary_label)

	# --- RIGHT: TACTICAL OPERATION COMMAND DECK ---
	var deck_panel := _create_tactical_panel(Color("0d1520"), Color("00e5ff"), 2, 10, 6)
	deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_stretch_ratio = 0.95
	body_hbox.add_child(deck_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	deck_panel.add_child(main_vbox)

	var deck_header := Label.new()
	deck_header.text = "◢ TACTICAL OPERATION TERMINAL (작전 출격 제어실)"
	deck_header.add_theme_font_size_override("font_size", 15)
	deck_header.add_theme_color_override("font_color", Color("00e5ff"))
	main_vbox.add_child(deck_header)

	var has_save := SaveManagerClass.has_save_file()

	# Primary Operation Buttons (Heroes War Angled/Accent Style)
	btn_continue = _create_tactical_menu_button(
		"◢ 🛡  작전 재개 : 여정 이어하기 (CONTINUE)",
		_on_continue_pressed,
		Color("132838"),
		Color("00e5ff"),
		56
	)
	main_vbox.add_child(btn_continue)
	btn_continue.disabled = not has_save

	btn_new_game = _create_tactical_menu_button(
		"◢ ⚔  작전 출격 : 새로운 여정 시작 (DEPLOY CAMPAIGN)",
		_on_new_game_pressed,
		Color("3b2308"),
		Color("ffb800"),
		62
	)
	main_vbox.add_child(btn_new_game)

	btn_shop = _create_tactical_menu_button(
		"◢ 🔥  웨폰 & 코어 연구소 : 성소 강화 (SANCTUARY LAB)",
		_on_shop_pressed,
		Color("1a1f30"),
		Color("c084fc"),
		54
	)
	main_vbox.add_child(btn_shop)

	btn_ax_data = _create_tactical_menu_button(
		"◢ 📊  AX 택티컬 데이터 도감 (AX TACTICAL CODEX)",
		_on_ax_data_pressed,
		Color("102a2a"),
		Color("34d399"),
		54
	)
	main_vbox.add_child(btn_ax_data)

	# Bottom Row: Settings & Credits Side-by-Side
	var util_hbox := HBoxContainer.new()
	util_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(util_hbox)

	btn_settings = _create_tactical_menu_button(
		"⚙ 시스템 설정 (CONFIG)",
		_on_settings_pressed,
		Color("141e2b"),
		Color("64748b"),
		48
	)
	btn_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_hbox.add_child(btn_settings)

	btn_credits = _create_tactical_menu_button(
		"📜 제작진 (CREDITS)",
		_on_credits_pressed,
		Color("141e2b"),
		Color("64748b"),
		48
	)
	btn_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_hbox.add_child(btn_credits)

	# ==========================================================================
	# 4. FOOTER STATUS BAR
	# ==========================================================================
	var footer_hbox := HBoxContainer.new()
	root_vbox.add_child(footer_hbox)

	var sys_lbl := Label.new()
	sys_lbl.text = "● SYSTEM ONLINE  |  HEROES WAR UI CONCEPT v2.0  |  5 OPERATIONS & 5 BOSS THREATS READY"
	sys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_lbl.add_theme_font_size_override("font_size", 12)
	sys_lbl.add_theme_color_override("font_color", Color("64748b"))
	footer_hbox.add_child(sys_lbl)

	var version_lbl := Label.new()
	version_lbl.text = "v2.0.0 Heroes War Tactical Build · JUNYPAPA STUDIO"
	version_lbl.add_theme_font_size_override("font_size", 12)
	version_lbl.add_theme_color_override("font_color", Color("94a3b8"))
	footer_hbox.add_child(version_lbl)


func _update_save_summary() -> void:
	var shards: int = SaveManagerClass.get_shards()
	if _header_shards_label != null:
		_header_shards_label.text = "💎 영혼 파편: %d" % shards

	var hp_lvl := SaveManagerClass.get_upgrade_level("hp_boost")
	var dmg_lvl := SaveManagerClass.get_upgrade_level("dmg_boost")
	var dash_lvl := SaveManagerClass.get_upgrade_level("shadow_dash")
	var cp_val := 14850 + (hp_lvl * 1200) + (dmg_lvl * 2500) + (dash_lvl * 1800)
	if _cp_label != null:
		_cp_label.text = "⚔ 작전 전투력 (CP): %d" % cp_val

	if SaveManagerClass.has_save_file():
		var data := SaveManagerClass.load_game()
		var stage_idx: int = int(data.get("stage_index", 0))
		var stages := ["1지역: 성문 외곽", "2지역: 야수숲", "3지역: 무너진 성벽", "4지역: 돌의 성소", "5지역: 침묵의 성채"]
		var stage_name: String = stages[stage_idx] if stage_idx < stages.size() else "알 수 없음"
		save_summary_label.text = "기록된 진행도: [%s]  ·  영혼 파편: %d개" % [stage_name, shards]
		if btn_continue:
			btn_continue.disabled = false
	else:
		save_summary_label.text = "기록된 여정이 없습니다. 새로운 여정을 시작하세요."
		if btn_continue:
			btn_continue.disabled = true


func _create_tactical_panel(bg_col: Color, border_col: Color, border_w: int, corner_r: int, left_accent_w: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(border_w)
	style.border_width_left = maxi(border_w, left_accent_w)
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_top_right = corner_r
	style.corner_radius_bottom_left = corner_r
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_tag_badge(text_str: String, bg_col: Color, fg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)

	var l := Label.new()
	l.text = text_str
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", fg_col)
	p.add_child(l)
	return p


func _create_resource_pill(text_str: String, accent_col: Color) -> Label:
	var l := Label.new()
	l.text = text_str
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", accent_col)
	return l


func _add_tactical_stat_row(parent: Control, name_str: String, val_str: String, ratio: float, bar_col: Color) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var nl := Label.new()
	nl.text = name_str
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.add_theme_font_size_override("font_size", 12)
	nl.add_theme_color_override("font_color", Color("94a3b8"))
	hbox.add_child(nl)

	var vl := Label.new()
	vl.text = val_str
	vl.add_theme_font_size_override("font_size", 12)
	vl.add_theme_color_override("font_color", Color("f8fafc"))
	hbox.add_child(vl)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color("060a10")
	bar_bg.custom_minimum_size = Vector2(220, 8)
	vbox.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.color = bar_col
	bar_fill.size = Vector2(220.0 * clampf(ratio, 0.05, 1.0), 8)
	bar_bg.add_child(bar_fill)


func _create_tactical_menu_button(title: String, callback: Callable, bg_col: Color, accent_col: Color, min_h: float) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color("f8fafc"))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_col
	normal_style.border_color = accent_col
	normal_style.set_border_width_all(2)
	normal_style.border_width_left = 8
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.content_margin_left = 16
	normal_style.content_margin_right = 14
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = bg_col.lightened(0.18)
	hover_style.border_color = Color("ffb800")
	hover_style.set_border_width_all(2)
	hover_style.border_width_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_left = 10
	hover_style.content_margin_left = 16
	hover_style.content_margin_right = 14
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color("0a0f16")
	disabled_style.border_color = Color("1e293b")
	disabled_style.set_border_width_all(1)
	disabled_style.border_width_left = 4
	disabled_style.content_margin_left = 16
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.pressed.connect(callback)
	return btn


func _on_continue_pressed() -> void:
	_launch_campaign(false)


func _on_new_game_pressed() -> void:
	SaveManagerClass.clear_save()
	_launch_campaign(true)


func _launch_campaign(_is_new: bool) -> void:
	get_tree().change_scene_to_file(CAMPAIGN_SCENE_PATH)


func _on_shop_pressed() -> void:
	var shop := CampfireShopClass.new()
	shop.name = "CampfireShop"
	add_child(shop)
	shop.shop_closed.connect(func(): _update_save_summary())


func _on_ax_data_pressed() -> void:
	var viewer := AXDataViewerClass.new()
	viewer.name = "AXDataViewer"
	add_child(viewer)


func _on_settings_pressed() -> void:
	_open_settings_modal()


func _on_credits_pressed() -> void:
	_open_credits_modal()


func _open_settings_modal() -> void:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(modal)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.78)
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := _create_tactical_panel(Color("0f1722"), Color("00e5ff"), 2, 12, 8)
	panel.custom_minimum_size = Vector2(600, 440)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var mtitle := Label.new()
	mtitle.text = "◢ ⚙  TACTICAL SYSTEM CONFIG (환경 설정)"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 22)
	mtitle.add_theme_color_override("font_color", Color("ffb800"))
	vbox.add_child(mtitle)

	# BGM Volume Slider
	var bgm_box := HBoxContainer.new()
	var bgm_lbl := Label.new()
	bgm_lbl.text = "배경음악 (BGM):"
	bgm_lbl.custom_minimum_size = Vector2(160, 0)
	bgm_lbl.add_theme_font_size_override("font_size", 17)
	bgm_box.add_child(bgm_lbl)

	var bgm_slider := HSlider.new()
	bgm_slider.custom_minimum_size = Vector2(280, 32)
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	bgm_slider.value = 0.8
	bgm_slider.value_changed.connect(func(v: float): AudioManager.set_bgm_volume(v))
	bgm_box.add_child(bgm_slider)
	vbox.add_child(bgm_box)

	# VIP No-Ads Commercial Option
	var no_ads_box := HBoxContainer.new()
	var no_ads_lbl := Label.new()
	no_ads_lbl.text = "광고 제거 VIP (No-Ads):"
	no_ads_lbl.custom_minimum_size = Vector2(200, 0)
	no_ads_lbl.add_theme_font_size_override("font_size", 17)
	no_ads_box.add_child(no_ads_lbl)

	var btn_toggle_ads := Button.new()
	var current_no_ads := SaveManagerClass.is_ad_free()
	btn_toggle_ads.text = "💎 VIP 적용 중 (무광고 즉시 수령)" if current_no_ads else "💎 광고 제거 패키지 ($2.99)"
	btn_toggle_ads.custom_minimum_size = Vector2(260, 40)
	btn_toggle_ads.add_theme_font_size_override("font_size", 15)
	btn_toggle_ads.pressed.connect(func():
		var new_state := not SaveManagerClass.is_ad_free()
		SaveManagerClass.set_ad_free(new_state)
		btn_toggle_ads.text = "💎 VIP 적용 중 (무광고 즉시 수령)" if new_state else "💎 광고 제거 패키지 ($2.99)"
		_update_save_summary()
	)
	no_ads_box.add_child(btn_toggle_ads)
	vbox.add_child(no_ads_box)

	# Controls Guide Box
	var guide_box := VBoxContainer.new()
	var guide_title := Label.new()
	guide_title.text = "📱 HEROES WAR 택티컬 덱 & PC 키보드 조작 안내"
	guide_title.add_theme_font_size_override("font_size", 16)
	guide_title.add_theme_color_override("font_color", Color("00e5ff"))
	guide_box.add_child(guide_title)

	var guide_text := Label.new()
	guide_text.text = "• 좌측 레이더 스틱: 360도 전술 기동 (X축 전진/후퇴 · Z축 깊이 이동)\n• 우측 택티컬 스킬 덱: ⚔ STRIKE(3단 콤보/검기) · 🛡 PARRY(0.14s 패링) · 💨 DASH(무적 회피) · ▲ LEAP(도약)\n• PC 키보드: W/A/S/D(이동) · Space(점프) · J/Z(공격) · K/X(방패 패링) · Shift/C(대시)"
	guide_text.add_theme_font_size_override("font_size", 14)
	guide_text.add_theme_color_override("font_color", Color("cbd5e1"))
	guide_box.add_child(guide_text)
	vbox.add_child(guide_box)

	var btn_close := _create_tactical_menu_button("✖ 설정 저장 및 닫기 (SAVE & CLOSE)", func(): modal.queue_free(), Color("281822"), Color("ff3b5c"), 46)
	vbox.add_child(btn_close)


func _open_credits_modal() -> void:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(modal)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.78)
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := _create_tactical_panel(Color("0f1722"), Color("ffb800"), 2, 12, 8)
	panel.custom_minimum_size = Vector2(520, 360)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var mtitle := Label.new()
	mtitle.text = "◢ 📜  JUNYPAPA STUDIO — COMMAND CREDITS"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 22)
	mtitle.add_theme_color_override("font_color", Color("ffb800"))
	vbox.add_child(mtitle)

	var ctext := Label.new()
	ctext.text = "Project Knight: Counterattack (Heroes War UI Edition)\n\n• 총괄 디렉터: Studio Director\n• 택티컬 시스템 & AX 데이터 설계: Studio Manager\n• 3D 쿼터뷰 물리 엔진: Client Lead Engineer\n• 히어로즈 워 UI & VFX 디렉션: Art Director & UI Specialist\n• 자율 주행 QA 검수: Autonomous QA Specialist\n\n© 2026 JUNYPAPA STUDIO. All rights reserved."
	ctext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctext.add_theme_font_size_override("font_size", 14)
	ctext.add_theme_color_override("font_color", Color("cbd5e1"))
	vbox.add_child(ctext)

	var btn_close := _create_tactical_menu_button("✔ 확인 (CLOSE)", func(): modal.queue_free(), Color("132838"), Color("00e5ff"), 44)
	vbox.add_child(btn_close)
