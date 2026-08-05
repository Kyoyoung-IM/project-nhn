extends SceneTree

# 편집 가능한 HUD 씬을 실제 게임 루트에 붙여 필수 노드와 카드 입력 영역을 검증한다.

const GAME_SCENE := preload("res://scenes/prototype_game.tscn")


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
	var shop_ui := hud.get_node_or_null("Layout/ShopUI") as Control
	if shop_ui == null:
		_fail("editable ShopUI node is missing")
		return
	for card_number in range(1, 6):
		var card := shop_ui.get_node_or_null("ShopCard%d" % card_number) as Button
		if card == null or card.get_node_or_null("Frame") == null or card.get_node_or_null("PriceLabel") == null:
			_fail("editable shop card %d is incomplete" % card_number)
			return
		if card.size != Vector2(306.0, 270.0):
			_fail("shop card %d size changed unexpectedly" % card_number)
			return

	var price_label := shop_ui.get_node("ShopCard1/PriceLabel") as Label
	if price_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or price_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("shop price label is not centered inside the editable price area")
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
	if not game_over_overlay.visible:
		_fail("game-over overlay did not open on defeat")
		return
	var status_label := hud.get_node("Layout/StatusLabel") as Label
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

	print("Editable HUD layout validation passed: SCENE_NODES_SHOP_AND_GAME_OVER_READY")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
