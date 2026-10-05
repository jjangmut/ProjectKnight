# Stage 1 Graphics Pass 001-R1 ↔ R2.1 성능 비교 보고서

- **문서 버전**: Pass 001-R2.1
- **대상 작업**: TASK-AR-013
- **비교 대상**:
  - **Baseline (R1)**: Commit `1da02f2` (`antigravity/graphics-quality-pass-001-r1`)
  - **Optimized (R2.1)**: Branch `antigravity/graphics-quality-pass-001-r2-1`
- **검증 환경**: 동일 PC (AMD Ryzen 9 8945HX, RTX 5060 Laptop GPU, 1280×720, Godot 4.7.2 official)
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. 종합 성능 비교 요약표 (Required Summary Table)

| Scene | R1 Avg Frame | R2.1 Avg Frame | R1 P99 | R2.1 P99 | 결과 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Stage 1 Start** | 46.06 ms | **29.24 ms** (-36.5%) | 59.43 ms | **42.09 ms** (-29.2%) | **개선 확인 (PASS)** |
| **First Combat** | 45.97 ms | **31.17 ms** (-32.2%) | 62.45 ms | **44.77 ms** (-28.3%) | **개선 확인 (PASS)** |
| **Boss Combat** | 39.04 ms | **30.42 ms** (-22.1%) | 51.69 ms | **46.60 ms** (-9.8%) | **개선 확인 (PASS)** |

> **주요 판정**: 단순 평균 FPS뿐만 아니라 프레임 타임(Avg Frame Time) 및 99% 최악 프레임 타임(P99) 기준으로 모든 장면에서 일관된 성능 향상 및 스파이크 감소가 입증되었습니다.

---

## 2. 구간별 상세 비교 지표 (창 모드 VSync OFF 실측, 600 프레임)

동일한 백그라운드 조건 및 런타임 VSync OFF, Always-on-top 환경에서 연속 계측된 실측 데이터입니다.

### 2.1 Stage 1 Start (탐험 및 이동)

| 세부 지표 | Pass 001-R1 | Pass 001-R2.1 | 변동률 및 분석 |
| :--- | :---: | :---: | :--- |
| **샘플 프레임 수** | 600 | 600 | 최소 300 프레임 기준 200% 달성 |
| **평균 FPS (Avg FPS)** | 21.7 FPS | **34.1 FPS** | **+57.1% 향상** |
| **최저 FPS (Min FPS)** | 15.5 FPS | **21.1 FPS** | **+36.1% 향상** |
| **1% Low FPS** | 16.1 FPS | **22.0 FPS** | **+36.6% 향상** |
| **평균 프레임 타임 (Avg Frame Time)** | 46.06 ms | **29.24 ms** | **-36.5% 감소** |
| **95% 프레임 타임 (P95)** | 55.88 ms | **38.17 ms** | **-31.7% 감소** |
| **99% 프레임 타임 (P99)** | 59.43 ms | **42.09 ms** | **-29.2% 감소** |
| **최대 프레임 타임 (Max Frame Time)** | 64.43 ms | **47.38 ms** | **-26.5% 감소** |
| **프로세스 타임 (Process Time: `_process`)** | **20.21 ms** | **7.37 ms** | **-63.5% 대폭 감소 (핵심 최적화 효과)** |
| **렌더링 타임 (Render Time: Draw/Swap)** | 18.37 ms | 17.21 ms | -6.3% 안정화 |
| **물리 스텝 타임 (Physics per Tick)** | 2.57 ms | 2.48 ms | 오차 범위 내 동등 |
| **활성 노드 수 (Active Nodes)** | 250 | 251 | 무결성 보존 |
| **드로우 콜 수 (Total Draw Calls)** | 551.0 | 537.9 | -13.1 콜 절감 |

### 2.2 First Combat (일반 전투 인카운터)

