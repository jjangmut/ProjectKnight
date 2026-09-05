extends Node2D

signal hit_received(hit_count: int)

@export var hit_flash_duration: float = 0.12

@onready var visual: Polygon2D = $Visual
@onready var hit_label: Label = $HitLabel
@onready var hit_flash_timer: Timer = $HitFlashTimer

var hit_count: int = 0
var _base_color: Color


func _ready() -> void:
	_base_color = visual.color
	hit_flash_timer.wait_time = hit_flash_duration
	hit_flash_timer.timeout.connect(_end_hit_flash)


func receive_hit() -> void:
	hit_count += 1
	visual.color = Color(1, 1, 1, 1)
	hit_label.visible = true
	hit_flash_timer.start()
	hit_received.emit(hit_count)
	print("HIT")


func _end_hit_flash() -> void:
	visual.color = _base_color
	hit_label.visible = false
