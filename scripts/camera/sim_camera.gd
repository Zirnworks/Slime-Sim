extends Camera2D

const ZOOM_MIN := Vector2(0.3, 0.3)
const ZOOM_MAX := Vector2(8.0, 8.0)
const ZOOM_STEP := 0.15
const PAN_SPEED := 200.0

var _dragging := false

var grid_width: int = 256
var grid_height: int = 256


func setup(gw: int, gh: int, display_scale: int = 2) -> void:
	grid_width = gw
	grid_height = gh
	# No tight limits — let the camera move freely
	limit_left = -10000
	limit_top = -10000
	limit_right = 10000
	limit_bottom = 10000
	# Center on the display
	var world_w := float(gw * display_scale)
	var world_h := float(gh * display_scale)
	position = Vector2(world_w * 0.5, world_h * 0.5)
	# Auto-fit: zoom so the entire grid is visible as a square
	var vp_size := get_viewport_rect().size
	var fit := minf(vp_size.x / world_w, vp_size.y / world_h)
	zoom = Vector2(fit, fit)


func _process(delta: float) -> void:
	# WASD / arrow key panning
	var pan_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_dir.x += 1.0
	if pan_dir != Vector2.ZERO:
		position += pan_dir.normalized() * PAN_SPEED * delta / zoom.x
	# +/- or I/O keys for zoom
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_I):
		_zoom_at(ZOOM_STEP * delta * 3.0)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_O):
		_zoom_at(-ZOOM_STEP * delta * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(-ZOOM_STEP)
			get_viewport().set_input_as_handled()
		# Middle-click OR right-click to pan
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging:
			position -= event.relative / zoom
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# Touchpad two-finger scroll to pan
		position += event.delta * 10.0 / zoom.x
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		# Touchpad pinch to zoom
		_zoom_at((event.factor - 1.0) * 0.5)
		get_viewport().set_input_as_handled()


func _zoom_at(step: float) -> void:
	var mouse_world_before := get_global_mouse_position()
	zoom = (zoom + Vector2(step, step)).clamp(ZOOM_MIN, ZOOM_MAX)
	force_update_scroll()
	var mouse_world_after := get_global_mouse_position()
	position += mouse_world_before - mouse_world_after
