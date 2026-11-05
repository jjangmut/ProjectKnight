# QA Review & Rejection Report: Cycle 1 - Stamina & Dash Component

- **Task ID**: `FIXTURE-V3-LIVE-003`
- **Iteration**: `1`
- **Reviewer**: `PK_QALead` (Independent QA Lead)
- **Reviewed Commit SHA**: `3657b7716b2ee875858c49a123090679839acc63`
- **Date**: `2026-11-05`
- **Target File**: `D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/tests/fixtures/fixture_stamina_component_r3.gd`
- **Worker Evidence**: `D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-002-R3/live_workflow/cycle_1_worker_evidence.md`
- **Verdict**: `QA FIX_REQUIRED`

---

## 1. Executive Summary

As the Independent QA Lead for ProjectKnight Studio V3, an independent audit of commit `3657b7716b2ee875858c49a123090679839acc63` was conducted.
The delivery implements `FixtureStaminaComponentR3`, a core stamina and dash mechanics fixture designed for Godot 4.x.

Functional code analysis and boundary verification revealed severe logic flaws in `consume_dash()`:
1. It completely bypasses the `is_exhausted` state check.
2. It fails to verify `dash_cooldown_remaining`.
3. It permits negative stamina underflow (`current_stamina` drops to `-25.0`) due to missing subtraction clamping.

These flaws break state consistency and allow illegal gameplay actions during exhaustion and active cooldown.
Consequently, milestone delivery cannot be approved. Defect `ISS-LIVE-003` is filed with **P1 Major** severity, blocking milestone progression until resolved.

---

## 2. QA Layer Audits

### 2.1 Functional QA (Mechanics, State Machine, Bounds & Underflow)
- `init(max_val)`: **PASS**. Correctly sets `max_stamina` and `current_stamina`, clears exhaustion and cooldown timers, and emits `stamina_changed` and `exhaustion_state_changed(false)`.
- `update_cooldown(delta)`: **PASS**. Cooldown decrements correctly with `maxf(0.0, dash_cooldown_remaining - delta)`.
- `consume_stamina(amount)`: **PASS**. Validates `amount > 0.0` and sufficiency `amount <= current_stamina`. Correctly clamps using `maxf(0.0, current_stamina - amount)` and triggers exhaustion transition when stamina reaches `0.0`.
- `can_dash()`: **PASS**. Accurately evaluates predicate:
  ```gdscript
  return not is_exhausted and dash_cooldown_remaining <= 0.0 and current_stamina >= dash_cost
  ```
- `consume_dash()`: **FAIL (DEFECT CONFIRMED)**.
  - Does NOT consult `can_dash()` or perform pre-condition checks.
  - Does NOT check `is_exhausted`. Allows player to dash while exhausted.
  - Does NOT check `dash_cooldown_remaining`. Allows player to dash during active cooldown.
  - Direct subtraction `current_stamina -= dash_cost` without clamping underflows stamina below `0.0` (e.g. `0.0 - 25.0 = -25.0`).
- `regenerate(delta)`: **CONDITIONAL / IMPAIRED**. While regeneration logic itself uses `minf(max_stamina, current_stamina + regen_rate * delta)`, because `consume_dash()` allows negative stamina, regeneration takes disproportionately longer to recover from negative values to threshold, corrupting timing expectations.

### 2.2 Visual QA & Signal Consistency
- `dash_performed` is emitted even when dash should be illegal.
- `stamina_changed` emits negative float values (e.g., `-25.0`), which will cause UI gauges or stamina bars to display distorted or broken negative ratios (`-25 / 100 = -0.25`).

### 2.3 Play QA (Pacing & Balance)
- Unbounded dashing while exhausted removes the punishment of stamina mismanagement, directly undermining combat rhythm and tension.
- Cooldown bypass allows rapid consecutive dash spamming.

---

## 3. Defect Report

### [ISS-LIVE-003] Stamina & Dash: Missing exhaustion guard and cooldown enforcement in consume_dash()

- **Issue ID**: `ISS-LIVE-003`
- **Severity**: `P1 (Major)`
- **Owner**: `PK_ClientLead`
- **Location**: `STUDIO_V3/tests/fixtures/fixture_stamina_component_r3.gd:64-75`

#### Reproduction Steps:
1. Initialize `FixtureStaminaComponentR3` with `max_stamina = 100.0`.
2. Drain stamina to `0.0` via `consume_stamina(100.0)` so `is_exhausted == true`.
3. Call `consume_dash()`.
   - **Expected**: Returns `false`. No dash performed, stamina remains `0.0`, cooldown not reset.
   - **Actual**: Returns `true`. Emits `dash_performed(25.0)`, `dash_cooldown_remaining` set to `0.5`, `current_stamina` drops to `-25.0`.
4. Call `consume_dash()` immediately again while `dash_cooldown_remaining == 0.5`.
   - **Expected**: Returns `false`.
   - **Actual**: Returns `true`. Cooldown check is bypassed.

#### Impact:
- Breaks core combat rules: allows infinite dodging or dash-spamming during exhausted state.
- Corrupts UI stamina display due to negative value underflow.
- Violates acceptance criteria for reliable stamina management.

---

## 4. Remediation Action Items for Worker (PK_ClientLead)

In Iteration 2, `PK_ClientLead` must implement the following fixes:
1. In `consume_dash()`, integrate precondition check:
   ```gdscript
   if not can_dash():
       return false
   ```
   Or explicitly verify `if is_exhausted or dash_cooldown_remaining > 0.0 or current_stamina < dash_cost: return false`.
2. Ensure stamina consumption clamps to `0.0`:
   ```gdscript
   current_stamina = maxf(0.0, current_stamina - dash_cost)
   ```
3. Update unit tests / evidence to prove:
   - Dashing when exhausted is rejected (`consume_dash() == false`).
   - Dashing on cooldown is rejected (`consume_dash() == false`).
   - Stamina cannot drop below `0.0`.

---

## 5. Review Verdict

```json
{
  "task_id": "FIXTURE-V3-LIVE-003",
  "iteration": 1,
  "role": "PK_QALead",
  "reviewed_commit_sha": "3657b7716b2ee875858c49a123090679839acc63",
  "verdict": "FIX_REQUIRED",
  "issues": [
    {
      "id": "ISS-LIVE-003",
      "severity": "P1",
      "title": "Stamina & Dash: Missing exhaustion guard and cooldown enforcement in consume_dash()",
      "reproduction_steps": "1. Initialize FixtureStaminaComponentR3 with max_stamina=100. 2. Consume 100 stamina to trigger exhaustion (is_exhausted=true). 3. Call consume_dash(). Expected: false. Actual: true, stamina drops to -25.0.",
      "expected": "consume_dash() returns false when is_exhausted == true or dash_cooldown_remaining > 0.0, and stamina never drops below 0.0.",
      "actual": "consume_dash() returns true, ignores exhaustion and cooldown, allowing stamina underflow to -25.0.",
      "evidence": [
        "STUDIO_V3/evidence/V3-002-R3/live_workflow/cycle_1_qa_rejection.md"
      ]
    }
  ],
  "evidence_manifest": "STUDIO_V3/evidence/V3-002-R3/live_workflow/cycle_1_qa_rejection.md"
}
```

**Final Decision**: **QA FIX_REQUIRED** (Milestone blocked until ISS-LIVE-003 resolved).
