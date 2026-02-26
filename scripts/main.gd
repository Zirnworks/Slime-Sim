extends Node2D

const GRID_SIZE := 256

var grid: Grid
var renderer: GridRenderer

@onready var grid_display: TextureRect = $GridDisplay
@onready var sim_camera: Camera2D = $SimCamera


func _ready() -> void:
	# Initialize grid
	grid = Grid.new()
	grid.init(GRID_SIZE, GRID_SIZE)

	# Fill with a test pattern to verify rendering
	_fill_test_pattern()

	# Setup renderer
	renderer = GridRenderer.new()
	renderer.setup(grid, grid_display)
	renderer.render()

	# Setup camera
	sim_camera.setup(GRID_SIZE, GRID_SIZE)


func _fill_test_pattern() -> void:
	var w := grid.width
	var h := grid.height
	for y in range(h):
		for x in range(w):
			var idx := y * w + x
			# Checkerboard of different materials
			var block_x: int = x / 32
			var block_y: int = y / 32
			var material_id := (block_x + block_y * 3) % 10
			grid.cell_type[idx] = material_id
