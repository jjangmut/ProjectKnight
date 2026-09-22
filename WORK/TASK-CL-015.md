# 작업(Task)

작업 ID: TASK-CL-015
제목: 몬스터 공격 전조 시각화 및 피격 경직(Hit Stun / Counter Stun) 시스템 구현
상태: DONE (test_enemy.gd, ranged_enemy.gd 탑재 완료)
분야: CL (클라이언트)
담당: Client Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: CLIENT/Game/data/monsters.json, DESIGN/COMBAT_SYSTEM_DEEPENING_001.md

## 1. 지시

상용 액션 게임 수준의 깊이 있는 공방 연출과 타격감을 위해, 모든 몬스터 베이스(`test_enemy.gd`, `ranged_enemy.gd`)에 피격 경직(Hit Stun / Counter Stun) 및 공격 전조(Telegraph) 시각 피드백 시스템을 탑재한다.

## 2. 완료 조건

1. `test_enemy.gd`에 `hit_stun_duration`, `is_stunned`, `_hit_stun_remaining`, `is_counter_stunned` 변수 및 감속/정지 로직 구현.
2. 플레이어의 카운터 어택 피격 메타(`counter_stunned`, 0.40s) 판정 시 일반 피격보다 긴 0.40s 이상 특수 스턴 및 청백색 스턴 플래시 적용.
3. 피격 경직 중에는 몬스터의 이동, 추적 및 공격 로직이 정지되며 공격 도중 피격 시 즉시 캔슬.
4. 공격 윈드업 시 가드 가능 공격(황금색 발광 `Color(1.0, 0.82, 0.2, 1.0)`)과 가드 불가 공격(붉은색 발광 `Color(1.0, 0.28, 0.15, 1.0)`)에 따른 시각 전조 구분 표시.
5. 원거리 몬스터(`ranged_enemy.gd`)에도 피격 경직(0.25s), 카운터 스턴 및 발사 캔슬 로직 탑재.

## 3. 결과물

- `CLIENT/Game/scripts/enemy/test_enemy.gd`
- `CLIENT/Game/scripts/enemy/ranged_enemy.gd`
- `WORK/TASK-CL-015.md`
