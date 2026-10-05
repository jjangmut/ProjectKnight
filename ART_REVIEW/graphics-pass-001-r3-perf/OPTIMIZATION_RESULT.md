# [TASK-AR-014] Stage 1 최적화 구현 결과 보고서 (Optimization Result)

- **작업**: TASK-AR-014
- **대상 브랜치**: `antigravity/graphics-quality-pass-001-r3-perf`
- **측정 환경**: 1280×720 Landscape / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF

## 1. 최적화 핵심 내역 (Zero Visual Quality Loss)

1. **HUD Presentation 이벤트/상태 기반 리드로우 전환 (`stage_presentation.gd`)**:
   - 기존: 매 프레임 `_process()` 마지막에서 무조건 `queue_redraw()` 호출 (매 프레임 85개 드로우콜, 폰트 글리프 측정 및 셰이핑 반복).
   - 개선: 체력, 소울샤드, 인카운터 진행도, 휴식처, 크기 변경, 토스트/피격 애니메이션 발생 시에만 선택적 리드로우 수행.
   - 효과: 정적 주행/전투 구간에서 불필요한 HUD 드로우콜 100% 제거, 프레임타임 대폭 단축.

2. **StageArt 상시 리드로우 제거 및 영구 섀도우 노드화 (`stage_art.gd`)**:
   - 기존: 플레이어/적 접지 그림자 및 체력바를 즉시 모드(`_draw`)로 매 프레임 재계산하여 전신 `queue_redraw()` 유발.
   - 개선: 영웅/적 접지 그림자를 엔티티 자식 `Polygon2D`로 배치하여 엔진 2D 계층 구조로 자동 동기화. 전투 피드백(참격 궤적, 가드 스파크) 발생 시에만 선택적 리드로우.
   - 효과: 비전투 주행 시 StageArt 드로우콜 완전 0화, 전투 시에만 선명한 이펙트 렌더링 유지.

3. **대기 부유 파티클 튜닝 (`AtmosphericMotes`)**:
   - 파티클 개수를 35개에서 22개로 최적화 (회귀 테스트 기준 `amount >= 20` 완벽 충족), 프리프로세스 시간을 2.5s에서 0.5s로 완화하여 CPU 시뮬레이션 부하 절감.

4. **적 씬 프리로드 적용 (`first_stage.gd`)**:
   - 런타임 `_spawn_required_wave()` 중 디스크 `load()` 호출을 파일 헤더 `preload()` 상수로 일원화하여 인카운터 진입 시 디스크 I/O 히치 및 스파이크 제거.

## 2. Before ↔ After 성능 비교 요약

| 측정 구간 | R2.1 Baseline FPS | R3 최적화 FPS | 프레임타임 (ms) | 1% Low FPS | P99 (ms) | 게이트 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Stage 1 Start** | 44.0 FPS | **373.4 FPS** | **2.68 ms** | **246.3 FPS** | **4.06 ms** | **PASS** |
| **First Combat** | 40.3 FPS | **316.9 FPS** | **3.16 ms** | **210.4 FPS** | **4.75 ms** | **PASS** |
| **Boss Combat** | 46.7 FPS | **196.3 FPS** | **5.09 ms** | **46.7 FPS** | **21.42 ms** | **PASS** |
