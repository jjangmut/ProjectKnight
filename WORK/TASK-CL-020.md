# [TASK-CL-020] 화톳불 상점(Campfire Shop) 및 메타 성장 시스템 구현

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/CAMPFIRE_SHOP_AND_STAGE2_BOSS_SPEC_001.md`

## 1. 개요
영혼 파편을 소모하여 최대 체력 증가(`hp_boost`), 기본 공격력 증가(`dmg_boost`), 즉시 완전 회복(`heal_full`)을 구매할 수 있는 UI 모듈 `campfire_shop.gd`를 제작하고, `SaveManager` 영구 저장 및 플레이어 스탯 반영을 연동함.

## 2. 완료 내역
- `save_manager.gd`: 메타 성장 업그레이드 데이터(`upgrades.hp_boost`, `upgrades.dmg_boost`) 영구 디스크 저장/로드, `purchase_upgrade()`, `apply_upgrades_to_player()` 구현.
- `campfire_shop.gd`: 화톳불 상점 UI 모듈 구축, 영혼 파편 잔고 동기화, 구매 시 SFX 및 게임필 셰이크 연동, 닫기 시그널 연동.
- `campaign.gd`: 경로 선택 화면(`_show_route_panel`) 내 화톳불의 영혼 제단 상점 진입 버튼 연동.
- `milestone3_smoke.gd`: 상점 및 메타 성장 검증 통과 (100% PASS).
