# [TASK-AR-019] Stage 5 (침묵의 성채) 렌더 성능 계측 및 60 FPS Gate 보고서

- **작업**: TASK-AR-019 Stage 5 Graphics Pass 005
- **작업 브랜치**: `antigravity/graphics-quality-pass-005-stage5`
- **측정 환경**: 1280×720 Landscape / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF
- **검측 프레임수**: 구간별 600 프레임 (총 2,400 프레임 정밀 계측)
- **상태**: **`INDEPENDENT REVIEW REQUESTED`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

## 1. 60 FPS Gate 충족 검증표

| 측정 구간 | 기준 Avg FPS (>=60) | 실측 Avg FPS | 기준 1% Low (>=45) | 실측 1% Low | 기준 P99 (<=22ms) | 실측 P99 | 게이트 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Entry (진입로)** | >= 60.0 | **230.1** | >= 45.0 | **157.5** | <= 22.0 ms | **6.35 ms** | **PASS** |
| **2. Mixed Combat (혼합 적 전투)** | >= 60.0 | **229.1** | >= 45.0 | **180.8** | <= 22.0 ms | **5.53 ms** | **PASS** |
| **3. Late Citadel (후반부 성채)** | >= 60.0 | **210.1** | >= 45.0 | **114.2** | <= 22.0 ms | **8.76 ms** | **PASS** |
| **4. Boss Combat (최종 심판실)** | >= 60.0 | **241.8** | >= 45.0 | **185.5** | <= 22.0 ms | **5.39 ms** | **PASS** |

## 2. 세부 프레임타임 및 렌더 리소스 분석

| 측정 구간 | 평균 프레임타임 | 최소 프레임타임 | P95 프레임타임 | 평균 Draw Calls | 활성 노드 수 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Entry** | 4.35 ms | 3.56 ms | 5.25 ms | 1358.5 | 465 |
| **2. Mixed Combat** | 4.36 ms | 3.57 ms | 5.23 ms | 1355.4 | 470 |
| **3. Late Citadel** | 4.76 ms | 3.71 ms | 6.61 ms | 1383.7 | 467 |
| **4. Boss Combat** | 4.14 ms | 3.50 ms | 5.03 ms | 1337.9 | 455 |

## 3. 최적화 및 렌더 파이프라인 준수 사항

1. **StageStaticArt 정적 캐시 아키텍처 100% 보존**:
   - Stage 5에 추가된 4계층 패럴랙스(검은 일식, 심연 첨탑군, 부유 회랑, 흑석 코니스 및 쇠사슬), 침묵의 3대 랜드마크(침묵의 왕문, 심연에 잠긴 왕좌 회랑, 최종 심판실 & 오벨리스크), 흑석 지주/현수 사슬이 `StageStaticArt`에 1회 사전 베이킹됨.
   - 런타임 불필요 리드로우 0건으로 200~280+ FPS의 압도적 헤드룸 확보.
2. **HUD Presentation 이벤트 구동 리드로우 계승**:
   - 상태 변경 시에만 갱신되는 이벤트 기반 구조 완벽 유지.
3. **동적 전투 효과의 선택적 렌더링 유지**:
   - 혼합 적(Charging Beast, Golem, Melee) 및 Abyssal Arbiter 전조/특수기는 공격 윈드업 및 액티브 상태에서만 제한적 리드로우되어 유휴 시 오버헤드 0% 보장.

## 4. 프로파일러 오버레이 캡처

- `profiler/01_entry_perf.png`
- `profiler/02_mixed_combat_perf.png`
- `profiler/03_late_citadel_perf.png`
- `profiler/04_boss_combat_perf.png`
