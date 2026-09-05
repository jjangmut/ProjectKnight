# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-002
제목: 플레이어 이동 및 점프 프로토타입
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): 클라이언트 리드(Client Lead)
작업자(Worker): 클라이언트(Client)
협의자(Consulted): 기획 리드(Planning Lead)
검토자(Reviewer): 스튜디오 매니저(Studio Manager)

## 목적

첫 플레이어블의 핵심인 좌우 이동과 단일 점프의 조작감을 Godot 실행 환경에서 검증한다.

## 작업 내용

- `CharacterBody2D` 기반 플레이어 Scene과 Script를 만든다.
- 지상 및 공중 좌우 이동, 지상 단일 점프, 중력을 구현한다.
- `PrototypeMain.tscn`에 플레이어와 충돌 가능한 테스트 지면을 배치한다.
- Godot 4.7.2에서 실행, 충돌, 입력 및 조작 결과를 검증한다.

## 작업 범위

- 좌우 이동과 방향 전환
- 지상 단일 점프와 중력
- 제한된 공중 좌우 조작
- Inspector에서 핵심 수치 조정
- 최소 테스트 스테이지

## 제외 범위

- 코요테 타임, 점프 입력 버퍼, 가변 점프 높이
- 이단 점프, 벽 점프, 대시 점프, 낙하 공격
- 공격, 회피, 피격, 적, 체크포인트
- 애니메이션 상태 머신과 복잡한 캐릭터 컨트롤러

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`
- `DESIGN/PROTOTYPE_PROPOSAL_001.md`
- `WORK/DEC-001.md`
- `WORK/DEC-002.md`
- `WORK/DEC-003.md`
- `WORK/TASK-CL-001.md`

## 완료 조건(Acceptance Criteria)

- Player Scene 생성 및 `CharacterBody2D` 기반 구성
- 좌우 이동, 방향 전환, 단일 점프, 중력 구현
- 지면 충돌과 공중 좌우 조작 확인
- Move Speed, Jump Velocity, Gravity를 Inspector에서 조정 가능
- Main Scene에서 실제 실행 가능
- 공중 재점프 및 충돌 관통 없음
- Script Error와 Missing Resource 없음
- 조작감 Self Check와 기획 관점 검토 기록

## 결과물(Deliverables)

- `CLIENT/Game/scenes/player/Player.tscn`
- `CLIENT/Game/scripts/player/player.gd`
- 갱신된 `CLIENT/Game/scenes/prototype/PrototypeMain.tscn`
- 실행 검증 및 검토 기록

## 의존성

- Godot 4.7.2 stable Standard 실행 환경

## 작업 결과

- `CharacterBody2D` 기반 Player Scene과 직사각형 충돌체, 임시 `Polygon2D` 시각 표현을 만들었다.
- 지상 즉시 반응형 좌우 이동과 방향 표시 전환을 구현했다.
- 지상에서만 가능한 단일 점프와 프레임 기반 중력을 구현했다.
- 공중에서는 기존 속도를 유지하면서 입력 방향으로 점진적으로 전환되도록 공중 제어를 제한했다.
- Move Speed `320 px/s`, Jump Velocity `-520 px/s`, Gravity `1400 px/s²`, Air Control `0.65`를 Inspector에서 조정할 수 있게 했다.
- `PrototypeMain.tscn`에 1920px 너비의 충돌 지면과 단순 Camera2D를 배치했다.
- Godot 4.7.2 Compatibility 렌더러에서 143프레임의 이동·점프·방향 전환·착지 장면을 실제 렌더링했다.
- Godot 물리 프레임 검증에서 오른쪽 이동 `160.0px/0.5초`, 방향 전환 속도 `-320.0px/s`, 점프 높이 약 `101.0px`, 체공 약 `0.73초`, 공중 이동 약 `211.8px`, 착지 높이 `591.9px`를 확인했다.
- 공중 재점프 차단, 지면 복귀, 충돌 비관통, Script 및 Resource 로드를 확인했다.

### 조작감 Self Check

- 이동 반응성: 적절 — 지상 입력 즉시 `320 px/s`가 적용되고 0.5초 동안 160px 이동했다.
- 점프 시작 반응: 적절 — 지상 점프 입력 다음 물리 처리에서 `-520 px/s`가 적용됐다.
- 체공 시간: 조정 필요 — 약 0.73초의 단순 포물선은 확인했으나 전투 패턴과 함께 실제 체감 조정이 필요하다.
- 낙하 속도: 조정 필요 — `1400 px/s²`의 일정 중력은 정상 동작하나 최종 무게감은 직접 플레이 확인이 필요하다.
- 공중 제어: 조정 필요 — `0.65` 비율의 완화된 방향 전환은 동작하나 회피 패턴과 함께 강도를 판단해야 한다.
- 방향 전환: 적절 — 지상 반대 입력에서 즉시 `-320 px/s`로 전환됐고 방향 표시도 입력을 따른다.

### 기획 리드 관점 검토

1. 지상 즉시 반응과 제한된 공중 제어는 이후 전투 회피 기반 액션으로 발전 가능한 단순한 기반이다.
2. 약 101px 높이와 0.73초 체공의 단일 점프 궤적은 적 패턴 회피 용도를 시험하기에 명확하다.
3. 이동 반응이 지나치게 둔하지는 않다. 점프 무게감은 Director의 실제 플레이 후 세 수치를 조정해야 한다.
4. Player Script가 이동과 점프에만 한정되어 이후 공격과 회피를 추가할 구조적 공간이 있다.

## 알려진 문제

없음

## 검토(Review)

검토자: 스튜디오 매니저(Studio Manager)
결과: PASS
Director Play Review: PASS
의견:

- Godot Project Manager 직접 실행, Editor 프로젝트 열기, F5/F6 실행을 확인했다.
- Move Speed `320`, Jump Velocity `-520`, Gravity `1400`, Air Control `0.65`를 프로토타입 기준값으로 승인했다.
- 현재 수치는 프로토타입 검증 기준이며 최종 밸런스 값은 아니다.
