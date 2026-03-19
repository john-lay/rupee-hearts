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
	CHARIOT_SELECT,
}

onready var map_data = $"../MapData"
onready var turn_manager = $"../TurnManager"
onready var units_node = $"../Units"
onready var _movement = $"../Movement"
onready var _camera: Camera = $"../CameraRig/Camera"
onready var _turn_order_bar = $"../UI/TurnOrderBar"

var state: int = State.INIT
var active_unit = null   # the unit currently taking their turn
var _reachable_cells := []
var _attack_targets := []
var _active_indicator: MeshInstance
var _indicator_pulse_time: float = 0.0
const _INDICATOR_COLOR = Color(1.0, 0.85, 0.0)

var _chariot_root = null       # root node of the timeline tree
var _current_node = null       # node representing the current turn position
var _next_branch_id: int = 0   # monotonic counter for new branches
var _chariot_turn_number: int = 0
var _chariot_node_id: int = 0  # unique int id per node — avoids hashing cyclic dicts
var _chariot_panel: Control = null


func _process(delta: float) -> void:
	if _active_indicator and _active_indicator.visible:
		_indicator_pulse_time += delta
		var t = (sin(_indicator_pulse_time * 2.0) + 1.0) * 0.5
		_active_indicator.material_override.set_shader_param(
			"border_color", _INDICATOR_COLOR.linear_interpolate(_INDICATOR_COLOR.lightened(0.5), t)
		)

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
	_turn_order_bar.setup(turn_manager)
	# Defer so all sibling nodes (AIController, Movement) finish their _ready()
	# before the CT loop can fire an enemy turn.
	call_deferred("_start_battle")


func _create_active_indicator() -> void:
	_active_indicator = MeshInstance.new()
	var plane := PlaneMesh.new()
	var cs = $"../GridMap".cell_size
	plane.size = Vector2(cs.x * 0.85, cs.z * 0.85)
	_active_indicator.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = $"../Movement"._outline_shader
	mat.set_shader_param("fill_color", _INDICATOR_COLOR)
	mat.set_shader_param("border_color", _INDICATOR_COLOR)
	_active_indicator.material_override = mat
	get_parent().add_child(_active_indicator)


func _update_active_indicator() -> void:
	if active_unit == null:
		_active_indicator.visible = false
		return
	var pos = map_data.cell_to_world(active_unit.grid_x, active_unit.grid_z)
	_active_indicator.translation = pos + Vector3(0, 0.05, 0)
	_active_indicator.visible = true
	_indicator_pulse_time = 0.0


func _start_battle() -> void:
	_create_active_indicator()
	_create_debug_checkbox()
	_create_chariot_button()
	_change_state(State.TICK_CT)


func _create_debug_checkbox() -> void:
	var hbox := HBoxContainer.new()
	hbox.anchor_top    = 1.0
	hbox.anchor_bottom = 1.0
	hbox.anchor_left   = 0.0
	hbox.anchor_right  = 0.0
	hbox.margin_left   = 8.0
	hbox.margin_top    = -30.0
	hbox.margin_bottom = -6.0
	hbox.margin_right  = 180.0

	var chk := CheckBox.new()
	chk.text = "Debug Grid"
	chk.connect("toggled", self, "_on_debug_grid_toggled")
	hbox.add_child(chk)

	get_node("../UI").add_child(hbox)


func _on_debug_grid_toggled(on: bool) -> void:
	_movement.toggle_debug_grid(on)


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
			_update_active_indicator()
			_change_state(State.TICK_CT)
		State.ENEMY_THINK:
			$"../AIController".take_turn(active_unit, map_data, self)
		State.CHARIOT_SELECT:
			_movement.clear_highlights()
			_open_chariot()


