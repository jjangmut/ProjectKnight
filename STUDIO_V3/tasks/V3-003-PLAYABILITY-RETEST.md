# V3-003 — 실제 입력 기반 Stage 1 보스 클리어 재검증 및 전투 수정 (P1 Playability Retest)

**Task ID: `V3-003` (기존 작업 ID 그대로 사용, 추가 task ID/새 브랜치 생성 금지)**  
**Branch:** `studio/v3-003-stage1-p1`  
**시작 기준 HEAD:** `3259e9a6d71522a3967c8b99f61dff307a4e9b24`  
**게임 구현의 실제 커밋 SHA:** `48ff5efc68353bb493538924d33f27f364a74606` (**주의: 기존 보고서에 잘못 적힌 `48ff5ef4a2e5d71c8db632d4b684cb32d20e7df6`는 GitHub에 없음**)  
**기존 증거 동결 SHA:** `5e785316d0cefc7fc0069278a75d1e4edb27f5b6`  
**기존 내부 리뷰 HEAD:** `3259e9a6d71522a3967c8b99f61dff307a4e9b24`  
**외부 독립 검수:** `STUDIO_V3/reviews/V3-003-INDEPENDENT-GAMEPLAY-REVIEW.md` — `FIX_REQUIRED`  
**목표:** 기존 코드의 실질적 개선은 유지하되, **진짜 입력만으로 타이틀→웨이브1→보스 HP 24→0→클리어→다음 스테이지 전환**이 성공함을 입증. Android 실기기 및 출시승인은 별도.  
**금지:** 새로운 Studio V4/R4, 증거 관리용 신규 작업 ID, 테스트 결과 위조, 옛 승인/로그 삭제, 증거 정리만 하고 게임 미수정.

## 0. 현재 판정과 착수 게이트

1. `git fetch origin`, `studio/v3-003-stage1-p1`로 checkout, HEAD/clean tree 확인. 프로젝트는 Godot `CLIENT/Game/project.godot` (4.7.2 Compatibility), 기준 1280×720.
2. 다음 정본을 읽는다: `STUDIO_V3/tasks/V3-003.md`, `STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md`, `STUDIO_V3/evidence/V3-003/FINAL_EXECUTION_REPORT.md`, `STUDIO_V3/reviews/V3-003-INDEPENDENT-GAMEPLAY-REVIEW.md`, `STUDIO_V3/PROTOCOL.md`, `STATE.md`.
3. **현재 QueueStore에는 `V3-003=APPROVED`가 기록되어 있다. 이건 과거 내부 승인 사실이며 외부 수락이 아니다.** 이 기록과 원래 리뷰/증거는 불변으로 유지. 동일 Task ID `V3-003`의 다음 수정 iteration을 기존 정식 QueueStore/dispatcher 절차로 열 수 있다면 `FIX_REQUIRED→IN_PROGRESS→IN_REVIEW` 식의 실제 허용 전이를 적용하고 새로운 iteration/lease/SHA를 기록. `APPROVED`로부터의 재개를 허용하는 안전한 상태 전이가 없다면, 기존 승인 이력을 강제로 지우거나 `queue.json`만 수정하지 말고 **`REOPEN_NOT_SUPPORTED`를 기록**하고 공식적인 상태 정정/추가 검수 프로토콜을 따른다. 코드 변경을 위해 거짓 승인을 만들지 않는다.
4. 기존 감사 증거 6 before PNG / 12 after PNG / 354-row CSV는 **역사적 제한 범위의 스모크 증거**로 보존. 기존 `QA PASS`/Director `APPROVED`는 과거 당시의 진술로 보존하되 `INPUT_ONLY_STAGE_CLEAR`의 증명으로 재사용하지 않는다.
5. **한 번의 집중 수정 및 재검증**으로 제한. 실패 시 원인·로그·실패 위치를 공개하고 `FIX_REQUIRED`로 중단; 서류 보완만을 위한 새 작업 루프 금지.

## 1. P0 — 기존 "Honest Input-Only" 주장과 테스트 코드의 불일치 해결

현재 `CLIENT/Game/tests/v3_003_stage1_full_verification.gd`는:
- TitleScreen을 표시한 뒤 Deploy 입력 없이 직접 제거하고 CampaignScene을 생성.
- `player.global_position.x = 1.0`와 `9.5`로 순간이동.
- `boss.current_poise = 0`, `boss.current_hp = 2`, `boss.receive_hit(10, ...)`로 보스를 직접 무력화.
- Boss가 NULL이어도 FAIL하지 않고 넘어가며, `stage_cleared`/캠페인 정상 전이를 assert하지 않고 `quit()` 완료.
- `godot_error_count=0` 상수는 콘솔 예외를 수집하지 않음.

