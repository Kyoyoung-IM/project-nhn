class_name PrototypeShopCard
extends Button

# 상점의 터렛 한 칸을 담당한다.
# 기본 상태에는 투명 배경 스프라이트·이름·가격만 표시하고, 호버하면 효과와 전투 능력치를 펼쳐 보여준다.

const TowerVisualAssetsScript := preload("res://scripts/tower_visual_assets.gd")
const SHOP_CARD_FRAME := preload("res://assets/ui/generated/shop_card_frame_v1.png")

# 카드에 표시할 데이터와 공통 한글 폰트다.
var tower_data: Dictionary = {}
var game_font: Font

# 구매 가능 여부, 현재 선택 여부, 마우스 호버 상태를 그리기에서 사용한다.
var card_available: bool = true
var card_selected: bool = false
var card_interactable: bool = true
var card_affordable: bool = true
var card_hovered: bool = false

# HUD와 같은 보라 판넬·짙은 잉크·금색 강조를 사용해 화면 전체의 시각 언어를 맞춘다.
const CARD_INK := Color("171827")
const CARD_PANEL := Color("443e5a")
const CARD_PANEL_LIGHT := Color("5b5273")
const CARD_CREAM := Color("fff0c5")
const CARD_GOLD := Color("f6c653")
const PRICE_BAR_RECT := Rect2(34.0, 212.0, 238.0, 46.0)


# 네이티브 Button 배경과 텍스트를 비우고 카드 전체를 코드 도형으로 그리도록 준비한다.
func setup(font: Font) -> void:
	game_font = font
	# 상점은 낮·밤 배경 색조와 분리된 HUD이므로 항상 원본 밝기를 유지한다.
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


# 새로 추첨된 터렛 데이터를 복사해 카드 내용을 교체한다.
func set_tower_data(config: Dictionary) -> void:
	tower_data = config.duplicate(true)
	queue_redraw()


# 구매·선택 상태를 갱신한다. disabled는 클릭만 막고 호버 상세 정보는 계속 볼 수 있게 한다.
func set_card_state(available: bool, selected: bool, interactable: bool, affordable: bool) -> void:
	card_available = available
	card_selected = selected
	card_interactable = interactable
	card_affordable = affordable
	disabled = not interactable
	queue_redraw()


# 호버 상태로 바뀌면 기본 카드 대신 상세 카드가 즉시 그려지게 한다.
func _on_mouse_entered() -> void:
	card_hovered = true
	queue_redraw()


# 커서가 빠져나가면 이미지·이름·가격만 있는 기본 상태로 복원한다.
func _on_mouse_exited() -> void:
	card_hovered = false
	queue_redraw()


# 참조 이미지처럼 기본 카드와 호버 상세 카드를 같은 영역에서 전환해 그린다.
func _draw() -> void:
	var border_color := CARD_GOLD if card_selected else (Color("7fe4db") if card_hovered else Color("81799a"))
	# 승인된 생성형 프레임을 카드 전체에 먼저 그리고 선택·호버 상태만 얇은 색 테두리로 덧댄다.
	draw_texture_rect(SHOP_CARD_FRAME, Rect2(Vector2.ZERO, size), false)
	draw_style_box(_make_card_style(Color.TRANSPARENT, border_color, 12, 3), Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0))
	if tower_data.is_empty() or game_font == null:
		_draw_centered_text("상점 준비 중", 145.0, 24, Color("d8e7ef"))
		return

	_draw_default_state()
	if not card_available:
		draw_style_box(_make_card_style(Color(0.05, 0.045, 0.09, 0.82), CARD_INK, 16, 5), Rect2(0.0, 0.0, size.x, size.y - 7.0))
		_draw_centered_text("구매 완료", size.y * 0.56, 27, Color("d7dee5"))

	# 호버 상세는 구매 완료·골드 부족 레이어보다 나중에 그려 어떤 카드에서도 정보를 최상단에 표시한다.
	if card_hovered:
		# 기본 이미지·이름·가격까지 카드 전체를 80% 딤드한 뒤 상세 정보만 최상단에 다시 그린다.
		draw_style_box(_make_card_style(Color(0.025, 0.02, 0.055, 0.80), Color.TRANSPARENT, 16, 0), Rect2(0.0, 0.0, size.x, size.y - 7.0))
		_draw_hover_state()


