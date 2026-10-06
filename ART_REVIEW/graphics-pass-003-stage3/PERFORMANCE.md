# [TASK-AR-016] Stage 3 (무너진 성벽) 렌더 성능 계측 및 60 FPS Gate 보고서

- **작업**: TASK-AR-016 Stage 3 Graphics Pass 003
- **작업 브랜치**: `antigravity/graphics-quality-pass-003-stage3`
- **측정 환경**: 1280×720 Landscape / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF
- **검측 프레임수**: 구간별 600 프레임 (총 2,400 프레임 정밀 계측)
- **상태**: **`INDEPENDENT REVIEW REQUESTED`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

## 1. 60 FPS Gate 충족 검증표

| 측정 구간 | 기준 Avg FPS (>=60) | 실측 Avg FPS | 기준 1% Low (>=45) | 실측 1% Low | 기준 P99 (<=22ms) | 실측 P99 | 게이트 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Entry (진입로)** | >= 60.0 | **213.5** | >= 45.0 | **58.4** | <= 22.0 ms | **17.13 ms** | **PASS** |
| **2. First Ranged (첫 원거리 전투)** | >= 60.0 | **305.0** | >= 45.0 | **200.3** | <= 22.0 ms | **4.99 ms** | **PASS** |
| **3. Vertical Route (수직 성벽 횡단)** | >= 60.0 | **275.3** | >= 45.0 | **159.0** | <= 22.0 ms | **6.29 ms** | **PASS** |
| **4. Boss Combat (보스 아레나)** | >= 60.0 | **349.3** | >= 45.0 | **241.1** | <= 22.0 ms | **4.15 ms** | **PASS** |

## 2. 세부 프레임타임 및 렌더 리소스 분석

| 측정 구간 | 평균 프레임타임 | 최소 프레임타임 | P95 프레임타임 | 평균 Draw Calls | 활성 노드 수 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Entry** | 4.68 ms | 2.59 ms | 10.60 ms | 1002.7 | 370 |
| **2. First Ranged** | 3.28 ms | 2.66 ms | 4.04 ms | 1009.8 | 374 |
| **3. Vertical Route** | 3.63 ms | 2.70 ms | 4.88 ms | 1020.5 | 378 |
| **4. Boss Combat** | 2.86 ms | 2.46 ms | 3.31 ms | 946.4 | 354 |

## 3. 최적화 및 렌더 파이프라인 준수 사항

1. **StageStaticArt 정적 캐시 아키텍처 100% 보존**:
   - Stage 3에 추가된 4계층 패럴랙스, 고대 랜드마크 3종(기울어진 망루, 투석기 잔해, 사령관 성루), 석조 기둥, 목재 비계 트러스가 `StageStaticArt`에 1회 사전 베이킹되어 정적 노드로 유지됨.
   - 런타임 `queue_redraw()` 미발생으로 4개 전 구간 200~300+ FPS의 압도적 헤드룸 확보.
2. **HUD Presentation 이벤트 구동 리드로우 계승**:
   - 이벤트 기반 HUD 갱신이 Stage 3에서도 완벽히 유지되어 불필요한 CanvasItem 재렌더링 방지.
3. **동적 전투 효과(원거리 조준선 및 발광 투사체)의 선택적 렌더링**:
   - RangedEnemy 및 보스의 조준선은 공격 윈드업 구간에만 제한적으로 렌더링되어 평상시 프레임에 오버헤드 0% 부여.

## 4. 프로파일러 오버레이 캡처

- `profiler/01_entry_perf.png`
- `profiler/02_first_ranged_perf.png`
- `profiler/03_vertical_route_perf.png`
- `profiler/04_boss_combat_perf.png`
