# QA Rejection Report: FIXTURE-V3-LIVE-002 (Cycle 1)

- **Task ID**: `FIXTURE-V3-LIVE-002`
- **Review Cycle**: Cycle 1 (Functional QA Review)
- **Reviewer**: `PK_QALead` (Independent QA Lead)
- **Reviewed Commit SHA**: `c12f47de844278c32a5bf16bce889789328ed693`
- **Target File**: `D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R2/live_workflow/fixture_stamina_component.gd`
- **Date**: 2026-11-05
- **Verdict**: `FIX_REQUIRED`

---

## 1. QA Evaluation Summary

In accordance with ProjectKnight Studio V3 production guidelines (RULE 1, RULE 4, RULE 5), an independent QA review of the `FixtureStaminaComponent` implementation was performed against functional specifications and resource contract requirements.

| Layer | Evaluation Status | Notes |
| :--- | :--- | :--- |
| **Functional QA** | **FAILED (P1 Defect)** | Underflow in `consume_stamina()` allowing negative values and unvalidated action execution. |
| **Visual QA** | **CONDITIONAL WARNING** | Headless component logic, but negative values will corrupt HUD stamina bar fill calculations. |
| **Play QA** | **FAILED** | Unchecked action execution violates combat pacing; regeneration dead-zone breaks recovery cadence. |

---

## 2. Defect Log

### [ISS-LIVE-002] Stamina underflow allows negative stamina values on over-consumption

- **Defect ID**: `ISS-LIVE-002`
- **Severity**: **P1 (Major)** - Milestone Gate Blocker
- **Owner**: `PK_ClientLead`
- **Component**: `FixtureStaminaComponent.consume_stamina(amount: float)`
- **File Reference**: [fixture_stamina_component.gd](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R2/live_workflow/fixture_stamina_component.gd#L28-L35)

#### Description
`consume_stamina()` subtracts `amount` directly from `current_stamina` without validating whether sufficient stamina exists, and without clamping the resulting value to `0.0`. Additionally, the function returns `true` unconditionally, signaling successful consumption even when the requested amount exceeds total available stamina.

#### Reproduction Steps
1. Instantiate `FixtureStaminaComponent` or call `init(100.0)`.
   - Result: `current_stamina = 100.0`, `max_stamina = 100.0`, `is_depleted = false`.
2. Invoke `consume_stamina(150.0)`.
3. Check returned boolean and `current_stamina` value.

#### Expected Behavior
- Either:
  1. Strict check: If `current_stamina < amount`, the operation fails, `current_stamina` remains unchanged (or is not reduced below 0.0), and the method returns `false`.
  2. Partial consumption / Clamped: `current_stamina` is clamped to `0.0` (`maxf(0.0, current_stamina - amount)`), and the method returns whether action was allowed or denied based on design spec.
- In all cases: `current_stamina` must never be negative (`current_stamina >= 0.0`).

#### Actual Behavior
- `current_stamina` is set to `-50.0` (`100.0 - 150.0 = -50.0`).
- The method returns `true` unconditionally.
- Signal `stamina_changed` is emitted with negative float `-50.0`.
- Calling `regenerate(delta)` will take 5.0 seconds at `regen_rate = 10.0` just to recover from `-50.0` back to `0.0`, causing an unintended 5-second dead-zone before `stamina_recovered` can fire.

#### Evidence
```gdscript
# Current implementation lines 28-34 in fixture_stamina_component.gd
func consume_stamina(amount: float) -> bool:
	current_stamina -= amount
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0 and not is_depleted:
		is_depleted = true
		stamina_depleted.emit()
	return true
```

Execution trace on test vector:
```text
[TEST SETUP] max_stamina = 100.0, current_stamina = 100.0
[INVOKE] consume_stamina(150.0)
[ACTUAL RESULT] return_value: true | current_stamina: -50.0 | is_depleted: true
[VIOLATION] Invariant current_stamina >= 0.0 violated (-50.0 < 0.0)
```

---

## 3. Remediation Recommendations for PK_ClientLead

1. Enforce sufficiency validation:
   ```gdscript
   func consume_stamina(amount: float) -> bool:
       if amount <= 0.0:
           return true
       if current_stamina < amount:
           return false
       current_stamina = maxf(0.0, current_stamina - amount)
       stamina_changed.emit(current_stamina, max_stamina)
       if current_stamina <= 0.0 and not is_depleted:
           is_depleted = true
           stamina_depleted.emit()
       return true
   ```
2. Verify that negative stamina cannot be reached under any sequence of inputs.
3. Update automated regression tests to assert that `consume_stamina(150.0)` returns `false` and leaves or clamps stamina to non-negative values.

---

## 4. Final Verdict

- **Verdict**: `QA FIX_REQUIRED`
- **Routing**: Forwarding issue `ISS-LIVE-002` to `PK_Producer` for reassignment to `PK_ClientLead`.
- **Milestone Status**: BLOCKED pending Cycle 2 remediation.
