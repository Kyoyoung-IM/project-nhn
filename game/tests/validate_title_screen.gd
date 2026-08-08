extends SceneTree

# 타이틀에는 승인된 플레이어용 버튼 세 개만 노출하고 테스트 환경 진입 제어를 두지 않는지 검증한다.

const TITLE_SCENE := preload("res://scenes/title_screen.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var title := TITLE_SCENE.instantiate() as Control
	root.add_child(title)
	await process_frame

	var illustration_slot := title.get_node_or_null("IllustrationSlot") as Control
	var game_start_button := title.get_node_or_null("GameStartButton") as Button
	var options_button := title.get_node_or_null("OptionsButton") as Button
	var credits_button := title.get_node_or_null("CreditsButton") as Button
	var options_overlay := title.get_node_or_null("TitleOptions") as Control
	var back_button := title.get_node_or_null("TitleOptions/BackButton") as Button
	var credits_overlay := title.get_node_or_null("TitleCredits") as Control
	var credits_back_button := title.get_node_or_null("TitleCredits/BackButton") as Button
	var credits_text := title.get_node_or_null("TitleCredits/CreditsScroll/CreditsText") as RichTextLabel
	if illustration_slot == null or game_start_button == null or options_button == null or credits_button == null \
			or options_overlay == null or back_button == null or credits_overlay == null \
			or credits_back_button == null or credits_text == null:
		_fail("title screen editable nodes are incomplete")
		return
	if illustration_slot.get_child_count() != 0:
		_fail("illustration slot must remain empty for the graphic designer artwork")
		return
	var visible_root_buttons: Array[Button] = []
	for child in title.get_children():
		if child is Button and (child as Button).visible:
			visible_root_buttons.append(child as Button)
	if visible_root_buttons.size() != 3 or game_start_button.text != "게임 시작" \
			or options_button.text != "옵션" or credits_button.text != "게임 크레딧":
		_fail("title screen must expose only game start, options and credits buttons")
		return
	if title.find_child("*Test*", true, false) != null or _tree_contains_text(title, "테스트"):
		_fail("title screen must not expose a test-mode entry")
		return
	if options_overlay.visible or credits_overlay.visible:
		_fail("title overlays must be closed initially")
		return
	options_button.pressed.emit()
	await process_frame
	if not options_overlay.visible or game_start_button.visible or options_button.visible or credits_button.visible:
		_fail("options button did not open the title-only options panel")
		return
	back_button.pressed.emit()
	await process_frame
	if options_overlay.visible or not game_start_button.visible or not options_button.visible or not credits_button.visible:
		_fail("title options back button did not restore the title screen")
		return
	credits_button.pressed.emit()
	await process_frame
	if not credits_overlay.visible or game_start_button.visible or options_button.visible or credits_button.visible:
		_fail("credits button did not open the title credits panel")
		return
	for required_credit in ["프로젝트 사용자", "OpenAI", "SIL Open Font License 1.1", "Godot Engine 4", "세부 원출처와 배포 라이선스: 미제공"]:
		if required_credit not in credits_text.text:
			_fail("credits panel is missing resource source: %s" % required_credit)
			return
	credits_back_button.pressed.emit()
	await process_frame
	if credits_overlay.visible or not game_start_button.visible or not options_button.visible or not credits_button.visible:
		_fail("credits back button did not restore the title screen")
		return
	game_start_button.pressed.emit()
	await process_frame
	await process_frame
	var game := current_scene
	if game == null or game.name != "PrototypeGame" or bool(game.get("test_mode")):
		_fail("game start must enter the regular game mode")
		return

	print("Title screen validation passed: PLAYER_HAS_NO_DIRECT_TEST_MODE_ENTRY")
	quit(0)


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
