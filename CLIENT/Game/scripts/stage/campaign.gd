extends Node
## Five-stage session and persistent campaign owner. Integrates with SaveManager.
const STAGES := [preload("res://scenes/stage/FirstStage.tscn"), preload("res://scenes/stage/SecondStage.tscn"), preload("res://scenes/stage/ThirdStage.tscn"), preload("res://scenes/stage/FourthStage.tscn"), preload("res://scenes/stage/FifthStage.tscn")]
const REGION_NAMES := ["성문 외곽", "야수숲", "무너진 성벽", "돌의 성소", "침묵의 성채"]
const SaveManagerClass := preload("res://scripts/system/save_manager.gd")
const CampfireShopClass := preload("res://scripts/ui/campfire_shop.gd")
const AdManagerClass := preload("res://scripts/system/ad_manager.gd")
var stage: Node2D
var stage_index := 0
var selected_trait := "basic"
var cleared: Array[bool] = [false, false, false, false, false]
var transitioning := false
var panel: Control
var route_note: Label
var transition_generation := 0
var last_cleared_shards: int = 0
var ad_bonus_claimed: bool = false

func _ready() -> void:
	if SaveManagerClass.has_save_file():
		var saved := SaveManagerClass.load_game()
		stage_index = saved.get("stage_index", 0)
		selected_trait = saved.get("selected_trait", "basic")
		cleared = saved.get("cleared", [false, false, false, false, false])
	_start_stage(stage_index)

func _start_stage(index: int, checkpoint: bool = false) -> void:
	var saved_snapshot: Dictionary = stage.get_checkpoint_snapshot() if checkpoint and is_instance_valid(stage) else {}
	transition_generation += 1
	get_tree().paused = false
	ad_bonus_claimed = false
	AdManagerClass.reset_run_ad_counters()
	for action in ["move_left", "move_right", "attack", "jump", "guard"]:
		Input.action_release(action)
	if is_instance_valid(panel):
		panel.queue_free()
		panel = null
	if is_instance_valid(stage):
		stage.queue_free()
		stage = null
	stage_index = index
	stage = STAGES[index].instantiate()
	stage.campaign_mode = true
	stage.stage_finished.connect(_on_stage_finished)
	add_child(stage)
	# Apply once to each fresh player, never accumulate modifiers on a reset.
	stage.player.attack_range = 90.0 if selected_trait == "reach" else 72.0
	stage.player.attack_cooldown = 0.40 if selected_trait == "reach" else 0.32
	stage.player._update_attack_geometry()
	stage.player.set_meta("equipped_trait", selected_trait)
	if checkpoint:
		stage.resume_snapshot(saved_snapshot)
	transitioning = false

func _on_stage_finished(result: int) -> void:
	if transitioning:
		return
	transitioning = true
	var generation := transition_generation
	var checkpoint: bool = result == 2
	await get_tree().create_timer(1.5, false).timeout
	if not is_inside_tree() or generation != transition_generation:
		return
	if result == 2:
		_start_stage(stage_index, checkpoint)
	else:
		cleared[stage_index] = true
		var player_shards: int = 0
		if is_instance_valid(stage) and is_instance_valid(stage.player) and "soul_shards" in stage.player:
			player_shards = stage.player.soul_shards
		last_cleared_shards = player_shards
		if player_shards > 0:
			SaveManagerClass.add_shards(player_shards)
		var current_shards := SaveManagerClass.get_shards()
		SaveManagerClass.save_game(stage_index, selected_trait, cleared, {"soul_shards": current_shards})
		_show_route_panel()


func choose_trait(value: String) -> void:
	if not is_instance_valid(panel) or not cleared[0] or stage_index != 0 or value not in ["basic", "reach"]:
		return
	selected_trait = value
	SaveManagerClass.save_game(1, selected_trait, cleared)
	_start_stage.call_deferred(1)

func restart_journey() -> void:
	if not is_instance_valid(panel) or not cleared[4]:
		return
	selected_trait = "basic"
	cleared = [false, false, false, false, false]
	SaveManagerClass.clear_save()
	_start_stage.call_deferred(0)

func continue_journey() -> void:
	if is_instance_valid(panel) and stage_index > 0 and stage_index < 4 and cleared[stage_index]:
		var next_idx := stage_index + 1
		SaveManagerClass.save_game(next_idx, selected_trait, cleared)
		_start_stage.call_deferred(next_idx)

