extends Node

# Emitted when a unit's CT reaches 100 and it is their turn to act.
signal turn_ready(unit)

var _units := []  # all living Unit nodes, registered at battle start


func register_units(units: Array) -> void:
	_units = units
	# Stagger starting CT so turns are spread across the first round
	randomize()
	for unit in _units:
		unit.ct = randi() % 100


# Advance CT for all units until the next one is ready to act.
# Calls turn_ready signal with that unit and stops.
func tick_until_next() -> void:
	while true:
		var next = _find_ready_unit()
		if next:
			emit_signal("turn_ready", next)
			return
		_advance_ct()


# Returns the unit whose CT just hit 100, or null if none yet.
func _find_ready_unit():
	var best = null
	for unit in _units:
		if unit.ct >= 100:
			if best == null or unit.ct > best.ct or \
					(unit.ct == best.ct and unit.speed > best.speed):
				best = unit
	return best


func _advance_ct() -> void:
	for unit in _units:
		unit.ct += unit.speed


# Simulate forward to predict the next `count` units to act, without
# modifying any real state. Used by the TurnOrderBar UI.
func preview_order(count: int) -> Array:
	# Snapshot CT values
	var snapshot := {}
	for unit in _units:
		snapshot[unit] = unit.ct

	var order := []
	while order.size() < count:
		# Find ready
		var best = null
		for unit in _units:
			var ct = snapshot[unit]
			if ct >= 100:
				if best == null or ct > snapshot[best] or \
						(ct == snapshot[best] and unit.speed > best.speed):
					best = unit
		if best:
			order.append(best)
			snapshot[best] = 0
		else:
			# Advance snapshot CTs
			for unit in _units:
				snapshot[unit] += unit.speed

	return order


func remove_unit(unit) -> void:
	_units.erase(unit)
