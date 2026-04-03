extends Control

const CELL  = 32   # pixels per grid cell
const SCALE = 2    # display magnification (2× on 64px frames = 128px on screen)

const CHARACTERS = [
	{"name": "Krel",   "path": "res://assets/sprites/krel.png"},
	{"name": "Dunar",  "path": "res://assets/sprites/dunar.png"},
	{"name": "Seriph", "path": "res://assets/sprites/seriph.png"},
	{"name": "Kori",   "path": "res://assets/sprites/kori.png"},
]

# Coordinate reference (all values in pixels, derived from sprites-simple.md):
#
#   Sheet: 1024×1024,  cell: 32×32
#
#   Row groups (y = row_index × 32):
#     SW walk + attack  y=32   h=160   rows 2-6
#     NW walk + attack  y=192  h=160   rows 7-11
#     Defensive/victory y=352  h=160   rows 12-16  (SW+NW in same band, diff x)
#     Weary SW+flying   y=512  h=160   rows 17-21
#     Weary NW+flying   y=672  h=160   rows 22-26
#     Weak/defeated     y=864  h=128   rows 28-31  (SW+NW in same band, diff x)
#     Portrait          y=0    h=288   top-right x=800 w=224
#
#   x offsets within walk+attack band:
#     Raise Hands  x=32  w=64
#     Walk L-foot  x=128 w=64
#     Walk together x=224 w=64
#     Walk R-foot  x=320 w=64
#     Attack prep  x=416 w=96
#     Attack strike x=544 w=96
#     Attack follow x=672 w=96
#
#   x offsets in defensive/victory band (same for both rows):
#     Defensive SW x=32  NW x=128  Victory SW x=224  NW x=320   all w=64
#
#   x offsets in weary band:
#     Weary 1 x=32  Weary 2 x=128  Weary 3 x=224   all w=64
#     Flying 1 x=448  Flying 2 x=608  Flying 3 x=768  all w=160  (seriph only)
#
#   x offsets in weak/defeated band:
#     Weak SW x=32  Weak NW x=128  Defeated SW x=224  Defeated NW x=320  all w=64

# State format: name, y_sw, y_nw, h, sw [[x,w],...], nw [[x,w],...], fps
# y_sw == y_nw when SW and NW share the same row band (diff x).
const STATES = [
	{"name": "Walk",
		"y_sw": 32,  "y_nw": 192, "h": 160,
		"sw": [[128,64],[224,64],[320,64],[224,64]],
		"nw": [[128,64],[224,64],[320,64],[224,64]], "fps": 2.0},

	{"name": "Raise Hands",
		"y_sw": 32,  "y_nw": 192, "h": 160,
		"sw": [[32,64]], "nw": [[32,64]], "fps": 0.0},

	{"name": "Attack",
		"y_sw": 32,  "y_nw": 192, "h": 160,
		"sw": [[416,96],[544,96],[672,96]],
		"nw": [[416,96],[544,96],[672,96]], "fps": 2.0},

	{"name": "Defensive",
		"y_sw": 352, "y_nw": 352, "h": 160,
		"sw": [[32,64]], "nw": [[128,64]], "fps": 0.0},

	{"name": "Victory",
		"y_sw": 352, "y_nw": 352, "h": 160,
		"sw": [[224,64]], "nw": [[320,64]], "fps": 0.0},

	{"name": "Weary",
		"y_sw": 512, "y_nw": 672, "h": 160,
		"sw": [[32,64],[128,64],[224,64],[128,64]],
		"nw": [[32,64],[128,64],[224,64],[128,64]], "fps": 2.0},

	{"name": "Flying (Seriph only)",
		"y_sw": 512, "y_nw": 672, "h": 160,
		"sw": [[448,160],[608,160],[768,160]],
		"nw": [[448,160],[608,160],[768,160]], "fps": 2.0},

	{"name": "Weak (one knee)",
		"y_sw": 864, "y_nw": 864, "h": 128,
		"sw": [[32,64]], "nw": [[128,64]], "fps": 0.0},

	{"name": "Defeated",
		"y_sw": 864, "y_nw": 864, "h": 128,
		"sw": [[224,64]], "nw": [[320,64]], "fps": 0.0},

	{"name": "Portrait",
		"y_sw": 0,   "y_nw": 0,   "h": 288,
		"sw": [[800,224]], "nw": [], "fps": 0.0},
]

