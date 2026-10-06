# [TASK-QA-020] Stage-by-Stage Playthrough QA Report

본 보고서는 Stage 1부터 Stage 5까지 각 스테이지의 인게임 플레이스루 검증 세부 내역을 다룹니다.

---

## 1. Stage 1: 성문 외곽 (Outskirts)
- **테마 & 환경**: 왕국 성문 외곽 평원 및 폐허, 모래먼지 앰비언스 (`assets/campaign/stage_one_v1.png`)
- **인카운터 구성**: 총 5개 (일반 인카운터 4개 + 보스 인카운터 1개)
  - Encounter 0 (x=400): Wave 1 일반 근접병 1체, Wave 2 근접병 2체
  - Encounter 1 (x=1850): Wave 1 근접병 1체, Wave 2 근접병 2체
  - Encounter 2 (x=3300): Wave 1 근접병 2체, Wave 2 근접병 2체
  - Encounter 3 (x=4750): Wave 1 근접병 2체, Wave 2 근접병 2체
  - Boss Encounter (x=6200): BossCommander 출현
- **체크포인트**: 2개소 (x=1600, x=4500)
- **보스**: `BossCommander` (최대 HP 12)
  - HP <= 6 도달 시 Phase 2 진입 및 공격 주기/이펙트 격화
  - 격파 시 보스 헬스바 언로드 및 스테이지 클리어
- **결과**: `CLEARED (PASS)`

---

## 2. Stage 2: 야수숲 (Beast Forest)
- **테마 & 환경**: 짙은 수풀과 야수 서식지, 에메랄드 그린/숲 안개 앰비언스 (`assets/campaign/stage_two_v1.png`)
- **인카운터 구성**: 총 6개 (일반 인카운터 5개 + 보스 인카운터 1개)
  - Encounter 0~4: Charging Beast 및 돌진 몬스터 중심의 웨이브 배치
  - Boss Encounter (x=9400): BeastChieftain 출현
- **체크포인트**: 2개소 (x=2800, x=6500)
- **보스**: `BeastChieftain` (최대 HP 14)
  - 돌진 전 포효/붉은 안광 텔레그래프 검증
  - HP <= 7 도달 시 Phase 2 진입 및 2단 연속 돌진 패턴 활성화
- **검증 캡처**: `QA_REVIEW/full-campaign-020/captures/stage2_beast_combat_gameplay.png`
- **결과**: `CLEARED (PASS)`

---

## 3. Stage 3: 무너진 성벽 (Crumbling Ramparts)
- **테마 & 환경**: 파괴된 왕국 외곽 고지대 성벽, 더스티 퍼플 및 오렌지 앰비언스, Ember 파티클 (`assets/campaign/stage_three_v1.png`)
- **인카운터 구성**: 총 6개 (일반 인카운터 5개 + 보스 인카운터 1개)
  - Encounter 0~4: RangedEnemy 배치 및 원거리 화살 궤적/투사체 피격 판정
  - Boss Encounter (x=9400): CrossbowCommander 출현
- **체크포인트**: 2개소 (x=2800, x=6500)
- **보스**: `CrossbowCommander` (최대 HP 16)
  - 다각도 부채꼴 산탄 화살 및 저격 조준선 텔레그래프 검증
  - HP <= 8 도달 시 Phase 2 진입
- **검증 캡처**: `QA_REVIEW/full-campaign-020/captures/stage3_ranged_combat_gameplay.png`
- **결과**: `CLEARED (PASS)`

---

## 4. Stage 4: 돌의 성소 (Stone Sanctuary)
- **테마 & 환경**: 고대 석조 의식 공간, 묵직한 룬 발광 및 돌가루 파티클 (`assets/campaign/stage_four_v1.png`)
- **인카운터 구성**: 총 6개 (일반 인카운터 5개 + 보스 인카운터 1개)
  - Encounter 0~4: GroundSlamGolem의 지면 강타 및 충격파 바닥 텔레그래프
  - Boss Encounter (x=9400): AncientGolemGuardian 출현
- **체크포인트**: 2개소 (x=2800, x=6500)
- **보스**: `AncientGolemGuardian` (최대 HP 20)
  - 광역 지면 균열(Ground Slam) 리드로우 갱신 검증 완료 (TASK-AR-018 수정 사항 유효)
  - HP <= 10 도달 시 Phase 2 진입 및 고대 룬 충격파 연타 패턴
- **결과**: `CLEARED (PASS)`

---

## 5. Stage 5: 침묵의 성채 (Silent Citadel)
- **테마 & 환경**: 심연에 잠식된 암흑 대성당, 심연의 보라/크림슨 앰비언스, Void 파티클 (`assets/campaign/stage_five_v1.png`, `terrain_v2/citadel.png`)
- **인카운터 구성**: 총 8개 (일반 인카운터 7개 + 보스 인카운터 1개)
  - Encounter 0~6: 근접/원거리/골렘 복합 교전 웨이브 배치
  - Boss Encounter (x=10550): AbyssalArbiter 출현
- **체크포인트**: 3개소 (x=2800, x=5800, x=8800)
- **보스**: `AbyssalArbiter` (최대 HP 24, 3페이즈 시스템)
  - Phase 1 (HP 24~17): 심연 참격 및 텔레포트
  - Phase 2 (HP 16~9): 대검 연격 및 공허 기둥 텔레그래프
  - Phase 3 (HP 8~0): 칠흑의 날개(Black Wings) 전개, 전장 전체를 뒤덮는 `Final Judgment` 궁극기 시전
- **검증 캡처**:
  - `QA_REVIEW/full-campaign-020/captures/stage5_entry_gameplay.png`
  - `QA_REVIEW/full-campaign-020/captures/stage5_mixed_combat_gameplay.png`
  - `QA_REVIEW/full-campaign-020/captures/stage5_arbiter_gameplay.png`
- **결과**: `CLEARED (PASS)`
