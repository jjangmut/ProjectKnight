# [TASK-AR-014] Stage 1 R2.1 Baseline 계측 보고서

- **측정 환경**: 1280×720 / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF / Engine.max_fps=0
- **샘플 수**: 구간별 300 프레임 (동일 입력 시뮬레이션)

## 1. Baseline 실측 지표 요약

| 측정 구간 | 평균 FPS | 1% Low FPS | 평균 프레임타임 | P95 | P99 | Process 시간 | Render 시간 | Draw Calls |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Stage 1 Start** | **44.0** | 22.5 | 22.70 ms | 39.19 ms | 44.36 ms | 0.00 ms | 0.00 ms | 543.2 |
| **First Combat** | **40.3** | 12.2 | 24.81 ms | 40.44 ms | 81.87 ms | 0.00 ms | 0.00 ms | 555.2 |
| **Boss Combat** | **46.7** | 25.5 | 21.41 ms | 33.52 ms | 39.23 ms | 0.00 ms | 0.00 ms | 500.8 |
