extends Node2D

# 프로토타입 전체 장면의 게임 루프와 UI를 조정하는 최상위 컨트롤러다.
# 개별 터렛/몬스터의 전투는 각 오브젝트 스크립트에 맡기고 여기서는 생성·경제·승패만 관리한다.

# 동적으로 생성하는 오브젝트, 데이터 로더, 한글 UI 폰트를 미리 로드한다.
const MonsterScript := preload("res://scripts/monster.gd")
const TowerScript := preload("res://scripts/tower.gd")
const TowerSlotScript := preload("res://scripts/tower_slot.gd")
const ShopCardScript := preload("res://scripts/shop_card.gd")
const DatabaseScript := preload("res://scripts/prototype_database.gd")
const RewardCoinPopupScript := preload("res://scripts/reward_coin_popup.gd")
const BattlefieldWorldScript := preload("res://scripts/battlefield_world.gd")
const TestBalancePanelScript := preload("res://scripts/test_balance_panel.gd")
# 둥근 획의 Jua를 공통 UI 글꼴로 사용해 캐주얼 RPG의 굵고 친근한 인상을 만든다.
const GAME_FONT := preload("res://assets/fonts/Jua-Regular.ttf")
# Jua에 없는 ▶ 기호는 기존 로컬 Noto Sans KR로 렌더링해 Web에서도 대체문자 없이 표시한다.
const SYMBOL_FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const DAY_NIGHT_HUD_DAY_FRAME := preload("res://assets/ui/day_night_hud_day_frame_v2.png")
const DAY_NIGHT_HUD_NIGHT_FRAME := preload("res://assets/ui/day_night_hud_night_frame_v2.png")
const DAY_NIGHT_SUN_ICON := preload("res://assets/ui/day_night_sun_icon_v1.png")
const DAY_NIGHT_MOON_ICON := preload("res://assets/ui/day_night_moon_icon_v1.png")

# 레퍼런스 UI에서 추출한 공통 팔레트다. 기능별 강조색만 바꾸고 짙은 외곽선은 공유한다.
const UI_INK := Color("171827")
const UI_PANEL := Color("39354d")
const UI_PANEL_LIGHT := Color("514a68")
const UI_CREAM := Color("fff0c5")
const UI_GOLD := Color("f6c653")
const UI_TEAL := Color("2ba89b")
const UI_RED := Color("d94b55")

# 모든 전투 좌표와 UI 배치는 16:9 Full HD 논리 해상도를 기준으로 작성한다.
# Web 창의 가로세로 비율이 달라져도 이 영역 전체가 보이도록 Godot 스트레치가 먼저 배율을 정한다.
const REFERENCE_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)

# 생성 배경의 자연스러운 발판 높이에 이동 경로와 슬롯 중심을 맞춰 한곳에서 관리한다.
const PATH_LEFT_X := 140.0
const PATH_RIGHT_X := 1770.0
# 지상 구간은 시각적 지형 굴곡과 무관하게 같은 Y축을 유지하는 수평 직선으로 이동한다.
const GROUND_MID_X := 1050.0
const GROUND_EXIT_X := 450.0
# 경로 Y는 몬스터 중심이 아니라 도형의 바닥이 닿는 배경 발판 접촉선이다.
const GROUND_LANE_Y := 1360.0
# 세로형 v6 배경에서 몬스터의 바닥이 각 발판 두께의 중앙선에 닿도록 맞춘 B1~B3 이동 높이다.
const COMBAT_LANE_Y := [1857.0, 2382.0, 2907.0]
const TOWER_SLOT_Y := [1757.0, 2282.0, 2807.0]
# 터렛·몬스터 같은 전투 오브젝트만 상점 위에서 자르고, 배경은 별도 층에서 화면 전체에 표시한다.
const BATTLEFIELD_ENTITY_VIEW_HEIGHT := 770.0
# 각 2층 전투 뷰의 아래쪽 플랫폼과 상점 사이에 약 70px 이상의 안전 여백을 확보한다.
const BATTLEFIELD_CAMERA_Y := [-650.0, -1185.0, -1685.0, -2210.0]
const BATTLEFIELD_CAMERA_TRANSITION_SEC := 0.26
# 오른쪽에서 등장하는 몬스터가 진입할 여백 40%를 비우고, 왼쪽 60%에만 슬롯을 둔다.
const TOWER_DEPLOYMENT_RATIO := 0.60
const TOWER_DEPLOYMENT_RIGHT_X := PATH_LEFT_X + (PATH_RIGHT_X - PATH_LEFT_X) * TOWER_DEPLOYMENT_RATIO
# 인접 슬롯은 데이터의 사거리 1칸 환산값과 같은 180px 간격을 사용한다.
const TOWER_SLOT_GAP_PX := 180.0
const TOWER_SLOT_X := [300.0, 480.0, 660.0, 840.0, 1020.0]
# 상점 하단 절반은 낮에 설치 터렛을 판매하는 드롭 영역으로 사용한다.
const SHOP_AREA_BOTTOM_Y := 1080.0
const SELL_ZONE_TOP_Y := 925.0
const SELL_ZONE_RECT := Rect2(24.0, SELL_ZONE_TOP_Y, 1872.0, SHOP_AREA_BOTTOM_Y - SELL_ZONE_TOP_Y)
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

