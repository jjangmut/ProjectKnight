# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-004
제목: 플레이어 회피 프로토타입
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): 클라이언트 리드(Client Lead)
작업자(Worker): 클라이언트(Client)
협의자(Consulted): 기획 리드(Planning Lead)
검토자(Reviewer): 스튜디오 매니저(Studio Manager)

## 목적

이동, 점프, 공격에 독립 회피 입력을 추가하여 첫 기본 액션 세트의 통합 조작 리듬을 검증한다.

## 작업 내용

- 입력 방향 또는 현재 바라보는 방향으로 짧게 이동하는 지상 Dodge를 구현한다.
- 회피 속도, 지속시간과 Cooldown을 Inspector에서 조정할 수 있게 한다.
- 회피 중 최소 시각 피드백을 제공한다.
- 공격과 회피, 점프와 회피의 상태 충돌을 방지한다.
- 네 가지 기본 액션을 통합 실행하고 기존 기능의 회귀를 검증한다.

## 작업 범위

- 독립 `dodge` 입력과 좌우 방향 처리
- 지상에서만 가능한 수평 회피
- 회피 지속시간과 Cooldown
- 기존 Body Collision과 중력 유지
- 공격 상태와 상호 차단

## 제외 범위

- 공중 회피와 입력 Buffer
- 무적 판정과 Collision Mask 전환
- 벽 또는 적 통과, Ghost Mode, Teleport
- Tween, 잔상, Trail과 복잡한 VFX
- 별도 Dodge Manager 또는 Ability System

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`
- `DESIGN/PROTOTYPE_PROPOSAL_001.md`
- `WORK/DEC-002.md`
- `WORK/TASK-CL-002.md`
- `WORK/TASK-CL-003.md`

## 완료 조건(Acceptance Criteria)

- 독립 Dodge 입력과 좌우 방향 처리
- 무입력 시 현재 Facing 방향 사용
- Dodge Speed, Duration, Cooldown 적용 및 Inspector 조정 가능
- 회피 중 시각 피드백
- 기본 Body Collision과 중력 유지
- Dodge 중 Attack, Attack 중 Dodge 차단
- 공중 Dodge 차단
- 기존 이동, 점프, 공격 회귀 없음
- Godot 4.7.2 실제 GPU 실행 PASS
- Script Error와 Missing Resource 없음
- 통합 입력, Self Check와 기획 리드 관점 검토 기록

## 결과물(Deliverables)

- 갱신된 Player Script
- 회피 충돌 검증용으로 갱신된 Prototype Main Scene
- 실행 검증 및 검토 기록

## 의존성

- `TASK-CL-003` 완료
- Godot 4.7.2 stable Standard 실행 환경

## 작업 결과

- 기존 `CharacterBody2D` Player Script에 `is_dodging`, 방향, 지속시간과 Cooldown만 추가해 수평 Dodge를 구현했다.
- 이동 입력이 있으면 입력 방향, 없으면 현재 Facing 방향을 사용한다.
- Dodge Speed `720 px/s`, Dodge Duration `0.18초`, Dodge Cooldown `0.45초`를 Inspector에서 조정할 수 있게 했다.
- 지상에서만 회피를 시작하며 회피 중에도 기존 중력과 Body Collision을 유지한다.
- 회피 중 Player를 반투명 청록색으로 표시하고 종료 시 원래 색으로 복구한다.
- 회피 중 Attack, Attack 중 Dodge, 공중 Dodge와 해당 입력 Buffer를 허용하지 않았다.
- 회피 중 Jump도 시작하지 않아 지상 회피 규칙을 유지한다.
- 테스트 Stage에 단순 Wall을 추가해 회피 중 Body Collision 비관통을 확인했다.
- Godot 물리 프레임 검증에서 자유 공간 오른쪽 Dodge 이동거리 `132.0px`, 왼쪽 입력 Dodge 동작, Cooldown 재입력 차단과 상태 충돌 규칙을 확인했다.
- 이동, 점프, 공격, 회피와 반대 방향 입력을 포함한 통합 흐름을 검증했다.
- Godot 4.7.2 Compatibility GPU 렌더러에서 217프레임을 실제 렌더링해 점프, 공격 Hit, 좌우 Dodge 시각 피드백과 회피 후 공격을 확인했다.

### 조작감 Self Check

- 회피 입력 반응: 적절 — 유효한 지상 입력 다음 물리 처리에서 즉시 고속 이동과 색상 변화가 시작된다.
- 회피 이동거리: 조정 필요 — 자유 공간 약 `132px`로 동작하며 적 공격 범위와 함께 최종 판단해야 한다.
- 회피 속도감: 적절 — `720 px/s`로 일반 이동 `320 px/s`와 명확하게 구분된다.
- 회피 Cooldown: 조정 필요 — `0.45초` 재입력 차단은 정상이나 반복 조작 리듬 확인이 필요하다.
- 이동 → 회피 연결: 적절 — 입력 방향이 우선 적용되고 회피 종료 후 일반 이동으로 복귀한다.
- 공격 → 회피 제한: 조정 필요 — 규칙은 명확하지만 공격 종료까지 회피가 차단되는 체감은 실제 전투에서 확인해야 한다.
- 점프와 회피 규칙: 적절 — 공중 입력이 무시되어 지상 전용 규칙을 이해하기 쉽다.

### 기획 리드 관점 검토

1. 일반 이동보다 2.25배 빠른 속도와 색상 변화로 Dodge가 별도 액션으로 구분된다.
2. 약 `132px`의 이동거리는 현재 Stage에서 과도하지 않지만 적 공격 범위 추가 후 재평가해야 한다.
3. 수평 위치 변경 역할이 점프의 수직 회피 및 공격의 타격 역할과 구분된다.
4. 공격 중 회피 차단은 단순하지만 실제 전투에서 답답함이 있는지 Director 확인이 필요하다.
5. 지상에서만 가능하고 무입력 시 Facing을 사용하는 규칙은 이해하기 쉽다.
6. Body Collision을 유지한 명시적 Dodge 상태는 향후 적 공격 회피와 무적시간 검토의 기반이 된다.

## 알려진 문제

없음

## 검토(Review)

검토자: 스튜디오 매니저(Studio Manager)
결과: PASS
Director Review: PASS
의견:

- Dodge Speed `720 px/s`, Duration `0.18초`, Cooldown `0.45초`, 이동거리 약 `132px`를 프로토타입 기준으로 승인했다.
- 지상 회피만 허용하고 Dodge 중 Attack, Attack 중 Dodge, 공중 Dodge, Dodge 중 Jump를 차단하는 규칙을 승인했다.
- 현재 값과 규칙은 첫 실제 적 공격 패턴과 결합한 뒤 다시 검토한다.
