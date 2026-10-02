# Project Knight Agent Rules & Execution Policy

## 1. Core Operating Rule: Autonomous Execution (자율 완주 원칙)
- **계획 승인(Planning Review) 대기 금지**:
  - `implementation_plan.md` 승인 요청('Proceed' / 'Submit')이나 `ask_question` 모달로 사용자의 승인을 기다리지 마십시오.
  - 모든 작업은 지시를 받는 즉시 계획 수립 ➔ 소스 코드 수정 ➔ 가능한 자동화 검증 ➔ 회귀 검증 ➔ 상태 문서 갱신까지 한 번에 자율적으로 완주합니다.
- **철저한 품질 검증**:
  - 로컬 Godot 실행이 가능한 에이전트(Codex/Antigravity)는 `Godot_v4.7.2-stable_win64_console.exe --headless -s` 기반 테스트를 실행하고 100% PASS 여부를 확인한 뒤 보고합니다.
  - GitHub만 접근 가능한 ChatGPT Chat은 로컬 실행/빌드를 수행했다고 주장하지 않습니다. 저장소의 실제 커밋, 테스트 코드, 최근 검증 기록만 근거로 상태를 보고합니다.

## 2. Environment & Working Directory
- **주 작업 Worktree**: `Worktrees/ProjectKnight/ART-STAGE-BATCH-001`
- **주 작업 Branch**: `task/art-stage-batch-001`
- 현재 단계에서는 위 브랜치를 프로젝트의 통합 기준선으로 사용합니다.
- 서로 다른 AI 에이전트가 같은 파일을 동시에 수정하지 않도록 작업 시작 전에 원격 HEAD를 확인하고, 최신 커밋을 기준으로 작업합니다.
- **Language**: 모든 보고, 커밋 로그, 문서는 전문적인 한국어로 작성합니다. 영문 기술 식별자/명령어는 원문을 유지합니다.

## 3. Source of Truth (진실의 원천)
에이전트는 프로젝트 상태를 다음 순서로 판단합니다.

1. 현재 Git 브랜치의 실제 소스 코드와 데이터
2. 최신 커밋 이력 및 테스트 결과
3. `STATE.md`
4. `PROJECT.md`, `PROJECT_RULES.md`
5. `WORK/TASK-*.md`, `WORK/DEC-*.md`, `DESIGN/*.md`

문서와 코드가 충돌하면 **최신 코드와 커밋이 우선**입니다. 충돌을 발견한 에이전트는 작업 종료 전에 관련 상태 문서를 최신화합니다.

## 4. CODEX ↔ ChatGPT 인계 규칙

### 4.1 인계 목적
Codex 사용량 소진, 세션 종료, 작업 환경 전환 시에도 동일한 GitHub 저장소를 기준으로 ChatGPT Chat 또는 다른 에이전트가 즉시 작업을 이어갈 수 있어야 합니다.

### 4.2 Codex/Antigravity → ChatGPT Chat 인계
로컬 실행 가능한 에이전트는 작업을 넘기기 전에 다음을 완료합니다.

1. 작업 파일 저장 및 로컬 변경 내용 확인
2. 가능한 Godot 헤드리스 테스트/회귀 테스트 실행
3. 실패 항목이 있으면 숨기지 말고 원인과 미해결 상태를 기록
4. 완료된 변경을 현재 작업 브랜치에 커밋
5. 원격 GitHub에 push
6. `STATE.md`에 다음을 갱신
   - 현재 단계
   - 방금 완료한 핵심 작업
   - 실제 검증 결과
   - 알려진 문제/블로커
   - 다음 우선 작업
   - 기준 커밋 SHA 또는 커밋 제목
7. 미완료 작업이 있으면 `STATE.md`의 “다음 작업”에 파일 경로와 구체적 재개 지점을 남김

**커밋되지 않은 로컬 변경은 ChatGPT Chat이 볼 수 없으므로 인계 완료로 간주하지 않습니다.**

### 4.3 ChatGPT Chat → Codex/Antigravity 인계
GitHub 기반 ChatGPT Chat은 다음 원칙을 따릅니다.

1. 작업 시작 시 원격 브랜치 HEAD와 최신 커밋을 먼저 확인
2. `AGENTS.md` → `STATE.md` → 관련 코드/테스트/작업 문서 순으로 읽음
3. GitHub에서 직접 수정할 경우 최신 blob SHA를 기준으로 안전하게 갱신
4. 코드 수정 후 가능한 정적 검토 및 기존 테스트 계약을 확인
5. 로컬 Godot 실행이 불가능한 경우 **“미실행”** 상태를 명시
6. 작업 결과를 커밋하고 `STATE.md`에 변경 사항과 검증 한계를 기록
7. Codex/Antigravity가 이어서 수행해야 할 로컬 검증 명령과 대상 테스트를 명확히 남김

### 4.4 세션 재개 규칙
새 에이전트는 사용자의 과거 채팅 내용보다 저장소를 우선합니다. 최소 재개 절차는 다음과 같습니다.

1. 현재 branch 및 HEAD 확인
2. 최근 커밋 10개 확인
3. `AGENTS.md`, `STATE.md`, `PROJECT.md` 확인
4. `STATE.md`의 다음 작업과 관련 파일 읽기
5. 변경 전 기존 구현/테스트 계약 확인
6. 완료 후 커밋 + `STATE.md` 갱신

### 4.5 금지 사항
- GitHub에 push되지 않은 로컬 변경을 다른 에이전트가 알고 있다고 가정하지 않습니다.
- 과거 채팅 기억만으로 파일 상태를 추정하지 않습니다.
- 실제 실행하지 않은 Godot 테스트, Android 빌드, APK 설치 검증을 PASS로 보고하지 않습니다.
- 서로 다른 에이전트가 같은 파일을 병렬 수정하지 않습니다.
- 최신 코드와 충돌하는 오래된 TASK/설계 문서를 그대로 현재 사실로 취급하지 않습니다.

## 5. 작업 완료 보고 기준
작업 완료 보고에는 최소한 다음이 포함되어야 합니다.

- 변경한 핵심 파일
- 구현 내용 요약
- 실행한 테스트와 PASS/FAIL 수
- 실행하지 못한 검증 항목
- 생성한 커밋
- 남은 리스크 또는 다음 작업
