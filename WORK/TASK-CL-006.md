# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-006
제목: 원거리형 적 전투 프로토타입
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): 클라이언트 리드(Client Lead)
작업자(Worker): 클라이언트(Client)
협의자(Consulted): 기획 리드(Planning Lead)
검토자(Reviewer): 스튜디오 매니저(Studio Manager)

## 목적

근접형과 원거리형 적이 함께 존재할 때 이동, 점프, 공격과 회피가 서로 다른 전투 선택으로 기능하는지 검증한다.

## 작업 내용

- 거리를 유지하며 수평 투사체를 발사하는 RangedEnemy를 만든다.
- 공격 준비 표시, Projectile 생성·이동·충돌·정리를 구현한다.
- Player 공격 3회로 RangedEnemy가 제거되도록 한다.
- 점프, 이동과 위치 Dodge의 Projectile 회피를 검증한다.
- 근접형과 원거리형 Enemy의 동시 전투를 확인한다.

## 작업 범위

- 작은 범위 Patrol과 거리 기반 감지
- 수평 직선 Projectile과 방향 결정
- Player HurtArea 피격 및 환경 충돌·거리 Cleanup
- RangedEnemy HP 3과 사망
- 기존 근접 Enemy 및 Player 액션 회귀 검증

## 제외 범위

- 예측 사격, 유도, 중력, 폭발, 반사와 Object Pool
- 복잡한 회피·후퇴 AI 및 AI Framework
- Enemy별 방어력과 범용 Damage 시스템
- Player 사망·재시작과 Dodge 무적시간

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`
- `DESIGN/PROTOTYPE_PROPOSAL_001.md`
- `WORK/TASK-CL-005.md`

## 완료 조건(Acceptance Criteria)

- RangedEnemy와 단순 행동, 감지 및 Telegraph 구현
- 수평 Projectile 생성, 방향, 이동, 충돌과 Cleanup 구현
- Player 피격과 Projectile 제거 확인
- RangedEnemy HP 감소 및 3회 공격 사망
- 점프, 이동과 Dodge 회피 검증
- 근접형 Enemy 및 Player 네 액션 회귀 없음
- 근접형과 원거리형 동시 전투 확인
- Godot 4.7.2 실제 실행 PASS
- Script Error와 Missing Resource 없음
- 전투 Self Check와 기획 리드 검토 기록

## 결과물(Deliverables)

- RangedEnemy Scene과 Script
- EnemyProjectile Scene과 Script
- 갱신된 Prototype Main Scene
- 실행 검증 및 검토 기록

## 의존성

- `TASK-CL-005` 완료
- Godot 4.7.2 stable Standard 실행 환경

## 작업 결과

- `CharacterBody2D` 기반 RangedEnemy에 작은 범위 Patrol과 거리 기반 원거리 공격 상태를 구현했다.
- Detection Range `700px`, Attack Windup `0.6초`, Attack Cooldown `1.4초`, HP `3`을 Inspector에서 조정 가능하게 했다.
- Windup 동안 연보라색으로 Telegraph하고 발사 순간 Player의 현재 좌우 위치만 기준으로 방향을 결정한다.
- `Area2D` 기반 EnemyProjectile을 만들고 Speed `400 px/s`, 최대 이동거리 `640px`의 수평 직선 이동을 구현했다.
- Projectile이 Player HurtArea에 닿으면 기존 피격 Flash를 호출하고 제거되며, 환경 Body 충돌 또는 최대 거리에서 제거된다.
- 최초 구현에서 Projectile이 발사자 Body와 겹쳐 즉시 제거되어 발사 방향의 Body 바깥 `40px` 지점에서 생성하도록 수정했다.
- 수평 탄도에서 위치 Dodge가 의미 있도록 최대 이동거리를 `640px`로 조정했다. 무적시간은 추가하지 않았다.
- RangedEnemy HurtArea와 HP `3`을 구현해 Player 기본 공격 3회에 제거되도록 했다.
- 기존 근접 Enemy를 구간 A, RangedEnemy를 구간 B에 배치하고 오른쪽 경계 Wall을 옮겨 접근 공간을 확보했다.
- 자동 물리 검증에서 좌우 발사, Player Hit 후 제거, 환경·거리 Cleanup, Jump·이동·Dodge 회피와 RangedEnemy 사망을 확인했다.
- 근접 Enemy와 RangedEnemy가 동시에 감지·접근·발사하는 상태를 확인했다.
- Godot 4.7.2 Compatibility GPU 렌더러에서 365프레임을 실제 렌더링해 Telegraph, Projectile, 회피, 복합 전투와 Enemy 제거를 확인했다.

### 전투 Self Check

- Projectile 속도: 적절 — `400 px/s`로 Player 이동 `320 px/s`보다 빠르지만 Telegraph 후 대응 가능하다.
- Projectile 가독성: 적절 — 밝은 보라색 수평 Placeholder로 방향과 위치를 구분할 수 있다.
- 공격 준비시간: 적절 — `0.6초` 색상 예고 후 발사되어 반응 구간이 명확하다.
- Jump 회피: 유효 — 지면 높이의 직선 Projectile을 위로 넘을 수 있다.
- Dodge 회피: 유효 — Windup 중 발사 반대 방향으로 거리를 벌리면 최대 이동거리 밖으로 벗어날 수 있다.
- 이동 회피: 유효 — 먼 거리에서 계속 거리를 벌이면 Projectile이 지정 거리에서 정리된다.
- 근접 + 원거리 조합: 추가 튜닝 필요 — 서로 다른 압박은 형성되지만 수치와 배치의 실제 재미 확인이 필요하다.
- Player 행동 선택: 이동은 거리 조절, 점프는 수직 회피, 공격은 Enemy 제거, Dodge는 빠른 재배치로 각각 사용된다.

### 기획 리드 관점 검토

1. 근접형은 접근 후 지면 공격, 원거리형은 제자리 Telegraph 후 투사체 발사로 역할이 구분된다.
2. `0.6초` Telegraph와 `400 px/s` 속도는 보고 반응할 시간을 제공한다.
3. 낮은 수평 탄도 때문에 점프가 명확한 원거리 대응 수단이다.
4. Dodge는 Windup 동안 빠르게 사거리 밖으로 재배치하는 선택으로 의미가 있다.
5. 일반 이동 회피는 먼 거리에서 가능하지만 가까운 거리에서는 Projectile이 더 빨라 다른 선택이 필요하다.
6. 두 Enemy 조합은 근접 대응과 Projectile 회피를 동시에 요구해 선택지를 늘린다.
7. 공격 중 Dodge 제한은 복합 전투에서 실제 체감 확인이 필요하다.
8. 복합 압박과 Player HP 소모가 작동하므로 다음 단계에서 사망·재시작 구조를 검토할 가치가 있다.

## 알려진 문제

없음

## 검토(Review)

검토자: 스튜디오 매니저(Studio Manager)
결과: PASS
의견: 근접 + 원거리 조합의 최종 배치와 전투 밸런스는 이후 스테이지(Stage) 구성 단계에서 재검토한다.

Director Review: PASS
