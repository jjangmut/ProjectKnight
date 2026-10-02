# [ART-REVIEW-002] Stage 1 Graphics Pass 001-R1 코드 독립 리뷰

- 검수일: 2026-10-02
- 대상 PR: #6
- 대상 브랜치: `antigravity/graphics-quality-pass-001-r1`
- 대상 HEAD: `1da02f2b`
- 검수자: ChatGPT / Studio QA Review
- 결론: **CHANGES REQUIRED**
- Stage 2 진행: **보류**

## 1. 결론 요약

Pass 001-R1은 이전 Pass 001보다 운영 절차가 개선되었다.

확인된 긍정 요소:
- Cycle A / Cycle B 2회 반복 수행
- baseline / cycle_a / cycle_b 5개 대표 장면 보존
- 10개 회귀 테스트 실행 기록
- Android 미검증 상태를 명확히 기록
- 자기평가 대신 독립 검수 요청 상태로 종료

그러나 코드 리뷰에서 아래 두 가지 Blocker를 확인했다.

1. 성능 보고 내용과 실제 `stage_art.gd` 구현이 일치하지 않음
2. 그래픽 패스 안에 실제 게임플레이 상태 변경이 포함됨

따라서 PR #6은 현재 상태로 `integration` 병합하지 않는다.

---

## 2. BLOCKER-01 — 성능 보고와 실제 렌더링 코드 불일치

### 보고 내용

`ART_REVIEW/graphics-pass-001-r1/REVIEW.md`에는 다음과 같이 적혀 있다.

- 지형 코벨 및 발판 섀도우는 초기 로드 시 1회 정적 버퍼에 생성
- 프레임당 재할당 비용 0

### 실제 코드

`CLIENT/Game/scripts/art/stage_art.gd`는 `_process()` 마지막에서 매 프레임:

```gdscript
queue_redraw()
```

를 호출한다.

그리고 `_draw()`에서 매번 다음 작업을 수행한다.

- `get_tree().get_nodes_in_group("stage_terrain")`
- `PackedVector2Array()` 신규 생성
- 각 지형 surface point 재조합
- `Rect2` 생성
- `PackedVector2Array([...])`로 corbel 신규 생성
- `draw_texture_rect_region`
- `draw_colored_polygon`
- `draw_polyline`
- 전체 Stage gate/checkpoint/goal marker 재그리기
- combat feedback 재그리기

따라서 "초기 로드 시 1회 정적 버퍼" 및 "프레임당 재할당 비용 0"이라는 설명은 현재 코드와 일치하지 않는다.

### 위험

Stage 1에서는 RTX 5060 Laptop 환경이라 문제가 눈에 띄지 않을 수 있다.

하지만 모바일 Compatibility Renderer에서는:
- CPU draw preparation 증가
- 매 프레임 임시 배열 생성
- 긴 Stage 전체 지형 반복
- UI/VFX와 함께 CanvasItem draw 비용 증가

가능성이 있다.

### 요구 수정

정적 환경 장식과 동적 전투 피드백을 분리한다.

권장 구조:

```text
StageStaticArt
 ├─ terrain edge
 ├─ platform corbel
 ├─ route sign frame
 ├─ gate decorative geometry
 └─ static world labels

StageDynamicArt
 ├─ player/enemy shadow
 ├─ attack VFX
 ├─ hit feedback
 └─ moving marker
```

정적 요소는:
- 최초 생성 시 Node2D/Polygon2D/Line2D로 캐시하거나
- 별도 CanvasItem에서 변경 시에만 queue_redraw

동적 요소만 매 프레임 redraw한다.

최소한:
- 지형 목록
- surface point 변환
- corbel polygon

을 캐시하여 매 프레임 재생성하지 않는다.

---

## 3. BLOCKER-02 — 그래픽 패스에 게임플레이 로직 변경 혼입

### 실제 변경

`first_stage.gd::_spawn_boss_encounter()`에 다음 로직이 추가되어 있다.

```gdscript
for group in optional_groups:
    for actor in group.get("actors", []):
        if is_instance_valid(actor):
            actor.queue_free()
    group["actors"].clear()
    group["cleared"] = true
```

### 문제

이 코드는 단순 비주얼 정리가 아니다.

선택 전투 적을:
- 강제 제거
- actors 목록에서 제거
- cleared 상태로 변경

한다.

