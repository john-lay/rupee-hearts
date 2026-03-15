extends Node

# MAP_LAYOUT[z][x] = height (number of stacked tiles)
# 0 = impassable, 1 = ground floor, 2 = elevated platform
const MAP_LAYOUT = [
	[1, 1, 1, 1, 1, 1],  # z=0
	[1, 1, 1, 1, 1, 1],  # z=1  (enemies start at x=1 and x=4)
	[1, 1, 2, 1, 1, 1],  # z=2  (elevated at x=2)
	[1, 1, 2, 1, 1, 1],  # z=3  (elevated at x=2)
	[1, 1, 1, 1, 1, 1],  # z=4  (players start at x=1 and x=4)
	[1, 1, 1, 1, 1, 1],  # z=5
]

const MAP_WIDTH = 6
const MAP_DEPTH = 6

onready var _grid_map: GridMap = get_node("../GridMap")

# _occupancy[z][x] -> Unit node or null
var _occupancy := []


func _ready() -> void:
	_init_occupancy()
	_populate_grid_map()


func _init_occupancy() -> void:
	for z in MAP_DEPTH:
		var row = []
		for x in MAP_WIDTH:
			row.append(null)
		_occupancy.append(row)


func _populate_grid_map() -> void:
	_grid_map.clear()
	for z in MAP_DEPTH:
		for x in MAP_WIDTH:
			var height = MAP_LAYOUT[z][x]
			for y in height:
				_grid_map.set_cell_item(x, y, z, 0)


# --- Queries ---

func is_in_bounds(x: int, z: int) -> bool:
	return x >= 0 and x < MAP_WIDTH and z >= 0 and z < MAP_DEPTH


func get_height(x: int, z: int) -> int:
	if not is_in_bounds(x, z):
		return 0
	return MAP_LAYOUT[z][x]


func is_walkable(x: int, z: int) -> bool:
	if not is_in_bounds(x, z):
		return false
	return MAP_LAYOUT[z][x] > 0 and _occupancy[z][x] == null


func get_unit_at(x: int, z: int):
	if not is_in_bounds(x, z):
		return null
	return _occupancy[z][x]


func set_unit_at(x: int, z: int, unit) -> void:
	if is_in_bounds(x, z):
		_occupancy[z][x] = unit


func clear_unit_at(x: int, z: int) -> void:
	if is_in_bounds(x, z):
		_occupancy[z][x] = null


# World position of the top-center of the tile at grid cell (x, z).
# This is where a unit standing on that cell should be positioned.
func cell_to_world(x: int, z: int) -> Vector3:
	var top_y = get_height(x, z) - 1
	var cell_center = _grid_map.map_to_world(x, top_y, z)
	return cell_center + Vector3(0, _grid_map.cell_size.y * 0.5, 0)
