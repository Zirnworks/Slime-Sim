class_name EntityManager
extends RefCounted

const TYPE_RED := 0
const TYPE_YELLOW := 1

# Tuning
const RED_SPEED := 0.4
const YELLOW_SPEED := 0.3
const RED_ATTACK := 0.2          # slime mass removed per tick per cell
const RED_OVERWHELM := 25.0      # surrounding slime mass to kill red
const BURN_DEPOSIT := 0.8        # burn intensity on active attack
const BURN_TRAIL := 0.15         # light burn trail when moving (no slime)
const BURN_RADIUS := 3           # fire area of effect radius
const YELLOW_BOOST := 0.2        # growth velocity boost per yellow consumed
const RESPAWN_DELAY := 180       # frames (~3 sec at 60fps)
const SENSE_RADIUS := 15         # red dot slime sensing range
const CLUSTER_SPREAD := 15.0     # how far entities spawn from cluster center

# Cardinal directions
const DIR_X: Array[int] = [1, -1, 0, 0]
const DIR_Y: Array[int] = [0, 0, 1, -1]

# Parallel arrays
var pos_x: PackedFloat32Array
var pos_y: PackedFloat32Array
var vel_x: PackedFloat32Array
var vel_y: PackedFloat32Array
var entity_type: PackedByteArray
var alive: PackedByteArray
var is_stationary: PackedByteArray
var move_dir: PackedByteArray     # cardinal direction (0-3) for road-following
var respawn_timer: PackedFloat32Array
var dir_timer: PackedFloat32Array
var count: int = 0

var grid: Grid
var road_cells: Array[Vector2i]
var building_cells: Array[Vector2i]


func init(g: Grid, num_red: int, num_yellow: int) -> void:
	grid = g
	count = num_red + num_yellow

	pos_x = PackedFloat32Array()
	pos_x.resize(count)
	pos_y = PackedFloat32Array()
	pos_y.resize(count)
	vel_x = PackedFloat32Array()
	vel_x.resize(count)
	vel_y = PackedFloat32Array()
	vel_y.resize(count)
	entity_type = PackedByteArray()
	entity_type.resize(count)
	alive = PackedByteArray()
	alive.resize(count)
	is_stationary = PackedByteArray()
	is_stationary.resize(count)
	is_stationary.fill(0)
	move_dir = PackedByteArray()
	move_dir.resize(count)
	respawn_timer = PackedFloat32Array()
	respawn_timer.resize(count)
	dir_timer = PackedFloat32Array()
	dir_timer.resize(count)

	# Cache cell positions by type
	_collect_cells()

	# Assign types
	for i in range(count):
		entity_type[i] = TYPE_RED if i < num_red else TYPE_YELLOW
		alive[i] = 1

	# Spawn red in 3-4 clusters away from center
	_spawn_red_clusters(0, num_red)

	# Spawn yellow: ~80% on roads as cars, ~20% stationary in buildings
	var num_stationary := mini(7, num_yellow / 4)
	var num_mobile := num_yellow - num_stationary
	_spawn_yellow_cars(num_red, num_mobile)
	_spawn_yellow_stationary(num_red + num_mobile, num_stationary)


func _collect_cells() -> void:
	road_cells = []
	building_cells = []
	var w := grid.width
	var h := grid.height
	var ct := grid.cell_type
	for y in range(h):
		var row := y * w
		for x in range(w):
			var t: int = ct[row + x]
			if t == Materials.CellType.ROAD:
				road_cells.append(Vector2i(x, y))
			elif t == Materials.CellType.BRICK or t == Materials.CellType.CONCRETE:
				building_cells.append(Vector2i(x, y))
	road_cells.shuffle()
	building_cells.shuffle()


func _spawn_red_clusters(start: int, count_red: int) -> void:
	var w := grid.width
	var h := grid.height
	var cx := w / 2.0
	var cy := h / 2.0
	var num_clusters := 4
	var centers: Array[Vector2] = []

	for _c in range(num_clusters):
		for _attempt in range(30):
			var px := randf_range(20.0, float(w - 20))
			var py := randf_range(20.0, float(h - 20))
			if sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy)) < 50.0:
				continue
			var too_close := false
			for existing in centers:
				if existing.distance_to(Vector2(px, py)) < 30.0:
					too_close = true
					break
			if not too_close:
				centers.append(Vector2(px, py))
				break

	if centers.is_empty():
		centers.append(Vector2(30, 30))

	for i in range(count_red):
		var center := centers[i % centers.size()]
		_spawn_near(start + i, center, false)


