extends HBoxContainer

const PREVIEW_COUNT = 5

var _turn_manager = null


func setup(turn_manager) -> void:
	_turn_manager = turn_manager


func refresh() -> void:
	for child in get_children():
		child.queue_free()

	if not _turn_manager:
		return

	var order = _turn_manager.preview_order(PREVIEW_COUNT)
	for unit in order:
		var lbl = Label.new()
		lbl.text = unit.unit_name
		lbl.modulate = Color(0.4, 0.6, 1) if unit.team == 0 else Color(1, 0.4, 0.4)
		add_child(lbl)
