class_name PrototypeDatabase
extends RefCounted

# 읽기 전용 Google Sheets의 Define/Turret/Monster/SpawnTable/ShopGacha 로컬 사본을 읽는 전용 로더다.
# 원본 camelCase 컬럼은 데이터 파일에 보존하고, 게임에서 쓰기 쉬운 snake_case로 여기서만 변환한다.

# 각 테이블의 res:// 경로다. 런타임 네트워크 호출 없이 Web 빌드 안에 함께 포함된다.
const DEFINE_PATH := "res://data/prototype_define.json"
const TURRET_PATH := "res://data/prototype_turrets.json"
const MONSTER_PATH := "res://data/prototype_monsters.json"
const SPAWN_TABLE_PATH := "res://data/prototype_spawn_table.json"
const SHOP_GACHA_PATH := "res://data/prototype_shop_gacha.json"

# PDF의 range는 슬롯 간격 단위이므로 현재 전장 슬롯 간격과 같은 픽셀값으로 환산한다.
const SLOT_SPACING_PX := 180.0

# 데이터 오탈자나 정의되지 않은 유형을 조기에 검출하기 위한 허용 목록이다.
const TURRET_TYPES := ["MELEE", "DOT", "STUN", "SLOW", "RANGED"]
const MONSTER_TYPES := ["NORMAL", "SPEED", "TANK", "BOSS"]

# 로드된 원본 행을 ID 인덱스와 배열 형태로 보관한다.
var define_values: Dictionary = {}
var define_extensions: Dictionary = {}
var turrets_by_id: Dictionary = {}
var monsters_by_id: Dictionary = {}
var spawn_rows: Array[Dictionary] = []
var shop_rows: Array[Dictionary] = []

# 검증 오류를 모아서 한 번에 출력하기 위한 버퍼다.
var validation_errors: Array[String] = []


# 다섯 JSON 문서를 읽고 내부 인덱스를 만든 뒤 전체 교차 참조를 검증한다.
# 성공 시 true이며, false일 때 게임은 잘못된 데이터로 시작하지 않는다.
func load_all() -> bool:
	define_values.clear()
	define_extensions.clear()
	turrets_by_id.clear()
	monsters_by_id.clear()
	spawn_rows.clear()
	shop_rows.clear()
	validation_errors.clear()

	var define_document := _read_document(DEFINE_PATH)
	var turret_document := _read_document(TURRET_PATH)
	var monster_document := _read_document(MONSTER_PATH)
	var spawn_document := _read_document(SPAWN_TABLE_PATH)
	var shop_document := _read_document(SHOP_GACHA_PATH)
	if not validation_errors.is_empty():
		_report_errors()
		return false

	_validate_placeholder_meta(define_document, DEFINE_PATH)
	_validate_placeholder_meta(turret_document, TURRET_PATH)
	_validate_placeholder_meta(monster_document, MONSTER_PATH)
	_validate_placeholder_meta(spawn_document, SPAWN_TABLE_PATH)
	_validate_placeholder_meta(shop_document, SHOP_GACHA_PATH)

	define_values = _dictionary_field(define_document, "values", DEFINE_PATH)
	define_extensions = _dictionary_field(define_document, "prototypeExtensions", DEFINE_PATH)
	_load_turrets(_array_field(turret_document, "rows", TURRET_PATH))
	_load_monsters(_array_field(monster_document, "rows", MONSTER_PATH))
	_load_spawn_rows(_array_field(spawn_document, "rows", SPAWN_TABLE_PATH))
	_load_shop_rows(_array_field(shop_document, "rows", SHOP_GACHA_PATH))
	_validate_define()
	_validate_cross_references()
	if not validation_errors.is_empty():
		_report_errors()
		return false
	return true


# Define의 숫자 값을 float로 안전하게 조회한다.
func define_float(key: String, fallback: float = 0.0) -> float:
	return float(define_values.get(key, fallback))


