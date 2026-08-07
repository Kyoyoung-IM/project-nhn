extends Node2D

# 프로토타입 전체 장면의 게임 루프와 UI를 조정하는 최상위 컨트롤러다.
# 개별 터렛/몬스터의 전투는 각 오브젝트 스크립트에 맡기고 여기서는 생성·경제·승패만 관리한다.

# 동적으로 생성하는 오브젝트, 데이터 로더, 한글 UI 폰트를 미리 로드한다.
const TowerScript := preload("res://scripts/tower.gd")
const DatabaseScript := preload("res://scripts/prototype_database.gd")
const RewardCoinPopupScript := preload("res://scripts/reward_coin_popup.gd")
const BattlefieldWorldScript := preload("res://scripts/battlefield_world.gd")
const GAME_HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const TOWER_SLOT_SCENE := preload("res://scenes/entities/tower_slot.tscn")

# 모든 전투 좌표와 UI 배치는 16:9 Full HD 논리 해상도를 기준으로 작성한다.
# Web 창의 가로세로 비율이 달라져도 이 영역 전체가 보이도록 Godot 스트레치가 먼저 배율을 정한다.
const REFERENCE_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)

# 터렛·몬스터 같은 전투 오브젝트만 상점 위에서 자르고, 배경은 별도 층에서 화면 전체에 표시한다.
const BATTLEFIELD_ENTITY_VIEW_HEIGHT := 770.0
const BATTLEFIELD_CAMERA_TRANSITION_SEC := 0.26
# 두 층의 위·아래 여백을 확보하되 모든 전장 이미지의 원본 비율을 유지하도록 균일 축소한다.
const BATTLEFIELD_CAMERA_SCALE := 0.9
const BATTLEFIELD_CAMERA_UNIFORM_SCALE := Vector2(BATTLEFIELD_CAMERA_SCALE, BATTLEFIELD_CAMERA_SCALE)
const BATTLEFIELD_CAMERA_HORIZONTAL_INSET := REFERENCE_VIEWPORT_SIZE.x * (1.0 - BATTLEFIELD_CAMERA_SCALE) * 0.5
# 두 층 화면에서는 아래층과 상점 사이의 불필요한 여백을 위층 표시 영역으로 돌린다.
const BATTLEFIELD_TWO_FLOOR_VERTICAL_OFFSET := 130.0
# 플레이어가 전투 중 선택할 수 있는 게임 진행 배속이다.
const GAME_SPEED_MULTIPLIERS := [1, 2, 3]
# 테스트 환경은 시작 보상 없이 일반 조건을 사용하되 빠른 반복 확인용 추가 배속은 유지한다.
const TEST_GAME_SPEED_MULTIPLIERS := [1, 3, 5, 10]
# URL 또는 사용자 인자로 특정 종류의 Tier 1~4를 즉시 배치하는 시각 검수 전용 ID 목록이다.
const TOWER_VISUAL_TEST_IDS := {
	"MELEE": ["turretMelee1", "turretMelee2", "turretMelee3", "turretMelee4"],
	"RANGED": ["turretRanged1", "turretRanged2", "turretRanged3", "turretRanged4"],
	"DOT": ["turretDot1", "turretDot2", "turretDot3", "turretDot4"],
	"SLOW": ["turretSlow1", "turretSlow2", "turretSlow3", "turretSlow4"],
	"STUN": ["turretStun1", "turretStun2", "turretStun3", "turretStun4"],
}
# 4개 임시 웨이브 전체를 시간 가속 상태에서 끝낼 수 있도록 헤드리스 테스트 제한을 넉넉히 둔다.
const AUTOMATED_TEST_TIMEOUT_SEC := 300.0

# READY는 낮, WAVE는 밤 자동 전투, VICTORY/DEFEAT는 입력 대기 결과 화면이다.
enum Phase { READY, WAVE, VICTORY, DEFEAT }

# 적 경로, 최종 패배 지점, 타워 슬롯과 카메라 정지 위치는 battlefield_layout.tscn에서 읽는다.
# 배열 순서는 몬스터의 상태 전환 인덱스와 연결되므로 장면의 Marker2D 순서를 그대로 보존한다.
@onready var battlefield_layout: PrototypeBattlefieldLayout = $BattlefieldLayout
var movement_path := PackedVector2Array()
var battlefield_camera_y := PackedFloat32Array()

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

# 낮 경제, 밤 기준시간과 스폰 타이머 상태다.
var gold: int = 0
var preparation_remaining_sec: float = 0.0
var reroll_count: int = 0
var spawn_cooldown_sec: float = 0.0
var wave_remaining_sec: float = 0.0
var game_speed_multiplier: int = 1

# 낮(0.0)과 밤(1.0) 사이의 배경 색조를 Tween으로 보간한다.
var night_visual_amount: float = 0.0:
	set(value):
		night_visual_amount = clampf(value, 0.0, 1.0)
		if is_instance_valid(battlefield_background):
			battlefield_background.night_visual_amount = night_visual_amount
		_update_day_night_hud_nodes()
var day_night_tween: Tween

# 기준 화면에 제한된 배경과 마스킹된 전투 오브젝트 월드, 현재 층 쌍과 전환 Tween을 추적한다.
var battlefield_background_clip: Control
var battlefield_background: PrototypeBattlefieldWorld
var battlefield_clip: Control
var battlefield_world: Node2D
var battlefield_view_index: int = 0
var battlefield_camera_tween: Tween

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
var automated_test_attack_styles: bool = false
var automated_test_wave_features: bool = false
var automated_test_merge: bool = false
var automated_test_camera_navigation: bool = false
var automated_test_test_environment: bool = false

# 플레이어와 Codex가 같은 샌드박스를 재현하도록 일반 자동 테스트와 구분한 테스트 환경 플래그다.
var test_mode: bool = false
var tower_visual_test_type: String = ""
var automated_test_elapsed_sec: float = 0.0

# 런타임에 생성하는 주요 HUD 참조다.
var phase_label: Label
var wave_title_label: Label
var wave_label: Label
var gold_label: Label
var gold_gain_label: Label
var gold_gain_tween: Tween
var status_label: Label
var action_button: Button
var reroll_button: Button
var speed_button: Button
var pause_button: Button
var action_button_backplate: TextureRect
var speed_button_backplate: TextureRect
var pause_button_backplate: TextureRect
var action_button_label: Label
var speed_button_label: Label
var day_night_hud: Control
var day_frame: TextureRect
var night_frame: TextureRect
var sun_icon: TextureRect
var moon_icon: TextureRect
var gold_gain_base_position := Vector2.ZERO
var options_overlay: Control
var options_menu_open: bool = false
var options_test_mode_button: Button
var game_clear_overlay: PrototypeGameClearOverlay
var game_over_overlay: Control
var game_over_restart_button: Button
var game_over_quit_button: Button
var game_over_tween: Tween
var test_mode_badge: Label
var test_balance_panel: PrototypeTestBalancePanel

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
	automated_test_mode = "--auto-test-victory" in user_args or "--auto-test-defeat" in user_args or "--auto-test-economy" in user_args or "--auto-test-drag" in user_args or "--auto-test-shop-drag" in user_args or "--auto-test-shop-merge" in user_args or "--auto-test-wave-shop" in user_args or "--auto-test-melee-attack" in user_args or "--auto-test-attack-styles" in user_args or "--auto-test-wave-features" in user_args or "--auto-test-merge" in user_args or "--auto-test-camera-navigation" in user_args or "--auto-test-test-environment" in user_args
	automated_test_expects_defeat = "--auto-test-defeat" in user_args
	automated_test_economy = "--auto-test-economy" in user_args
	automated_test_drag = "--auto-test-drag" in user_args
	automated_test_shop_drag = "--auto-test-shop-drag" in user_args
	automated_test_shop_merge = "--auto-test-shop-merge" in user_args
	automated_test_wave_shop = "--auto-test-wave-shop" in user_args
	automated_test_melee_attack = "--auto-test-melee-attack" in user_args
	automated_test_attack_styles = "--auto-test-attack-styles" in user_args
	automated_test_wave_features = "--auto-test-wave-features" in user_args
	automated_test_merge = "--auto-test-merge" in user_args
	automated_test_camera_navigation = "--auto-test-camera-navigation" in user_args
	automated_test_test_environment = "--auto-test-test-environment" in user_args
	tower_visual_test_type = _requested_tower_visual_test_type(user_args)
	test_mode = "--test-mode" in user_args or automated_test_test_environment or _web_query_requests_test_mode() or not tower_visual_test_type.is_empty()
	database = DatabaseScript.new() as PrototypeDatabase
	if database == null or not database.load_all():
		push_error("Prototype database could not be loaded.")
		get_tree().quit(1)
		return
	if not _load_editor_battlefield_layout():
		get_tree().quit(1)
		return
	_configure_shop_rng()
	_build_battlefield()
	_build_interface()
	_create_tower_slots()
	# aspect=expand가 만든 여분의 논리 공간에 게임을 중앙 정렬하고, 이후 브라우저 크기 변화도 추적한다.
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	_begin_preparation(true)
	if not tower_visual_test_type.is_empty():
		_populate_tower_visual_test()
	_update_interface()
	queue_redraw()
	if automated_test_mode:
		Engine.time_scale = 12.0
		call_deferred("_start_automated_test")


# 편집용 씬의 Marker2D를 런타임 경로와 카메라 좌표로 복사하고 구조 오류는 실행 전에 차단한다.
func _load_editor_battlefield_layout() -> bool:
	if battlefield_layout == null:
		push_error("BattlefieldLayout scene is missing from PrototypeGame.")
		return false
	var layout_errors := battlefield_layout.validate_layout()
	for layout_error in layout_errors:
		push_error("Battlefield layout error: %s" % layout_error)
	if not layout_errors.is_empty():
		return false
	movement_path = battlefield_layout.get_monster_path_points()
	battlefield_camera_y = battlefield_layout.get_camera_y_offsets()
	return true


# Web 빌드는 명령줄 인자를 받을 수 없으므로 URL의 test_mode=1을 같은 런타임 플래그로 변환한다.
func _web_query_requests_test_mode() -> bool:
	if not OS.has_feature("web"):
		return false
	var query_string := str(JavaScriptBridge.eval("window.location.search", true))
	for query_part in query_string.trim_prefix("?").split("&"):
		if query_part == "test_mode=1" or query_part == "test_mode=true":
			return true
	return false


