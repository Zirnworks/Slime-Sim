class_name Grid
extends RefCounted

const NUM_OWNERS := 3  # 1=green(player), 2=orange, 3=blue

var width: int
var height: int

# Cell data — flat arrays indexed as [y * width + x]
var cell_type: PackedByteArray
var cell_type_under: PackedByteArray  # original type before slime consumed it
var cell_energy: PackedFloat32Array

# Slime layers (single-buffer, updated in-place)
var slime_mass: PackedFloat32Array
var slime_trail: PackedFloat32Array
var slime_owner: PackedByteArray       # 0=none, 1=green, 2=orange, 3=blue
var slime_flow_x: PackedFloat32Array
var slime_flow_y: PackedFloat32Array

# Player attractor field
var attractor: PackedFloat32Array

# Per-owner targeting (3 elements each, indexed owner-1)
var owner_target_x: PackedInt32Array
var owner_target_y: PackedInt32Array
var owner_has_target: PackedByteArray
var owner_target_strength: PackedFloat32Array

# Per-owner growth velocity (boosted by eating yellow food dots)
var owner_growth_velocity: PackedFloat32Array

# Tendril direction (0=none, 1-4 = cardinal direction index+1 matching DIR_X/DIR_Y)
var tendril_dir: PackedByteArray

# Burn layer (fire damage from red dots)
var burn_intensity: PackedFloat32Array


func init(w: int, h: int) -> void:
	width = w
	height = h
	var size := w * h

	cell_type = PackedByteArray()
	cell_type.resize(size)
	cell_type.fill(0)

	cell_type_under = PackedByteArray()
	cell_type_under.resize(size)
	cell_type_under.fill(0)

	cell_energy = PackedFloat32Array()
	cell_energy.resize(size)
	cell_energy.fill(1.0)

	slime_mass = PackedFloat32Array()
	slime_mass.resize(size)
	slime_mass.fill(0.0)

	slime_trail = PackedFloat32Array()
	slime_trail.resize(size)
	slime_trail.fill(0.0)

	slime_owner = PackedByteArray()
	slime_owner.resize(size)
	slime_owner.fill(0)

	slime_flow_x = PackedFloat32Array()
	slime_flow_x.resize(size)
	slime_flow_x.fill(0.0)

	slime_flow_y = PackedFloat32Array()
	slime_flow_y.resize(size)
	slime_flow_y.fill(0.0)

	attractor = PackedFloat32Array()
	attractor.resize(size)
	attractor.fill(0.0)

	# Per-owner arrays (3 elements)
	owner_target_x = PackedInt32Array()
	owner_target_x.resize(NUM_OWNERS)
	owner_target_x.fill(-1)

	owner_target_y = PackedInt32Array()
	owner_target_y.resize(NUM_OWNERS)
	owner_target_y.fill(-1)

	owner_has_target = PackedByteArray()
	owner_has_target.resize(NUM_OWNERS)
	owner_has_target.fill(0)

	owner_target_strength = PackedFloat32Array()
	owner_target_strength.resize(NUM_OWNERS)
	owner_target_strength.fill(0.0)

	owner_growth_velocity = PackedFloat32Array()
	owner_growth_velocity.resize(NUM_OWNERS)
	owner_growth_velocity.fill(1.0)

	tendril_dir = PackedByteArray()
	tendril_dir.resize(size)
	tendril_dir.fill(0)

	burn_intensity = PackedFloat32Array()
	burn_intensity.resize(size)
	burn_intensity.fill(0.0)


func idx(x: int, y: int) -> int:
	return y * width + x


func set_owner_target(owner: int, pos: Vector2i, strength: float) -> void:
	var oi := owner - 1
	owner_target_x[oi] = pos.x
	owner_target_y[oi] = pos.y
	owner_has_target[oi] = 1
	owner_target_strength[oi] = strength


func get_owner_growth_vel(owner: int) -> float:
	return owner_growth_velocity[owner - 1]