# 웨이브 수·골드처럼 정수 의미인 Define 값을 int로 변환해 조회한다.
func define_int(key: String, fallback: int = 0) -> int:
	return int(define_values.get(key, fallback))


# 원본 명세 밖의 프로토타입 전용 Define 값을 조회한다.
func extension_int(key: String, fallback: int = 0) -> int:
	return int(define_extensions.get(key, fallback))


# Spawn Order 간격처럼 원본 Define에 없는 프로토타입 전용 실수 값을 조회한다.
func extension_float(key: String, fallback: float = 0.0) -> float:
	return float(define_extensions.get(key, fallback))


# Turret 원본 행을 런타임용 Dictionary로 정규화한다.
# attackspeed는 초 단위 공격 간격으로, range는 픽셀 사거리로 변환한다.
func get_turret_data(turret_id: String) -> Dictionary:
	if not turrets_by_id.has(turret_id):
		return {}
	var raw: Dictionary = turrets_by_id[turret_id]
	var extension: Dictionary = raw.get("prototypeExtensions", {})
	var range_slots := float(raw.get("range", 0.0))
	# 원본 설명에 따라 range=0이면 rangeValue도 슬롯 간격 단위로 해석한다.
	var effective_range_slots := float(raw.get("rangeValue", 0.0)) if range_slots <= 0.0 else range_slots
	var range_px := effective_range_slots * SLOT_SPACING_PX
	return {
		"id": turret_id,
		"display_name": str(extension.get("displayName", turret_id)),
		"type": str(raw.get("type", "RANGED")),
		"next_turret_id": str(raw.get("nextTurretId", "-1")),
		"is_shop": bool(raw.get("isShop", false)),
		"base_price": int(raw.get("basePrice", -1)),
		"damage": float(raw.get("damage", 1.0)),
		"attack_interval_sec": float(raw.get("attackspeed", 1.0)),
		"range_px": range_px,
		"cc_duration": float(raw.get("ccDuration", 0.0)),
		"cc_value": _ratio_value(raw.get("ccValue", 0.0)),
		"color_hex": str(extension.get("colorHex", "68d8c1")),
		"tier": int(extension.get("tier", 1)),
		"vfx_resource": str(raw.get("vfxResource", "")),
		"turret_resource": str(raw.get("turretResource", "")),
	}


# Monster 원본 행과 표시용 prototypeExtensions 값을 런타임 형식으로 합친다.
func get_monster_data(monster_id: String) -> Dictionary:
	if not monsters_by_id.has(monster_id):
		return {}
	var raw: Dictionary = monsters_by_id[monster_id]
	var extension: Dictionary = raw.get("prototypeExtensions", {})
	return {
		"id": monster_id,
		"display_name": str(extension.get("displayName", monster_id)),
		"type": str(raw.get("type", "NORMAL")).to_upper(),
		"max_hp": float(raw.get("baseHp", 1.0)),
		"move_speed_multiplier": float(raw.get("moveSpeed", 1.0)),
		"move_speed_px_sec": 88.0 * float(raw.get("moveSpeed", 1.0)),
		"reward_gold": int(raw.get("rewardGold", 0)),
		"color_hex": str(extension.get("colorHex", "d96772")),
		"prefab_resource": str(raw.get("prefabResource", "")),
	}


# SpawnTable을 실제 개체 단위로 펼치고 각 개체 뒤에 적용할 스폰 대기시간을 함께 반환한다.
# 같은 Spawn Order 안에서는 원본 0.4초를, 서로 다른 Order로 넘어갈 때는 임시 확장값 10초를 사용한다.
func get_wave_spawn_entries(wave_group: String) -> Array[Dictionary]:
	var matching_rows := _ordered_spawn_rows(wave_group)
	var individual_interval := define_float("monsterSpawnInterval", 0.4)
	var order_interval := extension_float("spawnOrderIntervalSec", 10.0)
	var entries: Array[Dictionary] = []
	for row_index in matching_rows.size():
		var row: Dictionary = matching_rows[row_index]
		var monster_count := maxi(0, int(row.get("value", 0)))
		var spawn_order := int(row.get("spawnOrder", -1))
		for monster_index in monster_count:
			var delay_after_sec := individual_interval
			# 현재 행의 마지막 개체 뒤에서 다음 행의 Order가 달라질 때만 그룹 간 10초를 적용한다.
			if monster_index == monster_count - 1 and row_index < matching_rows.size() - 1:
				var next_order := int(matching_rows[row_index + 1].get("spawnOrder", -1))
				if next_order != spawn_order:
					delay_after_sec = order_interval
			entries.append({
				"monster_id": str(row.get("monsterId", "")),
				"spawn_order": spawn_order,
				"delay_after_sec": delay_after_sec,
			})
	return entries


