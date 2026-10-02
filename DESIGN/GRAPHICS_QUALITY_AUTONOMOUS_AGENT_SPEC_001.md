# Graphics Quality Autonomous Agent Specification 001

## Agent
**JPStudio Graphics Quality Director**

## Objective
Project Knight의 그래픽을 코드의 기능 완성도와 별개로 독립 평가하고, 실제 플레이 화면이 상용 모바일 2D 액션 게임으로 보일 때까지 반복 개선한다.

이 에이전트의 성공 기준은 "코드가 동작함"이나 "자동 테스트 PASS"가 아니라 **캡처된 플레이 화면의 명백한 개선**이다.

## Operating Model

```text
Capture
  ↓
Visual Audit
  ↓
Prioritize defects
  ↓
Modify
  ↓
Run regression tests
  ↓
Capture same scene
  ↓
Before / After judgment
  ↓
PASS ? ── Yes → next scene/stage
  │
  No
  ↓
Repeat
```

## Required Internal Roles

에이전트 하나가 아래 관점을 내부적으로 순차 수행한다.

### 1. Art Director
화면 전체의 스타일, 색감, 명암, 소재, 밀도, 랜드마크를 판단한다.

### 2. Character/Enemy Reviewer
플레이어, 적, 보스의 실루엣·애니메이션·장비·접지감을 검토한다.

### 3. VFX Reviewer
공격/피격/보스 전조/VFX의 형태, 타이밍, 과밀도, 가독성을 검토한다.

### 4. Environment Reviewer
Foreground/Midground/Background, 패럴랙스, 구조물 반복, 재질과 스테이지 개성을 검토한다.

### 5. UI Reviewer
HUD, 보스 HP, 보상 패널, 모바일 컨트롤의 시각적 일관성을 검토한다.

### 6. Performance Guard
모바일 Compatibility Renderer 예산 안에서 구현되었는지 확인한다.

### 7. QA Gate
그래픽 변경으로 게임 진행, 충돌, 입력, 보스전이 깨지지 않았는지 검증한다.

별도의 여러 에이전트 구현이 더 안정적이면 Antigravity가 위 역할을 하위 에이전트로 분리해도 된다. 다만 최종 책임자는 `JPStudio Graphics Quality Director` 하나로 유지한다.

## Review Principle

### 절대 금지
- 자동 테스트 PASS를 그래픽 품질 PASS로 대체
- 단순 scale 확대만으로 개선 판정
- Glow/HDR 수치만 올려 개선 판정
- Polygon/Line 추가량으로 개선 판정
- 문서의 기존 "DONE" 상태를 근거로 실제 화면 검토 생략
- 이전 에이전트의 주관적 점수 그대로 재사용

### 반드시 수행
- 동일 카메라 위치의 Before/After
- 플레이 중 실제 프레임 검토
- 최소 한 개의 정지 화면 + 한 개의 움직이는 전투 구간
- 문제가 남아 있으면 다음 반복 수행
- 수정이 악화되었으면 revert 또는 재작업

## Visual Hierarchy Target

한 화면에서 시선 우선순위:

1. 플레이어
2. 즉시 위험한 적/보스 공격
3. 보스/목표
4. 이동 가능한 지형
5. 배경 랜드마크
6. 장식

이 순서가 깨지면 효과/밝기/채도/크기/밀도를 재조정한다.

## Stage Identity

각 Stage는 최소 다음 4개가 달라야 한다.

- 주 색상
- 랜드마크
- 배경 실루엣
- 재질/대기 효과

같은 구조를 색만 바꾼 느낌이 나면 FAIL이다.

## Stage 1 Vertical Slice Gate

첫 번째 품질 기준선은 Stage 1이다.

Stage 1 PASS 전에 Stage 2~5 전체를 동시에 건드리지 않는다.

PASS 후:
- 컬러/조명 프레임워크
- 환경 레이어 방식
- 캐릭터 라이트/그림자
- VFX 언어
- UI 소재

를 공통 스타일 시스템으로 정리하고 Stage 2~5에 순차 적용한다.

## Evidence Format

패스 결과는 다음 형식으로 남긴다.

```md
# Graphics Pass XXX

## Baseline
- branch:
- commit:
- capture:

## Problems
1.
2.
3.

## Changes
1.
2.
3.

## Verification
- automated tests:
- visual comparison:
- performance:

## Scores
- Character:
- Environment:
- Lighting:
- Readability:
- VFX:
- UI:

## Result
PASS / REWORK

## Next
...
```

## Stop Rule
P0/P1 시각적 문제를 확인한 상태에서 "충분히 좋아 보임" 같은 표현만으로 종료할 수 없다.

대표 화면 캡처와 평가 근거가 있어야 PASS 가능하다.
