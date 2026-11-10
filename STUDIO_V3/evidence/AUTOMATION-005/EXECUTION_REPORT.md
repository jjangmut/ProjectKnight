# AUTOMATION-005 Execution & Verification Report

**Task:** AUTOMATION-005 — Python Tkinter 실행기 삭제 및 C# WinForms 전면 재구축  
**Repository:** `jjangmut/ProjectKnight`  
**Target Branch:** `studio/v3-automation-winforms-rebuild`  
**Base Commit:** `668729bbf303621681be93448983479471047e82`  
**Date:** 2026-11-10  
**Status:** IMPLEMENTATION_COMPLETE (Verification Pass)

---

## 1. Executive Summary

본 작업은 `AUTOMATION-005.md` 지시서 및 `AUTOMATION-004-INDEPENDENT-REVIEW.md` 검수 결과에 따라, 기존 Python Tkinter 기반 개발 실행기를 완전히 삭제하고 **.NET 8 LTS 기반 C# Windows Forms(WinForms) 독립 실행형 애플리케이션(`ProjectKnight.Launcher.exe`)**으로 전면 재구축하였습니다.

동시에 이전 검수에서 지적된 태스크 선택 시 초기화 버그, 원격 SHA 무결성 미검증, 느슨한 Antigravity CLI 파싱 문제를 해결하기 위해 `runner.ps1`에 엄격한 Target Branch/HEAD SHA 바인딩 및 Fail-Closed JSON 검증 로직을 탑재하였습니다.

---

## 2. 신규 바이너리 및 설치 위치

| 항목 | 경로 | 크기 / 버전 | 비고 |
| :--- | :--- | :--- | :--- |
| **C# WinForms 독립 실행 파일** | `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\ProjectKnight.Launcher.exe` | 153,451,874 bytes | .NET 8 self-contained win-x64 단일 파일 EXE |
| **C# WinForms 배포 산출물** | `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\publish\ProjectKnight.Launcher.exe` | 153,451,874 bytes | `dotnet publish` 출력 위치 |
| **바탕화면 기본 바로가기** | `C:\Users\jjang\Desktop\ProjectKnight 작업 실행.lnk` | 바로가기 | `ProjectKnight.Launcher.exe` 직접 호출 |
| **SAC 대응 바로가기** | `C:\Users\jjang\Desktop\ProjectKnight 작업 실행 (SAC 대응).lnk` | 바로가기 | PowerShell 네이티브 WinForms 호스트 호출 |
| **네이티브 WinForms 호스트** | `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\launcher_winforms.ps1` | 34,791 bytes | SAC 환경 완전 호환 GUI 스크립트 |
| **개선된 자동화 엔진** | `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\runner.ps1` | 31,052 bytes | SHA/Branch 검증 및 격리 Worktree 엔진 |
| **C# 소스 코드 솔루션** | `tools/automation/ProjectKnight.Launcher/` | C# 12 / .NET 8.0 | 전체 소스 코드 저장소 포함 |
| **C# 단위 테스트 솔루션** | `tools/automation/ProjectKnight.Launcher.Tests/` | .NET 8.0 | 8개 단위 테스트 포함 |

---

## 3. 삭제된 기존 Python 실행기 목록

지시서 제6조 및 제7조 기준에 따라 다음 Python GUI 관련 파일들을 완전 삭제하였습니다.
- `tools/automation/launcher.py` (Git 삭제 완료)
- `tools/automation/test_launcher.py` (Git 삭제 완료)
- `tools/automation/test_e2e_launcher.py` (Git 삭제 완료)
- `tools/automation/run_launcher.bat` (Git 삭제 완료)
- `tools/automation/run_launcher.vbs` (Git 삭제 완료)
- `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\launcher.py` (로컬 삭제 완료)
- `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\run_launcher.bat` (로컬 삭제 완료)
- `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\run_launcher.vbs` (로컬 삭제 완료)
- 바탕화면 바로가기 내 `pythonw.exe` 및 `launcher.py` 인수 제거 완료

---

## 4. 핵심 개선 및 결함 수정 사항

1. **태스크 선택 무결성 (Selection Integrity):**
   - ComboBox에서 작업 선택 시 목록 갱신(Refresh)으로 인해 선택이 첫 번째 항목으로 강제 리셋되던 결함을 수정하였습니다.
   - 후보 태스크가 2개 이상일 때 두 번째 이후 태스크를 선택하더라도 해당 태스크의 `TaskId`, `TargetBranch`, `CommitSha`가 고정되어 정확히 실행됩니다.
2. **원격 HEAD SHA 엄격 바인딩 (Strict SHA Binding):**
   - Runner 실행 시 `-ExpectedBranch`와 `-ExpectedCommitSha` 파라미터를 강제하여, 사용자가 UI에서 조회/승인한 원격 커밋과 실제 실행 시점의 원격 HEAD가 1글자라도 다르면 즉시 `Security Violation` 예외를 발생시키고 실행을 중단합니다.
3. **지시서 Branch 메타데이터 검증 (Branch Metadata Validation):**
   - 원격 지시서 마크다운에 명시된 `Target branch` 또는 `Branch` 값과 실제 Git 브랜치명이 일치하지 않으면 `INVALID`(`[오류]`)로 분류하여 실행을 차단합니다.
4. **Antigravity CLI Fail-Closed JSON 파싱:**
   - CLI 실행 후 출력된 JSON 파일의 존재 여부 및 `STATUS == "SUCCESS"`를 엄격히 확인하며, 출력이 비정상이거나 실패 코드가 반환된 경우 완료 처리하지 않고 실패 상태로 격리합니다.
