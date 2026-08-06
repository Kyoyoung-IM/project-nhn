class_name PrototypeTestBalancePanel
extends Control

# 테스트 모드 전용 빠른 명령과 런타임 데이터 편집 창을 담당한다.
# Google Sheets와 로컬 JSON은 수정하지 않으며 PrototypeDatabase의 메모리 사본만 편집한다.

signal grant_gold_requested(amount: int)
signal start_wave_requested(wave_number: int)
signal runtime_data_changed(table_name: String)
signal editor_visibility_changed(opened: bool)

const TABLE_NAMES := ["Define", "Turret", "Monster", "SpawnTable", "ShopGacha"]
const GRID_SCENE := preload("res://scenes/ui/balance_table_grid.tscn")
const HEADER_CELL_SCENE := preload("res://scenes/ui/balance_header_cell.tscn")
const EDIT_CELL_SCENE := preload("res://scenes/ui/balance_edit_cell.tscn")
const READONLY_CELL_SCENE := preload("res://scenes/ui/balance_readonly_cell.tscn")
const DELETE_BUTTON_SCENE := preload("res://scenes/ui/balance_row_delete_button.tscn")

var database: PrototypeDatabase
var side_panel: Panel
var wave_spin_box: SpinBox
var editor_overlay: Control
var editor_title: Label
var editor_scroll: ScrollContainer
var editor_status: Label
var parse_input: TextEdit
var modified_input_template: LineEdit
var current_table_name: String = ""
var editor_cells: Array[Dictionary] = []
var editor_rows: Array[Dictionary] = []
var deleted_row_ids: Array = []
var temporary_row_serial: int = 0
var modal_was_paused: bool = false

@export_group("편집 결과 문구 색상")
@export var status_default_color := Color("d8d3e8")
@export var status_error_color := Color("ff9ca4")
@export var status_success_color := Color("8be3d8")
@export var status_reset_color := Color("fff0a8")


# 정적 위치·크기·스타일은 test_balance_panel.tscn에서 편집하고 이 함수는 데이터와 동작만 연결한다.
func setup(source_database: PrototypeDatabase) -> void:
	database = source_database
	side_panel = get_node("SidePanel") as Panel
	wave_spin_box = side_panel.get_node("WaveSpinBox") as SpinBox
	editor_overlay = get_node("EditorOverlay") as Control
	editor_title = editor_overlay.get_node("Title") as Label
	editor_scroll = editor_overlay.get_node("TableScroll") as ScrollContainer
	editor_status = editor_overlay.get_node("Status") as Label
	parse_input = editor_overlay.get_node("ParseInput") as TextEdit
	modified_input_template = editor_overlay.get_node("StyleTemplates/ModifiedInput") as LineEdit

	(side_panel.get_node("GrantGoldButton") as Button).pressed.connect(_on_grant_gold_pressed)
	(side_panel.get_node("StartWaveButton") as Button).pressed.connect(_on_start_wave_pressed)
	for table_name in TABLE_NAMES:
		var table_button := side_panel.get_node("%sButton" % table_name) as Button
		table_button.pressed.connect(_open_table.bind(table_name))
	(side_panel.get_node("ResetAllButton") as Button).pressed.connect(_reset_all_tables)
	(editor_overlay.get_node("AddRowButton") as Button).pressed.connect(_add_empty_row)
	(editor_overlay.get_node("ApplyButton") as Button).pressed.connect(_apply_current_table)
	(editor_overlay.get_node("ResetButton") as Button).pressed.connect(_reset_current_table)
	(editor_overlay.get_node("CloseButton") as Button).pressed.connect(_close_editor)
	(editor_overlay.get_node("ParseButton") as Button).pressed.connect(_parse_rows_from_input)
	set_test_mode_visible(false)


func set_test_mode_visible(enabled: bool) -> void:
	visible = enabled
	if not enabled and editor_overlay != null and editor_overlay.visible:
		_close_editor()
	if wave_spin_box != null and database != null:
		wave_spin_box.max_value = maxi(1, database.define_int("totalWaveCount", 1))


# The game controller uses this state to ignore global gameplay input while the modal is open.
func is_editor_open() -> bool:
	return editor_overlay != null and editor_overlay.visible


func _on_grant_gold_pressed() -> void:
	grant_gold_requested.emit(9999)


