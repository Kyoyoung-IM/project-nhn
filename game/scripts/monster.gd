class_name PrototypeMonster
extends Node2D

# 밤에 생성되는 몬스터 한 개의 이동·피격·상태 이상을 담당한다.
# 실제 플랫폼 물리 없이 고정 웨이포인트와 상태 전환으로 층을 이동한다.

# 처치와 최심부 도달은 보상/패배 처리를 위해 게임 컨트롤러에 알린다.
signal defeated(monster: PrototypeMonster)
signal reached_deepest_floor(monster: PrototypeMonster)

# SPAWNING부터 DEAD까지 몬스터의 현재 행동을 명시적으로 구분한다.
enum MoveState { SPAWNING, WALKING, DESCENDING, STUNNED, EXIT, DEAD }

# 몬스터 노드의 등장·층 이동 연출 배율이다. 실제 스프라이트 크기는 불투명 영역을
# 기준으로 별도 계산하며, 이 노드 배율과 접지 오프셋을 함께 적용해 발판 접촉을 유지한다.
const MONSTER_VISUAL_SCALE := 1.6
const STUN_STATUS_TEXTURE := preload("res://assets/combat_vfx/status_stun_stars_v2.png")
const STUN_STATUS_DRAW_SIZE := Vector2(126.0, 84.0)
const REGULAR_VISIBLE_AREA_SIDE := 132.0
const BOSS_VISIBLE_HEIGHT := 440.0

const MONSTER_TEXTURES := {
	"NORMAL": preload("res://assets/enemy/normal1.png"),
	"SPEED": preload("res://assets/enemy/spped1.png"),
	"TANK": preload("res://assets/enemy/tank1.png"),
	"BOSS": preload("res://assets/enemy/boss1.png"),
}

# 512px 원본 안에서 알파가 있는 실제 그림 경계다. 캔버스 여백을 제외한 이 영역을
# 기준으로 크기를 맞춰 타입별 원본 여백 차이가 게임 표시 크기에 영향을 주지 않게 한다.
const MONSTER_VISIBLE_BOUNDS := {
	"NORMAL": Rect2(164.0, 146.0, 184.0, 221.0),
	"SPEED": Rect2(94.0, 121.0, 325.0, 271.0),
	"TANK": Rect2(124.0, 83.0, 262.0, 345.0),
	"BOSS": Rect2(4.0, 21.0, 502.0, 469.0),
}

# 데이터 식별자와 표시용 속성이다.
var monster_id: String = ""
var display_name: String = ""
var monster_type: String = "NORMAL"

# 기본 전투 능력치다. 원본 Monster 컬럼과 표시용 prototypeExtensions를 정규화한 값이다.
var max_hp: float = 1.0
var hp: float = 1.0
var move_speed_px_sec: float = 1.0
var reward_gold: int = 0
var body_visible_world_size := Vector2.ZERO
var body_sprite: Sprite2D
# 처음 피해를 받기 전에는 체력 바를 숨기고, 첫 유효 피해부터 남은 전투 동안 표시한다.
var health_bar_visible: bool = false
var health_bar: ProgressBar

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
var visual_elapsed_sec: float = 0.0


# 로더가 정규화한 몬스터 데이터와 공유 이동 경로를 복사해 초기 상태를 만든다.
func setup(config: Dictionary, movement_path: PackedVector2Array) -> void:
	health_bar = get_node_or_null("HealthBar") as ProgressBar
	monster_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", monster_id))
	monster_type = str(config.get("type", "NORMAL"))
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	move_speed_px_sec = float(config.get("move_speed_px_sec", 1.0))
	reward_gold = int(config.get("reward_gold", 0))
	body_visible_world_size = _visible_world_size_for_type(monster_type)
	_configure_body_sprite()
	health_bar_visible = false
	body_bottom_offset_y = _body_bottom_offset_for_type(monster_type)
	_configure_health_bar_layout()
	_update_health_bar()
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
	# 같은 전장 CanvasItem 안에서 설치 터렛보다 앞, 투사체·피격 이펙트보다 뒤에 표시한다.
	z_index = 30
	add_to_group("prototype_monsters")
	_queue_status_redraw()
	_update_health_bar()


