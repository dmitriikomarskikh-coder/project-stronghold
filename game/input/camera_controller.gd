extends RefCounted

const CAMERA_SPEED := 900.0
const EDGE_SIZE := 16
const ZOOM_LEVELS := [Vector2(1.0, 1.0), Vector2(0.75, 0.75), Vector2(0.5, 0.5)]

var _camera: Camera2D
var _bounds := Rect2()
var _zoom_index := 1
var _dragging := false
var _last_mouse := Vector2.ZERO

func setup(camera: Camera2D, bounds: Rect2) -> void:
	_camera = camera
	_bounds = bounds
	_camera.zoom = ZOOM_LEVELS[_zoom_index]
	_clamp_camera()

func update(delta: float) -> void:
	if _camera == null:
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	var mouse := _camera.get_viewport().get_mouse_position()
	var viewport_size := _camera.get_viewport_rect().size
	if mouse.x <= EDGE_SIZE:
		direction.x -= 1.0
	elif mouse.x >= viewport_size.x - EDGE_SIZE:
		direction.x += 1.0
	if mouse.y <= EDGE_SIZE:
		direction.y -= 1.0
	elif mouse.y >= viewport_size.y - EDGE_SIZE:
		direction.y += 1.0

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		if not _dragging:
			_dragging = true
			_last_mouse = mouse
		else:
			_camera.position -= (mouse - _last_mouse) / _camera.zoom
			_last_mouse = mouse
	else:
		_dragging = false

	if direction != Vector2.ZERO:
		_camera.position += direction.normalized() * CAMERA_SPEED * delta / _camera.zoom.x
	_clamp_camera()

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_index = max(0, _zoom_index - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_index = min(ZOOM_LEVELS.size() - 1, _zoom_index + 1)
		_camera.zoom = ZOOM_LEVELS[_zoom_index]
		_clamp_camera()

func _clamp_camera() -> void:
	_camera.position.x = clamp(_camera.position.x, _bounds.position.x, _bounds.end.x)
	_camera.position.y = clamp(_camera.position.y, _bounds.position.y, _bounds.end.y)
