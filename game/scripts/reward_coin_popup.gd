class_name PrototypeRewardCoinPopup
extends Node2D

# 몬스터가 쓰러진 위치에서 새 UI 금화 이미지가 짧게 튀어 오르고 사라진다.

const LIFE_TIME_SEC := 0.72
const RISE_DISTANCE_PX := 52.0
const COIN_TEXTURE := preload("res://assets/ui/images/coin.png")

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


# 상점과 같은 금화 이미지를 사용해 재화 피드백의 모양을 통일한다.
func _draw() -> void:
	draw_texture_rect(COIN_TEXTURE, Rect2(-18.0, -18.0, 36.0, 36.0), false)
