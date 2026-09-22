class_name BossHealthBar
extends Control
## Cinematic Boss Health Bar: Appears at bottom center during boss encounters.
## Features lingering white damage trail, Phase 2 Enraged indicator, and stylized framing.

var max_hp: int = 12
var current_hp: int = 12
var linger_hp: float = 12.0
var boss_name: String = "타락한 방패 기사단장":
	set(val):
		boss_name = val
		if is_instance_valid(_title_label):
			_title_label.text = val
var is_enraged: bool = false
var is_active: bool = false

var _title_label: Label
var _phase_label: Label
var _bar_bg: ColorRect
var _bar_linger: ColorRect
var _bar_fill: ColorRect
var _border: Line2D

const BAR_WIDTH: float = 700.0
const BAR_HEIGHT: float = 36.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0 # Initially hidden
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH, 84.0)

	# Boss Name Label (Crisp 36pt font centered above bar)
	_title_label = Label.new()
	_title_label.text = boss_name
	_title_label.position = Vector2(0, 0)
	_title_label.size = Vector2(BAR_WIDTH, 40)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_title_label)

	# Phase 2 Enraged Tag (Right aligned above bar)
	_phase_label = Label.new()
	_phase_label.text = "[ ENRAGED ]"
	_phase_label.position = Vector2(0, 4)
	_phase_label.size = Vector2(BAR_WIDTH, 34)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.add_theme_font_size_override("font_size", 24)
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.18))
	_phase_label.visible = false
	add_child(_phase_label)

	# Bar Background
	_bar_bg = ColorRect.new()
	_bar_bg.position = Vector2(0, 42)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.color = Color(0.06, 0.08, 0.12, 0.92)
	add_child(_bar_bg)

	# Bar Linger (White damage delay)
	_bar_linger = ColorRect.new()
	_bar_linger.position = Vector2(0, 42)
	_bar_linger.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_linger.color = Color(0.92, 0.92, 0.95, 0.85)
	add_child(_bar_linger)

	# Bar Fill (Crimson / Enrage Red)
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(0, 42)
	_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_fill.color = Color(0.88, 0.18, 0.15, 1.0)
	add_child(_bar_fill)

	# Ornate Gold Border outline
	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2(-2, 40), Vector2(BAR_WIDTH + 2, 40),
		Vector2(BAR_WIDTH + 2, 44 + BAR_HEIGHT),
		Vector2(-2, 44 + BAR_HEIGHT), Vector2(-2, 40)
	])
	border.width = 3.5
	border.default_color = Color(0.82, 0.72, 0.52, 0.95)
	add_child(border)


func attach_boss(boss: CharacterBody2D) -> void:
	if not is_instance_valid(boss):

		return
	max_hp = boss.max_hp
	current_hp = boss.current_hp
	linger_hp = float(current_hp)

	boss.boss_hp_changed.connect(_on_hp_changed)
	boss.boss_phase_changed.connect(_on_phase_changed)
	boss.boss_defeated.connect(_on_boss_defeated)

	# Fade in smoothly
	is_active = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)


func _on_hp_changed(new_hp: int, new_max: int) -> void:
	current_hp = new_hp
	max_hp = new_max
	var ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	_bar_fill.size.x = BAR_WIDTH * ratio


func _on_phase_changed(phase: int) -> void:
	if phase == 2:
		is_enraged = true
		_phase_label.visible = true
		_bar_fill.color = Color(1.0, 0.12, 0.08, 1.0)
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))


func _on_boss_defeated() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2).set_delay(0.8)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if not is_active:
		return

	# Smoothly drain lingering damage bar
	if linger_hp > float(current_hp):
		linger_hp = move_toward(linger_hp, float(current_hp), 4.5 * delta)
		var linger_ratio := clampf(linger_hp / float(max_hp), 0.0, 1.0)
		_bar_linger.size.x = BAR_WIDTH * linger_ratio
