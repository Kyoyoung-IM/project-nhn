class_name PrototypeTower
extends Node2D

# 한 개의 배치된 터렛 오브젝트를 담당한다.
# 데이터베이스에서 정규화된 설정을 받아 표적 선택, 공격과 타입별 연출을 처리한다.
# 이 분기에서 터렛은 체력과 사망 상태가 없는 고정 불파괴 오브젝트다.

# 데이터 식별자와 머지 트리 정보다. 현재 머지 UI가 추가되면 이 값을 그대로 사용한다.
var turret_id: String = ""
var display_name: String = ""
var turret_type: String = "RANGED"
var next_turret_id: String = "-1"
var tier: int = 1

# 전투 능력치다. 모두 prototype_turrets.json에서 로드된 PLACEHOLDER 값이다.
var damage: float = 1.0
var attack_interval_sec: float = 1.0
var attack_range_px: float = 100.0
var cc_duration: float = 0.0
var cc_value: float = 0.0

# 렌더링 색상과 현재 배치된 전투층 인덱스다.
var tower_color := Color("68d8c1")
var floor_index: int = 0

# 공격 재사용 대기시간 및 짧은 광선 피드백 상태다.
var cooldown_sec: float = 0.0
var enabled: bool = true
var beam_end := Vector2.ZERO
var beam_visible_sec: float = 0.0

# 머지 직후 상위 Tier가 생성됐음을 보여주는 코드 기반 승급 연출 시간이다.
const UPGRADE_EFFECT_DURATION_SEC := 0.7
var upgrade_effect_remaining_sec: float = 0.0


# 로더가 만든 내부 설정을 복사하고 해당 층의 터렛 그룹에 등록한다.
func setup(config: Dictionary, assigned_floor_index: int) -> void:
	turret_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", turret_id))
	turret_type = str(config.get("type", "RANGED"))
	next_turret_id = str(config.get("next_turret_id", "-1"))
	tier = int(config.get("tier", 1))
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


# 새 밤 시작 시 공격 가능 상태와 시각 효과 타이머를 초기화한다.
func reset_for_wave() -> void:
	enabled = true
	cooldown_sec = 0.0
	beam_visible_sec = 0.0
	queue_redraw()


# 실제 VFX 리소스가 들어오기 전까지 확장 원과 빛 점으로 짧은 머지 완료 연출을 재생한다.
func play_upgrade_effect() -> void:
	upgrade_effect_remaining_sec = UPGRADE_EFFECT_DURATION_SEC
	queue_redraw()

# 공격 간격을 갱신하고 같은 층·사거리 안의 최우선 몬스터를 자동 공격한다.
func _process(delta: float) -> void:
	if beam_visible_sec > 0.0:
		beam_visible_sec -= delta
		queue_redraw()
	if upgrade_effect_remaining_sec > 0.0:
		upgrade_effect_remaining_sec = maxf(0.0, upgrade_effect_remaining_sec - delta)
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


# 같은 전투층에서 수평 사거리 안에 있으며 코어 진행도가 가장 높은 몬스터를 선택한다.
# 포탑과 경로의 수직 좌표 차이는 화면 연출용이므로 사거리 계산에서 제외한다.
func _select_target() -> PrototypeMonster:
	var selected: PrototypeMonster = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("prototype_monsters"):
		var monster := node as PrototypeMonster
		if monster == null or not monster.is_in_combat_floor():
			continue
		if monster.current_combat_floor() != floor_index:
			continue
		var horizontal_distance := absf(global_position.x - monster.global_position.x)
		if horizontal_distance > attack_range_px:
			continue
		var progress := monster.progress_score()
		if progress > best_progress:
			best_progress = progress
			selected = monster
	return selected