const PANEL_W   = 220.0
const SW_CX     = 450.0
const NW_CX     = 800.0
const SPRITE_CY = 330.0

var _tex: ImageTexture
var _current_char:  int = 0
var _current_state: int = 0
var _current_frame: int = 0
var _anim_time:     float = 0.0
var _is_animating:  bool = false

var _label_state_name: Label
var _label_frame_info: Label
var _label_sw_coords:  Label
var _label_nw_coords:  Label
var _btn_prev: Button
var _btn_next: Button
var _state_buttons:   Array = []
var _char_buttons:    Array = []
var _highlighted_btn: Button = null


func _ready() -> void:
	_build_ui()
	_load_char(0)
	_show_state(0)


func _load_char(idx: int) -> void:
	_current_char = idx
	var path = CHARACTERS[idx].path
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		_tex = null
		return
	_tex = ImageTexture.new()
	_tex.create_from_image(img, 0)  # nearest-neighbour

	# Update character button highlights
	for i in _char_buttons.size():
		_char_buttons[i].add_color_override("font_color",
			Color(1, 0.8, 0.2) if i == idx else Color(1, 1, 1))
	update()


func _process(delta: float) -> void:
	if not _is_animating:
		return
	var state = STATES[_current_state]
	_anim_time += delta
	var num_frames = max(state.sw.size(), state.nw.size())
	_current_frame = int(_anim_time * state.fps) % int(max(num_frames, 1))
	_refresh_info()
	update()


func _draw() -> void:
	draw_rect(Rect2(PANEL_W, 0.0, rect_size.x - PANEL_W, rect_size.y), Color(0.15, 0.15, 0.15))
	if not _tex:
		var msg := Label.new()  # Can't draw text in _draw; handled via label below
		return

	var state = STATES[_current_state]
	var sw_frames = state.sw.size()
	var nw_frames = state.nw.size()
	var frame = _current_frame

	# SW sprite
	if sw_frames > 0:
		var f  = state.sw[min(frame, sw_frames - 1)]
		var fw = f[1]
		var fh = state.h
		var dest = Rect2(SW_CX - fw * SCALE * 0.5, SPRITE_CY - fh * SCALE * 0.5,
			fw * SCALE, fh * SCALE)
		draw_texture_rect_region(_tex, dest, Rect2(f[0], state.y_sw, fw, fh))
		draw_rect(dest, Color(0.4, 0.4, 0.4), false)

	# NW sprite
	if nw_frames > 0:
		var f  = state.nw[min(frame, nw_frames - 1)]
		var fw = f[1]
		var fh = state.h
		var dest = Rect2(NW_CX - fw * SCALE * 0.5, SPRITE_CY - fh * SCALE * 0.5,
			fw * SCALE, fh * SCALE)
		draw_texture_rect_region(_tex, dest, Rect2(f[0], state.y_nw, fw, fh))
		draw_rect(dest, Color(0.4, 0.4, 0.4), false)


