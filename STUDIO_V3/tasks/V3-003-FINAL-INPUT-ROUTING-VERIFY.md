# V3-003 — Final Real Input-Path Verification & Stage 1 Exit Gate

**Task ID:** `V3-003` (기존 유지, **신규 Task ID/새 개발 브랜치 생성 금지**)  
**Branch:** `studio/v3-003-stage1-p1`  
**Instruction base HEAD:** `68c879ce996f5744d0826114af0114de10e3432d` (등록 시점; 시작 전 `git fetch`로 최신 확인)  
**Existing implementation:** `c2a20feff22420f5bf68b74b6bc8dc7a56fa5c30`  
**Existing frozen evidence:** `8537510214580ffcf14e4c554d07ad9a1afb5fd3`  
**Existing internal QA/Director documents:** `cdd07cf5c69933398fdec2a0ecef32d2982e3aee` 이후  
**External audit:** `STUDIO_V3/reviews/V3-003-RETEST-EXTERNAL-INDEPENDENT-REVIEW.md` — FIX_REQUIRED (actual input routing / claims)  
**Goal:** 실제 Godot 입력/GUI 경로 검증을 **한 번에** 수정·실행하고 V3-003 Stage 1 게임플레이 외부 수락 범위를 정확히 정리한다.  
**Non-goals:** V3-002/R4 감사 재개, 새 Studio agent framework, Stage 2 구현, 상용 출시 승인, Android 실기기 검증 추정.

## 0. 시작 및 이력 보호

1. 브랜치 checkout, `git status --short`, `git rev-parse HEAD`, Godot 4.7.2 / `CLIENT/Game/project.godot` 확인. 읽을 문서:
   - `STUDIO_V3/tasks/V3-003-PLAYABILITY-RETEST.md`
   - `STUDIO_V3/reviews/V3-003-RETEST-EXTERNAL-INDEPENDENT-REVIEW.md`
   - `STUDIO_V3/evidence/V3-003/retest/REAL_INPUT_E2E_RAW_LOG.txt`, `RESULT_MATRIX.md`, `FINAL_RETEST_REPORT.md`
   - `STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md`
2. 현재 GitHub `V3-003`은 **과거 iteration=1 APPROVED**, `current_commit_sha=5e785316...`; 신규 retest 리뷰 세션 `8f29844e...` / `ddeb78fa...`는 **별도 보고서로 존재**하지만 그 자체가 승인 게이트에 재등록된 iteration 2는 아님. 신규 리뷰가 과거 `queue.json`의 두 키를 대체했다고 주장하지 않는다.
3. 승인 완료된 과거 이벤트, 보고서, 6 PNG, CSV, 테스트 로그는 **불변**. 외부 검수의 FIX_REQUIRED는 *검증방법·결론 범위* 문제이지 이미 수정된 0.42초 돌진/Option C 코드를 전면 반려한 것은 아님.
4. 공식 SQLite/TaskDispatcher가 APPROVED의 재오픈을 지원하지 않으면 상태를 강제로 FIX_REQUIRED/APPROVED로 수기 변경하지 말고 **`REOPEN_NOT_SUPPORTED`**로 명시한다. 동일 기존 V3-003의 **새 입력검증 addendum**과 **소스 SHA를 묶은 독립 재검수**를 통해 외부 검수받는 것은 허용하되, 이것을 새 공식 queue iteration 승인이라고 속이지 않는다.
5. 실제 게임 UI/테스트 소스에 필요한 변경만. Test-support helper는 최소화, 불필요한 전투 AI/카메라/art/agent 코드 변경 금지. **한 번의 집중 구현·실행·검수**로 끝낸다.

## 1. Gate A — 타이틀 버튼을 진짜 Godot GUI 이벤트로 클릭

**현재 확인된 위반:**
`CLIENT/Game/tests/v3_003_real_input_e2e.gd` phase 0:
```gdscript
btn.pressed.emit()
```
이는 signal을 강제 발생시키므로 **실제 UI click 검증이 아니다**.

