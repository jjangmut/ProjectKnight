# 작업(Task)

작업 ID: TASK-CL-012
제목: 전투 심화 메커니즘 엔진 탑재 (카운터 어드밴티지, 3단 콤보, 공중 하향 찍기)
상태: DONE (구현 및 자동 검증 PASS)
분야: CL (클라이언트)
담당: Client Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/COMBAT_SYSTEM_DEEPENING_001.md, CLIENT/Game/data/player_combat.json

## 1. 지시

기획서 `DESIGN/COMBAT_SYSTEM_DEEPENING_001.md`에 명시된 3대 전투 심화 기믹(카운터 어드밴티지, 3단 콤보 시스템, 공중 하향 찍기/포고 점프)을 `player.gd`에 탑재하고 검증한다.

## 2. 완료 조건

1. 가드 성공 직후 0.18초 내 공격 입력 시 카운터 슬래시(사거리 85px, 피해 2, 적 0.4s 스턴) 발동.
2. 공격 홀드/연타 시 1타(찌르기, 피해 1) → 2타(올려베기, 피해 1) → 3타(내려치기 스매시, 피해 2, 넉백 200px) 3단 콤보 순환 전개.
3. 공중에서 `아래+공격` 시 급강하 하향 찍기 및 적 타격 시 280px 반동 도약(포고 점프) 발동.
4. 전용 자동 QA 스모크 테스트(`combat_deepening_smoke.gd`) 작성 및 100% 통과.

## 3. 결과물

- `CLIENT/Game/scripts/player/player.gd` (탑재 완료)
- `CLIENT/Game/tests/combat_deepening_smoke.gd` (10 checks PASS)