# 지상 숲→광산 입구는 수평 직선이며, 이후 B1~B3는 오른쪽→왼쪽으로 이어지는 고정 웨이포인트다.
# 인덱스 2/4/6의 출구에서 다음 지하층의 오른쪽 입구로 하강한다.
var movement_path := PackedVector2Array([
	Vector2(PATH_RIGHT_X + 10.0, GROUND_LANE_Y),
	Vector2(GROUND_MID_X, GROUND_LANE_Y),
	Vector2(GROUND_EXIT_X, GROUND_LANE_Y),
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
		queue_redraw()
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
var automated_test_sell: bool = false
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
var options_overlay: Control
var options_menu_open: bool = false
var options_test_mode_button: Button
var test_mode_badge: Label
var test_balance_panel: PrototypeTestBalancePanel
var sell_zone_overlay: TextureRect
var sell_zone_label: Label

# CanvasLayer는 Node2D 변환을 상속하지 않으므로 별도로 보관해 전장과 같은 중앙 오프셋을 적용한다.
var interface_canvas: CanvasLayer

# 설치된 터렛의 현재 슬롯을 인스턴스 ID로 찾고 드래그 시작·대상 상태를 추적한다.
var tower_slot_by_instance_id: Dictionary = {}
var dragged_tower: PrototypeTower = null
var dragged_origin_slot: PrototypeTowerSlot = null
var dragged_target_slot: PrototypeTowerSlot = null
var drag_pointer_offset := Vector2.ZERO
var drag_sell_active: bool = false

# 상점 카드 드래그 중 구매 예정 카드, 포인터를 따라가는 더미 터렛, 드롭 대상 슬롯을 추적한다.
var dragged_shop_card_index: int = -1
var shop_drag_preview: PrototypeTower = null
var shop_drag_target_slot: PrototypeTowerSlot = null


# 명령줄 테스트 플래그를 해석하고, 데이터→UI→슬롯→첫 정비 단계 순서로 초기화한다.
func _ready() -> void:
	# ESC 옵션 창이 SceneTree를 일시 정지해도 이 컨트롤러는 입력을 받아 다시 닫을 수 있어야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var user_args := OS.get_cmdline_user_args()
	automated_test_mode = "--auto-test-victory" in user_args or "--auto-test-defeat" in user_args or "--auto-test-economy" in user_args or "--auto-test-drag" in user_args or "--auto-test-shop-drag" in user_args or "--auto-test-shop-merge" in user_args or "--auto-test-wave-shop" in user_args or "--auto-test-melee-attack" in user_args or "--auto-test-attack-styles" in user_args or "--auto-test-wave-features" in user_args or "--auto-test-merge" in user_args or "--auto-test-sell" in user_args or "--auto-test-camera-navigation" in user_args or "--auto-test-test-environment" in user_args
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
	automated_test_sell = "--auto-test-sell" in user_args
	automated_test_camera_navigation = "--auto-test-camera-navigation" in user_args
	automated_test_test_environment = "--auto-test-test-environment" in user_args
	tower_visual_test_type = _requested_tower_visual_test_type(user_args)
	test_mode = "--test-mode" in user_args or automated_test_test_environment or _web_query_requests_test_mode() or not tower_visual_test_type.is_empty()
	database = DatabaseScript.new() as PrototypeDatabase
	if database == null or not database.load_all():
		push_error("Prototype database could not be loaded.")
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
	if options_menu_open:
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
	# ESC는 상점 사용 가능 여부와 관계없이 옵션 창을 열고 닫는다.
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if not automated_test_mode:
			_toggle_options_menu()
		get_viewport().set_input_as_handled()
		return
	# 드래그 중이 아닐 때 휠과 위·아래 방향키로 인접한 두 층 화면 사이를 이동한다.
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
			_update_shop_card_drag(_viewport_to_battlefield(event.position))
			get_viewport().set_input_as_handled()
		elif dragged_tower != null:
			_update_tower_drag(_viewport_to_battlefield(event.position))
			get_viewport().set_input_as_handled()


# 마우스 휠과 위·아래 방향키를 동일한 카메라 단계 변경으로 변환한다.
func _handle_battlefield_navigation_input(event: InputEvent) -> bool:
	if options_menu_open or dragged_tower != null or dragged_shop_card_index >= 0:
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
	# 상점 카드로 머지할 때도 기존 터렛 투자금과 새 카드 실구매가를 모두 상위 Tier에 승계한다.
	var merged_investment := target.invested_gold + tower_cost
	# 생성 실패 시 기존 점유자를 복원할 수 있도록 새 터렛 생성이 성공하기 전에는 기존 배열을 지우지 않는다.
	target_slot.clear_occupant()
	var upgraded_tower := _spawn_tower_in_slot(target_slot, upgraded_turret_id, merged_investment)
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


# 드래그를 시작하면서 상점 선택을 해제하고 같은 층의 이동·머지 가능 슬롯을 표시한다.
func _begin_tower_drag(tower: PrototypeTower, origin: PrototypeTowerSlot, local_pointer: Vector2) -> void:
	dragged_tower = tower
	dragged_origin_slot = origin
	drag_pointer_offset = tower.position - local_pointer
	drag_sell_active = false
	selected_shop_card = -1
	tower.z_index = 20
	tower.modulate = Color(1.0, 1.0, 1.0, 0.78)
	status_label.text = "빈 슬롯으로 이동·머지하거나 상점 하단에 놓아 판매하세요"
	_set_sell_zone_feedback(false, tower)
	_update_drag_slot_states(null)
	_update_shop_cards()


# 드래그 중 터렛을 포인터에 따라 이동시키고 가장 가까운 유효 슬롯을 드롭 대상으로 표시한다.
func _update_tower_drag(local_pointer: Vector2) -> void:
	if dragged_tower == null or not is_instance_valid(dragged_tower):
		_cancel_tower_drag()
		return
	dragged_tower.position = local_pointer + drag_pointer_offset
	# 터렛 중심이 상점 하단 절반에 들어오면 슬롯 이동보다 판매 판정을 우선한다.
	drag_sell_active = _is_in_sell_zone(dragged_tower.position)
	if drag_sell_active:
		dragged_target_slot = null
		_update_drag_slot_states(null, false)
		_set_sell_zone_feedback(true, dragged_tower)
		return
	_set_sell_zone_feedback(false, dragged_tower)
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


# 상점 하단 판매 영역이면 판매하고, 아니면 같은 층 머지·이동을 시도한 뒤 잘못된 위치에서는 복귀시킨다.
func _finish_tower_drag() -> void:
	if dragged_tower == null or not is_instance_valid(dragged_tower):
		_cancel_tower_drag()
		return
	if drag_sell_active:
		var refund := _sell_tower(dragged_tower)
		if refund >= 0:
			status_label.text = "터렛 판매  +%d G" % refund
			_clear_tower_drag_visuals()
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
	var merged_investment := source.invested_gold + target.invested_gold
	origin.clear_occupant()
	target_slot.clear_occupant()
	tower_slot_by_instance_id.erase(source.get_instance_id())
	tower_slot_by_instance_id.erase(target.get_instance_id())
	towers.erase(source)
	towers.erase(target)
	source.queue_free()
	target.queue_free()
	var upgraded_tower := _spawn_tower_in_slot(target_slot, upgraded_turret_id, merged_investment)
	if upgraded_tower == null:
		push_error("Could not create merged turret: %s" % upgraded_turret_id)
		return false
	upgraded_tower.play_upgrade_effect()
	return true


# 낮에 설치 터렛을 제거하고 누적 실구매가에 데이터 확장 환급률을 곱한 정수 골드를 지급한다.
func _sell_tower(tower: PrototypeTower) -> int:
	if phase != Phase.READY or tower == null or not is_instance_valid(tower):
		return -1
	var origin := tower_slot_by_instance_id.get(tower.get_instance_id()) as PrototypeTowerSlot
	if origin == null:
		return -1
	var refund := _tower_sale_price(tower)
	origin.clear_occupant()
	tower_slot_by_instance_id.erase(tower.get_instance_id())
	towers.erase(tower)
	gold += refund
	tower.queue_free()
	_update_interface()
	_update_shop_cards()
	return refund


# 판매 환급률은 아직 원본 테이블에 없으므로 prototype_define 확장값을 읽고 소수점 이하는 버린다.
func _tower_sale_price(tower: PrototypeTower) -> int:
	if tower == null or not is_instance_valid(tower):
		return 0
	var refund_rate := database.extension_float("sellRefundRate", 0.5)
	return floori(float(tower.invested_gold) * refund_rate)


# 설치 터렛은 낮에만 판매할 수 있으며 상점 UI의 정확한 하단 절반을 판정 영역으로 사용한다.
func _is_in_sell_zone(local_position: Vector2) -> bool:
	if phase != Phase.READY or not is_instance_valid(battlefield_world):
		return false
	# 전장 좌표를 고정 UI 기준 좌표로 되돌려 카메라 위치와 관계없이 같은 판매 영역을 사용한다.
	var viewport_position := battlefield_world.to_global(local_position)
	var reference_position := viewport_position - position
	return SELL_ZONE_RECT.has_point(reference_position)


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
	_set_sell_zone_feedback(false, dragged_tower)
	dragged_tower = null
	dragged_origin_slot = null
	dragged_target_slot = null
	drag_pointer_offset = Vector2.ZERO
	drag_sell_active = false


# 드래그 중 같은 층의 빈 슬롯과 머지 가능한 동일 터렛 슬롯을 구분해 강조한다.
func _update_drag_slot_states(target: PrototypeTowerSlot, show_eligible: bool = true) -> void:
	for slot in tower_slots:
		var eligible := false
		if show_eligible and dragged_tower != null and slot.floor_index == dragged_tower.floor_index and slot != dragged_origin_slot:
			eligible = slot.is_empty() or _can_merge_towers(dragged_tower, slot.occupant as PrototypeTower)
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
	battlefield_clip.add_child(battlefield_world)

	_set_battlefield_view_index(0, true)


# 0=하늘+지상, 1=지상+B1, 2=B1+B2, 3=B2+B3으로 제한하고 확대·축소 없이 Y 위치만 보간한다.
func _set_battlefield_view_index(requested_index: int, instant: bool = false) -> void:
	if not is_instance_valid(battlefield_world) or not is_instance_valid(battlefield_background):
		return
	battlefield_view_index = clampi(requested_index, 0, BATTLEFIELD_CAMERA_Y.size() - 1)
	var target_y := float(BATTLEFIELD_CAMERA_Y[battlefield_view_index])
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


# 상단 정보, 하단 상점, 웨이브/리롤 버튼을 CanvasLayer에 생성한다.
func _build_interface() -> void:
	interface_canvas = CanvasLayer.new()
	add_child(interface_canvas)

	# 중앙 원형 배지는 낮에는 남은 시간, 밤에는 웨이브 정보 중 하나만 표시한다.
	phase_label = _make_label(interface_canvas, Vector2(105.0, 132.0), Vector2(130.0, 52.0), 26)
	phase_label.text = ""
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", UI_CREAM)

	# 두 줄을 한 Label에 넣지 않고 제목과 숫자를 분리해 각각의 실제 글자 높이를 원 중심에 맞춘다.
	wave_title_label = _make_label(interface_canvas, Vector2(105.0, 126.0), Vector2(130.0, 30.0), 21)
	wave_title_label.text = "WAVE"
	wave_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_label = _make_label(interface_canvas, Vector2(105.0, 153.0), Vector2(130.0, 40.0), 25)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 보유 골드는 획득 애니메이션 유무와 관계없이 금색 캡슐 정중앙을 유지한다.
	gold_label = _make_label(interface_canvas, Vector2(50.0, 814.0), Vector2(200.0, 58.0), 27)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", UI_GOLD)
	# +n G는 판넬에 종속된 줄이 아니라 보유 골드와 같은 수평 중심에서 위로 떠오르는 독립 피드백이다.
	gold_gain_label = _make_label(interface_canvas, Vector2(50.0, 800.0), Vector2(200.0, 34.0), 21)
	gold_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_gain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_gain_label.add_theme_color_override("font_color", Color("fff2a6"))
	gold_gain_label.visible = false
	gold_gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 구매·판매 로직의 짧은 메시지 저장소는 유지하지만 승인된 화면에서는 알림 영역을 노출하지 않는다.
	status_label = _make_label(interface_canvas, Vector2.ZERO, Vector2.ZERO, 1)
	status_label.visible = false
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	action_button = Button.new()
	action_button.position = Vector2(1450.0, 38.0)
	action_button.size = Vector2(330.0, 60.0)
	action_button.text = "1 웨이브 시작"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_font_override("font", GAME_FONT)
	action_button.add_theme_font_size_override("font_size", 26)
	action_button.add_theme_stylebox_override("normal", _make_button_style(UI_GOLD, Color("fff1a8")))
	action_button.add_theme_stylebox_override("hover", _make_button_style(Color("ffda6f"), Color("fff7ca")))
	action_button.add_theme_stylebox_override("pressed", _make_button_style(Color("d79b2d"), Color("ffe283"), 2))
	action_button.add_theme_stylebox_override("disabled", _make_button_style(Color("504b5c"), Color("716b80")))
	_configure_button_text(action_button, Color("34283a"), Color("34283a"), Color("827b8b"))
	action_button.pressed.connect(_on_action_button_pressed)
	interface_canvas.add_child(action_button)
	_create_speed_controls(interface_canvas)

	# 테스트 환경임을 일반 플레이와 명확히 구분하는 작은 고정 배지를 상단에 표시한다.
	test_mode_badge = _make_label(interface_canvas, Vector2(1260.0, 38.0), Vector2(160.0, 60.0), 27)
	test_mode_badge.text = "TEST"
	test_mode_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_mode_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	test_mode_badge.add_theme_color_override("font_color", Color.WHITE)
	test_mode_badge.add_theme_stylebox_override("normal", _make_panel_style(UI_RED, UI_INK, 18, 5, true))
	test_mode_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	reroll_button = Button.new()
	reroll_button.position = Vector2(50.0, 884.0)
	reroll_button.size = Vector2(200.0, 64.0)
	reroll_button.text = "새로고침  %d G" % _current_reroll_cost()
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.add_theme_font_override("font", GAME_FONT)
	reroll_button.add_theme_font_size_override("font_size", 24)
	# 리롤 가능 여부가 색만 보아도 구분되도록 활성/호버/비활성 스타일을 명시한다.
	reroll_button.add_theme_stylebox_override("normal", _make_button_style(UI_TEAL, Color("8be3d8")))
	reroll_button.add_theme_stylebox_override("hover", _make_button_style(Color("42c4b4"), Color("c4fff5")))
	reroll_button.add_theme_stylebox_override("pressed", _make_button_style(Color("20867e"), Color("79d9cc"), 2))
	reroll_button.add_theme_stylebox_override("disabled", _make_button_style(Color("454354"), Color("6f6a7c")))
	_configure_button_text(reroll_button, Color.WHITE, Color.WHITE, Color("9994a7"))
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	interface_canvas.add_child(reroll_button)
	_create_shop_cards(interface_canvas)
	_create_sell_zone_feedback(interface_canvas)
	_create_options_menu(interface_canvas)
	_create_test_balance_panel(interface_canvas)


# 테스트 모드에서만 보이는 우측 빠른 옵션 패널과 별도 테이블 편집 창을 연결한다.
func _create_test_balance_panel(parent: Node) -> void:
	test_balance_panel = TestBalancePanelScript.new() as PrototypeTestBalancePanel
	parent.add_child(test_balance_panel)
	test_balance_panel.setup(database, GAME_FONT)
	test_balance_panel.grant_gold_requested.connect(_on_test_grant_gold_requested)
	test_balance_panel.start_wave_requested.connect(_on_test_start_wave_requested)
	test_balance_panel.runtime_data_changed.connect(_on_test_runtime_data_changed)
	_update_test_mode_ui()


# 판매 드래그 중에만 상점 하단 절반을 붉은 그라데이션으로 덮고 예상 환급액을 중앙에 표시한다.
func _create_sell_zone_feedback(parent: Node) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.78, 0.04, 0.08, 0.08),
		Color(0.78, 0.02, 0.04, 0.82),
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.5, 0.0)
	gradient_texture.fill_to = Vector2(0.5, 1.0)

	sell_zone_overlay = TextureRect.new()
	sell_zone_overlay.position = SELL_ZONE_RECT.position
	sell_zone_overlay.size = SELL_ZONE_RECT.size
	sell_zone_overlay.texture = gradient_texture
	sell_zone_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sell_zone_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	sell_zone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_zone_overlay.z_index = 50
	sell_zone_overlay.visible = false
	parent.add_child(sell_zone_overlay)

	sell_zone_label = _make_label(parent, Vector2(700.0, 968.0), Vector2(520.0, 66.0), 36)
	sell_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_zone_label.add_theme_color_override("font_color", Color("fff2f2"))
	sell_zone_label.add_theme_color_override("font_shadow_color", Color(0.22, 0.0, 0.02, 0.9))
	sell_zone_label.add_theme_constant_override("shadow_offset_x", 3)
	sell_zone_label.add_theme_constant_override("shadow_offset_y", 3)
	sell_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sell_zone_label.z_index = 51
	sell_zone_label.visible = false