# 기존 호출부와 데이터 검증에서 사용할 수 있도록 스폰 일정에서 ID 배열만 추출한다.
func get_wave_monster_ids(wave_group: String) -> Array[String]:
	var monster_ids: Array[String] = []
	for entry in get_wave_spawn_entries(wave_group):
		monster_ids.append(str(entry.get("monster_id", "")))
	return monster_ids


# 순서가 고유한 웨이브는 spawnOrder로 정렬하고, 중복 순서가 있으면 확정 규칙대로 원본 행 순서를 유지한다.
func _ordered_spawn_rows(wave_group: String) -> Array[Dictionary]:
	var matching_rows: Array[Dictionary] = []
	var used_orders: Dictionary = {}
	var has_duplicate_order := false
	for row in spawn_rows:
		if str(row.get("waveGroup", "")) == wave_group:
			matching_rows.append(row)
			var order := int(row.get("spawnOrder", -1))
			if used_orders.has(order):
				has_duplicate_order = true
			used_orders[order] = true
	if not has_duplicate_order:
		matching_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["spawnOrder"]) < int(b["spawnOrder"]))
	return matching_rows


# ShopGacha 확률 누적 방식으로 지정 개수만큼 Tier 1 터렛 ID를 뽑는다.
# 호출자가 일반 플레이용 무작위 시드 또는 테스트·영상용 고정 시드를 선택해 전달한다.
func roll_shop_turret_ids(rng: RandomNumberGenerator, count: int) -> Array[String]:
	var result: Array[String] = []
	if shop_rows.is_empty():
		return result
	for _index in count:
		var roll := rng.randf()
		var cumulative := 0.0
		var selected_id := str(shop_rows.back().get("turretIndex", ""))
		for row in shop_rows:
			cumulative += float(row.get("probability", 0.0))
			if roll <= cumulative:
				selected_id = str(row.get("turretIndex", ""))
				break
		result.append(selected_id)
	return result


# 시트의 `50%` 형식과 숫자 비율을 모두 0~1 실수로 정규화한다.
func _ratio_value(value: Variant) -> float:
	var text := str(value).strip_edges()
	if text.ends_with("%"):
		return float(text.trim_suffix("%")) / 100.0
	return float(value)


# 자동 테스트가 상점 선택 없이 터렛을 배치할 때 사용할 안전한 기본 ID다.
func first_shop_turret_id() -> String:
	return "" if shop_rows.is_empty() else str(shop_rows[0].get("turretIndex", ""))


