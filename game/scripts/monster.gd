class_name PrototypeMonster
extends Node2D

# 밤에 생성되는 몬스터 한 개의 이동·피격·상태 이상을 담당한다.
# 실제 플랫폼 물리 없이 고정 웨이포인트와 상태 전환으로 층을 이동한다.

# 처치와 최심부 도달은 보상/패배 처리를 위해 게임 컨트롤러에 알린다.
signal defeated(monster: PrototypeMonster)
signal reached_deepest_floor(monster: PrototypeMonster)

# SPAWNING부터 DEAD까지 몬스터의 현재 행동을 명시적으로 구분한다.
enum MoveState { SPAWNING, WALKING, DESCENDING, STUNNED, EXIT, DEAD }

# 데이터 식별자와 표시용 속성이다.
var monster_id: String = ""
var display_name: String = ""
var monster_type: String = "NORMAL"

# 기본 전투 능력치다. 원본 Monster 컬럼과 표시용 prototypeExtensions를 정규화한 값이다.
var max_hp: float = 1.0
var hp: float = 1.0
var move_speed_px_sec: float = 1.0
var reward_gold: int = 0
var body_color := Color("d96772")

# 터렛의 STUN, SLOW, DOT 효과를 초 단위 런타임 상태로 보관한다.
var stun_remaining_sec: float = 0.0
var slow_remaining_sec: float = 0.0
var slow_multiplier: float = 1.0
var dot_remaining_sec: float = 0.0
var dot_tick_damage: float = 0.0
var dot_tick_cooldown_sec: float = 0.0

# 현재 웨이포인트와 지상→B1→B2→B3 진행 상태다.
var path_points := PackedVector2Array()
var path_index: int = 0
var move_state: MoveState = MoveState.SPAWNING
var spawn_animation_sec: float = 0.24
var spawn_floor_contact_position := Vector2.ZERO

# 한 층의 왼쪽 출구에서 다음 층 오른쪽 입구로 이동하는 축소/확대 연출 상태다.
var floor_transfer_active: bool = false
var floor_transfer_repositioned: bool = false
var floor_transfer_remaining_sec: float = 0.0
var floor_transfer_destination_index: int = -1
var floor_transfer_duration_sec: float = 0.36

# 경로 좌표는 몬스터 중심이 아니라 발판에 닿아야 하는 바닥 접촉점으로 전달된다.
var body_bottom_offset_y: float = 16.0


# 로더가 정규화한 몬스터 데이터와 공유 이동 경로를 복사해 초기 상태를 만든다.
func setup(config: Dictionary, movement_path: PackedVector2Array) -> void:
	monster_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", monster_id))
	monster_type = str(config.get("type", "NORMAL"))
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	move_speed_px_sec = float(config.get("move_speed_px_sec", 1.0))
	reward_gold = int(config.get("reward_gold", 0))
	body_color = Color(str(config.get("color_hex", "d96772")))
	body_bottom_offset_y = _body_bottom_offset_for_type(monster_type)
	stun_remaining_sec = 0.0
	slow_remaining_sec = 0.0
	slow_multiplier = 1.0
	dot_remaining_sec = 0.0
	dot_tick_damage = 0.0
	dot_tick_cooldown_sec = 0.0
	path_points.clear()
	for floor_contact_point in movement_path:
		path_points.append(center_position_for_floor_contact(floor_contact_point))
	position = path_points[0]
	spawn_floor_contact_position = position + Vector2(0.0, body_bottom_offset_y)
	path_index = 0
	move_state = MoveState.SPAWNING
	scale = Vector2.ZERO
	add_to_group("prototype_monsters")
	queue_redraw()


# 더미 도형의 실제 최하단을 중심점 기준으로 반환해 종류별 뜨거나 파묻히는 차이를 없앤다.
static func _body_bottom_offset_for_type(type_value: String) -> float:
	match type_value:
		"SPEED":
			return 12.0
		"TANK":
			return 17.0
		"BOSS":
			return 22.0
	return 16.0


func center_position_for_floor_contact(floor_contact_position: Vector2) -> Vector2:
	return floor_contact_position - Vector2(0.0, body_bottom_offset_y)


