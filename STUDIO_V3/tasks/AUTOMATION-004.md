# AUTOMATION-004 — ProjectKnight 원클릭 개발 실행기 (Windows GUI)

## 목적
복잡한 MCP, Webhook, GitHub Actions, 항상 실행되는 GitHub 폴링 프로그램을 **사용하지 않는다**. 사용자가 Windows 바탕화면의 바로가기 또는 작은 앱에서 **버튼 한 번** 클릭하면 GitHub에 등록된 **미완료 작업지시서**를 읽고, 작업 내용을 화면에 보여준 후 **명확한 승인**을 받아 기존 Antigravity CLI 로컬 러너로 개발·테스트·커밋·Push를 수행한다.

## 기존 환경
- 저장소: `jjangmut/ProjectKnight` (공개 저장소)
- 프로젝트: `D:\JUNYPAPA_STUDIO\Projects\ProjectKnight`
- 자동화 도구: `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\runner.ps1`, `config.json`, `state/tasks_state.json`, `security_settings.json`
- 격리 Worktree: `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree`
- CLI: `agy` (기존 설치 활용)
- 게임 개발 V3-017을 방해하거나 실행·재실행하지 않는다.

## 실제 구현
1. Windows PowerShell WinForms/WPF 또는 Python Tkinter 중 **현재 PC에 이미 설치된 것만** 이용해 매우 작은 GUI 앱을 만든다. 새 상주 서비스, 관리자 권한, 별도 서버, 새 인증 토큰, 인터넷 수신 포트는 필요 없어야 한다.
2. 사용자의 눈에 보이는 주 버튼: **「GitHub 최신 작업 가져와 실행」**. 클릭 시에만 GitHub 읽기/갱신을 수행한다. 평상시 네트워크 트래픽과 백그라운드 폴링은 **없다**.
3. GitHub에서 브랜치와 `STUDIO_V3/tasks/V3-*.md` 지시서를 직접 확인한다. 실제 GitHub HEAD와 지시서 경로/브랜치를 검증한다. 완료 상태 `tasks_state.json`과 현재 실행 중인 락을 확인하고 완료/중복 작업은 제외한다. 모호한 후보가 여러 개면 작업 목록을 보여줘 사용자가 선택하게 하며 **아무 작업이나 최신으로 추측해 실행하지 않는다**.
4. 지시서 **작업 ID, 제목, 브랜치, HEAD SHA, 개요**를 GUI에 표시하고, 실행 전 별도 확인 버튼이나 팝업을 제공한다. 취소하면 아무것도 실행하지 않는다. `AutoApprove`는 이 명시적인 로컬 승인 이후에만 허용하며, 러너 내부 추가 보안 검사 우회 금지.
5. 이미 존재하는 `runner.ps1`을 재사용하되, 현재 Scan/Execute 동작과 로컬/원격 지시서 발견 방식을 실제 소스에서 먼저 확인하고 **실제로 동작하도록 최소 변경**한다. `runner.ps1 -Action Execute -TaskId <id>`와 관련 옵션은 현재 파라미터에 맞춰 호출하라. 실행 직전 승인했던 브랜치/SHA가 GitHub와 일치하는지 재검증하고 불일치 시 거부.
6. 자동 실행은 **분리된 Worktree 안에서만** 수행한다. 메인 프로젝트 작업 폴더의 checkout 금지. 실행 중에는 버튼 비활성화. 종료 시 성공/실패, 로그 위치, 새 커밋 SHA, GitHub 링크를 GUI에 표시한다. 사용자가 종료하려 할 때 안전한 중지 방법 제공.
7. 작업 문서나 GitHub 커밋 메시지 안의 내용을 PowerShell 명령으로 평가하거나 삽입하지 않는다. 실행 인자는 검증된 작업 ID/브랜치/SHA로만 구성한다. 변경 범위 검증 후 승인된 브랜치로만 Push; 기본 브랜치, Actions 워크플로, 계정/비밀 파일, 기존 개발 브랜치 변경 금지. 기존 보안 정책이 검증되지 않은 부분은 정확히 보고.
8. 운영 편의를 위해 바탕화면 바로가기 **「ProjectKnight 작업 실행」**을 만들 수 있도록 한다. 별도 PowerShell 창을 열지 않는 launcher(.cmd/.vbs/shortcut) 가능. 단, Windows 보안 기능 우회/비공식 바이너리 다운로드 금지.
9. GUI에는 큰 버튼 하나 외에 **상태 표시**, **진행 로그**, **작업 선택/승인·취소**만 최소한으로 둔다.
10. 설치 후 바탕화면 바로가기에서 클릭 → 미완료 GitHub 작업 표시 → 사용자 승인 → 테스트 태스크 실행 → 결과 커밋/푸시 → 재클릭 시 중복 차단까지 **실제 테스트**한다. 기존 V3-017을 테스트용으로 실행하지 않는다. 검증용 지시서가 필요하면 `test/v3-...` 전용 브랜치를 이용하고 사용자의 실제 개발 우선순위에 영향을 주지 않는다.

## 제출물 및 마감 기준
- 로컬 실행 가능한 GUI 앱 소스, 바로가기, 사용법 README. 로컬 경로 명시.
- 안전한 변경만 `studio/v3-automation-oneclick-launcher` 브랜치에 커밋 및 Push (비밀정보·사용자 PC 환경설정 제외).
- 버튼 클릭 **전에는 GitHub 조회나 Antigravity 실행이 전혀 없음**.
- 실제 테스트 근거: UI 표시 작업 ID/SHA, 실행 로그, 결과 GitHub commit SHA 및 URL, 중복 방지, 메인 프로젝트 폴더 불변.
- 테스트가 실패하거나 권한 문제로 실행이 막히면 PASS로 주장하지 말고 정확히 PARTIAL/FAIL 보고.
- **GitHub Actions Self-Hosted Runner, MCP, Webhook, 폴링 상주 프로세스는 설치하거나 사용하지 말 것.**

## 사용자 경험 (가장 중요)
사용자는 바탕화면의 **ProjectKnight 작업 실행** 아이콘만 누르면 된다. 작업지시서를 복사·붙여넣기하거나 별도 PowerShell 명령을 입력하지 않는다. 확인 대화상자에서 선택한 작업만 실행.