# 드래그 위치가 판매 영역에 들어오거나 나갈 때 오버레이와 안내 문구를 함께 전환한다.
func _set_sell_zone_feedback(active: bool, tower: PrototypeTower) -> void:
	if sell_zone_overlay == null or sell_zone_label == null:
		return
	sell_zone_overlay.visible = active
	sell_zone_label.visible = active
	if active:
		var refund := _tower_sale_price(tower)
		sell_zone_label.text = "판매  %d G" % refund
		status_label.text = "놓으면 판매  +%d G" % refund


# ESC 옵션 창을 전체 화면 어둡게 처리한 중앙 모달로 만들고 네 가지 명령을 묶는다.
func _create_options_menu(parent: Node) -> void:
	options_overlay = Control.new()
	options_overlay.position = Vector2.ZERO
	options_overlay.size = REFERENCE_VIEWPORT_SIZE
	options_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	options_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	options_overlay.z_index = 100
	options_overlay.visible = false
	parent.add_child(options_overlay)

	var dimmer := ColorRect.new()
	dimmer.position = Vector2.ZERO
	dimmer.size = REFERENCE_VIEWPORT_SIZE
	dimmer.color = Color(0.035, 0.03, 0.07, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	options_overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(700.0, 140.0)
	panel.size = Vector2(520.0, 800.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(UI_PANEL, UI_INK, 24, 8, true))
	options_overlay.add_child(panel)

	var title := _make_label(options_overlay, Vector2(760.0, 185.0), Vector2(400.0, 72.0), 46)
	title.text = "옵션"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UI_CREAM)

	var continue_button := _make_options_button(options_overlay, Vector2(790.0, 300.0), "계속하기", UI_TEAL, Color("8be3d8"))
	continue_button.pressed.connect(_on_options_continue_pressed)
	options_test_mode_button = _make_options_button(options_overlay, Vector2(790.0, 410.0), "테스트 환경 시작", Color("8d5ac7"), Color("d3a8ff"))
	options_test_mode_button.pressed.connect(_on_options_test_mode_pressed)
	var reset_button := _make_options_button(options_overlay, Vector2(790.0, 520.0), "프로토타입 초기화", UI_GOLD, Color("fff1a8"))
	reset_button.pressed.connect(_on_options_reset_pressed)
	var quit_button := _make_options_button(options_overlay, Vector2(790.0, 630.0), "게임 종료", UI_RED, Color("ff9ca4"))
	quit_button.pressed.connect(_on_options_quit_pressed)
	_update_test_mode_ui()