**수정:**
1. 기존 정상 TitleScreen 표시/Stage1→Boss→Stage2 input-only 전투 봇을 유지한다. `_initialize()`에서 title instance를 직접 scene root에 추가해 bootstrap하는 것은 fixture setup으로 별도 표시할 수 있으나 **메뉴에서 Campaign을 직접 instantiate하거나 버튼 signal을 직접 emit하여 이동하는 것은 금지**.
2. 배치 완료된 `btn_new_game.get_global_rect().get_center()`에서 진짜 `InputEventMouseButton` press+release 또는 `InputEventScreenTouch` 이벤트를 생성하고, **`Input.parse_input_event()` 또는 정확히 확인한 `Viewport.push_input()`**를 통해 Godot viewport/GUI 경로로 보낸다. `button.pressed.emit()`, `button.emit_signal()`, `_on_new_game_pressed()`, `button._gui_input()` 직접 호출 금지.
3. 실제 버튼 `pressed` signal에 **관찰 전용** 검수 callback 연결, 사용자가 만든 이벤트가 버튼 hit-test를 통과해 signal을 **정확히 한 번** 발생시키고, `SideQVCampaign` 실제 scene entry까지 연결되는지 assert한다. GUI 클릭 전에는 count=0, 클릭 후 count=1. 실제 viewport visibility/disabled/mouse_filter/state 확인.
4. 실제 `stage_cleared` signal: `side_qv_stage_base.gd`는 `signal stage_cleared`를 정의하고 완료 시 emit하며 `side_qv_campaign.gd`가 이를 구독한다. 플레이테스트도 Stage1 인스턴스의 `stage_cleared.connect()`에 **별도 관찰 callback**을 연결해 count=1을 assert. 기존의 `campaign.cleared_stages[0]` 조회만으로 “signal을 직접 수신했다”고 주장하지 않는다. Stage2 `current_stage_index==1` 및 실제 instance 정상 진입은 유지.
5. **보스 패링 중 직접 facing 변경도 제거:**
```gdscript
player.facing_dir_x = 1.0
player.facing_dir_x = -1.0
```
   방향 전환은 실제 `move_left`/`move_right` input으로 수행하고, player state를 **읽어** 방향 확인 후 `guard` 처리한다. `player.facing_dir_x`, actor position/HP/poise, enemy death/clear functions 직접 변경 금지. 이벤트를 보낸 뒤 실제 game state 관찰. 이전에 얻은 boss HP24→0, 두 minion 자연 defeat, Stage2 flow를 재실행한다.
6. E2E의 read-only 자동 검증(코드 검사)은 direct `pressed.emit()`, `_on_new_game_pressed()` 직접 호출, `facing_dir_x =` direct assignment, actor HP/poise mutation, actor teleport, `receive_hit()` direct injection을 **E2E 파일 내부에서 FAIL** 처리. 단, 별도 isolated boss timing fixture의 `_execute_shield_charge()` 호출은 E2E cheat와 혼동하지 않는다.

**PASS:** actual viewport GUI click counter=1, actual Stage1 signal counter=1, natural boss defeat and Stage2 transition, fail-closed exit code 0. 이벤트 미전달/화면 미표시/버튼 클릭 실패 시 exit code≠0과 원본 로그 보존.

## 2. Gate B — 모바일 UI 전체 엔진 입력 경로 + 다중 입력 소유권

**현재 확인된 우회:**
`CLIENT/Game/tests/v3_003_real_touch_ui.gd::_send_touch()`에서
```gdscript
hud._input(ev)
```
으로 스크립트 핸들러를 직접 호출한다. 이는 기존 컴포넌트 테스트로서는 유효하나 **실제 GUI/viewport event route 검증은 아님**.

1. 테스트는 현재 production `qv_mobile_controls.gd`의 실제 HUD tree와 player가 동작하는 1280×720 viewport/window에서 실행. `InputEventScreenTouch(index=0/1, pressed, position)`와 drag를 `Input.parse_input_event()` 또는 `Viewport.push_input()`으로 발송한다. `hud._input(ev)`, `btn.button_down.emit()`, `_press_virtual_action()` 직접 호출은 E2E touch test에서 **금지**. 기존 direct-handler smoke가 필요하면 별도 범위로만 명시.
2. **Strike/Leap/Parry/Dash** 각각 실제 UI rectangle center에 터치 press/release → 해당 `Player`의 `ATTACK`, jump velocity/airborne, guard/visible barrier, dash state를 assert. UI에 `Button.button_down/up` signals와 `CanvasLayer._input` 동시 처리 경로가 있는 만큼 **중복 action_press/release 또는 두 번 공격하는 오류**도 관찰. Event propagation/consumed-input behavior를 trace로 남긴다.
3. Two-finger index 0 joystick + index 1 attack / jump / guard; release order 0→1 및 1→0; canceled/focus lost/scene switch/controls hidden; stuck actions=0. 화면 1280×720 및 적어도 다른 가로 비율 1개에서 실제 get_global_rect()이 safe-area 내에 있고 터치가 맞는지 확인.
4. **현 `keyboard_hold_touch_release_ownership` step은 잘못된 false PASS:** 현재 `Input.action_press("move_left")`→touch press/release→**자기 손으로 `Input.action_release("move_left")`**→무조건 `results[...] = true`. 다음처럼 고친다.
   - 실제 keyboard `InputEventKey`를 engine route로 보내거나, 장치가 정말 keydown인지 `Input.is_physical_key_pressed`로 확인한 **manual hardware key hold**를 사용한다.
   - Touch release **직후**, keyboard keyup **전**에 `Input.is_action_pressed("move_left")`가 여전히 true인지 assert하고 당시 event-source state를 로그로 기록한다.
   - 그런 다음 실제 keyup, touch release 후 전체 action cleared assert. **Simulated `Input.action_press`만으로 하드웨어 키를 눌렀다고 증명하지 말 것.** Godot injected key가 실제 physical hardware state를 반영하지 않는다면 `SIMULATED_KEY_ROUTE_ONLY`라고 제한하고, real hardware hold test를 별도 실제 수동 검증하거나 `PHYSICAL_HARDWARE_OWNERSHIP_NOT_VERIFIED`로 기록한다.
