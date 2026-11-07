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
var cleared_stages: Array[bool] = [false, false, false, false, false]

var ui_layer: CanvasLayer


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
	if is_transitioning:
		return
	is_transitioning = true

	cleared_stages[current_stage_index] = true
	print(">>> [CAMPAIGN] Stage %d CLEARED! <<<" % [current_stage_index + 1])

	if current_stage_index < STAGE_SCENE_PATHS.size() - 1:
		# Next Stage Transition
		var next_idx := current_stage_index + 1
		await get_tree().create_timer(transition_delay).timeout
		load_stage(next_idx)
	else:
		# Full Campaign Victory!
		_show_campaign_victory()


func _on_stage_failed() -> void:
	print(">>> [CAMPAIGN] Stage %d FAILED! Restarting... <<<" % [current_stage_index + 1])
	await get_tree().create_timer(2.0).timeout
	load_stage(current_stage_index)


func _show_campaign_victory() -> void:
	print(">>> [CAMPAIGN] CONGRATULATIONS! ALL 5 STAGES CLEARED! <<<")
	campaign_completed.emit()

	var vic_panel := PanelContainer.new()
	vic_panel.name = "CampaignVictoryPanel"
	vic_panel.custom_minimum_size = Vector2(600, 300)
	vic_panel.position = Vector2(340, 210)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "★ CAMPAIGN VICTORY ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "All 5 Side Quarter-View Stages Cleared!\nThe Silent Citadel has been liberated."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(sub)

	vic_panel.add_child(vbox)
	ui_layer.add_child(vic_panel)
