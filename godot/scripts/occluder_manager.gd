extends Node

# Fades GridMap tiles that visually block a unit from the current camera angle.
# Uses a checkerboard discard shader (GLES2-safe — no alpha blending).
#
# For each unit, the three grid neighbours in the camera's direction are checked.
# If a neighbour's tile height exceeds the unit's tile height it is "faded":
#   - GridMap cell(s) are removed and replaced with dithered MeshInstances.
# Cells are restored as soon as they are no longer occluding anything.

onready var _grid_map: GridMap = get_node("../GridMap")
onready var _map_data          = get_node("../MapData")
onready var _camera: Camera    = get_node("../CameraRig/Camera")
onready var _units: Spatial    = get_node("../Units")

# Vector2(cx, cz) -> { "tile_ids": {y: int}, "meshes": [MeshInstance] }
var _faded := {}
var _mat_dither: ShaderMaterial


func _ready() -> void:
	var sh_dither = Shader.new()
	sh_dither.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	ivec2 px = ivec2(FRAGCOORD.xy);
	if ((px.x + px.y) % 4 == 0) discard;
	ALBEDO = vec3(0.38, 0.46, 0.36);
}
"""
	_mat_dither = ShaderMaterial.new()
	_mat_dither.shader = sh_dither



func _process(_delta: float) -> void:
	var wanted := {}
	var cam_pos = _camera.global_transform.origin

	for unit in _units.get_children():
		if not "grid_x" in unit:
			continue
		if not unit.alive:
			continue

		var ux: int = unit.grid_x
		var uz: int = unit.grid_z
		var unit_height: int = _map_data.get_height(ux, uz)
		var unit_world: Vector3 = unit.global_transform.origin

		var dx: int = int(sign(cam_pos.x - unit_world.x))
		var dz: int = int(sign(cam_pos.z - unit_world.z))

		# Up to 3 neighbours in the direction of the camera
		var candidates := []
		if dx != 0:
			candidates.append(Vector2(ux + dx, uz))
		if dz != 0:
			candidates.append(Vector2(ux, uz + dz))
		if dx != 0 and dz != 0:
			candidates.append(Vector2(ux + dx, uz + dz))

		for cell in candidates:
			var cx := int(cell.x)
			var cz := int(cell.y)
			if not _map_data.is_in_bounds(cx, cz):
				continue
			if _map_data.get_height(cx, cz) > unit_height:
				wanted[cell] = true

	# Fade newly occluding cells
	for cell in wanted:
		if not _faded.has(cell):
			_fade_cell(int(cell.x), int(cell.y))

	# Restore cells that are no longer blocking anything
	for cell in _faded.keys():
		if not wanted.has(cell):
			_restore_cell(int(cell.x), int(cell.y))


func _fade_cell(cx: int, cz: int) -> void:
	var key := Vector2(cx, cz)
	var height: int = _map_data.get_height(cx, cz)
	var top_y := height - 1
	var tile_ids := {}
	var meshes := []

	# Only fade the top tile — lower tiles stay solid so the column looks intact
	var tid: int = _grid_map.get_cell_item(cx, top_y, cz)
	if tid != GridMap.INVALID_CELL_ITEM:
		tile_ids[top_y] = tid
		_grid_map.set_cell_item(cx, top_y, cz, GridMap.INVALID_CELL_ITEM)

		var pos := _grid_map.map_to_world(cx, top_y, cz)
		var mesh = _grid_map.mesh_library.get_item_mesh(tid)

		var mi := MeshInstance.new()
		mi.mesh = mesh
		mi.material_override = _mat_dither
		get_parent().add_child(mi)
		mi.global_transform.origin = pos
		meshes.append(mi)



	_faded[key] = {"tile_ids": tile_ids, "meshes": meshes}



func _restore_cell(cx: int, cz: int) -> void:
	var key := Vector2(cx, cz)
	if not _faded.has(key):
		return
	var data = _faded[key]

	for y in data.tile_ids:
		_grid_map.set_cell_item(cx, y, cz, data.tile_ids[y])

	for mi in data.meshes:
		mi.queue_free()

	_faded.erase(key)