# 옵션 창 버튼은 같은 크기와 글자 스타일을 공유하고 기능색만 달리한다.
func _make_options_button(parent: Node, button_position: Vector2, button_text: String, background_color: Color, border_color: Color) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = Vector2(340.0, 78.0)
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_override("font", GAME_FONT)
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_stylebox_override("normal", _make_button_style(background_color, border_color))
	button.add_theme_stylebox_override("hover", _make_button_style(background_color.lightened(0.12), border_color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _make_button_style(background_color.darkened(0.16), border_color, 2))
	_configure_button_text(button, Color.WHITE, Color.WHITE, Color("9994a7"))
	parent.add_child(button)
	return button


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


# 우측 상단에 밤 전용 배속 캡슐과 항상 표시되는 원형 일시정지 버튼을 만든다.
func _create_speed_controls(parent: Node) -> void:
	speed_button = Button.new()
	speed_button.position = Vector2(1600.0, 38.0)
	speed_button.size = Vector2(180.0, 60.0)
	speed_button.text = "▶"
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.add_theme_font_override("font", SYMBOL_FONT)
	speed_button.add_theme_font_size_override("font_size", 26)
	speed_button.pressed.connect(_on_speed_button_pressed)
	parent.add_child(speed_button)

	pause_button = Button.new()
	pause_button.position = Vector2(1810.0, 34.0)
	pause_button.size = Vector2(68.0, 68.0)
	pause_button.text = "II"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.add_theme_font_override("font", GAME_FONT)
	pause_button.add_theme_font_size_override("font_size", 27)
	pause_button.pressed.connect(_on_pause_button_pressed)
	parent.add_child(pause_button)
	_update_speed_controls()


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
	speed_button.disabled = phase != Phase.WAVE or automated_test_mode
	speed_button.add_theme_stylebox_override("normal", _make_capsule_button_style(UI_GOLD, Color("fff0a8")))
	speed_button.add_theme_stylebox_override("hover", _make_capsule_button_style(Color("ffda6f"), Color("fff7ca")))
	speed_button.add_theme_stylebox_override("pressed", _make_capsule_button_style(Color("d79b2d"), Color("ffe283"), 2))
	_configure_button_text(speed_button, Color("34283a"), Color("34283a"), Color("9994a7"))
	if pause_button != null:
		pause_button.visible = true
		pause_button.disabled = automated_test_mode
		pause_button.add_theme_stylebox_override("normal", _make_circle_button_style(UI_PANEL, Color("aaa0c7")))
		pause_button.add_theme_stylebox_override("hover", _make_circle_button_style(Color("554d70"), Color("d9cff4")))
		pause_button.add_theme_stylebox_override("pressed", _make_circle_button_style(Color("312b45"), Color("aaa0c7"), 2))
		_configure_button_text(pause_button, UI_CREAM, Color.WHITE, Color("9994a7"))


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


# 모든 HUD Label에 동일한 한글 폰트와 기본 색상을 적용하는 생성 도우미다.
func _make_label(parent: Node, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", GAME_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5f7ff"))
	label.add_theme_color_override("font_outline_color", Color(0.07, 0.06, 0.11, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label


# 모든 버튼에 같은 굵은 외곽선, 둥근 모서리와 아래쪽 그림자를 적용한다.
func _make_button_style(background_color: Color, border_color: Color, pressed_offset: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(5)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0.04, 0.035, 0.07, 0.8)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 5.0 - pressed_offset)
	style.content_margin_top = 4.0 + pressed_offset
	return style


# 배속 표식을 넓은 알약 형태 안에 담아 일반 직사각형 버튼과 구분한다.
func _make_capsule_button_style(background_color: Color, border_color: Color, pressed_offset: int = 0) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, pressed_offset)
	style.set_corner_radius_all(30)
	return style


