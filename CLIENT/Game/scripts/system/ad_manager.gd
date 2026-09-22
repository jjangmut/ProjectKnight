class_name AdManager
extends Node
## Central Commercial Ad Monetization Manager for Project Knight.
## Handles Rewarded Video Ads, Contextual Interstitials, Revive-on-Defeat,
## Shard Boosters, and No-Ads VIP bypass integration.

static var _instance: AdManager = null

signal rewarded_ad_started(placement: String)
signal rewarded_ad_completed(placement: String, reward_granted: bool)
signal ad_free_status_changed(is_ad_free: bool)

var has_revived_this_run: bool = false
var is_ad_playing: bool = false

func _enter_tree() -> void:
	if _instance == null:
		_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

static func get_instance() -> AdManager:
	return _instance

static func ensure_manager(context: Object) -> AdManager:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var script := load("res://scripts/system/ad_manager.gd") as GDScript
	var new_mgr: AdManager = script.new()
	new_mgr.name = "AdManager"
	if context is SceneTree:
		context.root.add_child(new_mgr)
	elif context is Node and context.get_tree() != null:
		context.get_tree().root.add_child(new_mgr)
	_instance = new_mgr
	return _instance

static func is_ad_free() -> bool:
	return SaveManager.is_ad_free()

static func set_ad_free(enabled: bool) -> void:
	SaveManager.set_ad_free(enabled)
	if _instance != null:
		_instance.ad_free_status_changed.emit(enabled)

static func can_revive_with_ad() -> bool:
	if _instance != null:
		return not _instance.has_revived_this_run
	return true

static func consume_revive_with_ad() -> void:
	if _instance != null:
		_instance.has_revived_this_run = true

static func reset_run_ad_counters() -> void:
	if _instance != null:
		_instance.has_revived_this_run = false

## Shows a rewarded ad. If user owns No-Ads VIP or in test mode, grants immediately.
static func show_rewarded_ad(placement: String, parent_node: Node, on_success: Callable, on_fail: Callable = Callable()) -> void:
	var mgr := ensure_manager(parent_node)
	if is_ad_free():
		# VIP instant grant without ad playback
		print("[AdManager] VIP No-Ads active: Instant reward granted for placement: %s" % placement)
		mgr.rewarded_ad_completed.emit(placement, true)
		if on_success.is_valid():
			on_success.call()
		return

	# Display immersive rewarded ad modal
	mgr._play_simulated_rewarded_ad(placement, parent_node, on_success, on_fail)

func _play_simulated_rewarded_ad(placement: String, parent_node: Node, on_success: Callable, on_fail: Callable) -> void:
	if is_ad_playing:
		if on_fail.is_valid():
			on_fail.call()
		return
	is_ad_playing = true
	rewarded_ad_started.emit(placement)

	# Build lightweight presentation layer
	var layer := CanvasLayer.new()
	layer.layer = 100
	parent_node.add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.96)
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "🎬 성소의 축복 (후원 영상 시청)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("ddc18a"))
	vbox.add_child(title)

	var placement_desc := "영혼 파편 +30개 충전"
	if placement == "revive_defeat":
		placement_desc = "현 위치 풀 HP 즉시 부활"
	elif placement == "stage_clear_bonus":
		placement_desc = "원정 정산 파편 1.5배 보너스"

	var desc := Label.new()
	desc.text = "보상: %s\n영상을 시청하여 인디 개발 스튜디오를 후원해 주셔서 감사합니다." % placement_desc
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 26)
	desc.add_theme_color_override("font_color", Color("b0c4de"))
	vbox.add_child(desc)

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(560, 40)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	vbox.add_child(progress_bar)

	# Reliable timer-based completion
	var timer := get_tree().create_timer(0.6, false)
	timer.timeout.connect(func():
		is_ad_playing = false
		rewarded_ad_completed.emit(placement, true)
		if is_instance_valid(layer):
			layer.queue_free()
		if on_success.is_valid():
			on_success.call()
	)
