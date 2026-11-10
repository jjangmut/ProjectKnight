# ProjectKnight 원클릭 개발 실행기 (C# WinForms Launcher)

## 1. 개요 (Overview)

Windows 바탕화면의 바로가기를 더블클릭한 후 **「GitHub 최신 작업 가져와 실행」** 버튼 한 번으로, GitHub에 등록된 미완료 작업지시서를 읽고 **격리된 Git Worktree**에서 Antigravity CLI로 개발·테스트·검증·커밋·Push를 수행하는 전용 C# Windows Forms(WinForms) GUI 프로그램입니다.

```text
[바탕화면 "ProjectKnight 작업 실행" 바로가기 더블클릭]
                      │
                      ▼
        [ProjectKnight C# WinForms GUI (.NET 8)]
                      │
     ┌────────────────┴────────────────┐
     ▼                                 ▼
[자동 승인: OFF (기본)]           [자동 승인: ON]
- 작업 검증 후 승인 팝업          - 1회 클릭 시 검증된 작업을
- [확인] 클릭 시 실행            추가 팝업 없이 즉시 실행
     └────────────────┬────────────────┘
                      ▼
        [실시간 6단계 파이프라인 가동]
  ① 작업 탐색 (Discover)
  ② 지시서 검증 (Validate: Branch/SHA/Id strict match)
  ③ Worktree 준비 (Worktree 격리)
  ④ Antigravity CLI 개발·테스트 (Execute)
  ⑤ 범위 검증 및 커밋 (Scope Check & Commit)
  ⑥ GitHub Push 및 결과 반영 (Push & Sync)
                      │
                      ▼
[메인 개발 폴더 100% 무간섭 · 새 커밋 생성 및 Push 완료]
```

---

## 2. 핵심 원칙 및 특징

1. **C# WinForms 및 .NET 8 LTS 기반 독립 실행형 바이너리:**
   - 기존 Python Tkinter 런처를 완전히 대체하여 .NET 8 LTS 기반 Windows Forms 데스크톱 앱으로 구축되었습니다.
   - 단일 파일 독립 실행형 EXE (`ProjectKnight.Launcher.exe`)로 배포되어 별도의 Python 환경이나 외부 패키지 설치가 필요 없습니다.
2. **상주 프로세스 / 폴링 제로 (Zero Background Polling):**
   - 상주 백그라운드 서비스, Webhook, GitHub Actions Runner, 항상 실행되는 루프가 **전혀 없습니다**.
   - 사용자가 **버튼을 클릭했을 때만** 1회성으로 GitHub 원격 브랜치를 조회(`git fetch origin --prune`)합니다.
3. **작업 무결성 바인딩 (Strict Task/Branch/SHA Binding):**
   - 작업 선택 시 `TaskId + TargetBranch + 40-digit CommitSha`를 고정하여 runner에 전달합니다.
   - 지시서에 선언된 Target Branch와 원격 브랜치가 불일치하거나 원격 SHA가 변경된 경우 즉시 거부(Fail-closed)합니다.
4. **원클릭 자동 승인 (Auto-Approve):**
   - 「자동 승인」 체크박스를 ON으로 설정하면, 버튼 클릭 1회에 한해 유효한 단일 작업을 추가 확인 팝업 없이 즉시 실행합니다.
   - 미완료 작업이 여러 개 발견된 경우 사용자가 콤보박스 목록에서 대상을 명시적으로 선택해야 합니다.
5. **실시간 단계별 진행 표시 (Live Progress UI):**
   - 6단계 진행 상태(⏳ 대기, 🔄 진행중, ✅ 완료, ❌ 실패, ⏹ 중지)가 실시간으로 표시됩니다.
   - 시작 후 경과 시간(MM:SS)과 단계 타이머가 실시간 갱신됩니다.
6. **논블로킹(Non-Blocking) 비동기 로그 스트리밍:**
   - `async/await`와 비동기 프로세스 스트리밍을 사용하여 장시간 CLI 실행 중에도 UI 스레드가 멈추지 않습니다.
   - 표준출력/표준에러가 ANSI 색상 코드 제거 및 카테고리별 컬러 하이라이트로 실시간 출력됩니다.
