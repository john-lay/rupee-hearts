extends VBoxContainer

onready var btn_move   = $BtnMove
onready var btn_attack = $BtnAttack
onready var btn_wait   = $BtnWait

var _battle_manager = null


func _ready() -> void:
	hide()
	btn_move.connect("pressed", self, "_on_move")
	btn_attack.connect("pressed", self, "_on_attack")
	btn_wait.connect("pressed", self, "_on_wait")


func setup(battle_manager) -> void:
	_battle_manager = battle_manager
	_battle_manager.connect("state_changed", self, "_on_state_changed")


# Must match BattleManager.State.SELECT_ACTION
const _SELECT_ACTION = 3

func _on_state_changed(new_state: int) -> void:
	if new_state == _SELECT_ACTION:
		var unit = _battle_manager.active_unit
		btn_move.disabled   = unit.has_moved
		btn_attack.disabled = unit.has_acted
		show()
	else:
		hide()


func _on_move()   -> void: _battle_manager.player_select_move()
func _on_attack() -> void: _battle_manager.player_select_attack()
func _on_wait()   -> void: _battle_manager.player_wait()
