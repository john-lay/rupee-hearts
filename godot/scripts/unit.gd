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
export var jump: int = 3        # max climbable height difference per step
export var flying: bool = false # ignores climb cap and height movement cost; counts as 1 tile higher for combat
export var accuracy: int = 55   # base hit chance %
export var evasion: int = 0     # subtracts from attacker's accuracy

# --- Temporary modifiers (set by buffs/debuffs) ---
var accuracy_mod: int = 0
var evasion_mod: int = 0

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

# --- Walk animation ---
signal move_finished

const WALK_SPEED = 3.0  # tiles per second

var _is_walking:      bool    = false
var _walk_path:       Array   = []
var _walk_from_cell:  Vector2 = Vector2()
var _walk_from:       Vector3 = Vector3()
var _walk_to:         Vector3 = Vector3()
var _walk_t:          float   = 0.0
var _map_data                 = null  # cached from place_on_grid

# --- Sprite sheet ---
export var sprite_sheet:  String = "res://assets/sprites/soldier.png"
export var simple_sheet:  bool   = false   # true = new 1024×1024 simple format

# --- Legacy sheet constants (soldier.png) ---
const _FRAME_W    = 16
const _FRAME_H    = 40
const _FRAME_Y    = 0
const _PIXEL_SIZE = 0.06
const _ANIM_FPS   = 5.0

# SW walk: left foot, feet together, right foot, feet together
const _SW = [32, 56, 80, 56]
# NW walk: right foot, feet together, left foot, feet together
const _NW = [128, 152, 176, 152]

# Raise Hands (item use) — single frame, y=52, h=32
const _SW_RAISE_HANDS_X = 8
const _NW_RAISE_HANDS_X = 104
const _RAISE_HANDS_Y    = 52
const _RAISE_HANDS_H    = 32

const _CELL_ALLIED = Vector2(0,   0)
const _CELL_ENEMY  = Vector2(344, 0)

# --- Simple sheet constants (sprites-simple.md format) ---
# 1024×1024, 32×32 cells, 64×160 walk frames, 0.015 px/unit → 0.96×2.4 in-game
const _SS_PIXEL_SIZE      = 0.015
const _SS_FRAME_W         = 64
const _SS_FRAME_H         = 160
const _SS_ANIM_FPS        = 2.0
const _SS_SW_Y            = 32    # SW walk/raise/attack/weary band top
const _SS_NW_Y            = 192   # NW walk/raise/attack/weary band top
# Walk frames: left foot, together, right foot, together (ping-pong)
const _SS_WALK_X          = [128, 224, 320, 224]
# Weary frames: reserved for status ailment effect (same row as walk, ping-pong)
const _SS_WEARY_X         = [32, 128, 224, 128]
# Weak (one knee): low-HP pose — SW/NW share y=864 but use different x; h=128
const _SS_WEAK_Y          = 864
const _SS_WEAK_H          = 128
const _SS_WEAK_SW_X       = 32
const _SS_WEAK_NW_X       = 128
const _SS_WEAK_THRESH     = 0.35  # show weak pose below this HP ratio
# Attack frames: prep, strike, follow-through (96px wide, one-shot)
const _SS_ATTACK_X        = [416, 544, 672]
const _SS_ATTACK_W        = 96
const _SS_ATTACK_DURATION = 1.5   # 3 frames at 2fps
const _SS_RAISE_HANDS_X   = 32

# --- Node references ---
var _sprite: Sprite3D
var _hp_bar_root: Spatial
var _hp_bar_fill: MeshInstance
var _name_label: Label  = null
var _camera_ref: Camera = null

var _anim_time: float = 0.0
var _raise_hands_timer: float = 0.0
var _attack_anim_timer: float = 0.0
var _flash_timer: float = 0.0
const _FLASH_DURATION: float = 0.35


func _ready() -> void:
	hp = max_hp
	_create_sprite()
	_create_hp_bar()


func _create_sprite() -> void:
	_sprite = Sprite3D.new()
	var img := Image.new()
	img.load(sprite_sheet)
	var tex := ImageTexture.new()
	tex.create_from_image(img, 0)  # nearest-neighbour, no mipmaps
	_sprite.texture        = tex
	_sprite.pixel_size     = _SS_PIXEL_SIZE if simple_sheet else _PIXEL_SIZE
	_sprite.billboard = 1  # BILLBOARD_ENABLED: fully faces camera, sprite looks correct
	_sprite.alpha_cut = 1  # ALPHA_CUT_DISCARD: pixel art transparency via discard, GLES2-safe
	_sprite.region_enabled = true
	var px = _SS_PIXEL_SIZE if simple_sheet else _PIXEL_SIZE
	var fh = _SS_FRAME_H    if simple_sheet else _FRAME_H
	_sprite.translation.y  = fh * px * 0.35
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


func play_raise_hands(duration: float) -> void:
	_raise_hands_timer = duration


func play_attack_anim() -> void:
	_attack_anim_timer = _SS_ATTACK_DURATION


func flash() -> void:
	_flash_timer = _FLASH_DURATION


func _update_sprite() -> void:
	if simple_sheet:
		_update_sprite_simple()
	else:
		_update_sprite_legacy()


func _update_sprite_legacy() -> void:
	if not _sprite:
		return
	var params = _get_sprite_params()
	var flip   = params[1]
	var cell   = _CELL_ALLIED if team == Team.PLAYER else _CELL_ENEMY
	_sprite.flip_h = flip

	if _raise_hands_timer > 0.0:
		var x = _SW_RAISE_HANDS_X if params[0][0] == _SW[0] else _NW_RAISE_HANDS_X
		_sprite.region_rect = Rect2(cell.x + x, _RAISE_HANDS_Y, 16, _RAISE_HANDS_H)
		return

	var offsets = params[0]
	var frame   = int(_anim_time * _ANIM_FPS) % 4
	_sprite.region_rect = Rect2(cell.x + offsets[frame], cell.y + _FRAME_Y, _FRAME_W, _FRAME_H)