func _on_turn_ready(unit) -> void:
	active_unit = unit
	active_unit.start_turn()
	_update_active_indicator()
	_turn_order_bar.refresh(active_unit)
	if active_unit.team == active_unit.Team.PLAYER:
		_snapshot_turn(active_unit)
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
	_update_active_indicator()
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
	# Close Chariot overlay
	if state == State.CHARIOT_SELECT:
		if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
			_close_chariot()
			_change_state(State.SELECT_ACTION)
			return

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

	_spawn_damage_number(damage, defender)
	defender.take_damage(damage)
	_turn_order_bar.refresh(active_unit)
	if not defender.is_alive():
		_remove_unit(defender)
		_check_battle_over()


func _spawn_damage_number(amount: int, unit) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_color_override("font_color", Color(1.0, 0.9, 0.1))
	get_node("../UI").add_child(label)

	var world_pos = unit.global_transform.origin + Vector3(0, 2.0, 0)
	var screen_pos = _camera.unproject_position(world_pos)
	label.rect_position = screen_pos + Vector2(-12, 0)

	var tween := Tween.new()
	label.add_child(tween)
	tween.interpolate_property(label, "rect_position",
		label.rect_position, label.rect_position + Vector2(0, -50),
		0.9, Tween.TRANS_LINEAR)
	tween.interpolate_property(label, "modulate",
		Color(1, 1, 1, 1), Color(1, 1, 1, 0),
		0.9, Tween.TRANS_LINEAR)
	tween.connect("tween_all_completed", label, "queue_free")
	tween.start()


func _remove_unit(unit) -> void:
	map_data.clear_unit_at(unit.grid_x, unit.grid_z)
	turn_manager.remove_unit(unit)
	unit.cleanup_label()
	unit.set_alive(false)


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
	var result = []
	for unit in units_node.get_children():
		if unit.alive:
			result.append(unit)
	return result


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


# --- Chariot Tarot ---

func _snapshot_turn(unit) -> void:
	# Determine branch: first child continues parent's branch, further children fork
	var branch_id: int
	if _current_node == null:
		branch_id = 0
	elif _current_node.children.size() == 0:
		branch_id = _current_node.branch_id
	else:
		branch_id = _next_branch_id
		_next_branch_id += 1

	var snap := {
		"id":               _chariot_node_id,
		"turn_number":      _chariot_turn_number,
		"acting_unit_name": unit.unit_name,
		"acting_unit_team": unit.team,
		"branch_id":        branch_id,
		"parent":           _current_node,
		"children":         [],
		"units":            [],
	}
	_chariot_node_id += 1
	_chariot_turn_number += 1

	for u in units_node.get_children():
		snap.units.append(u.get_snapshot())

	if _current_node != null:
		_current_node.children.append(snap)
	else:
		_chariot_root = snap

	_current_node = snap


func _restore_snapshot(snap: Dictionary) -> void:
	var alive_units := []
	for entry in snap.units:
		entry.node.restore_from_snapshot(entry, map_data)
		if entry.alive:
			alive_units.append(entry.node)

	map_data.clear_all_units()
	for u in alive_units:
		map_data.set_unit_at(u.grid_x, u.grid_z, u)

	turn_manager.restore_units(alive_units)

	active_unit = null
	for u in alive_units:
		if u.unit_name == snap.acting_unit_name:
			active_unit = u
			break
	if not active_unit and alive_units.size() > 0:
		active_unit = alive_units[0]

	active_unit.start_turn()
	_update_active_indicator()
	_turn_order_bar.refresh(active_unit)

	_current_node = snap  # reposition in tree; id-based comparisons avoid cyclic dict hashing

	_close_chariot()
	_change_state(State.SELECT_ACTION)


# DFS pre-order walk: first child continues the branch at same indent,
# additional children (forks) get +1 indent level.
func _walk_tree(node: Dictionary, indent: int, result: Array) -> void:
	result.append({"snap": node, "indent": indent})
	if node.children.size() <= 1:
		for child in node.children:
			_walk_tree(child, indent, result)
	else:
		_walk_tree(node.children[0], indent, result)
		for i in range(1, node.children.size()):
			_walk_tree(node.children[i], indent + 1, result)