# ESC와 같은 기능의 버튼은 정사각형 크기 절반을 모서리 반경으로 사용해 원형으로 만든다.
func _make_circle_button_style(background_color: Color, border_color: Color, pressed_offset: int = 0) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, pressed_offset)
	style.set_corner_radius_all(34)
	return style


# 글자가 밝은 배경에서도 또렷하도록 버튼 전용 외곽선과 상태별 색을 묶어 적용한다.
func _configure_button_text(button: Button, normal_color: Color, hover_color: Color, disabled_color: Color) -> void:
	button.add_theme_color_override("font_color", normal_color)
	button.add_theme_color_override("font_hover_color", hover_color)
	button.add_theme_color_override("font_pressed_color", hover_color)
	button.add_theme_color_override("font_disabled_color", disabled_color)
	button.add_theme_color_override("font_outline_color", UI_INK)
	button.add_theme_constant_override("outline_size", 4)


# B1~B3 각 5개, 총 15개의 고정 터렛 슬롯을 만든다.
func _create_tower_slots() -> void:
	for floor_index in 3:
		for slot_index in 5:
			var slot := TowerSlotScript.new() as PrototypeTowerSlot
			slot.position = Vector2(TOWER_SLOT_X[slot_index], TOWER_SLOT_Y[floor_index])
			slot.setup(floor_index, slot_index)
			slot.pressed.connect(_on_tower_slot_pressed)
			battlefield_world.add_child(slot)
			tower_slots.append(slot)