# 테스트 밸런스 편집을 살아 있는 몬스터에도 반영하되 현재 체력 비율과 이동 상태는 유지한다.
func apply_runtime_balance(config: Dictionary) -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = maxf(0.001, float(config.get("max_hp", max_hp)))
	hp = clampf(max_hp * hp_ratio, 0.0, max_hp)
	move_speed_px_sec = maxf(0.001, float(config.get("move_speed_px_sec", move_speed_px_sec)))
	reward_gold = int(config.get("reward_gold", reward_gold))
	_update_health_bar()
	_queue_status_redraw()


# 타입별 텍스처와 실제 그림 경계를 반환한다.
static func _texture_for_type(type_value: String) -> Texture2D:
	return MONSTER_TEXTURES.get(type_value, MONSTER_TEXTURES["NORMAL"]) as Texture2D


static func _visible_bounds_for_type(type_value: String) -> Rect2:
	return MONSTER_VISIBLE_BOUNDS.get(type_value, MONSTER_VISIBLE_BOUNDS["NORMAL"]) as Rect2


# 일반형은 Tier 1 타워와 같은 육안 면적, 보스는 한 층보다 약간 작은 높이에 맞춘다.
# 반환값 하나를 가로·세로에 똑같이 적용하므로 어떤 타입도 종횡비가 변하지 않는다.
static func _texture_scale_for_type(type_value: String) -> float:
	var bounds := _visible_bounds_for_type(type_value)
	if type_value == "BOSS":
		return BOSS_VISIBLE_HEIGHT / maxf(1.0, bounds.size.y)
	return REGULAR_VISIBLE_AREA_SIDE / sqrt(maxf(1.0, bounds.size.x * bounds.size.y))


static func _visible_world_size_for_type(type_value: String) -> Vector2:
	return _visible_bounds_for_type(type_value).size * _texture_scale_for_type(type_value)


# 본체 이미지는 상태이상 redraw와 분리된 고정 Sprite2D로 유지한다. 투명 캔버스 안의
# 실제 그림 중심을 노드 원점에 맞추되 가로·세로에는 항상 같은 배율을 적용한다.
func _configure_body_sprite() -> void:
	if body_sprite == null:
		body_sprite = Sprite2D.new()
		body_sprite.name = "BodySprite"
		body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		body_sprite.z_index = -1
		add_child(body_sprite)
	var texture := _texture_for_type(monster_type)
	var bounds := _visible_bounds_for_type(monster_type)
	var local_texture_scale := _texture_scale_for_type(monster_type) / MONSTER_VISUAL_SCALE
	var texture_center := texture.get_size() * 0.5
	var visible_center := bounds.position + bounds.size * 0.5
	body_sprite.texture = texture
	body_sprite.position = -(visible_center - texture_center) * local_texture_scale
	body_sprite.scale = Vector2.ONE * local_texture_scale


# 스프라이트의 실제 최하단을 중심점 기준으로 반환해 종류별 뜨거나 파묻히는 차이를 없앤다.
static func _body_bottom_offset_for_type(type_value: String) -> float:
	return _visible_world_size_for_type(type_value).y * 0.5


func center_position_for_floor_contact(floor_contact_position: Vector2) -> Vector2:
	return floor_contact_position - Vector2(0.0, body_bottom_offset_y)


# 상태 이상, 등장 연출과 웨이포인트 이동을 우선순위대로 처리한다.
func _process(delta: float) -> void:
	visual_elapsed_sec += delta
	_process_status_effects(delta)
	if move_state == MoveState.DEAD:
		return
	if move_state == MoveState.SPAWNING:
		spawn_animation_sec -= delta
		var reveal := clampf(1.0 - spawn_animation_sec / 0.24, 0.0, 1.0)
		scale = Vector2.ONE * MONSTER_VISUAL_SCALE * reveal
		# 중심 확대 중에도 도형의 실제 발끝을 지면에 고정해 지상 진입 시 공중부양처럼 보이지 않게 한다.
		position = spawn_floor_contact_position - Vector2(0.0, body_bottom_offset_y * reveal)
		if spawn_animation_sec <= 0.0:
			scale = Vector2.ONE * MONSTER_VISUAL_SCALE
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
	scale = Vector2.ONE * MONSTER_VISUAL_SCALE * transition_scale
	if progress >= 0.5 and not floor_transfer_repositioned:
		position = path_points[floor_transfer_destination_index]
		floor_transfer_repositioned = true
	if floor_transfer_remaining_sec <= 0.0:
		path_index = floor_transfer_destination_index
		floor_transfer_active = false
		floor_transfer_destination_index = -1
		scale = Vector2.ONE * MONSTER_VISUAL_SCALE
		move_state = MoveState.WALKING


