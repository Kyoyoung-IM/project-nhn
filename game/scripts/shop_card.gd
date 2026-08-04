class_name PrototypeShopCard
extends Button

# 상점의 터렛 한 칸을 담당한다.
# 기본 상태에는 이미지형 도형·이름·가격만 표시하고, 호버하면 효과와 전투 능력치를 펼쳐 보여준다.

# 카드에 표시할 데이터와 공통 한글 폰트다.
var tower_data: Dictionary = {}
var game_font: Font

# 구매 가능 여부, 현재 선택 여부, 마우스 호버 상태를 그리기에서 사용한다.
var card_available: bool = true
var card_selected: bool = false
var card_interactable: bool = true
var card_hovered: bool = false

# HUD와 같은 보라 판넬·짙은 잉크·금색 강조를 사용해 화면 전체의 시각 언어를 맞춘다.
const CARD_INK := Color("171827")
const CARD_PANEL := Color("443e5a")
const CARD_PANEL_LIGHT := Color("5b5273")
const CARD_CREAM := Color("fff0c5")
const CARD_GOLD := Color("f6c653")


# 네이티브 Button 배경과 텍스트를 비우고 카드 전체를 코드 도형으로 그리도록 준비한다.
func setup(font: Font) -> void:
	game_font = font
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
func set_card_state(available: bool, selected: bool, interactable: bool) -> void:
	card_available = available
	card_selected = selected
	card_interactable = interactable
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
	# 아래쪽 그림자와 밝은 안쪽 테두리로 카드가 판넬 위에 놓인 물건처럼 보이게 한다.
	draw_style_box(_make_card_style(Color(0.03, 0.025, 0.06, 0.82), Color.TRANSPARENT, 16, 0), Rect2(3.0, 8.0, size.x - 6.0, size.y - 4.0))
	draw_style_box(_make_card_style(CARD_PANEL, CARD_INK, 16, 6), Rect2(0.0, 0.0, size.x, size.y - 7.0))
	draw_style_box(_make_card_style(Color.TRANSPARENT, border_color, 12, 3), Rect2(7.0, 7.0, size.x - 14.0, size.y - 21.0))
	if tower_data.is_empty() or game_font == null:
		_draw_centered_text("상점 준비 중", 145.0, 24, Color("d8e7ef"))
		return

	if card_hovered:
		_draw_hover_state()
	else:
		_draw_default_state()

	if not card_available:
		draw_style_box(_make_card_style(Color(0.05, 0.045, 0.09, 0.82), CARD_INK, 16, 5), Rect2(0.0, 0.0, size.x, size.y - 7.0))
		_draw_centered_text("구매 완료", size.y * 0.56, 27, Color("d7dee5"))
	elif not card_interactable:
		draw_style_box(_make_card_style(Color(0.05, 0.045, 0.09, 0.48), Color.TRANSPARENT, 16, 0), Rect2(0.0, 0.0, size.x, size.y - 7.0))


# 기본 상태는 큰 터렛 이미지형 도형 아래에 이름과 가격만 배치한다.
func _draw_default_state() -> void:
	var tower_color := Color(str(tower_data.get("color_hex", "68d8c1")))
	var image_rect := Rect2(13.0, 13.0, size.x - 26.0, 156.0)
	draw_style_box(_make_card_style(tower_color.darkened(0.48), CARD_INK, 11, 4), image_rect)
	draw_style_box(_make_card_style(Color(1.0, 1.0, 1.0, 0.08), Color.TRANSPARENT, 8, 0), Rect2(20.0, 20.0, size.x - 40.0, 44.0))
	_draw_tower_icon(Vector2(size.x * 0.5, 91.0), tower_color, 1.5)
	_draw_centered_text(str(tower_data.get("display_name", "터렛")), 205.0, 26, CARD_CREAM)
	draw_style_box(_make_card_style(Color("5b4935"), Color("d6a93f"), 12, 3), Rect2(73.0, 220.0, size.x - 146.0, 38.0))
	draw_circle(Vector2(size.x * 0.5 - 42.0, 239.0), 7.0, CARD_GOLD)
	_draw_centered_text("%d G" % int(tower_data.get("base_price", 0)), 248.0, 22, CARD_GOLD)


