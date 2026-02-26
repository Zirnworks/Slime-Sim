class_name CityGen
extends RefCounted

var rng: RandomNumberGenerator


func generate(grid: Grid, seed_val: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var w := grid.width
	var h := grid.height

	# Step 1: Fill everything with dirt
	for i in range(w * h):
		grid.cell_type[i] = Materials.CellType.DIRT
		grid.cell_energy[i] = 1.0

	# Step 2: Lay down road grid
	var road_positions_h: Array[int] = []
	var road_positions_v: Array[int] = []
	_lay_roads(grid, road_positions_h, road_positions_v)

	# Step 3: Fill city blocks with buildings
	_fill_city_blocks(grid, road_positions_h, road_positions_v)

	# Step 4: Scatter parks
	var num_parks := rng.randi_range(4, 10)
	for i in range(num_parks):
		var px := rng.randi_range(10, w - 30)
		var py := rng.randi_range(10, h - 30)
		var pw := rng.randi_range(8, 24)
		var ph := rng.randi_range(8, 24)
		_stamp_rect(grid, px, py, pw, ph, Materials.CellType.ORGANIC)

	# Step 5: Add a river
	if rng.randf() < 0.6:
		_draw_river(grid)


func _lay_roads(grid: Grid, h_roads: Array[int], v_roads: Array[int]) -> void:
	var w := grid.width
	var h := grid.height

	# Horizontal roads
	var y := rng.randi_range(6, 14)
	while y < h - 4:
		h_roads.append(y)
		var road_w := 1 if rng.randf() < 0.6 else 2
		for ry in range(road_w):
			for x in range(w):
				if y + ry < h:
					grid.cell_type[(y + ry) * w + x] = Materials.CellType.ROAD
					grid.cell_energy[(y + ry) * w + x] = 1.0
		var spacing := rng.randi_range(16, 32)
		y += spacing

	# Vertical roads
	var x := rng.randi_range(6, 14)
	while x < w - 4:
		v_roads.append(x)
		var road_w := 1 if rng.randf() < 0.6 else 2
		for rx in range(road_w):
			for yy in range(h):
				if x + rx < w:
					grid.cell_type[yy * w + (x + rx)] = Materials.CellType.ROAD
					grid.cell_energy[yy * w + (x + rx)] = 1.0
		var spacing := rng.randi_range(16, 32)
		x += spacing


func _fill_city_blocks(grid: Grid, h_roads: Array[int], v_roads: Array[int]) -> void:
	# Find rectangular regions between roads and fill with buildings
	var prev_y := 0
	for hy in h_roads:
		var prev_x := 0
		for vx in v_roads:
			# Block bounds: prev_x+1 to vx-1, prev_y+1 to hy-1
			var bx := prev_x + 2
			var by := prev_y + 2
			var bw := vx - prev_x - 3
			var bh := hy - prev_y - 3
			if bw > 3 and bh > 3:
				_fill_block(grid, bx, by, bw, bh)
			prev_x = vx
		prev_y = hy


func _fill_block(grid: Grid, bx: int, by: int, bw: int, bh: int) -> void:
	# Decide what goes in this block
	var roll := rng.randf()
	if roll < 0.1:
		# Vacant lot — leave as dirt
		return
	elif roll < 0.2:
		# Park
		_stamp_rect(grid, bx, by, bw, bh, Materials.CellType.ORGANIC)
		return

	# Fill with buildings
	var cx := bx
	while cx < bx + bw - 2:
		var bld_w := mini(rng.randi_range(4, 10), bx + bw - cx)
		var cy := by
		while cy < by + bh - 2:
			var bld_h := mini(rng.randi_range(4, 10), by + bh - cy)
			if bld_w >= 3 and bld_h >= 3:
				_stamp_building(grid, cx, cy, bld_w, bld_h)
			cy += bld_h + 1
		cx += bld_w + 1


func _stamp_building(grid: Grid, bx: int, by: int, bw: int, bh: int) -> void:
	var w := grid.width
	var h := grid.height
	for y in range(by, mini(by + bh, h)):
		for x in range(bx, mini(bx + bw, w)):
			var idx := y * w + x
			var is_edge_x := (x == bx or x == bx + bw - 1)
			var is_edge_y := (y == by or y == by + bh - 1)

			if is_edge_x and is_edge_y:
				# Corners — concrete
				grid.cell_type[idx] = Materials.CellType.CONCRETE
			elif is_edge_x or is_edge_y:
				# Walls — mix of concrete and glass windows
				if rng.randf() < 0.3:
					grid.cell_type[idx] = Materials.CellType.GLASS
				else:
					grid.cell_type[idx] = Materials.CellType.CONCRETE
			else:
				# Interior — brick
				grid.cell_type[idx] = Materials.CellType.BRICK

			# Some buildings have metal structural beams
			if is_edge_x and is_edge_y and rng.randf() < 0.4:
				grid.cell_type[idx] = Materials.CellType.METAL

			grid.cell_energy[idx] = 1.0


func _draw_river(grid: Grid) -> void:
	var w := grid.width
	var h := grid.height
	var river_width := rng.randi_range(3, 6)

	# Pick direction: horizontal or vertical
	if rng.randf() < 0.5:
		# Horizontal river
		var y := rng.randi_range(h / 4, 3 * h / 4)
		for x in range(w):
			y += rng.randi_range(-1, 1)
			y = clampi(y, river_width, h - river_width - 1)
			for dy in range(-river_width / 2, river_width / 2 + 1):
				var idx := (y + dy) * w + x
				grid.cell_type[idx] = Materials.CellType.WATER
				grid.cell_energy[idx] = 1.0
	else:
		# Vertical river
		var x := rng.randi_range(w / 4, 3 * w / 4)
		for y in range(h):
			x += rng.randi_range(-1, 1)
			x = clampi(x, river_width, w - river_width - 1)
			for dx in range(-river_width / 2, river_width / 2 + 1):
				var idx := y * w + (x + dx)
				grid.cell_type[idx] = Materials.CellType.WATER
				grid.cell_energy[idx] = 1.0


func _stamp_rect(grid: Grid, rx: int, ry: int, rw: int, rh: int, type: int) -> void:
	var w := grid.width
	var h := grid.height
	for y in range(maxi(0, ry), mini(h, ry + rh)):
		for x in range(maxi(0, rx), mini(w, rx + rw)):
			var idx := y * w + x
			grid.cell_type[idx] = type
			grid.cell_energy[idx] = 1.0
