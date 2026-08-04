class_name PrototypeRewardCoinPopup
extends Node2D

# 몬스터가 쓰러진 위치에서 짧게 튀어 오르고 사라지는 코드 기반 보상 동전이다.

const LIFE_TIME_SEC := 0.72
const RISE_DISTANCE_PX := 52.0

var elapsed_sec: float = 0.0
var origin_position := Vector2.ZERO


# 처치 좌표를 기준점으로 저장하고 전투 오브젝트보다 앞에서 보이게 한다.
func setup(spawn_position: Vector2) -> void:
	origin_position = spawn_position
	position = spawn_position
	z_index = 40
	add_to_group("reward_coin_popups")
	queue_redraw()


# 초반에는 통통 튀고 후반에는 위로 이동하면서 자연스럽게 투명해진다.
func _process(delta: float) -> void:
	elapsed_sec += delta
	var progress := clampf(elapsed_sec / LIFE_TIME_SEC, 0.0, 1.0)
	var bounce_x := sin(progress * PI * 2.0) * 7.0 * (1.0 - progress)
	var rise_y := -RISE_DISTANCE_PX * ease(progress, -1.8)
	position = origin_position + Vector2(bounce_x, rise_y)
	var pop_scale := 0.65 + sin(minf(progress * 2.0, 1.0) * PI * 0.5) * 0.45
	scale = Vector2.ONE * pop_scale
	modulate.a = 1.0 - smoothstep(0.58, 1.0, progress)
	if elapsed_sec >= LIFE_TIME_SEC:
		queue_free()


# 작은 금화가 화면 크기와 관계없이 읽히도록 외곽선, 금색 면과 반사광만 단순하게 그린다.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color("5c3a16"))
	draw_circle(Vector2.ZERO, 10.0, Color("f6c653"))
	draw_circle(Vector2.ZERO, 6.5, Color("d99b2f"))
	draw_line(Vector2(-2.0, -6.0), Vector2(-5.0, 1.0), Color("fff2a6"), 2.5)
	draw_arc(Vector2.ZERO, 8.0, -PI * 0.35, PI * 0.25, 10, Color("ffe98a"), 2.0)