7. **독립 Worktree 완전 격리 (Workspace Protection):**
   - 메인 프로젝트 작업 폴더(`D:\JUNYPAPA_STUDIO\Projects\ProjectKnight`)에서는 어떠한 checkout이나 브랜치 전환도 일어나지 않습니다.
   - 모든 빌드 및 개발은 격리된 Worktree(`D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree`)에서만 수행됩니다.
   - 현재 진행 중인 V3-017 작업 등은 완벽히 보호되며 자동화 대상에서 제외됩니다.
8. **Fail-Closed CLI 결과 검증 및 Pre-Commit Scope Gate:**
   - Antigravity CLI가 유효한 JSON을 반환하지 않거나 STATUS != SUCCESS인 경우 즉시 실패 처리합니다.
   - 허가되지 않은 디렉터리 변조나 바이너리 파일 생성이 감지되면 커밋과 Push가 원천 차단됩니다.

---

## 3. 디렉터리 구성

```text
tools/automation/ (저장소 내 경로)
├── ProjectKnight.Launcher/       # C# WinForms 프로젝트 (.NET 8)
│   ├── ProjectKnight.Launcher.csproj
│   ├── Program.cs
│   ├── MainForm.cs
│   ├── Models/
│   │   ├── TaskCandidate.cs
│   │   ├── LauncherSettings.cs
│   │   └── ExecutionStage.cs
│   └── Services/
│       ├── TaskDiscoveryService.cs
│       ├── AutomationRunnerService.cs
│       └── DesktopShortcutService.cs
├── ProjectKnight.Launcher.Tests/ # 단위 테스트 프로젝트
├── launcher_winforms.ps1         # 네이티브 WinForms 스크립트 (SAC 대응 호스트)
├── runner.ps1                    # 개선된 Worktree 제어 및 Antigravity CLI 엔진
├── install_desktop_shortcut.ps1  # 바탕화면 바로가기 갱신 스크립트
├── config.json                   # 프로젝트/도구 설정
├── security_settings.json        # 최소 권한 원칙 도구 화이트리스트
└── README.md                     # 본 설명서

D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\ (로컬 런타임 경로)
├── ProjectKnight.Launcher.exe    # 빌드된 64비트 독립 실행형 EXE
├── launcher_winforms.ps1         # 런타임 WinForms 호스트
├── launcher_settings.json        # 사용자 설정 (자동 승인 ON/OFF 상태 저장)
├── runner.ps1                    # 개선된 실행 엔진
├── config.json                   # 프로젝트/도구 설정
├── security_settings.json        # 보안 정책
├── worktree\                     # 완전 격리된 Git Worktree
├── state\                        # 태스크 완료 상태 (tasks_state.json) 및 락
└── logs\                         # 실행 로그 및 결과 JSON
```

---

## 4. 빌드 및 테스트 방법

### 4.1. C# WinForms 빌드
```powershell
# 개발 빌드
dotnet build tools/automation/ProjectKnight.Launcher -c Release

# 독립 실행형 단일 EXE 배포 (Windows x64)
dotnet publish tools/automation/ProjectKnight.Launcher `
  -c Release -r win-x64 --self-contained -p:PublishSingleFile=true `
  -o D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\publish
```

### 4.2. 단위 테스트 실행
```powershell
# 테스트 프로젝트 빌드 및 실행
dotnet build tools/automation/ProjectKnight.Launcher.Tests
dotnet exec tools/automation/ProjectKnight.Launcher.Tests/bin/Debug/net8.0-windows/ProjectKnight.Launcher.Tests.dll
```

### 4.3. 바탕화면 바로가기 등록
```powershell
powershell -ExecutionPolicy Bypass -File tools/automation/install_desktop_shortcut.ps1
```

---

## 5. Windows 11 Smart App Control (SAC) 안내

- Windows 11의 Smart App Control(SAC)이 활성화된 환경에서는 코드 사이닝 인증서가 없는 로컬 컴파일 EXE 실행 시 `0x800711C7` 차단이 발생할 수 있습니다.
- 이를 위해 두 가지 실행 방식을 모두 제공합니다:
  1. **표준 바이너리:** `ProjectKnight.Launcher.exe` (바탕화면 「ProjectKnight 작업 실행」 바로가기)
  2. **SAC 호환 모드:** `launcher_winforms.ps1` (바탕화면 「ProjectKnight 작업 실행 (SAC 대응)」 바로가기 — Microsoft 서명된 PowerShell 런타임에서 동일한 WinForms UI를 네이티브 렌더링)