# 즉시 피해를 적용하고 체력이 0이 되면 보상 처리를 위한 처치 신호를 보낸다.
func take_damage(amount: float) -> void:
	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return
	if amount > 0.0 and hp > 0.0:
		health_bar_visible = true
	hp = maxf(0.0, hp - amount)
	_update_health_bar()
	_queue_status_redraw()
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
	_queue_status_redraw()


# 매 프레임 상태 이상 시간을 감소시키고 DOT의 1초 주기 피해를 처리한다.
func _process_status_effects(delta: float) -> void:
	var status_visual_was_active := stun_remaining_sec > 0.0 or slow_remaining_sec > 0.0 or dot_remaining_sec > 0.0
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
	# 이동은 CanvasItem 변환만 바꾸므로 도형 명령을 다시 만들 필요가 없다. 상태 표시가
	# 실제로 보이는 동안에만 갱신해 다수 몬스터가 쌓여도 Web 메인 스레드 부하가 증가하지 않게 한다.
	if status_visual_was_active or stun_remaining_sec > 0.0 or slow_remaining_sec > 0.0 or dot_remaining_sec > 0.0:
		_queue_status_redraw()


# Web에서는 피해로 죽는 프레임에 redraw 예약과 queue_free가 겹치면 해제된
# GDScript draw 콜백을 호출하는 WASM null-function 크래시가 발생할 수 있다.
# 체력 바와 본체 Sprite2D는 별도 노드이므로 Web에서는 이 동적 draw 예약을 생략한다.
func _queue_status_redraw() -> void:
	if not OS.has_feature("web"):
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


# 본체 스프라이트는 고정 자식 노드가 담당한다. 여기서는 지속시간에 따라 바뀌는 상태
# 연출만 다시 그려 Web 전투 중 텍스처 드로우 명령이 반복 재생성되지 않게 한다.
func _draw() -> void:
	if OS.has_feature("web"):
		return
	var local_visible_size := body_visible_world_size / MONSTER_VISUAL_SCALE
	var local_half_height := body_bottom_offset_y / MONSTER_VISUAL_SCALE
	if stun_remaining_sec > 0.0:
		# 생성된 별 헤일로가 실제 기절 시간 동안 머리 위에서 가볍게 흔들리도록 표시한다.
		var stun_wobble := sin(visual_elapsed_sec * 7.0) * 4.0
		draw_texture_rect(
			STUN_STATUS_TEXTURE,
			Rect2(Vector2(-STUN_STATUS_DRAW_SIZE.x * 0.5 + stun_wobble, -local_half_height - STUN_STATUS_DRAW_SIZE.y * 0.8), STUN_STATUS_DRAW_SIZE),
			false
		)
	if slow_remaining_sec > 0.0:
		var slow_radius := minf(local_visible_size.x, local_visible_size.y) * 0.42
		draw_arc(Vector2.ZERO, slow_radius, 0.0, TAU, 32, Color("8fffea"), 2.0)
	if dot_remaining_sec > 0.0:
		draw_circle(Vector2(0.0, local_half_height - 4.0), 4.0, Color("d99aff"))


func _configure_health_bar_layout() -> void:
	if health_bar == null:
		return
	var bar_width_world := 180.0 if monster_type == "BOSS" else 84.0
	var bar_height_world := 7.0
	var bar_top_world := -body_bottom_offset_y - 14.0
	health_bar.position = Vector2(-bar_width_world * 0.5, bar_top_world) / MONSTER_VISUAL_SCALE
	health_bar.size = Vector2(bar_width_world, bar_height_world) / MONSTER_VISUAL_SCALE


# 체력 바의 배치·크기·스타일은 monster.tscn에서 편집하고 현재 수치와 표시 여부만 연결한다.
func _update_health_bar() -> void:
	if health_bar == null:
		health_bar = get_node_or_null("HealthBar") as ProgressBar
	if health_bar == null:
		return
	health_bar.max_value = maxf(max_hp, 0.001)
	health_bar.value = clampf(hp, 0.0, health_bar.max_value)
	health_bar.visible = health_bar_visible
