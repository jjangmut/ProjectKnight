# V3-026-R1-B — Recreate ALL hero combo animations in native 2D (NO 3D source or 3D-derived sprites)

**Project:** ProjectKnight Stage 1, Godot 4.7.2. **Branch:** `studio/v3-026-r1-rollback-broken-combo-art`.
**User's unambiguous decision:** "3D 기반 스프라이트 제외 하고 다시 제작해". 3D models/GLB/Blender renders converted to 2D are **not permitted** for this game-character animation task. Use hand-authored 2D sprite animation in the established hero identity/style. A 3D-to-2D pipeline is specifically REJECTED even if theoretically salvageable. Do not revive old 3D-rendered combo atlases under a new filename.

## 0. R1-A already implemented in GitHub, avoid reverting

R1-A commit `e8866feb0ad8c15cc03a7a06b32d7b248e81faf2` changes the runtime `side_qv_player.gd`: all three `TexCombo1/2/3` bindings now point to `TexAttack` known-good **2D** `attack_v1_aligned.png`; atlas metadata corrected to 2x2/4 frames and all three attack actions keep their **separate V3-026 physics timelines**. This is explicitly a temporary visual fallback, NOT distinct finished combo animation. It has NOT yet been run in Godot by ChatGPT; re-import, compile and regression test first.

## 1. Native 2D only production method

- Source sprites and canonical character design: `CLIENT/Game/assets/player_frames/idle_v1_aligned.png`, `run_v2_aligned.png`, `attack_v1_aligned.png`, `guard_v1_aligned.png`, other 2D action atlases. Audit silhouette, clothing/helmet, shield, sword, color palette, pixel density, feet, origin, and sprite margin to derive a cohesive **2D style sheet**. User wanted continuity with the pre-V3-026 hero, not a visibly different Paladin.
- Create **drawn 2D keyframes**, either pixel-painted frame-by-frame with Krita/Aseprite/LibreSprite or a genuine 2D-layer/cutout rig with hand-painted corrective keyframes. Compositing transforms of current 2D body parts are only acceptable if connected anatomy, proper hand grip, limb joints and foreshortening are visually convincing. **No Blender models, GLB, arbitrary bone rotation of 3D mesh, or rendering a 3D model into PNG. No generative single-frame copy-paste as a fake 8-frame animation.**
- Art direction: **true side-profile left/right facing** (mirror if handedness and shield positioning remain correct) as in V3-024-R1; Z-up/down moves retain the last X facing. Grounding, dark armor silhouette, pixel shading, gold/cyan highlights and proportions consistent with established sprites.
- Separate source project (layered .ora/.aseprite/.kra if available) and exportable PNG frames + reproducible scripted 2D atlas packer with frame metadata under `tools/2d_combat_animation`. Keep versions and licenses; do not flatten and discard all editable originals. Use 780×780 cell, pivot x=390/y=700 **measured from actual planted foot anchor**, not from bounding box of sword, cape, shadow, or effects.
- Hero actions:
  - Combo1 **horizontal cut**: ≥6 distinct purposeful hand-drawn 2D poses (anticipation→acceleration→contact→follow-through→settle), ensure visible sweep and actual grip.
  - Combo2 **reverse rising cut**: ≥6 distinct hand-drawn frames, clearly different starting point/body turn/blade trail from Combo1.
  - Combo3 **heavy overhead cleave**: ≥8 purposeful frames, distinctive planted foot/weight shift/sword raised/impact/recovery. No involuntary upward world jump, dislocated anatomy or weapon popping.
  - Keep attack timing as defined by CombatActionDefinition and contact triggered by existing CombatTimelineController; art contact pose must coincide with active hitbox marker (1x visual check at 60fps).
- Hero idle/run/attack transition seamless. No hard color/shape/pixel-size change between idle and attack. Left/right view continuity under Z sidesteps. Draw sword and arm separately only if attachment stays anchored on each frame.

## 2. Hard visual gates PRIOR to replacing runtime sprites

