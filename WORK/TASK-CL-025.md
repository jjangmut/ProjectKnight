# [TASK-CL-025] 3지역 보스 인카운터 및 화톳불 상점 어빌리티 해금 연동

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/STAGE3_BOSS_AND_AIR_DASH_SPEC_001.md`

## 1. 개요
3지역(무너진 성벽, ThirdStage) 최종 인카운터(E8)에 '폐허의 석궁 사령관' 보스룸 아레나 봉쇄 및 보스 체력바 UI, 보스 결전 BGM 연동을 완료하고, 화톳불 상점(Campfire Shop)에 '그림자 걸음(Shadow Dash)' 구매 및 영구 세이브 연동을 구축함.

## 2. 완료 내역
- `first_stage.gd`: `stage_number == 3` 최종 인카운터 보스 스폰 분기 추가, `BossHealthBarClass`("폐허의 석궁 사령관", 16 HP) 연동.
- `save_manager.gd`: `upgrades.shadow_dash` 영구 저장 및 플레이어 적용 연동.
- `campfire_shop.gd`: '그림자 걸음 (Shadow Dash)'(50 Shards) 구매 버튼 및 즉시 플레이어 대시 해금 연동.