# PDF/AGENTS에 확정된 5칸 TFT형 상점 카드 버튼을 만든다.
# 카드의 실제 내용은 매 정비 단계마다 _refresh_shop_cards에서 채운다.
func _create_shop_cards(canvas: CanvasLayer) -> void:
	var card_count := database.extension_int("shopCardCount", 5)
	for card_index in card_count:
		var card := ShopCardScript.new() as PrototypeShopCard
		card.position = Vector2(280.0 + card_index * 322.0, 790.0)
		card.size = Vector2(306.0, 270.0)
		card.setup(GAME_FONT)
		canvas.add_child(card)
		shop_cards.append(card)
		shop_card_available.append(true)
		shop_turret_ids.append("")


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
	# 자동 테스트의 무상 배치는 투자금 0, 실제 상점 구매는 카드의 실구매가를 기록한다.
	var invested_gold := tower_cost if use_shop_card else 0
	var tower := _spawn_tower_in_slot(slot, turret_id, invested_gold)
	if tower == null:
		return null
	_update_interface()
	_update_shop_cards()
	return tower


# 구매·자동 테스트·머지가 공유하도록 한 ID의 터렛을 지정 슬롯에 생성하는 순수 배치 도우미다.
func _spawn_tower_in_slot(slot: PrototypeTowerSlot, turret_id: String, invested_gold: int = 0) -> PrototypeTower:
	if slot == null or not slot.is_empty():
		return null
	var tower_data := database.get_turret_data(turret_id)
	if tower_data.is_empty():
		return null
	var tower := TowerScript.new() as PrototypeTower
	tower.position = slot.position
	tower.setup(tower_data, slot.floor_index, invested_gold)
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
	if automated_test_sell:
		_run_sell_automated_test()
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
	database.reset_balance_table("Turret")
	_on_test_runtime_data_changed("Turret")
	var source_reset_ok := is_equal_approx(float(database.get_turret_data("turretMelee1").get("damage", 0.0)), original_damage)
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
	var stun_hover_height_ok := is_equal_approx(float(TowerScript.STUN_HOVER_HEIGHT), 96.0)
	var test_button_ok := options_test_mode_button != null and options_test_mode_button.text == "일반 모드로 돌아가기"
	var passed := test_mode \
		and normal_start_gold_ok \
		and full_shop_ok \
		and reroll_full_shop_ok \
		and manual_ready_ok \
		and panel_visible_ok \
		and manual_gold_ok \
		and runtime_edit_ok \
		and source_reset_ok \
		and wave_jump_ok \
		and manual_next_wave_ok \
		and test_mode_badge != null \
		and test_mode_badge.visible \
		and speed_values_ok \
		and stun_hover_height_ok \
		and test_button_ok
	if passed:
		print("Automated test environment passed: MANUAL_WAVES_FULL_SHOP_RUNTIME_TABLE_SPEED_10X")
	else:
		push_error("Automated test environment failed: normal=%s full_shop=%s reroll_shop=%s manual_ready=%s panel=%s gold=%s edit=%s reset=%s wave=%s manual_next=%s speed=%s button=%s" % [normal_start_gold_ok, full_shop_ok, reroll_full_shop_ok, manual_ready_ok, panel_visible_ok, manual_gold_ok, runtime_edit_ok, source_reset_ok, wave_jump_ok, manual_next_wave_ok, speed_values_ok, test_button_ok])
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 경로와 수직으로 떨어진 근접 포탑이 같은 층·수평 사거리 안의 적을 찾아 실제 피해를 주는지 검증한다.
func _run_melee_attack_automated_test() -> void:
	_place_tower(tower_slots[0], false, "turretMelee1")
	var melee_tower := towers[0]
	var monster_data := database.get_monster_data("normal1")
	var target_monster := MonsterScript.new() as PrototypeMonster
	target_monster.setup(monster_data, movement_path)
	battlefield_world.add_child(target_monster)
	# 포탑과 X좌표는 같고 Y좌표는 실제 전투 경로에 두어 수평 거리 판정을 직접 검증한다.
	target_monster.position = target_monster.center_position_for_floor_contact(Vector2(melee_tower.position.x, COMBAT_LANE_Y[0]))
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
	var test_origin := Vector2(500.0, COMBAT_LANE_Y[0] - 100.0)

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
	var monster := MonsterScript.new() as PrototypeMonster
	monster.setup(database.get_monster_data("boss1"), movement_path)
	monster.position = monster.center_position_for_floor_contact(Vector2(spawn_x, COMBAT_LANE_Y[0]))
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
	var passing_monster := MonsterScript.new() as PrototypeMonster
	passing_monster.setup(monster_data, movement_path)
	battlefield_world.add_child(passing_monster)
	passing_monster.position = passing_monster.center_position_for_floor_contact(Vector2(test_tower.position.x, COMBAT_LANE_Y[0]))
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
	var reward_monster := MonsterScript.new() as PrototypeMonster
	reward_monster.setup(monster_data, movement_path)
	reward_monster.position = reward_monster.center_position_for_floor_contact(Vector2(820.0, COMBAT_LANE_Y[0]))
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
	var carryover_monster := MonsterScript.new() as PrototypeMonster
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
	var first_boss := MonsterScript.new() as PrototypeMonster
	var second_boss := MonsterScript.new() as PrototypeMonster
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


