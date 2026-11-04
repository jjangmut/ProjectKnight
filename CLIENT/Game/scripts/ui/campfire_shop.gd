class_name CampfireShop
extends Control
## Campfire Soul Altar (화톳불 상점):
## Allows players to spend collected Soul Shards to acquire permanent stat upgrades.

signal shop_closed
signal upgrade_purchased(upgrade_id: String)

const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const AudioManager = preload("res://scripts/audio/audio_manager.gd")
const GameFeelManager = preload("res://scripts/system/game_feel_manager.gd")
const AdManagerClass = preload("res://scripts/system/ad_manager.gd")

var _shard_label: Label
var _hp_btn: Button
var _dmg_btn: Button
var _dash_btn: Button
var _heal_btn: Button
var _ad_boost_btn: Button
var _vamp_btn: Button
var _thunder_btn: Button
var _aegis_btn: Button
var target_player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_ui()


func _build_ui() -> void:
	# Dark modal backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel_box := VBoxContainer.new()
	panel_box.custom_minimum_size = Vector2(960, 640)
	panel_box.add_theme_constant_override("separation", 16)
	center.add_child(panel_box)

	# Title (2x Scale)
	var title := Label.new()
	title.text = "화톳불의 영혼 제단 (Campfire Soul Altar)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("ddc18a"))
	panel_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "영혼 파편을 바쳐 기사의 육체와 칼날을 영구히 강화합니다."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", Color("9aaeb8"))
	panel_box.add_child(subtitle)

	# Shard Balance (2x Scale)
	_shard_label = Label.new()
	_shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shard_label.add_theme_font_size_override("font_size", 38)
	_shard_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	panel_box.add_child(_shard_label)

	var sep := HSeparator.new()
	panel_box.add_child(sep)

	# Scrollable Items Container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(scroll)

	var items_box := VBoxContainer.new()
	items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_box.add_theme_constant_override("separation", 10)
	scroll.add_child(items_box)

	var stat_title := Label.new()
	stat_title.text = "❖ 기본 스탯 & 액션 강화 (Basic Upgrades)"
	stat_title.add_theme_font_size_override("font_size", 22)
	stat_title.add_theme_color_override("font_color", Color("fbbf24"))
	items_box.add_child(stat_title)

	_hp_btn = _create_shop_button("생명의 축복 (Max HP +1)", 25, _on_buy_hp)
	items_box.add_child(_hp_btn)

	_dmg_btn = _create_shop_button("칼날 연마 (Attack Power +1)", 35, _on_buy_dmg)
	items_box.add_child(_dmg_btn)

	_dash_btn = _create_shop_button("그림자 걸음 (Shadow Dash)", 50, _on_buy_dash)
	items_box.add_child(_dash_btn)

	_heal_btn = _create_shop_button("영혼의 성유 (체력 완전 회복)", 10, _on_buy_heal)
	items_box.add_child(_heal_btn)

	var rune_sep := HSeparator.new()
	items_box.add_child(rune_sep)

	var rune_title := Label.new()
	rune_title.text = "❖ 고대 룬 각인 시스템 (Ancient Runic Engravings)"
	rune_title.add_theme_font_size_override("font_size", 22)
	rune_title.add_theme_color_override("font_color", Color("38bdf8"))
	items_box.add_child(rune_title)

	_vamp_btn = _create_shop_button("흡혈의 칼날 (Vampiric Edge - 3콤보 적중 시 체력 1 회복)", 60, func(): _on_buy_engraving("vampiric_edge", 60))
	items_box.add_child(_vamp_btn)

	_thunder_btn = _create_shop_button("뇌전의 걸음 (Thunder Step - 대시 궤적 번개 관통 1 피해)", 55, func(): _on_buy_engraving("thunder_step", 55))
	items_box.add_child(_thunder_btn)

	_aegis_btn = _create_shop_button("이지스 반사 (Aegis Reflect - 저스트 패링 시 2 데미지 즉시 반사)", 65, func(): _on_buy_engraving("aegis_reflect", 65))
	items_box.add_child(_aegis_btn)

	var ad_sep := HSeparator.new()
	items_box.add_child(ad_sep)

	_ad_boost_btn = _create_ad_button("🎬 성소의 기도 (후원 영상 시청 시 파편 +30개 즉시 획득)", _on_watch_ad_boost)
	items_box.add_child(_ad_boost_btn)

	var sep2 := HSeparator.new()
	panel_box.add_child(sep2)

	# Close Button (2x Scale)
	var close_btn := Button.new()
	close_btn.text = "여정으로 돌아가기 (Close)"
	close_btn.custom_minimum_size.y = 70
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.pressed.connect(_on_close_pressed)
	panel_box.add_child(close_btn)


