extends Node2D

# 프로토타입 전체 장면의 게임 루프와 UI를 조정하는 최상위 컨트롤러다.
# 개별 터렛/몬스터의 전투는 각 오브젝트 스크립트에 맡기고 여기서는 생성·경제·승패만 관리한다.

# 동적으로 생성하는 오브젝트, 데이터 로더, 한글 UI 폰트를 미리 로드한다.
const MonsterScript := preload("res://scripts/monster.gd")
const TowerScript := preload("res://scripts/tower.gd")
const TowerSlotScript := preload("res://scripts/tower_slot.gd")
const ShopCardScript := preload("res://scripts/shop_card.gd")
const DatabaseScript := preload("res://scripts/prototype_database.gd")
const GAME_FONT := preload("res://assets/fonts/NotoSansKR.ttf")

# 모든 전투 좌표와 UI 배치는 16:9 Full HD 논리 해상도를 기준으로 작성한다.
# Web 창의 가로세로 비율이 달라져도 이 영역 전체가 보이도록 Godot 스트레치가 먼저 배율을 정한다.
const REFERENCE_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)

# 전장 도형, 이동 경로, 슬롯이 같은 층 좌표를 공유하도록 화면 기준값을 한곳에 모은다.
const PATH_LEFT_X := 140.0
const PATH_RIGHT_X := 1770.0
const GROUND_LANE_Y := 150.0
const FLOOR_TOP_Y := [190.0, 380.0, 570.0]
const COMBAT_LANE_Y := [350.0, 540.0, 730.0]
const TOWER_SLOT_Y := [295.0, 485.0, 675.0]
# 오른쪽에서 등장하는 몬스터가 진입할 여백 40%를 비우고, 왼쪽 60%에만 슬롯을 둔다.
const TOWER_DEPLOYMENT_RATIO := 0.60
const TOWER_DEPLOYMENT_RIGHT_X := PATH_LEFT_X + (PATH_RIGHT_X - PATH_LEFT_X) * TOWER_DEPLOYMENT_RATIO
# 인접 슬롯은 데이터의 사거리 1칸 환산값과 같은 180px 간격을 사용한다.
const TOWER_SLOT_GAP_PX := 180.0
const TOWER_SLOT_X := [300.0, 480.0, 660.0, 840.0, 1020.0]
# 플레이어가 전투 중 선택할 수 있는 게임 진행 배속이다.
const GAME_SPEED_MULTIPLIERS := [1, 2, 3]
# 4개 임시 웨이브 전체를 시간 가속 상태에서 끝낼 수 있도록 헤드리스 테스트 제한을 넉넉히 둔다.
const AUTOMATED_TEST_TIMEOUT_SEC := 300.0

# READY는 낮, WAVE는 밤 자동 전투, VICTORY/DEFEAT는 입력 대기 결과 화면이다.
enum Phase { READY, WAVE, VICTORY, DEFEAT }

# 지상 오른쪽→왼쪽, B1~B3 각각 오른쪽→왼쪽으로 이어지는 고정 웨이포인트다.
# 홀수 인덱스의 왼쪽 출구에서 다음 짝수 인덱스의 오른쪽 입구로 하강한다.
var movement_path := PackedVector2Array([
	Vector2(PATH_RIGHT_X + 10.0, GROUND_LANE_Y),
	Vector2(PATH_LEFT_X, GROUND_LANE_Y),
	Vector2(PATH_RIGHT_X, COMBAT_LANE_Y[0]),
	Vector2(PATH_LEFT_X, COMBAT_LANE_Y[0]),
	Vector2(PATH_RIGHT_X, COMBAT_LANE_Y[1]),
	Vector2(PATH_LEFT_X, COMBAT_LANE_Y[1]),
	Vector2(PATH_RIGHT_X, COMBAT_LANE_Y[2]),
	Vector2(PATH_LEFT_X, COMBAT_LANE_Y[2]),
])

# 로드된 데이터베이스와 현재 장면 단계다.
var database: PrototypeDatabase
var phase: Phase = Phase.READY

# 현재 장면에 살아 있는 오브젝트와 15개 배치 슬롯 목록이다.
var monsters: Array[PrototypeMonster] = []
var towers: Array[PrototypeTower] = []
var tower_slots: Array[PrototypeTowerSlot] = []

# 하단 상점의 카드 UI, 카드별 구매 가능 여부, 실제 터렛 ID를 같은 인덱스로 관리한다.
var shop_cards: Array[PrototypeShopCard] = []
var shop_card_available: Array[bool] = []
var shop_turret_ids: Array[String] = []
var selected_shop_card: int = -1

# 현재 웨이브의 SpawnTable 전개 결과에는 개체 ID, Spawn Order와 다음 생성 전 대기시간이 함께 들어 있다.
var current_wave_number: int = 1
var current_wave_spawn_entries: Array[Dictionary] = []
var next_spawn_index: int = 0
var spawned_count: int = 0
var defeated_count: int = 0

# 정비 단계 경제 및 스폰 타이머 상태다.
var gold: int = 0
var preparation_remaining_sec: float = 0.0
var reroll_count: int = 0
var spawn_cooldown_sec: float = 0.0
var game_speed_multiplier: int = 1

# 낮(0.0)과 밤(1.0) 사이의 배경 색조를 Tween으로 보간한다.
var night_visual_amount: float = 0.0:
	set(value):
		night_visual_amount = clampf(value, 0.0, 1.0)
		queue_redraw()
var day_night_tween: Tween

# 일반 플레이에서는 무작위화하고 자동 테스트·디버그 시드에서는 재현 가능한 상점 RNG다.
var shop_rng := RandomNumberGenerator.new()

# 헤드리스 정상/실패/경제 테스트를 한 장면 코드에서 실행하기 위한 플래그다.
var automated_test_mode: bool = false
var automated_test_expects_defeat: bool = false
var automated_test_economy: bool = false
var automated_test_drag: bool = false
var automated_test_shop_drag: bool = false
var automated_test_shop_merge: bool = false
var automated_test_wave_shop: bool = false
var automated_test_melee_attack: bool = false
var automated_test_wave_features: bool = false
var automated_test_merge: bool = false
var automated_test_elapsed_sec: float = 0.0

# 런타임에 생성하는 주요 HUD 참조다.
var phase_label: Label
var wave_label: Label
var gold_label: Label
var status_label: Label
var action_button: Button
var reroll_button: Button
var speed_buttons: Array[Button] = []

# CanvasLayer는 Node2D 변환을 상속하지 않으므로 별도로 보관해 전장과 같은 중앙 오프셋을 적용한다.
var interface_canvas: CanvasLayer

# 설치된 터렛의 현재 슬롯을 인스턴스 ID로 찾고 드래그 시작·대상 상태를 추적한다.
var tower_slot_by_instance_id: Dictionary = {}
var dragged_tower: PrototypeTower = null
var dragged_origin_slot: PrototypeTowerSlot = null
var dragged_target_slot: PrototypeTowerSlot = null
var drag_pointer_offset := Vector2.ZERO

# 상점 카드 드래그 중 구매 예정 카드, 포인터를 따라가는 더미 터렛, 드롭 대상 슬롯을 추적한다.
var dragged_shop_card_index: int = -1
var shop_drag_preview: PrototypeTower = null
var shop_drag_target_slot: PrototypeTowerSlot = null


# 명령줄 테스트 플래그를 해석하고, 데이터→UI→슬롯→첫 정비 단계 순서로 초기화한다.
func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	automated_test_mode = "--auto-test-victory" in user_args or "--auto-test-defeat" in user_args or "--auto-test-economy" in user_args or "--auto-test-drag" in user_args or "--auto-test-shop-drag" in user_args or "--auto-test-shop-merge" in user_args or "--auto-test-wave-shop" in user_args or "--auto-test-melee-attack" in user_args or "--auto-test-wave-features" in user_args or "--auto-test-merge" in user_args
	automated_test_expects_defeat = "--auto-test-defeat" in user_args
	automated_test_economy = "--auto-test-economy" in user_args
	automated_test_drag = "--auto-test-drag" in user_args
	automated_test_shop_drag = "--auto-test-shop-drag" in user_args
	automated_test_shop_merge = "--auto-test-shop-merge" in user_args
	automated_test_wave_shop = "--auto-test-wave-shop" in user_args
	automated_test_melee_attack = "--auto-test-melee-attack" in user_args
	automated_test_wave_features = "--auto-test-wave-features" in user_args
	automated_test_merge = "--auto-test-merge" in user_args
	database = DatabaseScript.new() as PrototypeDatabase
	if database == null or not database.load_all():
		push_error("Prototype database could not be loaded.")
		get_tree().quit(1)
		return
	_configure_shop_rng()
	_build_interface()
	_create_tower_slots()
	# aspect=expand가 만든 여분의 논리 공간에 게임을 중앙 정렬하고, 이후 브라우저 크기 변화도 추적한다.
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	_begin_preparation(true)
	_update_interface()
	queue_redraw()
	if automated_test_mode:
		Engine.time_scale = 12.0
		call_deferred("_start_automated_test")


