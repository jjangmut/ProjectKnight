class_name TitleScreen
extends Control
## Commercial Main Title Screen Shell for Project Knight.
## Provides New Game, Continue, Sanctuary Shop, Settings (Audio/Controls), and Credits.
## Fully responsive for mobile and desktop displays.

const SaveManagerClass := preload("res://scripts/system/save_manager.gd")
const CampfireShopClass := preload("res://scripts/ui/campfire_shop.gd")
const CAMPAIGN_SCENE_PATH := "res://scenes/stage/Campaign.tscn"

var btn_new_game: Button
var btn_continue: Button
var btn_shop: Button
var btn_settings: Button
var btn_credits: Button

var save_summary_label: Label
var modal_container: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_update_save_summary()
	AudioManager.ensure_manager(self)
	AudioManager.bgm("exploration")

func _build_ui() -> void:
	# 1. Dark Atmospheric Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.09, 1.0)
	add_child(bg)

	# Atmospheric decorative rune lines
	var deco_rect := ColorRect.new()
	deco_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco_rect.color = Color(0.15, 0.25, 0.40, 0.12)
	add_child(deco_rect)

	# 2. Main Centered Layout
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.custom_minimum_size = Vector2(620, 520)
	main_vbox.add_theme_constant_override("separation", 16)
	center.add_child(main_vbox)

	# Title Header
	var title_lbl := Label.new()
	title_lbl.text = "PROJECT KNIGHT"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 46)
	title_lbl.add_theme_color_override("font_color", Color("f0e6d2"))
	main_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "— 결의의 기사와 심연의 성채 —"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 20)
	subtitle_lbl.add_theme_color_override("font_color", Color("ddc18a"))
	main_vbox.add_child(subtitle_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer)

	# Menu Buttons
	var has_save := SaveManagerClass.has_save_file()

	btn_continue = _create_menu_button("🛡  여정 이어하기 (Continue)", _on_continue_pressed)
	main_vbox.add_child(btn_continue)
	btn_continue.disabled = not has_save

	btn_new_game = _create_menu_button("⚔  새로운 여정 시작 (New Game)", _on_new_game_pressed)
	main_vbox.add_child(btn_new_game)

	btn_shop = _create_menu_button("🔥  성소 제단 강화 (Sanctuary)", _on_shop_pressed)
	main_vbox.add_child(btn_shop)

	btn_settings = _create_menu_button("⚙  게임 설정 (Settings)", _on_settings_pressed)
	main_vbox.add_child(btn_settings)

	btn_credits = _create_menu_button("📜  제작진 (Credits)", _on_credits_pressed)
	main_vbox.add_child(btn_credits)

	# Save Summary & Version Footer
	save_summary_label = Label.new()
	save_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_summary_label.add_theme_font_size_override("font_size", 16)
	save_summary_label.add_theme_color_override("font_color", Color("8ea4b0"))
	main_vbox.add_child(save_summary_label)

	var version_lbl := Label.new()
	version_lbl.text = "v1.0.0 Commercial Release Build · Junypapa Studio"
	version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_lbl.add_theme_font_size_override("font_size", 13)
	version_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.6))
	main_vbox.add_child(version_lbl)

func _update_save_summary() -> void:
	if SaveManagerClass.has_save_file():
		var data := SaveManagerClass.load_game()
		var stage_idx: int = int(data.get("stage_index", 0))
		var shards: int = SaveManagerClass.get_shards()
		var stages := ["1지역: 성문 외곽", "2지역: 야수숲", "3지역: 무너진 성벽", "4지역: 돌의 성소", "5지역: 침묵의 성채"]
		var stage_name: String = stages[stage_idx] if stage_idx < stages.size() else "알 수 없음"
		save_summary_label.text = "기록된 진행도: [%s]  ·  영혼 파편: %d개" % [stage_name, shards]
		if btn_continue:
			btn_continue.disabled = false
	else:
		save_summary_label.text = "기록된 여정이 없습니다. 새로운 여정을 시작하세요."
		if btn_continue:
			btn_continue.disabled = true

