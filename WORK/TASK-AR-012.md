# [TASK-AR-012] Stage 1 Graphics R1 코드 리뷰 Blocker 수정

- 상태: READY
- 담당: Antigravity / JPStudio Graphics Quality Director + Client QA
- 우선순위: P0
- 선행 브랜치: `antigravity/graphics-quality-pass-001-r1`
- 검수 문서: `ART_REVIEW/GRAPHICS_PASS_001_R1_CODE_REVIEW.md`
- 목표: PR #6의 코드 Blocker를 제거한 뒤 독립 검수 재요청

## 1. 작업 브랜치

`antigravity/graphics-quality-pass-001-r2`

기준:
`antigravity/graphics-quality-pass-001-r1` 최신 HEAD

Stage 2 작업은 계속 금지한다.

## 2. P0 — StageArt 정적/동적 렌더 분리

현재 `stage_art.gd`는 `_process()`에서 매 프레임 `queue_redraw()`를 호출하면서 정적 지형/코벨/마커까지 다시 계산한다.

### 필수 수정
- 정적 지형 geometry cache 구축
- corbel/support 좌표 캐시
- route/gate/checkpoint 정적 장식은 변경 시에만 rebuild
- 동적 combat feedback과 정적 stage decoration redraw 분리

### 금지
"RTX 5060에서 문제 없음"으로 종료 금지.

모바일을 고려한 구조적 비용 감소가 확인되어야 한다.

## 3. P0 — Optional Encounter 게임 로직 원복/분리

`_spawn_boss_encounter()`에서:
- optional actor queue_free
- actors.clear
- group.cleared = true

를 그래픽 목적만으로 수행하지 않는다.

### 기본 조치
Pass 001-R1 이전 게임플레이 상태 의미를 보존한다.

필요하면 화면 밖 적 표시만 억제하는 presentation-only 방법을 사용한다.

게임플레이 정책 변경이 필요하다고 판단하면 별도 TASK를 작성하고 이번 그래픽 브랜치에서는 제외한다.

## 4. P1 — Boss Telegraph HDR 검증

현재 HDR 전조:
- width 4.2
- HDR RGB 최대 4.0
- fill alpha 0.38

을 실제 렌더 프레임으로 다시 검토한다.

최소 캡처:
- 밝은 Stage 1 배경
- 어두운 구간
- 공격 시작
- 공격 active 직전

경계가 Bloom에 뭉개지면 intensity 또는 fill을 낮춘다.

## 5. P1 — 성능 측정

PC에서라도 다음을 기록한다.

### Stage 1 Start
- 평균 FPS
- 최저 FPS

### First Combat
- 평균 FPS
- 최저 FPS

### Boss Combat
- 평균 FPS
- 최저 FPS

VSync/프레임 제한 때문에 수치가 고정되면 Godot profiler에서:
- frame time
- process time
- physics time

을 기록한다.

## 6. 자동 테스트

기존 10개 회귀 테스트 재실행.

추가 테스트:
- Optional Encounter 상태 보존 테스트
- boss encounter 진입 후 optional_completed 의미 보존
- StageArt cache/rebuild smoke 가능하면 추가

## 7. 산출물

`ART_REVIEW/graphics-pass-001-r2/`

최소:
- CODE_REVIEW_FIX_REPORT.md
- performance.md
- telegraph 밝기 비교 캡처
- 수정 파일 목록
- 테스트 결과

## 8. 완료 조건

- P0 두 항목 해결
- 기존 gameplay 의미 보존
- 성능 보고와 코드 내용 일치
- HDR 캡처 검토
- 테스트 PASS
- STATE.md 갱신
- commit + push
- PR #6 업데이트 또는 새 독립 검수 PR 준비

완료 시 상태는:
`INDEPENDENT REVIEW REQUESTED`

이며 자체 PASS를 선언하지 않는다.
