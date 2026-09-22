# 작업(Task)

작업 ID: TASK-CL-016
제목: 로컬 영구 세이브 시스템(`SaveManager`) 구축 및 캠페인 진행 연동
상태: DONE (SaveManager.gd 구현 및 campaign.gd 연동 완료)
분야: CL (클라이언트)
담당: Client Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: CLIENT/Game/scripts/stage/campaign.gd

## 1. 지시

프로토타입의 단발성 메모리 세션 한계를 탈피하여, 플레이어의 캠페인 지역 진행도(스테이지 번호), 선택된 특성(Traits), 각 지역 클리어 플래그 및 통계 정보를 `user://save_data.json`에 영구 기록/로드/초기화하는 `SaveManager` 시스템을 구축하고 `campaign.gd`에 연동한다.

## 2. 완료 조건

1. `CLIENT/Game/scripts/system/save_manager.gd` 구현 (`save_game`, `load_game`, `has_save_file`, `clear_save`).
2. JSON 스키마 버전(`1.0.0`) 관리 및 로드 시 예외 방어/타입 보정 로직 탑재.
3. `campaign.gd`에서 게임 시작 시 세이브 파일 존재 여부 확인 및 자동 복원.
4. 스테이지 클리어, 특성 선택, 다음 지역 이동 시 자동 저장 트리거.
5. 5지역 완주 후 '처음부터 다시 도전' 시 세이브 초기화 연동.

## 3. 결과물

- `CLIENT/Game/scripts/system/save_manager.gd`
- `CLIENT/Game/scripts/stage/campaign.gd`
- `WORK/TASK-CL-016.md`
