extends Node

enum State {
	INIT,
	TICK_CT,
	SELECT_UNIT,
	SELECT_ACTION,
	SELECT_MOVE_TARGET,
	MOVE_UNIT,
	SELECT_ATTACK_TARGET,
	RESOLVE_COMBAT,
	ENEMY_THINK,
	END_TURN,
	BATTLE_OVER,
}

onready var map_data = $"../MapData"
onready var turn_manager = $"../TurnManager"
onready var units_node = $"../Units"
onready var _movement = $"../Movement"
onready var _camera: Camera = $"../CameraRig/Camera"

var state: int = State.INIT
var active_unit = null   # the unit currently taking their turn
var _reachable_cells := []
var _attack_targets := []

# Spawn positions from the prototype map layout
const PLAYER_STARTS = [Vector2(1, 4), Vector2(4, 4)]
const ENEMY_STARTS  = [Vector2(1, 1), Vector2(4, 1)]

var _unit_scene = preload("res://scenes/unit.tscn")

signal state_changed(new_state)
signal battle_over(winner_team)


func _ready() -> void:
	_spawn_units()
	turn_manager.connect("turn_ready", self, "_on_turn_ready")
	get_node("../UI/ActionMenu").setup(self)
	# Defer so all sibling nodes (AIController, Movement) finish their _ready()
	# before the CT loop can fire an enemy turn.
	call_deferred("_start_battle")


func _start_battle() -> void:
	_change_state(State.TICK_CT)


# --- State machine ---

func _change_state(new_state: int) -> void:
	state = new_state
	emit_signal("state_changed", new_state)
	match state:
		State.TICK_CT:
			turn_manager.tick_until_next()
		State.SELECT_ACTION:
			_movement.clear_highlights()
		State.SELECT_MOVE_TARGET:
			_reachable_cells = _movement.get_reachable_cells(active_unit)
			_movement.show_move_highlights(_reachable_cells)
		State.SELECT_ATTACK_TARGET:
			_attack_targets = _movement.get_attack_targets(active_unit)
			_movement.show_attack_highlights(_attack_targets)
		State.END_TURN:
			_movement.clear_highlights()
			active_unit = null
			_change_state(State.TICK_CT)
		State.ENEMY_THINK:
			$"../AIController".take_turn(active_unit, map_data, self)


func _on_turn_ready(unit) -> void:
	active_unit = unit
	active_unit.start_turn()
	if active_unit.team == active_unit.Team.PLAYER:
		_change_state(State.SELECT_ACTION)
	else:
		_change_state(State.ENEMY_THINK)


# Called by UI ActionMenu
func player_select_move() -> void:
	if state == State.SELECT_ACTION and not active_unit.has_moved:
		_change_state(State.SELECT_MOVE_TARGET)


func player_select_attack() -> void:
	if state == State.SELECT_ACTION and not active_unit.has_acted:
		_change_state(State.SELECT_ATTACK_TARGET)


func player_wait() -> void:
	if state == State.SELECT_ACTION:
		_change_state(State.END_TURN)


# Called by movement system after the player picks a destination
func confirm_move(to_x: int, to_z: int) -> void:
	_move_unit(active_unit, to_x, to_z)
	active_unit.has_moved = true
	_change_state(State.SELECT_ACTION)


# Called by attack targeting after the player picks a target cell
func confirm_attack(target_unit) -> void:
	_resolve_combat(active_unit, target_unit)
	active_unit.has_acted = true
	_change_state(State.SELECT_ACTION)


# Called by AI controller when it is done with its turn
func end_enemy_turn() -> void:
	_change_state(State.END_TURN)


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	# Cancel targeting with right-click or Escape
	if state == State.SELECT_MOVE_TARGET or state == State.SELECT_ATTACK_TARGET:
		if (event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE) or \
				(event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_RIGHT):
			_change_state(State.SELECT_ACTION)
			return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT):
		return

	var cell = _get_cell_under_mouse()
	var x = int(cell.x)
	var z = int(cell.y)

	match state:
		State.SELECT_MOVE_TARGET:
			if cell in _reachable_cells:
				confirm_move(x, z)
		State.SELECT_ATTACK_TARGET:
			if cell in _attack_targets:
				confirm_attack(map_data.get_unit_at(x, z))