5. 필요시 `qv_mobile_controls.gd`만 좁게 수정해 keyboard/touch press ownership 및 duplicate GUI routing 회피. 한 손가락 touch release가 다른 손가락의 같은 action 또는 keyboard hold를 해제하지 않는 상태 관리가 필요하다. 키보드+터치 혼합과 scene exit에서 stuck action이 없을 것.
6. Android hardware는 실제 Android 기기 실행 없는 한 **`NOT_TESTED`**.

**PASS:** 실제 engine-routed 4개 버튼, 2 index multitouch + release safety, keyboard hold assertion **또는 정직한 분리된 한계 판정**, raw log & exit code. `_input` 직접 호출 결과를 GUI 통과 PASS로 세탁하면 FAIL.

## 3. Gate C — 실행 증거/원본 로그/화면 캡처 신뢰도

1. Godot 4.7.2 Compatibility의 창 모드 1280×720 실행, **실제 Godot binary 명령/절대 프로젝트 경로(민감정보 마스킹 가능), 전체 stdout, stderr, shell exit code**를 저장. `REAL_INPUT_E2E_RAW_LOG.txt`는 현재 테스트 스크립트의 `_log()` 결과일 뿐 OS shell stdout 전체가 아니다.
2. `SceneTree`/scene UI 전환 시 스크린샷은 `RenderingServer.frame_post_draw` 또는 엔진에서 확인된 실제 draw completion 이후 `Viewport.get_texture().get_image()`로 저장. UI/보스/Stage2 캡처는 **최종 frame timestamp, active scene ID, player/boss visibility**를 manifest에 기록. 이미 존재하는 PNG는 보존하고 **새 `STUDIO_V3/evidence/V3-003/final-input/` 경로**를 사용.
3. 보스 HP 값은 이전 CSV에서 **24→22→20→16→14→12→6→3, 이후 객체 소멸**까지 확인되었다. 새 E2E에서 실제 `boss_defeated` signal callback 1회, live boss HP 24부터 사망 시 0 이하 확인(객체 삭제 전), Stage1 clear signal callback 1회, Stage2 scene instance/transition을 모두 기록한다. Boss가 사라진 사실만으로 HP0을 주장하지 않음.
4. standalone `v3_003_boss_charge_timing.gd`는 **isolated scenario fixture**라고 라벨링; 이미 코드/CSV가 일치하므로 기본적으로 재작업 금지. 추가 문제가 없으면 Z-plane/보스 예고 수치 0.4333초 등을 다시 측정하려고 이 작업 범위를 늘리지 않는다.
5. E2E/TUI 결과가 실패하면 새 PASS JSON을 작성하거나 기존 올바른 파일을 덮어쓰지 않는다. 실패 원인·엔진 raw errors·exit status를 그대로 남기고 한 번의 좁은 수정만 진행한다.
6. PNG 픽셀을 검사할 수 있는 실제 ArtDirector/Director는 최종 새 screenshot의 내용(2D actor silhouette, touch actions, Stage2 scene) **눈으로 확인**해야 한다. 파일명/파일크기/9.24 점수만으로 무조건 시각적 승인 금지.

## 4. 단일 변경·검수·외부 게이트

