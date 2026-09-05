# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-003
제목: 플레이어 기본 공격 프로토타입
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): 클라이언트 리드(Client Lead)
작업자(Worker): 클라이언트(Client)
협의자(Consulted): 기획 리드(Planning Lead)
검토자(Reviewer): 스튜디오 매니저(Studio Manager)

## 목적

이동과 점프 중 기본 공격을 입력했을 때 공격 타이밍과 범위를 명확히 이해할 수 있는지 검증한다.

## 작업 내용

- Player에 단일 근접 공격 상태와 `AttackArea` 판정을 추가한다.
- 바라보는 방향에 따라 좌우 공격 방향을 전환한다.
- 공격 유효시간과 범위를 임시 시각 표현으로 표시한다.
- 최소 테스트 Target으로 실제 타격 감지를 확인한다.
- 기존 이동과 점프를 포함한 실행 회귀 검증을 수행한다.

## 작업 범위

- `attack` 입력의 기본 근접 공격 1종
- 공격 지속시간, 재사용 대기시간, 범위 조정
- 지상 이동 및 공중에서 동일한 공격 사용
- `Area2D` 기반 타격 판정과 Target 피격 표시

## 제외 범위

- 콤보, 연속 공격 체인, 차지 공격
- 공중 전용 공격, 스킬, 투사체, 무기 교체
- 공격 취소와 복잡한 Animation State Machine
- 적 AI, HP, 사망, 보상, HitStop, Knockback, Screen Shake

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`
- `DESIGN/PROTOTYPE_PROPOSAL_001.md`
- `WORK/DEC-001.md`
- `WORK/DEC-002.md`
- `WORK/DEC-003.md`
- `WORK/TASK-CL-002.md`

## 완료 조건(Acceptance Criteria)

- 기본 공격 1종과 `AttackArea` 기반 판정 구현
- 좌우 방향 대응 및 임시 공격 시각화
- 최소 테스트 Target과 실제 Hit 감지
- 이동 중 및 공중 공격 가능
- 공격 유효시간 외 판정 비활성화
- 공격 연타가 무한 판정으로 이어지지 않음
- 기존 이동과 점프 회귀 없음
- Godot 4.7.2 실제 실행 PASS
- Script Error와 Missing Resource 없음
- 조작감 Self Check와 기획 리드 관점 검토 기록

## 결과물(Deliverables)

- 갱신된 Player Scene과 Script
- 테스트 Target Scene과 Script
- 갱신된 `PrototypeMain.tscn`
- 실행 검증 및 검토 기록

## 의존성

- `TASK-CL-002` 완료
- Godot 4.7.2 stable Standard 실행 환경

## 작업 결과

- Player에 `Area2D` 기반 `AttackArea`와 공격 중에만 보이는 반투명 근접 범위 표시를 추가했다.
- 공격 가능, 공격 중, 공격 종료를 Bool과 남은 시간 값으로 구성하고 별도 State Machine은 만들지 않았다.
- Attack Duration `0.16초`, Attack Cooldown `0.32초`, Attack Range `72px`를 Inspector에서 조정할 수 있게 했다.
- 공격 중 이동 속도를 잠그거나 제한하지 않아 기존 이동과 점프 입력을 그대로 유지했다.
- 바라보는 방향에 따라 Player 전체를 반전하지 않고 `AttackArea` 위치만 좌우로 전환했다.
- Target에 `HurtArea`, 흰색 순간 플래시, `HIT` 표시와 Output 메시지를 추가했다.
- 한 번의 공격에서 동일 Target은 한 번만 처리하고 cooldown 중 재입력은 새 공격을 시작하지 않게 했다.
- Godot 물리 프레임 검증에서 좌우 타격, 유효시간 외 판정 비활성화, 단일 Hit, cooldown 차단, 지상 이동 중 공격과 공중 공격을 확인했다.
- 기존 지상 이동, 점프와 착지가 유지되는지 회귀 검증했다.
- Godot 4.7.2 Compatibility GPU 렌더러에서 169프레임을 실제 렌더링해 지상 공격 범위, Target 피격 표시, 공중 왼쪽 공격을 확인했다.

### 조작감 Self Check

- 공격 입력 반응: 적절 — 입력 다음 물리 처리에서 공격 범위가 활성화되고 시각 표시가 나타난다.
- 공격 범위 가독성: 적절 — 반투명 주황 영역으로 현재 방향과 유효 범위를 구분할 수 있다.
- 공격 지속시간: 조정 필요 — `0.16초`의 판정은 명확하지만 실제 공격 모션과 함께 최종 확인해야 한다.
- 연속 입력 간격: 조정 필요 — `0.32초` cooldown은 무한 연타를 막지만 전투 리듬 검증이 필요하다.
- 이동 + 공격: 적절 — 공격 중 이동을 잠그지 않아 입력 충돌 없이 함께 동작한다.
- 점프 + 공격: 적절 — 지상과 동일한 판정이 공중에서도 좌우 방향에 맞게 활성화된다.

### 기획 리드 관점 검토

1. 공격 유효시간 동안만 범위가 표시되어 공격 타이밍을 이해할 수 있다.
2. 공격 범위는 명확하지만 이동 제한이 없어 위험 부담은 낮다. 적 패턴 추가 후 재평가가 필요하다.
3. 이동과 점프 중 공격 입력이 서로 차단되지 않아 결합이 자연스럽다.
4. `AttackArea`와 `HurtArea`의 분리는 이후 적 패턴 및 피격 판정과 결합할 수 있다.
5. 현재 입력 반응과 시각 피드백을 기반으로 모션, 소리와 타격감을 발전시킬 여지가 있다.

## 알려진 문제

없음

## 검토(Review)

검토자: 스튜디오 매니저(Studio Manager)
결과: PASS
Director Review: PASS
의견:

- Attack Duration `0.16초`, Attack Cooldown `0.32초`, Attack Range `72px`를 프로토타입 기준값으로 승인했다.
- 공격 중 이동과 공중 공격을 허용하는 현재 규칙을 승인했다.
- 현재 값은 적 패턴 및 실제 전투 테스트 전까지의 프로토타입 기준이며 최종 밸런스 값은 아니다.