# `?tower_visual_test=DOT` 또는 `--tower-visual-test=DOT` 값을 허용된 5종으로 제한한다.
func _requested_tower_visual_test_type(user_args: PackedStringArray) -> String:
	var requested_type := ""
	for argument in user_args:
		if argument.begins_with("--tower-visual-test="):
			requested_type = argument.trim_prefix("--tower-visual-test=").to_upper()
	if OS.has_feature("web"):
		var query_string := str(JavaScriptBridge.eval("window.location.search", true))
		for query_part in query_string.trim_prefix("?").split("&"):
			if query_part.begins_with("tower_visual_test="):
				requested_type = query_part.trim_prefix("tower_visual_test=").to_upper()
	return requested_type if TOWER_VISUAL_TEST_IDS.has(requested_type) else ""


# 일반 플레이를 건드리지 않고 B1 첫 네 슬롯에 선택 종류의 Tier 1~4를 나란히 배치한다.
func _populate_tower_visual_test() -> void:
	var turret_ids: Array = TOWER_VISUAL_TEST_IDS[tower_visual_test_type]
	for tier_index in mini(4, turret_ids.size()):
		_place_tower(tower_slots[tier_index], false, str(turret_ids[tier_index]))
	_set_battlefield_view_index(1, true)


# 최초 낮 카운트다운 또는 밤의 기준시간·몬스터 스폰을 매 프레임 처리한다.
func _process(delta: float) -> void:
	if options_menu_open or _is_test_editor_open():
		return
	if automated_test_mode:
		automated_test_elapsed_sec += delta
		if automated_test_elapsed_sec > AUTOMATED_TEST_TIMEOUT_SEC:
			# 실패 지점에서 웨이브·스폰·잔존 수를 남겨 데이터 변경에 따른 회귀 원인을 바로 찾는다.
			push_error("Automated wave test timed out: wave=%d spawned=%d/%d active=%d defeated=%d phase=%d" % [current_wave_number, spawned_count, current_wave_spawn_entries.size(), monsters.size(), defeated_count, phase])
			Engine.time_scale = 1.0
			get_tree().quit(1)
			return

	if phase == Phase.READY:
		# Test mode advances waves only through the explicit start controls.
		if not test_mode and not automated_test_mode and tower_visual_test_type.is_empty():
			var previous_second := ceili(preparation_remaining_sec)
			preparation_remaining_sec = maxf(0.0, preparation_remaining_sec - delta)
			if ceili(preparation_remaining_sec) != previous_second:
				_update_interface()
			if preparation_remaining_sec <= 0.0:
				_start_wave()
		return

	if phase != Phase.WAVE:
		return

	# 일반 웨이브는 데이터의 기준시간이 끝나면 잔존 적을 유지한 채 다음 밤을 추가로 시작한다.
	# 마지막 웨이브에는 다음 웨이브가 없으므로 타이머를 0에 고정하고 보스 처치/최심부 도달 판정을 기다린다.
	if wave_remaining_sec > 0.0:
		wave_remaining_sec = maxf(0.0, wave_remaining_sec - delta)
		if wave_remaining_sec <= 0.0 and not test_mode and current_wave_number < database.define_int("totalWaveCount", 1):
			_start_next_wave_immediately()
			return

	var total := current_wave_spawn_entries.size()
	if spawned_count < total:
		spawn_cooldown_sec -= delta
		if spawn_cooldown_sec <= 0.0:
			var next_delay_sec := _spawn_monster()
			# 전체 진행 테스트는 시간값 자체를 데이터 테스트에서 검증하고, 실행 시간은 개체 간격으로 단축한다.
			spawn_cooldown_sec += minf(next_delay_sec, database.define_float("monsterSpawnInterval", 0.4)) if automated_test_mode else next_delay_sec

# 일반 플레이는 실행마다 다른 시드를 쓰고, 테스트와 --shop-seed=<숫자> 실행은 고정 시드로 재현한다.
func _configure_shop_rng() -> void:
	var fallback_seed := database.extension_int("rngSeed", 20260803)
	if automated_test_mode or test_mode:
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
	# The balance editor is a strict modal: only its own Controls receive input until Close is pressed.
	# Do not mark the event handled here because that would also block the modal's buttons and fields.
	if _is_test_editor_open():
		return
	# ESC는 상점 사용 가능 여부와 관계없이 옵션 창을 열고 닫는다.
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if not automated_test_mode:
			_toggle_options_menu()
		get_viewport().set_input_as_handled()
		return
	# 상점 카드 드래그 중이 아닐 때 휠과 위·아래 방향키로 인접한 두 층 화면 사이를 이동한다.
	# 설치 터렛 드래그 중에는 층간 머지 대상을 찾을 수 있도록 카메라 이동을 계속 허용한다.
	if _handle_battlefield_navigation_input(event):
		get_viewport().set_input_as_handled()
		return
	if not _is_shop_available():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pointer := _viewport_to_battlefield(event.position)
		if event.pressed and dragged_tower == null and dragged_shop_card_index < 0:
			var shop_card_index := _shop_card_at_pointer(event.position)
			if shop_card_index >= 0:
				_begin_shop_card_drag(shop_card_index, local_pointer)
				get_viewport().set_input_as_handled()
				return
			# 설치 터렛은 낮에는 이동·머지, 밤에는 머지 목적으로 드래그할 수 있다.
			if phase != Phase.READY and phase != Phase.WAVE:
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
			_update_shop_card_drag(_viewport_to_battlefield(event.position))
			get_viewport().set_input_as_handled()
		elif dragged_tower != null:
			_update_tower_drag(_viewport_to_battlefield(event.position))
			get_viewport().set_input_as_handled()


# 마우스 휠과 위·아래 방향키를 동일한 카메라 단계 변경으로 변환한다.
func _handle_battlefield_navigation_input(event: InputEvent) -> bool:
	if options_menu_open or dragged_shop_card_index >= 0:
		return false
	var direction := 0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			direction = -1
		elif event.keycode == KEY_DOWN:
			direction = 1
	if direction == 0:
		return false
	_set_battlefield_view_index(battlefield_view_index + direction)
	return true


# 화면 좌표를 현재 수직 카메라 위치가 적용된 전장 로컬 좌표로 바꿔 드래그 판정을 유지한다.
func _viewport_to_battlefield(viewport_position: Vector2) -> Vector2:
	if not is_instance_valid(battlefield_world):
		return to_local(viewport_position)
	return battlefield_world.to_local(viewport_position)


# CanvasLayer 오프셋을 고려해 포인터 아래에 있는 상점 카드 인덱스를 찾는다.
func _shop_card_at_pointer(viewport_pointer: Vector2) -> int:
	var canvas_pointer := viewport_pointer - interface_canvas.offset
	for card_index in shop_cards.size():
		var card := shop_cards[card_index]
		# 카드를 ShopUI 아래에서 자유롭게 재배치해도 부모 좌표와 무관하게 실제 화면 영역을 판정한다.
		if card.visible and card.get_global_rect().has_point(canvas_pointer):
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
	battlefield_world.add_child(shop_drag_preview)
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
		if is_instance_valid(tower) and local_pointer.distance_to(tower.position) <= tower.get_interaction_radius():
			return tower
	return null


# 드래그를 시작하면서 상점 선택을 해제하고 현재 단계에서 가능한 이동·머지 슬롯을 표시한다.
func _begin_tower_drag(tower: PrototypeTower, origin: PrototypeTowerSlot, local_pointer: Vector2) -> void:
	dragged_tower = tower
	dragged_origin_slot = origin
	drag_pointer_offset = tower.position - local_pointer
	selected_shop_card = -1
	tower.z_index = 20
	tower.modulate = Color(1.0, 1.0, 1.0, 0.78)
	# 밤에는 드래그 중 공격 판정이 이동 경로를 따라 바뀌지 않도록 해당 터렛의 공격만 잠시 멈춘다.
	tower.enabled = false
	status_label.text = "동일 터렛에 놓아 층간 머지하세요" if phase == Phase.WAVE else "같은 층의 빈 슬롯으로 이동하거나 동일 터렛에 놓아 머지하세요"
	_update_drag_slot_states(null)
	_update_shop_cards()


# 드래그 중 터렛을 포인터에 따라 이동시키고 가장 가까운 유효 슬롯을 드롭 대상으로 표시한다.
func _update_tower_drag(local_pointer: Vector2) -> void:
	if dragged_tower == null or not is_instance_valid(dragged_tower):
		_cancel_tower_drag()
		return
	dragged_tower.position = local_pointer + drag_pointer_offset
	if not _is_in_battlefield_drop_area(dragged_tower.position):
		dragged_target_slot = null
		_update_drag_slot_states(null)
		return
	dragged_target_slot = _nearest_drag_target(dragged_tower.position)
	_update_drag_slot_states(dragged_target_slot)


# 포인터 위치에서 낮의 같은 층 빈 슬롯 또는 낮·밤의 층간 머지 가능 슬롯을 드롭 대상으로 반환한다.
func _nearest_drag_target(local_pointer: Vector2) -> PrototypeTowerSlot:
	var nearest: PrototypeTowerSlot = null
	var nearest_distance := 70.0
	for slot in tower_slots:
		if slot == dragged_origin_slot:
			continue
		var eligible := phase == Phase.READY and slot.floor_index == dragged_tower.floor_index and slot.is_empty()
		if not slot.is_empty():
			eligible = _can_merge_towers(dragged_tower, slot.occupant as PrototypeTower)
		if not eligible:
			continue
		var distance := local_pointer.distance_to(slot.position)
		if distance < nearest_distance:
			nearest = slot
			nearest_distance = distance
	return nearest


# 상점과 HUD 뒤로 가려진 월드 슬롯이 드롭 대상으로 잡히지 않도록 실제 전장 표시 영역만 허용한다.
func _is_in_battlefield_drop_area(local_position: Vector2) -> bool:
	if not is_instance_valid(battlefield_world):
		return false
	var viewport_position := battlefield_world.to_global(local_position)
	var reference_position := viewport_position - position
	return Rect2(Vector2.ZERO, Vector2(REFERENCE_VIEWPORT_SIZE.x, BATTLEFIELD_ENTITY_VIEW_HEIGHT)).has_point(reference_position)


# 층간 머지와 낮의 같은 층 이동을 순서대로 시도하고 잘못된 위치에서는 복귀시킨다.
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
		status_label.text = "밤에는 동일 종류·Tier 터렛 머지만 가능합니다" if phase == Phase.WAVE else "같은 층의 빈 슬롯 또는 동일 종류·Tier 터렛에만 놓을 수 있습니다"
	_clear_tower_drag_visuals()


