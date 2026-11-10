# AUTOMATION-005 — Python Tkinter 실행기 삭제 및 C# WinForms 전면 재구축

**Repository:** `jjangmut/ProjectKnight`
**Target branch:** `studio/v3-automation-winforms-rebuild`
**Base branch:** `studio/v3-automation-oneclick-launcher`
**Type:** Windows desktop developer utility (not game milestone)
**Status:** TODO

## 1. 결정사항 — Python GUI는 유지하지 않는다
사용자 확정 요구사항: **기존 Python Tkinter 원클릭 프로그램을 삭제하고 C# Windows Forms(WinForms)로 처음부터 다시 구현한다.** Python GUI와 WinForms GUI를 병행 운영하거나 Python 기반 실행기를 백업 프로그램으로 남기지 않는다. 다만 이미 구축된 PowerShell 자동화 엔진 및 격리 Worktree의 유효한 기능은 재사용하여 실제 게임 개발을 방해하지 않는다.

## 2. 대상 환경
- Windows 11 x64
- `D:\JUNYPAPA_STUDIO\Projects\ProjectKnight` (기존 Godot 게임 개발 작업 폴더, 건드리지 않음)
- `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\` (로컬 자동화 프로그램)
- `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree` (격리 개발용 Git worktree)
- `runner.ps1`, `config.json`, `security_settings.json`, `state/tasks_state.json` (기존 엔진 — 필요한 안전성 수정만)
- `agy` Antigravity CLI
- GitHub 계정/비밀번호/토큰을 코드에 하드코딩하지 않는다.

## 3. 구현 기술
1. **C# WinForms (.NET 8 LTS 이상 Windows Desktop)**. Windows PC에 설치된 .NET SDK 확인 후 필요하다면 공식 Microsoft 배포본만 설치(사용자 권한/승인 준수). 빌드 및 실제 실행을 검증.
2. 프로젝트 예시: `tools/automation/ProjectKnight.Launcher/ProjectKnight.Launcher.csproj`, `Program.cs`, `MainForm.cs`, `Services/...`, `Models/...`.
3. **Windows x64 self-contained single-file EXE** 형태로 `dotnet publish` 수행. 설치형 서비스, MCP, Webhook, GitHub Actions Self-Hosted Runner 및 백그라운드 폴링 불필요.
4. 필요 시 GUI 유지/단위 테스트용 로직 분리. WPF, Electron, Python wrapper/embedding 사용하지 않는다.

## 4. UI/UX
- 창 제목: **ProjectKnight 자동 개발 실행기**.
- 단일 핵심 버튼: **「GitHub 작업 가져와 실행」**. 사용자가 버튼을 클릭했을 때만 GitHub 조회.
- **「자동 승인」 ON/OFF** 옵션 (기본 OFF, 로컬 JSON 저장). ON 시에도 사용자의 명시적인 *해당 버튼 클릭 1회*에 대해서만 승인하고 실행. 백그라운드 재실행이나 작업 연쇄 실행 금지. GitHub 지시서가 여러 개면 목록에서 정확히 하나 선택해야 하며 자동으로 첫 후보 실행 금지.
- 선택 가능한 작업 목록: Task ID, 제목, 대상 브랜치, 원격 SHA, 완료/진행 여부 및 요약. 목록 조회(refresh)와 선택 작업 실행 흐름을 분리하여 기존 Tkinter의 '여러 후보면 영원히 실행 불가' 버그를 반복하지 않는다.
- 실시간 6단계 상태: 탐색 → 검증 → Worktree 준비 → CLI 개발/테스트 → 변경 범위 검증/커밋 → GitHub Push. 경과 시간 및 실시간 stdout/stderr 로그 표시; 근거 없는 퍼센트 진행률을 출력하지 않는다.
- 작업 중 중복 클릭 방지, 안전한 취소/중지, 완료·실패·부분완료 구분, 최종 GitHub 커밋 링크 및 로그 열기.
- `async/await`, `ProcessStartInfo`, `OutputDataReceived` 또는 `ReadLineAsync`, `CancellationToken` 사용해 UI 스레드 블로킹 및 cross-thread 접근 방지.
- 바탕화면 바로가기 **「ProjectKnight 작업 실행」**은 새 `ProjectKnight.Launcher.exe`를 직접 가리키도록 재생성.

## 5. GitHub 작업 탐색과 실행 무결성 — 필수 수정
이전 독립 검수: `STUDIO_V3/reviews/AUTOMATION-004-INDEPENDENT-REVIEW.md`를 먼저 읽고 다음 결함을 수정한다.

- 무작정 모든 브랜치의 역사적 `V3-*.md`를 모아 최신 작업으로 간주하지 않는다. 작업 ID, 브랜치 선언 및 파일 경로를 일치시키고 완료 기록/동시 실행을 걸러 후보를 중복 제거. **작업 여러 건을 UI에서 선택해 정상 실행할 것**.
- 승인/선택 시 **Task ID + 정확한 remote branch + 40자리 commit SHA**를 고정하여 `runner.ps1`에 전달. Runner에서 실제 원격 HEAD/지시서 내용이 승인 시점과 동일한지 재검증하고 일치하지 않으면 실패 처리. 로컬 메인 프로젝트 파일로 잘못된 작업을 실행하는 fallback 금지.
- 실행 명령은 검증된 인자 배열로만 구성. 지시서 markdown을 PowerShell 식/명령으로 실행하지 않는다.
- 작업 범위·계정·기본 브랜치·기타 프로젝트 보호 및 기존 격리 Worktree 유지.
- **Antigravity CLI JSON status**를 엄격히 파싱. Exit 0인데 JSON 부재·실패·거부된 필수 도구 동작이면 성공으로 처리하지 않는다. Push 실패/SkipPush/변경 없음/테스트 미실행은 상황에 맞는 PARTIAL/NO_CHANGES 처리. 실질적인 작업 완료 검증을 별도로 남긴다.
- `security_settings.json`의 `command(*)` 허용 + 문자열 deny 리스트는 OS 격리가 아니다. 위험 자동 승인 범위를 설명하고 가능하면 OS 제한 계정/권한 설계를 적용. `--dangerously-skip-permissions` 금지.
- 이미 진행 중인 V3-017 Android 빌드 작업은 자동 실행·재실행·체크아웃 금지.

## 6. 기존 Python 실행기 제거
**새 WinForms EXE가 빌드되고 핵심 테스트가 통과한 뒤 같은 작업 안에서 Python 실행기와 관련 테스트, Python 진입점, VBS/BAT 실행 래퍼, Python 바로가기를 삭제한다.** 삭제 대상은 다음과 같다.
- `tools/automation/launcher.py`
- `tools/automation/test_launcher.py`
- `tools/automation/test_e2e_launcher.py`
- `tools/automation/run_launcher.bat`
- `tools/automation/run_launcher.vbs`
- Python 전용 바탕화면 바로가기/로컬 복사본/런처 실행 엔트리포인트 및 문서 (대체 EXE 바로가기 생성)
- 저장소의 다른 **게임용 Python 스크립트나 다른 도구**는 삭제하지 않는다.
- `runner.ps1`과 상태 파일/로그/사용자 설정/Antigravity 인증은 삭제하지 않는다.
- 삭제/교체할 사용자 PC 파일을 실제 목록으로 검증하고, 데이터 손실 없이 GUI 런처 파일만 제거한다.
- README, 배포 스크립트, 설치 스크립트의 Python 참조를 C# EXE로 교체한다.

## 7. 테스트 및 수락 기준
1. Windows에서 `dotnet restore/build/publish` 성공, 출력 EXE 실존 및 실제 바탕화면 바로가기 실행.
2. GUI에서 자동 승인 OFF/ON 모드 각각 테스트.
3. **작업 후보 2개 이상일 때 두 번째 항목을 선택해 정확히 해당 ID/브랜치/SHA로 실행**하고, 재클릭·중복 실행 차단 테스트.
4. 원격 SHA 변경·잘못된 Branch 메타데이터·완료된 작업·CLI 반환 JSON 오류/실패·Push 실패 시 실패/중지 처리.
5. 테스트 전용 `test/v3-...` 지시서로 CLI 호출, 단계별 실시간 로그, 커밋 및 Push 검증. 테스트 결과를 GitHub 커밋/URL로 입증. 실제 V3-017 실행 금지.
6. 기존 메인 ProjectKnight 작업 폴더와 작업중 게임 브랜치가 손상되지 않았음을 확인.
7. Python 런처 파일 제거 및 새 EXE 바로가기 전환 확인.
8. 신규 설치 파일의 실제 실행 위치, .NET 버전, 파일 목록, 주요 테스트 증거 및 남은 위험을 결과 보고서에 명시.
9. GitHub 작업 브랜치에 안전한 소스와 테스트/문서를 커밋·Push. 빌드 산출물 `bin/obj`와 로컬 인증정보는 커밋하지 않음.

**완료 정의:** 실사용 가능한 WinForms EXE 하나로 원클릭 GitHub 작업 조회→작업 선택→자동/수동 승인→Antigravity 개발/테스트→GitHub Push 및 상태 로그까지 동작하고, 기존 Python GUI 구현이 삭제됨. 테스트를 모두 충족하지 못하면 완료라고 보고하지 말고 PARTIAL/FAIL 처리.


## 8. 사용자 요구사항 최종 단순화 (2026-11-10, 최우선)
**사용자가 프로그램을 직접 실행해 놓는다. 프로그램의 핵심 목적은 GitHub의 선택된 작업지시서를 가져와 Antigravity에 전달하고 개발을 시작시키는 것뿐이다.** 기존 요구사항과 충돌하면 이 절이 우선한다.

- 필수 사용자 흐름: (1) 사용자가 Windows 프로그램 실행 → (2) GitHub 작업 목록 가져오기 버튼 → (3) 작업 선택 및 필요 시 자동 승인 옵션 → (4) 선택된 원격 지시서 ID·브랜치·SHA 검증 → (5) **Antigravity CLI에 정확한 작업지시를 전달하여 실제 실행 시작** → (6) 실행 시작 여부와 현재 로그/상태 표시.
- **실행 파일을 자동으로 띄우는 상주 서비스/감시, GitHub Webhook/MCP/Actions, 결과 자동 Push, 고급 대시보드, 복잡한 CI 파이프라인은 이번 목표의 필수 조건이 아니다.** 개발 범위를 늘리지 말 것.
- 기존 `agy` CLI와 간단한 `runner.ps1` 연동을 우선 활용. GUI는 **C# WinForms 유지**; 사용자 요청대로 Python GUI는 제거 상태를 유지. PowerShell WinForms 대체 GUI를 필수 결과물로 간주하지 말 것.
- 진행 로그와 자동 승인 ON/OFF는 이미 사용자 요청한 기능이므로 간단하게 유지하되, 수동 승인에서 숨겨진 `Read-Host`가 멈추지 않도록 수정한다. 실행 지시의 대상 브랜치·SHA 불일치/중복 실행을 막는 최소 안전장치를 유지한다.
- Antigravity CLI는 **현재 데스크톱 Antigravity IDE 창에 메시지를 주입하는 것과 다르다**. CLI 세션으로 지시를 전달할 것인지 IDE에 전달할 방법이 있는지 검증하여 차이를 사용자에게 명확히 보고한다. 근거 없는 IDE 자동제어 주장은 금지.
- Windows Smart App Control 때문에 네이티브 C# EXE가 차단되면 **보안 기능을 끄거나 우회하지 말고 차단 사실을 명시**한다. 원클릭 실행 가능한 EXE가 핵심 요구사항이므로 실제 OS 실행 테스트 없이는 완료 판정 불가.
- 핵심 수락 기준은 **실제 Windows GUI에서 사용자가 직접 실행 → GitHub에서 작업 선택 → Antigravity CLI가 정확한 지시서를 읽고 작업을 시작함을 증명**하는 한 번의 테스트이다. 자동 Push나 다른 인프라 작업을 완료할 필요는 없다. 현재 게임 개발 작업 V3-017을 건드리지 않는다.
