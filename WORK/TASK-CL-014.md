# 작업(Task)

작업 ID: TASK-CL-014
제목: 1지역 및 전 지역 스테이지의 Data-Driven StageLoader 완전 전환
상태: DONE (구현 및 회귀 테스트 37 checks PASS)
분야: CL (클라이언트)
담당: Client Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: CLIENT/Game/scripts/stage/first_stage.gd, CLIENT/Game/data/stages/stage_01~05.json

## 1. 지시

`first_stage.gd`의 기존 하드코딩 수식 배치를 `StageLoader.get_stage_data(stage_number)`로 전환하여, 기획 JSON 데이터 시트로부터 월드 폭, 게이트 위치, 체크포인트 좌표, 상단 선택 분기 데이터를 동적으로 읽어오도록 리팩토링한다.

## 2. 완료 조건

1. `first_stage.gd` `_enter_tree()`에서 `StageLoader`를 통해 `stage_XX.json` 데이터를 로드하고 인카운터/체크포인트/상단분기 초기화.
2. 만약 JSON 데이터가 없을 경우를 대비한 기존 수식 알고리즘으로의 안전한 Fallback 유지.
3. 기존 37개 스테이지 회귀 테스트(`tests/stage_smoke.gd`) 100% 통과.

## 3. 결과물

- `CLIENT/Game/scripts/stage/first_stage.gd`
- `tests/stage_smoke.gd` (37 checks PASS)