# 두 설치 터렛이 동일 ID와 Tier이며 상위 데이터가 있으면 층과 낮·밤에 관계없이 머지 대상으로 인정한다.
func _can_merge_towers(source: PrototypeTower, target: PrototypeTower) -> bool:
	if (phase != Phase.READY and phase != Phase.WAVE) or source == null or target == null:
		return false
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
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

# 빈 슬롯 이동은 낮·같은 층에서만 허용하고, 층간 조작은 머지 경로로만 처리한다.
func _relocate_tower(tower: PrototypeTower, target: PrototypeTowerSlot) -> bool:
	if phase != Phase.READY or tower == null or target == null or not is_instance_valid(tower):
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
		dragged_tower.enabled = phase == Phase.WAVE
	for slot in tower_slots:
		slot.set_drag_state(false, false)
	dragged_tower = null
	dragged_origin_slot = null
	dragged_target_slot = null
	drag_pointer_offset = Vector2.ZERO


# 드래그 중 낮의 같은 층 빈 슬롯과 낮·밤의 층간 머지 가능 슬롯을 구분해 강조한다.
func _update_drag_slot_states(target: PrototypeTowerSlot) -> void:
	for slot in tower_slots:
		var eligible := false
		if dragged_tower != null and slot != dragged_origin_slot:
			eligible = phase == Phase.READY and slot.floor_index == dragged_tower.floor_index and slot.is_empty()
			if not slot.is_empty():
				eligible = _can_merge_towers(dragged_tower, slot.occupant as PrototypeTower)
		slot.set_drag_state(eligible, eligible and slot == target)


# 배경은 화면 전체에 두고 전투 오브젝트만 상점 위에서 자르는 두 개의 수직 이동 층을 생성한다.
func _build_battlefield() -> void:
	# 배경은 UI와 독립적으로 움직이되 1920×1080 기준 게임 화면 밖으로는 그리지 않는다.
	battlefield_background_clip = Control.new()
	battlefield_background_clip.position = Vector2.ZERO
	battlefield_background_clip.size = REFERENCE_VIEWPORT_SIZE
	battlefield_background_clip.clip_contents = true
	battlefield_background_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield_background_clip.z_index = -110
	add_child(battlefield_background_clip)

	# 기준 화면 안에서는 상점 카드 사이까지 배경이 끊김 없이 이어진다.
	battlefield_background = BattlefieldWorldScript.new() as PrototypeBattlefieldWorld
	battlefield_background.night_visual_amount = night_visual_amount
	battlefield_background.horizontal_extension_px = BATTLEFIELD_CAMERA_HORIZONTAL_INSET / BATTLEFIELD_CAMERA_SCALE
	battlefield_background.scale = BATTLEFIELD_CAMERA_UNIFORM_SCALE
	battlefield_background.position.x = BATTLEFIELD_CAMERA_HORIZONTAL_INSET
	battlefield_background_clip.add_child(battlefield_background)

	# 슬롯·터렛·몬스터는 상점 카드 뒤로 내려가지 않도록 기존 전장 높이에서만 표시한다.
	battlefield_clip = Control.new()
	battlefield_clip.position = Vector2.ZERO
	battlefield_clip.size = Vector2(REFERENCE_VIEWPORT_SIZE.x, BATTLEFIELD_ENTITY_VIEW_HEIGHT)
	battlefield_clip.clip_contents = true
	battlefield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 루트가 그리는 HUD 장식과 CanvasLayer UI보다 항상 뒤에서 렌더링한다.
	battlefield_clip.z_index = -100
	add_child(battlefield_clip)

	battlefield_world = Node2D.new()
	battlefield_world.name = "BattlefieldEntities"
	battlefield_world.scale = BATTLEFIELD_CAMERA_UNIFORM_SCALE
	battlefield_world.position.x = BATTLEFIELD_CAMERA_HORIZONTAL_INSET
	battlefield_clip.add_child(battlefield_world)

	_set_battlefield_view_index(0, true)


# 카메라 정지점의 원본 월드 좌표를 균일 축소된 화면 좌표로 바꾸고 두 층 화면만 아래로 당긴다.
func _battlefield_view_target_y(view_index: int) -> float:
	var target_y := float(battlefield_camera_y[view_index]) * BATTLEFIELD_CAMERA_SCALE
	if view_index > 0:
		target_y += BATTLEFIELD_TWO_FLOOR_VERTICAL_OFFSET
	return target_y


# 0=하늘+지상, 1=지상+B1, 2=B1+B2, 3=B2+B3으로 제한하고 균일 축소된 전장의 Y 위치를 보간한다.
func _set_battlefield_view_index(requested_index: int, instant: bool = false) -> void:
	if not is_instance_valid(battlefield_world) or not is_instance_valid(battlefield_background):
		return
	battlefield_view_index = clampi(requested_index, 0, battlefield_camera_y.size() - 1)
	var target_y := _battlefield_view_target_y(battlefield_view_index)
	if battlefield_camera_tween != null and battlefield_camera_tween.is_valid():
		battlefield_camera_tween.kill()
	if instant:
		battlefield_world.position.y = target_y
		battlefield_background.position.y = target_y
		return
	battlefield_camera_tween = create_tween()
	# 밤의 2·3배속과 무관하게 카메라 조작 감각이 일정하도록 실제 시간을 사용한다.
	battlefield_camera_tween.set_ignore_time_scale(true)
	battlefield_camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	battlefield_camera_tween.tween_property(battlefield_world, "position:y", target_y, BATTLEFIELD_CAMERA_TRANSITION_SEC)
	battlefield_camera_tween.parallel().tween_property(battlefield_background, "position:y", target_y, BATTLEFIELD_CAMERA_TRANSITION_SEC)


# 상단 HUD와 하단 상점을 편집 가능한 씬에서 불러오고 게임 로직 참조만 연결한다.
func _build_interface() -> void:
	interface_canvas = GAME_HUD_SCENE.instantiate() as CanvasLayer
	add_child(interface_canvas)

	var layout := interface_canvas.get_node("Layout") as Control
	day_night_hud = layout.get_node("DayNightHUD") as Control
	day_frame = day_night_hud.get_node("DayFrame") as TextureRect
	night_frame = day_night_hud.get_node("NightFrame") as TextureRect
	sun_icon = day_night_hud.get_node("SunIcon") as TextureRect
	moon_icon = day_night_hud.get_node("MoonIcon") as TextureRect
	phase_label = day_night_hud.get_node("PhaseLabel") as Label
	wave_title_label = day_night_hud.get_node("WaveTitleLabel") as Label
	wave_label = day_night_hud.get_node("WaveLabel") as Label

	var top_controls := layout.get_node("TopControls") as Control
	test_mode_badge = top_controls.get_node("TestModeBadge") as Label
	action_button_backplate = top_controls.get_node("ActionBackplate") as TextureRect
	action_button = top_controls.get_node("ActionButton") as Button
	action_button_label = top_controls.get_node("ActionLabel") as Label
	speed_button_backplate = top_controls.get_node("SpeedBackplate") as TextureRect
	speed_button = top_controls.get_node("SpeedButton") as Button
	speed_button_label = top_controls.get_node("SpeedLabel") as Label
	pause_button_backplate = top_controls.get_node("PauseBackplate") as TextureRect
	pause_button = top_controls.get_node("PauseButton") as Button

	var shop_ui := layout.get_node("ShopUI") as Control
	gold_label = shop_ui.get_node("GoldLabel") as Label
	reroll_button = shop_ui.get_node("RerollButton") as Button
	gold_gain_label = layout.get_node("GoldGainLabel") as Label
	status_label = layout.get_node("StatusLabel") as Label
	gold_gain_base_position = gold_gain_label.position
	game_clear_overlay = layout.get_node("GameClearOverlay") as PrototypeGameClearOverlay
	game_over_overlay = layout.get_node("GameOverOverlay") as Control
	game_over_restart_button = game_over_overlay.get_node("RestartButton") as Button
	game_over_quit_button = game_over_overlay.get_node("QuitButton") as Button
	game_over_restart_button.pressed.connect(_on_game_over_restart_pressed)
	game_over_quit_button.pressed.connect(_on_game_over_quit_pressed)
	_bind_options_menu(layout)
	_bind_test_balance_panel(layout)

	# 위치·폰트·색·버튼 상태 스타일은 game_hud.tscn에서 편집하고 여기서는 신호와 동적 문구만 연결한다.
	action_button.pressed.connect(_on_action_button_pressed)

	speed_button.pressed.connect(_on_speed_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)

	reroll_button.text = "새로고침\n%d G" % _current_reroll_cost()
	reroll_button.pressed.connect(_on_reroll_button_pressed)

	var card_count := mini(database.extension_int("shopCardCount", 5), 5)
	for card_index in card_count:
		var card := shop_ui.get_node("ShopCard%d" % (card_index + 1)) as PrototypeShopCard
		card.setup()
		shop_cards.append(card)
		shop_card_available.append(true)
		shop_turret_ids.append("")

	_update_day_night_hud_nodes()
	_update_speed_controls()


# 테스트 옵션과 데이터 편집 창은 game_hud.tscn에 포함된 편집 가능 씬에서 참조만 연결한다.
func _bind_test_balance_panel(layout: Control) -> void:
	test_balance_panel = layout.get_node("TestBalancePanel") as PrototypeTestBalancePanel
	test_balance_panel.setup(database)
	test_balance_panel.grant_gold_requested.connect(_on_test_grant_gold_requested)
	test_balance_panel.start_wave_requested.connect(_on_test_start_wave_requested)
	test_balance_panel.runtime_data_changed.connect(_on_test_runtime_data_changed)
	test_balance_panel.editor_visibility_changed.connect(_on_test_editor_visibility_changed)
	_update_test_mode_ui()


# Opening the modal cancels any half-finished battlefield drag so it cannot resume after closing.
func _on_test_editor_visibility_changed(opened: bool) -> void:
	if not opened:
		return
	_cancel_shop_card_drag()
	_cancel_tower_drag()


func _is_test_editor_open() -> bool:
	return test_balance_panel != null and test_balance_panel.is_editor_open()

# ESC 옵션 창의 모든 정적 노드는 options_menu.tscn에서 편집하고 여기서는 신호만 연결한다.
func _bind_options_menu(layout: Control) -> void:
	options_overlay = layout.get_node("OptionsMenu") as Control
	var continue_button := options_overlay.get_node("ContinueButton") as Button
	options_test_mode_button = options_overlay.get_node("TestModeButton") as Button
	var reset_button := options_overlay.get_node("ResetButton") as Button
	var quit_button := options_overlay.get_node("QuitButton") as Button
	continue_button.pressed.connect(_on_options_continue_pressed)
	options_test_mode_button.pressed.connect(_on_options_test_mode_pressed)
	reset_button.pressed.connect(_on_options_reset_pressed)
	quit_button.pressed.connect(_on_options_quit_pressed)
	options_overlay.connect("escape_pressed", _on_options_continue_pressed)
	_update_test_mode_ui()


