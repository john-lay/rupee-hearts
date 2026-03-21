extends Node

# Greedy AI: close on the nearest player unit; attack if in range.

onready var movement = get_node("../Movement")

var _pending_unit = null
var _pending_target = null
var _pending_battle_manager = null


func take_turn(unit, map_data, battle_manager) -> void:
	var target = _nearest_player(unit, map_data, battle_manager)
	if not target:
		battle_manager.end_enemy_turn()
		return

	# Attack without moving if already in range
	if _can_attack(unit, target):
		battle_manager.confirm_attack(target)
		battle_manager.end_enemy_turn()
		return

	# Move toward target, then check attack in the callback
	var reachable = movement.get_reachable_cells(unit)
	var best_cell = _closest_cell_to(reachable, target)
	if best_cell:
		_pending_unit = unit
		_pending_target = target
		_pending_battle_manager = battle_manager
		battle_manager.confirm_move(int(best_cell.x), int(best_cell.y), funcref(self, "_after_ai_move"))
		return  # _after_ai_move handles end_enemy_turn

	battle_manager.end_enemy_turn()


func _after_ai_move() -> void:
	var bm = _pending_battle_manager
	var pu = _pending_unit
	var pt = _pending_target
	_pending_unit = null
	_pending_target = null
	_pending_battle_manager = null
	if pu != null and pt != null and bm != null:
		if _can_attack(pu, pt):
			bm.confirm_attack(pt)
	if bm != null:
		bm.end_enemy_turn()


func _nearest_player(unit, map_data, battle_manager):
	var best = null
	var best_dist = INF
	for other in battle_manager.get_all_units():
		if other.team == unit.team:
			continue
		var dist = abs(other.grid_x - unit.grid_x) + abs(other.grid_z - unit.grid_z)
		if dist < best_dist:
			best_dist = dist
			best = other
	return best


func _can_attack(unit, target) -> bool:
	var dist = abs(target.grid_x - unit.grid_x) + abs(target.grid_z - unit.grid_z)
	return dist <= unit.attack_range


# From a list of reachable Vector2 cells, return the one closest to target
func _closest_cell_to(cells: Array, target) -> Vector2:
	var best = null
	var best_dist = INF
	for cell in cells:
		var dist = abs(cell.x - target.grid_x) + abs(cell.y - target.grid_z)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best
