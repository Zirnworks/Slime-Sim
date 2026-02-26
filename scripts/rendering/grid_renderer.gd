class_name GridRenderer
extends RefCounted

var image: Image
var texture: ImageTexture
var grid: Grid
var display: TextureRect


func setup(g: Grid, tex_rect: TextureRect) -> void:
	grid = g
	display = tex_rect
	image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	display.texture = texture
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Size the TextureRect to match grid dimensions (1 pixel = 1 world unit)
	display.custom_minimum_size = Vector2(grid.width, grid.height)
	display.size = Vector2(grid.width, grid.height)


func render() -> void:
	var w := grid.width
	var h := grid.height
	var ct := grid.cell_type
	var ce := grid.cell_energy
	var sm := grid.slime_mass
	var st := grid.slime_trail

	for y in range(h):
		var row_offset := y * w
		for x in range(w):
			var idx := row_offset + x
			var color: Color

			var mass: float = sm[idx]
			var trail: float = st[idx]

			if mass > 0.1:
				# Slime cell — bright green
				var intensity := clampf(mass, 0.3, 1.0)
				color = Color(0.15 * intensity, 0.85 * intensity, 0.08 * intensity)
				# Darken over building materials to show structure underneath
				var under_type: int = grid.cell_type_under[idx]
				if under_type != Materials.CellType.EMPTY and under_type != Materials.CellType.DIRT:
					var res: float = Materials.RESISTANCE[under_type]
					color = color.darkened(res * 0.45)
			elif trail > 0.05:
				# Trail residue — dim glow over base material
				var base: Color = Materials.COLORS[ct[idx]]
				var trail_color := Color(0.4, 0.6, 0.1)
				color = base.lerp(trail_color, clampf(trail * 0.5, 0.0, 0.6))
			else:
				# Base material color
				color = Materials.COLORS[ct[idx]]
				# Show damage on cells being eaten
				var energy: float = ce[idx]
				if energy < 1.0 and ct[idx] != Materials.CellType.EMPTY:
					color = color.darkened((1.0 - energy) * 0.5)

			image.set_pixel(x, y, color)

	texture.update(image)