# 상태 이상, 등장 연출과 웨이포인트 이동을 우선순위대로 처리한다.
func _process(delta: float) -> void:
	_process_status_effects(delta)
	if move_state == MoveState.DEAD:
		return
	if move_state == MoveState.SPAWNING:
		spawn_animation_sec -= delta
		var reveal := clampf(1.0 - spawn_animation_sec / 0.24, 0.0, 1.0)
		scale = Vector2.ONE * reveal
		# 중심 확대 중에도 도형의 실제 발끝을 지면에 고정해 지상 진입 시 공중부양처럼 보이지 않게 한다.
		position = spawn_floor_contact_position - Vector2(0.0, body_bottom_offset_y * reveal)
		if spawn_animation_sec <= 0.0:
			scale = Vector2.ONE
			position = center_position_for_floor_contact(spawn_floor_contact_position)
			move_state = MoveState.WALKING
		return

	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return
	if stun_remaining_sec > 0.0:
		move_state = MoveState.STUNNED
		return

	if floor_transfer_active:
		_process_floor_transfer(delta)
		return
	if _is_floor_transfer_origin():
		_begin_floor_transfer()
		return

	if path_index >= path_points.size() - 1:
		_reach_deepest_floor()
		return

	var target := path_points[path_index + 1]
	var offset := target - position
	move_state = MoveState.DESCENDING if absf(offset.y) > absf(offset.x) else MoveState.WALKING
	position = position.move_toward(target, move_speed_px_sec * slow_multiplier * delta)

	if position.is_equal_approx(target):
		path_index += 1
		if path_index >= path_points.size() - 1:
			_reach_deepest_floor()


# 경로 인덱스 2는 지상 광산 입구, 4/6은 B1/B2 왼쪽 출구이므로 하강 연출을 시작한다.
func _is_floor_transfer_origin() -> bool:
	return path_index == 2 or path_index == 4 or path_index == 6


# 다음 전투층의 오른쪽 입구를 목적지로 지정하고 DESCENDING 상태로 바꾼다.
func _begin_floor_transfer() -> void:
	floor_transfer_active = true
	floor_transfer_repositioned = false
	floor_transfer_remaining_sec = floor_transfer_duration_sec
	floor_transfer_destination_index = path_index + 1
	move_state = MoveState.DESCENDING


# 연출 중간에 목적지로 재배치하고 크기를 복원해 순간 이동을 부드럽게 보이게 한다.
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


# 즉시 피해를 적용하고 체력이 0이 되면 보상 처리를 위한 처치 신호를 보낸다.
func take_damage(amount: float) -> void:
	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return
	hp = maxf(0.0, hp - amount)
	queue_redraw()
	if hp <= 0.0:
		move_state = MoveState.DEAD
		defeated.emit(self)
		queue_free()


# 터렛 타입에 따라 기본 피해와 DOT/STUN/SLOW를 적용한다.
# BOSS는 명세에 따라 상태 이상 지속시간과 감속량을 50%만 받는다.
func receive_turret_hit(amount: float, source_type: String, cc_duration: float, cc_value: float) -> void:
	take_damage(amount)
	if move_state == MoveState.DEAD:
		return
	var boss_factor := 0.5 if monster_type == "BOSS" else 1.0
	match source_type:
		"DOT":
			dot_remaining_sec = maxf(dot_remaining_sec, cc_duration * boss_factor)
			dot_tick_damage = maxf(dot_tick_damage, amount * cc_value)
			dot_tick_cooldown_sec = minf(dot_tick_cooldown_sec, 0.35)
		"STUN":
			stun_remaining_sec = maxf(stun_remaining_sec, cc_duration * boss_factor)
		"SLOW":
			slow_remaining_sec = maxf(slow_remaining_sec, cc_duration * boss_factor)
			slow_multiplier = minf(slow_multiplier, clampf(1.0 - cc_value * boss_factor, 0.2, 1.0))
	queue_redraw()


