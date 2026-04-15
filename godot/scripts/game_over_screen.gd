extends CanvasLayer

# Reference resolution — the size game-over.png was designed for.
# All highlight/cursor positions are expressed in this space then scaled.
const REF_W = 1408.0
const REF_H = 768.0

# Top-left of each highlight image in reference (1408×768) coordinates.
# Tweak these two constants if YES or NO highlights don't land on the text.
const YES_REF    = Vector2(816, 446)
const NO_REF     = Vector2(961, 444)
const CURSOR_GAP = -10  # negative = cursor overlaps into the highlight (RPG pointer style)

const RES_DIR = "res://assets/overlays/"

var _selection: int = 0  # 0 = YES, 1 = NO

var _dark:   ColorRect  = null
var _bg:     TextureRect = null
var _yes_hl: TextureRect = null
var _no_hl:  TextureRect = null
var _cursor: TextureRect = null


func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()


func _load_tex(fname: String) -> ImageTexture:
	var img = Image.new()
	img.load(RES_DIR + fname)
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex


func _build_ui() -> void:
	# Dark tint behind everything
	_dark = ColorRect.new()
	_dark.color = Color(0, 0, 0, 0.75)
	_dark.anchor_right  = 1.0
	_dark.anchor_bottom = 1.0
	add_child(_dark)

	# Corner decorations — anchored to screen corners at native 320×320 size
	_add_corner("game-over-tl.png", 0.0, 0.0)
	_add_corner("game-over-tr.png", 1.0, 0.0)
	_add_corner("game-over-bl.png", 0.0, 1.0)
	_add_corner("game-over-br.png", 1.0, 1.0)

	# Main overlay — stretched to fill the viewport
	_bg = TextureRect.new()
	_bg.texture       = _load_tex("game-over.png")
	_bg.expand        = true
	_bg.anchor_right  = 1.0
	_bg.anchor_bottom = 1.0
	_bg.stretch_mode  = TextureRect.STRETCH_SCALE
	add_child(_bg)

	# YES / NO highlights
	_yes_hl = _make_tr("yes-highlight.png")
	add_child(_yes_hl)
	_no_hl = _make_tr("no-highlight.png")
	add_child(_no_hl)

	# Cursor
	_cursor = _make_tr("cursor.png")
	add_child(_cursor)


func _add_corner(fname: String, ax: float, ay: float) -> void:
	var tr  = _make_tr(fname)
	var w   = tr.texture.get_width()
	var h   = tr.texture.get_height()
	tr.anchor_left   = ax
	tr.anchor_right  = ax
	tr.anchor_top    = ay
	tr.anchor_bottom = ay
	tr.margin_left   = -w if ax == 1.0 else 0
	tr.margin_right  =  0 if ax == 1.0 else w
	tr.margin_top    = -h if ay == 1.0 else 0
	tr.margin_bottom =  0 if ay == 1.0 else h
	add_child(tr)


func _make_tr(fname: String) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = _load_tex(fname)
	return tr


func _update_selection() -> void:
	var vp = get_viewport().size
	var sx = vp.x / REF_W
	var sy = vp.y / REF_H

	# Scale highlights and cursor to match the stretched background
	_yes_hl.rect_scale = Vector2(sx, sy)
	_no_hl.rect_scale  = Vector2(sx, sy)
	_cursor.rect_scale = Vector2(sx, sy)

	var yes_pos = Vector2(YES_REF.x * sx, YES_REF.y * sy)
	var no_pos  = Vector2(NO_REF.x  * sx, NO_REF.y  * sy)
	var hl_h    = _yes_hl.texture.get_height() * sy
	var cur_w   = _cursor.texture.get_width()  * sx
	var cur_h   = _cursor.texture.get_height() * sy

	_yes_hl.visible      = (_selection == 0)
	_no_hl.visible       = (_selection == 1)
	_yes_hl.rect_position = yes_pos
	_no_hl.rect_position  = no_pos

	var active_pos = yes_pos if _selection == 0 else no_pos
	_cursor.rect_position = Vector2(
		active_pos.x - cur_w - CURSOR_GAP * sx,
		active_pos.y + (hl_h - cur_h) / 2.0
	)


func show_screen(_winner_team: int) -> void:
	_selection = 0
	visible = true
	_update_selection()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed):
		return
	match event.scancode:
		KEY_LEFT:
			_selection = 0
			_update_selection()
			get_tree().set_input_as_handled()
		KEY_RIGHT:
			_selection = 1
			_update_selection()
			get_tree().set_input_as_handled()
		KEY_ENTER:
			_confirm()
			get_tree().set_input_as_handled()


func _confirm() -> void:
	if _selection == 0:  # YES — Try Again
		get_tree().reload_current_scene()
	else:                # NO — Quit
		get_tree().quit()
