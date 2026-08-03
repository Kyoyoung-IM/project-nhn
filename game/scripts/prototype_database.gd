class_name PrototypeDatabase
extends RefCounted

const DEFINE_PATH := "res://data/prototype_define.json"
const TURRET_PATH := "res://data/prototype_turrets.json"
const MONSTER_PATH := "res://data/prototype_monsters.json"
const SPAWN_TABLE_PATH := "res://data/prototype_spawn_table.json"
const SHOP_GACHA_PATH := "res://data/prototype_shop_gacha.json"
const SLOT_SPACING_PX := 145.0
const TURRET_TYPES := ["MELEE", "DOT", "STUN", "SLOW", "RANGED"]
const MONSTER_TYPES := ["NORMAL", "SPEED", "TANK", "BOSS"]

var define_values: Dictionary = {}
var define_extensions: Dictionary = {}
var turrets_by_id: Dictionary = {}
var monsters_by_id: Dictionary = {}
var spawn_rows: Array[Dictionary] = []
var shop_rows: Array[Dictionary] = []
var validation_errors: Array[String] = []


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


func define_float(key: String, fallback: float = 0.0) -> float:
	return float(define_values.get(key, fallback))


func define_int(key: String, fallback: int = 0) -> int:
	return int(define_values.get(key, fallback))


func extension_int(key: String, fallback: int = 0) -> int:
	return int(define_extensions.get(key, fallback))


func get_turret_data(turret_id: String) -> Dictionary:
	if not turrets_by_id.has(turret_id):
		return {}
	var raw: Dictionary = turrets_by_id[turret_id]
	var extension: Dictionary = raw.get("prototypeExtensions", {})
	var range_slots := float(raw.get("range", 0.0))
	var range_px := float(raw.get("rangeValue", 0.0)) if range_slots <= 0.0 else range_slots * SLOT_SPACING_PX
	return {
		"id": turret_id,
		"display_name": str(extension.get("displayName", turret_id)),
		"type": str(raw.get("type", "RANGED")),
		"next_turret_id": str(raw.get("nextTurretId", "-1")),
		"is_shop": bool(raw.get("isShop", false)),
		"base_price": int(raw.get("basePrice", -1)),
		"max_hp": float(extension.get("maxHp", 1.0)),
		"damage": float(raw.get("damage", 1.0)),
		"attack_interval_sec": float(raw.get("attackspeed", 1.0)),
		"range_px": range_px,
		"cc_duration": float(raw.get("ccDuration", 0.0)),
		"cc_value": float(raw.get("ccValue", 0.0)),
		"color_hex": str(extension.get("colorHex", "68d8c1")),
		"tier": int(extension.get("tier", 1)),
		"vfx_resource": str(raw.get("vfxResource", "")),
		"turret_resource": str(raw.get("turretResource", "")),
	}


func get_monster_data(monster_id: String) -> Dictionary:
	if not monsters_by_id.has(monster_id):
		return {}
	var raw: Dictionary = monsters_by_id[monster_id]
	var extension: Dictionary = raw.get("prototypeExtensions", {})
	return {
		"id": monster_id,
		"display_name": str(extension.get("displayName", monster_id)),
		"type": str(raw.get("type", "NORMAL")),
		"max_hp": float(raw.get("baseHp", 1.0)),
		"move_speed_multiplier": float(raw.get("moveSpeed", 1.0)),
		"move_speed_px_sec": 88.0 * float(raw.get("moveSpeed", 1.0)),
		"reward_gold": int(raw.get("rewardGold", 0)),
		"attack_damage": float(extension.get("attackDamage", 1.0)),
		"attack_interval_sec": float(extension.get("attackIntervalSec", 1.0)),
		"attack_range_px": float(extension.get("attackRange", 55.0)),
		"color_hex": str(extension.get("colorHex", "d96772")),
		"prefab_resource": str(raw.get("prefabResource", "")),
	}


func get_wave_monster_ids(wave_group: String) -> Array[String]:
	var matching_rows: Array[Dictionary] = []
	for row in spawn_rows:
		if str(row.get("waveGroup", "")) == wave_group:
			matching_rows.append(row)
	matching_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["spawnOrder"]) < int(b["spawnOrder"]))
	var monster_ids: Array[String] = []
	for row in matching_rows:
		for _index in maxi(0, int(row.get("value", 0))):
			monster_ids.append(str(row.get("monsterId", "")))
	return monster_ids


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


func first_shop_turret_id() -> String:
	return "" if shop_rows.is_empty() else str(shop_rows[0].get("turretIndex", ""))


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


func _validate_placeholder_meta(document: Dictionary, path: String) -> void:
	var meta: Variant = document.get("meta", {})
	if typeof(meta) != TYPE_DICTIONARY or str((meta as Dictionary).get("status", "")) != "PLACEHOLDER":
		validation_errors.append("table must be marked PLACEHOLDER: %s" % path)


func _dictionary_field(document: Dictionary, key: String, path: String) -> Dictionary:
	var value: Variant = document.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		validation_errors.append("%s.%s must be an object" % [path, key])
		return {}
	return value as Dictionary


func _array_field(document: Dictionary, key: String, path: String) -> Array:
	var value: Variant = document.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		validation_errors.append("%s.%s must be an array" % [path, key])
		return []
	return value as Array


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
		if str(row.get("type", "")) not in MONSTER_TYPES:
			validation_errors.append("invalid monster type: %s" % str(row.get("type", "")))
		if float(row.get("baseHp", 0.0)) <= 0.0:
			validation_errors.append("monster baseHp must be positive: %s" % monster_id)
		if float(row.get("moveSpeed", 0.0)) <= 0.0:
			validation_errors.append("monster moveSpeed must be positive: %s" % monster_id)
		if typeof(row.get("prototypeExtensions", {})) != TYPE_DICTIONARY:
			validation_errors.append("monster prototypeExtensions must be an object: %s" % monster_id)
		monsters_by_id[monster_id] = row


func _load_spawn_rows(rows: Array) -> void:
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY:
			spawn_rows.append(value as Dictionary)
		else:
			validation_errors.append("SpawnTable row must be an object")


func _load_shop_rows(rows: Array) -> void:
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY:
			shop_rows.append(value as Dictionary)
		else:
			validation_errors.append("ShopGacha row must be an object")


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


func _validate_cross_references() -> void:
	for turret_id in turrets_by_id:
		var turret: Dictionary = turrets_by_id[turret_id]
		var next_id := str(turret.get("nextTurretId", "-1"))
		if next_id != "-1" and not turrets_by_id.has(next_id):
			validation_errors.append("nextTurretId does not exist: %s -> %s" % [turret_id, next_id])
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
		if used_orders.has(order):
			validation_errors.append("duplicate spawnOrder: %s order %d" % [wave_group, order])
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


func _report_errors() -> void:
	for message in validation_errors:
		push_error("Prototype database validation: %s" % message)
