extends Control

# 플레이어에게는 일반 게임 시작과 타이틀 전용 옵션만 제공한다.
# 명시적인 자동 검증 플래그는 기존 테스트 재현성을 위해 화면을 표시하지 않고 게임 장면으로 전달한다.

const GAME_SCENE_PATH := "res://scenes/prototype_game.tscn"
const AUTOMATED_TEST_PREFIX := "--auto-test-"
const TOWER_VISUAL_TEST_PREFIX := "--tower-visual-test="

@onready var game_start_button: Button = $GameStartButton
@onready var options_button: Button = $OptionsButton
@onready var game_start_backplate: CanvasItem = $GameStartBackplate
@onready var options_backplate: CanvasItem = $OptionsBackplate
@onready var options_overlay: Control = $TitleOptions
@onready var options_back_button: Button = $TitleOptions/BackButton


func _ready() -> void:
	if _should_bypass_title_for_test():
		call_deferred("_open_game")
		return
	game_start_button.pressed.connect(_on_game_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_back_button.pressed.connect(_close_options)
	game_start_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not options_overlay.visible or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	_close_options()
	get_viewport().set_input_as_handled()


func _on_game_start_pressed() -> void:
	_open_game()


func _on_options_pressed() -> void:
	_set_main_buttons_visible(false)
	options_overlay.visible = true
	options_back_button.grab_focus()


func _close_options() -> void:
	options_overlay.visible = false
	_set_main_buttons_visible(true)
	options_button.grab_focus()


func _set_main_buttons_visible(visible: bool) -> void:
	game_start_backplate.visible = visible
	game_start_button.visible = visible
	options_backplate.visible = visible
	options_button.visible = visible


func _open_game() -> void:
	var error := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		push_error("Could not open the game scene: %s" % error_string(error))


func _should_bypass_title_for_test() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--test-mode" or argument.begins_with(AUTOMATED_TEST_PREFIX) or argument.begins_with(TOWER_VISUAL_TEST_PREFIX):
			return true
	if not OS.has_feature("web"):
		return false
	var query_string := str(JavaScriptBridge.eval("window.location.search", true))
	for query_part in query_string.trim_prefix("?").split("&"):
		if query_part == "test_mode=1" or query_part == "test_mode=true" or query_part.begins_with("tower_visual_test="):
			return true
	return false