# 정비 카운트다운 또는 웨이브 몬스터 스폰/종료 조건을 매 프레임 처리한다.
func _process(delta: float) -> void:
	if automated_test_mode:
		automated_test_elapsed_sec += delta
		if automated_test_elapsed_sec > AUTOMATED_TEST_TIMEOUT_SEC:
			# 실패 지점에서 웨이브·스폰·잔존 수를 남겨 데이터 변경에 따른 회귀 원인을 바로 찾는다.
			push_error("Automated wave test timed out: wave=%d spawned=%d/%d active=%d defeated=%d phase=%d" % [current_wave_number, spawned_count, current_wave_spawn_entries.size(), monsters.size(), defeated_count, phase])
			Engine.time_scale = 1.0
			get_tree().quit(1)
			return

	if phase == Phase.READY:
		if not automated_test_mode:
			var previous_second := ceili(preparation_remaining_sec)
			preparation_remaining_sec = maxf(0.0, preparation_remaining_sec - delta)
			if ceili(preparation_remaining_sec) != previous_second:
				_update_interface()
			if preparation_remaining_sec <= 0.0:
				_start_wave()
		return

	if phase != Phase.WAVE:
		return

	var total := current_wave_spawn_entries.size()
	if spawned_count < total:
		spawn_cooldown_sec -= delta
		if spawn_cooldown_sec <= 0.0:
			var next_delay_sec := _spawn_monster()
			# 전체 진행 테스트는 시간값 자체를 데이터 테스트에서 검증하고, 실행 시간은 개체 간격으로 단축한다.
			spawn_cooldown_sec += minf(next_delay_sec, database.define_float("monsterSpawnInterval", 0.4)) if automated_test_mode else next_delay_sec

	if spawned_count >= total and monsters.is_empty():
		_complete_wave()


# 일반 플레이는 실행마다 다른 시드를 쓰고, 테스트와 --shop-seed=<숫자> 실행은 고정 시드로 재현한다.
func _configure_shop_rng() -> void:
	var fallback_seed := database.extension_int("rngSeed", 20260803)
	if automated_test_mode:
		shop_rng.seed = fallback_seed
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shop-seed="):
			var seed_text := argument.trim_prefix("--shop-seed=")
			shop_rng.seed = int(seed_text) if seed_text.is_valid_int() else fallback_seed
			return
	shop_rng.randomize()


# 정비 시간의 마우스 누름·이동·놓기를 상점 구매 드래그 또는 설치 터렛 이동으로 변환한다.
func _input(event: InputEvent) -> void:
	if not _is_shop_available():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pointer := to_local(event.position)
		if event.pressed and dragged_tower == null and dragged_shop_card_index < 0:
			var shop_card_index := _shop_card_at_pointer(event.position)
			if shop_card_index >= 0:
				_begin_shop_card_drag(shop_card_index, local_pointer)
				get_viewport().set_input_as_handled()
				return
			# 설치된 타워 이동은 정비 단계에서만 시작할 수 있다.
			if phase != Phase.READY:
				return
			var tower := _tower_at_pointer(local_pointer)
			if tower != null:
				var origin := tower_slot_by_instance_id.get(tower.get_instance_id()) as PrototypeTowerSlot
				if origin != null:
					_begin_tower_drag(tower, origin, local_pointer)
					get_viewport().set_input_as_handled()
		elif not event.pressed and dragged_shop_card_index >= 0:
			_update_shop_card_drag(local_pointer)
			_finish_shop_card_drag()
			get_viewport().set_input_as_handled()
		elif not event.pressed and dragged_tower != null:
			_update_tower_drag(local_pointer)
			_finish_tower_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if dragged_shop_card_index >= 0:
			_update_shop_card_drag(to_local(event.position))
			get_viewport().set_input_as_handled()
		elif dragged_tower != null:
			_update_tower_drag(to_local(event.position))
			get_viewport().set_input_as_handled()


# CanvasLayer 오프셋을 고려해 포인터 아래에 있는 상점 카드 인덱스를 찾는다.
func _shop_card_at_pointer(viewport_pointer: Vector2) -> int:
	var canvas_pointer := viewport_pointer - interface_canvas.offset
	for card_index in shop_cards.size():
		var card := shop_cards[card_index]
		if card.visible and Rect2(card.position, card.size).has_point(canvas_pointer):
			return card_index
	return -1


# 구매 가능한 상점 카드의 더미 터렛을 생성하고 모든 빈 슬롯을 드롭 대상으로 표시한다.
func _begin_shop_card_drag(card_index: int, local_pointer: Vector2) -> bool:
	if not _is_shop_available() or card_index < 0 or card_index >= shop_cards.size() or not shop_card_available[card_index]:
		return false
	var tower_data := database.get_turret_data(shop_turret_ids[card_index])
	var tower_cost := int(tower_data.get("base_price", -1))
	if tower_data.is_empty() or gold < tower_cost:
		status_label.text = "구매 골드가 부족합니다"
		return false
	dragged_shop_card_index = card_index
	selected_shop_card = card_index
	shop_drag_preview = TowerScript.new() as PrototypeTower
	shop_drag_preview.setup(tower_data, -1)
	shop_drag_preview.enabled = false
	shop_drag_preview.set_process(false)
	shop_drag_preview.position = local_pointer
	shop_drag_preview.z_index = 30
	shop_drag_preview.scale = Vector2.ONE * 1.2
	shop_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.78)
	add_child(shop_drag_preview)
	shop_drag_preview.remove_from_group("prototype_towers")
	status_label.text = "빈 슬롯에 설치하거나 같은 터렛 위에 놓아 머지하세요"
	_update_shop_drag_slot_states(null)
	_update_shop_cards()
	return true


# 상점 카드의 더미 터렛을 포인터에 따라 이동시키고 가장 가까운 설치·머지 슬롯을 강조한다.
func _update_shop_card_drag(local_pointer: Vector2) -> void:
	if shop_drag_preview == null or not is_instance_valid(shop_drag_preview):
		_cancel_shop_card_drag()
		return
	shop_drag_preview.position = local_pointer
	var tower_data := database.get_turret_data(shop_turret_ids[dragged_shop_card_index])
	shop_drag_target_slot = _nearest_shop_drop_target(local_pointer, tower_data)
	_update_shop_drag_slot_states(shop_drag_target_slot)


# 층 제한 없이 포인터 반경 안에서 빈 슬롯 또는 상점 머지 가능한 점유 슬롯을 찾는다.
func _nearest_shop_drop_target(local_pointer: Vector2, tower_data: Dictionary) -> PrototypeTowerSlot:
	var nearest: PrototypeTowerSlot = null
	var nearest_distance := 70.0
	for slot in tower_slots:
		var eligible := slot.is_empty()
		if not eligible:
			eligible = _can_merge_shop_card_with_tower(tower_data, slot.occupant as PrototypeTower)
		if not eligible:
			continue
		var distance := local_pointer.distance_to(slot.position)
		if distance < nearest_distance:
			nearest = slot
			nearest_distance = distance
	return nearest


# 유효한 빈 슬롯 또는 동일 터렛에 놓였을 때만 결제 후 설치·머지를 실행한다.
func _finish_shop_card_drag() -> void:
	var merge_requested := shop_drag_target_slot != null and not shop_drag_target_slot.is_empty()
	var purchased := _purchase_shop_card_to_slot(dragged_shop_card_index, shop_drag_target_slot)
	if purchased:
		status_label.text = "상점 터렛을 구매해 상위 Tier로 머지했습니다" if merge_requested else "터렛을 구매해 설치했습니다"
	else:
		status_label.text = "빈 슬롯 또는 동일 Tier 터렛에 놓아야 구매할 수 있습니다"
	_clear_shop_card_drag_visuals()


