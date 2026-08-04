class_name PrototypeBattlefieldWorld
extends Node2D

# 고정 HUD와 상점 아래에서 수직 이동하는 배경 전용 그리기 노드다.
# 전투 오브젝트와 분리되어 상점 카드 사이에서도 배경만 끊김 없이 이어진다.

const DAY_ENVIRONMENT_BACKGROUND := preload("res://assets/backgrounds/casual_rpg_mine_day_v8.png")
const NIGHT_ENVIRONMENT_BACKGROUND := preload("res://assets/backgrounds/casual_rpg_mine_night_v8.png")

# 세로형 v8 원본을 화면 폭에 맞춰 가로·세로 동일한 배율로 확대한다.
# 카메라는 확대된 한 장의 배경을 세로로 잘라 보여주므로 플랫폼과 원형 요소가 찌그러지지 않는다.
const REFERENCE_VIEWPORT_WIDTH := 1920.0
const BACKGROUND_SOURCE_SIZE := Vector2(887.0, 1774.0)
const BACKGROUND_UNIFORM_SCALE := REFERENCE_VIEWPORT_WIDTH / BACKGROUND_SOURCE_SIZE.x
const BATTLEFIELD_EXTENDED_HEIGHT := BACKGROUND_SOURCE_SIZE.y * BACKGROUND_UNIFORM_SCALE

# v8 낮/밤 원본은 v7의 플랫폼 구도를 보존하므로 같은 좌표·배율로 그려 추가 변형을 금지한다.
const NIGHT_VERTICAL_SCALE := 1.0
const NIGHT_VERTICAL_OFFSET_SOURCE_PX := 0.0

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
	draw_texture_rect(
		texture,
		Rect2(0.0, 0.0, REFERENCE_VIEWPORT_WIDTH, BATTLEFIELD_EXTENDED_HEIGHT),
		false,
		modulation
	)


# v8 밤 배경은 낮과 동일 좌표계로 그려 교차 페이드 중에도 플랫폼이 움직이지 않게 한다.
func _draw_aligned_night_background(modulation: Color) -> void:
	draw_texture_rect(
		NIGHT_ENVIRONMENT_BACKGROUND,
		Rect2(0.0, 0.0, REFERENCE_VIEWPORT_WIDTH, BATTLEFIELD_EXTENDED_HEIGHT),
		false,
		modulation
	)
