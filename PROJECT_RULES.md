# Project Knight 프로젝트 규칙

이 문서는 StudioOS 공통 규칙을 보완하는 Project Knight 전용 규칙이다.

## 우선순위

1. 첫 프로젝트는 완성도보다 Studio OS 실제 운영 검증을 우선한다.
2. 프로토타입 범위를 작게 유지한다.
3. 마계촌 등 기존 게임의 표현, 캐릭터, 스테이지, 음악, 이름 등을 직접 복제하지 않는다.
4. 고전 횡스크롤 액션의 구조와 감각만 참고하여 오리지널 IP를 만든다.
5. 모바일 플레이 가능성을 항상 우선 검토한다.

## 기술

엔진: Godot 4.7.2 stable

스크립트: GDScript

렌더러: Compatibility

기본 원칙:

- 모바일 우선
- 2D 횡스크롤 액션
- Godot 기본 Node / Resource / Scene 구조 우선
- GDScript 우선
- 외부 플러그인과 의존성 최소화
- AI Agent가 구조를 쉽게 이해할 수 있도록 단순한 파일 구조 유지
- 불필요한 Singleton 사용 금지
- 과도한 추상화 금지
- 프로토타입 단계에서 범용 Framework를 만들지 않음

외부 Add-on 또는 Plugin 도입은 필요성이 명확할 때만 검토한다.

버전 업데이트는 자동으로 하지 않으며 필요할 경우 별도 결정(Decision)으로 처리한다.

## 프로젝트별 예외 및 운영 규칙

- **자율 완주 원칙 (Autonomous Execution)**:
  - 디렉터 지침에 따라, 모든 마일스톤 및 개발 작업은 계획 승인(Planning Review / Proceed) 대기나 중간 질문 모달(`ask_question`) 없이 즉시 코드 작업에 착수하고, 자동화 검증(Headless Smoke & 회귀 테스트 100% PASS)까지 단번에 완주한다.
  - 별도의 사전 계획서 승인(Submit) 요청 없이 스튜디오 팀(기획-아트-클라-QA)이 자체적으로 판단 및 검증하여 완성형 빌드를 제공한다.

