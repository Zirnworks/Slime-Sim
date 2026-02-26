class_name Grid
extends RefCounted

var width: int
var height: int

# Cell data — flat arrays indexed as [y * width + x]
var cell_type: PackedByteArray
var cell_energy: PackedFloat32Array

# Slime layers (double-buffered)
var slime_mass_a: PackedFloat32Array
var slime_mass_b: PackedFloat32Array
var slime_trail_a: PackedFloat32Array
var slime_trail_b: PackedFloat32Array
var slime_flow_x: PackedFloat32Array
var slime_flow_y: PackedFloat32Array

# Player attractor field
var attractor: PackedFloat32Array

# Which buffer is current read
var buffer_flip: bool = false


func init(w: int, h: int) -> void:
	width = w
	height = h
	var size := w * h

	cell_type = PackedByteArray()
	cell_type.resize(size)
	cell_type.fill(0)

	cell_energy = PackedFloat32Array()
	cell_energy.resize(size)
	cell_energy.fill(1.0)

	slime_mass_a = PackedFloat32Array()
	slime_mass_a.resize(size)
	slime_mass_a.fill(0.0)

	slime_mass_b = PackedFloat32Array()
	slime_mass_b.resize(size)
	slime_mass_b.fill(0.0)

	slime_trail_a = PackedFloat32Array()
	slime_trail_a.resize(size)
	slime_trail_a.fill(0.0)

	slime_trail_b = PackedFloat32Array()
	slime_trail_b.resize(size)
	slime_trail_b.fill(0.0)

	slime_flow_x = PackedFloat32Array()
	slime_flow_x.resize(size)
	slime_flow_x.fill(0.0)

	slime_flow_y = PackedFloat32Array()
	slime_flow_y.resize(size)
	slime_flow_y.fill(0.0)

	attractor = PackedFloat32Array()
	attractor.resize(size)
	attractor.fill(0.0)


func get_slime_read() -> PackedFloat32Array:
	return slime_mass_a if not buffer_flip else slime_mass_b


func get_slime_write() -> PackedFloat32Array:
	return slime_mass_b if not buffer_flip else slime_mass_a


func get_trail_read() -> PackedFloat32Array:
	return slime_trail_a if not buffer_flip else slime_trail_b


func get_trail_write() -> PackedFloat32Array:
	return slime_trail_b if not buffer_flip else slime_trail_a


func swap_buffers() -> void:
	buffer_flip = not buffer_flip
	# Clear write buffers by copying read into them (so writes are additive)
	var sr := get_slime_read()
	var sw := get_slime_write()
	var tr := get_trail_read()
	var tw := get_trail_write()
	for i in range(width * height):
		sw[i] = sr[i]
		tw[i] = tr[i]


func idx(x: int, y: int) -> int:
	return y * width + x
