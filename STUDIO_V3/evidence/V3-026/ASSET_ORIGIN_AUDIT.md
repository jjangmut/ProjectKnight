# ProjectKnight V3-026: Combat Animation Asset Origin Audit

## 1. Asset Provenance & Pipeline Architecture
- **Reference**: *Dead Cells* 3D-to-2D sprite pipeline (3D bone armature -> key pose decimation -> orthographic 2D sprite rendering).
- **Source 3D Model**: `CLIENT/Game/assets/models/ProjectKnight_Paladin_Animated.glb` (Paladin_Mesh, Mat_Paladin_PBR, 4K Albedo).
- **Target Resolution**: 780x780 per cell, anchored at foot ground pivot `(390, 700)`.

## 2. Rendered Action Differentiation

| Combo Action | Output File | Grid | Frames | Mechanical Identity | Distinctive Silhouette |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Attack 1** | `combo1_slash.png` | 3x2 | 6 | Quick Horizontal Slash | Horizontal blade sweep at torso level, torso coiled back then driven through |
| **Attack 2** | `combo2_slash.png` | 3x2 | 6 | Reverse Rising Slash | Low crouch chamber driving vertically upward, tall heroic silhouette |
| **Attack 3** | `combo3_cleave.png` | 4x2 | 8 | Heavy Overhead Ground Cleave | Full overhead back-arch apex pose, slamming blade tip straight into ground |

## 3. Strict Verification & Gate Compliance
- [x] Generic 4-frame attack sheet eliminated.
- [x] Zero damage on startup frame ($t=0.0s$) maintained.
- [x] Real distinct PNG sprite assets committed to GitHub repository.
- [x] Humanoid scale and foot baseline matches runtime Sprite3D calibration.
