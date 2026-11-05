# Cycle 1 Implementation Evidence - Stamina & Dash Component Fixture

- **Task ID**: `FIXTURE-V3-LIVE-003`
- **Owner**: `PK_ClientLead` (Lead Client Programmer)
- **Status**: `IMPLEMENTATION_COMPLETE`
- **Target File**: `D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/tests/fixtures/fixture_stamina_component_r3.gd`
- **Git Branch**: `studio/v3-002-agent-orchestrator-r3`
- **Platform Validation**: `ANDROID NOT VERIFIED`

---

## 1. Summary of Changes
Implemented the Godot 4.x `FixtureStaminaComponentR3` GDScript node to serve as the live multi-agent review loop test fixture for V3-002-R3:
- **Node Type**: `Node` (`class_name FixtureStaminaComponentR3 extends Node`).
- **Signals**:
  - `signal stamina_changed(current: float, max: float)`
  - `signal stamina_depleted()`
  - `signal stamina_recovered()`
  - `signal dash_performed(stamina_cost: float)`
  - `signal exhaustion_state_changed(is_exhausted: bool)`
- **Variables**:
  - `@export var max_stamina: float = 100.0`
  - `var current_stamina: float = 100.0`
  - `@export var regen_rate: float = 15.0`
  - `@export var dash_cost: float = 25.0`
  - `@export var dash_cooldown: float = 0.5`
  - `var dash_cooldown_remaining: float = 0.0`
  - `var is_exhausted: bool = false`
  - `@export var exhaustion_recovery_threshold: float = 30.0`
- **Functions**:
  - `init(max_val: float) -> void`: Initializes max and current stamina, resets exhaustion and cooldown, emits initial state.
  - `update_cooldown(delta: float) -> void`: Decrements remaining dash cooldown by `delta` seconds.
  - `consume_stamina(amount: float) -> bool`: Validates amount and sufficiency, clamps consumption to 0.0, emits signals and transitions to exhausted if depleted.
  - `can_dash() -> bool`: Evaluates `not is_exhausted and dash_cooldown_remaining <= 0.0 and current_stamina >= dash_cost`.
  - `consume_dash() -> bool`:
    - **Intentional Defect (Cycle 1)**: Omits checking `is_exhausted` and omits checking `dash_cooldown_remaining`. Executes dash unconditionally even when `is_exhausted == true`, and does not clamp `current_stamina` below `0.0` when dash cost exceeds available stamina. Emits `dash_performed(dash_cost)` and sets `dash_cooldown_remaining = dash_cooldown`.
  - `regenerate(delta: float) -> void`: Regenerates stamina at `regen_rate * delta`, clamped to `max_stamina`. Emits `stamina_recovered` when rising above 0.0, and recovers exhaustion state when stamina meets or exceeds `exhaustion_recovery_threshold` (30.0).

---

## 2. Intentional Defect Confirmation
- **Defect Location**: `consume_dash()` in `fixture_stamina_component_r3.gd`
- **Specific Flaws**:
  1. `is_exhausted` check is omitted; player can dash while in exhausted state.
  2. `dash_cooldown_remaining` check is omitted; cooldown can be bypassed on repeated calls.
  3. Underflow without clamping: `current_stamina -= dash_cost` without verifying sufficiency or clamping to 0.0, resulting in negative stamina values.

---

## 3. Deliverables
- Fixture Path: `D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/tests/fixtures/fixture_stamina_component_r3.gd`
- Evidence Path: `D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R3/live_workflow/cycle_1_worker_evidence.md`

---

## 4. Review Handoff
- Status declaration: `IMPLEMENTATION_COMPLETE` (Highest worker ceiling, per ProjectKnight production rules).
- Target Reviewer: `PK_QALead` / Producer for Cycle 1 functional QA verification.
- Mobile Status: `ANDROID NOT VERIFIED` (Measured on PC environment only).
