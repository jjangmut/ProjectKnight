# Project Knight Agent Rules & Execution Policy

## 1. Core Operating Rule: Autonomous Execution (자율 완주 원칙)
- **계획 승인(Planning Review) 대기 금지**:
  - `implementation_plan.md` 승인 요청('Proceed' / 'Submit')이나 `ask_question` 모달로 사용자의 승인을 기다리지 마십시오.
  - 모든 작업은 지시를 받는 즉시 계획 수립 ➔ 소스 코드 수정 ➔ Godot 헤드리스 테스트 스위트 작성/실행 ➔ 회귀 검증까지 한 번에 자율적으로 완주합니다.
- **철저한 품질 검증**:
  - 변경 사항은 항상 Godot 콘솔 엔진(`Godot_v4.7.2-stable_win64_console.exe --headless -s`)으로 100% PASS 검증을 마친 후 보고합니다.

## 2. Environment & Working Directory
- **Worktree**: 항상 `Worktrees/ProjectKnight/ART-STAGE-BATCH-001` (Branch: `task/art-stage-batch-001`)에서 작업하며, main 레포지토리를 직접 수정하지 않습니다.
- **Language**: 모든 보고, 커밋 로그, 문서는 전문적인 한국어로 작성합니다 (영문 기술 식별자/명령어 보존).
