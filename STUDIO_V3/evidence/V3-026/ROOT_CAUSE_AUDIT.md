# V3-026 Root Cause Audit: Combat Animation & Contact Synchronization

**Milestone:** V3-026 Combat Animation Foundation Rebuild  
**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-026-combat-animation-foundation`  
**Target Codebase:** V3-025 baseline (`66b15c3`)

---

## 1. Executive Summary

This audit documents the foundational architectural and content defects in ProjectKnight's combat system as of V3-025. While earlier milestones established reliable physics, 2.5D belt-scroll traversal, Z-depth evasion, and macro-level telegraphs, the micro-level combat feel remains flawed due to **decoupled animation and damage timing**, **generic 4-frame sprite reuse**, and **global time-scale interference**.

Combat weight and tactile satisfaction cannot be achieved merely by adding more particle effects, screen shake, or damage numbers. A fundamental redesign of the **Combat Event Timeline** and **Character Animation Pipeline** is required.

---

## 2. Core Architectural & Timing Defects in `side_qv_player.gd`

### Defect 1: Immediate Damage Infliction on Attack Startup ($t = 0\text{s}$)
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd:784–855`
- **Current Execution Flow:**
  ```gdscript
  func start_attack() -> void:
      ...
      attack_area_3d.monitoring = true
      emit_signal("attack_swung", combo_step)

      # Responsive melee hit check (Direction-aligned spatial + Area3D check)
      attack_hit_checked = true
      _check_melee_hit() # <-- EXECUTES ON FRAME 0 (STARTUP)

      # Combo 3 Finisher: Fire glowing 3D piercing sword wave along attack direction!
      if combo_step == 3:
          _fire_sword_beam()
  ```
- **Consequence:** The instant the player presses the attack button (`J`), `_check_melee_hit()` executes immediately. Enemies take damage, play hit sounds, trigger knockback, and spawn damage popups **before the sword sprite or slash VFX has even moved 1 millimeter**.
- **Player Perception:** The depicted weapon feels completely disconnected from the damage. The sword is visually lagging behind an invisible instant hitbox.

---

### Defect 2: Identical 4-Frame Sprite Sheet Reused for All 3 Combo Steps
- **Location:** `side_qv_player.gd:804–809` and `side_qv_player.gd:1542–1548`
- **Current Asset Configuration:**
  ```gdscript
  const TexAttack = preload("res://assets/player_frames/attack_v1_aligned.png")
  ...
  sprite_3d.texture = TexAttack
  sprite_3d.hframes = 2
  sprite_3d.vframes = 2
  sprite_3d.frame = 0
  ```
- **Animation Stepping Logic:**
  ```gdscript
  # Linear frame calculation across 0.24s total duration
  var attack_prog: float = 1.0 - (attack_duration_remaining / ATTACK_TOTAL_DURATION)
  sprite_3d.frame = clampi(int(attack_prog * 4.0), 0, 3)
  ```
- **Consequence:**
  1. Attack 1, Attack 2, and Attack 3 use the **exact same 4 sprite frames** (frame 0: backswing prep, frame 1: forward cut, frame 2: extended follow-through, frame 3: recovery).
  2. The only difference between combo steps is a procedural rotation tween on the `slash_visual_3d` mesh (Attack 1 rotates $-30^\circ \to +25^\circ$, Attack 2 rotates $+35^\circ \to -35^\circ$, Attack 3 rotates $+65^\circ \to -25^\circ$).
  3. The hero's body posture, foot planting, and weapon trajectory do not change between combo steps. In a commercial action game (e.g., *Dead Cells*, *Streets of Rage 4*), each combo step must possess distinct visual identity (quick horizontal strike $\to$ upward reverse cut $\to$ committed overhead cleave).

---

### Defect 3: Disjointed Hit Feedback & Global Time-Scale Stacking
- **Location:** `side_qv_player.gd:918` vs `side_qv_camera.gd:110` vs `GameFeelManager.gd:35`
- **Current Mechanism:**
  - Upon hit, `GameFeelManager.hit_stop_3d()` calls `Engine.time_scale = slow_factor` with a short coroutine timer.
  - Simultaneously, camera `add_trauma()` or camera hitstop methods may independently alter `Engine.time_scale`.
- **Consequence:**
  - Applying global `Engine.time_scale` pauses the entire world (including un-hit background enemies, projectiles, and camera interpolation), which can cause input frame drop or video recording jitter.
  - Furthermore, hitstop applied after frame 0 damage emphasizes the wrong moment—the world freezes before the sword visually reaches the enemy!

---

## 3. Enemy & Boss Animation Decoupling

### 1. Melee Grunts (`side_qv_enemy.gd`)
- Features authored phase timers (`0.28s TELL`, `0.14s ACTIVE`, `0.22s RECOVERY`), yet the sprite sheet (`melee_directional_aligned.png`) only dedicates single static frames to each phase. The character remains virtually frozen while only the ground warning decaling animates.

### 2. Heavy Shield Knight (`side_qv_elite_knight.gd`)
- Shield bash surge and recovery openings exist in code, but the shield bash visual is driven by tweening a QuadMesh forward rather than an authored charging knight pose.

### 3. Boss Commander (`side_qv_boss.gd`)
- In `TRIPLE_CLEAVE`, frames 8–11 loop at 12 FPS irrespective of which specific swing (1, 2, or 3) is occurring. In `CHARGE`, the boss remains in defensive idle while sliding across the floor.

---

## 4. Architectural Requirements for V3-026 Rebuild

1. **Deterministic Combat Action Definition:**
   - Every attack must be defined as an immutable data structure (`CombatActionDefinition`) specifying exact duration, frame keys, windup window, active hitbox window, blade contact timestamp, damage, knockback, and cancel rules.
2. **Deterministic Physics Timeline Controller:**
   - `CombatTimelineController` steps the action clock in `_physics_process`.
   - **Strict Order of Operations:**
     $$\text{Input Event} \to \text{Windup Pose (Hitbox OFF)} \to \text{Hitbox Open (Blade Enters Range)} \to \text{Contact Resolution} \to \text{Damage / Hitstop / SFX} \to \text{Recovery / Cancel}$$
   - **Zero Damage at Startup:** $t_{\text{damage}} \ge t_{\text{hitbox\_open}} > 0$.
3. **Scoped HitPause Coordinator:**
   - Implement localized frame holds for the attacker and victim nodes rather than pausing the global engine timescale for routine melee hits.
4. **Authored 2D Pose-to-Pose Content:**
   - Produce distinct, authentic sprite sheets for Attack 1, Attack 2, and Attack 3 using the Dead Cells 3D-to-2D pipeline.
