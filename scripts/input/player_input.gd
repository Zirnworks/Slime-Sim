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
		grid.target_pos = grid_pos
		grid.has_target = true
		grid.target_strength = 1.0


func _screen_to_grid() -> Vector2i:
	var world_pos := camera.get_global_mouse_position()
	var gx: int = int(floor(world_pos.x))
	var gy: int = int(floor(world_pos.y))
	if gx < 0 or gx >= grid.width or gy < 0 or gy >= grid.height:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)