# 카드와 슬롯, 골드를 다시 검증한 뒤 빈 슬롯 설치 또는 점유 슬롯 머지 구매를 확정한다.
func _purchase_shop_card_to_slot(card_index: int, target: PrototypeTowerSlot) -> bool:
	if not _is_shop_available() or card_index < 0 or card_index >= shop_cards.size():
		return false
	if target == null or not shop_card_available[card_index]:
		return false
	var tower_data := database.get_turret_data(shop_turret_ids[card_index])
	var tower_cost := int(tower_data.get("base_price", -1))
	if tower_data.is_empty() or gold < tower_cost:
		return false
	selected_shop_card = card_index
	if target.is_empty():
		return _place_tower(target, true) != null
	return _merge_shop_card_with_tower(card_index, target, tower_data, tower_cost)


# 상점 카드와 설치 터렛이 같은 ID·Tier이고 다음 Tier 데이터가 있을 때 구매 머지를 허용한다.
# 설치 터렛 드래그와 달리 상점 구매는 기존 상점 정책에 따라 낮과 밤 모두 사용할 수 있다.
func _can_merge_shop_card_with_tower(tower_data: Dictionary, target: PrototypeTower) -> bool:
	if tower_data.is_empty() or target == null or not is_instance_valid(target):
		return false
	if str(tower_data.get("id", "")) != target.turret_id or int(tower_data.get("tier", -1)) != target.tier:
		return false
	var next_turret_id := str(tower_data.get("next_turret_id", "-1"))
	if next_turret_id.is_empty() or next_turret_id == "-1":
		return false
	return not database.get_turret_data(next_turret_id).is_empty()


# 카드 가격을 지불하고 대상 터렛 하나를 소비해 같은 슬롯에 상위 데이터 터렛을 생성한다.
func _merge_shop_card_with_tower(card_index: int, target_slot: PrototypeTowerSlot, tower_data: Dictionary, tower_cost: int) -> bool:
	if target_slot == null or target_slot.is_empty() or card_index < 0 or card_index >= shop_card_available.size():
		return false
	var target := target_slot.occupant as PrototypeTower
	if not _can_merge_shop_card_with_tower(tower_data, target):
		return false
	var upgraded_turret_id := str(tower_data.get("next_turret_id", "-1"))
	# 생성 실패 시 기존 점유자를 복원할 수 있도록 새 터렛 생성이 성공하기 전에는 기존 배열을 지우지 않는다.
	target_slot.clear_occupant()
	var upgraded_tower := _spawn_tower_in_slot(target_slot, upgraded_turret_id)
	if upgraded_tower == null:
		target_slot.set_occupant(target)
		return false
	tower_slot_by_instance_id.erase(target.get_instance_id())
	towers.erase(target)
	target.queue_free()
	gold -= tower_cost
	shop_card_available[card_index] = false
	selected_shop_card = -1
	upgraded_tower.play_upgrade_effect()
	_update_interface()
	_update_shop_cards()
	return true


# 단계 전환이나 게임 초기화로 구매 드래그가 중단되면 결제 없이 더미와 강조를 제거한다.
func _cancel_shop_card_drag() -> void:
	if dragged_shop_card_index < 0 and shop_drag_preview == null:
		return
	_clear_shop_card_drag_visuals()


# 상점 구매 드래그 종료 후 더미 터렛, 슬롯 강조, 카드 선택과 임시 참조를 초기화한다.
func _clear_shop_card_drag_visuals() -> void:
	if shop_drag_preview != null and is_instance_valid(shop_drag_preview):
		shop_drag_preview.queue_free()
	for slot in tower_slots:
		slot.set_drag_state(false, false)
	dragged_shop_card_index = -1
	shop_drag_preview = null
	shop_drag_target_slot = null
	selected_shop_card = -1
	_update_shop_cards()


# 구매 드래그 중 모든 빈 슬롯·동일 터렛 슬롯과 현재 드롭 대상을 구분해 강조한다.
func _update_shop_drag_slot_states(target: PrototypeTowerSlot) -> void:
	var tower_data: Dictionary = {}
	if dragged_shop_card_index >= 0 and dragged_shop_card_index < shop_turret_ids.size():
		tower_data = database.get_turret_data(shop_turret_ids[dragged_shop_card_index])
	for slot in tower_slots:
		var eligible := dragged_shop_card_index >= 0 and (slot.is_empty() or _can_merge_shop_card_with_tower(tower_data, slot.occupant as PrototypeTower))
		slot.set_drag_state(eligible, eligible and slot == target)


# 포인터 반경 안에서 가장 위에 그려진 살아 있는 설치 터렛을 찾는다.
func _tower_at_pointer(local_pointer: Vector2) -> PrototypeTower:
	for tower_index in range(towers.size() - 1, -1, -1):
		var tower := towers[tower_index]
		if is_instance_valid(tower) and local_pointer.distance_to(tower.position) <= 46.0:
			return tower
	return null


# 드래그를 시작하면서 상점 선택을 해제하고 같은 층의 이동·머지 가능 슬롯을 표시한다.
func _begin_tower_drag(tower: PrototypeTower, origin: PrototypeTowerSlot, local_pointer: Vector2) -> void:
	dragged_tower = tower
	dragged_origin_slot = origin
	drag_pointer_offset = tower.position - local_pointer
	selected_shop_card = -1
	tower.z_index = 20
	tower.modulate = Color(1.0, 1.0, 1.0, 0.78)
	status_label.text = "빈 슬롯으로 이동하거나 같은 터렛 위에 놓아 머지하세요"
	_update_drag_slot_states(null)
	_update_shop_cards()


# 드래그 중 터렛을 포인터에 따라 이동시키고 가장 가까운 유효 슬롯을 드롭 대상으로 표시한다.
func _update_tower_drag(local_pointer: Vector2) -> void:
	if dragged_tower == null or not is_instance_valid(dragged_tower):
		_cancel_tower_drag()
		return
	dragged_tower.position = local_pointer + drag_pointer_offset
	dragged_target_slot = _nearest_drag_target(dragged_tower.position, dragged_tower.floor_index)
	_update_drag_slot_states(dragged_target_slot)


# 포인터 위치에서 같은 층의 빈 슬롯 또는 머지 가능한 점유 슬롯을 드롭 대상으로 반환한다.
func _nearest_drag_target(local_pointer: Vector2, floor_index: int) -> PrototypeTowerSlot:
	var nearest: PrototypeTowerSlot = null
	var nearest_distance := 70.0
	for slot in tower_slots:
		if slot.floor_index != floor_index or slot == dragged_origin_slot:
			continue
		var eligible := slot.is_empty()
		if not eligible:
			eligible = _can_merge_towers(dragged_tower, slot.occupant as PrototypeTower)
		if not eligible:
			continue
		var distance := local_pointer.distance_to(slot.position)
		if distance < nearest_distance:
			nearest = slot
			nearest_distance = distance
	return nearest


# 같은 층의 동일 터렛이면 머지하고, 빈 슬롯이면 이동하며, 그 외 위치라면 원래 슬롯으로 되돌린다.
func _finish_tower_drag() -> void:
	if dragged_tower == null or not is_instance_valid(dragged_tower):
		_cancel_tower_drag()
		return
	var merged := _merge_tower(dragged_tower, dragged_target_slot)
	var moved := false
	if not merged:
		moved = _relocate_tower(dragged_tower, dragged_target_slot)
	if merged:
		status_label.text = "터렛을 상위 Tier로 머지했습니다"
	elif moved:
		status_label.text = "터렛 위치를 변경했습니다"
	else:
		dragged_tower.position = dragged_origin_slot.position
		status_label.text = "같은 층의 빈 슬롯 또는 동일 Tier 터렛에만 놓을 수 있습니다"
	_clear_tower_drag_visuals()


# 두 설치 터렛이 같은 층·동일 ID와 Tier이며 상위 데이터가 있을 때만 머지 대상으로 인정한다.
func _can_merge_towers(source: PrototypeTower, target: PrototypeTower) -> bool:
	if phase != Phase.READY or source == null or target == null:
		return false
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
		return false
	if source.floor_index != target.floor_index:
		return false
	if source.turret_id != target.turret_id or source.tier != target.tier:
		return false
	if source.next_turret_id.is_empty() or source.next_turret_id == "-1":
		return false
	return not database.get_turret_data(source.next_turret_id).is_empty()


