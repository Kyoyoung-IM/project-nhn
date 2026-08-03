class_name PrototypeTower
extends Node2D

signal tower_destroyed(tower: PrototypeTower)

var turret_id: String = ""
var display_name: String = ""
var turret_type: String = "RANGED"
var next_turret_id: String = "-1"
var tier: int = 1
var max_hp: float = 1.0
var hp: float = 1.0
var damage: float = 1.0
var attack_interval_sec: float = 1.0
var attack_range_px: float = 100.0
var cc_duration: float = 0.0
var cc_value: float = 0.0
var tower_color := Color("68d8c1")
var floor_index: int = 0
var cooldown_sec: float = 0.0
var enabled: bool = true
var beam_end := Vector2.ZERO
var beam_visible_sec: float = 0.0


func setup(config: Dictionary, assigned_floor_index: int) -> void:
	turret_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", turret_id))
	turret_type = str(config.get("type", "RANGED"))
	next_turret_id = str(config.get("next_turret_id", "-1"))
	tier = int(config.get("tier", 1))
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	damage = float(config.get("damage", 1.0))
	attack_interval_sec = float(config.get("attack_interval_sec", 1.0))
	attack_range_px = float(config.get("range_px", 100.0))
	cc_duration = float(config.get("cc_duration", 0.0))
	cc_value = float(config.get("cc_value", 0.0))
	tower_color = Color(str(config.get("color_hex", "68d8c1")))
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

	target.receive_turret_hit(damage, turret_type, cc_duration, cc_value)
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
	# PLACEHOLDER tower objects: table-driven colors and type silhouettes.
	draw_circle(Vector2.ZERO, 24.0, Color("29384f"))
	draw_circle(Vector2.ZERO, 19.0, tower_color)
	match turret_type:
		"MELEE":
			draw_colored_polygon(PackedVector2Array([Vector2(-5.0, -32.0), Vector2(6.0, -32.0), Vector2(12.0, -4.0), Vector2(-11.0, -4.0)]), tower_color.lightened(0.32))
			draw_line(Vector2(-12.0, -10.0), Vector2(12.0, -10.0), Color("fff5de"), 4.0)
		"DOT":
			draw_circle(Vector2(0.0, -13.0), 12.0, tower_color.lightened(0.28))
			draw_circle(Vector2(0.0, -13.0), 5.0, Color("2a1738"))
		"STUN":
			draw_line(Vector2(-6.0, -30.0), Vector2(4.0, -19.0), Color("e9f5ff"), 5.0)
			draw_line(Vector2(4.0, -19.0), Vector2(-4.0, -10.0), Color("e9f5ff"), 5.0)
			draw_line(Vector2(-4.0, -10.0), Vector2(7.0, -2.0), Color("e9f5ff"), 5.0)
		"SLOW":
			draw_line(Vector2(0.0, -31.0), Vector2(0.0, -3.0), Color("eaffff"), 4.0)
			draw_line(Vector2(-12.0, -24.0), Vector2(12.0, -10.0), Color("eaffff"), 4.0)
			draw_line(Vector2(12.0, -24.0), Vector2(-12.0, -10.0), Color("eaffff"), 4.0)
		_:
			draw_rect(Rect2(-7.0, -33.0, 14.0, 31.0), tower_color.lightened(0.35), true)
			draw_circle(Vector2.ZERO, 7.0, tower_color.darkened(0.42))
	var hp_ratio := hp / max_hp
	draw_rect(Rect2(-25.0, -39.0, 50.0, 6.0), Color("1a202b"), true)
	draw_rect(Rect2(-25.0, -39.0, 50.0 * hp_ratio, 6.0), Color("75e69a"), true)
	if beam_visible_sec > 0.0:
		draw_line(Vector2(0.0, -22.0), beam_end, tower_color.lightened(0.34), 4.0)
		draw_circle(beam_end, 6.0, tower_color.lightened(0.52))
