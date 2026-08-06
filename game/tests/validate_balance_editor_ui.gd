extends SceneTree

# 실제 모달 스크립트에서 행 추가·삭제·CSV 파싱·적용·원본 복원 흐름을 검증한다.

const PANEL_SCENE := preload("res://scenes/ui/test_balance_panel.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PrototypeDatabase.new()
	if not database.load_all():
		_fail("prototype database failed to load")
		return
	var panel := PANEL_SCENE.instantiate() as PrototypeTestBalancePanel
	root.add_child(panel)
	panel.setup(database)
	panel.set_test_mode_visible(true)
	panel.call("_open_table", "Define")
	var initial_count := panel.editor_rows.size()
	panel.call("_add_empty_row")
	if panel.editor_rows.size() != initial_count + 1:
		_fail("Add Row did not create a staged row")
		return
	panel.call("_delete_editor_row", panel.editor_rows.back())
	if panel.editor_rows.size() != initial_count or not panel.deleted_row_ids.is_empty():
		_fail("deleting an unapplied row incorrectly staged a database deletion")
		return
	panel.parse_input.text = "name,value\ntestParsedDefine,321"
	panel.call("_parse_rows_from_input")
	if panel.editor_rows.size() != initial_count + 1:
		_fail("CSV Parse did not create a staged row")
		return
	panel.call("_apply_current_table")
	if not is_equal_approx(database.define_float("testParsedDefine", -1.0), 321.0):
		_fail("parsed row was not applied through the modal")
		return
	panel.call("_reset_current_table")
	if database.define_values.has("testParsedDefine"):
		_fail("Original Restore did not remove the added runtime row")
		return
	panel.call("_close_editor")
	if panel.is_editor_open() or paused:
		_fail("balance editor did not restore pause state on close")
		return
	panel.queue_free()
	print("Balance editor UI validation passed: STAGED_ROW_PARSE_APPLY_RESET_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	paused = false
	quit(1)
