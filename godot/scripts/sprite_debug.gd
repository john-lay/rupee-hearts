extends Control

const SHEET_PATH = "res://assets/sprites/soldier.png"
const SCALE      = 5   # display magnification (5× = 80px for a 16px-wide frame)

# Y offsets and heights are pixel positions within one macro cell (344×352, 8px tiles).
# Allied macro cell sits at sheet position (0, 0) so these are also sheet-absolute for allied.
#
# Each entry:  name, y, h, sw [[x,w],...], nw [[x,w],...], fps (0 = static)
const STATES = [
	# ── Section 1: Walk shadowed (4-row, y=8, h=32) ────────────────────────────
	{"name": "Walk (shadowed)",      "y":  4, "h": 32,
		"sw": [[32,16],[56,16],[80,16],[56,16]],  "nw": [[128,16],[152,16],[176,16],[152,16]], "fps": 2.0},
	{"name": "Defending (shadowed)", "y":  4, "h": 32,
		"sw": [[200,16]],                         "nw": [[224,16]],                            "fps": 0.0},

	# ── Section 2: Misc unshadowed (5-row, y=48, h=40) ─────────────────────────
	{"name": "Walk",                 "y": 52, "h": 32,
		"sw": [[32,16],[56,16],[80,16],[56,16]],  "nw": [[128,16],[152,16],[176,16],[152,16]], "fps": 2.0},
	{"name": "Raise Hands",          "y": 52, "h": 32,
		"sw": [[8,16]],                           "nw": [[104,16]],                            "fps": 0.0},
	{"name": "Defending",            "y": 52, "h": 32,
		"sw": [[200,16]],                         "nw": [[224,16]],                            "fps": 0.0},
	{"name": "Victory",              "y": 52, "h": 32,
		"sw": [[248,16]],                 "nw": [[272,16]],                   "fps": 0.0},
	{"name": "Afflicted",            "y": 48, "h": 40,
		"sw": [[296,16]],                 "nw": [[320,16]],                   "fps": 0.0},

	# ── Section 3: Shallow water walk (4-row, y=96, h=32) ──────────────────────
	{"name": "Walk (shallow)",          "y": 96, "h": 32,
		"sw": [[32,16],[56,16],[80,16],[56,16]],  "nw": [[128,16],[152,16],[176,16],[152,16]], "fps": 2.0},
	{"name": "Raise Hands (shallow)",   "y": 96, "h": 32,
		"sw": [[8,16]],                           "nw": [[104,16]],                            "fps": 0.0},
	{"name": "Defending (shallow)",     "y": 96, "h": 32,
		"sw": [[200,16]],                         "nw": [[224,16]],                            "fps": 0.0},

	# ── Section 4: Water / fallen (4-row, y=184, h=32) ─────────────────────────
	{"name": "Afflicted (shallow)",  "y": 178, "h": 32,
		"sw": [[8,16]],                   "nw": [[32,16]],                    "fps": 0.0},
	{"name": "Walk (deep water)",    "y": 176, "h": 32,
		"sw": [[56,16],[80,16]],          "nw": [[104,16],[128,16]],          "fps": 2.0},
	{"name": "Fallen (shallow)",     "y": 184, "h": 32,
		"sw": [[152,16],[200,16]],        "nw": [[176,16],[224,16]],          "fps": 2.0},

	# ── Section 5: Damage / critical / fallen (4-row, y=224, h=32) ─────────────
	{"name": "Taking Damage",        "y": 212, "h": 32,
		"sw": [[8,16]],                   "nw": [[32,16]],                    "fps": 0.0},
	{"name": "Critical (shadow)",    "y": 214, "h": 32,
		"sw": [[56,16]],                  "nw": [[80,16]],                    "fps": 0.0},
	{"name": "Fallen (shadowed)",    "y": 218, "h": 32,
		"sw": [[104,16]],                 "nw": [[128,16]],                   "fps": 0.0},

	# ── Section 6: Attack (4-row, y=272, h=32) — wind-up & strike are 24px wide ─
	{"name": "Attack",               "y": 262, "h": 32,
		"sw": [[12,24],[42,24],[74,24]],  "nw": [[116,24],[146,24],[178,24]], "fps": 2.0},

	# ── Section 7: Weary / misc (y=311, h=32) ───────────────────────────────────
	{"name": "Weary",                "y": 309, "h": 32,
		"sw": [[8,16],[32,16],[8,16],[56,16]],    "nw": [[80,16],[104,16],[80,16],[128,16]], "fps": 2.0},
	{"name": "Defending (weary)",    "y": 309, "h": 32,
		"sw": [[152,16]],                 "nw": [[176,16]],                   "fps": 0.0},
	{"name": "Offering",             "y": 309, "h": 32,
		"sw": [[200,16]],                 "nw": [[224,16]],                   "fps": 0.0},
]

# Layout constants
const PANEL_W  = 220.0
const SW_CX    = 370.0   # SW sprite screen-centre X
const NW_CX    = 660.0   # NW sprite screen-centre X
const SPRITE_CY = 260.0  # sprite centre Y

var _tex: ImageTexture
var _current_state: int  = 0
var _current_frame: int  = 0
var _anim_time:     float = 0.0
var _is_animating:  bool  = false