func _show_route_panel() -> void:
	var layer := stage.get_node("HUD") as CanvasLayer
	stage.get_node("HUD/Presentation").visible = false
	if is_instance_valid(stage) and stage.get("mobile_controls") != null and is_instance_valid(stage.mobile_controls):
		stage.mobile_controls.visible = false
		stage.mobile_controls.release_all_touches()
		stage.mobile_controls.process_mode = Node.PROCESS_MODE_DISABLED
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(590, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := Label.new()
	title.text = "외곽 돌파 · 다음은 야수숲" if stage_index == 0 else "다섯 지역의 여정을 마쳤습니다" if stage_index == 4 else "%s 돌파" % REGION_NAMES[stage_index]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("ddc18a"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.text = "특성 1슬롯 · 다음 지역에서 사용할 전투 방식을 선택하세요\n체력과 공격 피해는 그대로입니다. 전투 중에는 바꿀 수 없습니다." if stage_index == 0 else "성채의 마지막 방어선을 넘어 길을 열었습니다.\n선택한 검술과 다섯 지역의 경험으로 완주했습니다." if stage_index == 4 else "다음 지역: %s\n선택한 검술은 유지되고 새 지역에서 HP 3으로 출발합니다." % REGION_NAMES[stage_index + 1]
	box.add_child(subtitle)
	if stage_index == 0:
		_button(box, "기본 검술  ·  사거리 72 / 재공격 0.32초", choose_trait.bind("basic"))
		_button(box, "긴 칼날  ·  사거리 90 / 재공격 0.40초", choose_trait.bind("reach"))
	elif stage_index < 4:
		_button(box, "다음 지역으로 → %s" % REGION_NAMES[stage_index + 1], continue_journey)
	else:
		_button(box, "처음부터 다시 도전", restart_journey)
	_button(box, "🔥 화톳불의 영혼 제단 (능력 강화 상점)", _open_campfire_shop)
	var bonus_shards := maxi(int(float(last_cleared_shards) * 0.5), 10)
	if not ad_bonus_claimed and last_cleared_shards > 0:
		_button(box, "🎬 원정 보너스: 영상 시청하고 파편 1.5배 수령 (+%d개)" % bonus_shards, _claim_ad_shard_bonus.bind(bonus_shards))
	_button(box, "🏰 메인 타이틀로 저장 후 나가기", _return_to_title)
	route_note = Label.new()
	_update_route_note()
	route_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_note.add_theme_font_size_override("font_size", 24)
	route_note.add_theme_color_override("font_color", Color("9aaeb8"))
	box.add_child(route_note)


func _claim_ad_shard_bonus(bonus_amount: int) -> void:
	if ad_bonus_claimed:
		return
	AdManagerClass.show_rewarded_ad("stage_clear_bonus", self, func():
		ad_bonus_claimed = true
		SaveManagerClass.add_shards(bonus_amount)
		_update_route_note()
		if is_instance_valid(panel):
			for btn in panel.find_children("", "Button", true, false):
				if "원정 보너스" in (btn as Button).text:
					(btn as Button).disabled = true
					(btn as Button).text = "✔ 원정 보너스 수령 완료 (+%d개)" % bonus_amount
	)


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")

func _open_campfire_shop() -> void:
	if not is_instance_valid(panel):
		return
	var shop := CampfireShopClass.new()
	if is_instance_valid(stage) and is_instance_valid(stage.player):
		shop.target_player = stage.player
	panel.add_child(shop)
	shop.shop_closed.connect(func():
		_update_route_note()
	)

func _update_route_note() -> void:
	if is_instance_valid(route_note):
		var current_shards := SaveManagerClass.get_shards()
		route_note.text = "보유 영혼 파편: %d개  ·  로컬 영구 자동 저장 완료 (user://save_data.json)" % current_shards

func _button(box: VBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 74
	button.add_theme_font_size_override("font_size", 28)
	for s in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203742") if s == "normal" else Color("31515c")
		style.border_color = Color("ddc18a") if s == "focus" else Color("6e929c")
		style.set_border_width_all(2 if s == "focus" else 1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(s, style)
	button.pressed.connect(action, CONNECT_DEFERRED)
	box.add_child(button)
	if box.get_child_count() == 3:
		button.grab_focus()