func _get_cell_under_mouse() -> Vector2:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = _camera.project_ray_origin(mouse_pos)
	var ray_dir    = _camera.project_ray_normal(mouse_pos)

	if abs(ray_dir.y) < 0.001:
		return Vector2(-1, -1)

	# Intersect with the top surface of ground tiles.
	# GridMap.world_to_map() does not exist in Godot 3 so we calculate manually.
	var grid_map = $"../GridMap"
	var plane_y = grid_map.cell_size.y
	var t = (plane_y - ray_origin.y) / ray_dir.y
	var hit = ray_origin + ray_dir * t

	var grid_x = int(floor(hit.x / grid_map.cell_size.x))
	var grid_z = int(floor(hit.z / grid_map.cell_size.z))
	return Vector2(grid_x, grid_z)


# --- Actions ---

func _move_unit(unit, to_x: int, to_z: int) -> void:
	map_data.clear_unit_at(unit.grid_x, unit.grid_z)
	unit.place_on_grid(to_x, to_z, map_data)
	map_data.set_unit_at(to_x, to_z, unit)


func _resolve_combat(attacker, defender) -> void:
	var height_diff = map_data.get_height(attacker.grid_x, attacker.grid_z) \
		- map_data.get_height(defender.grid_x, defender.grid_z)

	var damage = max(1, attacker.attack - defender.defense)
	if height_diff > 0:
		damage = int(damage * 1.15)
	elif height_diff < 0:
		damage = int(damage * 0.90)

	defender.take_damage(damage)
	if not defender.is_alive():
		_remove_unit(defender)
		_check_battle_over()


func _remove_unit(unit) -> void:
	map_data.clear_unit_at(unit.grid_x, unit.grid_z)
	turn_manager.remove_unit(unit)
	unit.queue_free()


func _check_battle_over() -> void:
	var players_alive = _get_units_by_team(load("res://scripts/unit.gd").Team.PLAYER).size() > 0
	var enemies_alive = _get_units_by_team(load("res://scripts/unit.gd").Team.ENEMY).size() > 0
	if not players_alive:
		_change_state(State.BATTLE_OVER)
		emit_signal("battle_over", load("res://scripts/unit.gd").Team.ENEMY)
	elif not enemies_alive:
		_change_state(State.BATTLE_OVER)
		emit_signal("battle_over", load("res://scripts/unit.gd").Team.PLAYER)


# --- Helpers ---

func get_all_units() -> Array:
	return units_node.get_children()


func _get_units_by_team(team: int) -> Array:
	var result = []
	for unit in get_all_units():
		if unit.team == team:
			result.append(unit)
	return result


# --- Spawn ---

func _spawn_units() -> void:
	var UnitScene = load("res://scenes/unit.tscn")
	var UnitScript = load("res://scripts/unit.gd")

	var player_configs = [
		{name = "Knight", team = UnitScript.Team.PLAYER, hp = 28, atk = 10, def = 6, spd = 8,  move = 3, range = 1},
		{name = "Archer", team = UnitScript.Team.PLAYER, hp = 20, atk = 9,  def = 3, spd = 12, move = 3, range = 2},
	]
	var enemy_configs = [
		{name = "Goblin",  team = UnitScript.Team.ENEMY, hp = 16, atk = 7, def = 2, spd = 10, move = 3, range = 1},
		{name = "Goblin2", team = UnitScript.Team.ENEMY, hp = 16, atk = 7, def = 2, spd = 10, move = 3, range = 1},
	]

	for i in player_configs.size():
		_spawn_unit(UnitScene, player_configs[i], PLAYER_STARTS[i])
	for i in enemy_configs.size():
		_spawn_unit(UnitScene, enemy_configs[i], ENEMY_STARTS[i])

	turn_manager.register_units(get_all_units())


func _spawn_unit(scene, cfg: Dictionary, grid_pos: Vector2) -> void:
	var unit = scene.instance()
	unit.unit_name = cfg.name
	unit.team = cfg.team
	unit.max_hp = cfg.hp
	unit.attack = cfg.atk
	unit.defense = cfg.def
	unit.speed = cfg.spd
	unit.move_range = cfg.move
	unit.attack_range = cfg.range
	units_node.add_child(unit)
	unit.place_on_grid(int(grid_pos.x), int(grid_pos.y), map_data)
	map_data.set_unit_at(int(grid_pos.x), int(grid_pos.y), unit)
