extends SceneTree

# 구매 후 리롤로 골드 부족 상태가 갱신될 때 가격 딤드가 동전 중간에서 잘리지 않는지 검증한다.

const SHOP_CARD_SCENE := preload("res://scenes/ui/shop_card.tscn")
const PRICE_SECTION_BOUNDS := Rect2(34.0, 205.0, 242.0, 53.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card := SHOP_CARD_SCENE.instantiate() as PrototypeShopCard
	root.add_child(card)
	await process_frame

	# 첫 카드 구매 상태에서는 전체 구매 완료 딤드가 가격 딤드를 대신한다.
	card.set_card_state(false, false, false, false)
	if card.price_dim.visible:
		_fail("price dim remained visible on a purchased card")
		return

	# 리롤로 새 카드가 들어온 뒤 골드가 부족하면 가격 영역만 딤드한다.
	card.set_card_state(true, false, false, false)
	if not card.price_dim.visible:
		_fail("price dim was not shown for an unaffordable rerolled card")
		return
	if card.price_dim.get_rect() != PRICE_SECTION_BOUNDS:
		_fail("price dim does not cover the full coin and price capsule")
		return

	# 기절 포탑처럼 구매 가능한 저가 카드는 가격 딤드를 표시하지 않는다.
	card.set_card_state(true, false, true, true)
	if card.price_dim.visible:
		_fail("price dim remained visible on an affordable rerolled card")
		return

	print("Shop price dim validation passed: FULL_PRICE_SECTION_WITHOUT_CLIPPED_COIN")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
