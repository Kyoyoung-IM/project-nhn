class_name PrototypeTestBalancePanel
extends Control

# 테스트 모드 전용 빠른 명령과 런타임 데이터 편집 창을 담당한다.
# Google Sheets와 로컬 JSON은 수정하지 않으며 PrototypeDatabase의 메모리 사본만 편집한다.

signal grant_gold_requested(amount: int)
signal start_wave_requested(wave_number: int)
signal runtime_data_changed(table_name: String)

const TABLE_NAMES := ["Define", "Turret", "Monster", "SpawnTable", "ShopGacha"]
const PANEL_INK := Color("171827")
const PANEL_COLOR := Color(0.18, 0.16, 0.27, 0.30)
const PANEL_SOLID := Color("39354d")
const PANEL_LIGHT := Color("514a68")
const CREAM := Color("fff0c5")
const GOLD := Color("f6c653")
const TEAL := Color("2ba89b")
const RED := Color("d94b55")

var database: PrototypeDatabase
var game_font: Font
var side_panel: Panel
var wave_spin_box: SpinBox
var editor_overlay: Control
var editor_title: Label
var editor_scroll: ScrollContainer
var editor_status: Label
var current_table_name: String = ""
var editor_cells: Array[Dictionary] = []
var modal_was_paused: bool = false


func setup(source_database: PrototypeDatabase, ui_font: Font) -> void:
	database = source_database
	game_font = ui_font
	position = Vector2.ZERO
	size = Vector2(1920.0, 1080.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 80
	_build_side_panel()
	_build_editor_overlay()
	set_test_mode_visible(false)


func set_test_mode_visible(enabled: bool) -> void:
	visible = enabled
	if not enabled and editor_overlay != null and editor_overlay.visible:
		_close_editor()
	if wave_spin_box != null and database != null:
		wave_spin_box.max_value = maxi(1, database.define_int("totalWaveCount", 1))


func _build_side_panel() -> void:
	side_panel = Panel.new()
	side_panel.position = Vector2(1470.0, 125.0)
	side_panel.size = Vector2(420.0, 610.0)
	side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	side_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_COLOR, Color(0.55, 0.50, 0.72, 0.65), 18, 4))
	add_child(side_panel)

	var title := _label(side_panel, Vector2(22.0, 16.0), Vector2(376.0, 54.0), "TEST OPTIONS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", CREAM)

	var gold_button := _button(side_panel, Vector2(24.0, 82.0), Vector2(372.0, 58.0), "+9999 GOLD", GOLD)
	gold_button.pressed.connect(func() -> void: grant_gold_requested.emit(9999))

	var wave_label := _label(side_panel, Vector2(24.0, 154.0), Vector2(116.0, 48.0), "WAVE", 23)
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_spin_box = SpinBox.new()
	wave_spin_box.position = Vector2(136.0, 154.0)
	wave_spin_box.size = Vector2(102.0, 48.0)
	wave_spin_box.min_value = 1
	wave_spin_box.max_value = maxi(1, database.define_int("totalWaveCount", 1))
	wave_spin_box.step = 1
	wave_spin_box.value = 1
	wave_spin_box.allow_greater = false
	wave_spin_box.allow_lesser = false
	wave_spin_box.add_theme_font_override("font", game_font)
	wave_spin_box.add_theme_font_size_override("font_size", 22)
	side_panel.add_child(wave_spin_box)
	var start_wave_button := _button(side_panel, Vector2(250.0, 154.0), Vector2(146.0, 48.0), "바로 시작", TEAL)
	start_wave_button.pressed.connect(func() -> void: start_wave_requested.emit(int(wave_spin_box.value)))

	var table_heading := _label(side_panel, Vector2(24.0, 218.0), Vector2(372.0, 38.0), "데이터 테이블", 23)
	table_heading.add_theme_color_override("font_color", CREAM)
	for table_index in TABLE_NAMES.size():
		var table_name := str(TABLE_NAMES[table_index])
		var column := table_index % 2
		var row := table_index / 2
		var button_position := Vector2(24.0 + column * 190.0, 264.0 + row * 60.0)
		var table_button := _button(side_panel, button_position, Vector2(182.0, 50.0), table_name, PANEL_LIGHT)
		table_button.pressed.connect(_open_table.bind(table_name))

	var reset_all_button := _button(side_panel, Vector2(24.0, 466.0), Vector2(372.0, 52.0), "전체 데이터 원본 복원", RED)
	reset_all_button.pressed.connect(_reset_all_tables)
	var hint := _label(side_panel, Vector2(24.0, 528.0), Vector2(372.0, 62.0), "변경값은 현재 테스트 세션에만 적용됩니다.", 18)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("d8d3e8"))


