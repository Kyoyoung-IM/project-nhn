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

	print("Editable HUD layout validation passed: SCENE_NODES_AND_SHOP_INPUT_READY")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
