## 변경 내용

- Godot 편집기에서 조정한 HUD 및 일시정지 메뉴 장면 반영
- HUD 루트 오프셋을 화면 기준 위치로 복원해 전체 UI 이탈 방지
- 최신 Web Release 산출물 갱신

## 검증

- `validate_editor_ui_layout.gd` 통과
- `validate_prototype.gd` 통과
- 로컬 Web에서 초기 HUD, ESC 일시정지 메뉴, 재개 상태 확인
- 브라우저 콘솔 오류·경고 없음
