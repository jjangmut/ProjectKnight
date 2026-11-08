# V3-004 Stage 2 Beastwood Forest Gorge — Reproduction & Execution Steps

**Milestone:** V3-004  
**Date:** 2026-11-08  
**Platform:** Windows 11 64-bit  
**Godot Engine:** v4.7.2.stable.official.ed1daf0bf  
**Renderer:** GL Compatibility (1280×720 Landscape Windowed)  

---

## 1. Prerequisites

Ensure Godot 4.7.2 is installed at:
`D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`

Repository path:
`D:\JUNYPAPA_STUDIO\Projects\ProjectKnight`

Active branch:
`studio/v3-004-stage2-beastwood`

---

## 2. Automated Full E2E Playthrough Command

Run the complete Title $\rightarrow$ Stage 1 $\rightarrow$ Stage 2 $\rightarrow$ Stage 3 continuous real-input verification:

```powershell
Set-Location "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight"
& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "CLIENT/Game" -s "res://tests/v3_004_stage2_real_input_e2e.gd"
```

**Expected Result:**
- Exit Code: `0`
- Duration: $\approx 23$ seconds
- Captures generated: 10 PNG screenshots in `STUDIO_V3/evidence/V3-004/captures/`
- All gates pass: Title click, Stage 1 clear, Stage 2 entry, 2 minion defeats, Chieftain boss spawn (HP 28), Pounce Leap & Triple Claw patterns, Phase 2 Enraged Roar ($HP \le 14$), Boss defeat ($HP = 0$), Stage 2 clear signal, Stage 3 load.

---

## 3. Isolated Plane & Mechanics Test Command

Run the focused actor Z-plane and boss mechanics verification:

```powershell
Set-Location "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight"
& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "CLIENT/Game" -s "res://tests/v3_004_stage2_plane_and_combat.gd"
```

**Expected Result:**
- Exit Code: `0`
- Output:
  - `Minion 1 spawn Z: 0.0000, Minion 2 spawn Z: 0.0000`
  - `Boss Chieftain spawned: HP=28/28 at Z=0.0000`
  - `Boss leap landed safely. Max airborne |vz|: 0.0000`
  - `phase_changed signal received: 2`

---

## 4. Stage 1 Regression Test Commands

Run the Stage 1 touch UI and boss timing regression suite to ensure zero regressions:

```powershell
# 1. Real touch UI and multi-touch ownership test
& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "CLIENT/Game" -s "res://tests/v3_003_real_touch_ui.gd"

# 2. Boss charge timing and parry cancellation test
& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "CLIENT/Game" -s "res://tests/v3_003_boss_charge_timing.gd"
```

**Expected Result:**
- Exit Code: `0` for both tests.

---

## 5. Manual Interactive Playtest Instructions

To play manually with keyboard or mouse:

1. Launch the game:
   ```powershell
   & "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "CLIENT/Game"
   ```
2. Click **출격 (Deploy)** on the Title Screen.
3. Complete Stage 1 (Citadel Terrace Gate).
4. Enter Stage 2 (Beastwood Forest Gorge):
   - Move: `A` / `D` or Arrow Keys.
   - Attack / Melee Slash: `J` or Left Click.
   - Guard / Just Parry: `K` or Right Click.
   - Jump: `Space` or `W`.
   - Dash: `Shift` or `L`.
5. Encounter 2 Feral Beasts: Watch for orange telegraph flash, parry the charge, combo strike.
6. Advance past $X \ge 6.5$: Fight Beast Chieftain. Parry triple claw combo, avoid landing shockwave of Pounce Leap, stagger during Phase 2 Enraged Roar.
7. Defeat boss and watch seamless transition into Stage 3 (Ruined Crossbow Bastion).
