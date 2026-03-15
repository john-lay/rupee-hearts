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


func _ready() -> void:
	hp = max_hp


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
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
