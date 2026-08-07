extends SceneTree

# 구매 후 리롤로 골드 부족 상태가 갱신될 때 딤드 없이 가격의 금색 픽셀만 회색화하는지 검증한다.

const SHOP_CARD_SCENE := preload("res://scenes/ui/shop_card.tscn")
const GAME_SCENE := preload("res://scenes/prototype_game.tscn")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card := SHOP_CARD_SCENE.instantiate() as PrototypeShopCard
	root.add_child(card)
	await process_frame

	if card.get_node_or_null("PriceDim") != null:
		_fail("legacy price dim overlay still exists")
		return

	var price_coin := card.get_node("PriceRow/CoinIcon") as TextureRect
	var price_label := card.get_node("PriceRow/PriceLabel") as Label
	if price_coin == null or price_label == null:
		_fail("image-based coin and price row are missing")
		return

	# 첫 카드 구매 상태에서는 구매 완료 오버레이만 사용하고 가격 회색화는 끈다.
	card.set_card_state(false, false, false, false)
	if price_coin.modulate != Color.WHITE:
		_fail("price coin remained grayscale on a purchased card")
		return

	# 리롤로 새 카드가 들어온 뒤 골드가 부족하면 가격의 금색 픽셀만 회색화한다.
	card.set_card_state(true, false, false, false)
	if price_coin.modulate == Color.WHITE or price_label.get_theme_color("font_color") != card.unaffordable_price_color:
		_fail("image coin and price text were not grayed for an unaffordable rerolled card")
		return

	# 기절 포탑처럼 구매 가능한 저가 카드는 원본 금색 가격을 유지한다.
	card.set_card_state(true, false, true, true)
	if price_coin.modulate != Color.WHITE or price_label.get_theme_color("font_color") != card.affordable_price_color:
		_fail("image coin and price text remained grayscale on an affordable rerolled card")
		return

	card.queue_free()

	# 일반 플레이의 몬스터 처치 보상으로 골드가 가격 이상이 되는 즉시 카드가 원래 금색으로 복원되어야 한다.
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var reward_card := game.shop_cards[0] as PrototypeShopCard
	var reward_price_coin := reward_card.get_node("PriceRow/CoinIcon") as TextureRect
	var reward_tower_data: Dictionary = game.database.get_turret_data(game.shop_turret_ids[0])
	var reward_tower_cost := int(reward_tower_data.get("base_price", 0))
	if reward_tower_cost <= 0 or reward_price_coin == null:
		_fail("reward transition test could not prepare a priced shop card")
		return

	game.gold = reward_tower_cost - 1
	game._update_shop_cards()
	if reward_price_coin.modulate == Color.WHITE:
		_fail("price coin was not grayed before the monster reward")
		return

	var reward_monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	reward_monster.reward_gold = 1
	game.battlefield_world.add_child(reward_monster)
	game.monsters.append(reward_monster)
	game._on_monster_defeated(reward_monster)
	if game.gold != reward_tower_cost:
		_fail("monster reward did not reach the shop card price")
		return
	if reward_price_coin.modulate != Color.WHITE:
		_fail("price coin remained grayscale after the monster reward made the card affordable")
		return

	print("Shop price grayscale validation passed: GOLD_PIXELS_AND_REWARD_RESTORE")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
