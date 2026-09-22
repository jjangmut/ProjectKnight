# 작업(Task)

작업 ID: TASK-PL-003
제목: 1지역(성문 외곽) 데이터 드리븐 시트 설계 및 구축
상태: DONE (데이터 시트 작성 완료)
분야: PL (기획)
담당: Planning Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/DATA_DRIVEN_STAGE_SPEC_001.md

## 1. 지시

기존 GDScript 하드코딩 수식 배치를 분리하여, 기획자가 직접 수치와 배치를 편집할 수 있는 JSON 기반 데이터 시트 체계를 확립하고 1지역(성문 외곽)의 정식 데이터를 구축한다.

## 2. 완료 조건

1. `monsters.json`에 1지역 몬스터 4종(기본병, 궁수, 돌진수, 골렘) 및 신규 중간보스(방패기사단장)의 HP, 이동속도, 사거리, 윈드업, 방어가능 여부 스펙 명시.
2. `stages/stage_01.json`에 폭 11000px, 6개 인카운터(웨이브 구성 포함), 2개 체크포인트, 3개 상단 선택 경로의 정밀 좌표 및 스폰 구성 완료.
3. 스키마 구조가 클라이언트 로더 연동 요구사항(`DESIGN/DATA_DRIVEN_STAGE_SPEC_001.md`)과 일치할 것.

## 3. 결과물

- `DESIGN/DATA_DRIVEN_STAGE_SPEC_001.md`
- `CLIENT/Game/data/monsters.json`
- `CLIENT/Game/data/stages/stage_01.json`