func _build_ui() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	# ── Left panel: state list ──────────────────────────────────────────────────
	var panel = PanelContainer.new()
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.margin_right  = PANEL_W
	add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var header = Label.new()
	header.text  = "States"
	header.align = Label.ALIGN_CENTER
	vbox.add_child(header)

	for i in STATES.size():
		var btn = Button.new()
		btn.text                  = STATES[i].name
		btn.align                 = Button.ALIGN_LEFT
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.connect("pressed", self, "_on_state_btn", [i])
		vbox.add_child(btn)
		_state_buttons.append(btn)

	# ── Character picker ────────────────────────────────────────────────────────
	var char_lbl = _lbl("Character:", PANEL_W + 20, 12, 120, 20)
	char_lbl.add_color_override("font_color", Color(0.7, 0.7, 0.7))

	var char_hbox = HBoxContainer.new()
	char_hbox.rect_position = Vector2(PANEL_W + 20, 36)
	char_hbox.add_constant_override("separation", 6)
	add_child(char_hbox)

	for i in CHARACTERS.size():
		var btn = Button.new()
		btn.text = CHARACTERS[i].name
		btn.connect("pressed", self, "_on_char_btn", [i])
		char_hbox.add_child(btn)
		_char_buttons.append(btn)

	# ── State info labels ───────────────────────────────────────────────────────
	_label_state_name = _lbl("", PANEL_W + 20, 72, 600, 28)

	var h_sw = _lbl("SW", SW_CX - 20, 110, 40, 20)
	h_sw.align = Label.ALIGN_CENTER
	var h_nw = _lbl("NW", NW_CX - 20, 110, 40, 20)
	h_nw.align = Label.ALIGN_CENTER

	_label_sw_coords  = _lbl("", PANEL_W + 20,  500, 400, 20)
	_label_nw_coords  = _lbl("", PANEL_W + 20,  520, 400, 20)
	_label_frame_info = _lbl("", PANEL_W + 20,  540, 300, 20)

	var hbox = HBoxContainer.new()
	hbox.rect_position = Vector2(PANEL_W + 20, 565)
	add_child(hbox)

	_btn_prev = Button.new()
	_btn_prev.text = "< Prev"
	_btn_prev.connect("pressed", self, "_on_prev_frame")
	hbox.add_child(_btn_prev)

	_btn_next = Button.new()
	_btn_next.text = "Next >"
	_btn_next.connect("pressed", self, "_on_next_frame")
	hbox.add_child(_btn_next)

	var back = Button.new()
	back.text = "Back to Game"
	back.connect("pressed", self, "_on_back")
	hbox.add_child(back)


func _lbl(text: String, x: float, y: float, w: float, h: float) -> Label:
	var lbl = Label.new()
	lbl.text          = text
	lbl.rect_position = Vector2(x, y)
	lbl.rect_size     = Vector2(w, h)
	add_child(lbl)
	return lbl


func _show_state(idx: int) -> void:
	if _highlighted_btn != null:
		_highlighted_btn.add_color_override("font_color", Color(1, 1, 1))
	_highlighted_btn = _state_buttons[idx]
	_highlighted_btn.add_color_override("font_color", Color(1, 0.8, 0.2))

	_current_state = idx
	_current_frame = 0
	_anim_time     = 0.0
	_is_animating  = STATES[idx].fps > 0.0

	_label_state_name.text = STATES[idx].name
	_refresh_info()
	update()


func _refresh_info() -> void:
	var state      = STATES[_current_state]
	var sw_frames  = state.sw.size()
	var nw_frames  = state.nw.size()
	var num_frames = max(sw_frames, nw_frames)
	var frame      = min(_current_frame, num_frames - 1)

	if sw_frames > 0:
		var f = state.sw[min(frame, sw_frames - 1)]
		_label_sw_coords.text = "SW: Rect2(%d, %d, %d, %d)" % [f[0], state.y_sw, f[1], state.h]
	else:
		_label_sw_coords.text = "SW: —"

	if nw_frames > 0:
		var f = state.nw[min(frame, nw_frames - 1)]
		_label_nw_coords.text = "NW: Rect2(%d, %d, %d, %d)" % [f[0], state.y_nw, f[1], state.h]
	else:
		_label_nw_coords.text = "NW: —"

	_label_frame_info.text = "Frame %d / %d" % [frame + 1, num_frames]
	var show_nav = not _is_animating and num_frames > 1
	_btn_prev.visible = show_nav
	_btn_next.visible = show_nav


func _on_char_btn(idx: int) -> void:
	_load_char(idx)


func _on_state_btn(idx: int) -> void:
	_show_state(idx)


func _on_prev_frame() -> void:
	var state      = STATES[_current_state]
	var num_frames = max(state.sw.size(), state.nw.size())
	_current_frame = (_current_frame - 1 + num_frames) % num_frames
	_refresh_info()
	update()


func _on_next_frame() -> void:
	var state      = STATES[_current_state]
	var num_frames = max(state.sw.size(), state.nw.size())
	_current_frame = (_current_frame + 1) % num_frames
	_refresh_info()
	update()


func _on_back() -> void:
	get_tree().change_scene("res://main.tscn")
