extends Node

var grid: Grid
var camera: Camera2D
var is_dragging: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if is_dragging:
				_set_target()
	elif event is InputEventMouseMotion:
		if is_dragging:
			_set_target()


func _set_target() -> void:
	var grid_pos := _screen_to_grid()
	if grid_pos.x >= 0:
		grid.set_owner_target(1, grid_pos, 1.0)  # owner 1 = green (player)


func _screen_to_grid() -> Vector2i:
	var world_pos := camera.get_global_mouse_position()
	# World is 2x grid (each cell = 2x2 world units)
	var gx: int = int(floor(world_pos.x / 2.0))
	var gy: int = int(floor(world_pos.y / 2.0))
	if gx < 0 or gx >= grid.width or gy < 0 or gy >= grid.height:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)
