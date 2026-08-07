@tool
class_name PrototypeBattlefieldLayout
extends Node2D

# 전장 제작자가 Godot 에디터에서 직접 옮길 수 있는 게임플레이 기준점을 한곳에서 관리한다.
# Marker2D는 실행 중에는 보이지 않으며, 이 스크립트의 가이드 선도 에디터에서만 그려진다.

const REQUIRED_ROUTE_POINT_COUNT := 9
const REQUIRED_COMBAT_FLOOR_COUNT := 3
const REQUIRED_SLOT_COUNT_PER_FLOOR := 5

@export_category("Editor Guides")
@export var show_route_guide: bool = true:
	set(value):
		show_route_guide = value
		queue_redraw()
@export var show_tower_slot_guide: bool = true:
	set(value):
		show_tower_slot_guide = value
		queue_redraw()

@onready var monster_route: Node2D = $MonsterRoute
@onready var tower_slots_root: Node2D = $TowerSlots


func _ready() -> void:
	# 자식 Marker2D를 에디터에서 드래그할 때 가이드가 즉시 따라오도록 편집 중에만 갱신한다.
	set_process(Engine.is_editor_hint())
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


# MonsterRoute 아래 Marker2D의 장면 순서가 SPAWN부터 DEFEAT까지의 실제 이동 순서다.
func get_monster_path_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for marker in _marker_children(monster_route):
		points.append(to_local(marker.global_position))
	return points


# B1, B2, B3 노드 아래 Marker2D를 층/슬롯 인덱스로 읽는다.
func get_tower_slot_positions() -> Array[PackedVector2Array]:
	var floor_positions: Array[PackedVector2Array] = []
	for floor_node in _node2d_children(tower_slots_root):
		var positions := PackedVector2Array()
		for marker in _marker_children(floor_node):
			positions.append(to_local(marker.global_position))
		floor_positions.append(positions)
	return floor_positions


func get_ground_lane_y() -> float:
	var points := get_monster_path_points()
	return points[0].y if not points.is_empty() else 0.0


# 전투층 접촉선은 각 층의 오른쪽 입구 웨이포인트(인덱스 3, 5, 7)를 기준으로 한다.
func get_combat_lane_y(floor_index: int) -> float:
	var points := get_monster_path_points()
	var path_index := 3 + floor_index * 2
	if path_index < 0 or path_index >= points.size():
		return 0.0
	return points[path_index].y


# 런타임 로직이 기대하는 고정 구조만 검사하고, 제작자가 조정한 실제 좌표값은 제한하지 않는다.
func validate_layout() -> PackedStringArray:
	var errors := PackedStringArray()
	if _marker_children(monster_route).size() != REQUIRED_ROUTE_POINT_COUNT:
		errors.append("MonsterRoute must contain exactly %d Marker2D nodes." % REQUIRED_ROUTE_POINT_COUNT)
	var floor_nodes := _node2d_children(tower_slots_root)
	if floor_nodes.size() != REQUIRED_COMBAT_FLOOR_COUNT:
		errors.append("TowerSlots must contain exactly %d floor nodes." % REQUIRED_COMBAT_FLOOR_COUNT)
	for floor_index in floor_nodes.size():
		var slot_count := _marker_children(floor_nodes[floor_index]).size()
		if slot_count != REQUIRED_SLOT_COUNT_PER_FLOOR:
			errors.append("TowerSlots floor %d must contain exactly %d Marker2D nodes." % [floor_index + 1, REQUIRED_SLOT_COUNT_PER_FLOOR])
	return errors


func _marker_children(parent: Node) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in parent.get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)
	return markers


func _node2d_children(parent: Node) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for child in parent.get_children():
		if child is Node2D and not child is Marker2D:
			nodes.append(child as Node2D)
	return nodes


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var route_points := get_monster_path_points()
	if show_route_guide:
		for point_index in route_points.size() - 1:
			draw_dashed_line(route_points[point_index], route_points[point_index + 1], Color(0.94, 0.36, 0.36, 0.9), 5.0, 18.0)
		for point_index in route_points.size():
			var color := Color(1.0, 0.24, 0.24, 0.95) if point_index == route_points.size() - 1 else Color(1.0, 0.72, 0.22, 0.95)
			draw_circle(route_points[point_index], 14.0, color)
	if show_tower_slot_guide:
		for floor_positions in get_tower_slot_positions():
			for slot_position in floor_positions:
				draw_circle(slot_position, 24.0, Color(0.48, 1.0, 0.42, 0.28))
				draw_arc(slot_position, 24.0, 0.0, TAU, 24, Color(0.48, 1.0, 0.42, 0.9), 3.0)
