# [TASK-QA-020] Reward, Relic & Save/Load QA Report

본 문서는 보스 격파 후 보상 화면, 트레이트 선택, 유물(Relic) 5종의 스탯/능력 연동, 그리고 SaveManager를 통한 저장/로드 라운드트립 무결성 검증 결과를 기술합니다.

---

## 1. 보상 패널 및 트레이트 선택 검증

- **보상 패널 트리거**:
  - 스테이지 최종 보스 격파 시 스테이지 상태가 `CLEARED`로 전환되며 `CampaignRoute` 및 트레이트 선택 UI(`RewardPanel`)가 자동 노출됨.
- **트레이트 선택 및 계승**:
  - `campaign.choose_trait("reach")` 또는 `continue_journey()` 호출 시 선택된 트레이트가 `campaign.selected_traits` 목록에 누적됨.
  - 다음 스테이지로 전이되어 새로운 플레이어 노드가 스폰될 때 트레이트 효과(예: 공격 리치 증가, 대시 쿨다운 감소 등)가 즉시 재적용됨.

---

## 2. 유물(Relic) 5종 패시브 스탯/능력 연동 검증

Project Knight에 구현된 5개 주요 유물의 인게임 연동 상태를 전수 검증하였습니다:

| 유물 명칭 | 식별자 | 획득 스테이지 | 연동 메커니즘 및 플레이어 파라미터 변화 | 검증 결과 |
| :--- | :--- | :--- | :--- | :--- |
| **수호자의 방패** | `relic_shield` | Stage 1 완료 후 | `player.relic_shield_active = true` (피격 1회 무효화 방어막) | **PASS** |
| **그림자 망토** | `relic_cloak` | Stage 2 완료 후 | `player.relic_cloak_active = true` (대시 중 완전 무적 프레임 연장) | **PASS** |
| **바람의 화살통** | `relic_quiver` | Stage 3 완료 후 | `player.relic_quiver_active = true` (공중 점프/체공 기동성 향상) | **PASS** |
| **거인의 견갑** | `relic_pauldrons` | Stage 4 완료 후 | `player.relic_pauldrons_active = true` (가드 브레이크 저항 및 경직 감소) | **PASS** |
| **심연의 왕관** | `relic_crown` | Stage 5 클리어 시 | `player.relic_crown_active = true` (최종 공격력 및 패링 충격파 증폭) | **PASS** |

- 모든 유물은 `player.refresh_relic_buffs()` 호출 시 정상 동기화되며, 스테이지 전이 후에도 상태가 손실되지 않고 온전히 유지됨.

---

## 3. SaveManager 라운드트립 무결성 검증

- **세이브 데이터 구조 (`save_manager.gd`)**:
  - `save_data.cleared_stages`: `[true, true, true, true, true]`
  - `save_data.acquired_relics`: 5종 등록
  - `save_data.selected_traits`: 선택 내역 등록
- **세이브/로드 라운드트립 시나리오**:
  1. Campaign에서 5개 스테이지 클리어 및 유물 5종 장착.
  2. 디스크에 세이브 저장 (`SaveManager.save_game()`).
  3. 세이브 파일 파싱 및 로드 (`SaveManager.load_game()`).
  4. 클리어 플래그 배열, 획득 유물 목록, 선택 트레이트가 1:1 완벽히 복원됨을 검증.
- **결과**: `tests/full_campaign_reward_qa.gd` 26개 항목 100% PASS.