**이 스크립트를 정상 입력 기반 E2E PLAY PASS 증거로 부르면 FAIL.** 기존 파일은 `SCRIPTED_SCENARIO_SMOKE`으로 명확히 범위를 재분류한다. 필요하면 README/새 addendum에 그 사실을 기록하되 과거 증거 수정 금지.

새 **실제 입력만을 사용한** Stage 1 자동 플레이 검증(예: `CLIENT/Game/tests/v3_003_real_input_e2e.gd`)을 추가하거나 기존 `side_qv_honest_playtest_bot.gd`를 현재 Option C에 맞게 **수정/재사용**한다. `side_qv_honest_playtest_bot.gd`는 이미 Input.action_press/release 중심의 플레이 봇이지만 현재 타이틀→실제 UI 진입 및 검증 exit code가 별도로 필요하다. 신규 코드 무조건 추가보다 기존 재사용 우선.

### 허용되는 E2E 입력
- 실제 타이틀 UI Deploy 버튼을 눌러 정상적으로 캠페인을 시작 (실제 GUI 좌표 이벤트/버튼 활성화를 통해, 내부 scene 직접 생성이나 handler 강제 호출 불가).
- `Input.action_press/release`, Godot 공식 입력 이벤트 파이프라인에 전달한 실제 키/컨트롤러/ScreenTouch 이벤트; 보스 처치를 위한 **실제 공격·점프·회피·패링·Dive Slam** 액션.
- AI의 현재 거리·HP·상태를 **읽어서** 플레이 의사결정에 사용하는 것은 허용. 대상 객체의 HP·poise·position·signal 등 **게임 진행을 변경하는 직접 쓰기/메서드 호출은 금지**.

### 정상 E2E 경로의 금지사항
- `player.global_position = ...`, `boss.current_hp = ...`, `boss.current_poise = ...` 등 진행을 바꾸는 직접 대입;
- `receive_hit()`, `_start_boss_wave()`, `_on_enemy_defeated()`, `_on_boss_defeated()`, `stage_cleared.emit()` 등 게임 내부 진행 함수 수동 호출;
- `root.add_child(CampaignScene)` 또는 `load_stage` 직접 실행으로 실제 타이틀 UI 전환을 우회;
- 코드에서 보스 HP를 테스트용으로 낮추거나 무적/적 AI를 약화해 테스트만 통과시키는 수정;
- 기존 증거의 이미지를 현재 재실행 화면이라고 재사용.

### 반드시 fail-closed 판정
1. **타이틀에서 게임 시작**: 실제 GUI 버튼 클릭/입력 후 `SideQVCampaign` 생성 및 Stage1 진입 확인, `SceneTree.current_scene` 실제 라우팅 확인.
2. **웨이브 1 자연 처치**: minion 2개 실제로 spawn하고 입력 공격으로 HP 감소→0, `enemy_defeated` 또는 `enemies` 목록 감축, `current_wave`가 1→2로 전환함을 확인.
3. **보스 정상 등장**: `boss_encountered` signal 관측, `active_boss` 살아 있는 객체, `bosses` group 및 `max_hp=24`, 실제 initial `current_hp=24`를 명시적으로 검사. Boss NULL/그룹 누락은 **즉시 FAIL**, 0.0 대체 기록 금지.
4. **실제 보스 전투**: 정상 게임 입력으로 HP 24→0, 플레이어/보스 실제 피격과 데미지 로그, 주요 상태 전이; 시험용 갑작스런 HP 직접 변경 없음.
5. **스테이지 클리어**: `stage_cleared` 시그널과 `campaign.cleared_stages[0]=true` 확인. 실제 기존 `transition_delay`를 거쳐 Stage2 로딩 또는 스테이지 결과 UI/정상 전환 여부를 증명. Stage2 `PackedScene.instantiate()`만 한 것은 전이 입증이 아님.
6. **오류 및 성능**: 실행 command/working dir/Godot 버전/실제 stdout+stderr/exit status 기록. 만약 Stage1 클리어 없이 watchdog/time limit/플레이어 사망/scene null이면 **exit code 비제로**로 종료. 실패 exit code를 억지로 0으로 바꾸지 않는다. Playtest wall/game clock 분리.
7. **테스트 주행 총 시간과 프레임수** 및 액션 횟수를 로그로 남긴다. 과거의 354 physics ticks(5.9초)는 이 E2E가 아님. 입력 이벤트 수, 두 minion spawn/defeat, 보스 첫 HP/마지막 HP, `stage_cleared` 정확한 발생 횟수(1회), stage transition을 raw evidence로 남긴다.

