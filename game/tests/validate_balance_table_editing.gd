extends SceneTree

# 테스트 데이터 편집기의 파싱·행 추가·행 삭제 트랜잭션과 실패 시 복원을 검증한다.


func _init() -> void:
	var database := PrototypeDatabase.new()
	if not database.load_all():
		_fail("prototype database failed to load")
		return

	var monster_json := '{"monsterId":"testDummy","type":"normal","baseHp":25,"moveSpeed":1.5,"rewardGold":2,"prefabResource":"prefab_testDummy"}'
	var monster_parse := database.parse_balance_rows("Monster", monster_json)
	if not (monster_parse.get("errors", []) as Array).is_empty() or (monster_parse.get("rows", []) as Array).size() != 1:
		_fail("JSON monster row parsing failed: %s" % str(monster_parse))
		return
	var monster_rows: Array[Dictionary] = []
	monster_rows.append(((monster_parse.get("rows", []) as Array)[0] as Dictionary))
	var monster_errors := database.apply_balance_changes("Monster", [], monster_rows, [])
	if not monster_errors.is_empty() or database.get_monster_data("testDummy").is_empty():
		_fail("parsed monster row was not added")
		return

	var spawn_tsv := "waveGroup\tmonsterId\tspawnOrder\tvalue\nwave1\ttestDummy\t99\t2"
	var spawn_parse := database.parse_balance_rows("SpawnTable", spawn_tsv)
	if not (spawn_parse.get("errors", []) as Array).is_empty() or (spawn_parse.get("rows", []) as Array).size() != 1:
		_fail("TSV spawn row parsing failed")
		return
	var spawn_rows: Array[Dictionary] = []
	spawn_rows.append(((spawn_parse.get("rows", []) as Array)[0] as Dictionary))
	var spawn_errors := database.apply_balance_changes("SpawnTable", [], spawn_rows, [])
	if not spawn_errors.is_empty() or database.get_wave_monster_ids("wave1").count("testDummy") != 2:
		_fail("parsed spawn row was not added with typed values")
		return

	var protected_delete_errors := database.apply_balance_changes("Monster", [], [], ["testDummy"])
	if protected_delete_errors.is_empty() or database.get_monster_data("testDummy").is_empty():
		_fail("referenced monster deletion did not roll back")
		return

	var spawn_row_id := database.balance_table_rows("SpawnTable").size() - 1
	if not database.apply_balance_changes("SpawnTable", [], [], [spawn_row_id]).is_empty():
		_fail("spawn row deletion failed")
		return
	if not database.apply_balance_changes("Monster", [], [], ["testDummy"]).is_empty() or not database.get_monster_data("testDummy").is_empty():
		_fail("unreferenced monster deletion failed")
		return

	var define_before := database.define_int("totalWaveCount", -1)
	var required_delete_errors := database.apply_balance_changes("Define", [], [], ["totalWaveCount"])
	if required_delete_errors.is_empty() or database.define_int("totalWaveCount", -1) != define_before:
		_fail("required Define deletion did not roll back")
		return

	var invalid_parse := database.parse_balance_rows("SpawnTable", "waveGroup,monsterId,value\nwave1,normal1,2")
	if (invalid_parse.get("errors", []) as Array).is_empty():
		_fail("missing required CSV column was accepted")
		return

	print("Balance table editing validation passed: PARSE_ADD_DELETE_TRANSACTION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
