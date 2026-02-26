class_name Grid
extends RefCounted

var width: int
var height: int

# Cell data — flat arrays indexed as [y * width + x]
var cell_type: PackedByteArray
var cell_type_under: PackedByteArray  # original type before slime consumed it
var cell_energy: PackedFloat32Array

# Slime layers (single-buffer, updated in-place)
var slime_mass: PackedFloat32Array
var slime_trail: PackedFloat32Array
var slime_flow_x: PackedFloat32Array
var slime_flow_y: PackedFloat32Array

# Player attractor field
var attractor: PackedFloat32Array

# Global growth target (set by player click)
var target_pos: Vector2i = Vector2i(-1, -1)
var has_target: bool = false
var target_strength: float = 0.0


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

	slime_flow_x = PackedFloat32Array()
	slime_flow_x.resize(size)
	slime_flow_x.fill(0.0)

	slime_flow_y = PackedFloat32Array()
	slime_flow_y.resize(size)
	slime_flow_y.fill(0.0)

	attractor = PackedFloat32Array()
	attractor.resize(size)
	attractor.fill(0.0)


func idx(x: int, y: int) -> int:
	return y * width + x
