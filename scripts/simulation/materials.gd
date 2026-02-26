class_name Materials
extends RefCounted

enum CellType {
	EMPTY = 0,
	ROAD = 1,
	CONCRETE = 2,
	BRICK = 3,
	GLASS = 4,
	ORGANIC = 5,
	WATER = 6,
	DIRT = 7,
	METAL = 8,
	SLIME = 9,
}

# How hard it is to eat (0.0 = instant, 1.0 = nearly indestructible)
const RESISTANCE: Array[float] = [
	0.0,   # EMPTY
	0.4,   # ROAD
	0.8,   # CONCRETE
	0.6,   # BRICK
	0.2,   # GLASS
	0.1,   # ORGANIC
	0.05,  # WATER
	0.2,   # DIRT
	0.95,  # METAL
	0.0,   # SLIME
]

# Energy gained from consuming this cell
const ENERGY_YIELD: Array[float] = [
	0.0,   # EMPTY
	0.1,   # ROAD
	0.05,  # CONCRETE
	0.15,  # BRICK
	0.1,   # GLASS
	0.8,   # ORGANIC
	0.0,   # WATER
	0.2,   # DIRT
	0.0,   # METAL
	0.0,   # SLIME
]

# Travel speed multiplier for slime
const TRAVEL_SPEED: Array[float] = [
	1.0,   # EMPTY
	1.2,   # ROAD
	0.2,   # CONCRETE
	0.4,   # BRICK
	0.8,   # GLASS
	0.7,   # ORGANIC
	2.0,   # WATER
	0.9,   # DIRT
	0.1,   # METAL
	1.5,   # SLIME
]

# Colors for rendering
const COLORS: Array[Color] = [
	Color(0.08, 0.08, 0.1),     # EMPTY
	Color(0.3, 0.3, 0.35),      # ROAD
	Color(0.6, 0.6, 0.55),      # CONCRETE
	Color(0.55, 0.35, 0.25),    # BRICK
	Color(0.7, 0.85, 0.95),     # GLASS
	Color(0.2, 0.55, 0.15),     # ORGANIC
	Color(0.15, 0.3, 0.7),      # WATER
	Color(0.4, 0.3, 0.2),       # DIRT
	Color(0.5, 0.5, 0.55),      # METAL
	Color(0.6, 0.9, 0.1),       # SLIME
]
