# [TASK-AR-006] 보스 비주얼, 시네마틱 보스 체력바 HUD 및 연출 고도화

- 상태: DONE
- 담당: Art & UI Lead
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/COMBAT_JUICE_AND_BOSS_SPEC_001.md`


## 1. 개요
타락한 방패 기사단장의 중후한 실루엣과 방패/대검 비주얼, 분노 페이즈 발광 연출, 하단 시네마틱 보스 체력바 UI(`boss_health_bar.gd`), 영혼 파편 크리스탈 비주얼, 스테이지 빅토리 배너를 제작함.

## 2. 작업 내역
1. `CLIENT/Game/scripts/ui/boss_health_bar.gd` 제작 (지연 체력바 감쇠 연출 포함).
2. 보스 비주얼 렌더링 및 이펙트(Shockwave polygon, Enrage aura) 탑재.
3. `stage_presentation.gd`에 영혼 파편 보유량 HUD 및 빅토리 연출 연동.
