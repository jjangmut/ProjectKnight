# D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R1/live_workflow/fixture_health_component.gd
# Live Workflow Fixture: HealthComponent (Cycle 2 Fix Implementation)
class_name FixtureHealthComponent
extends Node

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died()

@export var max_health: int = 100
var current_health: int = 100
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health

## Apply incoming damage.
## NOTE (Cycle 2 Fix): Health is clamped to zero upon lethal or excess damage (ISS-LIVE-001 fix).
func take_damage(amount: int) -> void:
	if is_dead:
		return
	if amount <= 0:
		return
	
	current_health = maxi(0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		is_dead = true
		died.emit()

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)

func reset() -> void:
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)
