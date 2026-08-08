extends SceneTree

# 편집 가능한 HUD 씬을 실제 게임 루트에 붙여 필수 노드와 카드 입력 영역을 검증한다.

const GAME_SCENE := preload("res://scenes/prototype_game.tscn")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const EDIT_CELL_SCENE := preload("res://scenes/ui/balance_edit_cell.tscn")
const DELETE_BUTTON_SCENE := preload("res://scenes/ui/balance_row_delete_button.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var hud := game.get_node_or_null("GameHUD") as CanvasLayer
	if hud == null:
		_fail("editable GameHUD scene was not instantiated")
		return
	var hud_layout := hud.get_node("Layout") as Control
	var day_night_hud := hud_layout.get_node("DayNightHUD") as Control
	var day_night_bounds := Rect2(day_night_hud.position, day_night_hud.size)
	if not Rect2(Vector2.ZERO, hud_layout.size).encloses(day_night_bounds):
		_fail("day/night HUD extends outside the editable viewport layout")
		return
	var shop_ui := hud.get_node_or_null("Layout/ShopUI") as Control
	if shop_ui == null:
		_fail("editable ShopUI node is missing")
		return
	var action_icon := hud.get_node_or_null("Layout/TopControls/ActionBackplate/ActionIcon") as TextureRect
	var speed_icon_left := hud.get_node_or_null("Layout/TopControls/SpeedBackplate/SpeedIconLeft") as TextureRect
	var speed_icon_middle := hud.get_node_or_null("Layout/TopControls/SpeedBackplate/SpeedIcon") as TextureRect
	var speed_icon_right := hud.get_node_or_null("Layout/TopControls/SpeedBackplate/SpeedIconRight") as TextureRect
	var speed_icon_two_left := hud.get_node_or_null("Layout/TopControls/SpeedBackplate/SpeedIconTwoLeft") as TextureRect
	var speed_icon_two_right := hud.get_node_or_null("Layout/TopControls/SpeedBackplate/SpeedIconTwoRight") as TextureRect
	var pause_icon := hud.get_node_or_null("Layout/TopControls/PauseBackplate/PauseIcon") as TextureRect
	var reroll_button := shop_ui.get_node_or_null("RerollButton") as Button
	if action_icon == null or not action_icon.size.is_equal_approx(Vector2(28.0, 33.6)) \
		or speed_icon_left == null or not speed_icon_left.size.is_equal_approx(Vector2(23.8, 30.8)) \
		or speed_icon_middle == null or not speed_icon_middle.size.is_equal_approx(Vector2(23.8, 30.8)) \
		or speed_icon_right == null or not speed_icon_right.size.is_equal_approx(Vector2(23.8, 30.8)) \
		or speed_icon_two_left == null or not speed_icon_two_left.size.is_equal_approx(Vector2(23.8, 30.8)) \
		or speed_icon_two_right == null or not speed_icon_two_right.size.is_equal_approx(Vector2(23.8, 30.8)) \
		or not is_equal_approx(speed_icon_two_right.position.x - speed_icon_two_left.position.x - speed_icon_two_left.size.x, 4.0) \
		or pause_icon == null or not pause_icon.size.is_equal_approx(Vector2(23.8, 36.4)) \
		or reroll_button == null or reroll_button.icon_max_width != 36:
		_fail("HUD pictograms are not stored at 70% of their previous editable size")
		return
	for card_number in range(1, 6):
		var card := shop_ui.get_node_or_null("ShopCard%d" % card_number) as Button
		if card == null or card.get_node_or_null("Frame") == null or card.get_node_or_null("PriceRow/PriceLabel") == null or card.get_node_or_null("PriceRow/CoinIcon") == null:
			_fail("editable shop card %d is incomplete" % card_number)
			return
		if card.size != Vector2(306.0, 270.0):
			_fail("shop card %d size changed unexpectedly" % card_number)
			return

	var price_row := shop_ui.get_node("ShopCard1/PriceRow") as HBoxContainer
	var price_label := price_row.get_node("PriceLabel") as Label
	if price_row.alignment != BoxContainer.ALIGNMENT_CENTER or price_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("shop coin and price are not centered as one editable row")
		return
	if price_label.get_theme_font("font") == null:
		_fail("shop card font is not stored in the editable scene")
		return

	var options_menu := hud.get_node_or_null("Layout/OptionsMenu") as Control
	if options_menu == null or options_menu.get_node_or_null("PanelArt") == null or options_menu.get_node_or_null("ContinueButton") == null or options_menu.get_node_or_null("TestModeButton") == null or options_menu.get_node_or_null("ResetButton") == null or options_menu.get_node_or_null("QuitButton") == null:
		_fail("editable options menu scene is incomplete")
		return
	var options_dimmer := options_menu.get_node_or_null("Dimmer") as ColorRect
	if options_dimmer == null or options_dimmer.position != Vector2.ZERO or options_dimmer.size != options_menu.size or not is_equal_approx(options_dimmer.color.a, 128.0 / 255.0):
		_fail("options menu dimmer must cover the full screen with one uniform rectangular color")
		return
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	game._input(escape_event)
	var battlefield_world := game.get("battlefield_world") as Node2D
	if not options_menu.visible or not paused or game.can_process() or battlefield_world == null or battlefield_world.can_process():
		_fail("ESC options menu did not pause the game and battlefield")
		return
	if not options_menu.can_process():
		_fail("options menu cannot receive ESC while the game is paused")
		return
	options_menu.call("_unhandled_key_input", escape_event)
	if options_menu.visible or paused:
		_fail("second ESC did not resume and close the options menu")
		return

	if hud.get_node_or_null("Layout/SellZoneFeedback") != null:
		_fail("removed sell feedback must not remain in the HUD")
		return
	var test_panel := hud.get_node_or_null("Layout/TestBalancePanel") as Control
	if test_panel == null or test_panel.get_node_or_null("SidePanel/WaveSpinBox") == null or test_panel.get_node_or_null("EditorOverlay/TableScroll") == null or test_panel.get_node_or_null("EditorOverlay/AddRowButton") == null or test_panel.get_node_or_null("EditorOverlay/ParseInput") == null or test_panel.get_node_or_null("EditorOverlay/ParseButton") == null:
		_fail("editable test balance panel scene is incomplete")
		return
	var edit_cell := EDIT_CELL_SCENE.instantiate() as LineEdit
	if edit_cell == null or edit_cell.get_theme_stylebox("normal") == null or edit_cell.get_theme_font("font") == null:
		_fail("editable balance table cell template is incomplete")
		return
	edit_cell.free()
	var delete_button := DELETE_BUTTON_SCENE.instantiate() as Button
	if delete_button == null or delete_button.get_theme_stylebox("normal") == null:
		_fail("editable balance row delete template is incomplete")
		return
	delete_button.free()

	var tower_slots: Array = game.get("tower_slots")
	if tower_slots.is_empty() or (tower_slots[0] as Node).get_node_or_null("Visual/PlusLabel") == null or (tower_slots[0] as Node).get_node_or_null("CollisionShape2D") == null:
		_fail("editable tower slot scene is incomplete")
		return
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	if monster == null or monster.get_node_or_null("HealthBar") == null:
		_fail("editable monster health bar scene is incomplete")
		return
	monster.free()

	var game_clear_overlay := hud.get_node_or_null("Layout/GameClearOverlay") as PrototypeGameClearOverlay
	if game_clear_overlay == null:
		_fail("editable game-clear overlay is missing")
		return
	var game_clear_title := game_clear_overlay.get_node_or_null("TitleImage") as TextureRect
	var game_clear_restart := game_clear_overlay.get_node_or_null("RestartButton") as Button
	if game_clear_title == null or game_clear_title.texture == null or game_clear_restart == null:
		_fail("game-clear title or restart control is incomplete")
		return
	if game_clear_overlay.visible:
		_fail("game-clear overlay must be hidden before victory")
		return

	# 승리 단계에서는 편집 가능한 타이틀 오버레이만 표시하고 기존 결과 문구를 중복 표시하지 않는다.
	game._set_phase(2)
	await process_frame
	var status_label := hud.get_node("Layout/StatusLabel") as Label
	if not game_clear_overlay.visible:
		_fail("game-clear overlay did not open on victory")
		return
	if not status_label.text.is_empty():
		_fail("legacy victory text is still visible behind the game-clear artwork")
		return
	game_clear_restart.pressed.emit()
	await process_frame
	if game_clear_overlay.visible or int(game.get("phase")) != 0:
		_fail("game-clear restart did not return to the ready phase")
		return

	var game_over_overlay := hud.get_node_or_null("Layout/GameOverOverlay") as Control
	if game_over_overlay == null:
		_fail("editable game-over overlay is missing")
		return
	var game_over_title := game_over_overlay.get_node_or_null("TitleImage") as TextureRect
	var game_over_restart := game_over_overlay.get_node_or_null("RestartButton") as Button
	var game_over_quit := game_over_overlay.get_node_or_null("QuitButton") as Button
	if game_over_title == null or game_over_title.texture == null or game_over_restart == null or game_over_quit == null:
		_fail("game-over title or controls are incomplete")
		return
	if game_over_overlay.visible:
		_fail("game-over overlay must be hidden before defeat")
		return

	# 패배 단계에서 생성형 타이틀 오버레이만 표시되고 이전 상태 문구는 중복되지 않는지 확인한다.
	game._set_phase(3)
	await process_frame
	if not game_over_overlay.visible or game_clear_overlay.visible:
		_fail("game-over overlay did not open on defeat")
		return
	var wave_title_label := hud.get_node("Layout/DayNightHUD/WaveTitleLabel") as Label
	var wave_label := hud.get_node("Layout/DayNightHUD/WaveLabel") as Label
	if not status_label.text.is_empty() or wave_title_label.visible or wave_label.visible:
		_fail("legacy defeat text is still visible behind the game-over artwork")
		return

	game._on_game_over_restart_pressed()
	await process_frame
	if game_over_overlay.visible or int(game.get("phase")) != 0:
		_fail("game-over restart did not return to the ready phase")
		return

	print("Editable HUD layout validation passed: ALL_PLAYER_AND_TEST_UI_SCENES_READY")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