func _spawn_yellow_cars(start: int, count_mobile: int) -> void:
	if road_cells.is_empty():
		return
	var num_clusters := 6
	var centers: Array[Vector2i] = []

	for rc in road_cells:
		var too_close := false
		for existing in centers:
			if rc.distance_to(existing) < 25.0:
				too_close = true
				break
		if not too_close:
			centers.append(rc)
			if centers.size() >= num_clusters:
				break

	if centers.is_empty():
		centers.append(road_cells[0])

	for j in range(count_mobile):
		var i := start + j
		var center := centers[j % centers.size()]
		_spawn_on_road_near(i, center)
		is_stationary[i] = 0
		move_dir[i] = randi() % 4
		_set_cardinal_velocity(i)


func _spawn_yellow_stationary(start: int, count_stat: int) -> void:
	for j in range(count_stat):
		var i := start + j
		is_stationary[i] = 1
		vel_x[i] = 0.0
		vel_y[i] = 0.0
		if j < building_cells.size():
			var cell := building_cells[j]
			pos_x[i] = float(cell.x)
			pos_y[i] = float(cell.y)
		else:
			pos_x[i] = randf_range(20.0, float(grid.width - 20))
			pos_y[i] = randf_range(20.0, float(grid.height - 20))


func _spawn_near(i: int, center: Vector2, require_road: bool) -> void:
	var w := grid.width
	var h := grid.height
	for _attempt in range(40):
		var x := center.x + randf_range(-CLUSTER_SPREAD, CLUSTER_SPREAD)
		var y := center.y + randf_range(-CLUSTER_SPREAD, CLUSTER_SPREAD)
		x = clampf(x, 2.0, float(w - 4))
		y = clampf(y, 2.0, float(h - 4))
		var gx := int(x)
		var gy := int(y)
		var idx := gy * w + gx
		if grid.slime_mass[idx] > 0.01:
			continue
		if require_road:
			var ct: int = grid.cell_type[idx]
			if ct != Materials.CellType.ROAD and ct != Materials.CellType.DIRT:
				continue
		pos_x[i] = x
		pos_y[i] = y
		_set_random_velocity(i)
		return
	_spawn_at_edge(i)


func _spawn_on_road_near(i: int, center: Vector2i) -> void:
	var w := grid.width
	var ct := grid.cell_type
	for radius in range(0, int(CLUSTER_SPREAD) + 1):
		for _attempt in range(8):
			var x := center.x + randi_range(-radius, radius)
			var y := center.y + randi_range(-radius, radius)
			if x >= 2 and x < grid.width - 4 and y >= 2 and y < grid.height - 4:
				if ct[y * w + x] == Materials.CellType.ROAD:
					if grid.slime_mass[y * w + x] < 0.01:
						pos_x[i] = float(x)
						pos_y[i] = float(y)
						return
	pos_x[i] = float(center.x)
	pos_y[i] = float(center.y)


func update() -> void:
	var w := grid.width
	var h := grid.height
	var sm := grid.slime_mass

	for i in range(count):
		if alive[i] == 0:
			respawn_timer[i] -= 1.0
			if respawn_timer[i] <= 0:
				alive[i] = 1
				if entity_type[i] == TYPE_RED:
					_spawn_near(i, Vector2(pos_x[i], pos_y[i]), false)
				elif is_stationary[i] == 1:
					if not building_cells.is_empty():
						var bc := building_cells[randi() % building_cells.size()]
						pos_x[i] = float(bc.x)
						pos_y[i] = float(bc.y)
				else:
					_spawn_on_road_near(i, Vector2i(randi_range(10, w - 10), randi_range(10, h - 10)))
					move_dir[i] = randi() % 4
					_set_cardinal_velocity(i)
			continue

		if entity_type[i] == TYPE_RED:
			_update_red(i, w, h, sm)
		else:
			_update_yellow(i, w, h, sm)

		# Apply velocity (skip stationary)
		if is_stationary[i] == 0:
			pos_x[i] += vel_x[i]
			pos_y[i] += vel_y[i]

			if pos_x[i] < 1.0:
				pos_x[i] = 1.0
				vel_x[i] = absf(vel_x[i])
			elif pos_x[i] > float(w - 3):
				pos_x[i] = float(w - 3)
				vel_x[i] = -absf(vel_x[i])
			if pos_y[i] < 1.0:
				pos_y[i] = 1.0
				vel_y[i] = absf(vel_y[i])
			elif pos_y[i] > float(h - 4):
				pos_y[i] = float(h - 4)
				vel_y[i] = -absf(vel_y[i])


