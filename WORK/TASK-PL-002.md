# 작업(Task)

작업 ID: TASK-PL-002
제목: 전투 메커니즘 심화 기획 (카운터 어드밴티지, 공중 공격, 3단 콤보)
상태: DONE (기획서 작성 완료)
분야: PL (기획)
담당: Planning Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/COMBAT_SYSTEM_DEEPENING_001.md

## 1. 지시

단순 평타-가드 반복의 단조로움을 극복하기 위해, 기존 3개 버튼(공격, 점프, 방어)의 조작 편의성을 유지하면서 심리전과 타격 리듬을 극대화하는 전투 심화 상세 기획서를 완성한다.

## 2. 완료 조건

1. 정면 가드 성공 직후 0.18초 이내 반격하는 '카운터 어드밴티지' 판정, 대미지(2), 적 기절(0.4s) 명세 확정.
2. 공격 홀드/연타 시 1타(찌르기) → 2타(베기) → 3타(넉백 스매시)로 연계되는 3단 콤보 프레임/사거리/넉백 데이터 명세 확정.
3. 점프 중 하향 공격(Down Thrust) 판정 및 적 피격 시 반동 점프(280px Pogo Jump) 메커니즘 명세 확정.
4. `CLIENT/Game/data/player_combat.json` 데이터 시트와의 100% 일치 확인.

## 3. 결과물

- `DESIGN/COMBAT_SYSTEM_DEEPENING_001.md`
- `CLIENT/Game/data/player_combat.json`