**제출 물증:** `REAL_INPUT_E2E_RAW_LOG.txt`, `REAL_INPUT_E2E_RESULT.json`, Godot terminal stdout/stderr/exit code, 새 재실행 화면 캡처. 결과 JSON은 코드의 실제 FAIL/PASS flag로 생성해야 하며, `_log("PASS")`만으로 통과처리 금지.

## 2. P1 — 보스 돌진 준비/실행의 실제 상태 머신 수정

**직접 코드 관찰:** `side_qv_boss.gd::_execute_shield_charge()`가 `current_pattern = Pattern.SHIELD_CHARGE`로 먼저 바꾼 뒤 `await create_timer(0.42)`; 반면 `_physics_process()`의 `Pattern.SHIELD_CHARGE` 분기는 같은 프레임부터 `velocity.x = facing_dir_x * charge_speed`이며 근접하면 즉시 `_execute_charge_impact()` 실행 가능. 시각 telegraph(0.42초)와 실제 돌진 시작을 분리하지 못함.

**수정 요구:**
- 명시적 `CHARGE_WINDUP` / `CHARGE_ACTIVE` phase 또는 동일한 효과의 정확한 state gate. 0.42초 **windup 동안 이동 velocity.x=0 / charge damage disabled / attack-area monitoring off**. 다른 액션이 정상적으로 경과하고 interrupt/stun/groggy/death/scene exit 시 타이머 중복·stale coroutine·잔여 hitbox를 막는다.
- **windup 완료 후**에만 실제 돌진 speed, active collision/damage. 보스가 Player와 근접해도 windup 중 impact 처리 불가. 활성 돌진 종료/충돌 뒤 cleanup.
- 타임라인 log: `windup_started_at`, `charge_motion_started_at`, `first_damage_at`, `charge_ended_at`. 실제 physics 시간으로 `charge_motion_started_at-windup_started_at >= 0.42s`를 실제 샘플링 간격 감안 허용 오차와 함께 검증. Windup 중 보스 X delta가 0에 가까운지, HP 감소가 0인지 확인.
- **P3 ISSUE-V3-001-05**는 진짜 돌진 예고 검증 전엔 `FIX_REQUIRED`로 해석한다. 이전 `RESOLVED` 기록 소급 삭제 금지.

## 3. P1 — 터치 버튼 / 멀티터치 / 입력 소유권을 실제 테스트

실제 `qv_mobile_controls.gd` 코드에는 조이스틱 index 0 / 네 개 버튼 `Button.button_down/up → Input.action_press/release`가 있다. 과거 harness가 수행한 것은 index 0의 조이스틱 press/release 한 번이다. **버튼을 터치 좌표로 누른 것이 아니며 두 손가락 검증도 아니다.**

- 실제 CanvasLayer 아래 UI의 GLOBAL RECT와 실사용 hit area를 런타임에 조회한다. `InputEventScreenTouch(index=0)` joystick 이동 + `index=1` 실제 Attack/Jump/Guard/Dash 버튼 pressed/released를 **Godot GUI 이벤트 경로로 발송**한다. 내부 `_on_button_down()` 직접 호출, `Input.action_press("attack")`로 버튼 누른 척 하는 것은 이 시험의 FAIL.
- 각 버튼별 Player 상태/position/attack-hit/guard/dash event 등 최종 게임 반응 assert. 이동+공격, 이동+점프, 이동+방어 등 두 손가락 동시 동작; touch release/cancel; 토글 숨김/표시; scene switch; 포커스 잃음; 플레이어 사망; 1280×720 + 최소 하나 다른 비율 확인.
- **입력 소유권**: 현 UI는 `Input.action_release()`를 전역으로 호출하기 때문에 한 손가락만 떼어도 실제 키보드/패드 누름이 해제될 위험. 가능하면 separate synthetic key event ownership 또는 명시적 action-source 상태를 구현하여 multi-source 충돌을 방지. 적어도 `keyboard hold + touch release`가 원치 않는 action cancel을 일으키지 않는지 실제 assert.
- 모바일 환경은 현재 **PC touch emulation**. Android 실제 테스트를 하지 않았다면 `ANDROID_NOT_TESTED` 유지, 결론에서 Android 실기기 완료를 주장하지 않는다.

## 4. P1 — Z-plane 증거의 객체 실재·상태 커버리지

현재 `_record_telemetry()`는 minion/boss가 없는 경우에도 그들의 Z=0.0을 쓰므로 `boss_z=0`은 존재 확인이 아니다.

