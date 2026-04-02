extends VBoxContainer

const PREVIEW_COUNT = 5
const CARD_WIDTH    = 160
const PORTRAIT_W    = 24   # 0.5× integer scale of the 48px source
const PORTRAIT_H    = 32   # 0.5× integer scale of the 64px source
const SHEET_PATH    = "res://assets/sprites/soldier.png"

var _turn_manager   = null
var _battle_manager = null
var _portrait_ally:  ImageTexture = null
var _portrait_enemy: ImageTexture = null
var _footer: VBoxContainer = null


func _ready() -> void:
	var img = Image.new()
	img.load(SHEET_PATH)
	var ally_crop = img.get_rect(Rect2(352, 712, 48, 64))
	_portrait_ally = ImageTexture.new()
	_portrait_ally.create_from_image(ally_crop, 0)   # flags=0: nearest-neighbour
	var enemy_crop = img.get_rect(Rect2(408, 712, 48, 64))
	_portrait_enemy = ImageTexture.new()
	_portrait_enemy.create_from_image(enemy_crop, 0)
	_footer = VBoxContainer.new()
	add_child(_footer)


func add_to_footer(node: Control) -> void:
	_footer.add_child(node)


func setup(turn_manager, battle_manager = null) -> void:
	_turn_manager   = turn_manager
	_battle_manager = battle_manager


func refresh(active_unit = null) -> void:
	for child in get_children():
		if child != _footer:
			child.queue_free()
	if not _turn_manager:
		return

	if active_unit:
		_add_card(active_unit, true)

	var order = _turn_manager.preview_order(PREVIEW_COUNT)
	for unit in order:
		_add_card(unit, false)

	move_child(_footer, get_child_count() - 1)


func _add_card(unit, is_active: bool) -> void:
	var team_color = Color(0.35, 0.6, 1.0) if unit.team == 0 else Color(1.0, 0.38, 0.38)

	# Card panel
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.13, 0.13, 0.18) if is_active else Color(0.09, 0.09, 0.12)
	card_style.border_width_left = 3
	card_style.border_color = team_color if is_active else team_color.darkened(0.4)
	card_style.set_corner_radius_all(2)
	card_style.content_margin_left = 6
	card_style.content_margin_right = 6
	card_style.content_margin_top = 5
	card_style.content_margin_bottom = 5
	card.add_stylebox_override("panel", card_style)
	card.rect_min_size = Vector2(CARD_WIDTH, 0)
	if _battle_manager:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.connect("gui_input", self, "_on_card_input", [unit])
	add_child(card)

	# Row
	var hbox := HBoxContainer.new()
	hbox.add_constant_override("separation", 7)
	card.add_child(hbox)

	# Portrait — pre-cropped texture keeps nearest-neighbour filtering
	var portrait := TextureRect.new()
	portrait.texture = _portrait_ally if unit.team == 0 else _portrait_enemy
	portrait.expand = true
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.rect_min_size = Vector2(PORTRAIT_W, PORTRAIT_H)
	hbox.add_child(portrait)

	# Info: name + HP bar
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_constant_override("separation", 4)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = unit.unit_name
	name_lbl.add_color_override("font_color", Color(1, 1, 1) if is_active else Color(0.72, 0.72, 0.72))
	vbox.add_child(name_lbl)

	var hp_ratio = float(unit.hp) / float(unit.max_hp)
	var hp_color: Color
	if hp_ratio > 0.5:
		hp_color = Color(0.18, 0.6, 0.25)
	elif hp_ratio > 0.25:
		hp_color = Color(0.7, 0.62, 0.12)
	else:
		hp_color = Color(0.72, 0.2, 0.18)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_bar.rect_min_size = Vector2(0, 7)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.percent_visible = false

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = hp_color
	fill_style.set_corner_radius_all(1)
	hp_bar.add_stylebox_override("fg", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.12)
	bg_style.set_corner_radius_all(1)
	hp_bar.add_stylebox_override("bg", bg_style)

	vbox.add_child(hp_bar)


func _on_card_input(event: InputEvent, unit) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		_battle_manager.inspect_unit(unit)
