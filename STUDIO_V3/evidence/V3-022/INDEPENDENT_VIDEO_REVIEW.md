# V3-022 — Uploaded R1 Video: Independent Visual Review (2026-11-11)

**Evidence source:** user-uploaded actual `Stage1_Natural_Playtest.mp4` shared in ChatGPT, independently inspected (not merely report).  
**Container facts:** 29.733333s MP4; 1280×720 H.264 60fps 1,784 frames, AAC audio track; actual visual frames inspected at 0,2,4,...28s. This is **not** the 64.13-second natural E2E trial duration in previous telemetry; uncut provenance NOT established.  
**Comparison basis:** V3-021-R1 report/recording, not a human performance trial.

## Visible defects to reproduce/fix (timestamps = actual uploaded MP4 timeline)

| ID | Severity | Video time | Observation | Gate |
|---|---|---|---|---|
| VIS-001 | P0 | 0–16s | 3 encounter segments all visually occur on nearly identical repetitive flat-tiled walkway and stone balustrade. 100m technical length lacks distinctive staging or navigation experience; progress largely `PROCEED >>`. | Compare level world-space composition at X milestones; ask human to recognize three zones without overlays. |
| VIS-002 | P0 | 0–16s | Fight readability is weak at 1280×720: small sprites and tiny action UI/labels; player and opponents blend on repetitive tiles. | Record sprite pixel bounds, UI readability at phone-equivalent thumbnail, real screenshot review. |
| VIS-003 | P0 | 2,6,8,14,18–24s | Oversized cyan guard/parry discs, white slash traces, floor glyphs and hit counters frequently overlap actors. They can mask attack origin/contact and enemy telegraph; player silhouette/weapon direction hard to follow. | Capture frame aligned hit/guard/attack origins, overlay hitbox; reduce opacity/size only with visual proof. |
| VIS-004 | P0 | 18–24s | Boss confrontation reaches stage clear in ~6s of video. Even with automated input this does not demonstrate a readable multi-pattern, learning-and-counter sequence. | Uncut boss footage, distinct pre-windup active recovery beats for each pattern, no boss-enum-peeking acceptance. |
| VIS-005 | P1 | 24–28s | Victory displays near ~24s, then camera shows mostly the empty boss seal/floor at 26–28s without a recognizable hero/enemies; anticlimactic ending/focus continuity issue. | Check player/camera on stage-clear transition frame by frame; keep player framed and meaningful post-clear pose, don't just move game state to an arbitrary position. |
| VIS-006 | P0 | all | Up/down movement cannot be visually evaluated as 4-way authored movement animation from this video; the sprites read primarily as side-facing billboard characters. Directional physics tests alone cannot verify matching front/back swing motion and impact effect. | 4 cardinal + diagonal 120fps frame strips with pose, motion, actual hit point; fix/make missing authored animation explicit. |
| VIS-007 | P0 | 0–29.73s | Captured MP4 duration 29.73s, while R1 published E2E telemetry duration 64.13s. They are different timebases or not an uncut same run. | Reproduce run command, movie FPS/timebase, exact input and event trace synchronized to video. If speedup used, mark appropriately. |
| VIS-008 | P1 | 0–16s | Several encounters last only a few seconds before progression banners; level seems like a scripted showcase rather than natural escalating danger. | Real human play through Stage1, independent policy trials; map combat/travel duration in uncut elapsed runtime. |

## Boundaries on claims

- Video definitely shows a real 3D Godot-style rendered stage, 3 encounter banners, screen scrolling, a boss HUD, and stage-clear banner. It does NOT by itself establish depth movement precision, natural no-cheat state, attack-only punishment, hitbox/visual consistency, human playability or any sustained 2–4 min pace.
- A frame montage visual review is not objective audio/physics verification. A codec metadata check proves an AAC stream exists, not that every SFX is correct.
- Contact-sheet 2s interval review suggests early scene is mostly repeated tiled arena; check full temporal frames and original source before root-cause assertions. Do NOT claim complete visual QA before targeted frame inspection and a real person test.
- **P0 acceptance:** Stage1 must look and play like distinct spatial encounters and boss fight, readable animation/hit impacts, honest uncut video correlated to runtime event log. Existing 9.68 ratings are not proof.