# 같은 층 이동 성공과 다른 층 이동 거부를 헤드리스 환경에서 함께 검증한다.
func _run_drag_automated_test() -> void:
	var origin := tower_slots[0]
	var same_floor_target := tower_slots[1]
	var other_floor_target := tower_slots[5]
	# 평상시 0%, 조작 중 30%, 조작 종료 후 0%로 복원되는 슬롯 표시 규칙을 직접 확인한다.
	var slot_hidden_at_idle := is_zero_approx(same_floor_target.self_modulate.a)
	same_floor_target.set_drag_state(true, false)
	var slot_visible_during_drag := is_equal_approx(same_floor_target.self_modulate.a, PrototypeTowerSlot.ACTIVE_SLOT_OPACITY)
	same_floor_target.set_drag_state(false, false)
	var slot_hidden_after_drag := is_zero_approx(same_floor_target.self_modulate.a)
	_place_tower(origin, false, "turretMelee1")
	var tower := towers[0]
	var cross_floor_rejected := not _relocate_tower(tower, other_floor_target)
	var same_floor_moved := _relocate_tower(tower, same_floor_target)
	var passed := slot_hidden_at_idle and slot_visible_during_drag and slot_hidden_after_drag \
		and _tower_slot_layout_is_valid() and cross_floor_rejected and same_floor_moved \
		and origin.is_empty() and same_floor_target.occupant == tower and tower.position == same_floor_target.position
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


# 실제 구매 두 번의 투자금이 머지 터렛에 누적되고 낮 판매만 절반 환급되는지 검증한다.
func _run_sell_automated_test() -> void:
	var target_slot := tower_slots[0]
	var card_index := 0
	var turret_id := "turretMelee1"
	var tower_cost := int(database.get_turret_data(turret_id).get("base_price", -1))
	var starting_gold := gold
	shop_turret_ids[card_index] = turret_id
	shop_card_available[card_index] = true
	var first_purchase := _purchase_shop_card_to_slot(card_index, target_slot)
	shop_turret_ids[card_index] = turret_id
	shop_card_available[card_index] = true
	var second_purchase_merged := _purchase_shop_card_to_slot(card_index, target_slot)
	var merged_tower := target_slot.occupant as PrototypeTower
	var expected_investment := tower_cost * 2
	var expected_refund := floori(float(expected_investment) * database.extension_float("sellRefundRate", 0.5))
	var investment_preserved := merged_tower != null and merged_tower.turret_id == "turretMelee2" and merged_tower.invested_gold == expected_investment
	var threshold_detected := _is_in_sell_zone(Vector2(960.0, SELL_ZONE_TOP_Y + 1.0)) and not _is_in_sell_zone(Vector2(960.0, SELL_ZONE_TOP_Y - 1.0))
	var actual_refund := _sell_tower(merged_tower)
	var day_sale_ok := actual_refund == expected_refund and target_slot.is_empty() and gold == starting_gold - expected_investment + expected_refund

	# 밤에는 같은 API를 호출해도 터렛과 골드가 그대로 남아야 한다.
	var night_tower := _spawn_tower_in_slot(target_slot, turret_id, tower_cost)
	var gold_before_night_attempt := gold
	_set_phase(Phase.WAVE)
	var night_sale_rejected := _sell_tower(night_tower) == -1 and target_slot.occupant == night_tower and gold == gold_before_night_attempt
	var passed := first_purchase and second_purchase_merged and investment_preserved and threshold_detected and day_sale_ok and night_sale_rejected
	if passed:
		print("Automated sell test passed: DAY_LOWER_SHOP_HALF_CUMULATIVE_REFUND")
	else:
		push_error("Automated sell test failed.")
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


# 네 카메라 정지점과 경계 제한, 오브젝트 무축소 조건을 헤드리스 환경에서 검증한다.
func _run_camera_navigation_automated_test() -> void:
	_set_battlefield_view_index(1, true)
	var middle_view_valid := battlefield_view_index == 1 \
		and is_equal_approx(battlefield_world.position.y, float(BATTLEFIELD_CAMERA_Y[1])) \
		and is_equal_approx(battlefield_background.position.y, float(BATTLEFIELD_CAMERA_Y[1]))
	_set_battlefield_view_index(99, true)
	var bottom_index := BATTLEFIELD_CAMERA_Y.size() - 1
	var bottom_clamped := battlefield_view_index == bottom_index \
		and is_equal_approx(battlefield_world.position.y, float(BATTLEFIELD_CAMERA_Y[bottom_index])) \
		and is_equal_approx(battlefield_background.position.y, float(BATTLEFIELD_CAMERA_Y[bottom_index]))
	_set_battlefield_view_index(-99, true)
	var top_clamped := battlefield_view_index == 0 \
		and is_equal_approx(battlefield_world.position.y, float(BATTLEFIELD_CAMERA_Y[0])) \
		and is_equal_approx(battlefield_background.position.y, float(BATTLEFIELD_CAMERA_Y[0]))
	# 카메라 기능은 월드의 위치만 바꾸며 적·터렛을 작게 만드는 scale 변경을 사용하지 않는다.
	var object_scale_preserved := battlefield_world.scale == Vector2.ONE and battlefield_background.scale == Vector2.ONE
	var reference_frame_clipped := battlefield_background_clip.clip_contents and battlefield_background_clip.size == REFERENCE_VIEWPORT_SIZE
	# 각 2층 전투 화면의 아래쪽 접촉선이 상점 카드 위로 충분한 안전 여백을 가져야 한다.
	var shop_clearance_valid := true
	for view_index in range(1, BATTLEFIELD_CAMERA_Y.size()):
		var lower_floor_index := view_index - 1
		var lower_contact_screen_y: float = float(COMBAT_LANE_Y[lower_floor_index]) + float(BATTLEFIELD_CAMERA_Y[view_index])
		shop_clearance_valid = shop_clearance_valid and lower_contact_screen_y <= BATTLEFIELD_ENTITY_VIEW_HEIGHT - 70.0
	# 지상 등장 애니메이션 중간에도 스케일된 몸체의 발끝은 경로 접촉선에 고정돼야 한다.
	var spawn_test_monster := MonsterScript.new() as PrototypeMonster
	spawn_test_monster.setup(database.get_monster_data("normal1"), movement_path)
	battlefield_world.add_child(spawn_test_monster)
	spawn_test_monster._process(0.12)
	var scaled_spawn_bottom := spawn_test_monster.position.y + spawn_test_monster.body_bottom_offset_y * spawn_test_monster.scale.y
	var grounded_spawn_valid := is_equal_approx(scaled_spawn_bottom, GROUND_LANE_Y)
	spawn_test_monster.free()
	var passed := middle_view_valid and bottom_clamped and top_clamped and object_scale_preserved and reference_frame_clipped and shop_clearance_valid and grounded_spawn_valid
	if passed:
		print("Automated camera navigation test passed: FOUR_STOPS_NO_ZOOM")
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
	var monster := MonsterScript.new() as PrototypeMonster
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
	gold_gain_label.position = Vector2(50.0, 800.0)
	gold_gain_label.modulate = Color.WHITE
	gold_gain_label.visible = true
	gold_gain_tween = create_tween()
	gold_gain_tween.set_ignore_time_scale(true)
	gold_gain_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gold_gain_tween.tween_property(gold_gain_label, "position:y", 764.0, 0.68)
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
			reroll_button.text = "새로고침  %d G" % reroll_cost
		elif _is_shop_available():
			reroll_button.text = "골드 부족 · %d G" % reroll_cost
		else:
			reroll_button.text = "새로고침  %d G" % reroll_cost