# 모달 노출과 SceneTree 일시 정지를 한곳에서 함께 전환해 ESC와 계속하기 동작을 일치시킨다.
func _set_options_menu_visible(visible: bool) -> void:
	options_menu_open = visible
	if options_overlay != null:
		options_overlay.visible = visible
	get_tree().paused = visible


# 키보드 ESC와 원형 일시정지 버튼이 동일한 옵션 창 토글 경로를 공유한다.
func _toggle_options_menu() -> void:
	_set_options_menu_visible(not options_menu_open)


func _on_pause_button_pressed() -> void:
	if automated_test_mode:
		return
	_toggle_options_menu()


func _on_options_continue_pressed() -> void:
	_set_options_menu_visible(false)


# 일반↔테스트 환경 전환은 현재 판을 폐기하고 각 모드의 초기 골드·상점 상태로 새로 시작한다.
func _on_options_test_mode_pressed() -> void:
	_set_options_menu_visible(false)
	Engine.time_scale = 1.0
	test_mode = not test_mode
	# 테스트 세션의 런타임 편집값이 일반 모드나 다음 테스트 세션으로 유출되지 않게 원본을 복원한다.
	database.reset_all_balance_tables()
	game_speed_multiplier = 1
	_reset_game()
	_update_test_mode_ui()


func _on_options_reset_pressed() -> void:
	_set_options_menu_visible(false)
	Engine.time_scale = 1.0
	_reset_game()


func _on_options_quit_pressed() -> void:
	_set_options_menu_visible(false)
	Engine.time_scale = 1.0
	get_tree().quit()


# 게임 오버 화면의 다시 시작은 현재 판을 완전히 초기화하고 새 낮 단계에서 재개한다.
func _on_game_over_restart_pressed() -> void:
	if phase != Phase.DEFEAT:
		return
	Engine.time_scale = 1.0
	_reset_game()


func _on_game_over_quit_pressed() -> void:
	if phase != Phase.DEFEAT:
		return
	Engine.time_scale = 1.0
	get_tree().quit()


# 패배 진입 시 편집 가능한 오버레이 씬을 짧게 페이드인하고 다른 단계에서는 즉시 숨긴다.
func _set_game_over_visible(show_overlay: bool, instant: bool = false) -> void:
	if game_over_overlay == null:
		return
	if game_over_tween != null and game_over_tween.is_valid():
		game_over_tween.kill()
	if not show_overlay:
		game_over_overlay.visible = false
		game_over_overlay.modulate.a = 1.0
		return
	game_over_overlay.visible = true
	if instant:
		game_over_overlay.modulate.a = 1.0
		return
	game_over_overlay.modulate.a = 0.0
	game_over_tween = create_tween()
	game_over_tween.set_ignore_time_scale(true)
	game_over_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	game_over_tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.32)


# 승리 오버레이의 배치·색상·페이드 시간은 전용 씬과 Inspector 속성에서 관리한다.
func _set_game_clear_visible(show_overlay: bool, instant: bool = false) -> void:
	if game_clear_overlay == null:
		return
	game_clear_overlay.set_result_visible(show_overlay, instant)


# 일반 밤은 1→2→3배, 테스트 환경의 밤은 1→3→5→10배 순서로 순환한다.
func _on_speed_button_pressed() -> void:
	if phase != Phase.WAVE or automated_test_mode:
		return
	var available_speeds: Array = TEST_GAME_SPEED_MULTIPLIERS if test_mode else GAME_SPEED_MULTIPLIERS
	var current_index := available_speeds.find(game_speed_multiplier)
	var next_index := (current_index + 1) % available_speeds.size()
	game_speed_multiplier = int(available_speeds[next_index])
	Engine.time_scale = float(game_speed_multiplier)
	_update_speed_controls()


# 현재 단계와 선택값에 맞춰 배속 캡슐의 삼각형 개수와 두 버튼의 상태를 갱신한다.
func _update_speed_controls() -> void:
	if speed_button == null:
		return
	match game_speed_multiplier:
		2:
			speed_button.text = "▶ ▶"
		3:
			speed_button.text = "▶ ▶ ▶"
		5:
			speed_button.text = "×5"
		10:
			speed_button.text = "×10"
		_:
			speed_button.text = "▶"
	speed_button.visible = phase == Phase.WAVE
	if speed_button_backplate != null:
		speed_button_backplate.visible = speed_button.visible
	if speed_button_label != null:
		speed_button_label.text = speed_button.text
		speed_button_label.visible = speed_button.visible
	speed_button.disabled = phase != Phase.WAVE or automated_test_mode
	if pause_button != null:
		pause_button.visible = true
		if pause_button_backplate != null:
			pause_button_backplate.visible = true
		pause_button.disabled = automated_test_mode


# 테스트 배지와 옵션 버튼 문구를 현재 모드에 맞춰 동시에 갱신한다.
func _update_test_mode_ui() -> void:
	if test_mode_badge != null:
		test_mode_badge.visible = test_mode
	if options_test_mode_button != null:
		options_test_mode_button.text = "일반 모드로 돌아가기" if test_mode else "테스트 환경 시작"
	if test_balance_panel != null:
		test_balance_panel.set_test_mode_visible(test_mode)


# 테스트 보상은 진입 시 자동 지급하지 않고 우측 패널 버튼을 누를 때마다 정확히 9999 골드를 더한다.
func _on_test_grant_gold_requested(amount: int) -> void:
	if not test_mode:
		return
	gold += maxi(0, amount)
	_show_gold_gain_feedback(maxi(0, amount))
	_update_interface()
	_update_shop_cards()


# 선택한 웨이브의 스폰 일정으로 전장을 정리하고 즉시 밤을 시작한다. 설치 타워와 현재 골드는 보존한다.
func _on_test_start_wave_requested(wave_number: int) -> void:
	if not test_mode:
		return
	var total_wave_count := maxi(1, database.define_int("totalWaveCount", 1))
	current_wave_number = clampi(wave_number, 1, total_wave_count)
	current_wave_spawn_entries = database.get_wave_spawn_entries("wave%d" % current_wave_number)
	if current_wave_spawn_entries.is_empty():
		push_error("Test wave has no SpawnTable entries: wave%d" % current_wave_number)
		return
	_clear_transient_combat_effects()
	_start_wave(true)


# 런타임 테이블 변경을 이미 배치되거나 생성된 오브젝트와 현재 UI에 필요한 범위까지 즉시 동기화한다.
func _on_test_runtime_data_changed(table_name: String) -> void:
	if not test_mode:
		return
	if table_name.is_empty() or table_name == "Turret":
		for tower in towers:
			if is_instance_valid(tower):
				tower.apply_runtime_balance(database.get_turret_data(tower.turret_id))
		_refresh_current_shop_card_data()
	if table_name.is_empty() or table_name == "Monster":
		for monster in monsters:
			if is_instance_valid(monster):
				monster.apply_runtime_balance(database.get_monster_data(monster.monster_id))
	if table_name.is_empty() or table_name == "Define" or table_name == "SpawnTable":
		var total_wave_count := maxi(1, database.define_int("totalWaveCount", 1))
		current_wave_number = clampi(current_wave_number, 1, total_wave_count)
		current_wave_spawn_entries = database.get_wave_spawn_entries("wave%d" % current_wave_number)
		if phase == Phase.WAVE:
			next_spawn_index = mini(next_spawn_index, current_wave_spawn_entries.size())
			spawned_count = mini(spawned_count, current_wave_spawn_entries.size())
	if table_name.is_empty() or table_name == "ShopGacha":
		# 확률 변경은 현재 카드를 강제로 바꾸지 않고 다음 리롤부터 사용한다.
		pass
	_update_interface()
	_update_shop_cards()


# 현재 상점의 추첨 결과 ID는 유지하고 가격·공격 정보만 수정된 Turret 데이터로 다시 그린다.
func _refresh_current_shop_card_data() -> void:
	for card_index in mini(shop_cards.size(), shop_turret_ids.size()):
		shop_cards[card_index].set_tower_data(database.get_turret_data(shop_turret_ids[card_index]))


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


# B1~B3 각 5개, 총 15개의 고정 터렛 슬롯을 만든다.
func _create_tower_slots() -> void:
	var floor_slot_positions := battlefield_layout.get_tower_slot_positions()
	for floor_index in floor_slot_positions.size():
		var slot_positions: PackedVector2Array = floor_slot_positions[floor_index]
		for slot_index in slot_positions.size():
			var slot := TOWER_SLOT_SCENE.instantiate() as PrototypeTowerSlot
			slot.position = slot_positions[slot_index]
			slot.setup(floor_index, slot_index)
			slot.pressed.connect(_on_tower_slot_pressed)
			battlefield_world.add_child(slot)
			tower_slots.append(slot)


# 화면의 진행 버튼은 낮에 밤을 조기 시작하는 단일 역할만 담당한다.
func _on_action_button_pressed() -> void:
	if phase == Phase.READY:
		_start_wave()


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
	battlefield_world.add_child(tower)
	towers.append(tower)
	slot.set_occupant(tower)
	tower_slot_by_instance_id[tower.get_instance_id()] = slot
	return tower


# 현재 SpawnTable이 유효한지 확인하고 카운터/터렛 쿨다운을 초기화해 전투를 시작한다.
func _start_wave(clear_existing_monsters: bool = true) -> void:
	if current_wave_spawn_entries.is_empty():
		push_error("Current wave has no SpawnTable entries: wave%d" % current_wave_number)
		return
	# 최초 밤/전체 초기화만 기존 적을 제거한다. 시간 만료로 이어지는 다음 웨이브는 전장의 적과 투사체를 유지한다.
	if clear_existing_monsters:
		_clear_monsters()
	next_spawn_index = 0
	spawned_count = 0
	defeated_count = 0
	spawn_cooldown_sec = 0.15
	wave_remaining_sec = database.define_float("waveTimeSec", 50.0)
	# 상점 카드 드래그 중 전투가 시작돼도 구매 동작은 그대로 이어간다.
	if dragged_shop_card_index < 0:
		selected_shop_card = -1
	for tower in towers:
		if is_instance_valid(tower):
			tower.reset_for_wave()
	_set_phase(Phase.WAVE)


