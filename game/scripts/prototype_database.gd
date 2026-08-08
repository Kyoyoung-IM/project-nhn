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

# 테스트 밸런스 편집은 메모리의 런타임 사본만 바꾸며, 이 스냅샷으로 언제든 로컬 JSON 원본값으로 돌아간다.
var source_table_snapshot: Dictionary = {}

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
	_capture_source_table_snapshot()
	return true


# 테스트 편집 창에 노출할 컬럼 순서와 편집 가능 여부를 한곳에서 정의한다.
# ID, 타입, 다음 Tier와 리소스 참조는 런타임 연결을 깨뜨릴 수 있어 읽기 전용이다.
func balance_table_columns(table_name: String) -> Array[Dictionary]:
	match table_name:
		"Define":
			return [
				{"key": "name", "label": "name", "editable": false},
				{"key": "value", "label": "value", "editable": true},
			]
		"Turret":
			return _column_definitions(
				["turretId", "type", "nextTurretId", "isShop", "basePrice", "damage", "attackspeed", "range", "rangeValue", "ccDuration", "ccValue", "vfxResource", "turretResource"],
				["isShop", "basePrice", "damage", "attackspeed", "range", "rangeValue", "ccDuration", "ccValue"]
			)
		"Monster":
			return _column_definitions(
				["monsterId", "type", "baseHp", "moveSpeed", "rewardGold", "prefabResource"],
				["baseHp", "moveSpeed", "rewardGold"]
			)
		"SpawnTable":
			return _column_definitions(
				["waveGroup", "monsterId", "spawnOrder", "value"],
				["spawnOrder", "value"]
			)
		"ShopGacha":
			return _column_definitions(["turretIndex", "probability"], ["probability"])
	return []


