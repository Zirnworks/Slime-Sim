class_name SlimeSim
extends RefCounted

# Tuning knobs
const EAT_RATE := 0.06         # base damage per tick (slower eating)
const MATURE_THRESHOLD := 0.8  # mass needed to eat/colonize neighbors
const MASS_GROWTH := 0.04      # how fast immature slime cells grow toward 1.0
const TRAIL_DEPOSIT := 0.3
const TRAIL_DECAY := 0.98
const TRAIL_DIFFUSE := 0.15
const NOISE_AMOUNT := 0.2
const ATTRACTOR_WEIGHT := 5.0
const TRAIL_WEIGHT := 2.0
const TARGET_BIAS := 15.0         # how strongly the global target influences growth direction
const TARGET_RANGE := 80.0        # max distance (pixels) for target influence — tight for tendrils

# Cardinal directions
const DIR_X: Array[int] = [1, -1, 0, 0]
const DIR_Y: Array[int] = [0, 0, 1, -1]

var grid: Grid

# Stats
var total_mass: float = 0.0
var cells_consumed: int = 0


func seed_slime(cx: int, cy: int, radius: int = 5, _mass: float = 1.0) -> void:
	var w := grid.width
	var h := grid.height
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < w and y >= 0 and y < h:
					var idx := y * w + x
					grid.slime_mass[idx] = 1.0
					grid.cell_type[idx] = Materials.CellType.EMPTY
					grid.cell_energy[idx] = 0.0


func update_band(band_start: int, band_end: int) -> void:
	var w := grid.width
	var h := grid.height
	var ct := grid.cell_type
	var ce := grid.cell_energy
	var sm := grid.slime_mass
	var st := grid.slime_trail
	var attr := grid.attractor

	# Cache global target info
	var has_target := grid.has_target
	var target_x: int = grid.target_pos.x if has_target else 0
	var target_y: int = grid.target_pos.y if has_target else 0
	var t_strength: float = grid.target_strength if has_target else 0.0
	var growth_vel: float = grid.growth_velocity

	for y in range(band_start, mini(band_end, h)):
		var row_off := y * w
		for x in range(w):
			var idx := row_off + x
			if sm[idx] < 0.01:
				continue

			# --- MATURE: immature slime slowly grows toward 1.0 ---
			if sm[idx] < 1.0:
				sm[idx] = minf(sm[idx] + MASS_GROWTH * growth_vel, 1.0)

			# Only mature cells can eat and spread
			if sm[idx] < MATURE_THRESHOLD:
				st[idx] += TRAIL_DEPOSIT * 0.3
				continue

			var is_frontier := false

			# --- FRONTIER: eat and colonize neighbors ---
			for d in range(4):
				var nx := x + DIR_X[d]
				var ny := y + DIR_Y[d]
				if nx < 0 or nx >= w or ny < 0 or ny >= h:
					continue
				var nidx := ny * w + nx
				var ntype: int = ct[nidx]

				# Skip already-slimed cells
				if sm[nidx] > 0.01:
					continue

				is_frontier = true

				if ntype == Materials.CellType.EMPTY:
					# Empty cell — colonize immediately at full strength
					sm[nidx] = 1.0
					cells_consumed += 1
					continue

				# Eat the cell: flat rate scaled by inverse resistance
				var resistance: float = Materials.RESISTANCE[ntype]
				var eat_power := EAT_RATE * (1.0 - resistance * 0.8) * growth_vel

				# Attractor boost: eat faster toward attractors
				var attract_val: float = attr[nidx]
				if attract_val > 0.1:
					eat_power *= 1.0 + attract_val

				# Global target bias: boost eating in the direction of the target
				if has_target:
					var dx_t := target_x - x
					var dy_t := target_y - y
					var dist_sq_t := dx_t * dx_t + dy_t * dy_t
					if dist_sq_t > 0:
						var dist_t := sqrt(float(dist_sq_t))
						if dist_t < TARGET_RANGE:
							# How much this eat direction aligns with target direction
							var alignment := (DIR_X[d] * dx_t + DIR_Y[d] * dy_t) / dist_t
							if alignment > 0.0:
								# Steep falloff: strongest near target, zero at TARGET_RANGE
								var falloff := 1.0 - dist_t / TARGET_RANGE
								falloff *= falloff  # quadratic for sharper tendril focus
								eat_power *= 1.0 + TARGET_BIAS * t_strength * alignment * falloff

				# Random variation for organic feel
				eat_power *= 0.5 + randf()

				ce[nidx] -= eat_power
				if ce[nidx] <= 0:
					# Consumed! Colonize with low mass — needs time to mature
					cells_consumed += 1
					grid.cell_type_under[nidx] = ntype
					ct[nidx] = Materials.CellType.EMPTY
					ce[nidx] = 0.0
					# Building cells start weak, open terrain starts strong
					sm[nidx] = 1.0 - resistance * 0.8

			# --- TRAIL: frontier cells deposit more ---
			if is_frontier:
				st[idx] += TRAIL_DEPOSIT * 2.0
			else:
				st[idx] += TRAIL_DEPOSIT * 0.5


func diffuse_trails_band(band_start: int, band_end: int) -> void:
	var w := grid.width
	var h := grid.height
	var st := grid.slime_trail

	for y in range(band_start, mini(band_end, h)):
		var row_off := y * w
		for x in range(w):
			var idx := row_off + x
			var center: float = st[idx]
			if center < 0.001:
				continue

			var neighbor_avg := 0.0
			for d in range(4):
				var nx := x + DIR_X[d]
				var ny := y + DIR_Y[d]
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					neighbor_avg += st[ny * w + nx]
			neighbor_avg *= 0.25

			# Blend toward neighbor average and decay
			st[idx] = (center * (1.0 - TRAIL_DIFFUSE) + neighbor_avg * TRAIL_DIFFUSE) * TRAIL_DECAY


func decay_attractors_band(band_start: int, band_end: int, band_index: int) -> void:
	var w := grid.width
	var h := grid.height
	var attr := grid.attractor
	for y in range(band_start, mini(band_end, h)):
		var row_off := y * w
		for x in range(w):
			var idx := row_off + x
			if absf(attr[idx]) > 0.001:
				attr[idx] *= 0.99

	# Decay burn intensity
	var burn := grid.burn_intensity
	for y in range(band_start, mini(band_end, grid.height)):
		var row_off := y * w
		for x in range(w):
			var bidx := row_off + x
			if burn[bidx] > 0.001:
				burn[bidx] *= 0.985

	# Decay growth velocity once per full cycle (on first band only)
	if band_index == 0 and grid.growth_velocity > 1.0:
		grid.growth_velocity = maxf(1.0, grid.growth_velocity * 0.998)


func get_stats() -> Dictionary:
	var slime_cells := 0
	var sm := grid.slime_mass
	for i in range(grid.width * grid.height):
		if sm[i] > 0.01:
			slime_cells += 1
	return {"cells": slime_cells, "consumed": cells_consumed}
