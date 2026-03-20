extends Spatial

# Rotation — 90° snaps give four cardinal isometric positions (SW, NW, NE, SE)
const ROTATE_STEP  = 90.0
const ROTATE_SPEED = 10.0

# Orthographic zoom levels (camera size = vertical world-units visible)
const ZOOM_LEVELS = [7.0, 10.0, 14.0]

# True isometric elevation: arctan(1/sqrt(2)) ≈ 35.264° — all axes equally foreshortened
const ELEVATION_DEG = 35.264
const CAMERA_ARM    = 20.0  # arm length; only affects near/far depth, not zoom

onready var _camera: Camera = $Camera

var _yaw: float = 45.0         # current Y rotation in degrees
var _target_yaw: float = 45.0  # snapped target we are smoothly rotating toward
var _zoom_index: int = 1      # start at second level (10.0)


func _ready() -> void:
	_apply_camera()


func _process(delta: float) -> void:
	_yaw = lerp(_yaw, _target_yaw, ROTATE_SPEED * delta)
	rotation_degrees.y = _yaw


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.scancode:
			KEY_D:
				_target_yaw += ROTATE_STEP
			KEY_A:
				_target_yaw -= ROTATE_STEP
			KEY_W:
				_zoom_index = max(0, _zoom_index - 1)
				_apply_camera()
			KEY_S:
				_zoom_index = min(ZOOM_LEVELS.size() - 1, _zoom_index + 1)
				_apply_camera()


# Position the Camera child at the isometric elevation angle and set orthographic zoom.
func _apply_camera() -> void:
	if not _camera:
		return
	var elev_rad := deg2rad(ELEVATION_DEG)
	_camera.projection    = Camera.PROJECTION_ORTHOGONAL
	_camera.size          = ZOOM_LEVELS[_zoom_index]
	_camera.transform.origin = Vector3(
		0.0,
		CAMERA_ARM * sin(elev_rad),
		CAMERA_ARM * cos(elev_rad)
	)
	_camera.rotation_degrees = Vector3(-ELEVATION_DEG, 0.0, 0.0)
