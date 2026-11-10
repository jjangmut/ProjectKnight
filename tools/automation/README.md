# ProjectKnight 원클릭 개발 실행기 (One-Click Developer GUI)

## 1. 개요 (Overview)

Windows 바탕화면의 바로가기를 더블클릭한 후 **「GitHub 최신 작업 가져와 실행」** 버튼 한 번으로, GitHub에 등록된 미완료 작업지시서를 읽고 **격리된 Git Worktree**에서 Antigravity CLI로 개발·테스트·검증·커밋·Push를 수행하는 전용 GUI 프로그램입니다.

```text
[바탕화면 "ProjectKnight 작업 실행" 바로가기 더블클릭]
                      │
                      ▼
            [ProjectKnight Launcher GUI]
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
  ② 지시서 검증 (Validate)
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

1. **상주 프로세스 / 폴링 제로 (Zero Background Polling):**
   - 상주 백그라운드 서비스, Webhook, GitHub Actions Runner, 항상 실행되는 루프가 **전혀 없습니다**.
   - 사용자가 **버튼을 클릭했을 때만** 1회성으로 GitHub 원격 브랜치를 조회(`git fetch origin --prune`)합니다.
2. **원클릭 자동 승인 (Auto-Approve):**
   - 「자동 승인」 체크박스를 ON으로 설정하면, 버튼 클릭 1회에 한해 유효한 단일 작업을 추가 확인 팝업 없이 즉시 실행합니다.
   - 단, 미완료 작업이 여러 개 발견된 경우 사용자가 목록에서 대상을 명시적으로 선택해야 합니다.
3. **실시간 단계별 진행 표시 (Live Progress UI):**
   - 6단계 진행 상태(⏳ 대기, 🔄 진행중, ✅ 완료, ❌ 실패, ⏹ 중지)가 실시간으로 표시됩니다.
   - 시작 후 경과 시간(MM:SS)과 최근 로그 수신 시간이 실시간 갱신됩니다.
4. **논블로킹(Non-Blocking) 비동기 로그 스트리밍:**
   - GUI 메인 스레드와 실행 워커 스레드가 분리되어 있어 작업 중 창이 멈추지 않습니다.
   - Antigravity CLI 및 검증 엔진의 표준출력/표준에러가 1초 미만 간격으로 실시간 스크롤 갱신됩니다.
5. **독립 Worktree 완전 격리 (Workspace Protection):**
   - 메인 프로젝트 작업 폴더(`D:\JUNYPAPA_STUDIO\Projects\ProjectKnight`)에서는 어떠한 checkout이나 브랜치 전환도 일어나지 않습니다.
   - 모든 빌드 및 개발은 격리된 Worktree(`D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree`)에서만 수행됩니다.
   - 현재 진행 중인 V3-017 작업 등은 완벽히 보호되며 자동화 대상에서 제외됩니다.
6. **Pre-Commit Scope Gate 내장:**
   - 허가되지 않은 디렉터리 변조나 바이너리 파일 생성이 감지되면 커밋과 Push가 원천 차단됩니다.

---

## 3. 디렉터리 구성

```text
tools/automation/ (저장소 내 경로)
├── launcher.py               # Tkinter GUI 메인 프로그램
├── run_launcher.bat          # 더블클릭용 배치 실행기
├── run_launcher.vbs          # 콘솔창 없는 무음 실행기
├── install_desktop_shortcut.ps1 # 바탕화면 바로가기 등록 스크립트
└── README.md                 # 본 설명서

D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\ (로컬 런타임 경로)
├── launcher.py               # 런타임 GUI 프로그램
├── launcher_settings.json    # 사용자 설정 (자동 승인 ON/OFF 상태 저장)
├── runner.ps1                # Worktree 제어 및 Antigravity CLI 실행기
├── config.json               # 프로젝트/도구 설정
├── security_settings.json    # 최소 권한 원칙 도구 화이트리스트
├── worktree\                 # 완전 격리된 Git Worktree
├── state\                    # 태스크 완료 상태 (tasks_state.json) 및 락
└── logs\                     # 실행 로그 및 결과 JSON
```

---

## 4. 사용 방법

### 4.1. 바탕화면 바로가기로 실행
- 바탕화면의 **「ProjectKnight 작업 실행」** 아이콘을 더블클릭합니다.
- 만약 바로가기가 없다면:
  - `tools/automation/run_launcher.bat`을 실행하거나
  - GUI 우측 하단의 **[ 📌 바탕화면 바로가기 생성 ]** 버튼을 누릅니다.

### 4.2. 기본 작업 흐름
1. **「자동 승인」 설정:**
   - 수동 승인을 원하면 체크박스를 OFF(기본값)로 둡니다.
   - 즉시 원클릭 실행을 원하면 체크박스를 ON으로 설정합니다.
2. **버튼 클릭:**
   - **[ 🚀 GitHub 최신 작업 가져와 실행 ]** 버튼을 클릭합니다.
3. **진행 상황 모니터링:**
   - 6단계 상태 카드와 하단 실시간 콘솔 로그를 확인합니다.
4. **완료 및 결과 확인:**
   - 작업 완료 시 초록색 배너와 신규 커밋 SHA가 표시됩니다.
   - **[ 🌐 GitHub 커밋 보기 ]** 버튼을 눌러 GitHub 원격 변경 내용을 즉시 확인할 수 있습니다.
