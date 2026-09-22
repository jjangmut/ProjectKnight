# 작업(Task)

작업 ID: TASK-PL-004
제목: 2~5지역(야수숲, 성벽, 성소, 성채) 데이터 시트 확장 설계 및 구축
상태: DONE (2~5지역 데이터 시트 구축 완료)
분야: PL (기획)
담당: Planning Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: CLIENT/Game/data/stages/stage_02~05.json

## 1. 지시

1지역 데이터 시트 구조를 기반으로, 2~5지역의 월드 폭, 고유 테마, 몬스터 인카운터(웨이브 구성), 체크포인트 좌표, 상단 선택 분기 지형 데이터를 JSON으로 완성한다.

## 2. 완료 조건

1. `stage_02.json` (야수숲: 폭 11600, 필수 6, CP 2, 선택 3, 돌진맹수 중심) 구축.
2. `stage_03.json` (무너진 성벽: 폭 12000, 필수 8, CP 3, 선택 4, 성벽 궁수 중심) 구축.
3. `stage_04.json` (돌의 성소: 폭 11200, 필수 8, CP 3, 선택 4, 지면강타 골렘 중심) 구축.
4. `stage_05.json` (침묵의 성채: 폭 12600, 필수 8, CP 3, 선택 4, 최종 혼합 엘리트 방어선) 구축.
5. 전체 5개 지역의 총 폭(58400px), 총 체크포인트(13개), 총 필수 인카운터(36개), 총 선택 분기(18개)가 기존 시스템 명세(`DESIGN/STAGE_EXPANSION_003.md`)와 100% 일치할 것.

## 3. 결과물

- `CLIENT/Game/data/stages/stage_02.json`
- `CLIENT/Game/data/stages/stage_03.json`
- `CLIENT/Game/data/stages/stage_04.json`
- `CLIENT/Game/data/stages/stage_05.json`
