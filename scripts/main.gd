extends Node2D

const GRID_SIZE := 256
const NUM_BANDS := 4

var grid: Grid
var renderer: GridRenderer
var city_gen: CityGen
var slime_sim: SlimeSim
var player_input: Node
var hud: CanvasLayer
var current_band: int = 0

@onready var grid_display: TextureRect = $GridDisplay
@onready var sim_camera: Camera2D = $SimCamera


func _ready() -> void:
	# Initialize grid
	grid = Grid.new()
	grid.init(GRID_SIZE, GRID_SIZE)

	# Generate city
	city_gen = CityGen.new()
	city_gen.generate(grid)

	# Clear a landing zone around center and seed slime
	var cx: int = GRID_SIZE >> 1
	var cy: int = GRID_SIZE >> 1
	_clear_area(cx, cy, 15)

	slime_sim = SlimeSim.new()
	slime_sim.grid = grid
	slime_sim.seed_slime(cx, cy, 10, 2.0)

	# Setup renderer
	renderer = GridRenderer.new()
	renderer.setup(grid, grid_display)
	renderer.render()

	# Setup camera
	sim_camera.setup(GRID_SIZE, GRID_SIZE)

	# Setup player input
	player_input = preload("res://scripts/input/player_input.gd").new()
	player_input.grid = grid
	player_input.camera = sim_camera
	add_child(player_input)

	# Setup HUD
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.slime_sim = slime_sim
	add_child(hud)


func _clear_area(cx: int, cy: int, radius: int) -> void:
	var w := grid.width
	var h := grid.height
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var px := cx + dx
				var py := cy + dy
				if px >= 0 and px < w and py >= 0 and py < h:
					var idx := py * w + px
					grid.cell_type[idx] = Materials.CellType.DIRT
					grid.cell_energy[idx] = 1.0


func _physics_process(_delta: float) -> void:
	# Simulate one band per frame
	var band_height: int = GRID_SIZE / NUM_BANDS
	var band_start := current_band * band_height
	var band_end := band_start + band_height

	slime_sim.update_band(band_start, band_end)
	slime_sim.diffuse_trails_band(band_start, band_end)
	slime_sim.decay_attractors_band(band_start, band_end)

	current_band = (current_band + 1) % NUM_BANDS

	# Render
	renderer.render()