func _create_ad_button(label_text: String, on_click: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size.y = 72
	btn.add_theme_font_size_override("font_size", 26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e2f1e")
	style.border_color = Color("6ee7b7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("2b442b")
	hover.border_color = Color("a7f3d0")
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.pressed.connect(on_click)
	return btn


func _on_watch_ad_boost() -> void:
	AdManagerClass.show_rewarded_ad("shard_boost_30", self, func():
		SaveManagerClass.add_shards(30)
		AudioManager.play("pogo_bounce", global_position)
		GameFeelManager.shake(0.12)
		_refresh_ui()
	)


func _create_shop_button(label_text: String, cost: int, on_click: Callable) -> Button:
	var btn := Button.new()
	btn.text = "%s  —  %d Shards" % [label_text, cost]
	btn.custom_minimum_size.y = 72
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(on_click)
	return btn


func _refresh_ui() -> void:
	var shards := SaveManagerClass.get_shards()
	_shard_label.text = "보유 영혼 파편: %d 개" % shards

	var hp_lvl := SaveManagerClass.get_upgrade_level("hp_boost")
	if hp_lvl >= 2:
		_hp_btn.text = "생명의 축복 (Max HP +1) [ 최대 레벨 완료: +2 HP ]"
		_hp_btn.disabled = true
	else:
		_hp_btn.text = "생명의 축복 (Max HP +1) [ 현재: +%d HP ] — 25 Shards" % hp_lvl
		_hp_btn.disabled = (shards < 25)

	var dmg_lvl := SaveManagerClass.get_upgrade_level("dmg_boost")
	if dmg_lvl >= 1:
		_dmg_btn.text = "칼날 연마 (Attack Power +1) [ 최대 레벨 완료: +1 DMG ]"
		_dmg_btn.disabled = true
	else:
		_dmg_btn.text = "칼날 연마 (Attack Power +1) — 35 Shards"
		_dmg_btn.disabled = (shards < 35)

	var dash_lvl := SaveManagerClass.get_upgrade_level("shadow_dash")
	if dash_lvl >= 1:
		_dash_btn.text = "그림자 걸음 (Shadow Dash) [ 습득 완료 ]"
		_dash_btn.disabled = true
	else:
		_dash_btn.text = "그림자 걸음 (Shadow Dash) — 50 Shards"
		_dash_btn.disabled = (shards < 50)

	_heal_btn.disabled = (shards < 10)

	# Runic Engravings Status
	if SaveManagerClass.is_engraving_unlocked("vampiric_edge"):
		_vamp_btn.text = "흡혈의 칼날 (Vampiric Edge) [ 각인 완료 ]"
		_vamp_btn.disabled = true
	else:
		_vamp_btn.text = "흡혈의 칼날 (3단 콤보 피니셔 시 HP 1 흡수) — 60 Shards"
		_vamp_btn.disabled = (shards < 60)

	if SaveManagerClass.is_engraving_unlocked("thunder_step"):
		_thunder_btn.text = "뇌전의 걸음 (Thunder Step) [ 각인 완료 ]"
		_thunder_btn.disabled = true
	else:
		_thunder_btn.text = "뇌전의 걸음 (대시 궤적 번개 관통 1 피해) — 55 Shards"
		_thunder_btn.disabled = (shards < 55)

	if SaveManagerClass.is_engraving_unlocked("aegis_reflect"):
		_aegis_btn.text = "이지스 반사 (Aegis Reflect) [ 각인 완료 ]"
		_aegis_btn.disabled = true
	else:
		_aegis_btn.text = "이지스 반사 (저스트 패링 시 2 데미지 즉시 반사) — 65 Shards"
		_aegis_btn.disabled = (shards < 65)


func _on_buy_engraving(engraving_id: String, cost: int) -> void:
	if SaveManagerClass.unlock_engraving(engraving_id, cost):
		AudioManager.play("counter_hit", global_position)
		GameFeelManager.shake(0.22)
		if is_instance_valid(target_player):
			SaveManagerClass.apply_upgrades_to_player(target_player)
		_refresh_ui()
		upgrade_purchased.emit(engraving_id)


func _on_buy_hp() -> void:
	if SaveManagerClass.purchase_upgrade("hp_boost", 25, 2):
		AudioManager.play("pogo_bounce", global_position)
		GameFeelManager.shake(0.15)
		if is_instance_valid(target_player):
			SaveManagerClass.apply_upgrades_to_player(target_player)
		_refresh_ui()
		upgrade_purchased.emit("hp_boost")


func _on_buy_dmg() -> void:
	if SaveManagerClass.purchase_upgrade("dmg_boost", 35, 1):
		AudioManager.play("counter_hit", global_position)
		GameFeelManager.shake(0.20)
		if is_instance_valid(target_player):
			SaveManagerClass.apply_upgrades_to_player(target_player)
		_refresh_ui()
		upgrade_purchased.emit("dmg_boost")


func _on_buy_dash() -> void:
	if SaveManagerClass.purchase_upgrade("shadow_dash", 50, 1):
		AudioManager.play("counter_hit", global_position)
		GameFeelManager.shake(0.25)
		if is_instance_valid(target_player):
			SaveManagerClass.apply_upgrades_to_player(target_player)
		_refresh_ui()
		upgrade_purchased.emit("shadow_dash")



func _on_buy_heal() -> void:
	var shards := SaveManagerClass.get_shards()
	if shards >= 10:
		SaveManagerClass.add_shards(-10)
		AudioManager.play("guard_clang", global_position)
		if is_instance_valid(target_player) and "max_hp" in target_player:
			target_player.current_hp = target_player.max_hp
		_refresh_ui()
		upgrade_purchased.emit("heal_full")


func _on_close_pressed() -> void:
	shop_closed.emit()
	queue_free()
