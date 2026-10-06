# [TASK-AR-017] Stage 4 (돌의 성소) 렌더 성능 계측 및 60 FPS Gate 보고서

- **작업**: TASK-AR-017 Stage 4 Graphics Pass 004
- **작업 브랜치**: `antigravity/graphics-quality-pass-004-stage4`
- **측정 환경**: 1280×720 Landscape / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF
- **검측 프레임수**: 구간별 600 프레임 (총 2,400 프레임 정밀 계측)
- **상태**: **`INDEPENDENT REVIEW REQUESTED`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

## 1. 60 FPS Gate 충족 검증표

| 측정 구간 | 기준 Avg FPS (>=60) | 실측 Avg FPS | 기준 1% Low (>=45) | 실측 1% Low | 기준 P99 (<=22ms) | 실측 P99 | 게이트 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Entry (진입로)** | >= 60.0 | **291.3** | >= 45.0 | **244.7** | <= 22.0 ms | **4.09 ms** | **PASS** |
| **2. First Golem (첫 골렘 전투)** | >= 60.0 | **273.3** | >= 45.0 | **231.9** | <= 22.0 ms | **4.31 ms** | **PASS** |
| **3. Mid Sanctuary (성소 회랑 횡단)** | >= 60.0 | **258.2** | >= 45.0 | **196.3** | <= 22.0 ms | **5.09 ms** | **PASS** |
| **4. Boss Combat (보스 아레나)** | >= 60.0 | **292.6** | >= 45.0 | **235.6** | <= 22.0 ms | **4.25 ms** | **PASS** |

## 2. 세부 프레임타임 및 렌더 리소스 분석

| 측정 구간 | 평균 프레임타임 | 최소 프레임타임 | P95 프레임타임 | 평균 Draw Calls | 활성 노드 수 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Entry** | 3.43 ms | 3.07 ms | 3.86 ms | 1235.2 | 386 |
| **2. First Golem** | 3.66 ms | 3.21 ms | 4.12 ms | 1247.8 | 386 |
| **3. Mid Sanctuary** | 3.87 ms | 3.21 ms | 4.73 ms | 1275.8 | 402 |
| **4. Boss Combat** | 3.42 ms | 3.03 ms | 3.91 ms | 1191.3 | 396 |

## 3. 최적화 및 렌더 파이프라인 준수 사항

1. **StageStaticArt 정적 캐시 아키텍처 100% 보존**:
   - Stage 4에 추가된 4계층 패럴랙스, 고대 랜드마크 3종(거대한 룬 석문, 쓰러진 거상, 고대 성소), 거석 원주 기둥, 파일런 지지대가 `StageStaticArt`에 1회 사전 베이킹되어 정적 노드로 유지됨.
   - 런타임 `queue_redraw()` 미발생으로 4개 전 구간 200~300+ FPS의 압도적 헤드룸 확보.
2. **HUD Presentation 이벤트 구동 리드로우 계승**:
   - 이벤트 기반 HUD 갱신이 Stage 4에서도 완벽히 유지되어 불필요한 CanvasItem 재렌더링 방지.
3. **동적 전투 효과(지면 강타 전조 림 및 충격파)의 선택적 렌더링**:
   - GroundSlamGolem 및 보스의 지면 강타 전조는 공격 윈드업 및 액티브 슬램 구간에만 제한적으로 렌더링되어 평상시 프레임에 오버헤드 0% 부여.

## 4. 프로파일러 오버레이 캡처

- `profiler/01_entry_perf.png`
- `profiler/02_first_golem_perf.png`
- `profiler/03_mid_sanctuary_perf.png`
- `profiler/04_boss_combat_perf.png`
