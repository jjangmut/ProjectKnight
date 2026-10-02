# Project Knight AI 인계 체크리스트

Codex / Antigravity / ChatGPT 간 작업을 넘길 때 사용하는 공통 체크리스트다.

## 작업 종료 전

- [ ] 현재 브랜치와 원격 HEAD 확인
- [ ] 변경 파일 확인
- [ ] 테스트 실행
- [ ] PASS/FAIL 결과 기록
- [ ] 실행하지 못한 테스트 기록
- [ ] 미완료 코드/버그/블로커 기록
- [ ] `STATE.md` 갱신
- [ ] 커밋
- [ ] push
- [ ] 다음 작업의 관련 파일/함수 기록
- [ ] 필요 시 `integration` PR 생성

## STATE.md 인계 메모 예시

```md
### 최신 인계
- 작업 브랜치: codex/fix-stage3-boss
- 마지막 커밋: abcdef12
- 완료: Stage 3 보스 투사체 충돌 수정
- 검증: boss_smoke 24/24 PASS
- 미실행: Android 실기
- 블로커: 없음
- 다음 작업: CLIENT/Game/scripts/enemy/crossbow_commander.gd의 Phase 2 패턴 실기 밸런스 확인
```

## ChatGPT에서 재개할 때

1. `integration` HEAD 확인
2. 해당 작업 브랜치와 비교
3. `AGENTS.md`, `STATE.md` 읽기
4. 최근 커밋 10개 확인
5. 관련 파일 및 테스트 읽기
6. GitHub에 push된 상태만 사실로 취급
