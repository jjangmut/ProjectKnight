# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-005
제목: 첫 적 전투 프로토타입
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): 클라이언트 리드(Client Lead)
작업자(Worker): 클라이언트(Client)
협의자(Consulted): 기획 리드(Planning Lead)
검토자(Reviewer): 스튜디오 매니저(Studio Manager)

## 목적

첫 근접형 적과 실제 전투를 구성하여 이동, 점프, 공격과 회피가 의미 있는 선택으로 작동하는지 검증한다.

## 작업 내용

- 순찰, 접근과 근접 공격을 수행하는 TestEnemy를 만든다.
- 공격 준비, 유효시간, 종료와 Cooldown을 시각적으로 구분한다.
- Enemy HP와 Player 피격 확인을 최소 구현한다.
- 점프 및 위치 Dodge로 Enemy 공격을 피할 수 있는지 검증한다.

## 작업 범위

- 단일 Enemy와 단순 수평 거리 기반 행동
- Enemy AttackArea와 HurtArea
- HP 3, Player 기본 공격 3회 사망
- Player HurtArea, 피격 횟수와 색상 Flash
- 기존 네 가지 Player Action 회귀 검증

## 제외 범위

- Navigation, Pathfinding과 AI Framework
- 복수 Enemy, 특수 패턴과 정식 몬스터 설정
- Loot, EXP, Drop, 사망 Animation
- HitStop, Knockback, Screen Shake
- Dodge 무적시간과 범용 Damage Framework

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`
- `DESIGN/PROTOTYPE_PROPOSAL_001.md`
- `WORK/DEC-002.md`
- `WORK/TASK-CL-002.md`
- `WORK/TASK-CL-003.md`
- `WORK/TASK-CL-004.md`

## 완료 조건(Acceptance Criteria)

- TestEnemy Scene과 단순 Patrol, 감지, 접근 구현
- 공격 준비, 유효 판정, 종료와 Cooldown 구현
- Enemy HurtArea, HP와 Player 공격 3회 사망 구현
- Enemy 공격으로 Player 피격 및 시각 피드백
- 점프와 Dodge 회피 검증
- 기존 네 가지 Player Action 회귀 없음
- Collision 관통 없음
- Godot 4.7.2 실제 실행 PASS
- Script Error와 Missing Resource 없음
- 전투 Self Check와 기획 리드 검토 기록

## 결과물(Deliverables)

- `CLIENT/Game/scenes/enemy/TestEnemy.tscn`
- `CLIENT/Game/scripts/enemy/test_enemy.gd`
- 갱신된 Player Scene과 Script
- 갱신된 `PrototypeMain.tscn`
- 실행 검증 및 검토 기록

## 의존성

- `TASK-CL-004` 완료
- Godot 4.7.2 stable Standard 실행 환경

## 작업 결과

- `CharacterBody2D` 기반 TestEnemy와 `PATROL`, `CHASE`, `ATTACK` Enum 상태를 구현했다.
- Enemy Move Speed `130 px/s`, Detection Range `420px`, Attack Range `90px`를 Inspector에서 조정할 수 있게 했다.
- 공격은 Windup `0.5초`, Active `0.15초`, Cooldown `1.0초` 순서이며 노랑 예고와 빨강 유효상태로 표시한다.
- 초기 Active `0.2초`와 높은 세로 판정에서는 점프 착지 구간이 피격되어, 권장 범위 안의 `0.15초`와 지면 중심 `16px` 높이로 조정했다.
- Enemy HurtArea와 HP `3`을 추가하고 Player 기본 공격 3회에 Enemy가 제거되도록 했다.
- Player에 HurtArea, HP `3`, 피격 횟수와 흰색 Flash를 추가했다. Player 사망 처리는 이번 범위에 포함하지 않았다.
- Dodge 무적시간은 추가하지 않고 AttackArea 밖으로 이동하는 위치 회피만 사용했다.
- 기존 정적 `Target.tscn`은 삭제하지 않고 Main Scene에서 TestEnemy로 교체했다.
- 자동 물리 검증에서 순찰, 거리 감지, 접근, 공격 예고·판정, Player 피격, Enemy HP 감소·사망을 확인했다.
- 조정 후 점프 회피와 위치 Dodge 회피가 모두 피격 없이 PASS했다.
- Godot 4.7.2 Compatibility GPU 렌더러에서 259프레임을 실제 렌더링해 공격 예고, Player 피격, 점프·Dodge 회피와 Enemy 제거를 확인했다.

### 전투 Self Check

- Enemy 접근 속도: 적절 — `130 px/s`로 Player 이동보다 느리고 대응 시간을 제공한다.
- 공격 예고시간: 적절 — 노랑 표시 `0.5초` 후 공격이 발생해 반응 구간이 구분된다.
- 공격 범위: 조정 필요 — 수평 `90px`는 명확하나 실제 아트와 적 패턴에 맞춘 재검토가 필요하다.
- Player 공격으로 대응: 적절 — 근접 범위에서 3회 공격으로 Enemy를 제거할 수 있다.
- 점프 회피: 유효 — 낮춘 지면 중심 판정을 점프로 넘을 수 있다.
- Dodge 회피: 유효 — 무적 없이 약 `132px` 위치 이동만으로 범위를 벗어날 수 있다.
- 공격 후 Dodge 제한: 추가 검토 — 규칙은 동작하지만 실전 체감은 Director 확인이 필요하다.
- 전체 전투 리듬: 추가 튜닝 필요 — 기본 선택지는 성립하지만 실제 플레이 재미와 수치는 아직 확정하지 않았다.

### 기획 리드 관점 검토

1. 노랑 `0.5초` 예고 후 빨강 유효상태가 나타나 공격을 보고 대응할 수 있다.
2. 이동은 거리 조절, 점프는 지면 판정 회피, Dodge는 빠른 수평 이탈로 역할이 구분된다.
3. 예고와 Cooldown으로 공격할 구간과 피할 구간이 구분된다.
4. 공격 중 Dodge 제한은 단순하지만 실제 전투에서 답답한지 추가 확인해야 한다.
5. 위치 Dodge만으로 회피가 가능해 현재 단계에서는 무적시간이 구조적으로 필요하지 않다.
6. `0.5초` 예고시간은 자동·시각 검증에서 충분했으며 Director 체감 확인이 남아 있다.
7. 현재 상태 구조는 별도 AI Framework 없이 두 번째 공격 패턴으로 확장할 가치가 있다.

## 알려진 문제

없음

## 검토(Review)

검토자: 스튜디오 매니저(Studio Manager)
결과: PASS
Director Review: PASS
의견:

- Move Speed `130`, Detection `420`, Attack Range `90`, Windup `0.5초`, Active `0.15초`, Cooldown `1.0초`, HP `3`을 프로토타입 기준으로 승인했다.
- Player와 Enemy의 상호 피격, 점프 회피와 무적시간 없는 위치 Dodge 회피를 승인했다.
- Player 사망 및 재시작은 구현하지 않으며 현재 수치는 최종 밸런스가 아니다.