# 테스트 종류에 필요한 터렛을 자동 배치한 뒤 정비 시간을 건너뛰고 웨이브를 시작한다.
func _start_automated_test() -> void:
	if automated_test_test_environment:
		_run_test_environment_automated_test()
		return
	if automated_test_camera_navigation:
		_run_camera_navigation_automated_test()
		return
	if automated_test_merge:
		_run_merge_automated_test()
		return
	if automated_test_shop_merge:
		_run_shop_merge_automated_test()
		return
	if automated_test_wave_features:
		_run_wave_features_automated_test()
		return
	if automated_test_attack_styles:
		_run_attack_styles_automated_test()
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


# 테스트 전용 환경이 일반 시작 조건, 수동 보상·웨이브 점프·런타임 편집과 기존 고배속을 함께 제공하는지 검증한다.
func _run_test_environment_automated_test() -> void:
	var normal_start_gold_ok := gold == database.define_int("initialGold", 100)
	var expected_test_shop := database.all_shop_turret_ids()
	var full_shop_ok := shop_turret_ids == expected_test_shop and shop_turret_ids.size() == shop_cards.size()
	var panel_visible_ok := test_balance_panel != null and test_balance_panel.visible
	_set_battlefield_view_index(1, true)
	test_balance_panel.call("_open_table", "Turret")
	var modal_open_ok := test_balance_panel.is_editor_open() and get_tree().paused
	var modal_focus_ok := get_viewport().gui_get_focus_owner() == test_balance_panel.editor_overlay
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	_input(escape_event)
	var modal_escape_blocked_ok := test_balance_panel.is_editor_open() and not options_menu_open
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	_input(wheel_event)
	var modal_navigation_blocked_ok := battlefield_view_index == 1
	test_balance_panel.call("_close_editor")
	var modal_close_ok := not test_balance_panel.is_editor_open() and not get_tree().paused
	var preparation_before_manual_step := preparation_remaining_sec
	_process(1.0)
	var manual_ready_ok := phase == Phase.READY and is_equal_approx(preparation_remaining_sec, preparation_before_manual_step)
	_on_test_grant_gold_requested(9999)
	var manual_gold_ok := gold == database.define_int("initialGold", 100) + 9999
	_on_reroll_button_pressed()
	var reroll_full_shop_ok := shop_turret_ids == expected_test_shop
	var original_damage := float(database.get_turret_data("turretMelee1").get("damage", 0.0))
	var edit_errors := database.apply_balance_edits("Turret", [{"row_id": "turretMelee1", "column": "damage", "value": str(original_damage + 7.0)}])
	_on_test_runtime_data_changed("Turret")
	var runtime_edit_ok := edit_errors.is_empty() and is_equal_approx(float(database.get_turret_data("turretMelee1").get("damage", 0.0)), original_damage + 7.0)
	var source_difference_detected_ok := database.balance_value_differs_from_source("Turret", "turretMelee1", "damage", str(original_damage + 7.0))
	database.reset_balance_table("Turret")
	_on_test_runtime_data_changed("Turret")
	var source_reset_ok := is_equal_approx(float(database.get_turret_data("turretMelee1").get("damage", 0.0)), original_damage)
	var source_difference_cleared_ok := not database.balance_value_differs_from_source("Turret", "turretMelee1", "damage", str(original_damage))
	_on_test_start_wave_requested(2)
	var wave_jump_ok := current_wave_number == 2 and phase == Phase.WAVE and not current_wave_spawn_entries.is_empty()
	wave_remaining_sec = 0.01
	_process(0.02)
	var manual_next_wave_ok := current_wave_number == 2 and phase == Phase.WAVE and is_zero_approx(wave_remaining_sec)
	# 실제 버튼 경로를 열어 테스트 배속이 3→5→10→1로 순환하는지 확인한다.
	automated_test_mode = false
	var observed_speed_cycle: Array[int] = []
	for _step in 4:
		_on_speed_button_pressed()
		observed_speed_cycle.append(game_speed_multiplier)
	var speed_values_ok := TEST_GAME_SPEED_MULTIPLIERS == [1, 3, 5, 10] \
		and observed_speed_cycle == [3, 5, 10, 1] \
		and is_equal_approx(Engine.time_scale, 1.0)
	automated_test_mode = true
	var test_button_ok := options_test_mode_button != null and options_test_mode_button.text == "일반 모드로 돌아가기"
	var passed := test_mode \
		and normal_start_gold_ok \
		and full_shop_ok \
		and reroll_full_shop_ok \
		and modal_open_ok \
		and modal_focus_ok \
		and modal_escape_blocked_ok \
		and modal_navigation_blocked_ok \
		and modal_close_ok \
		and manual_ready_ok \
		and panel_visible_ok \
		and manual_gold_ok \
		and runtime_edit_ok \
		and source_difference_detected_ok \
		and source_reset_ok \
		and source_difference_cleared_ok \
		and wave_jump_ok \
		and manual_next_wave_ok \
		and test_mode_badge != null \
		and test_mode_badge.visible \
		and speed_values_ok \
		and test_button_ok
	if passed:
		print("Automated test environment passed: MANUAL_WAVES_FULL_SHOP_RUNTIME_TABLE_SPEED_10X")
	else:
		push_error("Automated test environment failed: normal=%s full_shop=%s reroll_shop=%s modal=%s focus=%s escape=%s navigation=%s close=%s manual_ready=%s panel=%s gold=%s edit=%s diff=%s reset=%s diff_clear=%s wave=%s manual_next=%s speed=%s button=%s" % [normal_start_gold_ok, full_shop_ok, reroll_full_shop_ok, modal_open_ok, modal_focus_ok, modal_escape_blocked_ok, modal_navigation_blocked_ok, modal_close_ok, manual_ready_ok, panel_visible_ok, manual_gold_ok, runtime_edit_ok, source_difference_detected_ok, source_reset_ok, source_difference_cleared_ok, wave_jump_ok, manual_next_wave_ok, speed_values_ok, test_button_ok])
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 경로와 수직으로 떨어진 근접 포탑이 같은 층·수평 사거리 안의 적을 찾아 실제 피해를 주는지 검증한다.
func _run_melee_attack_automated_test() -> void:
	_place_tower(tower_slots[0], false, "turretMelee1")
	var melee_tower := towers[0]
	var monster_data := database.get_monster_data("normal1")
	var target_monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	target_monster.setup(monster_data, movement_path)
	battlefield_world.add_child(target_monster)
	# 포탑과 X좌표는 같고 Y좌표는 실제 전투 경로에 두어 수평 거리 판정을 직접 검증한다.
	target_monster.position = target_monster.center_position_for_floor_contact(Vector2(melee_tower.position.x, battlefield_layout.get_combat_lane_y(0)))
	target_monster.path_index = 3
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


# 다섯 터렛 타입의 히트스캔·투사체 분기와 기존 피해/상태이상 적용 시점을 한 번에 검증한다.
func _run_attack_styles_automated_test() -> void:
	var test_origin := Vector2(500.0, battlefield_layout.get_combat_lane_y(0) - 100.0)

	# MELEE는 투사체 없이 즉시 피해를 주고 할퀴기 이펙트를 생성해야 한다.
	var melee_tower := _create_attack_test_tower("turretMelee1", test_origin)
	var melee_monster := _create_attack_test_monster(test_origin.x + 20.0)
	var melee_hp_before := melee_monster.hp
	melee_tower._process(melee_tower.attack_interval_sec)
	var melee_ok := melee_monster.hp < melee_hp_before \
		and get_tree().get_nodes_in_group("tower_projectiles").is_empty() \
		and not get_tree().get_nodes_in_group("tower_hit_effects").is_empty()
	_free_attack_test_nodes(melee_tower, melee_monster)

	# DOT는 rangeValue=1.5칸 안의 표적을 선택하고 화염방사가 닿은 뒤에만 기본 피해와 화상을 적용한다.
	var dot_tower := _create_attack_test_tower("turretDot1", test_origin)
	var dot_monster := _create_attack_test_monster(test_origin.x + 200.0)
	var dot_hp_before := dot_monster.hp
	dot_tower._process(dot_tower.attack_interval_sec)
	var dot_flamethrower := _latest_attack_test_flamethrower()
	var dot_waited_for_impact := dot_flamethrower != null and is_equal_approx(dot_monster.hp, dot_hp_before)
	if dot_flamethrower != null:
		dot_flamethrower._process(0.21)
	var dot_ok := dot_waited_for_impact and dot_monster.hp < dot_hp_before and dot_monster.dot_remaining_sec > 0.0
	_free_attack_test_nodes(dot_tower, dot_monster)
	# 화염방사가 닿기 전에 표적이 층 이동을 시작하면 추적과 피해가 모두 취소되어야 한다.
	var dot_cancel_tower := _create_attack_test_tower("turretDot1", test_origin)
	var dot_cancel_monster := _create_attack_test_monster(test_origin.x + 200.0)
	var dot_cancel_hp_before := dot_cancel_monster.hp
	dot_cancel_tower._process(dot_cancel_tower.attack_interval_sec)
	var cancelled_flamethrower := _latest_attack_test_flamethrower()
	dot_cancel_monster.floor_transfer_active = true
	if cancelled_flamethrower != null:
		cancelled_flamethrower._process(0.21)
	var dot_floor_cancel_ok := cancelled_flamethrower != null \
		and cancelled_flamethrower.is_queued_for_deletion() \
		and is_equal_approx(dot_cancel_monster.hp, dot_cancel_hp_before)
	_free_attack_test_nodes(dot_cancel_tower, dot_cancel_monster)

	# SLOW 눈덩이는 명중 전에는 변화가 없고 명중 뒤 이동 배율을 낮춰야 한다.
	var slow_tower := _create_attack_test_tower("turretSlow1", test_origin)
	var slow_monster := _create_attack_test_monster(test_origin.x + 220.0)
	var slow_hp_before := slow_monster.hp
	slow_tower._process(slow_tower.attack_interval_sec)
	var slow_projectile := _latest_attack_test_projectile()
	var slow_waited_for_impact := slow_projectile != null and is_equal_approx(slow_monster.hp, slow_hp_before)
	if slow_projectile != null:
		slow_projectile._process(1.0)
	var slow_ok := slow_waited_for_impact and slow_monster.hp < slow_hp_before and slow_monster.slow_multiplier < 1.0
	_free_attack_test_nodes(slow_tower, slow_monster)

	# RANGED 초록 콩알은 상태이상 없이 투사체 명중 시점에만 피해를 준다.
	var ranged_tower := _create_attack_test_tower("turretRanged1", test_origin)
	var ranged_monster := _create_attack_test_monster(test_origin.x + 220.0)
	var ranged_hp_before := ranged_monster.hp
	ranged_tower._process(ranged_tower.attack_interval_sec)
	var ranged_projectile := _latest_attack_test_projectile()
	var ranged_waited_for_impact := ranged_projectile != null and is_equal_approx(ranged_monster.hp, ranged_hp_before)
	if ranged_projectile != null:
		ranged_projectile._process(1.0)
	var ranged_ok := ranged_waited_for_impact \
		and ranged_monster.hp < ranged_hp_before \
		and ranged_monster.dot_remaining_sec == 0.0 \
		and ranged_monster.slow_remaining_sec == 0.0 \
		and ranged_monster.stun_remaining_sec == 0.0
	_free_attack_test_nodes(ranged_tower, ranged_monster)
	# 이동 투사체도 표적이 층 이동을 시작한 즉시 소멸하고 기존 층에서 피해를 주지 않아야 한다.
	var projectile_cancel_tower := _create_attack_test_tower("turretRanged1", test_origin)
	var projectile_cancel_monster := _create_attack_test_monster(test_origin.x + 220.0)
	var projectile_cancel_hp_before := projectile_cancel_monster.hp
	projectile_cancel_tower._process(projectile_cancel_tower.attack_interval_sec)
	var cancelled_projectile := _latest_attack_test_projectile()
	projectile_cancel_monster.floor_transfer_active = true
	if cancelled_projectile != null:
		cancelled_projectile._process(0.05)
	var projectile_floor_cancel_ok := cancelled_projectile != null \
		and cancelled_projectile.is_queued_for_deletion() \
		and is_equal_approx(projectile_cancel_monster.hp, projectile_cancel_hp_before)
	_free_attack_test_nodes(projectile_cancel_tower, projectile_cancel_monster)

	# STUN은 충전 중 피해가 없고 충전 완료 후 낙뢰 히트스캔·기절·헤롱헤롱 이펙트를 생성한다.
	var stun_tower := _create_attack_test_tower("turretStun1", test_origin)
	var stun_monster := _create_attack_test_monster(test_origin.x + 220.0)
	var stun_hp_before := stun_monster.hp
	stun_tower._process(0.01)
	var stun_charged_before_hit := stun_tower.stun_charge_remaining_sec > 0.0 and is_equal_approx(stun_monster.hp, stun_hp_before)
	stun_tower._process(PrototypeTower.STUN_CHARGE_DURATION_SEC + 0.01)
	var stun_ok := stun_charged_before_hit \
		and stun_monster.hp < stun_hp_before \
		and stun_monster.stun_remaining_sec > 0.0 \
		and not get_tree().get_nodes_in_group("tower_hit_effects").is_empty()
	_free_attack_test_nodes(stun_tower, stun_monster)

	var passed := melee_ok and dot_ok and dot_floor_cancel_ok and slow_ok and ranged_ok and projectile_floor_cancel_ok and stun_ok
	if passed:
		print("Automated attack style test passed: HITSCAN_PROJECTILES_STATUS_VFX")
	else:
		push_error("Automated attack style test failed: melee=%s dot=%s dot_cancel=%s slow=%s ranged=%s projectile_cancel=%s stun=%s" % [melee_ok, dot_ok, dot_floor_cancel_ok, slow_ok, ranged_ok, projectile_floor_cancel_ok, stun_ok])
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