# 편집 창이 테이블을 공통 그리드로 만들 수 있도록 원본 컬럼 이름을 보존한 행을 반환한다.
func balance_table_rows(table_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match table_name:
		"Define":
			var keys := define_values.keys()
			keys.sort()
			for key in keys:
				result.append({"_row_id": str(key), "name": str(key), "value": define_values[key]})
		"Turret":
			for turret_id in turrets_by_id:
				var row: Dictionary = (turrets_by_id[turret_id] as Dictionary).duplicate(true)
				row["_row_id"] = str(turret_id)
				result.append(row)
		"Monster":
			for monster_id in monsters_by_id:
				var row: Dictionary = (monsters_by_id[monster_id] as Dictionary).duplicate(true)
				row["_row_id"] = str(monster_id)
				result.append(row)
		"SpawnTable":
			for row_index in spawn_rows.size():
				var row: Dictionary = spawn_rows[row_index].duplicate(true)
				row["_row_id"] = row_index
				result.append(row)
		"ShopGacha":
			for row_index in shop_rows.size():
				var row: Dictionary = shop_rows[row_index].duplicate(true)
				row["_row_id"] = row_index
				result.append(row)
	return result


# 새 행 입력과 CSV·TSV·JSON 파싱에서 공통으로 사용하는 테이블별 기본값이다.
# ID와 참조 문자열은 적용 전 UI에서 입력하며, 숨겨진 prototypeExtensions는 행 적용 시 안전한 기본값으로 만든다.
func balance_table_new_row(table_name: String) -> Dictionary:
	match table_name:
		"Define":
			return {"name": "", "value": 0.0}
		"Turret":
			return {
				"turretId": "", "type": "RANGED", "nextTurretId": "-1", "isShop": false,
				"basePrice": -1, "damage": 1.0, "attackspeed": 1.0, "range": 2.0, "rangeValue": 0.0,
				"ccDuration": 0.0, "ccValue": "0%", "vfxResource": "", "turretResource": "",
			}
		"Monster":
			return {
				"monsterId": "", "type": "normal", "baseHp": 1.0, "moveSpeed": 1.0,
				"rewardGold": 0, "prefabResource": "",
			}
		"SpawnTable":
			return {"waveGroup": "wave1", "monsterId": "", "spawnOrder": 1, "value": 1}
		"ShopGacha":
			return {"turretIndex": "", "probability": 0.0}
	return {}


# 현재 테이블 스키마에 맞춰 JSON 객체·배열 또는 헤더 포함 CSV·TSV를 타입 변환한다.
# 성공한 행도 적용 전 편집 화면에만 추가되며 이 함수는 런타임 데이터를 변경하지 않는다.
func parse_balance_rows(table_name: String, source_text: String) -> Dictionary:
	var text := source_text.strip_edges()
	if text.is_empty():
		return {"rows": [], "errors": ["파싱할 행 데이터를 입력하세요"]}
	var raw_rows: Array = []
	var errors: Array[String] = []
	if text.begins_with("{") or text.begins_with("["):
		var json := JSON.new()
		var json_error := json.parse(text)
		if json_error != OK:
			return {"rows": [], "errors": ["JSON 파싱 오류(%d행): %s" % [json.get_error_line(), json.get_error_message()]]}
		var parsed_json: Variant = json.data
		if typeof(parsed_json) == TYPE_DICTIONARY:
			raw_rows.append(parsed_json)
		elif typeof(parsed_json) == TYPE_ARRAY:
			raw_rows = parsed_json as Array
		else:
			return {"rows": [], "errors": ["JSON은 객체 한 개 또는 객체 배열이어야 합니다"]}
	else:
		var delimited := _parse_delimited_balance_rows(text)
		errors.append_array(delimited.get("errors", []) as Array[String])
		raw_rows = delimited.get("rows", []) as Array
	if not errors.is_empty():
		return {"rows": [], "errors": errors}
	var defaults := balance_table_new_row(table_name)
	if defaults.is_empty():
		return {"rows": [], "errors": ["지원하지 않는 테이블입니다: %s" % table_name]}
	var result: Array[Dictionary] = []
	for row_index in raw_rows.size():
		var raw_value: Variant = raw_rows[row_index]
		if typeof(raw_value) != TYPE_DICTIONARY:
			errors.append("%d행: 객체 형식이 아닙니다" % (row_index + 1))
			continue
		var raw_row := raw_value as Dictionary
		var normalized: Dictionary = {}
		for raw_key in raw_row:
			if not defaults.has(str(raw_key)):
				errors.append("%d행: 알 수 없는 컬럼 %s" % [row_index + 1, str(raw_key)])
		for column in balance_table_columns(table_name):
			var key := str(column.get("key", ""))
			if not raw_row.has(key):
				errors.append("%d행: 필수 컬럼 %s이(가) 없습니다" % [row_index + 1, key])
				continue
			var parsed := _parse_balance_value(str(raw_row[key]), defaults.get(key))
			if not bool(parsed.get("ok", false)):
				errors.append("%d행 %s: %s" % [row_index + 1, key, str(parsed.get("error", "값 형식 오류"))])
				continue
			normalized[key] = parsed["value"]
		if normalized.size() == defaults.size():
			result.append(normalized)
	if not errors.is_empty():
		return {"rows": [], "errors": errors}
	return {"rows": result, "errors": []}


# 편집 창의 문자열 값을 현재 데이터 타입으로 변환해 적용하고 전체 참조 검증에 실패하면 원상 복구한다.
# 반환 배열이 비어 있으면 성공이며, 메시지가 있으면 어떤 값도 적용하지 않는다.
func apply_balance_edits(table_name: String, edits: Array[Dictionary]) -> Array[String]:
	return apply_balance_changes(table_name, edits, [], [])


# 셀 편집, 기존 행 삭제와 신규 행 추가를 한 트랜잭션으로 적용한다.
# 어느 단계든 실패하면 런타임 사본 전체를 적용 전 상태로 되돌린다.
func apply_balance_changes(table_name: String, edits: Array[Dictionary], added_rows: Array[Dictionary], deleted_row_ids: Array) -> Array[String]:
	var before := _make_runtime_snapshot()
	var edit_errors: Array[String] = []
	for edit in edits:
		var row_id: Variant = edit.get("row_id")
		var column := str(edit.get("column", ""))
		var value_text := str(edit.get("value", ""))
		var target := _runtime_edit_target(table_name, row_id, column)
		if target.is_empty():
			edit_errors.append("편집 대상을 찾을 수 없습니다: %s / %s" % [str(row_id), column])
			continue
		var container: Dictionary = target["container"]
		var target_column := str(target.get("column", column))
		var old_value: Variant = container.get(target_column)
		var parsed := _parse_balance_value(value_text, old_value)
		if not bool(parsed.get("ok", false)):
			edit_errors.append("%s.%s: %s" % [str(row_id), column, str(parsed.get("error", "값 형식 오류"))])
			continue
		container[target_column] = parsed["value"]
	_remove_balance_rows(table_name, deleted_row_ids, edit_errors)
	for row_index in added_rows.size():
		var normalized := _normalize_added_balance_row(table_name, added_rows[row_index], row_index, edit_errors)
		if not normalized.is_empty():
			_append_balance_row(table_name, normalized, edit_errors)
	if not edit_errors.is_empty():
		_restore_runtime_snapshot(before)
		return edit_errors
	validation_errors.clear()
	_validate_define()
	_validate_cross_references()
	if not validation_errors.is_empty():
		var result: Array[String] = validation_errors.duplicate()
		_restore_runtime_snapshot(before)
		validation_errors.clear()
		return result
	return []


# 현재 테이블 하나 또는 전체 테이블을 최초 JSON 로드 직후 값으로 되돌린다.
func reset_balance_table(table_name: String) -> void:
	if not source_table_snapshot.has(table_name):
		return
	var current := _make_runtime_snapshot()
	current[table_name] = _duplicate_table_value(source_table_snapshot[table_name])
	_restore_runtime_snapshot(current)


func reset_all_balance_tables() -> void:
	_restore_runtime_snapshot(source_table_snapshot)


# Compares editor text against the immutable JSON snapshot with the source value's data type.
# Invalid text is treated as changed so it remains visually noticeable until corrected.
func balance_value_differs_from_source(table_name: String, row_id: Variant, column: String, value_text: String) -> bool:
	var source := _source_balance_value(table_name, row_id, column)
	if not bool(source.get("found", false)):
		return true
	var source_value: Variant = source.get("value")
	var parsed := _parse_balance_value(value_text, source_value)
	if not bool(parsed.get("ok", false)):
		return true
	var candidate: Variant = parsed.get("value")
	if typeof(source_value) == TYPE_FLOAT or typeof(candidate) == TYPE_FLOAT:
		return not is_equal_approx(float(candidate), float(source_value))
	return candidate != source_value


func balance_source_value_text(table_name: String, row_id: Variant, column: String) -> String:
	var source := _source_balance_value(table_name, row_id, column)
	return str(source.get("value", "")) if bool(source.get("found", false)) else ""


func _source_balance_value(table_name: String, row_id: Variant, column: String) -> Dictionary:
	if not source_table_snapshot.has(table_name):
		return {"found": false}
	match table_name:
		"Define":
			var source_define := source_table_snapshot["Define"] as Dictionary
			if column == "value" and source_define.has(str(row_id)):
				return {"found": true, "value": source_define[str(row_id)]}
		"Turret", "Monster":
			var source_rows := source_table_snapshot[table_name] as Dictionary
			if source_rows.has(str(row_id)):
				var source_row := source_rows[str(row_id)] as Dictionary
				if source_row.has(column):
					return {"found": true, "value": source_row[column]}
		"SpawnTable", "ShopGacha":
			var source_rows := source_table_snapshot[table_name] as Array
			var row_index := int(row_id)
			if row_index >= 0 and row_index < source_rows.size():
				var source_row := source_rows[row_index] as Dictionary
				if source_row.has(column):
					return {"found": true, "value": source_row[column]}
	return {"found": false}


func _column_definitions(keys: Array[String], editable_keys: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in keys:
		result.append({"key": key, "label": key, "editable": key in editable_keys})
	return result


func _runtime_edit_target(table_name: String, row_id: Variant, column: String) -> Dictionary:
	match table_name:
		"Define":
			if column == "value" and define_values.has(str(row_id)):
				return {"container": define_values, "column": str(row_id)}
		"Turret":
			if turrets_by_id.has(str(row_id)):
				return {"container": turrets_by_id[str(row_id)], "column": column}
		"Monster":
			if monsters_by_id.has(str(row_id)):
				return {"container": monsters_by_id[str(row_id)], "column": column}
		"SpawnTable":
			var spawn_index := int(row_id)
			if spawn_index >= 0 and spawn_index < spawn_rows.size():
				return {"container": spawn_rows[spawn_index], "column": column}
		"ShopGacha":
			var shop_index := int(row_id)
			if shop_index >= 0 and shop_index < shop_rows.size():
				return {"container": shop_rows[shop_index], "column": column}
	return {}


func _parse_balance_value(value_text: String, old_value: Variant) -> Dictionary:
	match typeof(old_value):
		TYPE_BOOL:
			var lowered := value_text.strip_edges().to_lower()
			if lowered in ["true", "1", "yes", "on"]:
				return {"ok": true, "value": true}
			if lowered in ["false", "0", "no", "off"]:
				return {"ok": true, "value": false}
			return {"ok": false, "error": "true/false 값을 입력하세요"}
		TYPE_INT:
			var integer_text := value_text.strip_edges()
			if integer_text.is_valid_int():
				return {"ok": true, "value": int(integer_text)}
			if integer_text.is_valid_float():
				var float_value := float(integer_text)
				if is_equal_approx(float_value, roundf(float_value)):
					return {"ok": true, "value": int(float_value)}
			return {"ok": false, "error": "정수를 입력하세요"}
		TYPE_FLOAT:
			if not value_text.strip_edges().is_valid_float():
				return {"ok": false, "error": "숫자를 입력하세요"}
			return {"ok": true, "value": float(value_text)}
		TYPE_STRING:
			return {"ok": true, "value": value_text.strip_edges()}
	return {"ok": false, "error": "지원하지 않는 데이터 타입입니다"}


func _parse_delimited_balance_rows(source_text: String) -> Dictionary:
	var delimiter := "\t" if source_text.get_slice("\n", 0).contains("\t") else ","
	var records: Array[Array] = []
	var record: Array[String] = []
	var field := ""
	var in_quotes := false
	var index := 0
	while index < source_text.length():
		var character := source_text.substr(index, 1)
		if character == "\"":
			if in_quotes and index + 1 < source_text.length() and source_text.substr(index + 1, 1) == "\"":
				field += "\""
				index += 2
				continue
			in_quotes = not in_quotes
		elif character == delimiter and not in_quotes:
			record.append(field)
			field = ""
		elif (character == "\n" or character == "\r") and not in_quotes:
			record.append(field)
			field = ""
			if not _delimited_record_is_empty(record):
				records.append(record)
			record = []
			if character == "\r" and index + 1 < source_text.length() and source_text.substr(index + 1, 1) == "\n":
				index += 1
		else:
			field += character
		index += 1
	if in_quotes:
		return {"rows": [], "errors": ["CSV/TSV 따옴표가 닫히지 않았습니다"]}
	record.append(field)
	if not _delimited_record_is_empty(record):
		records.append(record)
	if records.size() < 2:
		return {"rows": [], "errors": ["CSV/TSV는 헤더와 한 개 이상의 데이터 행이 필요합니다"]}
	var headers: Array[String] = []
	for header_value in records[0]:
		var header := str(header_value).strip_edges().trim_prefix("﻿")
		if header.is_empty():
			return {"rows": [], "errors": ["CSV/TSV 헤더에 빈 컬럼이 있습니다"]}
		if header in headers:
			return {"rows": [], "errors": ["CSV/TSV 헤더가 중복됩니다: %s" % header]}
		headers.append(header)
	var rows: Array[Dictionary] = []
	var errors: Array[String] = []
	for record_index in range(1, records.size()):
		var values: Array = records[record_index]
		if values.size() != headers.size():
			errors.append("%d행: 헤더는 %d개지만 값은 %d개입니다" % [record_index, headers.size(), values.size()])
			continue
		var row: Dictionary = {}
		for column_index in headers.size():
			row[headers[column_index]] = str(values[column_index]).strip_edges()
		rows.append(row)
	return {"rows": rows, "errors": errors}


func _delimited_record_is_empty(record: Array[String]) -> bool:
	for value in record:
		if not value.strip_edges().is_empty():
			return false
	return true


func _normalize_added_balance_row(table_name: String, raw_row: Dictionary, row_index: int, errors: Array[String]) -> Dictionary:
	var defaults := balance_table_new_row(table_name)
	var normalized: Dictionary = {}
	for column in balance_table_columns(table_name):
		var key := str(column.get("key", ""))
		if not raw_row.has(key):
			errors.append("신규 %d행: 필수 컬럼 %s이(가) 없습니다" % [row_index + 1, key])
			continue
		var parsed := _parse_balance_value(str(raw_row[key]), defaults.get(key))
		if not bool(parsed.get("ok", false)):
			errors.append("신규 %d행 %s: %s" % [row_index + 1, key, str(parsed.get("error", "값 형식 오류"))])
			continue
		normalized[key] = parsed["value"]
	return normalized if normalized.size() == defaults.size() else {}


func _remove_balance_rows(table_name: String, row_ids: Array, errors: Array[String]) -> void:
	if table_name in ["SpawnTable", "ShopGacha"]:
		var indices: Array[int] = []
		for row_id in row_ids:
			var row_index := int(row_id)
			if row_index not in indices:
				indices.append(row_index)
		indices.sort()
		indices.reverse()
		var target_rows: Array = spawn_rows if table_name == "SpawnTable" else shop_rows
		for row_index in indices:
			if row_index < 0 or row_index >= target_rows.size():
				errors.append("삭제할 행을 찾을 수 없습니다: %s / %d" % [table_name, row_index])
				continue
			target_rows.remove_at(row_index)
		return
	for row_id in row_ids:
		var key := str(row_id)
		match table_name:
			"Define":
				if define_values.has(key):
					define_values.erase(key)
				else:
					errors.append("삭제할 Define 행을 찾을 수 없습니다: %s" % key)
			"Turret":
				if turrets_by_id.has(key):
					turrets_by_id.erase(key)
				else:
					errors.append("삭제할 Turret 행을 찾을 수 없습니다: %s" % key)
			"Monster":
				if monsters_by_id.has(key):
					monsters_by_id.erase(key)
				else:
					errors.append("삭제할 Monster 행을 찾을 수 없습니다: %s" % key)


func _append_balance_row(table_name: String, row: Dictionary, errors: Array[String]) -> void:
	match table_name:
		"Define":
			var define_name := str(row.get("name", "")).strip_edges()
			if define_name.is_empty() or define_values.has(define_name):
				errors.append("신규 Define name이 비어 있거나 중복됩니다: %s" % define_name)
				return
			define_values[define_name] = row.get("value")
		"Turret":
			var turret_id := str(row.get("turretId", "")).strip_edges()
			if turret_id.is_empty() or turrets_by_id.has(turret_id):
				errors.append("신규 turretId가 비어 있거나 중복됩니다: %s" % turret_id)
				return
			var turret_row := row.duplicate(true)
			turret_row["type"] = str(turret_row.get("type", "")).to_upper()
			turret_row["prototypeExtensions"] = {
				"displayName": turret_id,
				"colorHex": "68d8c1",
				"tier": _trailing_positive_int(turret_id, 1),
			}
			turrets_by_id[turret_id] = turret_row
		"Monster":
			var monster_id := str(row.get("monsterId", "")).strip_edges()
			if monster_id.is_empty() or monsters_by_id.has(monster_id):
				errors.append("신규 monsterId가 비어 있거나 중복됩니다: %s" % monster_id)
				return
			var monster_row := row.duplicate(true)
			monster_row["type"] = str(monster_row.get("type", "")).to_lower()
			monster_row["prototypeExtensions"] = {
				"displayName": monster_id,
				"colorHex": "d96772",
			}
			monsters_by_id[monster_id] = monster_row
		"SpawnTable":
			spawn_rows.append(row.duplicate(true))
		"ShopGacha":
			shop_rows.append(row.duplicate(true))
		_:
			errors.append("지원하지 않는 테이블입니다: %s" % table_name)


func _trailing_positive_int(value: String, fallback: int) -> int:
	var regex := RegEx.new()
	if regex.compile("([0-9]+)$") != OK:
		return fallback
	var result := regex.search(value)
	if result == null:
		return fallback
	return maxi(1, int(result.get_string(1)))


func _capture_source_table_snapshot() -> void:
	source_table_snapshot = _make_runtime_snapshot()


func _duplicate_table_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


func _make_runtime_snapshot() -> Dictionary:
	return {
		"Define": define_values.duplicate(true),
		"Turret": turrets_by_id.duplicate(true),
		"Monster": monsters_by_id.duplicate(true),
		"SpawnTable": spawn_rows.duplicate(true),
		"ShopGacha": shop_rows.duplicate(true),
	}


func _restore_runtime_snapshot(snapshot: Dictionary) -> void:
	define_values = (snapshot.get("Define", {}) as Dictionary).duplicate(true)
	turrets_by_id = (snapshot.get("Turret", {}) as Dictionary).duplicate(true)
	monsters_by_id = (snapshot.get("Monster", {}) as Dictionary).duplicate(true)
	spawn_rows.clear()
	for row in snapshot.get("SpawnTable", []):
		spawn_rows.append((row as Dictionary).duplicate(true))
	shop_rows.clear()
	for row in snapshot.get("ShopGacha", []):
		shop_rows.append((row as Dictionary).duplicate(true))


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
	var range_value_slots := float(raw.get("rangeValue", 0.0))
	var turret_type := str(raw.get("type", "RANGED")).to_upper()
	# 원본의 range=0 폴백은 유지하고, 기획자 확정에 따라 DOT 화염방사기는 rangeValue를 실제 공격 사거리로 사용한다.
	var effective_range_slots := range_value_slots if range_slots <= 0.0 or (turret_type == "DOT" and range_value_slots > 0.0) else range_slots
	var range_px := effective_range_slots * SLOT_SPACING_PX
	return {
		"id": turret_id,
		"display_name": str(extension.get("displayName", turret_id)),
		"type": turret_type,
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
# 같은 Spawn Order 안에서는 monsterSpawnInterval을, 서로 다른 Order로 넘어갈 때는 최신 define의 spawnOrderInterval을 사용한다.
func get_wave_spawn_entries(wave_group: String) -> Array[Dictionary]:
	var matching_rows := _ordered_spawn_rows(wave_group)
	var individual_interval := define_float("monsterSpawnInterval", 0.4)
	var order_interval := define_float("spawnOrderInterval", 0.5)
	var entries: Array[Dictionary] = []
	for row_index in matching_rows.size():
		var row: Dictionary = matching_rows[row_index]
		var monster_count := maxi(0, int(row.get("value", 0)))
		var spawn_order := int(row.get("spawnOrder", -1))
		for monster_index in monster_count:
			var delay_after_sec := individual_interval
			# 현재 행의 마지막 개체 뒤에서 다음 행의 Order가 달라질 때만 그룹 간 간격을 적용한다.
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


# 최신 테이블의 spawnOrder를 기준으로 웨이브 행을 오름차순 정렬한다. 같은 값은 원본 행 순서를 유지한다.
func _ordered_spawn_rows(wave_group: String) -> Array[Dictionary]:
	var matching_rows: Array[Dictionary] = []
	for row in spawn_rows:
		if str(row.get("waveGroup", "")) == wave_group:
			matching_rows.append(row)
	matching_rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_order := int(a["spawnOrder"])
			var b_order := int(b["spawnOrder"])
			if a_order != b_order:
				return a_order < b_order
			return spawn_rows.find(a) < spawn_rows.find(b)
	)
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


# Returns each Tier 1 shop turret once, preserving the ShopGacha row order.
# Test mode uses this list so every turret type is always available without changing source data.
func all_shop_turret_ids() -> Array[String]:
	var result: Array[String] = []
	for row in shop_rows:
		var turret_id := str(row.get("turretIndex", ""))
		if not turret_id.is_empty() and not result.has(turret_id):
			result.append(turret_id)
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
	for key in ["prepareTimeSec", "totalWaveCount", "waveTimeSec", "initialGold", "rerollCost", "rerollPlusCost", "failAllowedMonster", "monsterSpawnInterval", "spawnOrderInterval"]:
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
	if define_float("spawnOrderInterval", 0.0) <= 0.0:
		validation_errors.append("spawnOrderInterval must be positive")


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

	for row in spawn_rows:
		var wave_group := str(row.get("waveGroup", ""))
		var monster_id := str(row.get("monsterId", ""))
		var order := int(row.get("spawnOrder", -1))
		if wave_group.is_empty() or not monsters_by_id.has(monster_id):
			validation_errors.append("SpawnTable has an invalid wave or monster reference: %s / %s" % [wave_group, monster_id])
		if int(row.get("value", 0)) <= 0:
			validation_errors.append("SpawnTable value must be positive: %s order %d" % [wave_group, order])

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
