extends VBoxContainer

onready var _main_buttons      = $MainButtons
onready var btn_move           = $MainButtons/BtnMove
onready var btn_attack         = $MainButtons/BtnAttack
onready var btn_item           = $MainButtons/BtnItem
onready var btn_wait           = $MainButtons/BtnWait
onready var btn_cancel         = $MainButtons/BtnCancel
onready var _item_sub_menu     = $ItemSubMenu
onready var btn_healing_potion = $ItemSubMenu/BtnHealingPotion
onready var btn_item_back      = $ItemSubMenu/BtnItemBack

var _battle_manager = null


func _ready() -> void:
	hide()
	btn_move.connect("pressed", self, "_on_move")
	btn_attack.connect("pressed", self, "_on_attack")
	btn_item.connect("pressed", self, "_on_open_item_menu")
	btn_wait.connect("pressed", self, "_on_wait")
	btn_cancel.connect("pressed", self, "_on_cancel")
	btn_healing_potion.connect("pressed", self, "_on_healing_potion")
	btn_item_back.connect("pressed", self, "_on_item_back")


func setup(battle_manager) -> void:
	_battle_manager = battle_manager
	_battle_manager.connect("state_changed", self, "_on_state_changed")


# Must match BattleManager.State values
const _SELECT_ACTION      = 3
const _SELECT_MOVE_TARGET = 4
const _SELECT_ITEM_TARGET = 13

func _on_state_changed(new_state: int) -> void:
	if new_state == _SELECT_ACTION:
		var unit = _battle_manager.active_unit
		btn_move.disabled   = unit.has_moved
		btn_attack.disabled = unit.has_acted or not _battle_manager.has_attack_targets()
		btn_item.disabled   = unit.has_acted or _battle_manager.item_stock <= 0
		btn_item.text       = "Item"
		_show_main_buttons()
		_set_all_buttons_visible(true)
		show()
	elif new_state == _SELECT_MOVE_TARGET or new_state == _SELECT_ITEM_TARGET:
		_show_main_buttons()
		_set_all_buttons_visible(false)
		btn_cancel.show()
		show()
	else:
		hide()


func _set_all_buttons_visible(visible: bool) -> void:
	btn_move.visible   = visible
	btn_attack.visible = visible
	btn_item.visible   = visible
	btn_wait.visible   = visible
	btn_cancel.visible = visible


func _show_main_buttons() -> void:
	_main_buttons.show()
	_item_sub_menu.hide()


func _show_item_sub_menu() -> void:
	btn_healing_potion.text = "Healing Potion (x%d)" % _battle_manager.item_stock
	_main_buttons.hide()
	_item_sub_menu.show()


func _on_move()   -> void: _battle_manager.player_select_move()
func _on_attack() -> void: _battle_manager.player_select_attack()
func _on_wait()   -> void: _battle_manager.player_wait()
func _on_cancel() -> void:
	var s: int = _battle_manager.state
	if s == _SELECT_MOVE_TARGET or s == _SELECT_ITEM_TARGET:
		_battle_manager.player_cancel_targeting()
	else:
		_battle_manager.player_cancel_turn()

func _on_open_item_menu() -> void:
	_show_item_sub_menu()

func _on_healing_potion() -> void:
	_battle_manager.player_select_item()

func _on_item_back() -> void:
	_show_main_buttons()
