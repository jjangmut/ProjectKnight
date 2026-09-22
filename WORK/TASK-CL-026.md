# [TASK-CL-026] 4지역 관문 보스 '고대 골렘 수호자' 및 천장 낙석 시스템 구현

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/MILESTONE5_FINAL_BOSSES_SPEC_001.md`, `TASK-PL-008.md`

## 1. 개요
4지역(돌의 성소, FourthStage) 관문 보스 '고대 골렘 수호자'(`ancient_golem_guardian.gd`, 18 HP) 및 천장 낙석 투사체(`falling_boulder.gd`)를 구현하고, 4지역 E8 보스 인카운터 아레나 봉쇄 및 보스 체력바 UI를 연동함.

## 2. 완료 내역
- `falling_boulder.gd`: 천장 낙석 투사체 생성, 지면 충돌 시 화면 진동 및 파편 분산, 플레이어 피격 시 2 데미지 판정.
- `ancient_golem_guardian.gd`:
  - 18 HP, 1페이즈 지진 슬램(양방향 지면 충격파 2개 방출) 및 천장 낙석비(3개 낙석 투하).
  - 2페이즈 체력 50%(9 HP) 이하 진입 시 마그마 코어 과부하(`core_overload = true`) 및 롤링 돌진 공격(`rolling_charge_speed = 360.0`).
  - 격파 시 영혼 샤드 18개 드랍 및 `boss_defeated` 시그널 방출.
- `first_stage.gd`: 4지역(돌의 성소) E8 인카운터 진입 시 `AncientGolemGuardianClass` 스폰 및 보스 체력바(`"고대 골렘 수호자"`) HUD 연동.
