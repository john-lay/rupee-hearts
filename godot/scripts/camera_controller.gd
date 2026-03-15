extends Spatial

# Rotation
const ROTATE_STEP  = 45.0   # degrees per key press
const ROTATE_SPEED = 10.0   # lerp speed toward target

# Zoom levels (arm length): close → far
const ZOOM_LEVELS = [9.0, 10.0, 15.0, 22.0]

onready var _camera: Camera = $Camera

var _yaw: float = 0.0         # current Y rotation in degrees
var _target_yaw: float = 0.0  # snapped target we are smoothly rotating toward
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


# Reposition the Camera child along its arm using the current zoom level
func _apply_camera() -> void:
	if _camera:
		var z = ZOOM_LEVELS[_zoom_index]
		_camera.transform.origin = Vector3(0, z * 0.5, z)
