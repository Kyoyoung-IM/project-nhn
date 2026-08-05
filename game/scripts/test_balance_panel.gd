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

var database: PrototypeDatabase
var side_panel: Panel
var wave_spin_box: SpinBox
var editor_overlay: Control
var editor_title: Label
var editor_scroll: ScrollContainer
var editor_status: Label
var modified_input_template: LineEdit
var current_table_name: String = ""
var editor_cells: Array[Dictionary] = []
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
	modified_input_template = editor_overlay.get_node("StyleTemplates/ModifiedInput") as LineEdit

	(side_panel.get_node("GrantGoldButton") as Button).pressed.connect(_on_grant_gold_pressed)
	(side_panel.get_node("StartWaveButton") as Button).pressed.connect(_on_start_wave_pressed)
	for table_name in TABLE_NAMES:
		var table_button := side_panel.get_node("%sButton" % table_name) as Button
		table_button.pressed.connect(_open_table.bind(table_name))
	(side_panel.get_node("ResetAllButton") as Button).pressed.connect(_reset_all_tables)
	(editor_overlay.get_node("ApplyButton") as Button).pressed.connect(_apply_current_table)
	(editor_overlay.get_node("ResetButton") as Button).pressed.connect(_reset_current_table)
	(editor_overlay.get_node("CloseButton") as Button).pressed.connect(_close_editor)
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
	_populate_editor_table()
	# Move keyboard focus away from any underlying SpinBox/Button while the modal is active.
	editor_overlay.grab_focus()


func _populate_editor_table() -> void:
	for child in editor_scroll.get_children():
		child.queue_free()
	editor_cells.clear()
	editor_title.text = "%s 런타임 밸런스 편집" % current_table_name
	editor_status.text = "ID·타입·리소스 참조는 읽기 전용입니다. 적용 전 전체 데이터 유효성을 검사합니다."
	editor_status.add_theme_color_override("font_color", status_default_color)
	var columns := database.balance_table_columns(current_table_name)
	var rows := database.balance_table_rows(current_table_name)
	var grid := GRID_SCENE.instantiate() as GridContainer
	grid.columns = maxi(1, columns.size())
	editor_scroll.add_child(grid)
	for column in columns:
		var header := HEADER_CELL_SCENE.instantiate() as Label
		header.text = str(column.get("label", ""))
		grid.add_child(header)
	for row in rows:
		var row_id: Variant = row.get("_row_id")
		for column in columns:
			var column_key := str(column.get("key", ""))
			var value_text := str(row.get(column_key, ""))
			if bool(column.get("editable", false)):
				var input := EDIT_CELL_SCENE.instantiate() as LineEdit
				input.text = value_text
				grid.add_child(input)
				var cell := {
					"row_id": row_id,
					"column": column_key,
					"input": input,
					"original": value_text,
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


func _on_editor_cell_text_changed(_new_text: String, cell: Dictionary) -> void:
	_update_editor_cell_style(cell)


# Gold styling marks both unsaved edits and values already applied to the runtime copy.
func _update_editor_cell_style(cell: Dictionary) -> void:
	var input := cell.get("input") as LineEdit
	if input == null:
		return
	var row_id: Variant = cell.get("row_id")
	var column := str(cell.get("column", ""))
	var modified := database.balance_value_differs_from_source(current_table_name, row_id, column, input.text)
	if modified:
		input.add_theme_color_override("font_color", modified_input_template.get_theme_color("font_color"))
		input.add_theme_stylebox_override("normal", modified_input_template.get_theme_stylebox("normal").duplicate())
		input.add_theme_stylebox_override("focus", modified_input_template.get_theme_stylebox("focus").duplicate())
		input.tooltip_text = "원본값: %s" % database.balance_source_value_text(current_table_name, row_id, column)
	else:
		input.add_theme_color_override("font_color", cell.get("base_font_color", Color.WHITE))
		input.add_theme_stylebox_override("normal", cell.get("base_normal") as StyleBox)
		input.add_theme_stylebox_override("focus", cell.get("base_focus") as StyleBox)
		input.tooltip_text = ""


func _apply_current_table() -> void:
	var edits: Array[Dictionary] = []
	for cell in editor_cells:
		var input := cell.get("input") as LineEdit
		if input != null and input.text != str(cell.get("original", "")):
			edits.append({"row_id": cell.get("row_id"), "column": cell.get("column"), "value": input.text})
	if edits.is_empty():
		editor_status.text = "변경된 값이 없습니다."
		return
	var errors := database.apply_balance_edits(current_table_name, edits)
	if not errors.is_empty():
		editor_status.text = "적용 실패: %s" % " | ".join(errors.slice(0, 3))
		editor_status.add_theme_color_override("font_color", status_error_color)
		return
	runtime_data_changed.emit(current_table_name)
	_populate_editor_table()
	editor_status.text = "%s 변경값을 현재 테스트 세션에 적용했습니다." % current_table_name
	editor_status.add_theme_color_override("font_color", status_success_color)


func _reset_current_table() -> void:
	database.reset_balance_table(current_table_name)
	runtime_data_changed.emit(current_table_name)
	_populate_editor_table()
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