# 드래그한 터렛과 대상 터렛을 소비하고 대상 슬롯에 데이터 테이블의 상위 터렛을 생성한다.
func _merge_tower(source: PrototypeTower, target_slot: PrototypeTowerSlot) -> bool:
	if source == null or target_slot == null or target_slot.is_empty():
		return false
	var target := target_slot.occupant as PrototypeTower
	if not _can_merge_towers(source, target):
		return false
	var origin := tower_slot_by_instance_id.get(source.get_instance_id()) as PrototypeTowerSlot
	if origin == null or origin == target_slot:
		return false
	var upgraded_turret_id := source.next_turret_id
	origin.clear_occupant()
	target_slot.clear_occupant()
	tower_slot_by_instance_id.erase(source.get_instance_id())
	tower_slot_by_instance_id.erase(target.get_instance_id())
	towers.erase(source)
	towers.erase(target)
	source.queue_free()
	target.queue_free()
	var upgraded_tower := _spawn_tower_in_slot(target_slot, upgraded_turret_id)
	if upgraded_tower == null:
		push_error("Could not create merged turret: %s" % upgraded_turret_id)
		return false
	upgraded_tower.play_upgrade_effect()
	return true


# 터렛과 대상 슬롯이 확정 규칙을 만족할 때만 슬롯 점유 관계와 좌표를 변경한다.
func _relocate_tower(tower: PrototypeTower, target: PrototypeTowerSlot) -> bool:
	if tower == null or target == null or not is_instance_valid(tower):
		return false
	var origin := tower_slot_by_instance_id.get(tower.get_instance_id()) as PrototypeTowerSlot
	if origin == null or target == origin or target.floor_index != origin.floor_index or not target.is_empty():
		return false
	origin.clear_occupant()
	target.set_occupant(tower)
	tower.position = target.position
	tower.floor_index = target.floor_index
	tower_slot_by_instance_id[tower.get_instance_id()] = target
	return true


# 드래그가 취소되면 터렛을 원래 슬롯에 복원하고 모든 슬롯 강조를 제거한다.
func _cancel_tower_drag() -> void:
	if dragged_tower != null and is_instance_valid(dragged_tower) and dragged_origin_slot != null:
		dragged_tower.position = dragged_origin_slot.position
	_clear_tower_drag_visuals()


# 드래그 종료 후 투명도·그리기 순서·슬롯 강조와 임시 참조를 초기화한다.
func _clear_tower_drag_visuals() -> void:
	if dragged_tower != null and is_instance_valid(dragged_tower):
		dragged_tower.z_index = 0
		dragged_tower.modulate = Color.WHITE
	for slot in tower_slots:
		slot.set_drag_state(false, false)
	dragged_tower = null
	dragged_origin_slot = null
	dragged_target_slot = null
	drag_pointer_offset = Vector2.ZERO


# 드래그 중 같은 층의 빈 슬롯과 머지 가능한 동일 터렛 슬롯을 구분해 강조한다.
func _update_drag_slot_states(target: PrototypeTowerSlot) -> void:
	for slot in tower_slots:
		var eligible := false
		if dragged_tower != null and slot.floor_index == dragged_tower.floor_index and slot != dragged_origin_slot:
			eligible = slot.is_empty() or _can_merge_towers(dragged_tower, slot.occupant as PrototypeTower)
		slot.set_drag_state(eligible, eligible and slot == target)


# 상단 정보, 하단 상점, 웨이브/리롤 버튼을 CanvasLayer에 생성한다.
func _build_interface() -> void:
	interface_canvas = CanvasLayer.new()
	add_child(interface_canvas)

	phase_label = _make_label(interface_canvas, Vector2(50.0, 34.0), Vector2(900.0, 48.0), 34)
	phase_label.text = ""

	wave_label = _make_label(interface_canvas, Vector2(50.0, 92.0), Vector2(280.0, 42.0), 27)
	gold_label = _make_label(interface_canvas, Vector2(42.0, 826.0), Vector2(184.0, 42.0), 27)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	status_label = _make_label(interface_canvas, Vector2(650.0, 34.0), Vector2(560.0, 60.0), 25)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	action_button = Button.new()
	action_button.position = Vector2(1540.0, 34.0)
	action_button.size = Vector2(340.0, 60.0)
	action_button.text = "1 웨이브 시작"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_font_override("font", GAME_FONT)
	action_button.add_theme_font_size_override("font_size", 26)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("f3c95f")
	normal_style.corner_radius_top_left = 9
	normal_style.corner_radius_top_right = 9
	normal_style.corner_radius_bottom_left = 9
	normal_style.corner_radius_bottom_right = 9
	action_button.add_theme_stylebox_override("normal", normal_style)
	action_button.add_theme_color_override("font_color", Color("2e2819"))
	action_button.pressed.connect(_on_action_button_pressed)
	interface_canvas.add_child(action_button)
	_create_speed_controls(interface_canvas)

	reroll_button = Button.new()
	reroll_button.position = Vector2(42.0, 888.0)
	reroll_button.size = Vector2(184.0, 64.0)
	reroll_button.text = "새로고침  %d G" % _current_reroll_cost()
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.add_theme_font_override("font", GAME_FONT)
	reroll_button.add_theme_font_size_override("font_size", 24)
	# 리롤 가능 여부가 색만 보아도 구분되도록 활성/호버/비활성 스타일을 명시한다.
	reroll_button.add_theme_stylebox_override("normal", _make_button_style(Color("2f9d69"), Color("8ff0b4")))
	reroll_button.add_theme_stylebox_override("hover", _make_button_style(Color("3eb978"), Color("c3ffd8")))
	reroll_button.add_theme_stylebox_override("pressed", _make_button_style(Color("23764f"), Color("8ff0b4")))
	reroll_button.add_theme_stylebox_override("disabled", _make_button_style(Color("27313a"), Color("46535e")))
	reroll_button.add_theme_color_override("font_color", Color.WHITE)
	reroll_button.add_theme_color_override("font_hover_color", Color.WHITE)
	reroll_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	reroll_button.add_theme_color_override("font_disabled_color", Color("77838e"))
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	interface_canvas.add_child(reroll_button)
	_create_shop_cards(interface_canvas)


# 웨이브 시작 버튼 왼쪽에 전투 중에만 보이는 ×1/×2/×3 속도 버튼을 만든다.
func _create_speed_controls(parent: Node) -> void:
	for speed_index in GAME_SPEED_MULTIPLIERS.size():
		var multiplier := int(GAME_SPEED_MULTIPLIERS[speed_index])
		var speed_button := Button.new()
		speed_button.position = Vector2(1260.0 + speed_index * 90.0, 38.0)
		speed_button.size = Vector2(80.0, 52.0)
		speed_button.text = "×%d" % multiplier
		speed_button.focus_mode = Control.FOCUS_NONE
		speed_button.add_theme_font_override("font", GAME_FONT)
		speed_button.add_theme_font_size_override("font_size", 23)
		speed_button.pressed.connect(_on_speed_button_pressed.bind(multiplier))
		parent.add_child(speed_button)
		speed_buttons.append(speed_button)
	_update_speed_controls()


# 일반 플레이의 웨이브 중에만 선택 배속을 엔진 시간 배율에 반영한다.
func _on_speed_button_pressed(multiplier: int) -> void:
	if phase != Phase.WAVE or automated_test_mode or multiplier not in GAME_SPEED_MULTIPLIERS:
		return
	game_speed_multiplier = multiplier
	Engine.time_scale = float(game_speed_multiplier)
	_update_speed_controls()


# 현재 단계와 선택값에 맞춰 속도 버튼 노출, 입력 가능 상태와 강조색을 갱신한다.
func _update_speed_controls() -> void:
	for speed_index in speed_buttons.size():
		var speed_button := speed_buttons[speed_index]
		var multiplier := int(GAME_SPEED_MULTIPLIERS[speed_index])
		var selected := multiplier == game_speed_multiplier
		speed_button.visible = phase == Phase.WAVE
		speed_button.disabled = phase != Phase.WAVE or automated_test_mode
		var normal_color := Color("d8aa3c") if selected else Color("29384f")
		var border_color := Color("ffe69a") if selected else Color("60738d")
		speed_button.add_theme_stylebox_override("normal", _make_button_style(normal_color, border_color))
		speed_button.add_theme_stylebox_override("hover", _make_button_style(Color("e8be55"), Color("fff0b8")))
		speed_button.add_theme_stylebox_override("pressed", _make_button_style(Color("b88929"), Color("ffe69a")))
		speed_button.add_theme_color_override("font_color", Color("2e2819") if selected else Color.WHITE)
		speed_button.add_theme_color_override("font_hover_color", Color("2e2819"))
		speed_button.add_theme_color_override("font_pressed_color", Color("2e2819"))


