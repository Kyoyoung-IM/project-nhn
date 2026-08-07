# Godot UI 편집 경로

일반 플레이와 테스트 환경의 정적 UI는 GDScript에서 생성하지 않고 아래 장면 파일에서 관리한다. Godot의 `FileSystem` 패널에서 경로를 펼친 뒤 `.tscn` 파일을 더블클릭하면 2D 편집기와 Inspector에서 위치·크기·폰트·색·스타일을 직접 조절할 수 있다.

## 화면별 장면

- 전체 HUD 및 상점 배치: `res://scenes/ui/game_hud.tscn`
- 상점 카드 한 장의 내부 배치: `res://scenes/ui/shop_card.tscn`
- 일시정지·옵션 창: `res://scenes/ui/options_menu.tscn`
- 게임 클리어 화면: `res://scenes/ui/game_clear_overlay.tscn`
- 게임 오버 화면: `res://scenes/ui/game_over_overlay.tscn`
- 테스트 옵션 및 데이터 편집 모달: `res://scenes/ui/test_balance_panel.tscn`
- 데이터 편집 표 전체 간격: `res://scenes/ui/balance_table_grid.tscn`
- 데이터 표 머리글 셀: `res://scenes/ui/balance_header_cell.tscn`
- 데이터 표 수정 가능 셀: `res://scenes/ui/balance_edit_cell.tscn`
- 데이터 표 읽기 전용 셀: `res://scenes/ui/balance_readonly_cell.tscn`
- 타워 설치 위치 표시: `res://scenes/entities/tower_slot.tscn`
- 몬스터 체력 바: `res://scenes/entities/monster.tscn`의 `HealthBar`

## 일시정지 창 편집 순서

1. Godot에서 `res://scenes/ui/options_menu.tscn`을 연다.
2. `PanelArt`에서 중앙 판넬 이미지의 위치와 크기를 조절한다.
3. `TitleLabel`에서 제목의 위치·폰트·색을 조절한다.
4. `ContinueButton`, `TestModeButton`, `ResetButton`, `QuitButton`에서 각 입력 영역과 문구 스타일을 조절한다.
5. 전체 화면 어두움은 `Dimmer`의 `Color`와 알파값으로 조절한다.

버튼 이름과 노드 계층은 GDScript의 기능 연결 기준이므로 이름을 변경하거나 삭제하지 않는다. 위치, 크기, 텍스트 기본값, 테마 속성 및 이미지 교체는 자유롭게 편집할 수 있다.

## 게임 클리어 화면 편집 순서

1. Godot에서 `res://scenes/ui/game_clear_overlay.tscn`을 연다.
2. `Dimmer`에서 전체 화면 딤드의 색상과 불투명도를 조절한다.
3. `TitleImage`에서 승인된 `GAME CLEAR` 이미지의 위치와 크기, Stretch Mode를 조절한다.
4. 루트 `GameClearOverlay`의 Inspector에서 `Fade Duration Sec`을 조절한다.

`GameClearOverlay`, `Dimmer`, `TitleImage` 노드 이름은 런타임 연결과 UI 검증 기준이므로 변경하거나 삭제하지 않는다. 승리 화면에는 별도 결과 버튼을 두지 않으며, 초기화와 게임 종료는 기존 규칙대로 `ESC` 옵션 창에서 실행한다.

## 동적 데이터 UI

데이터 테이블은 행과 열 수가 원본 데이터에 따라 달라지므로 런타임에 목록을 반복 생성한다. 다만 생성되는 각 구성 요소는 `balance_*_cell.tscn` 템플릿을 인스턴스하므로 셀 크기·폰트·색·테두리는 Godot 편집기에서 직접 변경할 수 있다.

게임 상태에 따라 바뀌는 문구, 골드·웨이브 값, 버튼 활성화 여부와 데이터 행 생성만 GDScript가 담당한다.