1. **Combo1 only** first: deliver exact 2D hand-drawn source frames/atlas, 1280x720 in-game actual side-facing test footage at 1x, 8-frame contact sheet with large isolated pose. Human/art director must inspect actual raster pixels, not filenames or tests. **If failed, do not produce Combo2/3 yet**; keep current known-good fallback live.
2. After explicit visual approval, author Combo2 and Combo3 in same 2D workflow. Run each idle→run→attack→idle transition without pop, weapon alignment, physical hit synchronization and end-of-combo recovery. Do not commit visual binding until all animated samples checked.
3. Keep bad 3D-combo assets archived in Git history only, but remove them from all active runtime references; create `2D_ASSET_ALLOWLIST.json` identifying art source and allowed atlas per action, `REJECTED_3D_ASSETS.json` registering `combo1_slash.png`, `combo2_slash.png`, `combo3_cleave.png` as rejected **by provenance**. Any new 3D-derived image should fail an automated asset provenance check even if it looks intact.
4. Check **actual animation motion**: key poses distinct at 1x with VFX/audio OFF, no frame dislocation/crop, consistent shading/pivot, recognizable sword orientation. With effects ON, hitstop/piercing sounds accentuate contact rather than obscure. No 3D geometry, 3D model fragment, random pasted frame.
5. Each output sprite sheet has row-major packing that exactly matches GDScript `hframes/vframes/total_frames` and the action definition's `windup_frames/active_frames/recovery_frames`. No accidental old 4-frame metadata or index overflow.
6. **QA independent visual gate** cannot be substituted by technical PASS, prerecorded reports or synthetic 9.x game director score. User's gameplay observation overrides art test claims.

## 3. Technical and gameplay regression

- Preserve R1-A removal of broken sprite while retaining new V3-026 event synchronization, scoped hitpause, player cancel windows and enemy/boss attack phases. Do not re-enable damage at input frame 0.
- Verify 1x in Godot source build: combo1,2,3 twice consecutively; mirrored left/right; same facing while moving Z, dodge/guard cancels, hurt/parry and triple cleave boss.
- Run V3-022 projectile/pillar/pogo, V3-024-R2 corner Z escape, V3-024-R3 lane match, V3-024-R4 death/retry camera visibility, V3-025 enemy telegraphs and pacing, V3-026 temporal contact/anti-duplicate tests.
- Capture short isolated 1x 60fps movie `D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-026-R1/Native2D_ComboVisualReview_1x.mp4` and full Stage1 `Stage1_Native2DCombat_1x.mp4` only after accepted visual assets. Deliver real 1280×720 frames with SHA/run ID and label human vs bot.
- Under `STUDIO_V3/evidence/V3-026-R1/` include `NATIVE_2D_ART_BIBLE.md`, `SOURCE_ASSET_MANIFEST.json`, `2D_ASSET_ALLOWLIST.json`, `REJECTED_3D_ASSETS.json`, `COMBO_FRAME_CONTACT_SHEETS/`, `COMBAT_EVENT_TIMELINE.json`, `REGRESSION_RESULTS.json`, `VISUAL_REVIEW_GATE.md`, `VIDEO_PROVENANCE.json`.

## 4. Status and execution order

**R1-A:** DONE (code binding fallback only, awaiting actual local Godot test).  
**R1-B1:** author authentic 2D Combo1 → visual approval / hold.  
**R1-B2:** distinct authentic 2D Combo2 and 3 after B1 approval.  
**R1-C:** integrate approved 2D atlases, full Stage1 natural, regression, user footage.

If a true 2D artist/authoring tool isn't available, explicitly report `2D_ART_AUTHORING_BLOCKED` and keep known-good fallback; **do not silently use a 3D model** to satisfy time pressure. This scope is restricted to Stage1 hero actions; enemies still use their original 2D assets.

**Stop condition:** If attacking shows the visually unrelated/broken 3D Paladin again, R1 FAIL instantly regardless of test status.