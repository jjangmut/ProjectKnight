# [TASK-CL-024] 3지역 관문 보스 '폐허의 석궁 사령관' 2페이즈 AI 및 볼트 탄막 구현

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/STAGE3_BOSS_AND_AIR_DASH_SPEC_001.md`

## 1. 개요
3지역(무너진 성벽) 최종 관문 보스 `CrossbowCommander`를 제작하고, 직선 고속 관통 볼트, 곡사 화살비(Volley), 플레이어 접근 시 백스텝 도약 회피, 2페이즈 데드아이 분노(Dead-Eye Enrage) 및 바닥 쇠못 트랩(Caltrop) 살포, 처치 시 15개 영혼 파편 폭발 드랍을 연동함.

## 2. 완료 내역
- `CrossbowBolt` (`scripts/enemy/crossbow_bolt.gd`): 고속 수평/낙하 볼트 투사체, 방패 가드 및 대시 무적 연동.
- `CaltropTrap` (`scripts/enemy/caltrop_trap.gd`): 2페이즈 후퇴 시 바닥에 살포되는 지면 트랩.
- `CrossbowCommander` (`scripts/enemy/crossbow_commander.gd`): 16 HP, 2페이즈 AI 상태 머신 및 시네마틱 처치 연출 탑재.