# 호버 상태는 카드 상단 이름, 흐리게 남은 이미지, 효과 설명과 핵심 능력치를 표시한다.
func _draw_hover_state() -> void:
	var tower_color := Color(str(tower_data.get("color_hex", "68d8c1")))
	draw_style_box(_make_card_style(Color("603326"), CARD_INK, 11, 4), Rect2(13.0, 13.0, size.x - 26.0, 126.0))
	_draw_centered_text(str(tower_data.get("display_name", "터렛")), 43.0, 26, CARD_CREAM)
	_draw_tower_icon(Vector2(size.x * 0.5, 93.0), tower_color.darkened(0.18), 1.05)
	draw_line(Vector2(25.0, 150.0), Vector2(size.x - 25.0, 150.0), Color("81799a"), 3.0)
	_draw_centered_text(_effect_description(), 178.0, 20, Color("fff1dc"))
	_draw_centered_text("공격력  %.0f" % float(tower_data.get("damage", 0.0)), 207.0, 19, Color("e5ddf3"))
	_draw_centered_text("주기 %.2fs   사거리 %.0f" % [float(tower_data.get("attack_interval_sec", 0.0)), float(tower_data.get("range_px", 0.0))], 232.0, 18, Color("c9c0db"))
	_draw_centered_text("%d G" % int(tower_data.get("base_price", 0)), 258.0, 21, CARD_GOLD)


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


# 실제 이미지 에셋이 추가되기 전까지 터렛 타입을 구분하는 더미 도형을 이미지 영역에 그린다.
func _draw_tower_icon(center: Vector2, color: Color, icon_scale: float) -> void:
	draw_circle(center, 27.0 * icon_scale, Color("203342"))
	draw_circle(center, 21.0 * icon_scale, color)
	var turret_type := str(tower_data.get("type", "RANGED"))
	match turret_type:
		"MELEE":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-6.0, -34.0) * icon_scale,
				center + Vector2(6.0, -34.0) * icon_scale,
				center + Vector2(13.0, -3.0) * icon_scale,
				center + Vector2(-12.0, -3.0) * icon_scale,
			]), color.lightened(0.28))
		"DOT":
			draw_circle(center + Vector2(0.0, -17.0) * icon_scale, 12.0 * icon_scale, color.lightened(0.3))
			draw_circle(center + Vector2(0.0, -17.0) * icon_scale, 5.0 * icon_scale, Color("2a1738"))
		"STUN":
			draw_line(center + Vector2(-7.0, -34.0) * icon_scale, center + Vector2(5.0, -21.0) * icon_scale, Color("f3fbff"), 5.0 * icon_scale)
			draw_line(center + Vector2(5.0, -21.0) * icon_scale, center + Vector2(-5.0, -8.0) * icon_scale, Color("f3fbff"), 5.0 * icon_scale)
		"SLOW":
			draw_line(center + Vector2(0.0, -35.0) * icon_scale, center + Vector2(0.0, -4.0) * icon_scale, Color("efffff"), 4.0 * icon_scale)
			draw_line(center + Vector2(-13.0, -27.0) * icon_scale, center + Vector2(13.0, -12.0) * icon_scale, Color("efffff"), 4.0 * icon_scale)
		_:
			draw_rect(Rect2(center + Vector2(-8.0, -36.0) * icon_scale, Vector2(16.0, 34.0) * icon_scale), color.lightened(0.35), true)


# draw_string의 기준선을 숨기고 카드 폭 전체를 사용해 한 줄 텍스트를 가운데 정렬한다.
func _draw_centered_text(value: String, baseline_y: float, font_size: int, color: Color) -> void:
	# 작은 그림자를 먼저 그려 밝은 이미지 영역에서도 둥근 폰트의 외곽이 무너지지 않게 한다.
	draw_string(game_font, Vector2(2.0, baseline_y + 3.0), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(0.04, 0.03, 0.07, 0.86))
	draw_string(game_font, Vector2(0.0, baseline_y), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)


# 카드 내부에서 반복 사용하는 둥근 StyleBoxFlat을 생성한다.
func _make_card_style(background_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