func _update_red(i: int, w: int, h: int, sm: PackedFloat32Array) -> void:
	var gx := int(pos_x[i])
	var gy := int(pos_y[i])

	# Sense slime: sample 8 random nearby cells
	var sense_dx := 0.0
	var sense_dy := 0.0
	var found_slime := false
	for _s in range(8):
		var sx := gx + randi_range(-SENSE_RADIUS, SENSE_RADIUS)
		var sy := gy + randi_range(-SENSE_RADIUS, SENSE_RADIUS)
		if sx >= 0 and sx < w and sy >= 0 and sy < h:
			if sm[sy * w + sx] > 0.1:
				var dx := float(sx - gx)
				var dy := float(sy - gy)
				var dist := sqrt(dx * dx + dy * dy)
				if dist > 0.5:
					sense_dx += dx / dist
					sense_dy += dy / dist
					found_slime = true

	if found_slime:
		var slen := sqrt(sense_dx * sense_dx + sense_dy * sense_dy)
		if slen > 0.1:
			sense_dx /= slen
			sense_dy /= slen
		vel_x[i] = lerpf(vel_x[i], sense_dx * RED_SPEED, 0.1)
		vel_y[i] = lerpf(vel_y[i], sense_dy * RED_SPEED, 0.1)
	else:
		vel_x[i] += randf_range(-0.02, 0.02)
		vel_y[i] += randf_range(-0.02, 0.02)
		_clamp_speed(i, RED_SPEED)

	var burn := grid.burn_intensity
	var center_x := gx + 1
	var center_y := gy + 1

	# Check if on slime (any owner)
	var on_slime := false
	for dy in range(3):
		for dx in range(2):
			var cx := gx + dx
			var cy := gy + dy
			if cx >= 0 and cx < w and cy >= 0 and cy < h:
				if sm[cy * w + cx] > 0.01 and grid.slime_owner[cy * w + cx] != 0:
					on_slime = true
					break
		if on_slime:
			break

	if on_slime:
		# Full fire attack: burn + damage in radius
		for dy in range(-BURN_RADIUS, BURN_RADIUS + 1):
			for dx in range(-BURN_RADIUS, BURN_RADIUS + 1):
				var dist_sq := dx * dx + dy * dy
				if dist_sq > BURN_RADIUS * BURN_RADIUS:
					continue
				var cx := center_x + dx
				var cy := center_y + dy
				if cx >= 0 and cx < w and cy >= 0 and cy < h:
					var idx := cy * w + cx
					var dist_factor := 1.0 - sqrt(float(dist_sq)) / float(BURN_RADIUS + 1)
					burn[idx] = minf(burn[idx] + BURN_DEPOSIT * dist_factor, 1.0)
					if sm[idx] > 0.01:
						sm[idx] = maxf(0.0, sm[idx] - RED_ATTACK * dist_factor)

		# Overwhelm check
		var mass_sum := 0.0
		for dy in range(-2, 6):
			for dx in range(-2, 5):
				var cx := gx + dx
				var cy := gy + dy
				if cx >= 0 and cx < w and cy >= 0 and cy < h:
					mass_sum += sm[cy * w + cx]
		if mass_sum > RED_OVERWHELM:
			alive[i] = 0
			respawn_timer[i] = RESPAWN_DELAY
	else:
		# Small movement trail: just footprint, light burn
		for dy in range(3):
			for dx in range(2):
				var cx := gx + dx
				var cy := gy + dy
				if cx >= 0 and cx < w and cy >= 0 and cy < h:
					burn[cy * w + cx] = minf(burn[cy * w + cx] + BURN_TRAIL, 0.4)


