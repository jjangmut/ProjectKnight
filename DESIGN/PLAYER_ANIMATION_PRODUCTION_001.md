# 플레이어 애니메이션 첫 제작 지시

상태: 전체 플레이어 7동작 28프레임 제작·연동 완료. 데스크톱 QA PASS, 원화/확인한 GPU 정지 화면 아트 PASS. 정상속도 사람 조작감·모바일 실기 인수는 별도다.
근거: DEC-004 캠페인 확대 승인과 기존 동작 인지성/싱크 개선 요청.
Owner: 아트 리드. 협업: 클라이언트 리드. 검토: Review/QA 및 정상 속도 Director 시각 확인.

## 지시와 순서

기존 플레이어 1종의 2등신 디자인을 유지하여 공격·달리기·회피·대기·점프·피격·사망을 하나의 제작 묶음으로 완료하고 검수했다. 개별 동작마다 Director의 다음 지시를 기다리는 방식으로 운영하지 않았다.
작업명세 원본: StudioRuntime/.runtime/production/STAGE-PACING-003/ANIMATION_WORK_ORDER.md.
공격 4프레임, 달리기6~8프레임, 회피4프레임을 출발 사양으로 사용하며 숫자만 채운 유사 정지 이미지는 반려한다.

## 인수 계약

- 동일 캔버스·발 기준점·일관된 체형/무기. 손잡이와 검 끝 기준점을 기록한다.
- 기존 controller의 상태·남은 시간으로 프레임을 선택한다. 공격0.16초는 전체 활성 구간이므로 무해한 선딜을 그림만으로 추가하지 않는다.
- HP·이동·점프·피격 보호·회피·공격 판정 규칙을 아트에 맞춰 바꾸지 않는다.
- 이전 단일 PNG 회전 연출과 새 프레임을 중복 재생하지 않는다.
- 공격 취소·피격·사망·씬 재시작, 좌우 및 터치/키보드 입력을 확인한다.

## 연동 예정 파일

- 기존 CLIENT/Game/scripts/player/player_art.gd
- 기존 CLIENT/Game/scripts/art/stage_art.gd
- 기존 CLIENT/Game/scenes/player/Player.tscn
- 신규 CLIENT/Game/assets/player_frames/ (시트와 motion_manifest.json 연결 완료)
- 기존 CLIENT/Game/tests/player_art_smoke.gd 및 tests/animation_sync_smoke.gd

player.gd, first_stage.gd, 적 AI, 저장·성장 구현은 이 아트 작업 범위 밖이다. 실제 생성 파일 목록은 납품 명세에서 고정한다.

## 결과물과 완료 조건

원본 프레임·게임 적용 자산·기준점/시간 명세·정상속도 및 느린 검토 증거를 제출한다. 발 미끄러짐·크기 변화·무기 불연속을 검토하고 기존 player art/animation sync/stage/checkpoint 검사를 유지한다. 정지 캡처나 headless 검사만으로 애니메이션 품질 완료를 선언하지 않는다.
첫 플레이어 연동 검증 후 스테이지 공통 설정 분리와 Stage2 회색박스 구현을 진행한다. 기획 설계 작업은 병행 가능하다.

## 이번 묶음 납품

- 공격4·달리기6·회피4·대기4·점프3·피격3·사망4, 총28프레임. 공격/달리기는 아트 리드 지적 수정본 v2 사용.
- manifest가 원본 PNG의 Atlas 영역·발 기준점·동작별 고정 크기를 보관한다. 생성 시트가 균등 격자를 벗어난 경우 명시 regions로 무기/발 잘림을 방지했다. 원본 픽셀은 후처리하지 않았다.
- 공격/회피/피격은 기존 controller 잔여시간, 점프는 수직속도, 달리기는 실제 이동거리로 프레임을 선택한다. 대기/사망만 시각 시간을 사용하며 pause 시 정지한다. 사망은 0.48초 후 마지막 프레임 유지.
- 기존 단일 이미지 회전/압축을 새 프레임과 중복 적용하지 않는다. player.gd 및 적/투사체 코드는 변경하지 않았다.
- 상세 납품·검토·한계: StudioRuntime/assets/ACCEPTANCE_PLAYER_MOTION_BATCH_001.md (스튜디오 루트 기준).
- 증거: StudioRuntime/.runtime/production/PLAYER-MOTION-BATCH-001/의 ART_REVIEW.md, QA_REVIEW.md, GPU/Headless 로그, 원속도 및 1/4속도 영상, 프레임 캡처, 생성 프롬프트·최종 hash.