func _create_menu_button(title: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(440, 56)
	btn.add_theme_font_size_override("font_size", 20)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("1a2b35")
	normal_style.border_color = Color("4b6a78")
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("284352")
	hover_style.border_color = Color("ddc18a")
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

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
	dim.color = Color(0, 0, 0, 0.75)
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 440)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color("141e28")
	pstyle.border_color = Color("ddc18a")
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var mtitle := Label.new()
	mtitle.text = "⚙  게임 환경 설정 (Settings)"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 24)
	mtitle.add_theme_color_override("font_color", Color("ddc18a"))
	vbox.add_child(mtitle)

	# BGM Volume Slider
	var bgm_box := HBoxContainer.new()
	var bgm_lbl := Label.new()
	bgm_lbl.text = "배경음악 (BGM):"
	bgm_lbl.custom_minimum_size = Vector2(160, 0)
	bgm_lbl.add_theme_font_size_override("font_size", 18)
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
	no_ads_lbl.add_theme_font_size_override("font_size", 18)
	no_ads_box.add_child(no_ads_lbl)

	var btn_toggle_ads := Button.new()
	var current_no_ads := SaveManagerClass.is_ad_free()
	btn_toggle_ads.text = "💎 VIP 적용 중 (무광고 즉시 수령)" if current_no_ads else "💎 광고 제거 패키지 ($2.99)"
	btn_toggle_ads.custom_minimum_size = Vector2(260, 40)
	btn_toggle_ads.add_theme_font_size_override("font_size", 16)
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
	guide_title.text = "📱 모바일 및 PC 조작 안내"
	guide_title.add_theme_font_size_override("font_size", 18)
	guide_title.add_theme_color_override("font_color", Color("6ee7b7"))
	guide_box.add_child(guide_title)

	var guide_text := Label.new()
	guide_text.text = "• 좌측 조이패드: 위(점프) · 아래(발판 하강) · 좌/우(이동) · 대각선(점프이동)\n• 우측 액션: ⚔ 공격(우하단) · 💨 대시(좌하단) · 🛡 방패(상단)\n• PC 키보드: A/D(이동) · Space(점프) · S(하강) · J(공격) · K(방패) · Shift(대시)"
	guide_text.add_theme_font_size_override("font_size", 15)
	guide_text.add_theme_color_override("font_color", Color("c0d0d8"))
	guide_box.add_child(guide_text)
	vbox.add_child(guide_box)

	# Close Button
	var btn_close := Button.new()
	btn_close.text = "닫기 (Save & Close)"
	btn_close.custom_minimum_size = Vector2(200, 48)
	btn_close.add_theme_font_size_override("font_size", 18)
	btn_close.pressed.connect(func(): modal.queue_free())
	vbox.add_child(btn_close)

func _open_credits_modal() -> void:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(modal)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 360)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color("141e28")
	pstyle.border_color = Color("ddc18a")
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var mtitle := Label.new()
	mtitle.text = "📜  JUNYPAPA STUDIO"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 24)
	mtitle.add_theme_color_override("font_color", Color("ddc18a"))
	vbox.add_child(mtitle)

	var ctext := Label.new()
	ctext.text = "Project Knight: The Resolute Paladin\n\n• 총괄 디렉터: Studio Director\n• 게임 디자인 & 프로덕션: Studio Manager\n• 클라이언트 & 물리 엔진: Client Lead Engineer\n• 아트 & 프레젠테이션: Art Director & UI Specialist\n• 품질 검증: Autonomous QA Specialist\n\n© 2026 JUNYPAPA STUDIO. All rights reserved."
	ctext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctext.add_theme_font_size_override("font_size", 15)
	ctext.add_theme_color_override("font_color", Color("b0c4de"))
	vbox.add_child(ctext)

	var btn_close := Button.new()
	btn_close.text = "확인"
	btn_close.custom_minimum_size = Vector2(160, 44)
	btn_close.add_theme_font_size_override("font_size", 17)
	btn_close.pressed.connect(func(): modal.queue_free())
	vbox.add_child(btn_close)