# JSON 파일 하나를 읽어 최상위 객체로 반환하고 구문/파일 오류를 기록한다.
func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		validation_errors.append("missing table: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		validation_errors.append("table must contain a JSON object: %s" % path)
		return {}
	return parsed as Dictionary


# 모든 프로토타입 테이블이 최종 밸런스로 오해되지 않도록 PLACEHOLDER 표기를 강제한다.
func _validate_placeholder_meta(document: Dictionary, path: String) -> void:
	var meta: Variant = document.get("meta", {})
	if typeof(meta) != TYPE_DICTIONARY or str((meta as Dictionary).get("status", "")) != "PLACEHOLDER":
		validation_errors.append("table must be marked PLACEHOLDER: %s" % path)


# 필수 Dictionary 필드를 타입 검사와 함께 꺼낸다.
func _dictionary_field(document: Dictionary, key: String, path: String) -> Dictionary:
	var value: Variant = document.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		validation_errors.append("%s.%s must be an object" % [path, key])
		return {}
	return value as Dictionary


# 필수 Array 필드를 타입 검사와 함께 꺼낸다.
func _array_field(document: Dictionary, key: String, path: String) -> Array:
	var value: Variant = document.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		validation_errors.append("%s.%s must be an array" % [path, key])
		return []
	return value as Array


# Turret 행을 ID로 인덱싱하고 유형·공격 주기·확장 필드를 1차 검증한다.
func _load_turrets(rows: Array) -> void:
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			validation_errors.append("Turret row must be an object")
			continue
		var row := value as Dictionary
		var turret_id := str(row.get("turretId", ""))
		if turret_id.is_empty() or turrets_by_id.has(turret_id):
			validation_errors.append("invalid or duplicate turretId: %s" % turret_id)
			continue
		if str(row.get("type", "")) not in TURRET_TYPES:
			validation_errors.append("invalid turret type: %s" % str(row.get("type", "")))
		if float(row.get("attackspeed", 0.0)) <= 0.0:
			validation_errors.append("turret attackspeed must be positive: %s" % turret_id)
		if typeof(row.get("prototypeExtensions", {})) != TYPE_DICTIONARY:
			validation_errors.append("turret prototypeExtensions must be an object: %s" % turret_id)
		turrets_by_id[turret_id] = row


# Monster 행을 ID로 인덱싱하고 유형·체력·이동 속도를 1차 검증한다.
func _load_monsters(rows: Array) -> void:
	for value in rows:
		if typeof(value) != TYPE_DICTIONARY:
			validation_errors.append("Monster row must be an object")
			continue
		var row := value as Dictionary
		var monster_id := str(row.get("monsterId", ""))
		if monster_id.is_empty() or monsters_by_id.has(monster_id):
			validation_errors.append("invalid or duplicate monsterId: %s" % monster_id)
			continue
		if str(row.get("type", "")).to_upper() not in MONSTER_TYPES:
			validation_errors.append("invalid monster type: %s" % str(row.get("type", "")))
		if float(row.get("baseHp", 0.0)) <= 0.0:
			validation_errors.append("monster baseHp must be positive: %s" % monster_id)
		if float(row.get("moveSpeed", 0.0)) <= 0.0:
			validation_errors.append("monster moveSpeed must be positive: %s" % monster_id)
		if typeof(row.get("prototypeExtensions", {})) != TYPE_DICTIONARY:
			validation_errors.append("monster prototypeExtensions must be an object: %s" % monster_id)
		monsters_by_id[monster_id] = row


# SpawnTable 행을 타입 확인 후 순서를 유지한 채 저장한다.
func _load_spawn_rows(rows: Array) -> void:
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY:
			spawn_rows.append(value as Dictionary)
		else:
			validation_errors.append("SpawnTable row must be an object")


# ShopGacha 행을 타입 확인 후 확률 검증용 배열에 저장한다.
func _load_shop_rows(rows: Array) -> void:
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY:
			shop_rows.append(value as Dictionary)
		else:
			validation_errors.append("ShopGacha row must be an object")


# Define 필수 키, 양수/음수 범위, 고정 상점 카드 수를 검증한다.
# failAllowedMonster는 존재 여부만 보장하며 게임 오버 계산에는 사용하지 않는다.
func _validate_define() -> void:
	for key in ["prepareTimeSec", "totalWaveCount", "waveTimeSec", "initialGold", "rerollCost", "rerollPlusCost", "failAllowedMonster", "monsterSpawnInterval"]:
		if not define_values.has(key):
			validation_errors.append("Define key is missing: %s" % key)
	if define_float("prepareTimeSec", -1.0) < 0.0:
		validation_errors.append("prepareTimeSec must not be negative")
	if define_int("totalWaveCount", 0) <= 0:
		validation_errors.append("totalWaveCount must be positive")
	if define_float("monsterSpawnInterval", 0.0) <= 0.0:
		validation_errors.append("monsterSpawnInterval must be positive")
	if define_float("rerollCost", -1.0) < 0.0 or define_float("rerollPlusCost", -1.0) < 0.0:
		validation_errors.append("reroll costs must not be negative")
	if extension_int("shopCardCount", 0) != 5:
		validation_errors.append("prototype shopCardCount must remain 5")
	if extension_float("spawnOrderIntervalSec", 0.0) <= 0.0:
		validation_errors.append("prototype spawnOrderIntervalSec must be positive")


# 머지 트리, 몬스터 참조, 스폰 순서, 상점 확률 합계, 웨이브 누락을 검사한다.
func _validate_cross_references() -> void:
	for turret_id in turrets_by_id:
		var turret: Dictionary = turrets_by_id[turret_id]
		var next_id := str(turret.get("nextTurretId", "-1"))
		if next_id != "-1":
			if not turrets_by_id.has(next_id):
				validation_errors.append("nextTurretId does not exist: %s -> %s" % [turret_id, next_id])
			else:
				# 수동 머지는 이 연결을 그대로 사용하므로 다음 행의 타입과 Tier 연속성도 함께 검증한다.
				var next_turret: Dictionary = turrets_by_id[next_id]
				var extension: Dictionary = turret.get("prototypeExtensions", {})
				var next_extension: Dictionary = next_turret.get("prototypeExtensions", {})
				if str(next_turret.get("type", "")) != str(turret.get("type", "")):
					validation_errors.append("nextTurretId must keep turret type: %s -> %s" % [turret_id, next_id])
				if int(next_extension.get("tier", -1)) != int(extension.get("tier", -1)) + 1:
					validation_errors.append("nextTurretId must advance exactly one tier: %s -> %s" % [turret_id, next_id])
		if bool(turret.get("isShop", false)) and int(turret.get("basePrice", -1)) < 0:
			validation_errors.append("shop turret must have a non-negative basePrice: %s" % turret_id)

	var spawn_orders_by_wave: Dictionary = {}
	for row in spawn_rows:
		var wave_group := str(row.get("waveGroup", ""))
		var monster_id := str(row.get("monsterId", ""))
		var order := int(row.get("spawnOrder", -1))
		if wave_group.is_empty() or not monsters_by_id.has(monster_id):
			validation_errors.append("SpawnTable has an invalid wave or monster reference: %s / %s" % [wave_group, monster_id])
		if int(row.get("value", 0)) <= 0:
			validation_errors.append("SpawnTable value must be positive: %s order %d" % [wave_group, order])
		if not spawn_orders_by_wave.has(wave_group):
			spawn_orders_by_wave[wave_group] = {}
		var used_orders: Dictionary = spawn_orders_by_wave[wave_group]
		# 중복 spawnOrder는 Design Request/20260803 REQUEST.md의 결정에 따라 원본 행 순서를 유지하므로 오류로 처리하지 않는다.
		used_orders[order] = true

	var probability_sum := 0.0
	for row in shop_rows:
		var turret_id := str(row.get("turretIndex", ""))
		if not turrets_by_id.has(turret_id) or not bool((turrets_by_id.get(turret_id, {}) as Dictionary).get("isShop", false)):
			validation_errors.append("ShopGacha turret must reference an isShop turret: %s" % turret_id)
		probability_sum += float(row.get("probability", 0.0))
	if not is_equal_approx(probability_sum, 1.0):
		validation_errors.append("ShopGacha probability sum must be 1.0, got %.4f" % probability_sum)

	for wave_number in range(1, define_int("totalWaveCount", 0) + 1):
		if get_wave_monster_ids("wave%d" % wave_number).is_empty():
			validation_errors.append("SpawnTable is missing wave%d" % wave_number)


# 누적된 검증 오류에 공통 접두사를 붙여 Godot 오류 로그로 출력한다.
func _report_errors() -> void:
	for message in validation_errors:
		push_error("Prototype database validation: %s" % message)
