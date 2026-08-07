## 변경 내용

- 전장 배경·몬스터·터렛을 가로세로 동일한 90% 배율로 축소해 두 층이 확실히 보이도록 조정했습니다.
- 두 층 카메라 화면을 130px 위로 이동해 하단의 불필요한 동굴 여백을 바로 위층 표시 공간으로 전환했습니다.
- 균일 축소로 생기는 좌우 여백은 원본 가장자리 조각을 동일 배율로 거울 연장해 채웠습니다.
- 사용자 확인용 Web Release와 관련 기획·현황 문서를 함께 갱신했습니다.

## 이유와 영향

기존 카메라는 보이는 세로 범위가 좁고 하단 상점 위에 불필요한 여백이 남았습니다. 변경 후 이미지 비율을 유지하면서 인접한 두 층의 전투 공간을 더 넓게 확인할 수 있습니다. HUD와 상점 크기는 유지됩니다.

## 검증

- `validate_editor_ui_layout.gd`: 통과
- `--auto-test-camera-navigation`: `FOUR_STOPS_UNIFORM_90_PERCENT_SCALE` 통과
- `--auto-test-drag`: `SAME_FLOOR_ONLY` 통과
- `--auto-test-shop-drag`: `PAY_ON_VALID_DROP` 통과
- `--auto-test-sell`: `DAY_LOWER_SHOP_HALF_CUMULATIVE_REFUND` 통과
- 최신 `origin/main` 리베이스 후 Web Release 재내보내기 완료
- 로컬 Web 화면 사용자 확인 완료
