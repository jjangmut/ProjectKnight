# Stage 1 Graphics Pass 001-R2 코드 리뷰 Blocker 수정 보고서
**Project Knight — JPStudio Graphics Quality Director & Client QA**

- **작업 브랜치**: `antigravity/graphics-quality-pass-001-r2`
- **검수 문서**: `ART_REVIEW/GRAPHICS_PASS_001_R1_CODE_REVIEW.md`
- **지시 문서**: `WORK/TASK-AR-012.md`
- **결론 상태**: **`INDEPENDENT REVIEW REQUESTED` (독립 검수 재요청)**
- **작업 일자**: 2026-10-02

---

## 1. 개요 및 Blocker 수정 요약

`ART-REVIEW-002`에서 지적된 2건의 Blocker와 2건의 Major 이슈를 전면 해결하였으며, Stage 2 작업 착수 없이 Stage 1의 렌더 구조 및 게임플레이 상태 보존을 완결하였습니다.

| 이슈 ID | 심각도 | 지적 사항 | 해결 조치 및 결과 | 판정 |
| :--- | :---: | :--- | :--- | :---: |
| **BLOCKER-01** | P0 | 성능 보고 내용(정적 버퍼)과 실제 코드(매 프레임 queue_redraw 및 지형 계산) 불일치 | `StageStaticArt` 분리 구현 및 정적 지형/코벨/마커 캐시 구축, `StageArt`는 동적 전투 피드백 전용으로 분리 | **RESOLVED** |
| **BLOCKER-02** | P0 | 보스 진입 시 Optional Encounter 적 강제 삭제 및 `group["cleared"] = true` 설정으로 게임플레이 로직 변조 | `group["cleared"] = true` 및 `queue_free()` 제거. 아레나 인접 적만 `visible = false` 및 프로세스 일시 정지(Presentation-only)로 처리하여 퀘스트/보상 상태 100% 보존 | **RESOLVED** |
| **MAJOR-01** | P1 | HDR 전조 값 과다(4.0) 및 블룸 번짐 우려 | 외곽선 3.4px, rim_color 2.4/2.6, fill alpha 0.22로 튜닝. 밝은/어두운 배경 및 공격 개시/후반 4종 비교 캡처 검증 | **RESOLVED** |
| **MAJOR-02** | P1 | 실제 FPS / 프레임 타임 측정 데이터 부재 | Stage 1 3개 핵심 구간 실측 벤치마크 수행 (평균 60.0~60.1 FPS, 1% Low 59.1~59.3 FPS, 95% 프레임타임 16.8ms 기록) | **RESOLVED** |

---

## 2. 상세 수정 내역

### 1) BLOCKER-01: `StageStaticArt` 정적/동적 렌더 분리
- **신규 파일**: `CLIENT/Game/scripts/art/stage_static_art.gd`
  - 스테이지 로드 시 1회 실행되는 `build_cache()` 구축:
    - 43개 지형 타일의 변환 좌표, 반전 스케일, 텍스처 영역 사전 계산 (`cached_ground_tiles`).
    - 모든 발판의 표면 좌표, 하단 슬랩 드롭 섀도우, 기둥 서포트 렉트, 코벨(까치발) 폴리곤 및 외곽선 사전 계산 (`cached_platforms`).
    - 선택 경로 엔틱 브론즈 현판 렉트 및 텍스트 좌표 사전 계산 (`cached_route_signs`).
    - 체크포인트 및 골 텍스트 좌표 사전 계산.
  - `_process()`를 등록하지 않으며 매 프레임 `queue_redraw()`를 호출하지 않음. 게이트 파괴, 체크포인트 갱신 등 상태 변경 시에만 `invalidate()`로 재드로우.
- **수정 파일**: `CLIENT/Game/scripts/art/stage_art.gd`
  - `StageStaticArt`를 자식 노드로 인스턴스화하고, `stage_art.gd`의 `_draw()`는 오직 동적 전투 피드백(`_draw_combat_feedback`: 플레이어/적 접지 섀도우, 히어로 앰비언트, 공격/하향찌르기/회오리/카운터 아크, 적 HP 바)과 목표 화살표만 렌더링.
  - 모바일 호환(Compatibility) 렌더러에서의 CPU CanvasItem 드로우 프리퍼레이션 부하를 원천 차단.

