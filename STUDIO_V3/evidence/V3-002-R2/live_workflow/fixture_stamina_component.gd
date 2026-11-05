# D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R2/live_workflow/fixture_stamina_component.gd
# Live Workflow Fixture: StaminaComponent (Cycle 2 Remediation)
class_name FixtureStaminaComponent
extends Node

signal stamina_changed(current: float, max: float)
signal stamina_depleted()
signal stamina_recovered()

@export var max_stamina: float = 100.0
var current_stamina: float = 100.0
@export var regen_rate: float = 10.0

var is_depleted: bool = false

func _ready() -> void:
	current_stamina = max_stamina

func init(max_val: float) -> void:
	max_stamina = max_val
	current_stamina = max_val
	is_depleted = false
	stamina_changed.emit(current_stamina, max_stamina)

## Consume stamina for actions (dash, attack, guard).
## Remediated in Cycle 2 (ISS-LIVE-002):
## Clamps stamina and rejects over-consumption / invalid requests.
func consume_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return false
	if amount > current_stamina:
		return false
	current_stamina = maxf(0.0, current_stamina - amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if is_zero_approx(current_stamina):
		is_depleted = true
		stamina_depleted.emit()
	return true

## Regenerate stamina over time given delta in seconds.
func regenerate(delta: float) -> void:
	if delta <= 0.0 or current_stamina >= max_stamina:
		return
	var prev: float = current_stamina
	current_stamina = minf(max_stamina, current_stamina + regen_rate * delta)
	stamina_changed.emit(current_stamina, max_stamina)
	if prev <= 0.0 and current_stamina > 0.0:
		is_depleted = false
		stamina_recovered.emit()