func _create_attack_test_tower(turret_id: String, spawn_position: Vector2) -> PrototypeTower:
	var tower := TowerScript.new() as PrototypeTower
	tower.position = spawn_position
	tower.setup(database.get_turret_data(turret_id), 0)
	battlefield_world.add_child(tower)
	return tower


func _create_attack_test_monster(spawn_x: float) -> PrototypeMonster:
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	monster.setup(database.get_monster_data("boss1"), movement_path)
	monster.position = monster.center_position_for_floor_contact(Vector2(spawn_x, battlefield_layout.get_combat_lane_y(0)))
	monster.path_index = 3
	monster.move_state = PrototypeMonster.MoveState.WALKING
	monster.scale = Vector2.ONE
	battlefield_world.add_child(monster)
	return monster


func _latest_attack_test_projectile() -> PrototypeTowerProjectile:
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	return projectiles.back() as PrototypeTowerProjectile if not projectiles.is_empty() else null


func _latest_attack_test_flamethrower() -> Node2D:
	var flamethrowers := get_tree().get_nodes_in_group("tower_flamethrowers")
	return flamethrowers.back() as Node2D if not flamethrowers.is_empty() else null


func _free_attack_test_nodes(tower: PrototypeTower, monster: PrototypeMonster) -> void:
	if is_instance_valid(tower):
		tower.free()
	if is_instance_valid(monster):
		monster.free()
	for group_name in ["tower_projectiles", "tower_flamethrowers", "tower_hit_effects"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.free()


# 불파괴 터렛, 보상, 시간 전환 시 적 유지, 마지막 보스 웨이브 전멸 승리를 함께 검증한다.
func _run_wave_features_automated_test() -> void:
	_place_tower(tower_slots[0], false, "turretMelee1")
	var test_tower := towers[0]
	var monster_data := database.get_monster_data("normal1")
	var passing_monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	passing_monster.setup(monster_data, movement_path)
	battlefield_world.add_child(passing_monster)
	passing_monster.position = passing_monster.center_position_for_floor_contact(Vector2(test_tower.position.x, battlefield_layout.get_combat_lane_y(0)))
	passing_monster.path_index = 3
	passing_monster.move_state = PrototypeMonster.MoveState.WALKING
	passing_monster.scale = Vector2.ONE
	monsters.append(passing_monster)
	var monster_start_x := passing_monster.position.x
	# 이 테스트에서만 일반 플레이 배속 분기를 실행하고, 종료 전 자동 테스트 상태를 복원한다.
	automated_test_mode = false
	_set_phase(Phase.WAVE)
	_on_speed_button_pressed()
	_on_speed_button_pressed()
	passing_monster._process(0.1)
	var night_state_ok := not phase_label.visible and wave_label.visible and speed_button.visible and speed_button.text == "▶ ▶ ▶" and pause_button.visible and not action_button.visible
	var triple_speed_applied := game_speed_multiplier == 3 and is_equal_approx(Engine.time_scale, 3.0)
	var tower_remained_fixed := is_instance_valid(test_tower) and towers.has(test_tower) and passing_monster.position.x < monster_start_x
	monsters.erase(passing_monster)
	passing_monster.queue_free()
	# 실제 처치 콜백이 데이터 보상 지급, +n G 표시와 사망 위치 동전을 함께 생성하는지 확인한다.
	var reward_monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	reward_monster.setup(monster_data, movement_path)
	reward_monster.position = reward_monster.center_position_for_floor_contact(Vector2(820.0, battlefield_layout.get_combat_lane_y(0)))
	reward_monster.reward_gold = 2
	battlefield_world.add_child(reward_monster)
	monsters.append(reward_monster)
	var gold_before_reward := gold
	_on_monster_defeated(reward_monster)
	var reward_feedback_ok := gold == gold_before_reward + 2 \
		and gold_gain_label.visible \
		and gold_gain_label.text == "+ 2 G" \
		and not get_tree().get_nodes_in_group("reward_coin_popups").is_empty()
	var ordinary_kill_kept_wave_running := phase == Phase.WAVE and current_wave_number == 1
	reward_monster.queue_free()
	# 기준시간 전환 직전의 적은 다음 웨이브가 시작되어도 전장과 추적 배열에 남아야 한다.
	var carryover_monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	carryover_monster.setup(monster_data, movement_path)
	battlefield_world.add_child(carryover_monster)
	monsters.append(carryover_monster)
	current_wave_number = 1
	wave_remaining_sec = 0.01
	_process(0.02)
	var wave_advanced_immediately := phase == Phase.WAVE \
		and current_wave_number == 2 \
		and is_equal_approx(wave_remaining_sec, database.define_float("waveTimeSec", 50.0)) \
		and not phase_label.visible \
		and wave_label.visible
	var carryover_preserved := is_instance_valid(carryover_monster) and monsters.has(carryover_monster)
	var speed_preserved := game_speed_multiplier == 3 and is_equal_approx(Engine.time_scale, 3.0)
	_on_pause_button_pressed()
	var options_opened := options_menu_open and options_overlay.visible and get_tree().paused
	_on_pause_button_pressed()
	var options_closed := not options_menu_open and not options_overlay.visible and not get_tree().paused
	current_wave_number = database.define_int("totalWaveCount", 1)
	current_wave_spawn_entries = [
		{"monster_id": "boss1"},
		{"monster_id": "boss1"},
	]
	next_spawn_index = current_wave_spawn_entries.size()
	spawned_count = current_wave_spawn_entries.size()
	wave_remaining_sec = 0.01
	_process(0.02)
	var final_wave_waits_for_boss := phase == Phase.WAVE and wave_remaining_sec == 0.0
	# 보스 한 기 처치만으로는 승리하지 않고, 보스 웨이브와 이전 웨이브 잔존 적을 모두 처치해야 한다.
	var first_boss := MONSTER_SCENE.instantiate() as PrototypeMonster
	var second_boss := MONSTER_SCENE.instantiate() as PrototypeMonster
	first_boss.setup(database.get_monster_data("boss1"), movement_path)
	second_boss.setup(database.get_monster_data("boss1"), movement_path)
	battlefield_world.add_child(first_boss)
	battlefield_world.add_child(second_boss)
	monsters.append(first_boss)
	monsters.append(second_boss)
	_on_monster_defeated(first_boss)
	var first_boss_did_not_win := phase == Phase.WAVE
	_on_monster_defeated(second_boss)
	var boss_wave_waited_for_carryover := phase == Phase.WAVE and monsters.has(carryover_monster)
	_on_monster_defeated(carryover_monster)
	var full_clear_victory := phase == Phase.VICTORY
	first_boss.queue_free()
	second_boss.queue_free()
	carryover_monster.queue_free()
	var passed := night_state_ok and triple_speed_applied and tower_remained_fixed and reward_feedback_ok and ordinary_kill_kept_wave_running and wave_advanced_immediately and carryover_preserved and speed_preserved and options_opened and options_closed and final_wave_waits_for_boss and first_boss_did_not_win and boss_wave_waited_for_carryover and full_clear_victory
	automated_test_mode = true
	if passed:
		print("Automated wave feature test passed: TIMED_PERSISTENCE_FULL_BOSS_WAVE_CLEAR")
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


# 같은 층 이동 성공, 다른 층 이동 거부와 상점 영역의 잘못된 드롭 복원을 함께 검증한다.
func _run_drag_automated_test() -> void:
	var origin := tower_slots[0]
	var same_floor_target := tower_slots[1]
	var other_floor_target := tower_slots[5]
	# 평상시 0%, 조작 중 30%, 조작 종료 후 0%로 복원되는 슬롯 표시 규칙을 직접 확인한다.
	var slot_hidden_at_idle := not same_floor_target.visual.visible and is_zero_approx(same_floor_target.visual.modulate.a)
	same_floor_target.set_drag_state(true, false)
	var slot_visible_during_drag := same_floor_target.visual.visible and is_equal_approx(same_floor_target.visual.modulate.a, PrototypeTowerSlot.ACTIVE_SLOT_OPACITY)
	same_floor_target.set_drag_state(false, false)
	var slot_hidden_after_drag := not same_floor_target.visual.visible and is_zero_approx(same_floor_target.visual.modulate.a)
	_place_tower(origin, false, "turretMelee1")
	var tower := towers[0]
	var cross_floor_rejected := not _relocate_tower(tower, other_floor_target)
	var same_floor_moved := _relocate_tower(tower, same_floor_target)
	var gold_before_invalid_drop := gold
	_begin_tower_drag(tower, same_floor_target, tower.position)
	_update_tower_drag(battlefield_world.to_local(position + Vector2(960.0, 1000.0)))
	_finish_tower_drag()
	var invalid_shop_drop_restored := same_floor_target.occupant == tower and tower.position == same_floor_target.position and gold == gold_before_invalid_drop
	var passed := slot_hidden_at_idle and slot_visible_during_drag and slot_hidden_after_drag \
		and _tower_slot_layout_is_valid() and cross_floor_rejected and same_floor_moved \
		and invalid_shop_drop_restored and origin.is_empty()
	if passed:
		print("Automated drag test passed: SAME_FLOOR_ONLY_INVALID_SHOP_DROP_RESTORED")
	else:
		push_error("Automated drag test failed: idle=%s active=%s cleared=%s layout=%s cross_floor=%s same_floor=%s invalid_drop=%s origin_empty=%s" % [slot_hidden_at_idle, slot_visible_during_drag, slot_hidden_after_drag, _tower_slot_layout_is_valid(), cross_floor_rejected, same_floor_moved, invalid_shop_drop_restored, origin.is_empty()])
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 서로 다른 층과 밤에도 동일 ID/Tier 수동 머지가 가능하고 상위 데이터 스탯이 적용되는지 검증한다.
func _run_merge_automated_test() -> void:
	var source_slot := tower_slots[0]
	var cross_floor_slot := tower_slots[5]
	var different_type_slot := tower_slots[2]
	var source := _place_tower(source_slot, false, "turretMelee1")
	var cross_floor_target := _place_tower(cross_floor_slot, false, "turretMelee1")
	var different_type_target := _place_tower(different_type_slot, false, "turretDot1")
	var no_automatic_merge := source_slot.occupant == source and cross_floor_slot.occupant == cross_floor_target and towers.has(source) and towers.has(cross_floor_target)
	var cross_floor_allowed := _can_merge_towers(source, cross_floor_target)
	var different_type_rejected := not _can_merge_towers(source, different_type_target)
	_set_phase(Phase.WAVE)
	var night_merge_allowed := _can_merge_towers(source, cross_floor_target)
	var merged := _merge_tower(source, cross_floor_slot)
	var upgraded := cross_floor_slot.occupant as PrototypeTower
	var upgraded_data := database.get_turret_data("turretMelee2")
	var upgraded_stats_applied := upgraded != null \
		and upgraded.turret_id == "turretMelee2" \
		and upgraded.floor_index == cross_floor_slot.floor_index \
		and upgraded.tier == int(upgraded_data.get("tier", -1)) \
		and is_equal_approx(upgraded.damage, float(upgraded_data.get("damage", -1.0))) \
		and is_equal_approx(upgraded.attack_interval_sec, float(upgraded_data.get("attack_interval_sec", -1.0))) \
		and upgraded.upgrade_effect_remaining_sec > 0.0
	var source_consumed := source_slot.is_empty() and not towers.has(source) and not towers.has(cross_floor_target)
	var passed := no_automatic_merge and cross_floor_allowed and different_type_rejected and night_merge_allowed and merged and source_consumed and upgraded_stats_applied
	if passed:
		print("Automated merge test passed: MANUAL_CROSS_FLOOR_DAY_NIGHT_DATA_DRIVEN")
	else:
		push_error("Automated merge test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)

# 편집용 씬에 층별 슬롯이 빠짐없이 있고 같은 층의 두 슬롯이 완전히 겹치지 않는지 검증한다.
func _tower_slot_layout_is_valid() -> bool:
	if not battlefield_layout.validate_layout().is_empty():
		return false
	var floors := battlefield_layout.get_tower_slot_positions()
	for floor_positions in floors:
		for first_index in floor_positions.size():
			for second_index in range(first_index + 1, floor_positions.size()):
				if floor_positions[first_index].is_equal_approx(floor_positions[second_index]):
					return false
	return true


# 네 카메라 정지점과 경계 제한, 전장 이미지의 균일 축소 조건을 헤드리스 환경에서 검증한다.
func _run_camera_navigation_automated_test() -> void:
	_set_battlefield_view_index(1, true)
	var expected_middle_y := _battlefield_view_target_y(1)
	var middle_view_valid := battlefield_view_index == 1 \
		and is_equal_approx(battlefield_world.position.y, expected_middle_y) \
		and is_equal_approx(battlefield_background.position.y, expected_middle_y)
	_set_battlefield_view_index(99, true)
	var bottom_index := battlefield_camera_y.size() - 1
	var expected_bottom_y := _battlefield_view_target_y(bottom_index)
	var bottom_clamped := battlefield_view_index == bottom_index \
		and is_equal_approx(battlefield_world.position.y, expected_bottom_y) \
		and is_equal_approx(battlefield_background.position.y, expected_bottom_y)
	_set_battlefield_view_index(-99, true)
	var expected_top_y := _battlefield_view_target_y(0)
	var top_clamped := battlefield_view_index == 0 \
		and is_equal_approx(battlefield_world.position.y, expected_top_y) \
		and is_equal_approx(battlefield_background.position.y, expected_top_y)
	# 배경·몬스터·터렛의 부모에 같은 X/Y 배율을 적용해 어떤 이미지도 찌그러뜨리지 않는다.
	var uniform_scale_valid := battlefield_world.scale == BATTLEFIELD_CAMERA_UNIFORM_SCALE \
		and battlefield_background.scale == BATTLEFIELD_CAMERA_UNIFORM_SCALE \
		and is_equal_approx(battlefield_world.scale.x, battlefield_world.scale.y) \
		and is_equal_approx(battlefield_background.scale.x, battlefield_background.scale.y) \
		and is_equal_approx(battlefield_world.position.x, BATTLEFIELD_CAMERA_HORIZONTAL_INSET) \
		and is_equal_approx(battlefield_background.position.x, BATTLEFIELD_CAMERA_HORIZONTAL_INSET) \
		and is_equal_approx(battlefield_background.horizontal_extension_px * BATTLEFIELD_CAMERA_SCALE, BATTLEFIELD_CAMERA_HORIZONTAL_INSET)
	var reference_frame_clipped := battlefield_background_clip.clip_contents and battlefield_background_clip.size == REFERENCE_VIEWPORT_SIZE
	# 두 층 화면은 위층 오브젝트 공간을 넓히고 아래층 접촉선은 상점 바로 위에 유지한다.
	var two_floor_clearance_valid := true
	for view_index in range(1, battlefield_camera_y.size()):
		var upper_floor_index := view_index - 2
		var lower_floor_index := view_index - 1
		var upper_lane_y := battlefield_layout.get_ground_lane_y() if upper_floor_index < 0 else battlefield_layout.get_combat_lane_y(upper_floor_index)
		var target_y := _battlefield_view_target_y(view_index)
		var upper_contact_screen_y: float = upper_lane_y * BATTLEFIELD_CAMERA_SCALE + target_y
		var lower_contact_screen_y: float = battlefield_layout.get_combat_lane_y(lower_floor_index) * BATTLEFIELD_CAMERA_SCALE + target_y
		two_floor_clearance_valid = two_floor_clearance_valid \
			and upper_contact_screen_y >= 260.0 \
			and lower_contact_screen_y <= BATTLEFIELD_ENTITY_VIEW_HEIGHT - 10.0
	# 지상 등장 애니메이션 중간에도 스케일된 몸체의 발끝은 경로 접촉선에 고정돼야 한다.
	var spawn_test_monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	spawn_test_monster.setup(database.get_monster_data("normal1"), movement_path)
	battlefield_world.add_child(spawn_test_monster)
	spawn_test_monster._process(0.12)
	# body_bottom_offset_y는 완전 표시 배율까지 반영된 값이므로 현재 등장 비율만 다시 곱한다.
	var spawn_reveal_ratio := spawn_test_monster.scale.y / PrototypeMonster.MONSTER_VISUAL_SCALE
	var scaled_spawn_bottom := spawn_test_monster.position.y + spawn_test_monster.body_bottom_offset_y * spawn_reveal_ratio
	var grounded_spawn_valid := is_equal_approx(scaled_spawn_bottom, battlefield_layout.get_ground_lane_y())
	spawn_test_monster.free()
	var editable_layout_valid := battlefield_layout.validate_layout().is_empty() \
		and movement_path[0].is_equal_approx(battlefield_layout.get_monster_path_points()[0]) \
		and movement_path[-1].is_equal_approx(battlefield_layout.get_monster_path_points()[-1]) \
		and _tower_slot_layout_is_valid()
	var passed := middle_view_valid and bottom_clamped and top_clamped and uniform_scale_valid and reference_frame_clipped and two_floor_clearance_valid and grounded_spawn_valid and editable_layout_valid
	if passed:
		print("Automated camera navigation test passed: FOUR_STOPS_UNIFORM_90_PERCENT_SCALE")
	else:
		push_error("Automated camera navigation test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 리롤 비용 10→15 증가와 전체 게임 초기화 시 기본 비용 복원을 검증한다.
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
	_reset_game()
	passed = passed \
		and _current_reroll_cost() == base_cost \
		and gold == database.define_int("initialGold", 100)
	if passed:
		print("Automated economy test passed: REROLL_10_15_RUN_RESET")
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
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	monster.setup(monster_data, movement_path)
	monster.defeated.connect(_on_monster_defeated)
	monster.reached_deepest_floor.connect(_on_monster_reached_deepest_floor)
	battlefield_world.add_child(monster)
	monsters.append(monster)
	spawned_count += 1
	_update_interface()
	return float(spawn_entry.get("delay_after_sec", fallback_interval))


# 처치된 몬스터를 목록에서 제거하고 보상을 지급한 뒤 마지막 보스 웨이브 전멸 여부를 확인한다.
func _on_monster_defeated(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	defeated_count += 1
	var reward_amount := monster.reward_gold
	_spawn_reward_coin(monster.position)
	_show_gold_gain_feedback(reward_amount)
	gold += reward_amount
	_update_interface()
	_update_shop_cards()
	_check_final_wave_victory()


# 몬스터의 마지막 월드 좌표에 작은 동전 팝업을 추가한다.
func _spawn_reward_coin(spawn_position: Vector2) -> void:
	var coin_popup := RewardCoinPopupScript.new() as PrototypeRewardCoinPopup
	coin_popup.setup(spawn_position)
	battlefield_world.add_child(coin_popup)


# 골드 제어부 안의 +n G 문구를 위로 살짝 띄우고 사라지게 하며 연속 처치 시 애니메이션을 갱신한다.
func _show_gold_gain_feedback(reward_amount: int) -> void:
	if gold_gain_label == null:
		return
	if gold_gain_tween != null and gold_gain_tween.is_valid():
		gold_gain_tween.kill()
	gold_gain_label.text = "+ %d G" % reward_amount
	# 시작점은 game_hud.tscn에서 배치한 위치를 사용해 편집기 조정값을 보존한다.
	gold_gain_label.position = gold_gain_base_position
	gold_gain_label.modulate = Color.WHITE
	gold_gain_label.visible = true
	gold_gain_tween = create_tween()
	gold_gain_tween.set_ignore_time_scale(true)
	gold_gain_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gold_gain_tween.tween_property(gold_gain_label, "position:y", gold_gain_base_position.y - 36.0, 0.68)
	gold_gain_tween.parallel().tween_property(gold_gain_label, "modulate:a", 0.0, 0.42).set_delay(0.32)
	gold_gain_tween.tween_callback(func() -> void: gold_gain_label.visible = false)


# 별도 코어 그래픽 없이 B3 왼쪽 경로 끝 좌표 도달만 패배로 처리한다.
func _on_monster_reached_deepest_floor(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	if phase == Phase.WAVE:
		_set_phase(Phase.DEFEAT)


# 기준시간이 끝나도 기존 적과 투사체를 유지하고 낮 단계를 거치지 않은 채 다음 웨이브를 추가로 시작한다.
func _start_next_wave_immediately() -> void:
	var next_wave_number := current_wave_number + 1
	var next_wave_entries := database.get_wave_spawn_entries("wave%d" % next_wave_number)
	if next_wave_entries.is_empty():
		push_error("Next wave has no SpawnTable entries: wave%d" % next_wave_number)
		return
	current_wave_number = next_wave_number
	current_wave_spawn_entries = next_wave_entries
	status_label.text = ""
	_start_wave(false)


# 마지막 웨이브의 모든 개체가 생성됐고 이전 웨이브 잔존 적까지 전부 사라졌을 때만 승리한다.
func _check_final_wave_victory() -> void:
	if phase != Phase.WAVE:
		return
	if current_wave_number < database.define_int("totalWaveCount", 1):
		return
	if spawned_count < current_wave_spawn_entries.size() or not monsters.is_empty():
		return
	_set_phase(Phase.VICTORY)

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
	_set_game_clear_visible(phase == Phase.VICTORY, automated_test_mode)
	_set_game_over_visible(phase == Phase.DEFEAT, automated_test_mode)
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
	day_night_tween.tween_property(self, "night_visual_amount", target_amount, 1.2)


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


# 테스트 웨이브 점프 시 이전 대상에 연결된 투사체·화염방사·피격 잔상을 함께 정리한다.
func _clear_transient_combat_effects() -> void:
	for group_name in ["tower_projectiles", "tower_flamethrowers", "tower_hit_effects"]:
		for effect in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(effect):
				effect.queue_free()


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
	if gold_gain_tween != null and gold_gain_tween.is_valid():
		gold_gain_tween.kill()
	if gold_gain_label != null:
		gold_gain_label.visible = false
	for coin_popup in get_tree().get_nodes_in_group("reward_coin_popups"):
		if is_instance_valid(coin_popup):
			coin_popup.queue_free()
	current_wave_number = 1
	_set_battlefield_view_index(0, true)
	_configure_shop_rng()
	_begin_preparation(true)


# 게임 시작 또는 웨이브 사이 정비 시간을 설정하고 상점/리롤 상태를 초기화한다.
# reset_run=false일 때는 기존 골드와 살아 있는 터렛을 보존한다.
func _begin_preparation(reset_run: bool) -> void:
	if reset_run:
		# 테스트 모드도 일반 모드와 같은 데이터 시작 골드를 사용하고 추가 골드는 우측 패널에서 수동 지급한다.
		gold = database.define_int("initialGold", 100)
	reroll_count = 0
	preparation_remaining_sec = database.define_float("prepareTimeSec", 20.0)
	current_wave_spawn_entries = database.get_wave_spawn_entries("wave%d" % current_wave_number)
	selected_shop_card = -1
	_set_phase(Phase.READY)
	_refresh_shop_cards()
	status_label.text = ""
	_update_interface()


# ShopGacha 확률로 카드 ID를 새로 뽑고 카드에 타입·능력치·가격을 표시한다.
func _refresh_shop_cards() -> void:
	# Test mode exposes every Tier 1 type once; normal mode keeps the ShopGacha roll.
	shop_turret_ids = database.all_shop_turret_ids() if test_mode else database.roll_shop_turret_ids(shop_rng, shop_cards.size())
	# Keep the UI safe if a malformed table temporarily provides fewer rows than card slots.
	while shop_turret_ids.size() < shop_cards.size():
		shop_turret_ids.append(database.first_shop_turret_id())
	if shop_turret_ids.size() > shop_cards.size():
		shop_turret_ids.resize(shop_cards.size())
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
		# 낮·밤 배경 교차 페이드는 CanvasLayer 상점 카드의 밝기에 영향을 주지 않는다.
		card.modulate = Color.WHITE
		card.self_modulate = Color.WHITE
		var tower_data := database.get_turret_data(shop_turret_ids[card_index])
		var tower_cost := int(tower_data.get("base_price", 0))
		var affordable := gold >= tower_cost
		var interactable := _is_shop_available() and shop_card_available[card_index] and affordable
		card.set_card_state(shop_card_available[card_index], card_index == selected_shop_card, interactable, affordable)
	if reroll_button != null:
		var reroll_cost := _current_reroll_cost()
		var can_reroll := _is_shop_available() and gold >= reroll_cost
		reroll_button.disabled = not can_reroll
		if can_reroll:
			reroll_button.text = "새로고침\n%d G" % reroll_cost
		elif _is_shop_available():
			reroll_button.text = "골드 부족\n%d G" % reroll_cost
		else:
			reroll_button.text = "새로고침\n%d G" % reroll_cost


# 낮에는 남은 시간만, 밤에는 웨이브만 보이도록 HUD 정보를 현재 상태에 맞춰 갱신한다.
func _update_interface() -> void:
	if wave_label == null:
		return
	var wave_total := current_wave_spawn_entries.size()
	var total_wave_count := database.define_int("totalWaveCount", 1)
	wave_label.text = "%d / %d" % [current_wave_number, total_wave_count]
	gold_label.text = "%d" % gold
	match phase:
		Phase.READY:
			phase_label.text = "%d초" % ceili(preparation_remaining_sec)
			phase_label.visible = true
			wave_title_label.visible = false
			wave_label.visible = false
			action_button.text = "%d번째 밤 시작" % current_wave_number
			if action_button_label != null:
				action_button_label.text = action_button.text
			action_button.disabled = false
			action_button.visible = true
			if action_button_backplate != null:
				action_button_backplate.visible = true
			if action_button_label != null:
				action_button_label.visible = true
		Phase.WAVE:
			phase_label.visible = false
			wave_title_label.visible = true
			wave_label.visible = true
			status_label.text = "밤 방어 중  %d / %d 처치" % [defeated_count, wave_total]
			action_button.visible = false
			if action_button_backplate != null:
				action_button_backplate.visible = false
			if action_button_label != null:
				action_button_label.visible = false
		Phase.VICTORY:
			phase_label.visible = false
			wave_title_label.visible = false
			wave_label.visible = false
			status_label.text = ""
			action_button.visible = false
			if action_button_backplate != null:
				action_button_backplate.visible = false
			if action_button_label != null:
				action_button_label.visible = false
		Phase.DEFEAT:
			phase_label.visible = false
			wave_title_label.visible = false
			wave_label.visible = false
			status_label.text = ""
			action_button.visible = false
			if action_button_backplate != null:
				action_button_backplate.visible = false
			if action_button_label != null:
				action_button_label.visible = false


# 낮·밤 프레임과 아이콘은 씬 노드로 유지해 편집기에서 크기와 기준 위치를 직접 조절한다.
func _update_day_night_hud_nodes() -> void:
	if not is_instance_valid(day_night_hud) or not is_instance_valid(night_frame):
		return
	night_frame.modulate = Color(1.0, 1.0, 1.0, night_visual_amount)

	# 기존 반원 궤도는 유지하되 위치는 DayNightHUD 로컬 좌표로 계산한다.
	var orbit_center := Vector2(250.0, 165.0)
	var orbit_radius := 88.0
	var sun_angle := -PI * 0.5 - night_visual_amount * PI * 0.5
	var moon_angle := -night_visual_amount * PI * 0.5
	_set_hud_orbit_icon(sun_icon, orbit_center + Vector2(cos(sun_angle), sin(sun_angle)) * orbit_radius, night_visual_amount * TAU, 1.0 - night_visual_amount)
	_set_hud_orbit_icon(moon_icon, orbit_center + Vector2(cos(moon_angle), sin(moon_angle)) * orbit_radius, -night_visual_amount * PI * 0.5, night_visual_amount)


func _set_hud_orbit_icon(icon: TextureRect, center_position: Vector2, rotation_radians: float, opacity: float) -> void:
	if not is_instance_valid(icon):
		return
	icon.position = center_position - icon.size * 0.5
	icon.pivot_offset = icon.size * 0.5
	icon.rotation = rotation_radians
	icon.modulate = Color(1.0, 1.0, 1.0, opacity)
