extends Control

const NUM_DROPS  = 250
const DROP_SPEED = 550.0   # pixels per second
const LEAN       = -0.12   # horizontal drift per vertical pixel

var _time:  float = 0.0
var _drops: Array = []     # pre-generated: {x, y, speed, length, alpha}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_margins_preset(PRESET_WIDE)
	visible = false

	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in NUM_DROPS:
		_drops.append({
			"x":      rng.randf(),
			"y":      rng.randf(),
			"speed":  0.65 + rng.randf() * 0.7,
			"length": 14 + rng.randi() % 22,
			"alpha":  0.35 + rng.randf() * 0.45,
		})


func _process(delta: float) -> void:
	_time += delta
	update()


func _draw() -> void:
	var sz = get_viewport_rect().size

	# Dark tint
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.08, 0.18, 0.28))

	# Extend x spawn range rightward so drops lean into the bottom-right corner
	var overflow = sz.y * abs(LEAN) + 20.0

	# Rain streaks
	for drop in _drops:
		var y    = fmod(drop.y * sz.y + _time * DROP_SPEED * drop.speed, sz.y)
		var x    = drop.x * (sz.x + overflow) + y * LEAN
		var dy   = float(drop.length)
		var from = Vector2(x,             y)
		var to   = Vector2(x + dy * LEAN, y + dy)
		draw_line(from, to, Color(0.72, 0.80, 0.92, drop.alpha), 1.0)
