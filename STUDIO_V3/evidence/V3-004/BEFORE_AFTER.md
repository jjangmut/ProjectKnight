# V3-004 Stage 2 Beastwood Forest Gorge — Before / After Analysis

**Date:** 2026-11-08  
**Scope:** Stage 2 Beastwood Forest Gorge Option C Plane Alignment and Encounter Gameplay  
**Auditor:** PK_ClientLead / PK_Producer  

---

## 1. Architectural Changes: Option C 2D Plane Lock ($Z = 0.0$)

| Aspect | Before V3-004 | After V3-004 | Impact |
|---|---|---|---|
| **Minion 1 Spawn** | `Vector3(4.5, 0.1, -1.6)` (Z off-plane) | `Vector3(4.5, 0.1, 0.0)` | Actors spawn on the exact 2D combat plane. |
| **Minion 2 Spawn** | `Vector3(8.0, 0.1, +1.6)` (Z off-plane) | `Vector3(8.0, 0.1, 0.0)` | Eliminates diagonal pursuit drift and plane misalignment. |
| **Minion Chase AI** | 3D `diff.normalized()` and `velocity.z = dir.z * ...` | Pure 1D horizontal direction $dir\_x = \text{signf}(diff\_x)$, $v_z = 0.0$ | Minions never drift into background or foreground. |
| **Minion Pounce Telegraph** | Inactive flash, 3D charge direction | 0.32s flash with `attack_area.monitoring = false`, $v_z = 0.0$ | Clear hazard warning precedes damage; zero phantom hits. |
| **Minion Double-Hit Risk** | Both Area3D overlap and proximity impact applied damage | Single-hit flag `has_hit_in_current_charge = true` | Zero double damage glitch on player. |
| **Boss Leap Velocity** | `velocity.z = clampf(diff.z * 1.5, -4.5, 4.5)` | Strictly 2D parabolic jump ($v_y = 7.2, v_x = \text{speed}, v_z = 0.0$) | Boss leap never deviates from $Z = 0.0$ combat plane. |
| **Boss Phase 2 Trigger** | Triggered only by raw HP mutation without signal tracking | Emits `phase_changed(2)` and `boss_phase_changed(2)` at $HP \le 14$ | Fully observable event for Campaign and HUD. |
| **Enraged Roar Aura** | Stale hidden mesh | Activates glowing emerald torus aura ring and shockwave ring | Clear visual telegraph for boss enrage phase. |
| **Signal Safety** | `set_monitoring` during physics callback emitted engine errors | Uses `set_deferred("monitoring", false)` | Clean engine log with zero warnings or errors. |

---

## 2. Playthrough Progression Changes

| Milestone Gate | Before V3-004 | After V3-004 |
|---|---|---|
| **Continuous E2E Journey** | Only Stage 1 was proven; Stage 2 was untested prototype | Full Title $\rightarrow$ Stage 1 $\rightarrow$ Stage 2 $\rightarrow$ Stage 3 continuous run proven with real engine inputs. |
| **Stage 2 Minions** | Incomplete wave verification | Both minions defeated naturally ($HP = 5 \rightarrow 0$) via attack and parry. |
| **Stage 2 Boss** | HP 28 unverified, Phase 2 skipped or forced | Full combat verified from HP 28 down to 0, with Phase 2 Enraged Roar at HP 12. |
| **Stage 2 Clear Signal** | Not verified in E2E context | `stage_cleared` callback observed count == 1. |
| **Stage 3 Transition** | Not verified in E2E context | Campaign correctly loaded `SideQVStage3` (current_stage_index = 2). |