func _update_yellow(i: int, w: int, h: int, sm: PackedFloat32Array) -> void:
	var gx := int(pos_x[i])
	var gy := int(pos_y[i])

	# Check if consumed by slime
	if gx >= 0 and gx < w and gy >= 0 and gy < h:
		var cell_idx := gy * w + gx
		if sm[cell_idx] > 0.5 and grid.slime_owner[cell_idx] != 0:
			alive[i] = 0
			respawn_timer[i] = RESPAWN_DELAY
			var consuming_owner: int = grid.slime_owner[cell_idx]
			var oi := consuming_owner - 1
			grid.owner_growth_velocity[oi] = minf(grid.owner_growth_velocity[oi] + YELLOW_BOOST, 3.0)
			# Visual reward: bright green pulse
			for edy in range(-4, 5):
				for edx in range(-4, 5):
					if edx * edx + edy * edy <= 16:
						var cx := gx + edx
						var cy := gy + edy
						if cx >= 0 and cx < w and cy >= 0 and cy < h:
							var cidx := cy * w + cx
							if sm[cidx] > 0.01:
								sm[cidx] = minf(sm[cidx] + 0.3, 1.0)
								grid.slime_trail[cidx] = minf(grid.slime_trail[cidx] + 2.0, 3.0)
			return

	# Stationary yellows don't move
	if is_stationary[i] == 1:
		return

	# Road-following car behavior
	var ct := grid.cell_type
	var d: int = move_dir[i]
	var ahead_x := gx + DIR_X[d] * 2
	var ahead_y := gy + DIR_Y[d] * 2
	var can_continue := false
	if ahead_x >= 0 and ahead_x < w and ahead_y >= 0 and ahead_y < h:
		var ahead_type: int = ct[ahead_y * w + ahead_x]
		can_continue = (ahead_type == Materials.CellType.ROAD or ahead_type == Materials.CellType.DIRT)

	if not can_continue:
		# Try turning: check perpendicular and other directions
		var turn_options: Array[int] = []
		for new_d in range(4):
			if new_d == d:
				continue
			var nx := gx + DIR_X[new_d] * 2
			var ny := gy + DIR_Y[new_d] * 2
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				var nt: int = ct[ny * w + nx]
				if nt == Materials.CellType.ROAD or nt == Materials.CellType.DIRT:
					turn_options.append(new_d)
		if not turn_options.is_empty():
			move_dir[i] = turn_options[randi() % turn_options.size()]
		else:
			# Dead end: reverse
			move_dir[i] = [1, 0, 3, 2][d]
		_set_cardinal_velocity(i)
	elif randf() < 0.01:
		# Occasionally turn at intersections for variety
		var turn_options: Array[int] = []
		for new_d in range(4):
			if new_d == d:
				continue
			var nx := gx + DIR_X[new_d] * 2
			var ny := gy + DIR_Y[new_d] * 2
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				var nt: int = ct[ny * w + nx]
				if nt == Materials.CellType.ROAD or nt == Materials.CellType.DIRT:
					turn_options.append(new_d)
		if not turn_options.is_empty():
			move_dir[i] = turn_options[randi() % turn_options.size()]
			_set_cardinal_velocity(i)

	# Slime avoidance: check ahead
	for dist in range(1, 6):
		var check_x := gx + DIR_X[move_dir[i]] * dist
		var check_y := gy + DIR_Y[move_dir[i]] * dist
		if check_x >= 0 and check_x < w and check_y >= 0 and check_y < h:
			if sm[check_y * w + check_x] > 0.1:
				var turn_options: Array[int] = []
				for new_d in range(4):
					if new_d == move_dir[i]:
						continue
					var nx := gx + DIR_X[new_d] * 3
					var ny := gy + DIR_Y[new_d] * 3
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						if sm[ny * w + nx] < 0.1:
							turn_options.append(new_d)
				if not turn_options.is_empty():
					move_dir[i] = turn_options[randi() % turn_options.size()]
					_set_cardinal_velocity(i)
				break


func _set_cardinal_velocity(i: int) -> void:
	var d: int = move_dir[i]
	vel_x[i] = DIR_X[d] * YELLOW_SPEED
	vel_y[i] = DIR_Y[d] * YELLOW_SPEED


func _clamp_speed(i: int, max_speed: float) -> void:
	var spd := sqrt(vel_x[i] * vel_x[i] + vel_y[i] * vel_y[i])
	if spd > max_speed:
		vel_x[i] = vel_x[i] / spd * max_speed
		vel_y[i] = vel_y[i] / spd * max_speed
	elif spd < max_speed * 0.2:
		var angle := randf() * TAU
		vel_x[i] = cos(angle) * max_speed
		vel_y[i] = sin(angle) * max_speed


func _set_random_velocity(i: int) -> void:
	var angle := randf() * TAU
	var speed := RED_SPEED if entity_type[i] == TYPE_RED else YELLOW_SPEED
	vel_x[i] = cos(angle) * speed
	vel_y[i] = sin(angle) * speed
	dir_timer[i] = randf_range(60.0, 120.0)


func _spawn_at_edge(i: int) -> void:
	var w := grid.width
	var h := grid.height
	var edge := randi() % 4
	match edge:
		0:
			pos_x[i] = randf_range(2.0, float(w - 4))
			pos_y[i] = 2.0
		1:
			pos_x[i] = randf_range(2.0, float(w - 4))
			pos_y[i] = float(h - 4)
		2:
			pos_x[i] = 2.0
			pos_y[i] = randf_range(2.0, float(h - 4))
		3:
			pos_x[i] = float(w - 4)
			pos_y[i] = randf_range(2.0, float(h - 4))
	_set_random_velocity(i)
