# D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/tests/fixtures/fixture_stamina_component_r3.gd
# Live Workflow Fixture: Advanced Stamina & Dash System (Cycle 1 Implementation)
class_name FixtureStaminaComponentR3
extends Node

signal stamina_changed(current: float, max: float)
signal stamina_depleted()
signal stamina_recovered()
signal dash_performed(stamina_cost: float)
signal exhaustion_state_changed(is_exhausted: bool)

@export var max_stamina: float = 100.0
var current_stamina: float = 100.0
@export var regen_rate: float = 15.0
@export var dash_cost: float = 25.0
@export var dash_cooldown: float = 0.5
var dash_cooldown_remaining: float = 0.0
var is_exhausted: bool = false
@export var exhaustion_recovery_threshold: float = 30.0

func _ready() -> void:
	current_stamina = max_stamina
	dash_cooldown_remaining = 0.0
	is_exhausted = false

## Initialize stamina component with maximum stamina value.
func init(max_val: float) -> void:
	max_stamina = max_val
	current_stamina = max_val
	dash_cooldown_remaining = 0.0
	is_exhausted = false
	stamina_changed.emit(current_stamina, max_stamina)
	exhaustion_state_changed.emit(false)

## Progress cooldown timers by delta seconds.
func update_cooldown(delta: float) -> void:
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)

## General stamina consumption with sufficiency and bounds checking.
func consume_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return false
	if amount > current_stamina:
		return false
	current_stamina = maxf(0.0, current_stamina - amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if is_zero_approx(current_stamina) or current_stamina <= 0.0:
		if not is_exhausted:
			is_exhausted = true
			exhaustion_state_changed.emit(true)
			stamina_depleted.emit()
	return true

## Check if player can perform a dash.
func can_dash() -> bool:
	return not is_exhausted and dash_cooldown_remaining <= 0.0 and current_stamina >= dash_cost

## Consume dash action.
## INTENTIONAL DEFECT FOR CYCLE 1:
## Intentionally OMITS checking is_exhausted and OMITS checking dash_cooldown_remaining.
## Allows dash to execute even when is_exhausted == true.
## Does NOT clamp current_stamina below zero when dash_cost exceeds available stamina.
func consume_dash() -> bool:
	# Intentional flaw: neither is_exhausted nor dash_cooldown_remaining is checked
	current_stamina -= dash_cost # Intentional underflow below 0.0 without clamping
	dash_cooldown_remaining = dash_cooldown
	stamina_changed.emit(current_stamina, max_stamina)
	dash_performed.emit(dash_cost)
	if current_stamina <= 0.0:
		if not is_exhausted:
			is_exhausted = true
			exhaustion_state_changed.emit(true)
			stamina_depleted.emit()
	return true

## Regenerate stamina over time given delta seconds.
func regenerate(delta: float) -> void:
	if delta <= 0.0 or current_stamina >= max_stamina:
		return
	var prev: float = current_stamina
	current_stamina = minf(max_stamina, current_stamina + regen_rate * delta)
	stamina_changed.emit(current_stamina, max_stamina)
	if prev <= 0.0 and current_stamina > 0.0:
		stamina_recovered.emit()
	if is_exhausted and current_stamina >= exhaustion_recovery_threshold:
		is_exhausted = false
		exhaustion_state_changed.emit(false)