이는 실제 Stage 상태와 선택 전투 결과를 바꾸는 게임플레이 로직이다.

특히 기존 선택 전투는:
- 시작 여부
- 적 처치 여부
- HP +1 보상
- optional_completed

등과 연동되어 있다.

보스 진입 시 살아 있는 적을 단순히 지워버리면서 `group["cleared"] = true`를 설정하면 "플레이어가 처치하지 않은 선택 전투"를 시스템상 완료처럼 보이게 만들 수 있다.

현재 `optional_completed`와 `defeated` 배열까지 동일하게 갱신하지 않으므로 상태 의미도 불일치할 수 있다.

### 요구 수정

그래픽 패스에서는 다음 중 하나로 처리한다.

#### 방법 A — 시각적/AI 비활성화만
보스 진입 시 화면에 방해되는 Optional Enemy를:
- visible false
- process disabled
- collision disabled

등으로 처리하되 진행 상태/보상 상태는 변경하지 않는다.

#### 방법 B — 별도 Gameplay Task로 분리
"보스 진입 시 미완료 Optional Encounter를 종료한다"가 실제 기획 의도라면:
- 별도 TASK-PL/CL
- 별도 커밋
- 보상 정책 결정
- Save/checkpoint 영향 검증

을 거친다.

현재 Graphics PR에서 `group["cleared"] = true` 변경은 제거하는 것이 우선이다.

---

## 4. MAJOR-01 — HDR Telegraph 값 재검증 필요

`boss_commander.gd`에서 공격 전조 값이 다음 수준까지 올라갔다.

```text
rim_color = Color(4.0, 3.2, 1.0, 1.0)
AttackRim.width = 4.2
fill alpha = 0.38
```

HDR 4.0 값 자체가 잘못된 것은 아니다.

그러나 작업 원칙은 "Glow/HDR 수치 증가를 품질 개선으로 판단하지 않는다"였다.

따라서 Android 미검증 상태에서 이 값을 그대로 승인하지 않는다.

실제 기기에서 최소:
- 밝은 배경
- 어두운 배경
- 화면 밝기 50%
- 화면 밝기 100%

에서 전조 경계가 뭉개지지 않는지 확인한다.

---

## 5. MAJOR-02 — 실제 FPS 데이터 부재

현재 성능 보고는:
- 노드 수
- 파티클 수
- "지연 없음"

정도다.

실측:
- 평균 FPS
- 1% low 또는 최저 FPS
- Boss 전투 최저 FPS

는 기록되지 않았다.

이번 패스에서 Android 실기까지 요구하지 않더라도, PC Godot 실행에서 최소 30~60초 동안 Stage 1 구간별 FPS를 기록한다.

향후 Android에서는 같은 지표를 다시 측정한다.

---

## 6. PR 구조 문제

PR #6은 `integration`에 아직 병합되지 않은 이전 문서 PR(#4, #5)의 내용까지 포함하고 있다.

따라서 현재 PR은:
- 그래픽 구현
- 이전 지시 문서
- 독립 리뷰 문서
- STATE 변경

이 한 번에 섞여 있다.

최종 병합 전에 가능하면 커밋 구조를 명확히 정리한다.

최소:
1. Agent/Review documents
2. Graphics implementation
3. Gameplay logic change (필요하면 별도)
4. State update

로 추적 가능해야 한다.

---

## 7. 독립 코드 리뷰 판정

| 항목 | 판정 |
|---|---|
| 반복 개선 절차 | PASS |
| 회귀 테스트 기록 | PASS |
| 캡처 산출물 | PASS |
| Android 검증 | NOT VERIFIED |
| 정적/동적 렌더 비용 분리 | **FAIL** |
| 그래픽/게임플레이 로직 분리 | **FAIL** |
| HDR 모바일 검증 | PENDING |
| 실제 FPS 기록 | PENDING |

### 최종

**CHANGES REQUIRED**

Stage 2 진행을 계속 보류한다.

---

## 8. 승인 조건

다음 네 가지가 끝나면 다시 독립 검수한다.

1. 정적 StageArt 매 프레임 재구축 문제 개선
2. Optional Enemy 강제 clear 로직을 그래픽 PR에서 제거/분리
3. HDR Telegraph 실기 또는 최소 다중 밝기 캡처 검증
4. PC 구간별 FPS 실측 기록

이후 회귀 테스트를 다시 실행하고 PR #6을 재검토한다.