var _label_state_name: Label
var _label_frame_info: Label
var _label_sw_coords:  Label
var _label_nw_coords:  Label
var _btn_prev: Button
var _btn_next: Button
var _state_buttons = []
var _highlighted_btn: Button = null


func _ready() -> void:
	_load_texture()
	_build_ui()
	_show_state(0)


func _load_texture() -> void:
	var img = Image.new()
	img.load(SHEET_PATH)
	_tex = ImageTexture.new()
	_tex.create_from_image(img, 0)  # flags=0: no mipmaps, no filter → nearest-neighbour


func _process(delta: float) -> void:
	if not _is_animating:
		return
	var state = STATES[_current_state]
	_anim_time += delta
	_current_frame = int(_anim_time * state.fps) % state.sw.size()
	_refresh_info()
	update()


func _draw() -> void:
	if not _tex:
		return
	# Dark background for sprite area
	draw_rect(Rect2(PANEL_W, 0.0, rect_size.x - PANEL_W, rect_size.y), Color(0.15, 0.15, 0.15))

	var state  = STATES[_current_state]
	var frame  = min(_current_frame, state.sw.size() - 1)

	# SW sprite
	if state.sw.size() > 0:
		var f    = state.sw[min(frame, state.sw.size() - 1)]
		var fw   = f[1]
		var fh   = state.h
		var dest = Rect2(SW_CX - fw * SCALE * 0.5, SPRITE_CY - fh * SCALE * 0.5, fw * SCALE, fh * SCALE)
		draw_texture_rect_region(_tex, dest, Rect2(f[0], state.y, fw, fh))
		draw_rect(dest, Color(0.4, 0.4, 0.4), false)  # frame outline

	# NW sprite
	if state.nw.size() > 0:
		var f    = state.nw[min(frame, state.nw.size() - 1)]
		var fw   = f[1]
		var fh   = state.h
		var dest = Rect2(NW_CX - fw * SCALE * 0.5, SPRITE_CY - fh * SCALE * 0.5, fw * SCALE, fh * SCALE)
		draw_texture_rect_region(_tex, dest, Rect2(f[0], state.y, fw, fh))
		draw_rect(dest, Color(0.4, 0.4, 0.4), false)


func _build_ui() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	# ── Left panel: scrollable state list ──────────────────────────────────────
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

	# ── Right panel labels ─────────────────────────────────────────────────────
	_label_state_name = _lbl("", PANEL_W + 20, 10, 600, 28)

	# Column headers
	var h_sw = _lbl("SW", SW_CX - 20, 80, 40, 20)
	h_sw.align = Label.ALIGN_CENTER
	var h_nw = _lbl("NW", NW_CX - 20, 80, 40, 20)
	h_nw.align = Label.ALIGN_CENTER

	# Coord readouts
	_label_sw_coords = _lbl("", PANEL_W + 20,  430, 300, 20)
	_label_nw_coords = _lbl("", PANEL_W + 340, 430, 300, 20)

	# Frame counter
	_label_frame_info = _lbl("", PANEL_W + 20, 460, 300, 20)

	# Frame navigation (hidden for animated / single-frame states)
	var hbox = HBoxContainer.new()
	hbox.rect_position = Vector2(PANEL_W + 20, 490)
	add_child(hbox)

	_btn_prev = Button.new()
	_btn_prev.text = "< Prev"
	_btn_prev.connect("pressed", self, "_on_prev_frame")
	hbox.add_child(_btn_prev)

	_btn_next = Button.new()
	_btn_next.text = "Next >"
	_btn_next.connect("pressed", self, "_on_next_frame")
	hbox.add_child(_btn_next)

	# Back to game
	var back = Button.new()
	back.rect_position = Vector2(PANEL_W + 20, 550)
	back.rect_size     = Vector2(150, 30)
	back.text          = "Back to Game"
	back.connect("pressed", self, "_on_back")
	add_child(back)


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
	var state     = STATES[_current_state]
	var num_frames = state.sw.size()
	var frame     = min(_current_frame, num_frames - 1)

	if state.sw.size() > 0:
		var f = state.sw[min(frame, state.sw.size() - 1)]
		_label_sw_coords.text = "SW: Rect2(%d, %d, %d, %d)" % [f[0], state.y, f[1], state.h]
	else:
		_label_sw_coords.text = "SW: —"

	if state.nw.size() > 0:
		var f = state.nw[min(frame, state.nw.size() - 1)]
		_label_nw_coords.text = "NW: Rect2(%d, %d, %d, %d)" % [f[0], state.y, f[1], state.h]
	else:
		_label_nw_coords.text = "NW: —"

	_label_frame_info.text = "Frame %d / %d" % [frame + 1, num_frames]
	var show_nav = not _is_animating and num_frames > 1
	_btn_prev.visible = show_nav
	_btn_next.visible = show_nav


func _on_state_btn(idx: int) -> void:
	_show_state(idx)


func _on_prev_frame() -> void:
	var n = STATES[_current_state].sw.size()
	_current_frame = (_current_frame - 1 + n) % n
	_refresh_info()
	update()


func _on_next_frame() -> void:
	var n = STATES[_current_state].sw.size()
	_current_frame = (_current_frame + 1) % n
	_refresh_info()
	update()


func _on_back() -> void:
	get_tree().change_scene("res://main.tscn")