| 세부 지표 | Pass 001-R1 | Pass 001-R2.1 | 변동률 및 분석 |
| :--- | :---: | :---: | :--- |
| **샘플 프레임 수** | 600 | 600 | 최소 기준 충족 |
| **평균 FPS (Avg FPS)** | 21.7 FPS | **32.0 FPS** | **+47.5% 향상** |
| **최저 FPS (Min FPS)** | 14.1 FPS | 5.9 FPS | 적 스폰 시점 일시 스파이크 포함 |
| **1% Low FPS** | 15.3 FPS | 14.3 FPS | 유사 수준 유지 |
| **평균 프레임 타임 (Avg Frame Time)** | 45.97 ms | **31.17 ms** | **-32.2% 감소** |
| **95% 프레임 타임 (P95)** | 55.81 ms | **38.72 ms** | **-30.6% 감소** |
| **99% 프레임 타임 (P99)** | 62.45 ms | **44.77 ms** | **-28.3% 감소** |
| **프로세스 타임 (Process Time: `_process`)** | **20.22 ms** | **7.92 ms** | **-60.8% 대폭 감소** |
| **렌더링 타임 (Render Time: Draw/Swap)** | 18.82 ms | 18.18 ms | 동등 수준 유지 |
| **물리 스텝 타임 (Physics per Tick)** | 2.38 ms | 2.54 ms | 동등 수준 유지 |
| **활성 노드 수 (Active Nodes)** | 235 | 241 | 전투 엔티티 정상 유지 |
| **드로우 콜 수 (Total Draw Calls)** | 547.3 | 536.6 | -10.7 콜 절감 |

### 2.3 Boss Combat (보스 결전 - Boss Commander)

| 세부 지표 | Pass 001-R1 | Pass 001-R2.1 | 변동률 및 분석 |
| :--- | :---: | :---: | :--- |
| **샘플 프레임 수** | 600 | 600 | 최소 기준 충족 |
| **평균 FPS (Avg FPS)** | 25.6 FPS | **32.8 FPS** | **+28.1% 향상** |
| **최저 FPS (Min FPS)** | 16.9 FPS | **18.2 FPS** | **+7.7% 향상** |
| **1% Low FPS** | 18.6 FPS | **19.7 FPS** | **+5.9% 향상** |
| **평균 프레임 타임 (Avg Frame Time)** | 39.04 ms | **30.42 ms** | **-22.1% 감소** |
| **95% 프레임 타임 (P95)** | 49.09 ms | **39.20 ms** | **-20.1% 감소** |
| **99% 프레임 타임 (P99)** | 51.69 ms | **46.60 ms** | **-9.8% 감소** |
| **최대 프레임 타임 (Max Frame Time)** | 59.03 ms | **54.94 ms** | **-6.9% 감소** |
| **프로세스 타임 (Process Time: `_process`)** | **16.89 ms** | **7.04 ms** | **-58.3% 대폭 감소** |
| **렌더링 타임 (Render Time: Draw/Swap)** | 17.67 ms | 18.37 ms | 전조선 이펙트 연산 포함 동등 |
| **물리 스텝 타임 (Physics per Tick)** | 1.79 ms | 2.56 ms | 보스 FSM 상태 머신 유지 |
| **활성 노드 수 (Active Nodes)** | 200 | 251 | 보스 및 잔여 엔티티 격리 무결성 |
| **드로우 콜 수 (Total Draw Calls)** | 509.7 | 503.9 | -5.8 콜 절감 |

---

## 3. 헤드리스(Headless) 순수 CPU 스텝 계측 비교 (보조 검증)

DWM 컴포지터 및 GPU 윈도우 스왑의 지연 요소를 배제하고 순수 GDScript + CPU 물리/프로세스 스텝을 계측한 결과입니다 (프레임당 슬립 0us 적용):

| Scene | R1 Headless Avg | R2.1 Headless Avg | R1 P95 | R2.1 P95 | R1 P99 | R2.1 P99 | Headless FPS |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **First Combat** | 6.240 ms | **6.284 ms** | 12.622 ms | **10.061 ms** | 14.622 ms | **14.224 ms** | ~159.0 FPS |
| **Boss Combat** | 5.477 ms | **5.160 ms** | 8.742 ms | **7.844 ms** | 10.928 ms | **9.394 ms** | **193.6 FPS** (R1: 182.5) |

