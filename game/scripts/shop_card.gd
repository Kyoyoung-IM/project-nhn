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
	var border_color := Color("ffd86a") if card_selected else (Color("e8f6ff") if card_hovered else Color("17627e"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a2733"), true)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 4.0)
	if tower_data.is_empty() or game_font == null:
		_draw_centered_text("상점 준비 중", 145.0, 24, Color("d8e7ef"))
		return

	if card_hovered:
		_draw_hover_state()
	else:
		_draw_default_state()

	if not card_available:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08, 0.72), true)
		_draw_centered_text("구매 완료", size.y * 0.56, 27, Color("d7dee5"))
	elif not card_interactable:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08, 0.38), true)


# 기본 상태는 큰 터렛 이미지형 도형 아래에 이름과 가격만 배치한다.
func _draw_default_state() -> void:
	var tower_color := Color(str(tower_data.get("color_hex", "68d8c1")))
	var image_rect := Rect2(12.0, 12.0, size.x - 24.0, 174.0)
	draw_rect(image_rect, tower_color.darkened(0.2), true)
	draw_rect(image_rect, Color("123745"), false, 3.0)
	_draw_tower_icon(Vector2(size.x * 0.5, 103.0), tower_color, 1.65)
	_draw_centered_text(str(tower_data.get("display_name", "터렛")), 222.0, 26, Color("f2f7fa"))
	draw_circle(Vector2(size.x * 0.5 - 44.0, 255.0), 7.0, Color("f5d76e"))
	_draw_centered_text("%d G" % int(tower_data.get("base_price", 0)), 263.0, 23, Color("f5d76e"))


# 호버 상태는 카드 상단 이름, 흐리게 남은 이미지, 효과 설명과 핵심 능력치를 표시한다.
func _draw_hover_state() -> void:
	var tower_color := Color(str(tower_data.get("color_hex", "68d8c1")))
	draw_rect(Rect2(12.0, 12.0, size.x - 24.0, 132.0), Color("4b2517"), true)
	_draw_centered_text(str(tower_data.get("display_name", "터렛")), 39.0, 26, Color.WHITE)
	_draw_tower_icon(Vector2(size.x * 0.5, 91.0), tower_color.darkened(0.42), 1.2)
	draw_line(Vector2(24.0, 150.0), Vector2(size.x - 24.0, 150.0), Color("345667"), 2.0)
	_draw_centered_text(_effect_description(), 177.0, 21, Color("fff1dc"))
	_draw_centered_text("HP %.0f   ATK %.0f" % [float(tower_data.get("max_hp", 0.0)), float(tower_data.get("damage", 0.0))], 207.0, 19, Color("d9e6ec"))
	_draw_centered_text("주기 %.2fs   사거리 %.0f" % [float(tower_data.get("attack_interval_sec", 0.0)), float(tower_data.get("range_px", 0.0))], 234.0, 18, Color("bdced7"))
	_draw_centered_text("%d G" % int(tower_data.get("base_price", 0)), 263.0, 21, Color("f5d76e"))


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
	draw_string(game_font, Vector2(0.0, baseline_y), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
