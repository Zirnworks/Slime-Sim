extends Node

var grid: Grid
var camera: Camera2D
var grid_display: TextureRect

var brush_radius: int = 5
var brush_strength: float = 3.0
var is_painting: bool = false
var paint_sign: float = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			paint_sign = 1.0
			if is_painting:
				_paint_at_mouse()
	elif event is InputEventMouseMotion:
		if is_painting:
			_paint_at_mouse()


func _paint_at_mouse() -> void:
	var grid_pos := _screen_to_grid()
	print("Click at grid pos: ", grid_pos)
	if grid_pos.x < 0:
		return
	_paint_attractor(grid_pos.x, grid_pos.y, paint_sign)


func _paint_attractor(gx: int, gy: int, direction: float) -> void:
	var w := grid.width
	var h := grid.height
	var attr := grid.attractor
	for dy in range(-brush_radius, brush_radius + 1):
		for dx in range(-brush_radius, brush_radius + 1):
			var dist_sq := dx * dx + dy * dy
			if dist_sq > brush_radius * brush_radius:
				continue
			var px := gx + dx
			var py := gy + dy
			if px >= 0 and px < w and py >= 0 and py < h:
				var idx := py * w + px
				var dist_factor := 1.0 - sqrt(float(dist_sq)) / float(brush_radius + 1)
				attr[idx] += brush_strength * direction * dist_factor


func _screen_to_grid() -> Vector2i:
	var world_pos := camera.get_global_mouse_position()
	var gx: int = int(floor(world_pos.x))
	var gy: int = int(floor(world_pos.y))
	if gx < 0 or gx >= grid.width or gy < 0 or gy >= grid.height:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)
