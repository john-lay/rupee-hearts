extends Panel

const ALLY_COLOR  = Color(0.08, 0.18, 0.55, 0.92)
const ENEMY_COLOR = Color(0.55, 0.08, 0.08, 0.92)

const PORTRAIT_ALLY_RECT  = Rect2(352, 712, 48, 64)
const PORTRAIT_ENEMY_RECT = Rect2(408, 712, 48, 64)

var _bg:           ColorRect
var _portrait:     TextureRect
var _name_label:   Label
var _hp_label:     Label
var _stat_vals:    Dictionary
var _tween:        Tween
var _pending_unit  = null

# Set in _ready() from anchor and stored margins
var _slide_dir:        int   = -1   # -1 = slide left,  +1 = slide right
var _rest_margin_left:  float = 0.0
var _rest_margin_right: float = 0.0
var _slide_offset:      float = 0.0  # pixels to shift off-screen


func _ready() -> void:
	rect_min_size = Vector2(162, 220)

	# anchor_left is 0.0 for left panel, 1.0 for right panel (set in main.tscn)
	_slide_dir = -1 if anchor_left < 0.5 else 1
	_rest_margin_left  = margin_left
	_rest_margin_right = margin_right
	_slide_offset      = _slide_dir * (rect_min_size.x + 20)

	_bg = ColorRect.new()
	_bg.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	add_child(_bg)

	var margin_c := MarginContainer.new()
	margin_c.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	margin_c.add_constant_override("margin_left",   8)
	margin_c.add_constant_override("margin_right",  8)
	margin_c.add_constant_override("margin_top",    8)
	margin_c.add_constant_override("margin_bottom", 8)
	add_child(margin_c)

	var vbox := VBoxContainer.new()
	vbox.add_constant_override("separation", 4)
	margin_c.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_constant_override("separation", 6)
	vbox.add_child(header)

	_portrait = TextureRect.new()
	_portrait.rect_min_size = Vector2(48, 64)
	_portrait.expand = true
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_portrait)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info_vbox)

	_name_label = Label.new()
	_name_label.autowrap = true
	info_vbox.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.add_color_override("font_color", Color(0.4, 1.0, 0.4))
	info_vbox.add_child(_hp_label)

	vbox.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_constant_override("hseparation", 10)
	grid.add_constant_override("vseparation", 2)
	vbox.add_child(grid)

	_stat_vals = {}
	var rows = [
		["ATK", "attack"],
		["DEF", "defense"],
		["SPD", "speed"],
		["ACC", "accuracy"],
		["EVA", "evasion"],
		["MOV", "move_range"],
		["JMP", "jump"],
	]
	for row in rows:
		var key_lbl := Label.new()
		key_lbl.text = row[0]
		key_lbl.add_color_override("font_color", Color(0.65, 0.65, 0.65))
		grid.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "—"
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val_lbl)
		_stat_vals[row[1]] = val_lbl

	_tween = Tween.new()
	_tween.connect("tween_all_completed", self, "_on_tween_done")
	add_child(_tween)

	hide()


func show_unit(unit) -> void:
	_tween.stop_all()
	if visible:
		# Slide off, swap content, slide back in
		_pending_unit = unit
		_tween.interpolate_property(self, "margin_left",
			margin_left, _rest_margin_left + _slide_offset,
			0.12, Tween.TRANS_QUAD, Tween.EASE_IN)
		_tween.interpolate_property(self, "margin_right",
			margin_right, _rest_margin_right + _slide_offset,
			0.12, Tween.TRANS_QUAD, Tween.EASE_IN)
		_tween.start()
	else:
		# Place off-screen, show, slide in
		_populate(unit)
		margin_left  = _rest_margin_left  + _slide_offset
		margin_right = _rest_margin_right + _slide_offset
		show()
		_slide_in()


func _slide_in() -> void:
	_tween.interpolate_property(self, "margin_left",
		margin_left, _rest_margin_left,
		0.18, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.interpolate_property(self, "margin_right",
		margin_right, _rest_margin_right,
		0.18, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.start()


func _on_tween_done() -> void:
	if _pending_unit != null:
		_populate(_pending_unit)
		_pending_unit = null
		margin_left  = _rest_margin_left  + _slide_offset
		margin_right = _rest_margin_right + _slide_offset
		_slide_in()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		if _tween:
			_tween.stop_all()
		_pending_unit = null
		# Reset margins so next show_unit starts from the correct off-screen position
		margin_left  = _rest_margin_left
		margin_right = _rest_margin_right


func _populate(unit) -> void:
	_bg.color = ALLY_COLOR if unit.team == unit.Team.PLAYER else ENEMY_COLOR

	var img := Image.new()
	img.load(unit.sprite_sheet)
	var crop_rect = PORTRAIT_ALLY_RECT if unit.team == unit.Team.PLAYER else PORTRAIT_ENEMY_RECT
	var crop := img.get_rect(crop_rect)
	var tex := ImageTexture.new()
	tex.create_from_image(crop, 0)
	_portrait.texture = tex

	_name_label.text = unit.unit_name
	_hp_label.text   = "HP  %d / %d" % [unit.hp, unit.max_hp]

	for prop in _stat_vals:
		_stat_vals[prop].text = str(unit.get(prop))