# 외부 이미지가 없는 프로토타입이므로 타입과 Tier별 도형을 직접 그린다.
func _draw() -> void:
	# Tier가 오를수록 본체와 외곽 장식이 커져 실제 스프라이트 없이도 승급 상태를 구분한다.
	var tier_offset := float(maxi(0, tier - 1))
	var body_radius := 19.0 + tier_offset * 1.8
	draw_circle(Vector2.ZERO, body_radius + 5.0, Color("29384f"))
	draw_circle(Vector2.ZERO, body_radius, tower_color)
	for ring_index in maxi(0, tier - 1):
		var ring_radius := body_radius + 7.0 + float(ring_index) * 3.0
		draw_arc(Vector2.ZERO, ring_radius, PI, TAU, 20, tower_color.lightened(0.42), 2.0)
	match turret_type:
		"MELEE":
			var blade_height := 32.0 + tier_offset * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(-5.0, -blade_height), Vector2(6.0, -blade_height), Vector2(12.0, -4.0), Vector2(-11.0, -4.0)]), tower_color.lightened(0.32))
			draw_line(Vector2(-12.0, -10.0), Vector2(12.0, -10.0), Color("fff5de"), 4.0)
		"DOT":
			draw_circle(Vector2(0.0, -13.0 - tier_offset), 12.0 + tier_offset, tower_color.lightened(0.28))
			draw_circle(Vector2(0.0, -13.0), 5.0, Color("2a1738"))
		"STUN":
			draw_line(Vector2(-6.0, -30.0 - tier_offset * 2.0), Vector2(4.0, -19.0), Color("e9f5ff"), 5.0 + tier_offset * 0.5)
			draw_line(Vector2(4.0, -19.0), Vector2(-4.0, -10.0), Color("e9f5ff"), 5.0)
			draw_line(Vector2(-4.0, -10.0), Vector2(7.0, -2.0), Color("e9f5ff"), 5.0)
		"SLOW":
			draw_line(Vector2(0.0, -31.0 - tier_offset * 2.0), Vector2(0.0, -3.0), Color("eaffff"), 4.0 + tier_offset * 0.4)
			draw_line(Vector2(-12.0, -24.0), Vector2(12.0, -10.0), Color("eaffff"), 4.0)
			draw_line(Vector2(12.0, -24.0), Vector2(-12.0, -10.0), Color("eaffff"), 4.0)
		_:
			var barrel_width := 14.0 + tier_offset * 2.0
			draw_rect(Rect2(-barrel_width * 0.5, -33.0 - tier_offset * 2.0, barrel_width, 31.0 + tier_offset * 2.0), tower_color.lightened(0.35), true)
			draw_circle(Vector2.ZERO, 7.0, tower_color.darkened(0.42))
	# 본체 아래의 밝은 점 개수로 Tier를 직접 읽을 수 있게 한다.
	for pip_index in tier:
		var pip_x := (float(pip_index) - float(tier - 1) * 0.5) * 8.0
		draw_circle(Vector2(pip_x, 12.0), 2.5, Color("fff3bd"))
	if beam_visible_sec > 0.0:
		draw_line(Vector2(0.0, -22.0), beam_end, tower_color.lightened(0.34), 4.0)
		draw_circle(beam_end, 6.0, tower_color.lightened(0.52))
	# 머지 직후 바깥으로 퍼지는 링과 방사형 빛 점을 그려 승급 순간을 강조한다.
	if upgrade_effect_remaining_sec > 0.0:
		var effect_progress := 1.0 - upgrade_effect_remaining_sec / UPGRADE_EFFECT_DURATION_SEC
		var effect_color := tower_color.lightened(0.55)
		effect_color.a = 1.0 - effect_progress
		var effect_radius := lerpf(30.0, 64.0, effect_progress)
		draw_arc(Vector2.ZERO, effect_radius, 0.0, TAU, 40, effect_color, 5.0)
		for spark_index in 8:
			var spark_angle := TAU * float(spark_index) / 8.0
			var spark_position := Vector2.from_angle(spark_angle) * effect_radius
			draw_circle(spark_position, 4.0 * (1.0 - effect_progress * 0.6), effect_color)
