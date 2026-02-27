extends Node2D

const GRID_SIZE := 256
const NUM_BANDS := 4
const DISPLAY_SCALE := 4
const AI_TARGET_INTERVAL := 300  # frames between AI retargeting (~5 sec at 60fps)

var grid: Grid
var renderer: GridRenderer
var city_gen: CityGen
var slime_sim: SlimeSim
var player_input: Node
var hud: CanvasLayer
var entities: EntityManager
var current_band: int = 0
var ai_target_timer: int = 0

@onready var grid_display: TextureRect = $GridDisplay
@onready var sim_camera: Camera2D = $SimCamera


func _ready() -> void:
	# Initialize grid
	grid = Grid.new()
	grid.init(GRID_SIZE, GRID_SIZE)

	# Generate city
	city_gen = CityGen.new()
	city_gen.generate(grid)

	slime_sim = SlimeSim.new()
	slime_sim.grid = grid

	# Seed three slimes at different positions
	var cx: int = GRID_SIZE >> 1
	var cy: int = GRID_SIZE >> 1

	# Green (player) — center
	_clear_area(cx, cy, 15)
	slime_sim.seed_slime(cx, cy, 10, 2.0, 1)

	# Orange (AI) — top-left quadrant
	var ox: int = GRID_SIZE / 4
	var oy: int = GRID_SIZE / 4
	_clear_area(ox, oy, 15)
	slime_sim.seed_slime(ox, oy, 10, 2.0, 2)

	# Blue (AI) — bottom-right quadrant
	var bx: int = GRID_SIZE * 3 / 4
	var by: int = GRID_SIZE * 3 / 4
	_clear_area(bx, by, 15)
	slime_sim.seed_slime(bx, by, 10, 2.0, 3)

	# Setup renderer
	renderer = GridRenderer.new()
	renderer.setup(grid, grid_display)
	renderer.render()

	# Setup camera
	sim_camera.setup(GRID_SIZE, GRID_SIZE, DISPLAY_SCALE)

	# Setup player input
	player_input = preload("res://scripts/input/player_input.gd").new()
	player_input.grid = grid
	player_input.camera = sim_camera
	add_child(player_input)

	# Setup entities
	entities = EntityManager.new()
	entities.init(grid, 20, 35)
	renderer.entities = entities

	# Setup HUD
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.slime_sim = slime_sim
	hud.grid = grid
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
	# AI targeting
	ai_target_timer += 1
	if ai_target_timer >= AI_TARGET_INTERVAL:
		ai_target_timer = 0
		_update_ai_targets()

	# Simulate one band per frame
	var band_height: int = GRID_SIZE / NUM_BANDS
	var band_start := current_band * band_height
	var band_end := band_start + band_height

	entities.update()
	slime_sim.update_band(band_start, band_end)
	slime_sim.diffuse_trails_band(band_start, band_end)
	slime_sim.decay_attractors_band(band_start, band_end, current_band)

	current_band = (current_band + 1) % NUM_BANDS

	# Render
	renderer.render()


func _update_ai_targets() -> void:
	# For each AI slime (owner 2=orange, 3=blue), find a good growth target
	for owner in [2, 3]:
		var best_pos := Vector2i(-1, -1)
		var best_score := -1.0

		# Scan yellow entities: find alive ones with highest density not in our territory
		for i in range(entities.count):
			if entities.alive[i] == 0:
				continue
			if entities.entity_type[i] != EntityManager.TYPE_YELLOW:
				continue

			var ex := int(entities.pos_x[i])
			var ey := int(entities.pos_y[i])
			if ex < 0 or ex >= grid.width or ey < 0 or ey >= grid.height:
				continue

			# Skip if already in our territory
			var eidx := ey * grid.width + ex
			if grid.slime_owner[eidx] == owner:
				continue

			# Score: count nearby yellow dots (cluster density)
			var score := 0.0
			for j in range(entities.count):
				if j == i or entities.alive[j] == 0:
					continue
				if entities.entity_type[j] != EntityManager.TYPE_YELLOW:
					continue
				var dx := entities.pos_x[j] - entities.pos_x[i]
				var dy := entities.pos_y[j] - entities.pos_y[i]
				var dist_sq := dx * dx + dy * dy
				if dist_sq < 900.0:  # within 30 pixels
					score += 1.0

			if score > best_score:
				best_score = score
				best_pos = Vector2i(ex, ey)

		if best_pos.x >= 0:
			grid.set_owner_target(owner, best_pos, 0.8)
		else:
			# Fallback: pick a random frontier cell and target outward
			_set_random_frontier_target(owner)


func _set_random_frontier_target(owner: int) -> void:
	var w := grid.width
	var h := grid.height
	var sm := grid.slime_mass
	var so := grid.slime_owner

	# Sample random cells to find a frontier
	for _attempt in range(50):
		var x := randi_range(2, w - 3)
		var y := randi_range(2, h - 3)
		var idx := y * w + x
		if so[idx] != owner or sm[idx] < 0.5:
			continue
		# Check if frontier (has unowned neighbor)
		var is_frontier := false
		for d in range(4):
			var nx := x + SlimeSim.DIR_X[d]
			var ny := y + SlimeSim.DIR_Y[d]
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				if so[ny * w + nx] != owner:
					is_frontier = true
					break
		if is_frontier:
			# Target outward from center of our blob
			grid.set_owner_target(owner, Vector2i(x, y), 0.6)
			return

	# Last resort: target center of map
	grid.set_owner_target(owner, Vector2i(w / 2, h / 2), 0.3)