func _on_start_wave_pressed() -> void:
	start_wave_requested.emit(int(wave_spin_box.value))


func _open_table(table_name: String) -> void:
	current_table_name = table_name
	modal_was_paused = get_tree().paused
	get_tree().paused = true
	editor_overlay.visible = true
	editor_visibility_changed.emit(true)
	_load_editor_rows()
	_render_editor_table()
	# Move keyboard focus away from any underlying SpinBox/Button while the modal is active.
	editor_overlay.grab_focus()


func _load_editor_rows() -> void:
	editor_rows.clear()
	deleted_row_ids.clear()
	temporary_row_serial = 0
	parse_input.text = ""
	for source_row in database.balance_table_rows(current_table_name):
		var values := source_row.duplicate(true)
		var row_id: Variant = values.get("_row_id")
		values.erase("_row_id")
		editor_rows.append({
			"row_id": row_id,
			"values": values,
			"original": values.duplicate(true),
			"is_new": false,
		})


func _render_editor_table() -> void:
	for child in editor_scroll.get_children():
		child.queue_free()
	editor_cells.clear()
	editor_title.text = "%s 런타임 밸런스 편집" % current_table_name
	editor_status.text = "기존 ID·참조는 읽기 전용이며 신규 행은 적용 전까지 입력할 수 있습니다."
	editor_status.add_theme_color_override("font_color", status_default_color)
	var columns := database.balance_table_columns(current_table_name)
	var grid := GRID_SCENE.instantiate() as GridContainer
	grid.columns = maxi(1, columns.size() + 1)
	editor_scroll.add_child(grid)
	var action_header := HEADER_CELL_SCENE.instantiate() as Label
	action_header.custom_minimum_size.x = 86.0
	action_header.text = "작업"
	grid.add_child(action_header)
	for column in columns:
		var header := HEADER_CELL_SCENE.instantiate() as Label
		header.text = str(column.get("label", ""))
		grid.add_child(header)
	for row_model in editor_rows:
		var delete_button := DELETE_BUTTON_SCENE.instantiate() as Button
		delete_button.pressed.connect(_delete_editor_row.bind(row_model))
		grid.add_child(delete_button)
		var row_id: Variant = row_model.get("row_id")
		var values := row_model.get("values") as Dictionary
		var original := row_model.get("original") as Dictionary
		for column in columns:
			var column_key := str(column.get("key", ""))
			var value_text := str(values.get(column_key, ""))
			if bool(column.get("editable", false)) or bool(row_model.get("is_new", false)):
				var input := EDIT_CELL_SCENE.instantiate() as LineEdit
				input.text = value_text
				grid.add_child(input)
				var cell := {
					"row_id": row_id,
					"column": column_key,
					"input": input,
					"original": str(original.get(column_key, "")),
					"row_model": row_model,
					"base_font_color": input.get_theme_color("font_color"),
					"base_normal": input.get_theme_stylebox("normal").duplicate(),
					"base_focus": input.get_theme_stylebox("focus").duplicate(),
				}
				editor_cells.append(cell)
				input.text_changed.connect(_on_editor_cell_text_changed.bind(cell))
				_update_editor_cell_style(cell)
			else:
				var readonly := READONLY_CELL_SCENE.instantiate() as Label
				readonly.text = value_text
				readonly.tooltip_text = value_text
				grid.add_child(readonly)


func _on_editor_cell_text_changed(new_text: String, cell: Dictionary) -> void:
	var row_model := cell.get("row_model") as Dictionary
	var values := row_model.get("values") as Dictionary
	values[str(cell.get("column", ""))] = new_text
	_update_editor_cell_style(cell)


# Gold styling marks both unsaved edits and values already applied to the runtime copy.
func _update_editor_cell_style(cell: Dictionary) -> void:
	var input := cell.get("input") as LineEdit
	if input == null:
		return
	var row_id: Variant = cell.get("row_id")
	var column := str(cell.get("column", ""))
	var row_model := cell.get("row_model") as Dictionary
	var modified := bool(row_model.get("is_new", false)) or database.balance_value_differs_from_source(current_table_name, row_id, column, input.text)
	if modified:
		input.add_theme_color_override("font_color", modified_input_template.get_theme_color("font_color"))
		input.add_theme_stylebox_override("normal", modified_input_template.get_theme_stylebox("normal").duplicate())
		input.add_theme_stylebox_override("focus", modified_input_template.get_theme_stylebox("focus").duplicate())
		input.tooltip_text = "신규 행" if bool(row_model.get("is_new", false)) else "원본값: %s" % database.balance_source_value_text(current_table_name, row_id, column)
	else:
		input.add_theme_color_override("font_color", cell.get("base_font_color", Color.WHITE))
		input.add_theme_stylebox_override("normal", cell.get("base_normal") as StyleBox)
		input.add_theme_stylebox_override("focus", cell.get("base_focus") as StyleBox)
		input.tooltip_text = ""


