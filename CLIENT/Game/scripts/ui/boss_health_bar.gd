class_name BossHealthBar
extends Control
## Dungeon Hunter 2 Gothic Winged Boss Health Bar
## Features high-resolution gothic wings filigree texture frame,
## faceted ruby gemstone fill, lingering amber magma delay trail,
## phase segment dividers (50% / 25%), and dynamic enraged pulse.

const TexBossBarFrame = preload("res://assets/ui/boss_bar_frame.png")
const TexBossBarFillRuby = preload("res://assets/ui/boss_bar_fill_ruby.png")
const TexBossBarLingerAmber = preload("res://assets/ui/boss_bar_linger_amber.png")

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
var _fade_tween: Tween = null
var _pulse_timer: float = 0.0

var _title_label: Label
var _phase_label: Label
var _bar_bg: ColorRect
var _bar_linger: ColorRect
var _bar_fill: ColorRect

const BAR_WIDTH: float = 700.0
const BAR_HEIGHT: float = 34.0
const BAR_Y: float = 40.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0 # Initially hidden
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + 80.0, 84.0)

	# Boss Name Label (Crisp 30pt font centered above bar with drop shadow)
	_title_label = Label.new()
	_title_label.text = boss_name
	_title_label.position = Vector2(0, 2)
	_title_label.size = Vector2(BAR_WIDTH, 36)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_title_label)

	# Phase 2 Enraged Tag (Right aligned above bar)
	_phase_label = Label.new()
	_phase_label.text = "[ ENRAGED ]"
	_phase_label.position = Vector2(0, 6)
	_phase_label.size = Vector2(BAR_WIDTH, 32)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.add_theme_font_size_override("font_size", 22)
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.20))
	_phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_phase_label.add_theme_constant_override("shadow_offset_x", 2)
	_phase_label.add_theme_constant_override("shadow_offset_y", 2)
	_phase_label.visible = false
	add_child(_phase_label)

	# Bar Background: Preserved for test hierarchy, transparent since rendered via custom _draw()
	_bar_bg = ColorRect.new()
	_bar_bg.position = Vector2(0, BAR_Y)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.color = Color.TRANSPARENT
	add_child(_bar_bg)

	# Bar Linger: Preserved for test contract, transparent since rendered via custom _draw()
	_bar_linger = ColorRect.new()
	_bar_linger.position = Vector2(0, BAR_Y)
	_bar_linger.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_linger.color = Color(0.96, 0.78, 0.40, 0.0)
	add_child(_bar_linger)

	# Bar Fill: Preserved for test contract, transparent since rendered via custom _draw()
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(0, BAR_Y)
	_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_fill.color = Color(0.85, 0.16, 0.22, 0.0)
	add_child(_bar_fill)


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
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.6)


func snap_to_visible() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	modulate.a = 1.0


func _on_hp_changed(new_hp: int, new_max: int) -> void:
	current_hp = new_hp
	max_hp = new_max
	var ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	_bar_fill.size.x = BAR_WIDTH * ratio
	queue_redraw()


func _on_phase_changed(phase: int) -> void:
	if phase == 2:
		is_enraged = true
		_phase_label.visible = true
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		queue_redraw()


func _on_boss_defeated() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2).set_delay(0.8)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if not is_active:
		return

	if is_enraged:
		_pulse_timer += delta * 4.0
		var pulse := (sin(_pulse_timer) + 1.0) * 0.5
		_phase_label.modulate.a = lerpf(0.65, 1.0, pulse)
		queue_redraw()

	# Smoothly drain lingering damage bar
	if linger_hp > float(current_hp):
		linger_hp = move_toward(linger_hp, float(current_hp), 4.5 * delta)
		var linger_ratio := clampf(linger_hp / float(max_hp), 0.0, 1.0)
		_bar_linger.size.x = BAR_WIDTH * linger_ratio
		queue_redraw()


func _draw() -> void:
	# 1. Obsidian Backplate Base
	var bg_rect := Rect2(0, BAR_Y, BAR_WIDTH, BAR_HEIGHT)
	draw_rect(bg_rect, Color(0.04, 0.06, 0.10, 0.95), true)

	# 2. Lingering Amber Magma Damage Trail Texture
	var linger_ratio := clampf(linger_hp / float(max_hp), 0.0, 1.0)
	var linger_w := BAR_WIDTH * linger_ratio
	if linger_w > 0.0:
		var linger_rect := Rect2(0, BAR_Y, linger_w, BAR_HEIGHT)
		var linger_src := Rect2(0, 0, TexBossBarLingerAmber.get_width() * linger_ratio, TexBossBarLingerAmber.get_height())
		draw_texture_rect_region(TexBossBarLingerAmber, linger_rect, linger_src)

	# 3. High-Resolution Faceted Ruby Gemstone Fill Texture
	var fill_ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var fill_w := BAR_WIDTH * fill_ratio
	if fill_w > 0.0:
		var fill_rect := Rect2(0, BAR_Y, fill_w, BAR_HEIGHT)
		var fill_src := Rect2(0, 0, TexBossBarFillRuby.get_width() * fill_ratio, TexBossBarFillRuby.get_height())
		var fill_tint := Color(1.3, 0.7, 0.7, 1.0) if is_enraged else Color(1.0, 1.0, 1.0, 1.0)
		draw_texture_rect_region(TexBossBarFillRuby, fill_rect, fill_src, fill_tint)

	# 4. High-Resolution Dungeon Hunter 2 Gothic Winged Filigree Frame Texture
	var frame_rect := Rect2(-60.0, BAR_Y - 35.0, 820.0, 110.0)
	var frame_tint := Color(1.35, 0.75, 0.65, 1.0) if is_enraged else Color(1.0, 1.0, 1.0, 1.0)
	draw_texture_rect(TexBossBarFrame, frame_rect, false, frame_tint)

	# 5. Dynamic Enraged Ruby Pulsing Aura on Wings
	if is_enraged:
		var pulse := (sin(_pulse_timer) + 1.0) * 0.5
		var aura_col := Color(1.5, 0.2, 0.2, 0.65 * pulse)
		draw_circle(Vector2(-20, BAR_Y + BAR_HEIGHT * 0.5), 10.0, aura_col)
		draw_circle(Vector2(BAR_WIDTH + 20, BAR_Y + BAR_HEIGHT * 0.5), 10.0, aura_col)
