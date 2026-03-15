extends Spatial

# Rotation
const ROTATE_SPEED = 90.0      # degrees per second when holding Q/E
const ROTATE_SNAP  = 45.0      # snap to nearest 45° on key release

# Pan (middle mouse drag)
const PAN_SPEED = 0.05

# Zoom
const ZOOM_SPEED  = 1.5
const ZOOM_MIN    = 4.0
const ZOOM_MAX    = 20.0

onready var _camera: Camera = $Camera

var _yaw: float = 0.0           # current Y rotation in degrees
var _zoom: float = 10.0         # camera arm length
var _panning: bool = false
var _pan_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_apply_camera()


func _process(delta: float) -> void:
	var rotating = false

	if Input.is_action_pressed("rotate_cw"):
		_yaw -= ROTATE_SPEED * delta
		rotating = true
	if Input.is_action_pressed("rotate_ccw"):
		_yaw += ROTATE_SPEED * delta
		rotating = true

	if not rotating:
		# Snap to nearest 45° when key released
		var snapped = round(_yaw / ROTATE_SNAP) * ROTATE_SNAP
		_yaw = lerp(_yaw, snapped, 10.0 * delta)

	rotation_degrees.y = _yaw


func _input(event: InputEvent) -> void:
	# Middle mouse pan
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_MIDDLE:
			_panning = event.pressed
			_pan_origin = event.position

	if event is InputEventMouseMotion and _panning:
		var delta = event.relative * PAN_SPEED
		# Pan along the camera's local X and Z axes
		var right   = -transform.basis.x * delta.x
		var forward =  transform.basis.z * delta.y
		translation += right + forward

	# Scroll zoom
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP:
			_zoom = clamp(_zoom - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			_apply_camera()
		elif event.button_index == BUTTON_WHEEL_DOWN:
			_zoom = clamp(_zoom + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			_apply_camera()


# Reposition the Camera child to sit at `_zoom` distance along its current arm
func _apply_camera() -> void:
	if _camera:
		_camera.transform.origin = Vector3(0, _zoom * 0.5, _zoom)
