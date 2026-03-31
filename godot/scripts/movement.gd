extends Node

# Cardinal neighbours only (no diagonals)
const DIRS = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

# Fallback climb limit used only if a unit somehow lacks a jump stat
const MAX_STEP = 1

onready var map_data = get_node("../MapData")
onready var grid_map: GridMap = get_node("../GridMap")

var _highlight_meshes := []  # Array of {mi: MeshInstance, mat: ShaderMaterial, color: Color}
var _debug_meshes     := []  # same structure, shown independently of gameplay highlights
var _pulse_time: float = 0.0
var _outline_shader: Shader


func _ready() -> void:
	_outline_shader = Shader.new()
	_outline_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 fill_color : hint_color = vec4(1.0);
uniform vec4 border_color : hint_color = vec4(1.0);
uniform float border_width : hint_range(0.01, 0.49) = 0.07;

void fragment() {
	float bw = border_width;
	bool is_border = UV.x <= bw || UV.x >= 1.0 - bw || UV.y <= bw || UV.y >= 1.0 - bw;
	ALBEDO = is_border ? border_color.rgb : fill_color.rgb;
}
"""


func _process(delta: float) -> void:
	if _highlight_meshes.empty() and _debug_meshes.empty():
		return
	_pulse_time += delta
	var t = (sin(_pulse_time * 2.0) + 1.0) * 0.5  # oscillates 0 → 1
	for entry in _highlight_meshes + _debug_meshes:
		if is_instance_valid(entry.mi):
			var c: Color = entry.color
			entry.mat.set_shader_param("border_color", c.linear_interpolate(c.lightened(0.5), t))


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

			if not unit.flying and step > unit.jump:
				continue
			if not map_data.is_walkable(nx, nz) and map_data.get_unit_at(nx, nz) != unit:
				continue

			var cost: int = 1
			if not unit.flying:
				cost += int(max(0, step))
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
			if not unit.flying and step > unit.jump:
				continue
			if not map_data.is_walkable(nx, nz) and nb != goal:
				continue
			var step_cost: int = 0 if unit.flying else int(max(0, step))
			var new_g = g[current] + 1 + step_cost
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


func show_item_highlights(cells: Array) -> void:
	clear_highlights()
	for cell in cells:
		_add_highlight(cell, Color(0.25, 0.9, 0.35))


func clear_highlights() -> void:
	for entry in _highlight_meshes:
		if is_instance_valid(entry.mi):
			entry.mi.queue_free()
	_highlight_meshes.clear()
	_pulse_time = 0.0



func toggle_debug_grid(on: bool) -> void:
	if on:
		var purple := Color(0.55, 0.1, 0.85)
		for z in map_data.MAP_DEPTH:
			for x in map_data.MAP_WIDTH:
				_add_highlight_to(Vector2(x, z), purple, _debug_meshes, 0.03)
	else:
		for entry in _debug_meshes:
			if is_instance_valid(entry.mi):
				entry.mi.queue_free()
		_debug_meshes.clear()


func _add_highlight(cell: Vector2, color: Color) -> void:
	_add_highlight_to(cell, color, _highlight_meshes, 0.05)


func _add_highlight_to(cell: Vector2, color: Color, target: Array, y_offset: float) -> void:
	var x = int(cell.x)
	var z = int(cell.y)
	var world_pos = map_data.cell_to_world(x, z)

	var mi := MeshInstance.new()
	var plane := PlaneMesh.new()
	var cs := grid_map.cell_size
	plane.size = Vector2(cs.x * 0.9, cs.z * 0.9)
	mi.mesh = plane

	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_param("fill_color", color)
	mat.set_shader_param("border_color", color)
	mi.material_override = mat

	get_parent().add_child(mi)
	mi.global_transform.origin = world_pos + Vector3(0, y_offset, 0)
	target.append({mi = mi, mat = mat, color = color})
