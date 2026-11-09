# V3-012 Source Diff & Architectural Summary

## Overview of Changes
Milestone **V3-012** resolves core encounter readability and feedback shortcomings across the ProjectKnight side-scrolling combat system. All modifications adhere strictly to Option C ($Z=0.0000, v_z=0.0000$), preserving the entire V3-011 procedural combat audio pipeline, V3-010 multi-touch routing, and full 5-stage campaign progression without balance cheating.

---

## 1. Modified Files & Behavioral Summary

### 1.1 `CLIENT/Game/scripts/side_quarter_view/side_qv_enemy.gd` (Melee Minions)
- **Hit Reaction & Micro-Recoil**:
  - Implemented `is_recoiling` state, `recoil_timer`, and physics damping in `_physics_process`.
  - In `receive_hit(amount, hit_dir, is_counter)`:
    - Normal hit: 2.2 m/s impulse, white-hot flash (`Color(3.5, 1.0, 1.0, 1.0)` to `Color.WHITE` in 0.12s).
    - Counter hit: 3.6 m/s impulse, cyan-gold resonance flash (`Color(1.5, 3.2, 4.0, 1.0)` to `Color.WHITE` in 0.18s).
    - Recoil impulse strictly clamped along X axis; $Z = 0.0000$ plane lock maintained.
- **Defeat State Overhaul (`_die`)**:
  - Immediate collision neutralization (`collision_layer = 0, collision_mask = 0`).
  - Immediate attack monitoring deactivation (`attack_area_3d.monitoring = false`).
  - Atomic guard `_death_signaled`: guarantees `enemy_defeated` is emitted exactly once per instance, preventing duplicate shard rewards or progression race conditions.
  - Immediate hiding of overhead HP bar (`OverheadHPBar.visible = false`).
  - Visual defeat transition: stagger recoil frame 3, unshaded toroidal defeat burst ring (`_spawn_defeat_burst`), and upward lift + dissolve tween before freeing.

### 1.2 `CLIENT/Game/scripts/side_quarter_view/enemies/side_qv_beast_minion.gd` (Stage 2 Minions)
- Applied identical hit reaction, micro-recoil, and atomic defeat architecture.
- Added `is_recoiling`, `recoil_timer`, and clamped X impulse.
- In `_die(is_counter)`: collision layers/masks cleared, attack monitoring disabled, `_death_signaled` atomic guard, and `_spawn_defeat_burst`.

### 1.3 `CLIENT/Game/scripts/side_quarter_view/side_qv_ranged_minion.gd` (Stage 3 Minions)
- Applied identical hit reaction, micro-recoil, and atomic defeat architecture.
- Added `is_recoiling`, `recoil_timer`, and clamped X impulse.
- In `_die(is_counter)`: collision layers/masks cleared, bolt firing interrupted, `_death_signaled` atomic guard, and `_spawn_defeat_burst`.

### 1.4 `CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd` (Stage 1 Boss Commander)
- Added `is_dead` and `_defeated_signaled` atomic guards.
- Overhauled `receive_hit`:
  - Boss maintains zero displacement (`velocity = Vector3.ZERO`), but applies a micro-recoil sprite visual shake (`position.x = offset_x` returning via tween in 0.08s).
  - Distinct normal flash vs cyan-gold counter resonance flash.
- In `_die()`: collision layers/masks zeroed, attack monitoring disabled, and `_defeated_signaled` ensures `boss_defeated` signal is emitted exactly once.

### 1.5 `CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_beast_chieftain.gd` (Stage 2 Boss)
- Added `_defeated_signaled` atomic guard.
- Updated `receive_hit` with distinct normal/counter flash and sprite micro-shake.
- Updated `_die()` with collision zeroing and duplicate prevention.

### 1.6 `CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd` (Stage 3 Boss)
- Replaced 1-line floor telegraph with full 3-way fan volley telegraph:
  - `_create_fan_aim_lines(base_dir)` creates three distinct laser beams for angles `[-18.0°, 0.0°, +18.0°]` in the X/Y plane along $Z=0$.
  - Visual aim line accurately represents actual projectile flight trajectories.
- Updated `receive_hit` and `_die()` with poise micro-shake, collision clearing, and `_defeated_signaled` protection.

### 1.7 `CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_golem_guardian.gd` (Stage 4 Boss)
- Fixed Ground Slam Telegraph Alignment:
  - Telegraph danger ring origin moved from feet center to `slam_origin` (`facing_dir_x * 1.5m`).
  - Telegraph torus ring expanded to 4.5m radius to match exact shockwave collision radius.
  - Spatial offset between telegraph warning and physical shockwave reduced from $1.50\text{ m}$ to $0.0000\text{ m}$.
- Fixed Tween transition to valid Godot 4 constant `Tween.TRANS_CUBIC`.
- Updated `receive_hit` and `_die()` with poise micro-shake, collision zeroing, and `_defeated_signaled`.

### 1.8 `CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd` (Stage 5 Boss)
- Added `_defeated_signaled` atomic guard, collision zeroing in `_die()`.
- Updated `receive_hit` with distinct normal/counter flash and sprite micro-shake.

### 1.9 `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` (Player Controller)
- Updated melee attack hit callbacks to pass `was_counter`:
  - Standard melee combo strike: `receive_hit(dmg, hit_dir, was_counter)`.
  - Dive slam impact: `receive_hit(slam_dmg, push, true)` (treated as counter/heavy hit).
  - Aegis parry reflect: `receive_hit(2, ref_push, true)` (treated as counter hit).

---

## 2. Regression & Option C Integrity
- **Z-Plane Lock**: All actors, projectiles, telegraph aim lines, danger rings, and defeat bursts strictly enforce $Z = 0.0000$ and $v_z = 0.0000$.
- **Zero Balance Alteration**: Player max HP (8), minion HP, boss HP values, and invulnerability timers are completely untouched.
- **Audio Integrity**: Preserved 100% of V3-011 audio event hooks (`slash_combo`, `enemy_hit_impact`, `parry_clash`, `boss_tell`, `campaign_victory_fanfare`).
- **Touch Input Integrity**: Preserved 100% of V3-010 single-owner multi-touch routing.
