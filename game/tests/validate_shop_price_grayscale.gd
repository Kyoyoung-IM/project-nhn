extends SceneTree

# 구매 후 리롤로 골드 부족 상태가 갱신될 때 딤드 없이 가격의 금색 픽셀만 회색화하는지 검증한다.

const SHOP_CARD_SCENE := preload("res://scenes/ui/shop_card.tscn")
const PRICE_GOLD_GRAYSCALE_PARAMETER := &"price_gold_grayscale"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card := SHOP_CARD_SCENE.instantiate() as PrototypeShopCard
	root.add_child(card)
	await process_frame

	if card.get_node_or_null("PriceDim") != null:
		_fail("legacy price dim overlay still exists")
		return

	var frame := card.get_node("Frame") as TextureRect
	var price_material := frame.material as ShaderMaterial
	if price_material == null:
		_fail("price grayscale shader material is missing")
		return

	# 첫 카드 구매 상태에서는 구매 완료 오버레이만 사용하고 가격 회색화는 끈다.
	card.set_card_state(false, false, false, false)
	if not is_zero_approx(float(price_material.get_shader_parameter(PRICE_GOLD_GRAYSCALE_PARAMETER))):
		_fail("price grayscale remained enabled on a purchased card")
		return

	# 리롤로 새 카드가 들어온 뒤 골드가 부족하면 가격의 금색 픽셀만 회색화한다.
	card.set_card_state(true, false, false, false)
	if not is_equal_approx(float(price_material.get_shader_parameter(PRICE_GOLD_GRAYSCALE_PARAMETER)), 1.0):
		_fail("price gold grayscale was not enabled for an unaffordable rerolled card")
		return

	# 기절 포탑처럼 구매 가능한 저가 카드는 원본 금색 가격을 유지한다.
	card.set_card_state(true, false, true, true)
	if not is_zero_approx(float(price_material.get_shader_parameter(PRICE_GOLD_GRAYSCALE_PARAMETER))):
		_fail("price gold grayscale remained enabled on an affordable rerolled card")
		return

	print("Shop price grayscale validation passed: GOLD_PIXELS_ONLY_WITHOUT_DIM_OVERLAY")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