func _update_sprite_simple() -> void:
	if not _sprite:
		return
	var cam_yaw := 0.0
	if _camera_ref:
		cam_yaw = fmod(_camera_ref.get_parent().rotation_degrees.y, 360.0)
		if cam_yaw < 0.0:
			cam_yaw += 360.0
	var cam_index := int(cam_yaw / 90.0) % 4
	# dir: 0=NW, 1=SE(mirrored SW), 2=NE(mirrored NW), 3=SW
	var dir = _SPRITE_LOOKUP[cam_index][facing]
	var is_sw = (dir == 1 or dir == 3)
	_sprite.flip_h = (dir == 1 or dir == 2)
	var row_y = _SS_SW_Y if is_sw else _SS_NW_Y

	# Priority: raise-hands → attack → weary → walk
	if _raise_hands_timer > 0.0:
		_sprite.region_rect = Rect2(_SS_RAISE_HANDS_X, row_y, _SS_FRAME_W, _SS_FRAME_H)
		return

	if _attack_anim_timer > 0.0:
		var elapsed = _SS_ATTACK_DURATION - _attack_anim_timer
		var frame = min(int(elapsed * _SS_ANIM_FPS), 2)
		_sprite.region_rect = Rect2(_SS_ATTACK_X[frame], row_y, _SS_ATTACK_W, _SS_FRAME_H)
		return

	if float(hp) / float(max_hp) < _SS_WEAK_THRESH:
		var weak_x = _SS_WEAK_SW_X if is_sw else _SS_WEAK_NW_X
		_sprite.region_rect = Rect2(weak_x, _SS_WEAK_Y, _SS_FRAME_W, _SS_WEAK_H)
		return

	var frame = int(_anim_time * _SS_ANIM_FPS) % 4
	_sprite.region_rect = Rect2(_SS_WALK_X[frame], row_y, _SS_FRAME_W, _SS_FRAME_H)


func _process(delta: float) -> void:
	_anim_time += delta
	if _raise_hands_timer > 0.0:
		_raise_hands_timer = max(0.0, _raise_hands_timer - delta)
	if _attack_anim_timer > 0.0:
		_attack_anim_timer = max(0.0, _attack_anim_timer - delta)

	if _flash_timer > 0.0:
		_flash_timer = max(0.0, _flash_timer - delta)
		var t = _flash_timer / _FLASH_DURATION
		_sprite.modulate = Color(1.0 + t, 1.0 + t, 1.0 + t, 1.0)
	else:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _is_walking:
		_walk_t = min(_walk_t + delta * WALK_SPEED, 1.0)
		global_transform.origin = _walk_from.linear_interpolate(_walk_to, _walk_t)
		if _walk_t >= 1.0:
			_start_next_step()

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


func heal(amount: int) -> int:
	var actual := int(min(amount, max_hp - hp))
	hp = int(min(max_hp, hp + amount))
	_update_hp_bar()
	return actual


func set_alive(val: bool) -> void:
	alive = val
	visible = val
	if _name_label and is_instance_valid(_name_label):
		_name_label.visible = val


func get_snapshot() -> Dictionary:
	return {
		"node":         self,
		"grid_x":       grid_x,
		"grid_z":       grid_z,
		"hp":           hp,
		"ct":           ct,
		"facing":       facing,
		"has_moved":    has_moved,
		"has_acted":    has_acted,
		"alive":        alive,
		"accuracy_mod": accuracy_mod,
		"evasion_mod":  evasion_mod,
	}


func restore_from_snapshot(entry: Dictionary, map_data) -> void:
	hp           = entry.hp
	ct           = entry.ct
	facing       = entry.get("facing", DIR_S)
	has_moved    = entry.has_moved
	has_acted    = entry.has_acted
	accuracy_mod = entry.get("accuracy_mod", 0)
	evasion_mod  = entry.get("evasion_mod", 0)
	set_alive(entry.alive)
	if entry.alive:
		place_on_grid(entry.grid_x, entry.grid_z, map_data)
	_update_hp_bar()


func place_on_grid(x: int, z: int, map_data) -> void:
	_map_data = map_data
	_is_walking = false
	_walk_path.clear()
	grid_x = x
	grid_z = z
	global_transform.origin = map_data.cell_to_world(x, z)


# Animate the unit along a pre-computed path.
# path: Array of Vector2 steps (not including start), from movement.find_path().
# from_cell: the grid cell the unit is departing from (before grid_x/z are committed).
func walk_path(path: Array, from_cell: Vector2) -> void:
	if path.empty():
		emit_signal("move_finished")
		return
	_walk_path = path.duplicate()
	_walk_from_cell = from_cell
	_is_walking = true
	_start_next_step()


func _start_next_step() -> void:
	if _walk_path.empty():
		_is_walking = false
		emit_signal("move_finished")
		return
	var next_cell: Vector2 = _walk_path.pop_front()
	var dx = int(next_cell.x) - int(_walk_from_cell.x)
	var dz = int(next_cell.y) - int(_walk_from_cell.y)
	if abs(dz) > abs(dx):
		facing = DIR_S if dz > 0 else DIR_N
	else:
		facing = DIR_E if dx > 0 else DIR_W
	_walk_from = global_transform.origin
	_walk_to = _map_data.cell_to_world(int(next_cell.x), int(next_cell.y))
	_walk_t = 0.0
	_walk_from_cell = next_cell


func start_turn() -> void:
	has_moved = false
	has_acted = false
	ct = 0
