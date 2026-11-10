extends Node3D
class_name SideQVCampaign
## 사이드 쿼터뷰 5개 스테이지 풀 캠페인 매니저 (Side Quarter-View 5-Stage Campaign Manager)
## - Stage 1 ~ Stage 5 순차적 자동 진행 및 전환
## - 플레이어 스탯 및 성장 데이터 승계
## - 스테이지 클리어 축하 및 최종 캠페인 승리 연출

signal stage_transitioned(stage_idx: int)
signal campaign_completed

const STAGE_SCENE_PATHS: Array[String] = [
	"res://scenes/side_quarter_view/SideQVStage1.tscn",
	"res://scenes/side_quarter_view/SideQVStage2.tscn",
	"res://scenes/side_quarter_view/SideQVStage3.tscn",
	"res://scenes/side_quarter_view/SideQVStage4.tscn",
	"res://scenes/side_quarter_view/SideQVStage5.tscn"
]

const STAGE_NAMES: Array[String] = [
	"성문 외곽 (Citadel Terrace Gate)",
	"야수숲 (Beastwood Forest Gorge)",
	"무너진 성벽 (Ruined Crossbow Bastion)",
	"돌의 성소 (Titan Stone Sanctuary)",
	"침묵의 성채 (Silent Abyssal Citadel)"
]

@export var start_stage_index: int = 0
@export var transition_delay: float = 1.8

var current_stage_index: int = 0
var current_stage_instance: Node3D = null
var is_transitioning: bool = false
var is_defeat_active: bool = false
var cleared_stages: Array[bool] = [false, false, false, false, false]

var ui_layer: CanvasLayer
var failure_overlay: Control = null
var clear_overlay: Control = null


func _ready() -> void:
	_setup_ui()
	# Fix ISSUE-V3-001-03: Defer stage load to prevent 'add_child() called while parent node busy'
	load_stage.call_deferred(start_stage_index)


func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "CampaignUILayer"
	add_child(ui_layer)


func load_stage(idx: int) -> void:
	if idx < 0 or idx >= STAGE_SCENE_PATHS.size():
		printerr("[CAMPAIGN] Invalid stage index: %d" % idx)
		return

	is_transitioning = true
	current_stage_index = idx

	# Clean up any active defeat overlay
	if failure_overlay != null and is_instance_valid(failure_overlay):
		failure_overlay.queue_free()
		failure_overlay = null
	is_defeat_active = false

	# Clean up any active clear intermission overlay
	if clear_overlay != null and is_instance_valid(clear_overlay):
		clear_overlay.queue_free()
		clear_overlay = null

	# Clean up previous stage
	if current_stage_instance != null and is_instance_valid(current_stage_instance):
		current_stage_instance.queue_free()
		current_stage_instance = null

	var scene_path := STAGE_SCENE_PATHS[idx]
	if not ResourceLoader.exists(scene_path):
		printerr("[CAMPAIGN] Stage scene does not exist: %s" % scene_path)
		is_transitioning = false
		return

	var scene_res := load(scene_path) as PackedScene
	if scene_res == null:
		printerr("[CAMPAIGN] Failed to load packed scene: %s" % scene_path)
		is_transitioning = false
		return

	current_stage_instance = scene_res.instantiate() as Node3D
	add_child(current_stage_instance)

	if current_stage_instance.has_signal("stage_cleared"):
		current_stage_instance.connect("stage_cleared", _on_stage_cleared)
	if current_stage_instance.has_signal("stage_failed"):
		current_stage_instance.connect("stage_failed", _on_stage_failed)

	stage_transitioned.emit(current_stage_index)
	is_transitioning = false
	print(">>> [CAMPAIGN] Loaded Stage %d: %s <<<" % [current_stage_index + 1, STAGE_NAMES[current_stage_index]])


func _on_stage_cleared() -> void:
	if is_transitioning or is_defeat_active:
		return
	is_transitioning = true

	cleared_stages[current_stage_index] = true
	print(">>> [CAMPAIGN] Stage %d CLEARED! <<<" % [current_stage_index + 1])

	if current_stage_index < STAGE_SCENE_PATHS.size() - 1:
		# Stages 1 to 4: Show Stage Clear Intermission Overlay with player agency
		_show_stage_clear_intermission()
	else:
		# Full Campaign Victory!
		_show_campaign_victory()


