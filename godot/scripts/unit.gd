extends Spatial

enum Team { PLAYER, ENEMY }

# --- Identity ---
export var unit_name: String = "Unit"
export var team: int = Team.PLAYER

# --- Base stats ---
export var max_hp: int = 20
export var attack: int = 8
export var defense: int = 4
export var speed: int = 10
export var move_range: int = 3
export var attack_range: int = 1

# --- Runtime state ---
var hp: int
var ct: int = 0
var grid_x: int = 0
var grid_z: int = 0
var has_moved: bool = false
var has_acted: bool = false

signal died(unit)

# --- Sprite sheet constants ---
const _SHEET_PATH = "res://assets/sprites/soldier.png"
const _FRAME_W  = 16   # pixels wide per frame (2 tiles)
const _FRAME_H  = 40   # pixels tall per frame (5 tiles — includes top row the head extends into)
const _FRAME_Y  = 0    # start from top of macro cell
const _PIXEL_SIZE = 0.06
const _ANIM_FPS = 5.0

# SW walk: left foot, feet together, right foot, feet together
const _SW = [32, 56, 80, 56]
# NW walk: right foot, feet together, left foot, feet together
const _NW = [128, 152, 176, 152]

const _CELL_ALLIED = Vector2(0,   0)
const _CELL_ENEMY  = Vector2(344, 0)

# --- Node references ---
var _sprite: Sprite3D
var _hp_bar_fill: MeshInstance
var _name_label: Label  = null
var _camera_ref: Camera = null

var _anim_time: float = 0.0


func _ready() -> void:
	hp = max_hp
	_create_sprite()
	_create_hp_bar()


func _create_sprite() -> void:
	_sprite = Sprite3D.new()
	var img := Image.new()
	img.load(_SHEET_PATH)
	var tex := ImageTexture.new()
	tex.create_from_image(img, 0)  # flags=0: nearest-neighbour, no mipmaps
	_sprite.texture = tex
	_sprite.pixel_size = _PIXEL_SIZE
	_sprite.billboard  = 1  # SpatialMaterial.BILLBOARD_ENABLED
	_sprite.region_enabled = true
	# Lift so base sits at ground level; nudge -X/+Z to correct isometric billboard offset
	_sprite.translation = Vector3(-0.15, _FRAME_H * _PIXEL_SIZE * 0.5, 0.3)
	add_child(_sprite)
	_set_sprite_frame(0, false)


func _set_sprite_frame(frame_idx: int, flip: bool) -> void:
	var cell = _CELL_ALLIED if team == Team.PLAYER else _CELL_ENEMY
	_sprite.flip_h = flip
	_sprite.region_rect = Rect2(
		cell.x + _get_dir_frames()[frame_idx],
		cell.y + _FRAME_Y,
		_FRAME_W, _FRAME_H
	)


func _get_dir_frames() -> Array:
	if not _camera_ref:
		return _SW
	var yaw = fmod(_camera_ref.get_parent().rotation_degrees.y, 360.0)
	if yaw < 0.0:
		yaw += 360.0
	if yaw < 45.0 or yaw >= 315.0:
		return _SW
	elif yaw < 135.0:
		return _NW
	elif yaw < 225.0:
		return _SW
	else:
		return _NW


func _process(delta: float) -> void:
	# Determine camera yaw for direction + flip
	var yaw = 0.0
	if _camera_ref:
		yaw = fmod(_camera_ref.get_parent().rotation_degrees.y, 360.0)
		if yaw < 0.0:
			yaw += 360.0
	var flip = (yaw >= 135.0 and yaw < 315.0)

	# Advance walk animation
	_anim_time += delta
	var frame_idx = int(_anim_time * _ANIM_FPS) % 4
	_set_sprite_frame(frame_idx, flip)

	# Update floating name label
	if _name_label and _camera_ref and is_instance_valid(_camera_ref):
		var world_pos = global_transform.origin + Vector3(0, 2.4, 0)
		var screen_pos = _camera_ref.unproject_position(world_pos)
		_name_label.rect_position = screen_pos - Vector2(_name_label.rect_min_size.x * 0.5, 0)


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


func _create_hp_bar() -> void:
	var root := Spatial.new()
	root.translation = Vector3(0, 2.1, 0)
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
	_hp_bar_fill.translation.x = -0.4 * (1.0 - ratio)


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> void:
	hp = int(max(0, hp - amount))
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