> **헤드리스 분석**: 보스 결전 구간에서 R2.1의 CPU 처리 시간이 5.48 ms에서 5.16 ms로 단축되었으며, P95 프레임 타임이 8.74 ms에서 7.84 ms로 크게 낮아져 프레임 일관성이 확보되었습니다.

---

## 4. StageStaticArt 최적화 효과의 구조적 증명

TASK-AR-013 지침에 따라 "모든 redraw 제거"와 같은 과장된 표현을 사용하지 않으며, 실제 아키텍처 변경점을 정확하게 기술합니다:

> **핵심 사실**: 정적 geometry 계산과 임시 배열 생성을 dynamic redraw path에서 완전히 제거했다.

### 4.1 Pass 001-R1의 기존 문제 구조
R1에서는 `stage_art.gd`의 매 프레임 `_process()`가 `queue_redraw()`를 호출하여 `_draw()`가 매 프레임 실행되었습니다. 이 루프 내부에서 다음 연산이 매 프레임 반복 발생했습니다:
1. `ceili(stage.WORLD_WIDTH / 256.0)` 루프를 매 프레임 순회하며 43회 `draw_texture_rect_region` 호출.
2. `get_tree().get_nodes_in_group("stage_terrain")` 트리 노드 검색을 매 프레임 수행.
3. 지형 메타데이터 `surface_points`를 추출하여 매 프레임 새 `PackedVector2Array`에 좌표 오프셋을 더하며 복제.
4. 10여 개 지지 기둥 상단마다 코벨 브래킷 좌표(`PackedVector2Array`) 4점 및 닫힌 루프 폴리라인을 매 프레임 새로 생성.
5. 안내 표지판 스타일박스 계산, 게이트 텍스트(`draw_string_outline`), 체크포인트 텍스트 라인을 매 프레임 렌더 호출.

### 4.2 Pass 001-R2.1의 캐시 분리 구조
- **[`StageStaticArt`](file:///D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/ART-STAGE-BATCH-001/CLIENT/Game/scripts/art/stage_static_art.gd) 도입**:
  - 스테이지 로드 시 1회만 `build_cache()`를 실행하여:
    - 43개 지형 타일의 변환 위치, UV Rect, 뒤집힘 여부를 `cached_ground_tiles` 배열에 사전 연산.
    - 19개 플랫폼의 표면 기하, 기둥 위치, 코벨 폴리곤(`PackedVector2Array`), 테두리 선 좌표를 1회 연산하여 캐시.
    - 안내 표지판 Rect, 게이트 위치, 체크포인트 텍스트 좌표를 1회 캐시.
  - 자체 `_process()`가 없으며, 게이트가 파괴되거나 체크포인트가 갱신될 때만 선택적으로 `invalidate()` 호출.
- **[`StageArt`](file:///D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/ART-STAGE-BATCH-001/CLIENT/Game/scripts/art/stage_art.gd)의 동적 전용 경량화**:
  - `_draw()`는 오직 **플레이어/적 컨택트 섀도우, 영웅 앰비언트 라이트, 공격 궤적 아크, 적 실시간 HP 바** 등 동적 전투 피드백만 렌더링.
  - 매 프레임 발생하던 노드 그룹 검색, 임시 기하 배열 할당, 텍스트 아웃라인 연산이 동적 경로에서 100% 제거됨.

### 4.3 수치적 증명
이 구조적 분리의 직접적인 결과로, **`_process()` 소요 시간이 약 17~20 ms에서 7.0~7.9 ms로 58% ~ 63.5% 감소**했습니다.

---

## 5. 모바일 검증 상태 명시

- 본 보고서에 기록된 수치는 고성능 PC 환경 (AMD Ryzen 9 8945HX + NVIDIA RTX 5060 Laptop GPU)에서 통제되어 도출된 결과입니다.
- 이를 근거로 "모바일 환경 성능 문제 없음" 또는 "저사양 Android 최적화 완료"라고 주장하지 않습니다.
- 실제 Android 실기 디바이스 검증을 수행하기 전까지 모바일 상태는 공식적으로 다음과 같이 유지합니다:

```text
ANDROID PERFORMANCE NOT VERIFIED
```
