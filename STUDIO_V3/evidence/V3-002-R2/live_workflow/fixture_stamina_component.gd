# D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R2/live_workflow/fixture_stamina_component.gd
# Live Workflow Fixture: StaminaComponent (Cycle 1 Initial Implementation)
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
## INTENTIONAL DEFECT (Cycle 1): Does not clamp to 0 and does not check if amount > current_stamina,
## allowing stamina to underflow into negative numbers and always returning true.
func consume_stamina(amount: float) -> bool:
	current_stamina -= amount
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0 and not is_depleted:
		is_depleted = true
		stamina_depleted.emit()
	return true

## Regenerate stamina over time given delta in seconds.
func regenerate(delta: float) -> void:
	if delta <= 0.0 or current_stamina >= max_stamina:
		return
	current_stamina = minf(current_stamina + regen_rate * delta, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)
	if is_depleted and current_stamina > 0.0:
		is_depleted = false
		stamina_recovered.emit()