func _show_stage_clear_intermission() -> void:
	var earned_shards: int = -1
	if current_stage_instance != null and "last_earned_shards" in current_stage_instance and current_stage_instance.last_earned_shards > 0:
		earned_shards = current_stage_instance.last_earned_shards

	if earned_shards > 0:
		print(">>> [CAMPAIGN] Displaying Stage Clear Intermission: Stage %d, Authoritative Earned Shards=%d <<<" % [current_stage_index + 1, earned_shards])
	else:
		print(">>> [CAMPAIGN] Displaying Stage Clear Intermission: Stage %d, Authoritative Reward Unavailable <<<" % [current_stage_index + 1])
	AudioManager.play("stage_clear_stinger")
	is_transitioning = false

	if clear_overlay != null and is_instance_valid(clear_overlay):
		clear_overlay.queue_free()
		clear_overlay = null

	var overlay_root := Control.new()
	overlay_root.name = "StageClearOverlay"
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear_overlay = overlay_root

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(center)

	var clear_panel := PanelContainer.new()
	clear_panel.name = "StageClearPanel"
	clear_panel.custom_minimum_size = Vector2(640, 360)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	panel_style.border_color = Color(1.0, 0.85, 0.22, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	clear_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.name = "ClearTitleLabel"
	title.text = "★ STAGE COMPLETED ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.22))
	vbox.add_child(title)

	var sub := Label.new()
	sub.name = "ClearSubtitleLabel"
	sub.text = "STAGE %d — %s\nCampaign Progress: %d / %d Stages Cleared" % [
		current_stage_index + 1,
		STAGE_NAMES[current_stage_index],
		current_stage_index + 1,
		STAGE_SCENE_PATHS.size()
	]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98))
	vbox.add_child(sub)

	# Reward Section: Authoritative Single Source
	var reward_lbl := Label.new()
	reward_lbl.name = "RewardLabel"
	if earned_shards > 0:
		reward_lbl.text = "💎 + %d SOUL SHARDS EARNED" % earned_shards
		reward_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	else:
		reward_lbl.text = "💎 REWARD UNAVAILABLE"
		reward_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(reward_lbl)

	# Action Button Row (Continue to Next Stage & Return to Title)
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 24)

	var next_idx := current_stage_index + 1
	var btn_continue := Button.new()
	var btn_title := Button.new()

	btn_continue.name = "ContinueStageButton"
	btn_continue.text = "CONTINUE TO STAGE %d ➔" % [next_idx + 1]
	btn_continue.custom_minimum_size = Vector2(230, 48)
	btn_continue.add_theme_font_size_override("font_size", 16)
	btn_continue.focus_mode = Control.FOCUS_ALL
	btn_continue.pressed.connect(func():
		if is_transitioning:
			return
		is_transitioning = true
		btn_continue.disabled = true
		btn_title.disabled = true
		print(">>> [CAMPAIGN] Continue Button Pressed: Advancing to Stage %d... <<<" % [next_idx + 1])
		AudioManager.stop_sfx()
		if is_instance_valid(overlay_root):
			overlay_root.queue_free()
			clear_overlay = null
		load_stage(next_idx)
	)
	hbox_btns.add_child(btn_continue)

	btn_title.name = "ReturnTitleButton"
	btn_title.text = "⮌ RETURN TO TITLE"
	btn_title.custom_minimum_size = Vector2(210, 48)
	btn_title.add_theme_font_size_override("font_size", 16)
	btn_title.focus_mode = Control.FOCUS_ALL
	btn_title.pressed.connect(func():
		if is_transitioning:
			return
		is_transitioning = true
		btn_continue.disabled = true
		btn_title.disabled = true
		print(">>> [CAMPAIGN] Return to Title Button Pressed: Loading TitleScreen... <<<")
		AudioManager.reset_all()
		if is_instance_valid(overlay_root):
			overlay_root.queue_free()
			clear_overlay = null
		get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
	)
	hbox_btns.add_child(btn_title)

	vbox.add_child(hbox_btns)
	clear_panel.add_child(vbox)
	center.add_child(clear_panel)
	ui_layer.add_child(overlay_root)
	btn_continue.grab_focus()


func _on_stage_failed() -> void:
	if is_transitioning or is_defeat_active:
		return
	is_defeat_active = true
	print(">>> [CAMPAIGN] Stage %d FAILED! Displaying Stage Failed Overlay... <<<" % [current_stage_index + 1])
	_show_stage_failed()


