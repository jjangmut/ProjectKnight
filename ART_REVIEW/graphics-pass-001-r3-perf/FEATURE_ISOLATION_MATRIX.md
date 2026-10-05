# [TASK-AR-014] A/B Render Feature Isolation Matrix 및 병목 분류 보고서

- **작업**: TASK-AR-014
- **측정 환경**: RTX 5060 Laptop GPU / 1280×720 / Compatibility Renderer / VSync OFF

## 1. 기능 격리 계측 결과 요약 표 (First Combat 기준)

| 실험 ID | 격리 기능 및 설명 | 평균 FPS | 프레임타임 | 프레임타임 단축 | Render 시간 | 병목 분류 |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **BASELINE** | All Render Features ON (Default) | 40.3 FPS | 24.81 ms | +0.0% | 0.00 ms | BASELINE |
| **TEST_A** | WorldEnvironment Glow OFF | 36.5 FPS | 27.42 ms | -10.5% | 0.00 ms | NEGLIGIBLE / NOISE |
| **TEST_B** | StageCanvasModulate OFF | 165.3 FPS | 6.05 ms | +75.6% | 0.00 ms | **CRITICAL (>=20%)** |
| **TEST_C** | AtmosphericMotes (CPUParticles2D) OFF | 202.8 FPS | 4.93 ms | +80.1% | 0.00 ms | **CRITICAL (>=20%)** |
| **TEST_D** | ParallaxStageBackdrop OFF | 210.0 FPS | 4.76 ms | +80.8% | 0.00 ms | **CRITICAL (>=20%)** |
| **TEST_E** | StageArt Dynamic Draw OFF | 112.3 FPS | 8.91 ms | +64.1% | 0.00 ms | **CRITICAL (>=20%)** |
| **TEST_F** | HUD Presentation redraw OFF | 187.6 FPS | 5.33 ms | +78.5% | 0.00 ms | **CRITICAL (>=20%)** |
| **TEST_G** | MobileControls OFF | 221.5 FPS | 4.52 ms | +81.8% | 0.00 ms | **CRITICAL (>=20%)** |
| **COMBINED** | Combined Top Culprits OFF (Glow + HUD redraw + Motes) | 280.6 FPS | 3.56 ms | +85.6% | 0.00 ms | **CRITICAL (>=20%)** |

## 2. 3개 전 구간 기능 격리 전체 매트릭스

| 실험 ID | Stage Start FPS (ms) | First Combat FPS (ms) | Boss Combat FPS (ms) | Draw Calls (평균) |
| :--- | :---: | :---: | :---: | :---: |
| **BASELINE** | 44.0 (22.70 ms) | 40.3 (24.81 ms) | 46.7 (21.41 ms) | 543.2 / 555.2 / 500.8 |
| **TEST_A** | 38.3 (26.14 ms) | 36.5 (27.42 ms) | 42.6 (23.46 ms) | 532.7 / 554.0 / 500.6 |
| **TEST_B** | 35.9 (27.86 ms) | 165.3 (6.05 ms) | 243.8 (4.10 ms) | 524.5 / 553.1 / 499.7 |
| **TEST_C** | 210.1 (4.76 ms) | 202.8 (4.93 ms) | 170.8 (5.85 ms) | 539.5 / 551.8 / 498.8 |
| **TEST_D** | 180.7 (5.53 ms) | 210.0 (4.76 ms) | 187.6 (5.33 ms) | 538.2 / 549.5 / 492.8 |
| **TEST_E** | 231.1 (4.33 ms) | 112.3 (8.91 ms) | 93.3 (10.71 ms) | 538.8 / 547.2 / 499.9 |
| **TEST_F** | 347.8 (2.88 ms) | 187.6 (5.33 ms) | 331.5 (3.02 ms) | 458.2 / 471.0 / 442.5 |
| **TEST_G** | 158.1 (6.33 ms) | 221.5 (4.52 ms) | 161.9 (6.18 ms) | 477.6 / 488.5 / 435.8 |
| **COMBINED** | 363.5 (2.75 ms) | 280.6 (3.56 ms) | 337.4 (2.96 ms) | 457.2 / 469.6 / 441.7 |
