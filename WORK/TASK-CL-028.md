# [TASK-CL-028] 캐릭터-몬스터 바디 물리 중첩(Stacking Lock) 버그 해결 및 근접 타격 판정 개선

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 관련 버그 리포트: 유저 첨부 스크린샷 (몬스터가 플레이어 머리 위로 올라타 이동/점프/공격 불가 현상)

## 1. 개요 및 원인 분석
- **현상**: 몬스터가 점프 후 플레이어 머리 위로 착지 시, 플레이어 머리 위에 올라타 서서 몬스터/플레이어 모두 이동, 점프, 공격이 완전히 불가능해지는 치명적 물리 락(Physics Stacking Lock) 발생.
- **원인 1 (물리 고체 충돌)**: 플레이어와 몬스터의 `CharacterBody2D`가 둘 다 기본 `collision_layer = 1`, `collision_mask = 1`을 사용하여 서로를 단단한 고체 지형(벽/바닥/천장)으로 인식함. 몬스터는 플레이어 머리를 바닥으로 밟고 서고, 플레이어는 천장 충돌로 점프 캔슬 및 캡슐 겹침으로 수평 이동 불가.
- **원인 2 (공격 사각지대)**: 플레이어 공격 판정 시작점이 플레이어 중심부 외곽(+20px)부터 시작하여 몸체에 겹친 적에 칼날이 닿지 않는 사각지대 존재.
- **원인 3 (공중 공격 락)**: 몬스터가 공중에서 플레이어 위로 떨어질 때 `is_on_floor()` 체크 없이 공격 상태로 진입하여 공중 헛손질 무한 루프 발생.

## 2. 해결 내역
1. **CharacterBody2D 물리 레이어 분리**:
   - 지형/월드 (`StaticBody2D`): Layer 1 (Environment)
   - 플레이어 (`Player`): `collision_layer = 8` (Player Body), `collision_mask = 1` (지형만 충돌)
   - 몬스터 (`TestEnemy`, `RangedEnemy`, 보스 등): `collision_layer = 16` (Enemy Body), `collision_mask = 1` (지형만 충돌)
   - 효과: 몬스터가 공중에서 떨어져도 플레이어 머리 위에 올라타지 않고 지면으로 통과하여 바닥에 안전하게 착지. 상호 간 물리 벽/천장 블로킹 원천 제거.
2. **플레이어 근접 공격 범위 중심부 확장**:
   - `_update_attack_geometry()`에서 공격 시작점을 플레이어 정중앙(`X = 0.0`)부터 시작하도록 오프셋 조정 (`facing_direction * (effective_range * 0.5)`).
   - 몸체 겹침 상태에서도 전방을 휘두를 때 적이 100% 피격되도록 사각지대 완전 해소 (`AttackArea` 기본 규격 `Vector2(72, 52)` 완벽 보존).
3. **몬스터 착지 공격 보장 및 소프트 분리**:
   - `test_enemy.gd`의 `_update_chase()` 공격 진입 조건에 `is_on_floor()` 명시: 공중 낙하 중 헛공격 루프 방지.
   - 플레이어와 수평 거리 20px 이내 초근접 시 부드럽게 좌/우로 비켜서는 소프트 분리(Soft Separation) 속도 적용.
4. **품질 검증**:
   - 신규 자동화 테스트 `tests/character_stacking_bug_test.gd` (13 checks PASS).
   - 기존 전체 13개 회귀 테스트 포함 총 14개 스위트 469 checks 전수 100% PASS 달성.