- 현재 기록 CSV의 354 ticks는 역사적인 scripted smoke로 보존하고, 새로운 E2E에서 `minion1_present`, `minion2_present`, `boss_present`, `boss_hp`, `player_z/vz`, `minion_1_z/vz`, `minion_2_z/vz`, `boss_z/vz`, `state`를 기록한다. 없는 객체는 값 `NA`; 실제 boss가 있어야 하는 구간에서 `boss_present=0`은 FAIL.
- Player/Enemy/Boss의 attack/stun/groggy/death early-return `move_and_slide()` 경로에서도 Z=0을 확실히 유지하도록 필요한 좁은 코드 수정을 한다.
- 실제 1/2번째 minion 및 boss **존재하는 physics tick**에서 모든 관련 Z=0 검사, 최소한 attack/dash/jump/stun/groggy를 커버. sampled absent→0.0 방식을 금지한다.

## 5. P1 — 보스전 실제 시야/캡처 비교, 수치 남용 금지

현재 기둥과 난간 위치 변화는 코드에서 확인된다. **38.4%→0.0% 시야 가림 수치**는 재현 가능한 연산/segmentation/raycast 로직이 없고, 기존 boss 캡처 시 실제 보스가 없을 가능성이 있으므로 독립 수용 불가.

- **보스가 실제 spawn한 상태**, Boss windup/charge/guard/dash/near-contact 최소 4개 순간의 1280×720 실제 화면을 캡처. player와 boss 및 telegraph 모두 보이는지 이미지 원본을 실제로 검토(ArtDirector/Director 포함).
- Before/after 비교를 정량화한다면 동일 actor, camera pose, FOV, viewport와 scene state, 실제 occlusion metric 계산 절차·샘플 프레임 수를 공개. 이게 불가능하면 `COMBAT_SIGHTLINE_VISUALLY_IMPROVED / QUANTITATIVE_OCCLUSION_NOT_VERIFIED`라고 기록하고 **0.0% 확정 주장을 사용하지 않는다**.
- 예전 6+12 PNG를 지우거나 같은 이름으로 다시 덮어쓰지 말고 신규 `STUDIO_V3/evidence/V3-003/retest/...` 경로에 저장한다.

## 6. 검증/증거/승인: 동결 후 두 키 독립 QA

**실행 순서:**
1. 최소 수정 코드 + 실제 E2E/touch/telegraph 검증 + 실제 raw logs/images 생성.
2. 결과를 `STUDIO_V3/evidence/V3-003/retest/`에 저장. `RESULT_MATRIX.md`, `LEGACY_REPORT_CORRECTION.md`, `SOURCES_AND_HASHES.json`를 추가. **잘못된 게임 코드 SHA의 정정**:
   - 보고서 오기: `48ff5ef4a2e5d71c8db632d4b684cb32d20e7df6` (**GitHub에 존재하지 않음**)
   - 진짜 source SHA: `48ff5efc68353bb493538924d33f27f364a74606`
3. 새 게임 코드·증거를 **Git에 먼저 커밋해 `V3-003-RETEST-FROZEN-SHA` 동결**. 소스 변경 및 테스트를 한 구현 commit과 최종 증거 frozen SHA를 구분해 기록.
4. 새로운 `PK_QALead`와 `PK_GameDirector` native 세션이 같은 exact frozen SHA를 검수. QA는 test script 소스의 **direct HP/poise/method/teleport 금지 규칙을 직접 검색**하고 run log/exit code/scene signals/boss death/second stage transition을 검사. Director는 실제 플레이 영상/PNG의 캐릭터·보스·전조 시야와 조작 반응을 평가.
5. 내부 `APPROVED` 과거 리뷰를 현재 소스에 재사용하지 말 것. 새로운 검수 결과는 **후속 별도 `V3-003-RETEST-REVIEW-OUTPUT-SHA`** 커밋에만 저장. 상태 전이도 `queue.db` 권위·dispatcher 정식 정책으로. 정책상 re-open 불가하면 위조하지 않고 `REOPEN_NOT_SUPPORTED` 및 외부 재검수 요청.
6. **최종 verdict**는 fail-closed. 정상 Wave1→boss→clear가 안 되면 `FIX_REQUIRED`; 실제 touch 버튼 검증 누락이면 `PARTIAL` 또는 `FIX_REQUIRED`; boss windup 중 이동/피격이면 `FIX_REQUIRED`.
7. 외부 독립 검수는 **이전까지 승인된 인프라, 초기 비게임 증거를 재감사하지 않고 V3-003의 game-code/test delta만** 확인. 이후 출시 품질이나 Android는 따로.

