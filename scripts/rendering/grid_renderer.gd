class_name GridRenderer
extends RefCounted

var image: Image
var texture: ImageTexture
var grid: Grid
var entities: EntityManager
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

			# Burn overlay: marshmallow effect — fire → embers → brown → black char
			var burn_val: float = grid.burn_intensity[idx]
			if burn_val > 0.03:
				if burn_val > 0.7:
					# White-hot fire core
					var fire := Color(1.0, 0.8, 0.2)
					color = color.lerp(fire, 0.9)
				elif burn_val > 0.4:
					# Orange/red embers
					var t := (burn_val - 0.4) / 0.3
					var ember := Color(1.0, 0.25 + t * 0.35, 0.0)
					color = color.lerp(ember, 0.7 + t * 0.2)
				elif burn_val > 0.15:
					# Brown char
					var t := (burn_val - 0.15) / 0.25
					var brown := Color(0.25, 0.12, 0.05)
					color = color.lerp(brown, 0.4 + t * 0.3)
				else:
					# Dark blackened char (lingering)
					color = color.darkened(burn_val * 3.0)

			image.set_pixel(x, y, color)

	# Draw player target marker — white, large, distinct blink
	if grid.has_target:
		var tx := grid.target_pos.x
		var ty := grid.target_pos.y
		# Sharp on/off blink (visible 70% of the time)
		var blink := fmod(Time.get_ticks_msec() * 0.003, 1.0) < 0.7
		if blink:
			var center_color := Color(1.0, 1.0, 1.0, 1.0)  # solid white
			var ring_color := Color(0.8, 0.9, 1.0, 0.9)     # pale blue-white ring
			# Radius 4 for larger marker
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var dist_sq := dx * dx + dy * dy
					var px := tx + dx
					var py := ty + dy
					if px < 0 or px >= w or py < 0 or py >= h:
						continue
					if dist_sq <= 3:  # solid center (wider diamond)
						image.set_pixel(px, py, center_color)
					elif dist_sq >= 9 and dist_sq <= 16:  # outer ring
						image.set_pixel(px, py, ring_color)

	# Draw entities — 2x3 colored rectangles
	if entities:
		var red_color := Color(1.0, 0.1, 0.1)
		var yellow_color := Color(1.0, 0.9, 0.1)
		for i in range(entities.count):
			if entities.alive[i] == 0:
				continue
			var ex := int(entities.pos_x[i])
			var ey := int(entities.pos_y[i])
			var ecolor := red_color if entities.entity_type[i] == EntityManager.TYPE_RED else yellow_color
			for dy in range(3):
				for dx in range(2):
					var px := ex + dx
					var py := ey + dy
					if px >= 0 and px < w and py >= 0 and py < h:
						image.set_pixel(px, py, ecolor)

	texture.update(image)
