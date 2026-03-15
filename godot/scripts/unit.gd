extends Spatial

enum Team { PLAYER, ENEMY }

# --- Identity ---
export var unit_name: String = "Unit"
export var team: int = Team.PLAYER

# --- Base stats ---
export var max_hp: int = 20
export var attack: int = 8
export var defense: int = 4
export var speed: int = 10       # CT gained per tick
export var move_range: int = 3   # max cells moveable per turn
export var attack_range: int = 1 # max cell distance for a basic attack

# --- Runtime state ---
var hp: int
var ct: int = 0        # charge time (0-99 at start, resets to 0 after acting)
var grid_x: int = 0
var grid_z: int = 0
var has_moved: bool = false
var has_acted: bool = false

signal died(unit)

var _hp_bar_fill: MeshInstance
var _name_label: Label = null
var _camera_ref: Camera = null


func setup_label(camera: Camera, ui_node: Node) -> void:
	_camera_ref = camera
	_name_label = Label.new()
	_name_label.text = unit_name
	_name_label.rect_min_size = Vector2(80, 20)
	_name_label.align = Label.ALIGN_CENTER
	var color = Color(0.55, 0.75, 1.0) if team == Team.PLAYER else Color(1.0, 0.55, 0.55)
	_name_label.add_color_override("font_color", color)
	ui_node.add_child(_name_label)


func cleanup_label() -> void:
	if is_instance_valid(_name_label):
		_name_label.queue_free()
	_name_label = null


func _process(_delta: float) -> void:
	if _name_label and _camera_ref and is_instance_valid(_camera_ref):
		var world_pos = global_transform.origin + Vector3(0, 2.0, 0)
		var screen_pos = _camera_ref.unproject_position(world_pos)
		_name_label.rect_position = screen_pos - Vector2(_name_label.rect_min_size.x * 0.5, 0)


func _ready() -> void:
	hp = max_hp
	_apply_team_color()
	_create_hp_bar()


func _apply_team_color() -> void:
	var mat := SpatialMaterial.new()
	mat.albedo_color = Color(0.2, 0.4, 1.0) if team == Team.PLAYER else Color(0.9, 0.2, 0.2)
	$Mesh.set_surface_material(0, mat)


func _create_hp_bar() -> void:
	var root := Spatial.new()
	root.translation = Vector3(0, 1.6, 0)
	root.rotation_degrees.x = -36
	add_child(root)

	var bg := MeshInstance.new()
	var bg_mesh := CubeMesh.new()
	bg_mesh.size = Vector3(0.8, 0.1, 0.02)
	bg.mesh = bg_mesh
	var bg_mat := SpatialMaterial.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15)
	bg_mat.flags_unshaded = true
	bg.material_override = bg_mat
	root.add_child(bg)

	_hp_bar_fill = MeshInstance.new()
	var fill_mesh := CubeMesh.new()
	fill_mesh.size = Vector3(0.8, 0.1, 0.02)
	_hp_bar_fill.mesh = fill_mesh
	var fill_mat := SpatialMaterial.new()
	fill_mat.albedo_color = Color(0.1, 0.85, 0.15)
	fill_mat.flags_unshaded = true
	_hp_bar_fill.material_override = fill_mat
	_hp_bar_fill.translation.z = 0.015
	root.add_child(_hp_bar_fill)


func _update_hp_bar() -> void:
	if not _hp_bar_fill:
		return
	var ratio := float(hp) / float(max_hp)
	_hp_bar_fill.scale.x = max(0.01, ratio)
	# Shift left so the bar drains from the right
	_hp_bar_fill.translation.x = -0.4 * (1.0 - ratio)


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	_update_hp_bar()
	if hp == 0:
		emit_signal("died", self)


func place_on_grid(x: int, z: int, map_data) -> void:
	grid_x = x
	grid_z = z
	global_transform.origin = map_data.cell_to_world(x, z)


func start_turn() -> void:
	has_moved = false
	has_acted = false
	ct = 0
