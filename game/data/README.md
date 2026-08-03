# 프로토타입 데이터 테이블

`game_table_specification_v3.pdf`의 컬럼 구조를 다음 로컬 JSON 파일로 분리한다.

- `prototype_define.json`: Define
- `prototype_turrets.json`: Turret
- `prototype_monsters.json`: Monster
- `prototype_spawn_table.json`: SpawnTable
- `prototype_shop_gacha.json`: ShopGacha

모든 수치는 `PLACEHOLDER`이며 최종 밸런스가 아니다. 원본 명세에 없는 현재 프로토타입 전용 값은 각 행의 `prototypeExtensions`에만 둔다.

- 터렛: `displayName`, `maxHp`, `colorHex`, `tier`
- 몬스터: `displayName`, `attackDamage`, `attackIntervalSec`, `attackRange`, `colorHex`
- Define: `shopCardCount`, `rngSeed`

`failAllowedMonster`는 원본 컬럼 호환을 위해 보존하지만 현재 게임 오버 판정에는 사용하지 않는다.