# 낮에는 남은 시간만, 밤에는 웨이브만 보이도록 HUD 정보를 현재 상태에 맞춰 갱신한다.
func _update_interface() -> void:
	if wave_label == null:
		return
	var wave_total := current_wave_spawn_entries.size()
	var total_wave_count := database.define_int("totalWaveCount", 1)
	wave_label.text = "%d / %d" % [current_wave_number, total_wave_count]
	gold_label.text = "GOLD  %d" % gold
	match phase:
		Phase.READY:
			phase_label.text = "%d초" % ceili(preparation_remaining_sec)
			phase_label.visible = true
			wave_title_label.visible = false
			wave_label.visible = false
			action_button.text = "%d번째 밤 시작" % current_wave_number
			action_button.disabled = false
			action_button.visible = true
		Phase.WAVE:
			phase_label.visible = false
			wave_title_label.visible = true
			wave_label.visible = true
			status_label.text = "밤 방어 중  %d / %d 처치" % [defeated_count, wave_total]
			action_button.visible = false
		Phase.VICTORY:
			phase_label.visible = false
			wave_title_label.visible = false
			wave_label.visible = false
			status_label.text = "방어 성공"
			action_button.visible = false
		Phase.DEFEAT:
			phase_label.visible = false
			wave_title_label.visible = true
			wave_label.visible = true
			status_label.text = "최심부 침입 · 패배"
			action_button.visible = false


# 고정 HUD와 상점 제어 장식만 그리고, 화면 전체 배경은 독립된 수직 카메라 노드에 맡긴다.
func _draw() -> void:
	# 전체 폭 상단 판넬 대신 낮/밤과 웨이브만 담는 독립형 반원 HUD를 표시한다.
	_draw_day_night_hud()

	# 전체 폭 상점 판넬은 제거하고 골드·리롤 제어부만 독립 판넬로 유지한다.
	draw_style_box(_make_panel_style(Color("4a435f"), Color("81799a"), 15, 4), Rect2(38.0, 790.0, 224.0, 270.0))
	# 골드 표시는 상점의 재화라는 관계가 보이도록 금색 캡슐 안에 묶는다.
	draw_style_box(_make_panel_style(Color("5b4935"), Color("e8bd58"), 12, 3), Rect2(48.0, 814.0, 204.0, 58.0))


# 생성한 낮·밤 HUD 프레임을 교차시키고 해·달을 반원 내부 궤도에서 회전시킨다.
func _draw_day_night_hud() -> void:
	var frame_rect := Rect2(-80.0, -5.0, 500.0, 250.0)
	draw_texture_rect(DAY_NIGHT_HUD_DAY_FRAME, frame_rect, false)
	if night_visual_amount > 0.001:
		draw_texture_rect(DAY_NIGHT_HUD_NIGHT_FRAME, frame_rect, false, Color(1.0, 1.0, 1.0, night_visual_amount))

	# 아이콘 반지름을 프레임 안쪽으로 제한하고, 서로 반대 방향에서 꼭대기로 교대시킨다.
	var orbit_center := Vector2(170.0, 160.0)
	var orbit_radius := 88.0
	var sun_angle := -PI * 0.5 - night_visual_amount * PI * 0.5
	var moon_angle := -night_visual_amount * PI * 0.5
	var sun_position := orbit_center + Vector2(cos(sun_angle), sin(sun_angle)) * orbit_radius
	var moon_position := orbit_center + Vector2(cos(moon_angle), sin(moon_angle)) * orbit_radius
	_draw_orbiting_hud_icon(DAY_NIGHT_SUN_ICON, sun_position, 58.0, night_visual_amount * TAU, 1.0 - night_visual_amount)
	_draw_orbiting_hud_icon(DAY_NIGHT_MOON_ICON, moon_position, 58.0, -night_visual_amount * PI * 0.5, night_visual_amount)


# 생성 아이콘은 중심 기준으로 회전해도 58px 안전 영역 밖으로 나가지 않게 그린다.
func _draw_orbiting_hud_icon(texture: Texture2D, icon_position: Vector2, icon_size: float, rotation_radians: float, opacity: float) -> void:
	if opacity <= 0.001:
		return
	draw_set_transform(icon_position, rotation_radians, Vector2.ONE)
	draw_texture_rect(texture, Rect2(Vector2(-icon_size * 0.5, -icon_size * 0.5), Vector2(icon_size, icon_size)), false, Color(1.0, 1.0, 1.0, opacity))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Node2D 그리기에서도 재사용할 수 있는 둥근 판넬 스타일을 만든다.
func _make_panel_style(background_color: Color, border_color: Color, radius: int, border_width: int, with_shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	if with_shadow:
		style.shadow_color = Color(0.03, 0.025, 0.06, 0.82)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0.0, 7.0)
	return style