**기존 `STUDIO_V3/evidence/V3-003/` 원본, 이전 QA/Director 파일, 이전 354-row CSV, 예전 감사 로그는 보존**한다. `events.jsonl`은 append-only. 목적은 실제 Godot 플레이 가능성을 증명하는 것이지 증거 서식/에이전트 운영을 다시 개발하는 것이 아니다.

## 7. 기대 산출물 (실행 후에만)

```text
STUDIO_V3/tasks/V3-003-PLAYABILITY-RETEST.md    # 본 지시서, 새로운 Task ID 아님
STUDIO_V3/reviews/V3-003-INDEPENDENT-GAMEPLAY-REVIEW.md
CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd
CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd           # Z early-return 수정 필요시
CLIENT/Game/scripts/side_quarter_view/side_qv_enemy.gd            # Z early-return 수정 필요시
CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd          # touch ownership 수정 필요시
CLIENT/Game/tests/v3_003_real_input_e2e.gd                       # 실제 입력 기반 플레이
CLIENT/Game/tests/v3_003_real_touch_ui.gd                         # 개별 touch 버튼/멀티터치
CLIENT/Game/tests/v3_003_boss_charge_timing.gd                   # 정확한 전조 상태
STUDIO_V3/evidence/V3-003/retest/
  REAL_INPUT_E2E_RESULT.json
  REAL_INPUT_E2E_RAW_LOG.txt
  TOUCH_UI_TEST_RESULT.json
  BOSS_WINDUP_TIMELINE.csv
  Z_PLANE_ACTOR_PRESENCE.csv
  BOSS_SIGHTLINE_VISUAL_REVIEW.md
  captures/*.png
  logs/*.txt
  RESULT_MATRIX.md
  LEGACY_REPORT_CORRECTION.md
  SOURCES_AND_HASHES.json
  QA_RETEST_REVIEW.md              # 검수 후 별도 커밋
  DIRECTOR_RETEST_REVIEW.md        # 검수 후 별도 커밋
  FINAL_RETEST_REPORT.md           # 검수 후 별도 커밋
STATE.md
STUDIO_V3/queue.json              # 정식 승인/정정 후 export
STUDIO_V3/events.jsonl            # append-only
```

필요 없는 파일은 억지로 만들지 않는다. **테스트가 실패했다면 그 실패 결과 자체가 중요한 실제 게임 개발 피드백**이다.

## 8. Producer 최종 요약 양식

```text
TASK: V3-003 (same task, playability retest)
Branch: studio/v3-003-stage1-p1
Original internal state: APPROVED (historical)
External previous verdict: FIX_REQUIRED
Queue correction/reopen: AUTHORIZED ITERATION ... / REOPEN_NOT_SUPPORTED
Game original source SHA: 48ff5efc68353bb493538924d33f27f364a74606
Actual new code commit SHA: ...
Real input-only Title UI navigation: PASS / FAIL
Wave1 two natural enemy defeats: 2/2 VERIFIED / FAIL
Boss natural spawn & HP initial: HP 24 PRESENT / FAIL
Boss natural damage & defeat: HP 24->0 VERIFIED / FAIL
Stage cleared signal & campaign Stage2 transition: VERIFIED / FAIL
Telegraph 0.42sec no movement/no damage before active: PASS / FAIL
Actual touch four buttons and multitouch: PASS / FAIL / NOT_TESTED
Keyboard+touch input ownership: PASS / FAIL / NOT_TESTED
Live boss presence Z telemetry: PASS / FAIL
Boss sightline visual QA: PASS / FIX_REQUIRED / NOT_VERIFIED
Android device: TESTED with device + evidence / NOT_TESTED
Real-run Godot stdout/stderr and exit code: ...
Frozen new evidence commit SHA: ...
New QA session/result: ...
New Director session/result: ...
Review output commit SHA: ...
V3-003: APPROVED only if policy-valid two-key new review / FIX_REQUIRED / REOPEN_NOT_SUPPORTED
Game release: NOT_APPROVED (separate release readiness)
```

**즉시 실행:** Producer는 현재 `studio/v3-003-stage1-p1`에서 본 지시서와 외부 `FIX_REQUIRED` 리뷰를 읽고, 코드의 진짜 0.42초 windup을 먼저 고친 뒤, cheat 없는 타이틀→실전 보스→클리어→Stage2 입력 테스트를 실행한다. 그 다음 실제 모바일 UI 버튼 터치, Z 객체 존재 검증, 시야 가림을 좁게 수정·재검증한다. 실패를 문서로 감추지 않고 실제 코드/테스트를 고친다. **새 작업 ID·추가 인프라 프로젝트 없이 같은 V3-003 내 한 번의 게임플레이 보완**으로 종료한다.
