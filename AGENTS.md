# NAN 2026 머지 디펜스 공통 작업 지침

## 0. 정본 저장소와 경로

- 실제 게임 개발, Git과 GitHub 연동의 기준 저장소 `<repo>`는 `C:\GameDev\GameProject\project-nhn`이다.
- Godot 프로젝트는 `<repo>/game/project.godot` 하나만 사용한다.
- Web 내보내기 경로는 `<repo>/build/web/`이다.
- 게임 코드와 리소스에서는 개인 PC 절대 경로가 아니라 `res://` 경로를 사용한다.
- 현재 작업 디렉터리가 다르더라도 다른 위치에 대체 프로젝트나 Web 빌드를 만들지 않는다.
- 실제 저장소가 쓰기 가능 경로에 없으면 다른 위치에 작업물을 만들지 말고 사용자에게 저장소를 작업 공간으로 열거나 권한을 추가해 달라고 요청한다.

## 1. 문서 역할과 우선순위

- 이 `AGENTS.md`는 모든 작업에 공통인 경로, 문서 우선순위, 안전 원칙과 유형별 지침 라우팅을 관리하는 정본이다.
- `DESIGN.md`는 게임 목표, 핵심 루프, 전장, 전투, 상점, UI, 밸런스와 미확정 기획을 관리한다.
- `docs/GAME_SPEC.md`는 사용자·기획자 답변으로 확정된 규칙과 변경 이력을 관리한다.
- `docs/PROJECT_STATUS.md`는 여러 작업 채팅의 현재 브랜치·PR·배포·데이터·제출물 상태를 짧게 인수인계한다.
- `Design Request/YYYYMMDD REQUEST.md`는 데이터 누락·충돌·이상값과 기획자 요청을 일자별로 관리한다.
- 사용자 명령이 이 문서나 `DESIGN.md`와 충돌하면 관련 구현을 중단하고 `문서 현행 원문 / 새 명령 / 예상 영향` 형식으로 질문한다.
- `DESIGN.md`와 `docs/GAME_SPEC.md`가 충돌하면 임의로 결정하지 않고 사용자에게 확인한다.
- 사용자 승인으로 개발 지침이 바뀌면 이 문서나 관련 유형별 지침에, 게임 기획이 바뀌면 `DESIGN.md`와 `docs/GAME_SPEC.md`에 먼저 반영한 뒤 구현한다.

## 2. 작업 시작 라우팅

1. 모든 작업은 이 문서와 `docs/PROJECT_STATUS.md`의 관련 행을 확인한다.
2. 아래 표에서 현재 작업에 해당하는 유형별 지침만 작업 전에 끝까지 읽는다. 여러 유형이 겹치면 해당 파일을 모두 읽는다.
3. 현재 작업과 무관한 유형별 지침은 읽지 않는다.
4. 게임 코드·UI·데이터·플레이 규칙을 제작하거나 바꿀 때는 `DESIGN.md`와 `docs/GAME_SPEC.md`의 관련 절을 확인한다. 게임 규칙이나 문서 정합성 자체를 바꾸는 작업에서만 두 문서 전체를 교차 점검한다.

| 작업 유형 | 필수 유형별 지침 |
|---|---|
| 일반 기능 구현·버그 수정·Godot 테스트 | `docs/agent-rules/IMPLEMENTATION_TESTING.md` |
| UI 배치·스타일·상호작용 | `docs/agent-rules/UI.md` |
| 이미지 생성·편집·단순 그래픽 | `docs/agent-rules/IMAGE_GENERATION.md` |
| Google Sheets 조회·데이터 최신화·검증 | `docs/agent-rules/DATA_TABLE.md` |
| 커밋·푸시·이슈·PR·병합·배포 | `docs/agent-rules/GITHUB_RELEASE.md` |
| 공모전 일정·제출물·라이선스 | `docs/agent-rules/SUBMISSION.md` |

## 3. 공통 안전 원칙

- 초기 PDF, Google Sheets와 화면 이미지는 참고자료 또는 플레이스홀더이며 확인되지 않은 규칙·수치·화면 동작을 임의로 확정하지 않는다.
- 예시값이나 임시값은 코드와 데이터에서 `TODO`, `PLACEHOLDER` 또는 명시적 개발 플래그로 표시한다.
- 사용자 파일이나 팀원이 만든 리소스를 확인 없이 덮어쓰거나 삭제하지 않는다.
- 기능 구현에 꼭 필요하지 않은 대규모 리팩터링을 피한다.
- `sources/` 아래 파일과 기준 Google Sheets는 읽기 전용으로 취급한다.
- `.godot/`, 임시 캐시, 로그, 개인 IDE 설정과 내보내기 자격 증명을 커밋하지 않는다.
- 사용자 변경과 무관한 파일을 같은 커밋에 섞지 않는다.
- `git reset --hard`, 강제 푸시와 대규모 삭제는 사용자의 명시적 요청 없이 수행하지 않는다.
- 비밀 키, 토큰과 개인 자격 증명을 저장소에 넣지 않는다.
- 외부 에셋을 추가할 때 출처, 제작자, URL, 라이선스와 사용 범위를 기록한다.
- 규칙 기반 또는 유틸리티 기반 시스템을 머신러닝이라고 표현하지 않는다.

## 4. 프로젝트 공통 기술 기준

- Godot 4와 GDScript를 사용한다.
- 목표 플랫폼은 브라우저에서 바로 실행되는 Web 빌드다.
- Web 대상은 Compatibility 렌더러와 단일 스레드 내보내기를 기본으로 한다.
- Web에서 검증되지 않은 GDExtension을 사용하지 않는다.
- 제출 빌드는 Google Sheets나 외부 데이터 서비스 없이 로컬 데이터만으로 동작해야 한다.
- AI 공세 디렉터는 사용자가 별도로 요청하기 전에는 구현하지 않는 후순위 선택 기능이다.

## 5. 상태 관리

- 작업을 시작할 때 `docs/PROJECT_STATUS.md`의 관련 행만 읽고 긴 이전 채팅 기록을 기본 인수인계 수단으로 사용하지 않는다.
- 브랜치, PR, 병합, 배포, 데이터 동기화 또는 제출물 상태가 바뀌면 같은 작업에서 관련 행을 갱신한다.
- 확인하지 않은 상태나 추측한 진행률을 기록하지 않는다.

권장 구조:

```text
<repo>/
  AGENTS.md
  DESIGN.md
  Design Request/
  docs/
    GAME_SPEC.md
    PROJECT_STATUS.md
    agent-rules/
      UI.md
      IMAGE_GENERATION.md
      DATA_TABLE.md
      GITHUB_RELEASE.md
      IMPLEMENTATION_TESTING.md
      SUBMISSION.md
  game/
  build/web/
  submission/
```
