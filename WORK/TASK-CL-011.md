# 작업(Task)

작업 ID: TASK-CL-011
제목: Data-Driven StageLoader 아키텍처 준비
상태: DONE (StageLoader 구현 및 자동 검증 PASS)
분야: CL (클라이언트)
담당: Client Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/DATA_DRIVEN_STAGE_SPEC_001.md, CLIENT/Game/data/stages/stage_01.json

## 1. 지시

`first_stage.gd`의 하드코딩된 스테이지 생성 로직을 데이터 기반 아키텍처로 전환하기 위해, JSON 데이터를 파싱하여 인카운터, 게이트, 체크포인트, 몬스터를 동적으로 생성하는 `StageLoader` 노드/스크립트를 구현 준비한다.

## 2. 완료 조건

1. `CLIENT/Game/scripts/stage/stage_loader.gd` 구조 설계:
   - `stage_XX.json`을 읽어 `world_width`, `parallax_layers`, `encounters`, `checkpoints`, `optional_routes` 파싱.
   - 기존의 검증된 체크포인트 복원 스냅샷 메커니즘(`resume_snapshot`)과의 완전한 호환성 보장.
2. `monsters.json` 데이터를 기반으로 적 노드를 인스턴스화하고 속성(HP, 윈드업, 방어가능 여부, 속도)을 주입하는 팩토리 함수 마련.
3. 기존 24개 기술 QA 테스트와의 회귀가 없음을 검증하는 마이그레이션 계획 수립.

## 3. 결과물

- `WORK/TASK-CL-011.execution.json`
- `CLIENT/Game/scripts/stage/stage_loader.gd` (구현 시점)
