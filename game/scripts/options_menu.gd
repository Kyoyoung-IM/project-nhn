extends Control

# 게임 루트가 일시 정지된 동안에도 ESC로 옵션 메뉴를 닫을 수 있도록 전용 입력 신호를 제공한다.
signal escape_pressed


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	escape_pressed.emit()
	get_viewport().set_input_as_handled()