# 기본 상태는 별도 이미지 판넬 없이 승인된 Tier 1 스프라이트와 이름·가격만 배치한다.
func _draw_default_state() -> void:
	_draw_tower_sprite()
	_draw_centered_text(str(tower_data.get("display_name", "터렛")), 190.0, 24, CARD_CREAM)
	var price_color := CARD_GOLD if card_affordable else Color("a0a0aa")
	# 골드가 부족하면 카드 전체가 아니라 생성 프레임의 금화·가격 영역만 회색으로 가린다.
	if not card_affordable:
		draw_style_box(_make_card_style(Color(0.22, 0.22, 0.25, 0.86), Color("777783"), 9, 2), Rect2(48.0, 214.0, size.x - 66.0, 42.0))
	_draw_centered_price("%d G" % int(tower_data.get("base_price", 0)), 22, price_color)


# 호버 상태는 딤드된 카드 위에 가격과 이미지를 제외한 이름·효과·핵심 능력치만 중앙 배치한다.
func _draw_hover_state() -> void:
	_draw_centered_text(str(tower_data.get("display_name", "터렛")), 60.0, 29, CARD_CREAM)
	draw_line(Vector2(31.0, 78.0), Vector2(size.x - 31.0, 78.0), Color("81799a"), 3.0)
	_draw_centered_text(_effect_description(), 120.0, 21, Color("fff1dc"))
	_draw_centered_text("공격력  %.0f" % float(tower_data.get("damage", 0.0)), 165.0, 21, Color("f1eafa"))
	_draw_centered_text("공격 주기  %.2f초" % float(tower_data.get("attack_interval_sec", 0.0)), 202.0, 20, Color("d9d0e8"))
	_draw_centered_text("사거리  %.0f" % float(tower_data.get("range_px", 0.0)), 238.0, 20, Color("d9d0e8"))


# 터렛 유형별 효과를 플레이어가 바로 이해할 수 있는 짧은 문장으로 변환한다.
func _effect_description() -> String:
	var turret_type := str(tower_data.get("type", "RANGED"))
	match turret_type:
		"MELEE":
			return "효과 · 근거리 고화력 공격"
		"DOT":
			return "효과 · %.1f초 지속 피해" % float(tower_data.get("cc_duration", 0.0))
		"STUN":
			return "효과 · %.2f초 기절" % float(tower_data.get("cc_duration", 0.0))
		"SLOW":
			return "효과 · %.0f%% 이동 둔화" % (float(tower_data.get("cc_value", 0.0)) * 100.0)
		_:
			return "효과 · 장거리 단일 공격"


# 카드 상단에는 타입별 Tier 1 본체를 투명 배경 그대로 크게 보여준다.
# DOT 불꽃도 전장과 같은 별도 텍스처를 겹쳐 향후 이펙트 교체 경로를 통일한다.
func _draw_tower_sprite() -> void:
	var turret_type := str(tower_data.get("type", "RANGED"))
	var body_size := 158.0
	var body_rect := Rect2((size.x - body_size) * 0.5, 174.0 - body_size, body_size, body_size)
	draw_texture_rect(TowerVisualAssetsScript.body_texture(turret_type, 1), body_rect, false)
	if turret_type == "DOT":
		var flame_size := 80.0
		var flame_rect := Rect2((size.x - flame_size) * 0.5, 79.0 - flame_size, flame_size, flame_size)
		draw_texture_rect(TowerVisualAssetsScript.dot_flame_texture(1), flame_rect, false)


# draw_string의 기준선을 숨기고 카드 폭 전체를 사용해 한 줄 텍스트를 가운데 정렬한다.
func _draw_centered_text(value: String, baseline_y: float, font_size: int, color: Color) -> void:
	# 작은 그림자를 먼저 그려 밝은 이미지 영역에서도 둥근 폰트의 외곽이 무너지지 않게 한다.
	draw_string(game_font, Vector2(2.0, baseline_y + 3.0), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(0.04, 0.03, 0.07, 0.86))
	draw_string(game_font, Vector2(0.0, baseline_y), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)


# 가격 문자열의 실제 픽셀 폭을 측정해 카드 전체의 기하학적 중심에 고정한다.
func _draw_centered_price(value: String, font_size: int, price_color: Color) -> void:
	var ascent := game_font.get_ascent(font_size)
	var descent := game_font.get_descent(font_size)
	var baseline := PRICE_BAR_RECT.position.y + (PRICE_BAR_RECT.size.y + ascent - descent) * 0.5
	draw_string(game_font, Vector2(PRICE_BAR_RECT.position.x + 2.0, baseline + 3.0), value, HORIZONTAL_ALIGNMENT_CENTER, PRICE_BAR_RECT.size.x, font_size, Color(0.04, 0.03, 0.07, 0.86))
	draw_string(game_font, Vector2(PRICE_BAR_RECT.position.x, baseline), value, HORIZONTAL_ALIGNMENT_CENTER, PRICE_BAR_RECT.size.x, font_size, price_color)


# 카드 내부에서 반복 사용하는 둥근 StyleBoxFlat을 생성한다.
func _make_card_style(background_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
