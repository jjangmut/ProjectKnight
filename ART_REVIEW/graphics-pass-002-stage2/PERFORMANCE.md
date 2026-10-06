# [TASK-AR-015] Stage 2 (야수숲) 렌더 성능 계측 및 60 FPS Gate 보고서

- **작업**: TASK-AR-015 Stage 2 Graphics Pass 002
- **작업 브랜치**: `antigravity/graphics-quality-pass-002-stage2`
- **측정 환경**: 1280×720 Landscape / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF
- **검측 프레임수**: 구간별 600 프레임 (총 2,400 프레임 정밀 계측)
- **상태**: **`INDEPENDENT REVIEW REQUESTED`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

## 1. 60 FPS Gate 충족 검증표

| 측정 구간 | 기준 Avg FPS (>=60) | 실측 Avg FPS | 기준 1% Low (>=45) | 실측 1% Low | 기준 P99 (<=22ms) | 실측 P99 | 게이트 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Entry (진입로)** | >= 60.0 | **270.6** | >= 45.0 | **222.0** | <= 22.0 ms | **4.50 ms** | **PASS** |
| **2. First Beast (첫 전투)** | >= 60.0 | **257.7** | >= 45.0 | **201.9** | <= 22.0 ms | **4.95 ms** | **PASS** |
| **3. Mid Forest (중반 숲길)** | >= 60.0 | **244.1** | >= 45.0 | **177.3** | <= 22.0 ms | **5.64 ms** | **PASS** |
| **4. Boss Combat (보스 아레나)** | >= 60.0 | **272.5** | >= 45.0 | **223.3** | <= 22.0 ms | **4.48 ms** | **PASS** |

## 2. 세부 프레임타임 및 렌더 리소스 분석

| 측정 구간 | 평균 프레임타임 | 최소 프레임타임 | P95 프레임타임 | 평균 Draw Calls | 활성 노드 수 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Entry** | 3.69 ms | 3.28 ms | 4.16 ms | 1209.7 | 299 |
| **2. First Beast** | 3.88 ms | 3.33 ms | 4.45 ms | 1217.9 | 304 |
| **3. Mid Forest** | 4.10 ms | 3.36 ms | 4.95 ms | 1231.1 | 311 |
| **4. Boss Combat** | 3.67 ms | 3.26 ms | 4.19 ms | 1176.7 | 290 |

## 3. 최적화 및 렌더 파이프라인 준수 사항

1. **StageStaticArt 정적 캐시 아키텍처 완전 유지**:
   - Stage 2에 추가된 4계층 패럴랙스, 고대 랜드마크 3종, 이끼/덩굴 식생, 지하고둥 뿌리 지지대가 모두 1회 베이킹되어 정적 노드로 유지됨.
   - 매 프레임 `queue_redraw()`를 유발하지 않아 4개 전 구간 평균 FPS 200~300+의 고성능 달성.
2. **HUD Presentation 이벤트 구동 리드로우 계승**:
   - Stage 1 최적화 패스에서 구현된 이벤트 기반 HUD 갱신이 Stage 2에서도 완벽 호환되어 드로우콜 오버헤드 억제.
3. **동적 전투 효과(전조 및 피격)의 선택적 리드로우**:
   - Charging Beast의 호박색 셰브론 지면 전조는 공격 윈드업 구간에만 발동되어 평상시 주행 프레임에 제로 부하 부여.

## 4. 프로파일러 오버레이 캡처

- `profiler/01_entry_perf.png`
- `profiler/02_first_beast_perf.png`
- `profiler/03_mid_forest_perf.png`
- `profiler/04_boss_combat_perf.png`