func _apply_current_table() -> void:
	var edits: Array[Dictionary] = []
	var added_rows: Array[Dictionary] = []
	for row_model in editor_rows:
		var values := row_model.get("values") as Dictionary
		if bool(row_model.get("is_new", false)):
			added_rows.append(values.duplicate(true))
			continue
		var original := row_model.get("original") as Dictionary
		for column in database.balance_table_columns(current_table_name):
			var column_key := str(column.get("key", ""))
			if str(values.get(column_key, "")) != str(original.get(column_key, "")):
				edits.append({"row_id": row_model.get("row_id"), "column": column_key, "value": str(values.get(column_key, ""))})
	if edits.is_empty() and added_rows.is_empty() and deleted_row_ids.is_empty():
		editor_status.text = "변경된 값이 없습니다."
		return
	var errors := database.apply_balance_changes(current_table_name, edits, added_rows, deleted_row_ids)
	if not errors.is_empty():
		editor_status.text = "적용 실패: %s" % " | ".join(errors.slice(0, 3))
		editor_status.add_theme_color_override("font_color", status_error_color)
		return
	runtime_data_changed.emit(current_table_name)
	_load_editor_rows()
	_render_editor_table()
	editor_status.text = "%s 변경값을 현재 테스트 세션에 적용했습니다." % current_table_name
	editor_status.add_theme_color_override("font_color", status_success_color)


func _add_empty_row() -> void:
	_append_new_editor_row(database.balance_table_new_row(current_table_name))
	_render_editor_table()
	editor_status.text = "신규 행을 추가했습니다. ID·참조 필드는 적용 전까지만 편집할 수 있습니다."


func _append_new_editor_row(values: Dictionary) -> void:
	temporary_row_serial += 1
	editor_rows.append({
		"row_id": "__new_%d" % temporary_row_serial,
		"values": values.duplicate(true),
		"original": {},
		"is_new": true,
	})


func _delete_editor_row(row_model: Dictionary) -> void:
	if not bool(row_model.get("is_new", false)):
		deleted_row_ids.append(row_model.get("row_id"))
	editor_rows.erase(row_model)
	_render_editor_table()
	editor_status.text = "행 삭제를 예약했습니다. 변경 적용 시 전체 참조를 검사합니다."
	editor_status.add_theme_color_override("font_color", status_reset_color)


func _parse_rows_from_input() -> void:
	var result := database.parse_balance_rows(current_table_name, parse_input.text)
	var errors: Array = result.get("errors", [])
	if not errors.is_empty():
		editor_status.text = "파싱 실패: %s" % " | ".join(errors.slice(0, 3))
		editor_status.add_theme_color_override("font_color", status_error_color)
		return
	var parsed_rows: Array = result.get("rows", [])
	for parsed_row in parsed_rows:
		_append_new_editor_row(parsed_row as Dictionary)
	parse_input.text = ""
	_render_editor_table()
	editor_status.text = "%d개 행을 파싱했습니다. 변경 적용 전 표에서 수정할 수 있습니다." % parsed_rows.size()
	editor_status.add_theme_color_override("font_color", status_success_color)


func _reset_current_table() -> void:
	database.reset_balance_table(current_table_name)
	runtime_data_changed.emit(current_table_name)
	_load_editor_rows()
	_render_editor_table()
	editor_status.text = "%s를 로컬 JSON 원본값으로 복원했습니다." % current_table_name
	editor_status.add_theme_color_override("font_color", status_reset_color)


func _reset_all_tables() -> void:
	database.reset_all_balance_tables()
	runtime_data_changed.emit("")
	wave_spin_box.max_value = maxi(1, database.define_int("totalWaveCount", 1))


func _close_editor() -> void:
	editor_overlay.visible = false
	get_tree().paused = modal_was_paused
	editor_visibility_changed.emit(false)
