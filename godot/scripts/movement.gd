extends Node

# Cardinal neighbours only (no diagonals)
const DIRS = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

# Maximum height difference a unit can step up or down in one move
const MAX_STEP = 1

onready var map_data = get_node("../MapData")
onready var grid_map: GridMap = get_node("../GridMap")

var _highlight_meshes := []  # Array of MeshInstance nodes currently in the scene


# Returns an Array of Vector2(x, z) the unit can reach.
# Cost to enter a cell = 1, plus 1 extra for each elevation step up.
func get_reachable_cells(unit) -> Array:
	var start = Vector2(unit.grid_x, unit.grid_z)
	var move_points = unit.move_range

	# BFS with remaining-move-points tracking
	# queue entries: [Vector2 pos, int remaining]
	var queue = [[start, move_points]]
	var visited = {start: move_points}  # pos -> best remaining MP

	while not queue.empty():
		var entry = queue.pop_front()
		var pos: Vector2 = entry[0]
		var mp: int = entry[1]

		for dir in DIRS:
			var nb = pos + dir
			var nx = int(nb.x)
			var nz = int(nb.y)

			if not map_data.is_in_bounds(nx, nz):
				continue

			var from_height = map_data.get_height(int(pos.x), int(pos.y))
			var to_height   = map_data.get_height(nx, nz)
			var step = to_height - from_height

			# Cannot climb more than MAX_STEP, can drop any amount
			if step > MAX_STEP:
				continue
			if not map_data.is_walkable(nx, nz) and map_data.get_unit_at(nx, nz) != unit:
				continue

			var cost = 1 + max(0, step)
			var remaining = mp - cost
			if remaining < 0:
				continue

			if not visited.has(nb) or visited[nb] < remaining:
				visited[nb] = remaining
				queue.append([nb, remaining])

	# Remove the starting cell — unit is already there
	visited.erase(start)
	return visited.keys()


# Returns an Array of Vector2(x, z) within attack range of the unit,
# occupied by a unit on the opposing team.
func get_attack_targets(unit) -> Array:
	var targets = []
	var origin = Vector2(unit.grid_x, unit.grid_z)
	for z in map_data.MAP_DEPTH:
		for x in map_data.MAP_WIDTH:
			var dist = abs(x - unit.grid_x) + abs(z - unit.grid_z)
			if dist < 1 or dist > unit.attack_range:
				continue
			var target = map_data.get_unit_at(x, z)
			if target and target.team != unit.team:
				targets.append(Vector2(x, z))
	return targets


# Find shortest path from unit's position to (to_x, to_z) using A*.
# Returns Array of Vector2 steps (not including start).
func find_path(unit, to_x: int, to_z: int) -> Array:
	var start = Vector2(unit.grid_x, unit.grid_z)
	var goal  = Vector2(to_x, to_z)

	var open = [start]
	var came_from = {}
	var g = {start: 0}

	while not open.empty():
		# Find lowest f = g + heuristic
		var current = open[0]
		for p in open:
			if _f(p, goal, g) < _f(current, goal, g):
				current = p

		if current == goal:
			return _reconstruct(came_from, current)

		open.erase(current)
		for dir in DIRS:
			var nb = current + dir
			var nx = int(nb.x)
			var nz = int(nb.y)
			if not map_data.is_in_bounds(nx, nz):
				continue
			var step = map_data.get_height(nx, nz) - map_data.get_height(int(current.x), int(current.y))
			if step > MAX_STEP:
				continue
			if not map_data.is_walkable(nx, nz) and nb != goal:
				continue
			var new_g = g[current] + 1 + max(0, step)
			if not g.has(nb) or new_g < g[nb]:
				g[nb] = new_g
				came_from[nb] = current
				if not open.has(nb):
					open.append(nb)

	return []  # no path found


func _f(pos: Vector2, goal: Vector2, g: Dictionary) -> float:
	var h = abs(pos.x - goal.x) + abs(pos.y - goal.y)
	return g.get(pos, INF) + h


func _reconstruct(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	path.pop_front()  # remove start
	return path


# --- Highlight helpers ---

func show_move_highlights(cells: Array) -> void:
	clear_highlights()
	for cell in cells:
		_add_highlight(cell, Color(0.2, 0.6, 1.0))


func show_attack_highlights(cells: Array) -> void:
	clear_highlights()
	for cell in cells:
		_add_highlight(cell, Color(1.0, 0.25, 0.25))


func clear_highlights() -> void:
	for mi in _highlight_meshes:
		if is_instance_valid(mi):
			mi.queue_free()
	_highlight_meshes.clear()


func _add_highlight(cell: Vector2, color: Color) -> void:
	var x = int(cell.x)
	var z = int(cell.y)
	var world_pos = map_data.cell_to_world(x, z)

	var mi := MeshInstance.new()
	var plane := PlaneMesh.new()
	var cs := grid_map.cell_size
	plane.size = Vector2(cs.x * 0.9, cs.z * 0.9)
	mi.mesh = plane

	var mat := SpatialMaterial.new()
	mat.albedo_color = color
	mat.flags_unshaded = true
	mi.material_override = mat

	# Add to the scene first so global_transform is valid, then position it
	get_parent().add_child(mi)
	mi.global_transform.origin = world_pos + Vector3(0, 0.05, 0)
	_highlight_meshes.append(mi)
