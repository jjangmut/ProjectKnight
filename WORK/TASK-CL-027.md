# [TASK-CL-027] 5지역 최종 보스 '심연의 심판관' 3페이즈 AI 및 결전 시스템 구현

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/MILESTONE5_FINAL_BOSSES_SPEC_001.md`, `TASK-PL-008.md`

## 1. 개요
5지역(침묵의 성채, FifthStage) 대단원 최종 보스 '심연의 심판관'(`abyssal_arbiter.gd`, 24 HP) 및 회전 심연 검환 투사체(`abyssal_blade.gd`)를 구현하고, 3페이즈 점진적 패턴 심화 및 캠페인 대단원 클리어 연동을 구축함.

## 2. 완료 내역
- `abyssal_blade.gd`: 4방향 회전 탄막 및 추적 칼날 투사체, 플레이어 피격 시 2 데미지 판정.
- `abyssal_arbiter.gd`:
  - 24 HP, 3페이즈 구조 설계:
    - Phase 1 (24~17 HP): 심연 대검 2단 참격 및 플레이어 배후 그림자 순간이동(`teleport`).
    - Phase 2 (16~9 HP): 심연 균열 개방, 4방향 회전 검환 탄막 방출 및 고속 추적.
    - Phase 3 (8~0 HP): 검은 날개 완전 개방(`black_wings_unfurled = true`), '종말의 심판(Final Judgment)' 광역 칼날 폭풍 및 극대화 공격.
  - 격파 시 영혼 샤드 25개 드랍 및 `boss_defeated` 시그널 방출.
- `first_stage.gd`: 5지역(침묵의 성채) E8 인카운터 진입 시 `AbyssalArbiterClass` 스폰 및 보스 체력바(`"심연의 심판관"`) HUD 연동.
