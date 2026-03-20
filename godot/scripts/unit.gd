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

# --- Direction ---
const DIR_S = 0  # south  (+Z)
const DIR_W = 1  # west   (-X)
const DIR_N = 2  # north  (-Z)
const DIR_E = 3  # east   (+X)

# --- Runtime state ---
var hp: int
var ct: int = 0
var grid_x: int = 0
var grid_z: int = 0
var facing: int = DIR_S
var has_moved: bool = false
var has_acted: bool = false
var alive: bool = true

# --- Sprite sheet constants ---
const _SHEET_PATH = "res://assets/sprites/soldier.png"
const _FRAME_W    = 16
const _FRAME_H    = 40
const _FRAME_Y    = 0
const _PIXEL_SIZE = 0.06
const _ANIM_FPS   = 5.0

# SW walk: left foot, feet together, right foot, feet together
const _SW = [32, 56, 80, 56]
# NW walk: right foot, feet together, left foot, feet together
const _NW = [128, 152, 176, 152]

const _CELL_ALLIED = Vector2(0,   0)
const _CELL_ENEMY  = Vector2(344, 0)

# --- Node references ---
var _sprite: Sprite3D
var _hp_bar_root: Spatial
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
	tex.create_from_image(img, 0)  # nearest-neighbour, no mipmaps
	_sprite.texture        = tex
	_sprite.pixel_size     = _PIXEL_SIZE
	_sprite.billboard = 1  # BILLBOARD_ENABLED: fully faces camera, sprite looks correct
	_sprite.alpha_cut = 1  # ALPHA_CUT_DISCARD: pixel art transparency via discard, GLES2-safe
	_sprite.region_enabled = true
	_sprite.translation.y  = _FRAME_H * _PIXEL_SIZE * 0.35
	add_child(_sprite)
	_update_sprite()


# [cam_index][facing] → effective screen direction
# effective: 0=NW, 1=SE, 2=NE, 3=SW
# Camera positions: cam 0=SE(yaw≈45°), 1=NE(135°), 2=NW(225°), 3=SW(315°)
# Derived from orthographic projection of each world cardinal onto screen axes.
const _SPRITE_LOOKUP = [
	[3, 0, 2, 1],  # cam SE: S→SW, W→NW, N→NE, E→SE
	[0, 2, 1, 3],  # cam NE: S→NW, W→NE, N→SE, E→SW
	[2, 1, 3, 0],  # cam NW: S→NE, W→SE, N→SW, E→NW
	[1, 3, 0, 2],  # cam SW: S→SE, W→SW, N→NW, E→NE
]

func _get_sprite_params() -> Array:
	var cam_yaw := 0.0
	if _camera_ref:
		cam_yaw = fmod(_camera_ref.get_parent().rotation_degrees.y, 360.0)
		if cam_yaw < 0.0:
			cam_yaw += 360.0
	var cam_index := int(cam_yaw / 90.0) % 4
	match _SPRITE_LOOKUP[cam_index][facing]:
		0: return [_NW, false]  # NW on screen
		1: return [_SW, true]   # SE on screen
		2: return [_NW, true]   # NE on screen
		_: return [_SW, false]  # SW on screen


func _update_sprite() -> void:
	if not _sprite:
		return
	var params  = _get_sprite_params()
	var offsets = params[0]
	var flip    = params[1]
	var frame   = int(_anim_time * _ANIM_FPS) % 4
	var cell    = _CELL_ALLIED if team == Team.PLAYER else _CELL_ENEMY
	_sprite.flip_h      = flip
	_sprite.region_rect = Rect2(cell.x + offsets[frame], cell.y + _FRAME_Y, _FRAME_W, _FRAME_H)


func _process(delta: float) -> void:
	_anim_time += delta
	_update_sprite()

	# HP bar billboard — match camera orientation each frame (yaw + elevation, no roll)
	if _hp_bar_root and _camera_ref and is_instance_valid(_camera_ref):
		var cam_yaw = _camera_ref.get_parent().rotation_degrees.y
		_hp_bar_root.rotation_degrees = Vector3(-35.264, cam_yaw, 0.0)

	# Name label
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
	root.translation = Vector3(0, 2.0, 0)
	_hp_bar_root = root
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
	return hp > 0 and alive


func take_damage(amount: int) -> void:
	hp = int(max(0, hp - amount))
	_update_hp_bar()


func set_alive(val: bool) -> void:
	alive = val
	visible = val
	if _name_label and is_instance_valid(_name_label):
		_name_label.visible = val


func get_snapshot() -> Dictionary:
	return {
		"node":      self,
		"grid_x":    grid_x,
		"grid_z":    grid_z,
		"hp":        hp,
		"ct":        ct,
		"facing":    facing,
		"has_moved": has_moved,
		"has_acted": has_acted,
		"alive":     alive,
	}


func restore_from_snapshot(entry: Dictionary, map_data) -> void:
	hp        = entry.hp
	ct        = entry.ct
	facing    = entry.get("facing", DIR_S)
	has_moved = entry.has_moved
	has_acted = entry.has_acted
	set_alive(entry.alive)
	if entry.alive:
		place_on_grid(entry.grid_x, entry.grid_z, map_data)
	_update_hp_bar()


func place_on_grid(x: int, z: int, map_data) -> void:
	grid_x = x
	grid_z = z
	global_transform.origin = map_data.cell_to_world(x, z)


func start_turn() -> void:
	has_moved = false
	has_acted = false
	ct = 0
