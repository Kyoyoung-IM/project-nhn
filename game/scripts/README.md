# GDScript 구조 안내

이 프로젝트의 런타임 코드는 모두 GDScript(`.gd`)다. 수정하려는 기능에 따라 다음 파일에서 시작한다.

- `prototype_game.gd`: 게임 단계, 웨이브, 경제, 상점, 오브젝트 생성, 드래그 이동·머지, HUD
- `prototype_database.gd`: JSON 로딩, 원본 컬럼 매핑, ID·확률·머지 트리 검증
- `tower.gd`: 불파괴 터렛의 표적 선택, 공격, Tier별 더미 외형과 머지 승급 효과
- `monster.gd`: 몬스터 이동, 터렛 공격, 상태 이상, 최심부 도달
- `tower_slot.gd`: 3개 층 × 5개 배치 슬롯의 입력과 점유 상태
- `shop_card.gd`: 상점 카드의 기본/호버 정보와 타입별 더미 이미지
- `../tests/validate_prototype.gd`: 데이터 테이블 헤드리스 검증

JSON은 문법상 주석을 지원하지 않는다. 데이터 컬럼과 프로토타입 확장 필드 설명은 `res://data/README.md`에서 관리한다.

## 변경 시 확인 순서

1. 수치는 `res://data/prototype_*.json`에서 변경한다.
2. 원본 PDF 컬럼을 게임 내부 이름으로 바꾸는 규칙은 `prototype_database.gd`에서 변경한다.
3. 실제 행동은 `tower.gd`, `monster.gd`, `prototype_game.gd`에서 변경한다.
4. `res://tests/validate_prototype.gd`와 자동 전투 경로를 실행한다.
5. Web 빌드를 다시 생성하고 브라우저에서 확인한다.

## 머지 검증

- `--auto-test-merge`: 낮 단계에서 같은 층의 동일 ID·Tier 터렛만 수동 머지되고, 층간·밤·다른 종류 머지가 거부되는지 검사한다.
- `--auto-test-shop-merge`: 밤에도 상점 카드의 동일 ID·Tier 구매 머지만 성공하고, 호환되지 않는 점유 슬롯에서는 결제되지 않는지 검사한다.
- 머지 결과는 `nextTurretId`의 행을 다시 로드하므로 공격력, 공격 주기, 사거리와 CC를 포함한 상위 Tier 스탯이 한 번에 교체된다.
