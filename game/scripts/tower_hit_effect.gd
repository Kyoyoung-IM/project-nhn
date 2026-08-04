class_name PrototypeTowerHitEffect
extends Node2D

# 히트스캔 공격의 판정 위치에 붙는 MELEE 할퀴기와 STUN 낙뢰·헤롱헤롱 연출이다.
const MELEE_DURATION_SEC := 0.24
const STUN_DURATION_SEC := 1.0

# 히트스캔은 판정 자체는 즉시 처리하고, 이 이미지만 대상 위치에 짧게 재생한다.
const MELEE_SLASH_TEXTURE := preload("res://assets/combat_vfx/hit_melee_slash_v2.png")
const STUN_LIGHTNING_TEXTURE := preload("res://assets/combat_vfx/hit_stun_lightning_v2.png")

var effect_type: String = "MELEE"
var remaining_sec: float = 0.0
var total_duration_sec: float = MELEE_DURATION_SEC
var tier: int = 1


func setup(attack_type: String, attack_tier: int) -> void:
	effect_type = attack_type
	tier = clampi(attack_tier, 1, 4)
	total_duration_sec = STUN_DURATION_SEC if effect_type == "STUN" else MELEE_DURATION_SEC
	remaining_sec = total_duration_sec
	z_index = 45
	add_to_group("tower_hit_effects")
	queue_redraw()


func _process(delta: float) -> void:
	remaining_sec = maxf(0.0, remaining_sec - delta)
	queue_redraw()
	if remaining_sec <= 0.0:
		queue_free()


func _draw() -> void:
	var progress := 1.0 - remaining_sec / total_duration_sec
	if effect_type == "STUN":
		_draw_stun_effect(progress)
	else:
		_draw_melee_slashes(progress)


# 세 줄의 발톱 자국이 빠르게 벌어졌다 사라지며 근접 히트스캔의 피격 위치를 명확히 보여준다.
func _draw_melee_slashes(progress: float) -> void:
	var alpha := 1.0 - progress
	var scale_factor := (0.82 + progress * 0.28) * (1.0 + float(tier - 1) * 0.05)
	var draw_size := Vector2(123.0, 138.0) * scale_factor
	draw_texture_rect(
		MELEE_SLASH_TEXTURE,
		Rect2(-draw_size * 0.5, draw_size),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)


# 작은 먹구름부터 지면 충돌점까지 이어지는 생성 낙뢰로 기절 타격을 표시한다.
# 지속되는 헤롱헤롱 별은 몬스터 상태에 직접 그려 실제 기절 시간과 동기화한다.
func _draw_stun_effect(progress: float) -> void:
	# Hold the lightning at full opacity before fading so one complete bolt is
	# visible even when combat is accelerated.
	var fade_progress := clampf((progress - 0.55) / 0.45, 0.0, 1.0)
	var lightning_alpha := 1.0 - fade_progress
	var lightning_size := Vector2(147.0, 213.0) * (1.0 + float(tier - 1) * 0.035)
	draw_texture_rect(
		STUN_LIGHTNING_TEXTURE,
		Rect2(Vector2(-lightning_size.x * 0.5, -lightning_size.y + 4.0), lightning_size),
		false,
		Color(1.0, 1.0, 1.0, lightning_alpha)
	)
