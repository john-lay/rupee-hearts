extends PanelContainer

onready var lbl_name = $VBox/LblName
onready var lbl_hp   = $VBox/LblHP
onready var hp_bar   = $VBox/HPBar


func show_unit(unit) -> void:
	lbl_name.text = unit.unit_name
	lbl_hp.text   = "%d / %d" % [unit.hp, unit.max_hp]
	hp_bar.max_value = unit.max_hp
	hp_bar.value     = unit.hp
	show()


func hide_unit() -> void:
	hide()
