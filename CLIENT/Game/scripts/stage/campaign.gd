extends Node
## Five-stage session owner. No singleton, disk save, or individual actor reset.
const STAGES := [preload("res://scenes/stage/FirstStage.tscn"), preload("res://scenes/stage/SecondStage.tscn"), preload("res://scenes/stage/ThirdStage.tscn"), preload("res://scenes/stage/FourthStage.tscn"), preload("res://scenes/stage/FifthStage.tscn")]
const REGION_NAMES := ["성문 외곽", "야수숲", "무너진 성벽", "돌의 성소", "침묵의 성채"]
var stage: Node2D
var stage_index := 0
var selected_trait := "basic"
var cleared: Array[bool] = [false, false, false, false, false]
var transitioning := false
var panel: Control
var transition_generation := 0

func _ready() -> void:
	_start_stage(0)

func _start_stage(index: int, checkpoint: bool = false) -> void:
	var saved_snapshot: Dictionary = stage.get_checkpoint_snapshot() if checkpoint and is_instance_valid(stage) else {}
	transition_generation += 1
	get_tree().paused = false
	for action in ["move_left", "move_right", "attack", "jump", "guard"]:
		Input.action_release(action)
	if is_instance_valid(panel):
		panel.free()
	if is_instance_valid(stage):
		stage.free()
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
		_show_route_panel()

func choose_trait(value: String) -> void:
	if not is_instance_valid(panel) or not cleared[0] or stage_index != 0 or value not in ["basic", "reach"]:
		return
	selected_trait = value
	_start_stage(1)

func restart_journey() -> void:
	if not is_instance_valid(panel) or not cleared[4]:
		return
	selected_trait = "basic"
	cleared = [false, false, false, false, false]
	_start_stage(0)

func continue_journey() -> void:
	if is_instance_valid(panel) and stage_index > 0 and stage_index < 4 and cleared[stage_index]:
		_start_stage(stage_index + 1)

func _show_route_panel() -> void:
	var layer := stage.get_node("HUD") as CanvasLayer
	stage.get_node("HUD/Presentation").visible = false
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
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ddc18a"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.text = "특성 1슬롯 · 다음 지역에서 사용할 전투 방식을 선택하세요\n체력과 공격 피해는 그대로입니다. 전투 중에는 바꿀 수 없습니다." if stage_index == 0 else "성채의 마지막 방어선을 넘어 길을 열었습니다.\n선택한 검술과 다섯 지역의 경험으로 완주했습니다." if stage_index == 4 else "다음 지역: %s\n선택한 검술은 유지되고 새 지역에서 HP 3으로 출발합니다." % REGION_NAMES[stage_index + 1]
	box.add_child(subtitle)
	if stage_index == 0:
		_button(box, "기본 검술  ·  사거리 72 / 재공격 0.32초", choose_trait.bind("basic"))
		_button(box, "긴 칼날  ·  사거리 90 / 재공격 0.40초", choose_trait.bind("reach"))
	elif stage_index < 4:
		_button(box, "다음 지역으로 → %s" % REGION_NAMES[stage_index + 1], continue_journey)
	else:
		_button(box, "처음부터 다시 도전", restart_journey)
	var note := Label.new()
	note.text = "이번 실행 중에만 진행·선택 유지 · 게임 종료 시 초기화"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("9aaeb8"))
	box.add_child(note)

func _button(box: VBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203742") if state == "normal" else Color("31515c")
		style.border_color = Color("ddc18a") if state == "focus" else Color("6e929c")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	box.add_child(button)
	if box.get_child_count() == 3:
		button.grab_focus()