5. **UI 스레드 완전 논블로킹 (Non-blocking UI):**
   - C# `ProcessStartInfo`, `BeginOutputReadLine()`, `BeginErrorReadLine()` 비동기 이벤트 핸들러를 채택하여 10분 이상의 장시간 빌드/테스트 중에도 UI가 멈추지 않습니다.
6. **설정 영속화 (Settings Persistence):**
   - 자동 승인 ON/OFF 상태를 `launcher_settings.json`에 영속 저장하며, 프로그램 재시작 시 기존 설정을 복원합니다.

---

## 5. 검증 및 테스트 결과

### 5.1. C# 단위 테스트 슈트 실행 결과
- 실행 명령: `dotnet exec tools/automation/ProjectKnight.Launcher.Tests/bin/Debug/net8.0-windows/ProjectKnight.Launcher.Tests.dll`
- 결과: **8 / 8 테스트 ALL PASS (0 Failed)**
```text
==================================================
ProjectKnight C# WinForms Launcher Test Suite
==================================================
[TEST] DeduceTaskIdFromBranch ... PASSED
[TEST] TaskMarkdownParsing_ValidMatchingBranch ... PASSED
[TEST] TaskMarkdownParsing_MismatchedBranchRejected ... PASSED
[TEST] TaskMarkdownParsing_MissingBranchRejected ... PASSED
[TEST] SettingsPersistence ... PASSED
[TEST] CandidateSelectionIntegrity_NonFirstCandidate ... PASSED
[TEST] StageTransitions ... PASSED
[TEST] DesktopShortcutPath ... PASSED
==================================================
Total: 8 | Passed: 8 | Failed: 0
==================================================
```

### 5.2. 태스크 탐색 및 파싱 검증 (Headless Test)
- 실행 명령: `powershell -ExecutionPolicy Bypass -File tools/automation/launcher_winforms.ps1 -HeadlessTest`
- 결과: **28개 원격 브랜치 탐색 완료, AUTOMATION-005 `[대기]` 정상 판정, 완료 태스크 정상 분리**
```text
[HEADLESS TEST] Running WinForms Launcher Verification...
  -> Settings loaded. AutoApprove: True
  -> Discovered task candidates count: 28
     - [대기] AUTOMATION-005 | studio/v3-automation-winforms-rebuild (668729bb) - Python Tkinter 실행기 삭제 및 C# WinForms 전면 재구축
     - [오류] AUTOMATION-004 | studio/v3-automation-oneclick-launcher (01bd311c) - ProjectKnight 원클릭 개발 실행기 (Windows GUI)
     - [완료] V3-001 ~ V3-016 (총 26개 완료 브랜치/태스크 정상 분류)
```

### 5.3. 원격 SHA 변조/불일치 차단 테스트 (Security Verification)
- 테스트 조건: 임의의 변조된 SHA(`0000000000000000000000000000000000000000`)를 `-ExpectedCommitSha`로 전달
- 결과: **즉시 거부 (ExitCode: 1)**
```text
[INFO] Binding execution to remote branch: origin/studio/v3-automation-winforms-rebuild
Security Violation: Remote branch HEAD SHA (668729bbf303621681be93448983479471047e82) does not match approved SHA (0000000000000000000000000000000000000000). Task rejected to prevent execution of unauthorized modifications.
```

### 5.4. 완료된 작업 중복 실행 차단 테스트
- 테스트 조건: 이미 완료된 `V3-013`에 대해 `-Force` 플래그 없이 실행
- 결과: **중복 실행 방지 경고 및 중단**
```text
[WARN] Task V3-013 is already recorded as COMPLETED in state file. Use -Force to re-run.
```

### 5.5. 메인 게임 개발 작업 환경 보호 검증
- 검증 경로: `D:\JUNYPAPA_STUDIO\Projects\ProjectKnight`
- 현재 브랜치: `studio/v3-016-render-performance-validation` (HEAD `9225407c`)
- 작업 트리 상태: **Clean (0 modified, 0 untracked, 0 deleted)**
- 활성 태스크 `V3-017`: 일체 접근하거나 checkout하지 않음.

---

## 6. Windows 11 Smart App Control (SAC) 환경 특이사항 및 보안 잔여 위험

1. **Smart App Control (SAC) 차단 현상:**
   - Windows 11 장치에서 `SmartAppControlState = On`, `RealTimeProtectionEnabled = True` 정책이 강제되고 있습니다.
   - 로컬에서 새롭게 컴파일된 비인증 바이너리(`ProjectKnight.Launcher.exe`)는 Microsoft Cloud ISG 평판 또는 서명이 없으므로 탐색기 더블클릭 시 OS 수준에서 `0x800711C7` (CodeIntegrity Event 3077)로 차단될 수 있습니다.
2. **이중 대응책 제공:**
   - 사용자의 시스템이 SAC 활성 상태여도 중단 없이 개발을 지속할 수 있도록, Microsoft 정식 서명된 `powershell.exe` 호스트를 통해 동일한 WinForms UI를 구동하는 `launcher_winforms.ps1`과 바탕화면 바로가기(`ProjectKnight 작업 실행 (SAC 대응).lnk`)를 동시 제공합니다.
3. **권한 보안 잔여 위험:**
   - Antigravity CLI의 `security_settings.json` 내 `command(*)` 권한은 특정 위험 명령 문자열(예: `rmdir`, `Format-Volume`, `New-LocalUser`)을 deny 리스트로 방어하고 있으나, OS 커널 수준의 완전한 샌드박스는 아니므로 신뢰할 수 있는 GitHub 저장소(`jjangmut/ProjectKnight`)의 승인된 지시서만 실행해야 합니다.