1. 새 구현/테스트/실행 증거를 commit하고 **`V3-003-FINAL-INPUT-FROZEN-SHA`** 동결. 최소 변경 대상:
```text
CLIENT/Game/tests/v3_003_real_input_e2e.gd
CLIENT/Game/tests/v3_003_real_touch_ui.gd
CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd   # 필요할 때만
STUDIO_V3/evidence/V3-003/final-input/
  ACTUAL_GUI_INPUT_E2E_RESULT.json
  ACTUAL_GUI_INPUT_E2E_LOG.txt
  TOUCH_EVENT_ROUTE_RESULT.json
  TOUCH_EVENT_ROUTE_LOG.txt
  SHELL_COMMANDS_STDOUT_STDERR_EXIT.txt
  CAPTURE_MANIFEST.json
  captures/*.png
  RESULT_AND_LIMITATIONS.md
```
2. 새로운 독립 `PK_QALead`와 `PK_GameDirector`가 **동일한 동결 SHA를 각각 검수**하도록 실제 Antigravity-native session 실행. QA는 특히 `pressed.emit`, `player.facing_dir_x=`, `hud._input`, keyboard ownership 무조건 PASS를 source grep / runtime assertion으로 반려한다. Director는 실사용 터치/보스 화면과 게임 진행 결과, Android `NOT_TESTED`를 확인한다.
3. 검수 완료 후 새 QA/Director 결과, 해당 세션 ID, source SHA/실행 명령 및 실제 log의 서명 가능한 출처를 **후속 `V3-003-FINAL-INPUT-REVIEW-SHA`** 커밋에 저장. **미래 리뷰 파일을 동결 source에 포함했다고 주장 금지**.
4. **기존 queue V3-003=APPROVED iteration 1은 과거 이력으로 보존.** 공식 정책이 reopen 지원하지 않으면 `REOPEN_NOT_SUPPORTED` + 새 리뷰 addendum을 분명히 표기. queue에서 APPROVED와 검수 SHA `5e785316...`이 유지되는데 새 `V3-003` 코드까지 “새 iteration2 QueueStore APPROVED”라고 거짓 선언 금지.
5. 모든 GATE A/B/C 충족하면 V3-003 **외부 delta-only 재검수 요청**. 미충족이면 **`FIX_REQUIRED / NOT_VERIFIED`**와 정확한 잔여 범위를 보고하고 작업 종료. 무한 검수 루프·새 작업/브랜치 생성 금지.
6. 이 작업은 Stage 1 **실행/입력 품질 게이트**이지 게임 상용 출시 승인 아님. V3-004 준비는 가능하나 Stage1 전체 GUI/터치 path 실증을 넘겨짚어 Stage2를 `READY`로 정당화하지 않는다.

## 5. 최종 결과 보고 포맷

```text
TASK: V3-003 (same ID, Final Real Input Path)
Branch: studio/v3-003-stage1-p1
Original internal queue: APPROVED / iteration 1 / reviewed 5e785316...
Reopen: FORMALLY_AUTHORIZED / REOPEN_NOT_SUPPORTED
Starting implementation SHA: c2a20feff22420f5bf68b74b6bc8dc7a56fa5c30
New code/test commit SHA: ...
Frozen actual GUI evidence SHA: ...
Real Title Button Event: PASS / FAIL / NOT_VERIFIED
btn_new_game pressed callback count: 1 / other...
No direct facing/HP/position/signal cheat in real-input E2E: PASS / FAIL
Natural Wave1: 2/2 verified / FAIL
Boss spawn HP24 & natural defeat signal: PASS / FAIL
Stage1 stage_cleared signal count: 1 / other...
Campaign Stage2 actual scene: PASS / FAIL
Engine-routed Strike, Leap, Parry, Dash: 4/4 / N/4
Engine-routed two-touch concurrent & release: PASS / FAIL
Keyboard+touch ownership: PHYSICAL_VERIFIED / SIMULATED_ONLY / NOT_VERIFIED
New screenshot pixels reviewed: YES / NO
Raw Godot stdout/stderr and true shell exit: SAVED / MISSING
New QA native session / verdict: ...
New Director native session / verdict: ...
Review output commit SHA: ...
External V3-003 gameplay acceptance: REQUESTED / FIX_REQUIRED
Android actual device: NOT_TESTED
Game commercial release: NOT_APPROVED
```

**최종 명령:** 기존 `V3-003` 브랜치에서 **1회 제한된 실제 GUI 입력 경로 수정**을 즉시 수행한다. Test source에서 `btn.pressed.emit()`, 직접 `facing_dir_x` 대입, `hud._input(ev)`, 검증 없이 ownership PASS를 먼저 제거한다. 실제 Godot viewport에 이벤트를 전달하고 Title→2 minions→Boss→Stage2 및 4 button+multitouch를 fail-closed 실행한다. 새 raw stdout/stderr/exit/captures를 동결 후 정확히 2명 신규 QA/Director가 독립 검수한다. 통과 시 외부 delta-only 승인을 요청하고 Stage2 개발로 전환한다. **새 작업 ID/시스템 재구축/무한 감사 루프 금지.**
