# 작업(Task)

작업 ID: TASK-CL-013
제목: 오디오 매니저(AudioManager) 및 전투 효과음 실연동
상태: DONE (구현 및 연동 완료)
분야: CL (클라이언트)
담당: Client Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: CLIENT/Game/assets/audio/guard_clang.wav

## 1. 지시

무음(Dummy) 상태였던 프로토타입의 타격감과 조작 피드백을 극대화하기 위해, 중앙 `AudioManager`를 구축하고 검막기 금속음(`guard_clang.wav`), 콤보 타수별 휘두르기/타격음, 피격음, 포고 점프음을 연결한다.

## 2. 완료 조건

1. `CLIENT/Game/scripts/audio/audio_manager.gd` 구현 (8개 채널 AudioStreamPlayer2D 풀링 및 합성/WAV 재생).
2. `CLIENT/Game/assets/audio/guard_clang.wav` 실에셋 연결.
3. 플레이어 가드 성공, 1/2/3단 콤보 공격, 카운터 타격, 공중 찍기 반동, 피격 시 즉각 오디오 트리거 호출 연동.
4. 헤드리스/더미 드라이버 환경에서도 크래시 없는 안전성 확보.

## 3. 결과물

- `CLIENT/Game/scripts/audio/audio_manager.gd`
- `CLIENT/Game/assets/audio/guard_clang.wav`
