class_name PrototypeMonster
extends Node2D

signal defeated(monster: PrototypeMonster)
signal reached_deepest_floor(monster: PrototypeMonster)

enum MoveState { SPAWNING, WALKING, DESCENDING, ATTACKING, EXIT, DEAD }

var max_hp: float = 1.0
var hp: float = 1.0
var move_speed_px_sec: float = 1.0
var attack_damage: float = 1.0
var attack_interval_sec: float = 1.0
var attack_range_px: float = 1.0
var attack_cooldown_sec: float = 0.0
var reward_gold: int = 0
var path_points := PackedVector2Array()
var path_index: int = 0
var move_state: MoveState = MoveState.SPAWNING
var spawn_animation_sec: float = 0.24
var floor_transfer_active: bool = false
var floor_transfer_repositioned: bool = false
var floor_transfer_remaining_sec: float = 0.0
var floor_transfer_destination_index: int = -1
var floor_transfer_duration_sec: float = 0.36


func setup(config: Dictionary, movement_path: PackedVector2Array) -> void:
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	move_speed_px_sec = float(config.get("move_speed_px_sec", 1.0))
	attack_damage = float(config.get("attack_damage", 1.0))
	attack_interval_sec = float(config.get("attack_interval_sec", 1.0))
	attack_range_px = float(config.get("attack_range_px", 1.0))
	reward_gold = int(config.get("reward_gold", 0))
	path_points = movement_path
	position = path_points[0]
	path_index = 0
	move_state = MoveState.SPAWNING
	scale = Vector2.ZERO
	add_to_group("prototype_monsters")
	queue_redraw()


func _process(delta: float) -> void:
	if move_state == MoveState.SPAWNING:
		spawn_animation_sec -= delta
		var reveal := clampf(1.0 - spawn_animation_sec / 0.24, 0.0, 1.0)
		scale = Vector2.ONE * reveal
		if spawn_animation_sec <= 0.0:
			scale = Vector2.ONE
			move_state = MoveState.WALKING
		return

	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return

	if floor_transfer_active:
		_process_floor_transfer(delta)
		return
	if _is_floor_transfer_origin():
		_begin_floor_transfer()
		return

	var blocking_tower := _find_blocking_tower()
	if blocking_tower != null:
		move_state = MoveState.ATTACKING
		attack_cooldown_sec = maxf(0.0, attack_cooldown_sec - delta)
		if attack_cooldown_sec <= 0.0:
			blocking_tower.take_damage(attack_damage)
			attack_cooldown_sec = attack_interval_sec
		return

	if path_index >= path_points.size() - 1:
		_reach_deepest_floor()
		return

	var target := path_points[path_index + 1]
	var offset := target - position
	move_state = MoveState.DESCENDING if absf(offset.y) > absf(offset.x) else MoveState.WALKING
	position = position.move_toward(target, move_speed_px_sec * delta)

	if position.is_equal_approx(target):
		path_index += 1
		if path_index >= path_points.size() - 1:
			_reach_deepest_floor()


func _is_floor_transfer_origin() -> bool:
	return path_index == 1 or path_index == 3 or path_index == 5


func _begin_floor_transfer() -> void:
	floor_transfer_active = true
	floor_transfer_repositioned = false
	floor_transfer_remaining_sec = floor_transfer_duration_sec
	floor_transfer_destination_index = path_index + 1
	move_state = MoveState.DESCENDING


func _process_floor_transfer(delta: float) -> void:
	floor_transfer_remaining_sec = maxf(0.0, floor_transfer_remaining_sec - delta)
	var progress := 1.0 - floor_transfer_remaining_sec / floor_transfer_duration_sec
	var transition_scale := 1.0 - sin(progress * PI) * 0.78
	scale = Vector2.ONE * transition_scale
	if progress >= 0.5 and not floor_transfer_repositioned:
		position = path_points[floor_transfer_destination_index]
		floor_transfer_repositioned = true
	if floor_transfer_remaining_sec <= 0.0:
		path_index = floor_transfer_destination_index
		floor_transfer_active = false
		floor_transfer_destination_index = -1
		scale = Vector2.ONE
		move_state = MoveState.WALKING


func take_damage(amount: float) -> void:
	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return
	hp = maxf(0.0, hp - amount)
	queue_redraw()
	if hp <= 0.0:
		move_state = MoveState.DEAD
		defeated.emit(self)
		queue_free()


func is_in_combat_floor() -> bool:
	return path_index >= 2 and move_state != MoveState.DEAD and move_state != MoveState.EXIT


func current_combat_floor() -> int:
	match path_index:
		2:
			return 0
		4:
			return 1
		6:
			return 2
	return -1


func _find_blocking_tower() -> PrototypeTower:
	var current_floor := current_combat_floor()
	if current_floor < 0:
		return null
	var closest: PrototypeTower = null
	var closest_distance := INF
	for node in get_tree().get_nodes_in_group("prototype_towers"):
		var candidate := node as PrototypeTower
		if candidate == null or candidate.hp <= 0.0 or candidate.floor_index != current_floor:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= attack_range_px and distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func progress_score() -> float:
	if path_points.is_empty():
		return 0.0
	var score := float(path_index) * 10000.0
	if path_index < path_points.size() - 1:
		score -= position.distance_to(path_points[path_index + 1])
	return score


func _reach_deepest_floor() -> void:
	if move_state == MoveState.EXIT:
		return
	move_state = MoveState.EXIT
	reached_deepest_floor.emit(self)
	queue_free()


func _draw() -> void:
	# PLACEHOLDER monster: simple capsule-like body and health bar.
	draw_circle(Vector2.ZERO, 16.0, Color("d96772"))
	draw_rect(Rect2(-13.0, -8.0, 26.0, 17.0), Color("bd4457"), true)
	draw_circle(Vector2(-6.0, -4.0), 3.0, Color.WHITE)
	draw_circle(Vector2(6.0, -4.0), 3.0, Color.WHITE)
	draw_circle(Vector2(-6.0, -4.0), 1.4, Color("1a2030"))
	draw_circle(Vector2(6.0, -4.0), 1.4, Color("1a2030"))
	draw_line(Vector2(-7.0, 6.0), Vector2(7.0, 6.0), Color("661e32"), 2.0)
	var hp_ratio := hp / max_hp
	draw_rect(Rect2(-18.0, -25.0, 36.0, 5.0), Color("2a1720"), true)
	draw_rect(Rect2(-18.0, -25.0, 36.0 * hp_ratio, 5.0), Color("73e18b"), true)
