class_name PrototypeBattlefieldWorld
extends Node2D

# 고정 HUD와 상점 아래에서 수직 이동하는 배경 전용 그리기 노드다.
# 전투 오브젝트와 분리되어 상점 카드 사이에서도 배경만 끊김 없이 이어진다.

const DAY_ENVIRONMENT_BACKGROUND := preload("res://assets/backgrounds/bg.png")
const NIGHT_ENVIRONMENT_BACKGROUND := preload("res://assets/backgrounds/bg_night.png")

# 세로형 낮·밤 원본을 화면 폭에 맞춰 가로·세로 동일한 배율로 확대한다.
# 카메라는 확대된 한 장의 배경을 세로로 잘라 보여주므로 플랫폼과 원형 요소가 찌그러지지 않는다.
const REFERENCE_VIEWPORT_WIDTH := 1920.0
const BACKGROUND_SOURCE_SIZE := Vector2(887.0, 1774.0)
const BACKGROUND_UNIFORM_SCALE := REFERENCE_VIEWPORT_WIDTH / BACKGROUND_SOURCE_SIZE.x
const BATTLEFIELD_EXTENDED_HEIGHT := BACKGROUND_SOURCE_SIZE.y * BACKGROUND_UNIFORM_SCALE

# 낮/밤 원본은 같은 플랫폼 구도이므로 같은 좌표·배율로 그려 추가 변형을 금지한다.
const NIGHT_VERTICAL_SCALE := 1.0
const NIGHT_VERTICAL_OFFSET_SOURCE_PX := 0.0

# 균일 축소 카메라가 만드는 좌우 여백은 원본 가장자리 일부를 같은 배율로 거울 연장해 채운다.
# 원본 전체를 가로로 늘리지 않으므로 배경의 종횡비와 플랫폼 비율은 유지된다.
var horizontal_extension_px: float = 0.0:
	set(value):
		horizontal_extension_px = maxf(0.0, value)
		queue_redraw()

# 낮 0.0과 밤 1.0 사이의 배경 교차 페이드 값이다.
var night_visual_amount: float = 0.0:
	set(value):
		night_visual_amount = clampf(value, 0.0, 1.0)
		queue_redraw()

# 같은 구도의 낮·밤 배경을 교차시켜 그린다.
func _draw() -> void:
	_draw_environment_background(DAY_ENVIRONMENT_BACKGROUND, Color.WHITE)
	if night_visual_amount > 0.001:
		_draw_aligned_night_background(Color(1.0, 1.0, 1.0, night_visual_amount))


# 전체 세로형 원본을 한 번에 균일 축척해 소품과 지형의 원래 비율을 유지한다.
func _draw_environment_background(texture: Texture2D, modulation: Color) -> void:
	_draw_horizontal_edge_extensions(texture, modulation)
	draw_texture_rect(
		texture,
		Rect2(0.0, 0.0, REFERENCE_VIEWPORT_WIDTH, BATTLEFIELD_EXTENDED_HEIGHT),
		false,
		modulation
	)


# 밤 배경은 낮과 동일 좌표계로 그려 교차 페이드 중에도 플랫폼이 움직이지 않게 한다.
func _draw_aligned_night_background(modulation: Color) -> void:
	_draw_horizontal_edge_extensions(NIGHT_ENVIRONMENT_BACKGROUND, modulation)
	draw_texture_rect(
		NIGHT_ENVIRONMENT_BACKGROUND,
		Rect2(0.0, 0.0, REFERENCE_VIEWPORT_WIDTH, BATTLEFIELD_EXTENDED_HEIGHT),
		false,
		modulation
	)


# 원본의 좌우 끝 조각을 원본과 동일한 균일 배율로 그린 뒤 수평 반전해 중앙 이미지와 이음새를 맞춘다.
func _draw_horizontal_edge_extensions(texture: Texture2D, modulation: Color) -> void:
	if horizontal_extension_px <= 0.0:
		return
	var source_extension_width := horizontal_extension_px / BACKGROUND_UNIFORM_SCALE
	var source_height := BACKGROUND_SOURCE_SIZE.y

	# 왼쪽: 원본 x=0이 중앙 이미지의 x=0 이음새에 그대로 닿도록 바깥쪽으로 반전한다.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(
		texture,
		Rect2(0.0, 0.0, horizontal_extension_px, BATTLEFIELD_EXTENDED_HEIGHT),
		Rect2(0.0, 0.0, source_extension_width, source_height),
		modulation
	)

	# 오른쪽: 원본 마지막 픽셀이 중앙 이미지의 오른쪽 이음새에 닿도록 같은 방식으로 반전한다.
	var right_source_x := BACKGROUND_SOURCE_SIZE.x - source_extension_width
	var right_draw_x := REFERENCE_VIEWPORT_WIDTH - horizontal_extension_px
	draw_set_transform(Vector2(REFERENCE_VIEWPORT_WIDTH * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(
		texture,
		Rect2(right_draw_x, 0.0, horizontal_extension_px, BATTLEFIELD_EXTENDED_HEIGHT),
		Rect2(right_source_x, 0.0, source_extension_width, source_height),
		modulation
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
