# 작업(Task)

작업 ID: TASK-AR-002
제목: 기사 플레이어 풀 프레임 액션 스프라이트 규격 수립
상태: DONE (규격서 작성 완료)
분야: AR (아트)
담당: Art Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/PLAYER_ANIMATION_PRODUCTION_001.md, DESIGN/COMBAT_SYSTEM_DEEPENING_001.md

## 1. 지시

프로토타입 단색 사각형/일부 정지 컷에서 벗어나, 상용 액션 게임 수준의 일관된 픽셀 덴시티와 타격감을 보장하는 기사 플레이어의 6대 핵심 액션 애니메이션 프레임 규격을 확정하고 제작 가이드를 수립한다.

## 2. 완료 조건

1. 6대 액션 프레임 사양 확정:
   - 대기 (Idle: 6F 루프)
   - 달리기 (Run: 8F 루프)
   - 3단 공격 (Attack: 1타 4F, 2타 4F, 3타 6F)
   - 전방 방어/막음 (Guard Hold 2F, Guard Impact 3F)
   - 점프/공중 (Jump Rise 2F, Fall 2F, Down Thrust 3F)
   - 피격 및 사망 (Hurt 3F, Die 6F)
2. 프레임당 규격: 64×64 또는 128×128 통일 캔버스, 원점(Pivot) 발바닥 중앙(Bottom Center) 고정.
3. 무기 궤적(Weapon Trail / Slash VFX) 및 방어 스파크 파티클 규격 명시.

## 3. 결과물

- `DESIGN/PLAYER_SPRITE_SPEC_001.md` (애니메이션 프레임 명세 및 타임라인)
