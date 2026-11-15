# V3-024-R4: R3 Video Diagnosis & Root-Cause Determination

## 1. Source Video Profile
- **File**: `D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-024-R3/Stage1_BossLaneAlignment_1x.mp4`
- **Resolution**: 1280x720 Landscape
- **Framerate**: 60.0 FPS Fixed
- **Duration**: 12.03 seconds (722 frames)
- **SHA-256**: `585b04061d56c2f10f0e445386ebfedd5cc3d30b1537403d0611e31a354dd88a`
- **Fixture Origin**: `tests/record_boss_lane_alignment.gd` (`ISOLATED_FIXTURE_STATE_SETUP`)

---

## 2. Issue 1: Hero Occlusion at 5.0s ~ 7.0s

### 2.1 Visual Evidence & Reproduction
Extracted inspection frames at 0.5s intervals:
- `diagnosis/r3_diag_05_0s.png` (Frame 300): Player at $Z = -1.60$, Boss at $Z = -1.55$. Separation $X = 2.15\text{m}$. Both silhouettes fully distinct.
- `diagnosis/r3_diag_05_5s.png` (Frame 330): Boss initiates `TRIPLE_CLEAVE`. Telegraph windup begins.
- `diagnosis/r3_diag_06_0s.png` (Frame 360): **Critical Overlap Incident**. Boss executes Swing 1. Boss forward lunge collapses horizontal distance to $X = 1.18\text{m}$.
- `diagnosis/r3_diag_06_5s.png` (Frame 390): Boss greatshield and chest sprite overlay the hero's lower torso. Hero core silhouette visibility drops to $\approx 64\%$.
- `diagnosis/r3_diag_07_0s.png` (Frame 420): Boss enters recovery. Pushback gradually restores separation to $X = 1.72\text{m}$.

### 2.2 Mathematical Root Cause
1. **Sprite Dimensions**:
   - Boss Commander sprite: $\approx 220\text{px} \times 0.0082 = 1.80\text{m}$ width (extends $0.90\text{m}$ from origin).
   - Paladin Hero sprite: $\approx 150\text{px} \times 0.0082 = 1.23\text{m}$ width (extends $0.62\text{m}$ from origin).
   - Minimum non-overlapping horizontal span: $0.90\text{m} + 0.62\text{m} = 1.52\text{m}$.
2. **Missing Pattern Pushback & Unchecked Lunge**:
   - In `side_qv_boss.gd` (line 716), `_execute_triple_cleave()` assigned:
     ```gdscript
     velocity.x = facing_dir_x * 4.2
     ```
     without evaluating proximity to the player.
   - `_prevent_player_pushing()` was only called inside `Pattern.CHASE`, so during `TRIPLE_CLEAVE` active swings, pushback was completely bypassed.
   - At $Z = -1.60\text{m}$ vs $Z = -1.55\text{m}$, the boss was $0.05\text{m}$ closer to the camera. Because sorting offset is proportional to $+Z$, the boss sprite was rendered in front of the player, completely covering the player's torso when distance dropped to $1.18\text{m} < 1.52\text{m}$.

### 2.3 Engine Fix & Verification
1. **Mutual Clearance Expansion**:
   - In `side_qv_boss.gd`: raised `min_x` from $1.70\text{m}$ to $2.05\text{m}$.
   - In `side_qv_player.gd`: raised `min_x_dist` against bosses from $1.65\text{m}$ to $2.05\text{m}$.
   - Called `_prevent_player_pushing()` unconditionally before `move_and_slide()` across all non-charge patterns.
2. **Proximity-Gated Lunge**:
   - In `_execute_triple_cleave()`:
     ```gdscript
     var forward_dist := absf(target_player.global_position.x - global_position.x)
     velocity.x = facing_dir_x * (4.2 if forward_dist > 2.30 else 0.5)
     ```
   - When within melee range ($\le 2.30\text{m}$), the boss performs a firm short step ($0.5\text{m/s}$) rather than lunging onto the player.
3. **Verification**:
   - `tests/quality_gate/v3_024_r4_sprite_bounding_verification.gd`:
     - Top rail duel minimum separation: $2.19\text{m}$ (exceeds $1.95\text{m}$ gate).
     - Screen bounding box gap: $+112.6\text{px}$ (exceeds $+45\text{px}$ gate).
     - Hero silhouette visibility: $100.0\%$ (exceeds $90\%$ gate).
     - Critical overlaps: **0**.

---

## 3. Issue 2: Hero Collapse at 9.0s ~ 11.0s

### 3.1 Visual Evidence & Reproduction
Extracted inspection frames at 0.5s intervals:
- `diagnosis/r3_diag_09_5s.png` (Frame 570): Player engages boss at $Z = 1.20\text{m}$. UI top-left shows `3 / 9 HP`.
- `diagnosis/r3_diag_10_0s.png` (Frame 600): Boss connects a cleave attack. Floating combat text `-2` appears. UI updates to `1 / 9 HP`.
- `diagnosis/r3_diag_10_5s.png` (Frame 630): Boss connects second cleave swing. Floating combat text `-2` appears. UI updates to `0 / 9 HP`.
- `diagnosis/r3_diag_11_0s.png` (Frame 660): Player enters `State.DEAD`. Hero collapses onto floor in fallen pose. Script ends at 12.0s.

### 3.2 Classification: `EXPECTED_DEFEAT`
- **Engine State Check**:
  - In `tests/record_boss_lane_alignment.gd`, Step 5 (`BOTTOM_LANE_DUEL`, lines 142–151):
    ```gdscript
    SequenceStep.BOTTOM_LANE_DUEL:
        if step_ticks % 22 == 5:
            Input.action_press("attack")
        elif step_ticks % 22 == 8:
            Input.action_release("attack")
    ```
  - The stress fixture was designed solely to drive attack animations and never issued `guard`, `dash`, or `move` inputs during this phase.
  - The boss dealt standard melee damage (2 HP per hit). Over the 11 seconds of combat without blocking or dodging, the hero absorbed 5 unmitigated hits, exhausting all 9 HP.
  - The hero collapse was a completely legitimate damage death according to core combat rules.
  - **It was NOT an engine crash, null reference, collision trap, or physics lock.**

### 3.3 Defeat & Clean Retry Verification
To satisfy Task D requirements:
- Implemented `tests/quality_gate/v3_024_r4_defeat_retry_verification.gd`.
- Verified that upon fatal damage:
  1. Hero transitions to `State.DEAD` with `is_dead = true`.
  2. Campaign spawns defeat overlay (`failure_overlay`) with `RetryStageButton`.
  3. Clicking `RetryStageButton` cleanly re-instantiates Stage 1, restores hero HP to 9, resets boss HP to 64, re-anchors the camera, and frees the overlay.
  4. Test passed with 100% success (documented in `DEFEAT_RETRY_RESULTS.json`).
- Updated `record_boss_lane_alignment.gd` so the stress fixture demonstrates active guard/counter cadence during `BOTTOM_LANE_DUEL`, keeping the hero alive throughout the demonstration clip.
