# ProjectKnight Playtest Report (v2 Multi-Agent Production)

- **검수일자**: 2026-11-04
- **검수자**: `PK_QALead`
- **검수 버전**: v2.0.1 (Branch: `feat/quarter-view-mode`)
- **대상 마일스톤**: `VS-001 (3D Background + 2D Character Vertical Slice)`

---

## 1. 3대 QA 레이어 검증 현황

### [Layer 1: Functional QA (기능 무결성)]
- **이동 및 물리**: 지상 이동, 3D 깊이 안팎 이동(W/S), 점프, 공중 자연 낙하 정상 작동.
- **전투 메커니즘**:
  - 3단 콤보 (Hit 1: 2 DMG, Hit 2: 2 DMG, Hit 3: 3 DMG + 신성 관통창 검기).
  - 0.14초 저스트 패링 시 3배 카운터 및 적 스턴/체간 붕괴 정상.
  - 공중 포고 바운스 (수직 반동 + 하향 충격파) 및 하향 다이브 슬램 (대지 진동 링) 정상 작동.
- **세이브 & 경제**: 영혼 파편(Soul Shards) 획득, 성소 화톳불 룬 각인 3종 구매 및 지속 저장 검증 완료.

### [Layer 2: Visual QA (시각 완성도)]
- **2D/3D 통합**: 3D 성채 아레나 바닥과 2D 팔라딘의 발끝 접지감(Grounding) 일치.
- **조명 및 앰비언스**: WorldEnvironment 3D HDR Glow 및 뎁스 포그(Depth Fog) 활성화, 3D 파티클 부유 정상.
- **피격 & 전투 VFX**:
  - 패링 시 3D 골든-시안 충격파 링 생성.
  - 대시 시 3D 네온 잔상 고스트(`DashGhost3D`) 및 뇌전 스파크 생성.
  - 플로팅 데미지 텍스트(Billboard Label3D) 월드 좌표 팝업 정상.

### [Layer 3: Play QA (체감 및 플레이어 경험)]
- **조작 반응성**: 코요테 타임 0.12s, 점프 버퍼 0.14s, 공격 버퍼 0.12s 적용으로 입력 씹힘 현상 0건.
- **보스전 긴장감**: 보스 지휘관 위험 공격(지진 강타) 전조 비콘 링 명확하여 점프로 회피 타이밍 인지 용이.

---

## 2. 검증 통과 결과
- **자동화 검증 스위트**: 75/75 PASS (100%)
- **데일리 개발 러너**: 50/50 PASS (100%)
- **종합 판정**: `QA PASS (Conditional Pass for Polish)`