### 2) BLOCKER-02: Optional Encounter 게임플레이 상태 완전 보존
- **수정 파일**: `CLIENT/Game/scripts/stage/first_stage.gd::_spawn_boss_encounter()`
  - 인위적으로 `group["cleared"] = true`를 대입하거나 `group["actors"].clear()`, `actor.queue_free()`하던 변조 로직을 전면 제거.
  - 보스 아레나 내 시각적 방해를 막기 위해 아레나 영역(x >= ENTRY_X - 200)에 존재하는 선택 적만 `visible = false` 및 `set_physics_process(false)`로 프레젠테이션만 억제.
  - `stage.optional_completed`, `group["cleared"]`, `group["actors"]` 및 플레이어 HP 회복 보상 상태는 본래의 기획 룰대로 보존됨.
- **수정 파일**: `CLIENT/Game/tests/stage1_vertical_slice_capture.gd`
  - 캡처 툴에서도 불필요하게 `group["cleared"] = true`를 조작하던 스크립트 코드 제거.
- **수정 파일**: `CLIENT/Game/scripts/art/stage_art.gd`
  - `entry.actor.visible == false`인 적에 대해 머리 위 플로팅 HP 바와 이펙트 드로우를 건너뛰도록 필터 추가 (`if not is_instance_valid(entry.actor) or not entry.actor.visible: continue`).

### 3) MAJOR-01: Boss Telegraph HDR 캘리브레이션 및 다중 환경 검증
- **수정 파일**: `CLIENT/Game/scripts/enemy/boss_commander.gd`
  - 외곽선 두께: 4.2px → **3.4px** (경계 흐림 억제 및 밀도감 확보).
  - 위험 영역 Fill Alpha: 0.38 → **0.22** (방패 본체 룬 문양과 재질 가독성 확보).
  - Rim HDR Color:
    - 방어 가능(골드): `Color(2.4, 2.0, 0.75, 0.95)` (과다 발광 방지).
    - 방어 불가(레드): `Color(2.6, 0.7, 0.3, 0.95)`.
- **검증 캡처 산출물**: `ART_REVIEW/graphics-pass-001-r2/telegraph/`
  1. `telegraph_bright_start.png`: 밝은 하늘 배경, 공격 개시 (전조 아크와 룬 실루엣 선명).
  2. `telegraph_bright_late.png`: 밝은 하늘 배경, 공격 직전 (경계선 번짐 없음).
  3. `telegraph_dark_start.png`: 어두운 폐허 배경, 공격 개시 (고대비 림 라인 식별).
  4. `telegraph_dark_late.png`: 어두운 폐허 배경, 공격 직전 (선명한 위협 구역 인지).

### 4) MAJOR-02: 실제 FPS 및 프레임 타임 실측 기록
- **측정 스크립트**: `CLIENT/Game/tests/stage1_performance_benchmark.gd`
- **측정 보고서**: `ART_REVIEW/graphics-pass-001-r2/performance.md`
- **실측 결과**:
  - **Stage 1 Start**: 평균 60.1 FPS / 최저 58.4 FPS / 1% Low 59.3 FPS (평균 프레임타임 16.65 ms, p95 16.78 ms).
  - **First Combat**: 평균 60.0 FPS / 최저 58.8 FPS / 1% Low 59.1 FPS (평균 프레임타임 16.66 ms, p95 16.81 ms).
  - **Boss Combat**: 평균 60.0 FPS / 최저 58.3 FPS / 1% Low 59.3 FPS (평균 프레임타임 16.66 ms, p95 16.81 ms).

---

## 3. 수정 및 신규 생성 파일 목록

