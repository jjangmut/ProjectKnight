# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-001
제목: Project Knight Godot 프로토타입 기반 환경 구축
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): 클라이언트 리드(Client Lead)
작업자(Worker): 클라이언트(Client)

## 목적

첫 플레이어블 프로토타입을 구현하기 전에 Godot 프로젝트의 최소 실행 기반과 입력 계약을 준비한다.

## 작업 내용

- Godot 4.7.2 stable Standard와 GDScript 기준의 프로젝트 설정을 구성한다.
- 최소 Main Scene과 프로젝트 폴더를 만든다.
- 개발용 키보드 Input Map을 정의한다.
- Godot 생성 Cache를 Git 관리 대상에서 제외한다.

## 작업 범위

- `CLIENT/Game` Godot 프로젝트 Root
- Compatibility 렌더러
- `PrototypeMain.tscn` Main Scene
- 이동, 점프, 공격, 회피 Input Map
- 최소 폴더와 Git Ignore 설정

## 제외 범위

- 플레이어 이동, 점프, 공격, 회피 구현
- 피격, 체크포인트, 적 AI, 보스 구현
- 모바일 터치 UI
- Android / iOS Export 설정
- 외부 Add-on 또는 Plugin

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `WORK/DEC-001.md`
- `WORK/DEC-002.md`
- `WORK/DEC-003.md`

## 완료 조건(Acceptance Criteria)

- Godot 4.7.2 기준 프로젝트 생성
- GDScript 기준
- Main Scene 실행 가능
- 기본 프로젝트 폴더 구성
- Input Map 정의
- 오류 없이 실행
- Git 관리 대상 검토
- 프로젝트 구조 문서화

## 결과물(Deliverables)

- `CLIENT/Game/project.godot`
- `CLIENT/Game/scenes/prototype/PrototypeMain.tscn`
- 최소 프로젝트 폴더 구조
- 갱신된 `.gitignore`

## 의존성

- Godot 4.7.2 stable Standard 실행 파일

## 작업 결과

- `CLIENT/Game`에 Godot 4.7.2 기준 최소 프로젝트 설정을 작성했다.
- Compatibility 렌더러와 `PrototypeMain.tscn` Main Scene을 지정했다.
- `move_left`, `move_right`, `jump`, `attack`, `dodge` Input Map과 개발용 키보드 입력을 정의했다.
- `scenes/prototype`, `scripts/player`, `scripts/common`, `assets/placeholder`, `tests` 구조를 만들었다.
- `.gitignore`에 Godot 4 생성 Cache와 생성 번역 파일 제외 규칙을 추가했다.
- 공식 Godot 4.7.2 stable Standard x86_64 실행환경을 `D:/JUNYPAPA_STUDIO/Tools/Godot/4.7.2`에 준비했다.
- Headless Editor 프로젝트 로드와 Main Scene 실행이 종료 코드 0으로 완료되었다.
- Godot 런타임에서 Main Scene Resource와 Input Map 5개 및 키 바인딩을 확인했다.
- 실제 Editor에서 `PrototypeMain.tscn`을 로드하고 종료 코드 0을 확인했다.
- Main Scene을 1280×720로 렌더링해 `Project Knight / Prototype 01` 표시를 확인했다.
- 생성된 `.godot/` Cache가 Git 상태에 나타나지 않는 것을 확인했다.

## 알려진 문제

없음

## 검토(Review)

검토자: 스튜디오 매니저(Studio Manager)
결과: PASS
의견:

- Godot 4.7.2 stable Standard 버전 일치
- GDScript 기준 및 Compatibility 렌더러 확인
- 프로젝트와 Main Scene 정상 로드
- Main Scene 실행 및 확인 텍스트 표시
- Script Error, Missing Resource, Configuration Error 없음
- Input Map 5개와 지정 키 바인딩 정상
- Godot Cache Git Ignore 정상
- 최소 프로젝트 구조와 관련 문서 확인