func _show_stage_failed() -> void:
	AudioManager.play("player_hurt")

	if failure_overlay != null and is_instance_valid(failure_overlay):
		failure_overlay.queue_free()
		failure_overlay = null

	if clear_overlay != null and is_instance_valid(clear_overlay):
		clear_overlay.queue_free()
		clear_overlay = null

	var overlay_root := Control.new()
	overlay_root.name = "StageFailedOverlay"
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	failure_overlay = overlay_root

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(center)

	var fail_panel := PanelContainer.new()
	fail_panel.name = "StageFailedPanel"
	fail_panel.custom_minimum_size = Vector2(620, 320)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.04, 0.05, 0.94)
	panel_style.border_color = Color(0.95, 0.25, 0.25, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	fail_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.name = "DefeatTitleLabel"
	title.text = "☠ STAGE FAILED ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	vbox.add_child(title)

	var sub := Label.new()
	sub.name = "DefeatSubtitleLabel"
	sub.text = "STAGE %d — %s\nThe Paladin has fallen in combat." % [current_stage_index + 1, STAGE_NAMES[current_stage_index]]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	vbox.add_child(sub)

	# Action Button Row (Retry Stage & Return to Title)
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 24)

	var btn_retry := Button.new()
	btn_retry.name = "RetryStageButton"
	btn_retry.text = "⚔ RETRY STAGE"
	btn_retry.custom_minimum_size = Vector2(220, 48)
	btn_retry.add_theme_font_size_override("font_size", 16)
	btn_retry.focus_mode = Control.FOCUS_ALL
	btn_retry.pressed.connect(func():
		if is_transitioning:
			return
		is_transitioning = true
		print(">>> [CAMPAIGN] Retry Stage Button Pressed: Reloading Stage %d... <<<" % [current_stage_index + 1])
		AudioManager.stop_sfx()
		if is_instance_valid(overlay_root):
			overlay_root.queue_free()
			failure_overlay = null
		is_defeat_active = false
		load_stage(current_stage_index)
	)
	hbox_btns.add_child(btn_retry)

	var btn_title := Button.new()
	btn_title.name = "ReturnTitleButton"
	btn_title.text = "⮌ RETURN TO TITLE"
	btn_title.custom_minimum_size = Vector2(220, 48)
	btn_title.add_theme_font_size_override("font_size", 16)
	btn_title.focus_mode = Control.FOCUS_ALL
	btn_title.pressed.connect(func():
		if is_transitioning:
			return
		is_transitioning = true
		print(">>> [CAMPAIGN] Return to Title Button Pressed: Loading TitleScreen... <<<")
		AudioManager.reset_all()
		if is_instance_valid(overlay_root):
			overlay_root.queue_free()
			failure_overlay = null
		is_defeat_active = false
		get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
	)
	hbox_btns.add_child(btn_title)

	vbox.add_child(hbox_btns)
	fail_panel.add_child(vbox)
	center.add_child(fail_panel)
	ui_layer.add_child(overlay_root)


func _show_campaign_victory() -> void:
	print(">>> [CAMPAIGN] CONGRATULATIONS! ALL 5 STAGES CLEARED! <<<")
	AudioManager.play("campaign_victory_fanfare")
	campaign_completed.emit()
	is_transitioning = false

	if clear_overlay != null and is_instance_valid(clear_overlay):
		clear_overlay.queue_free()
		clear_overlay = null

	var overlay_root := Control.new()
	overlay_root.name = "CampaignVictoryOverlay"
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(center)

	var vic_panel := PanelContainer.new()
	vic_panel.name = "CampaignVictoryPanel"
	vic_panel.custom_minimum_size = Vector2(640, 340)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	panel_style.border_color = Color(1.0, 0.85, 0.2, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	vic_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "★ CAMPAIGN VICTORY ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "All 5 Side Quarter-View Stages Cleared!\nThe Silent Citadel has been liberated."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(sub)

	# Action Button Row (Replay & Return to Title)
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 24)

	var btn_replay := Button.new()
	btn_replay.name = "ReplayCampaignButton"
	btn_replay.text = "⚔ REPLAY CAMPAIGN"
	btn_replay.custom_minimum_size = Vector2(220, 48)
	btn_replay.add_theme_font_size_override("font_size", 16)
	btn_replay.focus_mode = Control.FOCUS_ALL
	btn_replay.pressed.connect(func():
		if is_transitioning:
			return
		is_transitioning = true
		print(">>> [CAMPAIGN] Replay Campaign Button Pressed: Reloading Stage 1... <<<")
		AudioManager.stop_sfx()
		if is_instance_valid(overlay_root):
			overlay_root.queue_free()
		cleared_stages = [false, false, false, false, false]
		load_stage(0)
	)
	hbox_btns.add_child(btn_replay)

	var btn_title := Button.new()
	btn_title.name = "ReturnTitleButton"
	btn_title.text = "⮌ RETURN TO TITLE"
	btn_title.custom_minimum_size = Vector2(220, 48)
	btn_title.add_theme_font_size_override("font_size", 16)
	btn_title.focus_mode = Control.FOCUS_ALL
	btn_title.pressed.connect(func():
		if is_transitioning:
			return
		is_transitioning = true
		print(">>> [CAMPAIGN] Return to Title Button Pressed: Loading TitleScreen... <<<")
		AudioManager.reset_all()
		if is_instance_valid(overlay_root):
			overlay_root.queue_free()
		get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
	)
	hbox_btns.add_child(btn_title)

	vbox.add_child(hbox_btns)
	vic_panel.add_child(vbox)
	center.add_child(vic_panel)
	ui_layer.add_child(overlay_root)
