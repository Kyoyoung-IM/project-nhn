class_name PrototypeTower
extends Node2D

signal tower_destroyed(tower: PrototypeTower)

var max_hp: float = 1.0
var hp: float = 1.0
var damage: float = 1.0
var attack_interval_sec: float = 1.0
var attack_range_px: float = 100.0
var floor_index: int = 0
var cooldown_sec: float = 0.0
var enabled: bool = true
var beam_end := Vector2.ZERO
var beam_visible_sec: float = 0.0


func setup(config: Dictionary, assigned_floor_index: int) -> void:
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	damage = float(config.get("damage", 1.0))
	attack_interval_sec = float(config.get("attack_interval_sec", 1.0))
	attack_range_px = float(config.get("range_px", 100.0))
	floor_index = assigned_floor_index
	cooldown_sec = 0.0
	add_to_group("prototype_towers")
	queue_redraw()


func reset_for_wave() -> void:
	enabled = true
	cooldown_sec = 0.0
	beam_visible_sec = 0.0
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	queue_redraw()
	if hp <= 0.0:
		enabled = false
		tower_destroyed.emit(self)
		queue_free()


func _process(delta: float) -> void:
	if beam_visible_sec > 0.0:
		beam_visible_sec -= delta
		queue_redraw()

	if not enabled:
		return

	cooldown_sec = maxf(0.0, cooldown_sec - delta)
	if cooldown_sec > 0.0:
		return

	var target := _select_target()
	if target == null:
		return

	target.take_damage(damage)
	beam_end = to_local(target.global_position)
	beam_visible_sec = 0.09
	cooldown_sec = attack_interval_sec
	queue_redraw()


func _select_target() -> PrototypeMonster:
	var selected: PrototypeMonster = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("prototype_monsters"):
		var monster := node as PrototypeMonster
		if monster == null or not monster.is_in_combat_floor():
			continue
		if monster.current_combat_floor() != floor_index:
			continue
		if global_position.distance_to(monster.global_position) > attack_range_px:
			continue
		var progress := monster.progress_score()
		if progress > best_progress:
			best_progress = progress
			selected = monster
	return selected


func _draw() -> void:
	# PLACEHOLDER tower: simple geometric base, body, and barrel.
	draw_circle(Vector2.ZERO, 24.0, Color("29384f"))
	draw_circle(Vector2.ZERO, 19.0, Color("68d8c1"))
	draw_rect(Rect2(-8.0, -30.0, 16.0, 28.0), Color("b9fff0"), true)
	draw_circle(Vector2.ZERO, 7.0, Color("1d6f69"))
	var hp_ratio := hp / max_hp
	draw_rect(Rect2(-25.0, -39.0, 50.0, 6.0), Color("1a202b"), true)
	draw_rect(Rect2(-25.0, -39.0, 50.0 * hp_ratio, 6.0), Color("75e69a"), true)
	if beam_visible_sec > 0.0:
		draw_line(Vector2(0.0, -22.0), beam_end, Color("fff08a"), 4.0)
		draw_circle(beam_end, 6.0, Color("fff7bd"))