# Returns a set of integer ids for all ancestors of _current_node (inclusive).
func _get_current_path() -> Dictionary:
	var path := {}
	var node = _current_node
	while node != null:
		path[node.id] = true
		node = node.parent
	return path


func _create_chariot_button() -> void:
	var btn := Button.new()
	btn.text = "Chariot"
	btn.anchor_top    = 1.0
	btn.anchor_bottom = 1.0
	btn.anchor_left   = 0.0
	btn.anchor_right  = 0.0
	btn.margin_left   = 8.0
	btn.margin_top    = -58.0
	btn.margin_bottom = -34.0
	btn.margin_right  = 100.0
	btn.connect("pressed", self, "_on_chariot_pressed")
	get_node("../UI").add_child(btn)


func _on_chariot_pressed() -> void:
	if state == State.SELECT_ACTION and _chariot_root != null:
		_change_state(State.CHARIOT_SELECT)


func _open_chariot() -> void:
	if _chariot_panel and is_instance_valid(_chariot_panel):
		_chariot_panel.queue_free()
	_chariot_panel = _build_chariot_panel()
	get_node("../UI").add_child(_chariot_panel)


func _close_chariot() -> void:
	if _chariot_panel and is_instance_valid(_chariot_panel):
		_chariot_panel.queue_free()
	_chariot_panel = null


func _build_chariot_panel() -> Control:
	var panel := PanelContainer.new()
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.margin_left   = -200.0
	panel.margin_right  = 0.0
	panel.margin_top    = 0.0
	panel.margin_bottom = 0.0

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.margin_left   = 8.0
	vbox.margin_right  = -8.0
	vbox.margin_top    = 8.0
	vbox.margin_bottom = -8.0
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "— Chariot —"
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	# Walk the full tree in DFS order and build one card per node
	var entries := []
	_walk_tree(_chariot_root, 0, entries)
	var current_path := _get_current_path()
	for entry in entries:
		var is_current: bool = entry.snap.id == _current_node.id
		var is_on_path: bool = entry.snap.id in current_path and not is_current
		vbox.add_child(_build_chariot_card(entry.snap, entry.indent, is_current, is_on_path))

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.connect("pressed", self, "_on_chariot_cancel")
	vbox.add_child(cancel)

	return panel


func _build_chariot_card(snap: Dictionary, indent: int, is_current: bool, is_on_path: bool) -> Control:
	var team_color := Color(0.3, 0.5, 0.9) if snap.acting_unit_team == 0 else Color(0.9, 0.3, 0.3)

	# Outer container provides left-margin indentation for branch depth
	var row := HBoxContainer.new()
	if indent > 0:
		var spacer := Control.new()
		spacer.rect_min_size = Vector2(indent * 16, 0)
		row.add_child(spacer)

	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# TODO: replace initial with unit portrait image
	btn.text = snap.acting_unit_name[0] + "  " + snap.acting_unit_name + "\n   Turn " + str(snap.turn_number + 1)
	btn.align = Button.ALIGN_LEFT

	var bg_color: Color
	if is_current:
		bg_color = team_color.darkened(0.1)   # bright: current position
	elif is_on_path:
		bg_color = team_color.darkened(0.35)  # medium: on the active branch
	else:
		bg_color = team_color.darkened(0.6)   # dim: alternate branch

	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_width_left = 4
	normal.border_color = team_color if not is_current else Color(1, 1, 1)
	normal.content_margin_left   = 10.0
	normal.content_margin_top    = 6.0
	normal.content_margin_bottom = 6.0
	btn.add_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_stylebox_override("hover", hover)

	btn.connect("pressed", self, "_on_chariot_card_pressed", [snap])
	row.add_child(btn)
	return row


func _on_chariot_card_pressed(snap: Dictionary) -> void:
	_restore_snapshot(snap)


func _on_chariot_cancel() -> void:
	_close_chariot()
	_change_state(State.SELECT_ACTION)


# --- Spawn ---

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
	unit.setup_label(_camera, get_node("../UI"))
