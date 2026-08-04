class_name PrototypeTowerSlot
extends Area2D

# 전투층의 고정 배치 칸 하나를 담당한다.
# 슬롯은 터렛을 직접 생성하지 않고, 클릭 신호와 점유 상태만 관리한다.

# 프로토타입 게임 컨트롤러가 구매한 터렛을 배치할 때 받는 신호다.
signal pressed(slot: PrototypeTowerSlot)

# 데이터상 위치: floor_index는 B1~B3(0~2), slot_index는 층 안의 0~4다.
var floor_index: int = 0
var slot_index: int = 0

# 현재 슬롯에 배치된 터렛과 입력/호버 표시 상태다.
var occupant: PrototypeTower = null
var interaction_enabled: bool = true
var hovered: bool = false

# 터렛 드래그 중 같은 층의 이동·머지 가능 슬롯인지, 현재 드롭 대상으로 선택됐는지 표시한다.
var drag_eligible: bool = false
var drag_targeted: bool = false


# 슬롯 인덱스를 기록하고 마우스 판정용 사각 충돌 영역을 만든다.
func setup(new_floor_index: int, new_slot_index: int) -> void:
	floor_index = new_floor_index
	slot_index = new_slot_index
	input_pickable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(82.0, 52.0)
	collision.shape = shape
	add_child(collision)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


# 터렛 배치가 완료되면 점유자를 연결하고 슬롯 표시를 갱신한다.
func set_occupant(new_occupant: PrototypeTower) -> void:
	occupant = new_occupant
	queue_redraw()


# 터렛 파괴 또는 게임 초기화 시 점유 연결을 해제한다.
func clear_occupant() -> void:
	occupant = null
	queue_redraw()


# 삭제 예약된 터렛도 빈 슬롯으로 처리해 재배치가 막히지 않게 한다.
func is_empty() -> bool:
	return occupant == null or not is_instance_valid(occupant)


# 드래그 가능한 같은 층의 빈 슬롯·머지 슬롯과 현재 커서 아래 드롭 슬롯의 강조 상태를 갱신한다.
func set_drag_state(eligible: bool, targeted: bool) -> void:
	drag_eligible = eligible
	drag_targeted = targeted
	queue_redraw()


# 정비 단계에서 왼쪽 클릭을 받으면 게임 컨트롤러에 슬롯을 전달한다.
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
		get_viewport().set_input_as_handled()


# 호버 진입 시 테두리 강조를 켠다.
func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()


# 호버 종료 시 기본 테두리로 복원한다.
func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()


# 빈 슬롯의 + 기호, 점유 상태, 호버 테두리를 코드 도형으로 그린다.
func _draw() -> void:
	# 점유 슬롯은 터렛 외형만 보이게 완전히 숨긴다. 점유가 해제되면 queue_redraw로 빈 슬롯 표시가 복원된다.
	if not is_empty():
		return
	# 기본 설치 가능 영역은 배경을 덜 가리는 30% 불투명 연두색으로 통일한다.
	var fill := Color(0.48, 0.78, 0.22, 0.30)
	if drag_eligible:
		fill = Color(0.36, 0.82, 0.30, 0.78)
	var border := Color(0.70, 1.00, 0.38, 0.30)
	if drag_targeted:
		border = Color(0.95, 1.00, 0.55, 0.95)
	elif drag_eligible:
		border = Color(0.70, 1.00, 0.42, 0.90)
	elif hovered and interaction_enabled:
		border = Color(0.83, 1.00, 0.55, 0.82)
	# 슬롯도 카드와 같은 둥근 판넬과 아래 그림자를 사용해 설치 UI라는 점을 명확히 한다.
	draw_style_box(_make_slot_style(Color(0.04, 0.10, 0.03, 0.15), Color.TRANSPARENT, 12, 0), Rect2(-43.0, -20.0, 86.0, 50.0))
	draw_style_box(_make_slot_style(fill, Color(0.12, 0.22, 0.08, 0.30), 12, 5), Rect2(-43.0, -27.0, 86.0, 52.0))
	draw_style_box(_make_slot_style(Color.TRANSPARENT, border, 9, 3 if not drag_targeted else 5), Rect2(-37.0, -21.0, 74.0, 40.0))
	if is_empty():
		var plus_color := Color(0.90, 1.00, 0.66, 0.90) if hovered or drag_eligible else Color(0.82, 1.00, 0.56, 0.30)
		draw_line(Vector2(-10.0, -1.0), Vector2(10.0, -1.0), Color(0.10, 0.20, 0.07, 0.30), 7.0)
		draw_line(Vector2(0.0, -11.0), Vector2(0.0, 9.0), Color(0.10, 0.20, 0.07, 0.30), 7.0)
		draw_line(Vector2(-10.0, -2.0), Vector2(10.0, -2.0), plus_color, 4.0)
		draw_line(Vector2(0.0, -12.0), Vector2(0.0, 8.0), plus_color, 4.0)


# 코드 도형 슬롯의 모서리와 외곽선을 일관되게 만드는 작은 스타일 도우미다.
func _make_slot_style(background_color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