# 매 프레임 상태 이상 시간을 감소시키고 DOT의 1초 주기 피해를 처리한다.
func _process_status_effects(delta: float) -> void:
	if stun_remaining_sec > 0.0:
		stun_remaining_sec = maxf(0.0, stun_remaining_sec - delta)
	if slow_remaining_sec > 0.0:
		slow_remaining_sec = maxf(0.0, slow_remaining_sec - delta)
		if slow_remaining_sec <= 0.0:
			slow_multiplier = 1.0
	if dot_remaining_sec > 0.0:
		dot_remaining_sec = maxf(0.0, dot_remaining_sec - delta)
		dot_tick_cooldown_sec -= delta
		if dot_tick_cooldown_sec <= 0.0:
			take_damage(dot_tick_damage)
			dot_tick_cooldown_sec += 1.0
		if dot_remaining_sec <= 0.0:
			dot_tick_damage = 0.0
	queue_redraw()


# 지상 진입과 층간 하강을 제외하고 터렛이 공격할 수 있는 전투층인지 반환한다.
func is_in_combat_floor() -> bool:
	return current_combat_floor() >= 0 and not floor_transfer_active and move_state != MoveState.DEAD and move_state != MoveState.EXIT


# 경로 인덱스를 B1=0, B2=1, B3=2로 변환한다. 전투층 밖이면 -1이다.
func current_combat_floor() -> int:
	match path_index:
		3:
			return 0
		5:
			return 1
		7:
			return 2
	return -1


# 터렛 표적 우선순위용 진행도다. 경로 인덱스가 높을수록 코어에 더 가깝다.
func progress_score() -> float:
	if path_points.is_empty():
		return 0.0
	var score := float(path_index) * 10000.0
	if path_index < path_points.size() - 1:
		score -= position.distance_to(path_points[path_index + 1])
	return score


# B3 왼쪽 끝에 도달했음을 한 번만 알리고 자신을 장면에서 제거한다.
func _reach_deepest_floor() -> void:
	if move_state == MoveState.EXIT:
		return
	move_state = MoveState.EXIT
	reached_deepest_floor.emit(self)
	queue_free()


# 몬스터 타입별 도형, 눈, 체력 바와 현재 상태 이상 표시를 직접 그린다.
func _draw() -> void:
	# PLACEHOLDER monster objects: table-driven colors and type silhouettes.
	match monster_type:
		"SPEED":
			draw_colored_polygon(PackedVector2Array([Vector2(-18.0, 12.0), Vector2(18.0, 0.0), Vector2(-18.0, -12.0)]), body_color)
		"TANK":
			draw_rect(Rect2(-19.0, -17.0, 38.0, 34.0), body_color, true)
			draw_rect(Rect2(-15.0, -13.0, 30.0, 26.0), body_color.darkened(0.2), false, 4.0)
		"BOSS":
			draw_circle(Vector2.ZERO, 22.0, body_color)
			draw_colored_polygon(PackedVector2Array([Vector2(-18.0, -15.0), Vector2(-10.0, -31.0), Vector2(-2.0, -17.0), Vector2(7.0, -31.0), Vector2(17.0, -14.0)]), body_color.lightened(0.18))
		_:
			draw_circle(Vector2.ZERO, 16.0, body_color)
			draw_rect(Rect2(-13.0, -8.0, 26.0, 17.0), body_color.darkened(0.16), true)
	draw_circle(Vector2(-6.0, -4.0), 3.0, Color.WHITE)
	draw_circle(Vector2(6.0, -4.0), 3.0, Color.WHITE)
	draw_circle(Vector2(-6.0, -4.0), 1.4, Color("1a2030"))
	draw_circle(Vector2(6.0, -4.0), 1.4, Color("1a2030"))
	draw_line(Vector2(-7.0, 6.0), Vector2(7.0, 6.0), Color("661e32"), 2.0)
	var hp_ratio := hp / max_hp
	draw_rect(Rect2(-18.0, -25.0, 36.0, 5.0), Color("2a1720"), true)
	draw_rect(Rect2(-18.0, -25.0, 36.0 * hp_ratio, 5.0), Color("73e18b"), true)
	if stun_remaining_sec > 0.0:
		draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 24, Color("8fd7ff"), 3.0)
	if slow_remaining_sec > 0.0:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color("8fffea"), 2.0)
	if dot_remaining_sec > 0.0:
		draw_circle(Vector2(0.0, 16.0), 4.0, Color("d99aff"))
