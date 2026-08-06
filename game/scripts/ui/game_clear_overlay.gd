class_name PrototypeGameClearOverlay
extends Control

# 결과 화면의 정적 배치와 색상은 game_clear_overlay.tscn에서,
# 페이드 시간은 이 Export 속성에서 Godot Inspector로 조절한다.
@export_range(0.0, 2.0, 0.01) var fade_duration_sec: float = 0.32

var fade_tween: Tween


func set_result_visible(show_overlay: bool, instant: bool = false) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if not show_overlay:
		visible = false
		modulate.a = 1.0
		return
	visible = true
	if instant or fade_duration_sec <= 0.0:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	fade_tween = create_tween()
	fade_tween.set_ignore_time_scale(true)
	fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 1.0, fade_duration_sec)