# Web 캔버스가 넓거나 높아질 때 1920×1080 게임 영역을 남는 축의 중앙으로 이동한다.
# 실제 확대·축소는 project.godot의 canvas_items + expand 설정이 담당하므로 여기서는 왜곡 없이 위치만 맞춘다.
func _update_responsive_layout() -> void:
	var visible_size := get_viewport_rect().size
	var center_offset := Vector2(
		maxf(0.0, (visible_size.x - REFERENCE_VIEWPORT_SIZE.x) * 0.5),
		maxf(0.0, (visible_size.y - REFERENCE_VIEWPORT_SIZE.y) * 0.5)
	)
	position = center_offset
	if is_instance_valid(interface_canvas):
		interface_canvas.offset = center_offset


# 모든 HUD Label에 동일한 한글 폰트와 기본 색상을 적용하는 생성 도우미다.
func _make_label(parent: Node, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", GAME_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5f7ff"))
	parent.add_child(label)
	return label


# 상점 제어 버튼의 배경, 테두리와 모서리를 동일한 규격으로 생성한다.
func _make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style


# B1~B3 각 5개, 총 15개의 고정 터렛 슬롯을 만든다.
func _create_tower_slots() -> void:
	for floor_index in 3:
		for slot_index in 5:
			var slot := TowerSlotScript.new() as PrototypeTowerSlot
			slot.position = Vector2(TOWER_SLOT_X[slot_index], TOWER_SLOT_Y[floor_index])
			slot.setup(floor_index, slot_index)
			slot.pressed.connect(_on_tower_slot_pressed)
			add_child(slot)
			tower_slots.append(slot)


# PDF/AGENTS에 확정된 5칸 TFT형 상점 카드 버튼을 만든다.
# 카드의 실제 내용은 매 정비 단계마다 _refresh_shop_cards에서 채운다.
func _create_shop_cards(canvas: CanvasLayer) -> void:
	var card_count := database.extension_int("shopCardCount", 5)
	for card_index in card_count:
		var card := ShopCardScript.new() as PrototypeShopCard
		card.position = Vector2(250.0 + card_index * 300.0, 790.0)
		card.size = Vector2(280.0, 270.0)
		card.setup(GAME_FONT)
		canvas.add_child(card)
		shop_cards.append(card)
		shop_card_available.append(true)
		shop_turret_ids.append("")


# 정비 단계에서는 웨이브를 조기 시작하고, 결과 단계에서는 전체 게임을 초기화한다.
func _on_action_button_pressed() -> void:
	if phase == Phase.WAVE:
		return
	if phase == Phase.READY:
		_start_wave()
	else:
		_reset_game()


# 현재 누적 비용을 차감하고 카드 5장을 다시 추첨한 뒤 리롤 횟수를 증가시킨다.
func _on_reroll_button_pressed() -> void:
	if not _is_shop_available():
		return
	var reroll_cost := _current_reroll_cost()
	if gold < reroll_cost:
		status_label.text = "새로고침 골드가 부족합니다"
		return
	gold -= reroll_cost
	reroll_count += 1
	selected_shop_card = -1
	_refresh_shop_cards()
	_update_interface()
	status_label.text = "상점이 새로고침됐습니다"
	_update_shop_cards()


# 기존 클릭 구매를 사용하지 않으므로 빈 슬롯 클릭 시 상점 카드 드래그 방법을 안내한다.
func _on_tower_slot_pressed(slot: PrototypeTowerSlot) -> void:
	if phase != Phase.READY:
		return
	if not slot.is_empty():
		status_label.text = "이미 터렛이 배치된 슬롯입니다"
		return
	status_label.text = "상점 카드를 이 빈 슬롯으로 드래그하세요"


# 터렛 ID를 데이터로 변환해 오브젝트를 생성하고 슬롯 점유 관계를 연결한다.
# 자동 테스트는 use_shop_card=false와 override ID로 경제 차감 없이 배치할 수 있다.
func _place_tower(slot: PrototypeTowerSlot, use_shop_card: bool, turret_id_override: String = "") -> PrototypeTower:
	var turret_id := turret_id_override
	if use_shop_card:
		turret_id = shop_turret_ids[selected_shop_card]
	elif turret_id.is_empty():
		turret_id = database.first_shop_turret_id()
	var tower_data := database.get_turret_data(turret_id)
	if tower_data.is_empty():
		push_error("Cannot place unknown turret: %s" % turret_id)
		return null
	var tower_cost := int(tower_data.get("base_price", 0))
	if use_shop_card:
		gold -= tower_cost
		shop_card_available[selected_shop_card] = false
		selected_shop_card = -1
	var tower := _spawn_tower_in_slot(slot, turret_id)
	if tower == null:
		return null
	_update_interface()
	_update_shop_cards()
	return tower


# 구매·자동 테스트·머지가 공유하도록 한 ID의 터렛을 지정 슬롯에 생성하는 순수 배치 도우미다.
func _spawn_tower_in_slot(slot: PrototypeTowerSlot, turret_id: String) -> PrototypeTower:
	if slot == null or not slot.is_empty():
		return null
	var tower_data := database.get_turret_data(turret_id)
	if tower_data.is_empty():
		return null
	var tower := TowerScript.new() as PrototypeTower
	tower.position = slot.position
	tower.setup(tower_data, slot.floor_index)
	tower.enabled = phase == Phase.WAVE
	add_child(tower)
	towers.append(tower)
	slot.set_occupant(tower)
	tower_slot_by_instance_id[tower.get_instance_id()] = slot
	return tower


# 현재 SpawnTable이 유효한지 확인하고 카운터/터렛 쿨다운을 초기화해 전투를 시작한다.
func _start_wave() -> void:
	if current_wave_spawn_entries.is_empty():
		push_error("Current wave has no SpawnTable entries: wave%d" % current_wave_number)
		return
	_clear_monsters()
	next_spawn_index = 0
	spawned_count = 0
	defeated_count = 0
	spawn_cooldown_sec = 0.15
	# 상점 카드 드래그 중 전투가 시작돼도 구매 동작은 그대로 이어간다.
	if dragged_shop_card_index < 0:
		selected_shop_card = -1
	for tower in towers:
		if is_instance_valid(tower):
			tower.reset_for_wave()
	_set_phase(Phase.WAVE)


# 테스트 종류에 필요한 터렛을 자동 배치한 뒤 정비 시간을 건너뛰고 웨이브를 시작한다.
func _start_automated_test() -> void:
	if automated_test_merge:
		_run_merge_automated_test()
		return
	if automated_test_shop_merge:
		_run_shop_merge_automated_test()
		return
	if automated_test_wave_features:
		_run_wave_features_automated_test()
		return
	if automated_test_melee_attack:
		_run_melee_attack_automated_test()
		return
	if automated_test_wave_shop:
		_run_wave_shop_automated_test()
		return
	if automated_test_shop_drag:
		_run_shop_drag_automated_test()
		return
	if automated_test_drag:
		_run_drag_automated_test()
		return
	if automated_test_economy:
		_run_economy_automated_test()
		return
	if not automated_test_expects_defeat:
		# 승리 회귀 테스트는 밸런스 초안 변화와 무관하게 전체 진행을 검증하도록 모든 층에 최고 Tier 터렛을 배치한다.
		for slot in tower_slots:
			_place_tower(slot, false, "turretRanged4")
	_start_wave()