func _build_editor_overlay() -> void:
	editor_overlay = Control.new()
	editor_overlay.position = Vector2.ZERO
	editor_overlay.size = Vector2(1920.0, 1080.0)
	editor_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	editor_overlay.z_index = 150
	editor_overlay.visible = false
	add_child(editor_overlay)

	var dimmer := ColorRect.new()
	dimmer.position = Vector2.ZERO
	dimmer.size = editor_overlay.size
	dimmer.color = Color(0.025, 0.02, 0.05, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(110.0, 70.0)
	panel.size = Vector2(1700.0, 930.0)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_SOLID, PANEL_INK, 22, 7))
	editor_overlay.add_child(panel)

	editor_title = _label(editor_overlay, Vector2(150.0, 94.0), Vector2(1040.0, 64.0), "", 36)
	editor_title.add_theme_color_override("font_color", CREAM)
	editor_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var close_button := _button(editor_overlay, Vector2(1634.0, 92.0), Vector2(128.0, 56.0), "닫기", RED)
	close_button.pressed.connect(_close_editor)
	var apply_button := _button(editor_overlay, Vector2(1326.0, 92.0), Vector2(142.0, 56.0), "변경 적용", TEAL)
	apply_button.pressed.connect(_apply_current_table)
	var reset_button := _button(editor_overlay, Vector2(1480.0, 92.0), Vector2(142.0, 56.0), "원본 복원", GOLD)
	reset_button.pressed.connect(_reset_current_table)

	editor_scroll = ScrollContainer.new()
	editor_scroll.position = Vector2(150.0, 172.0)
	editor_scroll.size = Vector2(1610.0, 730.0)
	editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	editor_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	editor_overlay.add_child(editor_scroll)

	editor_status = _label(editor_overlay, Vector2(150.0, 914.0), Vector2(1610.0, 52.0), "", 21)
	editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_status.add_theme_color_override("font_color", Color("d8d3e8"))


func _open_table(table_name: String) -> void:
	current_table_name = table_name
	modal_was_paused = get_tree().paused
	get_tree().paused = true
	editor_overlay.visible = true
	_populate_editor_table()


func _populate_editor_table() -> void:
	for child in editor_scroll.get_children():
		child.queue_free()
	editor_cells.clear()
	editor_title.text = "%s 런타임 밸런스 편집" % current_table_name
	editor_status.text = "ID·타입·리소스 참조는 읽기 전용입니다. 적용 전 전체 데이터 유효성을 검사합니다."
	editor_status.add_theme_color_override("font_color", Color("d8d3e8"))
	var columns := database.balance_table_columns(current_table_name)
	var rows := database.balance_table_rows(current_table_name)
	var grid := GridContainer.new()
	grid.columns = maxi(1, columns.size())
	grid.custom_minimum_size = Vector2(maxf(1570.0, columns.size() * 180.0), maxf(700.0, (rows.size() + 1) * 48.0))
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	editor_scroll.add_child(grid)
	for column in columns:
		var header := _label(grid, Vector2.ZERO, Vector2.ZERO, str(column.get("label", "")), 19)
		header.custom_minimum_size = Vector2(172.0, 42.0)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_theme_stylebox_override("normal", _panel_style(PANEL_LIGHT, PANEL_INK, 8, 2))
	for row in rows:
		var row_id: Variant = row.get("_row_id")
		for column in columns:
			var column_key := str(column.get("key", ""))
			var value_text := str(row.get(column_key, ""))
			if bool(column.get("editable", false)):
				var input := LineEdit.new()
				input.text = value_text
				input.custom_minimum_size = Vector2(172.0, 42.0)
				input.add_theme_font_override("font", game_font)
				input.add_theme_font_size_override("font_size", 18)
				input.add_theme_color_override("font_color", Color.WHITE)
				input.add_theme_stylebox_override("normal", _panel_style(Color("27243a"), Color("77708e"), 7, 2))
				input.add_theme_stylebox_override("focus", _panel_style(Color("302c45"), TEAL, 7, 3))
				grid.add_child(input)
				editor_cells.append({"row_id": row_id, "column": column_key, "input": input, "original": value_text})
			else:
				var readonly := _label(grid, Vector2.ZERO, Vector2.ZERO, value_text, 17)
				readonly.custom_minimum_size = Vector2(172.0, 42.0)
				readonly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				readonly.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				readonly.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				readonly.tooltip_text = value_text
				readonly.add_theme_color_override("font_color", Color("aaa5b8"))
				readonly.add_theme_stylebox_override("normal", _panel_style(Color("232130"), Color("4b475b"), 7, 1))


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
		editor_status.add_theme_color_override("font_color", Color("ff9ca4"))
		return
	runtime_data_changed.emit(current_table_name)
	_populate_editor_table()
	editor_status.text = "%s 변경값을 현재 테스트 세션에 적용했습니다." % current_table_name
	editor_status.add_theme_color_override("font_color", Color("8be3d8"))


func _reset_current_table() -> void:
	database.reset_balance_table(current_table_name)
	runtime_data_changed.emit(current_table_name)
	_populate_editor_table()
	editor_status.text = "%s를 로컬 JSON 원본값으로 복원했습니다." % current_table_name
	editor_status.add_theme_color_override("font_color", Color("fff0a8"))


func _reset_all_tables() -> void:
	database.reset_all_balance_tables()
	runtime_data_changed.emit("")
	wave_spin_box.max_value = maxi(1, database.define_int("totalWaveCount", 1))


func _close_editor() -> void:
	editor_overlay.visible = false
	get_tree().paused = modal_was_paused


func _label(parent: Node, label_position: Vector2, label_size: Vector2, text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.text = text_value
	label.add_theme_font_override("font", game_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(label)
	return label


func _button(parent: Node, button_position: Vector2, button_size: Vector2, text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = button_size
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_override("font", game_font)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", _panel_style(color, color.lightened(0.28), 11, 3))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.10), color.lightened(0.40), 11, 3))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.14), color.lightened(0.20), 11, 3))
	button.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(button)
	return button


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