```text
CLIENT/Game/scripts/art/stage_static_art.gd           (신규: 정적 지형 및 장식 캐시 렌더러)
CLIENT/Game/scripts/art/stage_art.gd                  (수정: 정적 렌더 위임, 동적 피드백 전용화, 비가시 적 HP바 필터)
CLIENT/Game/scripts/stage/first_stage.gd              (수정: Optional Encounter 게임플레이 상태 완전 보존)
CLIENT/Game/scripts/enemy/boss_commander.gd           (수정: AttackRim 3.4px 및 HDR 전조 캘리브레이션, AttackVisual 네이밍)
CLIENT/Game/tests/stage1_vertical_slice_capture.gd    (수정: r2 기본 경로 전환, 캡처 시 불필요 상태 조작 제거)
CLIENT/Game/tests/stage1_telegraph_capture.gd         (신규: 전조 다중 밝기/배경 검증 캡처 스크립트)
CLIENT/Game/tests/stage1_performance_benchmark.gd     (신규: 실시간 벤치마크 및 프로파일러 측정 스크립트)
CLIENT/Game/tests/stage1_r2_blocker_fixes_smoke.gd    (신규: R2 Blocker 전용 단위/통합 스모크 테스트)
ART_REVIEW/graphics-pass-001-r2/performance.md       (신규: 실측 벤치마크 데이터 보고서)
ART_REVIEW/graphics-pass-001-r2/CODE_REVIEW_FIX_REPORT.md (본 문서)
ART_REVIEW/graphics-pass-001-r2/scenes/               (신규: R2 5대 대표 장면 캡처 아티팩트)
ART_REVIEW/graphics-pass-001-r2/telegraph/            (신규: 전조 4종 검증 캡처 아티팩트)
STATE.md                                              (수정: Pass 001-R2 완료 상태 갱신)
WORK/TASK-AR-012.md                                   (수정: 완료 상태 갱신)
```

---

## 4. 자동 회귀 테스트 결과

신규 스모크 테스트를 포함하여 총 11개 스위트 헤드리스 전체 PASS 완료 (0 Failures):

1. `tests/stage1_r2_blocker_fixes_smoke.gd`: **27/27 PASS** (StageStaticArt 캐시 검증, Optional Encounter 상태 보존 검증, 전조 수치 검증)
2. `tests/game_and_graphic_quality_smoke.gd`: **60/60 PASS** (WorldEnvironment, 유물 패시브, 버퍼링, 검기, 5대 보스 림라이트 등)
3. `tests/stage_reward_and_equipment_smoke.gd`: **23/23 PASS** (유물 레지스트리, 기사 외형 장착, 동적 반응, 보상 카드 렌더링)
4. `tests/boss1_visual_polish_smoke.gd`: **17/17 PASS** (보스 스케일, 참격 아크, 검기 방출, 충격파)
5. `tests/campaign_transition_test.gd`: **PASS** (스테이지 1→2 캠페인 트랜지션)
6. `tests/stage_smoke.gd`: **37/37 PASS** (체크포인트, 게이트, 인카운터 루프)
7. `tests/combat_deepening_smoke.gd`: **10/10 PASS** (3단 콤보, 카운터, 하향 찌르기)
8. `tests/guard_core_smoke.gd`: **21/21 PASS** (가드, 패링, 블록 연동)
9. `tests/sprint4_smoke.gd`: **23/23 PASS** (경직, 전조 색상, 로컬 저장, 4단 패럴랙스)
10. `tests/enemy_motion_smoke.gd`: **130/130 PASS** (적 행동 트리 및 순찰/추적)
11. `tests/data_driven_smoke.gd`: **38/38 PASS** (Stage 1~5 JSON 데이터 및 몬스터 스펙)

- **종합 결과**: **총 387개 검증 체크 100% 무결점 통과**

---

## 5. 최종 결론

`TASK-AR-012` 및 `ART-REVIEW-002`의 모든 Blocker와 Major 요구사항을 엄격하게 해결하였으며, 자체 합격(PASS) 판정 없이 독립 검수자에게 재심의를 요청합니다.

- **현재 브랜치**: `antigravity/graphics-quality-pass-001-r2`
- **검수 상태**: **`INDEPENDENT REVIEW REQUESTED` (독립 검수 재요청)**