# 경로와 수직으로 떨어진 근접 포탑이 같은 층·수평 사거리 안의 적을 찾아 실제 피해를 주는지 검증한다.
func _run_melee_attack_automated_test() -> void:
	_place_tower(tower_slots[0], false, "turretMelee1")
	var melee_tower := towers[0]
	var monster_data := database.get_monster_data("normal1")
	var target_monster := MonsterScript.new() as PrototypeMonster
	target_monster.setup(monster_data, movement_path)
	add_child(target_monster)
	# 포탑과 X좌표는 같고 Y좌표는 실제 전투 경로에 두어 수평 거리 판정을 직접 검증한다.
	target_monster.position = Vector2(melee_tower.position.x, COMBAT_LANE_Y[0])
	target_monster.path_index = 2
	target_monster.move_state = PrototypeMonster.MoveState.WALKING
	target_monster.scale = Vector2.ONE
	monsters.append(target_monster)
	var initial_hp := target_monster.hp
	# 낮에는 새로 배치된 터렛도 공격하지 않으므로 실제 전투 단계인 밤으로 전환한 뒤 피해를 검증한다.
	_set_phase(Phase.WAVE)
	var selected_target := melee_tower.call("_select_target") as PrototypeMonster
	melee_tower._process(melee_tower.attack_interval_sec)
	var passed := selected_target == target_monster and is_equal_approx(target_monster.hp, initial_hp - melee_tower.damage)
	if passed:
		print("Automated melee attack test passed: HORIZONTAL_RANGE_DAMAGE")
	else:
		push_error("Automated melee attack test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 불파괴 터렛, 낮/밤 명칭과 선택한 배속의 낮 전환 초기화를 함께 검증한다.
func _run_wave_features_automated_test() -> void:
	_place_tower(tower_slots[0], false, "turretMelee1")
	var test_tower := towers[0]
	var monster_data := database.get_monster_data("normal1")
	var passing_monster := MonsterScript.new() as PrototypeMonster
	passing_monster.setup(monster_data, movement_path)
	add_child(passing_monster)
	passing_monster.position = Vector2(test_tower.position.x, COMBAT_LANE_Y[0])
	passing_monster.path_index = 2
	passing_monster.move_state = PrototypeMonster.MoveState.WALKING
	passing_monster.scale = Vector2.ONE
	monsters.append(passing_monster)
	var monster_start_x := passing_monster.position.x
	# 이 테스트에서만 일반 플레이 배속 분기를 실행하고, 종료 전 자동 테스트 상태를 복원한다.
	automated_test_mode = false
	_set_phase(Phase.WAVE)
	_on_speed_button_pressed(3)
	passing_monster._process(0.1)
	var night_state_ok := phase_label.text == "밤" and speed_buttons[2].visible
	var triple_speed_applied := game_speed_multiplier == 3 and is_equal_approx(Engine.time_scale, 3.0)
	var tower_remained_fixed := is_instance_valid(test_tower) and towers.has(test_tower) and passing_monster.position.x < monster_start_x
	monsters.erase(passing_monster)
	passing_monster.queue_free()
	_complete_wave()
	var day_state_ok := phase_label.text.begins_with("낮") and not speed_buttons[0].visible
	var speed_reset := game_speed_multiplier == 1 and is_equal_approx(Engine.time_scale, 1.0)
	var passed := night_state_ok and triple_speed_applied and tower_remained_fixed and day_state_ok and speed_reset and phase == Phase.READY
	automated_test_mode = true
	if passed:
		print("Automated wave feature test passed: INDESTRUCTIBLE_TOWER_DAY_NIGHT_SPEED")
	else:
		push_error("Automated wave feature test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 잘못된 드롭은 무상 취소되고 유효한 빈 슬롯 드롭만 결제·설치되는지 검증한다.
func _run_shop_drag_automated_test() -> void:
	var card_index := 0
	var target := tower_slots[0]
	var starting_gold := gold
	var tower_data := database.get_turret_data(shop_turret_ids[card_index])
	var tower_cost := int(tower_data.get("base_price", -1))
	var invalid_drop_rejected := not _purchase_shop_card_to_slot(card_index, null) and gold == starting_gold
	var valid_drop_purchased := _purchase_shop_card_to_slot(card_index, target)
	var passed := invalid_drop_rejected and valid_drop_purchased and gold == starting_gold - tower_cost and not target.is_empty() and not shop_card_available[card_index]
	if passed:
		print("Automated shop drag test passed: PAY_ON_VALID_DROP")
	else:
		push_error("Automated shop drag test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 밤에도 상점 카드만 동일 ID·Tier 터렛과 구매 머지되고, 호환되지 않는 점유 슬롯은 결제 없이 거부되는지 검증한다.
func _run_shop_merge_automated_test() -> void:
	var card_index := 0
	var merge_target_slot := tower_slots[0]
	var incompatible_slot := tower_slots[1]
	var original_target := _place_tower(merge_target_slot, false, "turretMelee1")
	_place_tower(incompatible_slot, false, "turretDot1")
	shop_turret_ids[card_index] = "turretMelee1"
	shop_card_available[card_index] = true
	var tower_data := database.get_turret_data("turretMelee1")
	var tower_cost := int(tower_data.get("base_price", -1))
	var starting_gold := gold
	_set_phase(Phase.WAVE)
	var incompatible_rejected := not _purchase_shop_card_to_slot(card_index, incompatible_slot) and gold == starting_gold and shop_card_available[card_index]
	var merged_at_night := _purchase_shop_card_to_slot(card_index, merge_target_slot)
	var upgraded := merge_target_slot.occupant as PrototypeTower
	var passed := incompatible_rejected \
		and merged_at_night \
		and phase == Phase.WAVE \
		and gold == starting_gold - tower_cost \
		and not shop_card_available[card_index] \
		and not towers.has(original_target) \
		and upgraded != null \
		and upgraded.turret_id == "turretMelee2" \
		and upgraded.tier == 2 \
		and upgraded.enabled \
		and upgraded.upgrade_effect_remaining_sec > 0.0
	if passed:
		print("Automated shop merge test passed: NIGHT_PURCHASE_MERGE_PAY_ON_SUCCESS")
	else:
		push_error("Automated shop merge test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 전투 중에도 카드 구매와 리롤이 결제·갱신되는지 회귀 테스트한다.
func _run_wave_shop_automated_test() -> void:
	_set_phase(Phase.WAVE)
	var card_index := 0
	var target := tower_slots[0]
	var starting_gold := gold
	var tower_data := database.get_turret_data(shop_turret_ids[card_index])
	var tower_cost := int(tower_data.get("base_price", -1))
	var reroll_cost := _current_reroll_cost()
	var purchased := _purchase_shop_card_to_slot(card_index, target)
	_on_reroll_button_pressed()
	var placed_tower := target.occupant as PrototypeTower
	var passed := purchased and placed_tower != null and placed_tower.enabled and reroll_count == 1 and gold == starting_gold - tower_cost - reroll_cost
	if passed:
		print("Automated wave shop test passed: PURCHASE_AND_REROLL_DURING_WAVE")
	else:
		push_error("Automated wave shop test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 같은 층 이동 성공과 다른 층 이동 거부를 헤드리스 환경에서 함께 검증한다.
func _run_drag_automated_test() -> void:
	var origin := tower_slots[0]
	var same_floor_target := tower_slots[1]
	var other_floor_target := tower_slots[5]
	_place_tower(origin, false, "turretMelee1")
	var tower := towers[0]
	var cross_floor_rejected := not _relocate_tower(tower, other_floor_target)
	var same_floor_moved := _relocate_tower(tower, same_floor_target)
	var passed := _tower_slot_layout_is_valid() and cross_floor_rejected and same_floor_moved and origin.is_empty() and same_floor_target.occupant == tower and tower.position == same_floor_target.position
	if passed:
		print("Automated drag test passed: SAME_FLOOR_ONLY")
	else:
		push_error("Automated drag test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 낮·같은 층·동일 ID/Tier만 머지되고 상위 데이터 스탯과 외형 Tier가 적용되는지 검증한다.
func _run_merge_automated_test() -> void:
	var source_slot := tower_slots[0]
	var target_slot := tower_slots[1]
	var cross_floor_slot := tower_slots[5]
	var different_type_slot := tower_slots[2]
	var source := _place_tower(source_slot, false, "turretMelee1")
	var target := _place_tower(target_slot, false, "turretMelee1")
	var cross_floor_target := _place_tower(cross_floor_slot, false, "turretMelee1")
	var different_type_target := _place_tower(different_type_slot, false, "turretDot1")
	var no_automatic_merge := source_slot.occupant == source and target_slot.occupant == target and towers.has(source) and towers.has(target)
	var cross_floor_rejected := not _can_merge_towers(source, cross_floor_target)
	var different_type_rejected := not _can_merge_towers(source, different_type_target)
	_set_phase(Phase.WAVE)
	var night_merge_rejected := not _can_merge_towers(source, target)
	_set_phase(Phase.READY)
	var merged := _merge_tower(source, target_slot)
	var upgraded := target_slot.occupant as PrototypeTower
	var upgraded_data := database.get_turret_data("turretMelee2")
	var upgraded_stats_applied := upgraded != null \
		and upgraded.turret_id == "turretMelee2" \
		and upgraded.tier == int(upgraded_data.get("tier", -1)) \
		and is_equal_approx(upgraded.damage, float(upgraded_data.get("damage", -1.0))) \
		and is_equal_approx(upgraded.attack_interval_sec, float(upgraded_data.get("attack_interval_sec", -1.0))) \
		and upgraded.upgrade_effect_remaining_sec > 0.0
	var source_consumed := source_slot.is_empty() and not towers.has(source) and not towers.has(target)
	var passed := no_automatic_merge and cross_floor_rejected and different_type_rejected and night_merge_rejected and merged and source_consumed and upgraded_stats_applied
	if passed:
		print("Automated merge test passed: MANUAL_SAME_FLOOR_DAY_DATA_DRIVEN")
	else:
		push_error("Automated merge test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 슬롯 5개가 왼쪽 60% 배치 영역 안에 있고 실제 사거리 환산과 동일한 간격인지 회귀 검증한다.
func _tower_slot_layout_is_valid() -> bool:
	if TOWER_SLOT_X.size() != 5:
		return false
	for slot_index in TOWER_SLOT_X.size():
		var slot_x := float(TOWER_SLOT_X[slot_index])
		if slot_x < PATH_LEFT_X or slot_x > TOWER_DEPLOYMENT_RIGHT_X:
			return false
		if slot_index > 0 and not is_equal_approx(slot_x - float(TOWER_SLOT_X[slot_index - 1]), TOWER_SLOT_GAP_PX):
			return false
	return true


# 리롤 비용 10→15 증가와 다음 정비 단계의 기본 비용 초기화를 검증한다.
func _run_economy_automated_test() -> void:
	var starting_gold := gold
	var base_cost := database.define_int("rerollCost", 10)
	var plus_cost := database.define_int("rerollPlusCost", 5)
	var first_cost := _current_reroll_cost()
	_on_reroll_button_pressed()
	var second_cost := _current_reroll_cost()
	_on_reroll_button_pressed()
	var expected_gold := starting_gold - base_cost - (base_cost + plus_cost)
	var passed := first_cost == base_cost and second_cost == base_cost + plus_cost and gold == expected_gold
	_begin_preparation(false)
	passed = passed and _current_reroll_cost() == base_cost and gold == expected_gold
	if passed:
		print("Automated economy test passed: REROLL_10_15_RESET")
	else:
		push_error("Automated economy test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 펼쳐진 SpawnTable 일정에서 다음 개체를 생성하고, 그 뒤에 적용할 개체/Order 간격을 반환한다.
func _spawn_monster() -> float:
	var fallback_interval := database.define_float("monsterSpawnInterval", 0.4)
	if next_spawn_index >= current_wave_spawn_entries.size():
		return fallback_interval
	var spawn_entry: Dictionary = current_wave_spawn_entries[next_spawn_index]
	var monster_id := str(spawn_entry.get("monster_id", ""))
	next_spawn_index += 1
	var monster_data := database.get_monster_data(monster_id)
	if monster_data.is_empty():
		push_error("Cannot spawn unknown monster: %s" % monster_id)
		return float(spawn_entry.get("delay_after_sec", fallback_interval))
	var monster := MonsterScript.new() as PrototypeMonster
	monster.setup(monster_data, movement_path)
	monster.defeated.connect(_on_monster_defeated)
	monster.reached_deepest_floor.connect(_on_monster_reached_deepest_floor)
	add_child(monster)
	monsters.append(monster)
	spawned_count += 1
	_update_interface()
	return float(spawn_entry.get("delay_after_sec", fallback_interval))


# 처치된 몬스터를 목록에서 제거하고 Monster.rewardGold를 지급한다.
func _on_monster_defeated(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	defeated_count += 1
	gold += monster.reward_gold
	_update_interface()


# failAllowedMonster 대신 확정 규칙인 B3 최심부 코어 도달만 패배로 처리한다.
func _on_monster_reached_deepest_floor(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	if phase == Phase.WAVE:
		_set_phase(Phase.DEFEAT)


# 밤의 모든 몬스터를 처치하면 다음 낮 또는 최종 승리로 전환한다.
func _complete_wave() -> void:
	if current_wave_number >= database.define_int("totalWaveCount", 1):
		_set_phase(Phase.VICTORY)
		return
	current_wave_number += 1
	_begin_preparation(false)
	status_label.text = "밤 방어 완료 · 낮 시작"
	_update_interface()
	# 헤드리스 전체 승리 테스트는 사용자 입력이 없으므로 다음 정비 단계를 즉시 건너뛴다.
	if automated_test_mode:
		call_deferred("_start_wave")

# 단계에 맞춰 터렛 공격, 슬롯 입력, 몬스터 진행, HUD를 일괄 전환한다.
func _set_phase(next_phase: Phase) -> void:
	if next_phase != Phase.READY and next_phase != Phase.WAVE and dragged_shop_card_index >= 0:
		_cancel_shop_card_drag()
	if next_phase != Phase.READY and dragged_tower != null:
		_cancel_tower_drag()
	phase = next_phase
	_start_day_night_transition(automated_test_mode)
	for tower in towers:
		if is_instance_valid(tower):
			tower.enabled = phase == Phase.WAVE
	for slot in tower_slots:
		slot.interaction_enabled = phase == Phase.READY
	# 자동 테스트의 12배 가속은 유지하고, 일반 플레이만 웨이브 선택 배속을 사용한다.
	if not automated_test_mode:
		if phase == Phase.WAVE:
			Engine.time_scale = float(game_speed_multiplier)
		else:
			game_speed_multiplier = 1
			Engine.time_scale = 1.0
	_update_speed_controls()
	_update_shop_cards()
	if phase == Phase.DEFEAT:
		for monster in monsters:
			if is_instance_valid(monster):
				monster.set_process(false)
	_update_interface()
	queue_redraw()
	if automated_test_mode and (phase == Phase.VICTORY or phase == Phase.DEFEAT):
		call_deferred("_finish_automated_test")


# 현재 단계에 맞춰 낮/밤 색조를 즉시 적용하거나 짧은 Tween으로 전환한다.
func _start_day_night_transition(instant: bool = false) -> void:
	var target_amount := 1.0 if phase == Phase.WAVE or phase == Phase.DEFEAT else 0.0
	if day_night_tween != null and day_night_tween.is_valid():
		day_night_tween.kill()
	if instant:
		night_visual_amount = target_amount
		return
	day_night_tween = create_tween()
	day_night_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	day_night_tween.tween_property(self, "night_visual_amount", target_amount, 0.7)


# 기대 승패 단계와 실제 결과를 비교해 헤드리스 테스트 종료 코드를 결정한다.
func _finish_automated_test() -> void:
	var expected_phase := Phase.DEFEAT if automated_test_expects_defeat else Phase.VICTORY
	var passed := phase == expected_phase
	if passed:
		var result_name := "DEFEAT" if automated_test_expects_defeat else "VICTORY"
		print("Automated wave test passed: %s" % result_name)
	else:
		push_error("Automated wave test reached an unexpected result.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 장면에 남은 몬스터를 안전하게 삭제하고 추적 배열을 비운다.
func _clear_monsters() -> void:
	for monster in monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	monsters.clear()


# 결과 화면에서 새 게임을 시작할 때 몬스터·터렛·슬롯·RNG를 초기 상태로 되돌린다.
func _reset_game() -> void:
	_cancel_shop_card_drag()
	_cancel_tower_drag()
	_clear_monsters()
	for tower in towers:
		if is_instance_valid(tower):
			tower.queue_free()
	towers.clear()
	for slot in tower_slots:
		slot.clear_occupant()
	tower_slot_by_instance_id.clear()
	current_wave_number = 1
	_configure_shop_rng()
	_begin_preparation(true)


# 게임 시작 또는 웨이브 사이 정비 시간을 설정하고 상점/리롤 상태를 초기화한다.
# reset_run=false일 때는 기존 골드와 살아 있는 터렛을 보존한다.
func _begin_preparation(reset_run: bool) -> void:
	if reset_run:
		gold = database.define_int("initialGold", 100)
	reroll_count = 0
	preparation_remaining_sec = database.define_float("prepareTimeSec", 20.0)
	current_wave_spawn_entries = database.get_wave_spawn_entries("wave%d" % current_wave_number)
	selected_shop_card = -1
	_set_phase(Phase.READY)
	_refresh_shop_cards()
	status_label.text = "터렛을 구매해 배치하세요"
	_update_interface()


# ShopGacha 확률로 카드 ID를 새로 뽑고 카드에 타입·능력치·가격을 표시한다.
func _refresh_shop_cards() -> void:
	shop_turret_ids = database.roll_shop_turret_ids(shop_rng, shop_cards.size())
	shop_card_available.clear()
	for card_index in shop_cards.size():
		shop_card_available.append(true)
		var tower_data := database.get_turret_data(shop_turret_ids[card_index])
		var card := shop_cards[card_index]
		card.set_tower_data(tower_data)
	_update_shop_cards()


# 현재 정비 단계에서 지불할 비용을 기본값 + 증가값 × 실행 횟수로 계산한다.
func _current_reroll_cost() -> int:
	return database.define_int("rerollCost", 10) + database.define_int("rerollPlusCost", 5) * reroll_count


# 상점 카드는 정비와 전투 중 모두 구매할 수 있고, 결과 화면에서는 잠긴다.
func _is_shop_available() -> bool:
	return phase == Phase.READY or phase == Phase.WAVE


# 골드·단계·카드 소모 상태에 따라 상점과 리롤 버튼의 활성화를 갱신한다.
func _update_shop_cards() -> void:
	if shop_cards.is_empty() or shop_card_available.size() != shop_cards.size():
		return
	for card_index in shop_cards.size():
		var card := shop_cards[card_index]
		var tower_data := database.get_turret_data(shop_turret_ids[card_index])
		var tower_cost := int(tower_data.get("base_price", 0))
		var interactable := _is_shop_available() and shop_card_available[card_index] and gold >= tower_cost
		card.set_card_state(shop_card_available[card_index], card_index == selected_shop_card, interactable)
	if reroll_button != null:
		var reroll_cost := _current_reroll_cost()
		var can_reroll := _is_shop_available() and gold >= reroll_cost
		reroll_button.disabled = not can_reroll
		if can_reroll:
			reroll_button.text = "새로고침  %d G" % reroll_cost
		elif _is_shop_available():
			reroll_button.text = "골드 부족 · %d G" % reroll_cost
		else:
			reroll_button.text = "새로고침  %d G" % reroll_cost


# 웨이브/골드/정비시간/결과 문구를 현재 상태에 맞게 HUD에 반영한다.
func _update_interface() -> void:
	if wave_label == null:
		return
	var wave_total := current_wave_spawn_entries.size()
	var total_wave_count := database.define_int("totalWaveCount", 1)
	wave_label.text = "WAVE  %d / %d" % [current_wave_number, total_wave_count]
	gold_label.text = "GOLD  %d" % gold
	match phase:
		Phase.READY:
			phase_label.text = "낮  %d초" % ceili(preparation_remaining_sec)
			# 선택·구매·드래그 결과 메시지는 다음 사용자 행동까지 유지하고 빈 경우에만 기본 안내를 채운다.
			if status_label.text.is_empty():
				status_label.text = "터렛을 구매해 배치하세요"
			action_button.text = "%d번째 밤 시작" % current_wave_number
			action_button.disabled = false
		Phase.WAVE:
			phase_label.text = "밤"
			status_label.text = "밤 방어 중  %d / %d 처치" % [defeated_count, wave_total]
			action_button.text = "밤 진행 중"
			action_button.disabled = true
		Phase.VICTORY:
			phase_label.text = "모든 밤 방어 완료"
			status_label.text = "방어 성공"
			action_button.text = "프로토타입 초기화"
			action_button.disabled = false
		Phase.DEFEAT:
			phase_label.text = "밤 · 최심부 코어 침입"
			status_label.text = "최심부 침입 · 패배"
			action_button.text = "프로토타입 초기화"
			action_button.disabled = false


# 외부 배경 에셋 없이 1920×1080 지상 구간, 지하 3층, 진입구, 코어, 상점 배경을 그린다.
func _draw() -> void:
	# Header / ground staging area.
	draw_rect(Rect2(24.0, 20.0, 1872.0, 750.0), Color("253044"), true)
	var sky_color := Color("6ca4cb").lerp(Color("172847"), night_visual_amount)
	var ground_color := Color("759b60").lerp(Color("34485a"), night_visual_amount)
	draw_rect(Rect2(32.0, 28.0, 1856.0, 152.0), sky_color, true)
	draw_rect(Rect2(32.0, 142.0, 1856.0, 38.0), ground_color, true)
	draw_rect(Rect2(32.0, 174.0, 1856.0, 12.0), Color("283342"), true)
	# 낮에는 해가, 밤에는 달과 별이 서서히 나타나 단계 전환을 즉시 알아볼 수 있게 한다.
	var day_alpha := 1.0 - night_visual_amount
	if day_alpha > 0.01:
		draw_circle(Vector2(1480.0, 100.0), 25.0, Color(1.0, 0.83, 0.35, day_alpha))
	if night_visual_amount > 0.01:
		var night_alpha := night_visual_amount
		draw_circle(Vector2(1480.0, 100.0), 23.0, Color(0.86, 0.91, 1.0, night_alpha))
		draw_circle(Vector2(1490.0, 91.0), 22.0, Color(sky_color.r, sky_color.g, sky_color.b, night_alpha))
		for star_position in [Vector2(1300.0, 72.0), Vector2(1370.0, 122.0), Vector2(1580.0, 70.0), Vector2(1640.0, 130.0)]:
			draw_circle(star_position, 3.0, Color(0.92, 0.95, 1.0, night_alpha))

	# Entrance skyline and the dedicated descent shaft.
	draw_rect(Rect2(1690.0, 88.0, 150.0, 86.0), Color("39465c"), true)
	draw_rect(Rect2(1728.0, 112.0, 74.0, 62.0), Color("182234"), true)
	draw_rect(Rect2(94.0, 112.0, 92.0, 78.0), Color("171d2b"), true)
	draw_rect(Rect2(116.0, 136.0, 48.0, 620.0), Color("202838"), true)
	draw_line(Vector2(PATH_LEFT_X, 150.0), Vector2(PATH_LEFT_X, COMBAT_LANE_Y[2]), Color("90a1b7"), 7.0)

	# Three playable underground floors.
	var floor_colors := [
		Color("473f49").lerp(Color("292b3d"), night_visual_amount),
		Color("403943").lerp(Color("252838"), night_visual_amount),
		Color("39343f").lerp(Color("202432"), night_visual_amount),
	]
	for index in 3:
		draw_rect(Rect2(32.0, FLOOR_TOP_Y[index], 1856.0, 180.0), floor_colors[index], true)
		draw_line(Vector2(36.0, FLOOR_TOP_Y[index] + 10.0), Vector2(1884.0, FLOOR_TOP_Y[index] + 10.0), Color("655b65"), 5.0)
		draw_line(Vector2(48.0, COMBAT_LANE_Y[index]), Vector2(1872.0, COMBAT_LANE_Y[index]), Color("171b25"), 10.0)

	# Each combat floor has a right-side entrance and a left-side transfer exit.
	for lane_y in COMBAT_LANE_Y:
		draw_rect(Rect2(1695.0, lane_y - 52.0, 90.0, 52.0), Color("202838"), true)
	for lane_y in [COMBAT_LANE_Y[0], COMBAT_LANE_Y[1]]:
		draw_rect(Rect2(108.0, lane_y - 52.0, 64.0, 52.0), Color("202838"), true)

	# Deepest-floor breach core.
	draw_circle(Vector2(PATH_LEFT_X, COMBAT_LANE_Y[2]), 36.0, Color("5b2432"))
	draw_circle(Vector2(PATH_LEFT_X, COMBAT_LANE_Y[2]), 21.0, Color("ff6475"))
	draw_line(Vector2(129.0, 719.0), Vector2(151.0, 741.0), Color.WHITE, 4.0)
	draw_line(Vector2(151.0, 719.0), Vector2(129.0, 741.0), Color.WHITE, 4.0)

	# Bottom preparation deck and TFT-style five-card shop.
	draw_rect(Rect2(24.0, 770.0, 1872.0, 310.0), Color("151c2a"), true)
	draw_line(Vector2(24.0, 770.0), Vector2(1896.0, 770.0), Color("60708a"), 3.0)
	# Gold and reroll belong to the shop, so they share a dedicated control panel beside the cards.
	draw_rect(Rect2(34.0, 790.0, 200.0, 270.0), Color("0d202c"), true)
	draw_rect(Rect2(34.0, 790.0, 200.0, 270.0), Color("315264"), false, 3.0)
