# 프로토타입 데이터 테이블

읽기 전용 기준 데이터 테이블의 컬럼과 행을 다음 로컬 JSON 파일로 분리한다.

- 원본: `https://docs.google.com/spreadsheets/d/1DNYhAyOK-8hTO4hKY_9cGGzvM-DoM99ttiObfkve59s/edit?usp=sharing`
- 원본 시트는 수정하지 않으며 런타임은 아래 로컬 사본만 사용한다.

- `prototype_define.json`: Define
- `prototype_turrets.json`: Turret
- `prototype_monsters.json`: Monster
- `prototype_spawn_table.json`: SpawnTable
- `prototype_shop_gacha.json`: ShopGacha

모든 수치는 `PLACEHOLDER`이며 최종 밸런스가 아니다. 원본 명세에 없는 현재 프로토타입 전용 값은 각 행의 `prototypeExtensions`에만 둔다.

- 터렛: `displayName`, `colorHex`, `tier`
- 몬스터: `displayName`, `colorHex`
- Define: `shopCardCount`, `rngSeed`, `sellRefundRate` (`rngSeed`는 자동 테스트와 `--shop-seed=<숫자>` 디버그 재현에만 사용하며, `sellRefundRate=0.5`는 기획 확정 전 임시값)

2026-08-05 읽기 전용 원본의 다섯 시트(`define`, `turret`, `monster`, `spawntable`, `shopGacha`)를 다시 대조했다. 원본 행 순서를 유지해 변경된 터렛 피해·가격·CC 수치와 몬스터 체력·이동 속도를 반영했고, `wave4`의 `boss1` 수를 4기에서 1기로 갱신했다. `totalWaveCount=4`, `rerollPlusCost=5`, `spawnOrderInterval=0.5`, 고유한 `wave3.spawnOrder`와 상점 확률은 유지된다.

`failAllowedMonster`는 원본 컬럼 호환을 위해 보존하지만 현재 게임 오버 판정에는 사용하지 않는다.

현재 분기에서는 원본 Monster 시트에 공격 관련 컬럼이 없는 점을 기준으로 몬스터의 터렛 공격과 터렛 체력·사망을 사용하지 않는다.

현재 데이터 테이블의 누락·충돌과 임시 처리는 `Design Request/`의 활성 `YYYYMMDD REQUEST.md`에서 관리한다. 과거 날짜 파일은 읽기 전용 이력이다.
