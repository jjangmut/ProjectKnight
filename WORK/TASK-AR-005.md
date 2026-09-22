# 작업(Task)

작업 ID: TASK-AR-005
제목: 4계층 패럴랙스 배경 노드 시스템(`ParallaxStageBackdrop`) 구축 및 스테이지 연동
상태: DONE (ParallaxStageBackdrop.gd 구현 및 stage_art.gd 연동 완료)
분야: AR (아트/환경)
담당: Art Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/ENVIRONMENT_TILESET_SPEC_001.md, CLIENT/Game/scripts/art/stage_art.gd

## 1. 지시

단순 고정 화면 배경(CanvasLayer)을 대체하여, 카메라 이동에 따른 4단계 원근 차등 스크롤(Parallax Scrolling)을 구현하는 `ParallaxStageBackdrop` 노드 아키텍처를 구축하고 `stage_art.gd`에 연동한다.

## 2. 완료 조건

1. `CLIENT/Game/scripts/art/parallax_stage_backdrop.gd` 구현.
   - Layer 1 (하늘/천체): 스크롤 계수 0.05, 무한 반복 미러링.
   - Layer 2 (원경 산맥/성채 실루엣): 스크롤 계수 0.20, 무한 반복 미러링.
   - Layer 3 (중경 요새 잔해): 스크롤 계수 0.50, 무한 반복 미러링 및 기본 텍스처 합성.
   - Layer 4 (전경 대기 안개): 스크롤 계수 1.15, 하단 드리프트 연출.
2. 각 지역(1~5지역) 번호에 따라 밤하늘 및 실루엣 테마 색상 동적 매핑 지원.
3. `stage_art.gd`와 통합하여 기존 `background` 멤버 프로퍼티 및 스모크 테스트와 100% 호환성 유지.

## 3. 결과물

- `CLIENT/Game/scripts/art/parallax_stage_backdrop.gd`
- `CLIENT/Game/scripts/art/stage_art.gd`
- `WORK/TASK-AR-005.md`
