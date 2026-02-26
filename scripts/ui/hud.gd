extends CanvasLayer

var label: Label
var bar_fill: ColorRect
var bar_label: Label
var slime_sim: SlimeSim
var grid: Grid
var update_timer: int = 0

const BAR_WIDTH := 120.0
const BAR_HEIGHT := 8.0

func _ready() -> void:
	layer = 10  # always on top

	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()

	label = Label.new()
	label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label)

	# Growth velocity bar
	bar_label = Label.new()
	bar_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.6))
	bar_label.add_theme_font_size_override("font_size", 13)
	bar_label.text = "Growth: 1.0x"
	vbox.add_child(bar_label)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	vbox.add_child(bar_bg)

	bar_fill = ColorRect.new()
	bar_fill.size = Vector2(0, BAR_HEIGHT)
	bar_fill.color = Color(0.3, 0.9, 0.2)
	bar_bg.add_child(bar_fill)

	panel.add_child(vbox)
	add_child(panel)


func _process(_delta: float) -> void:
	update_timer += 1
	if update_timer < 10:
		return
	update_timer = 0

	var fps := Engine.get_frames_per_second()
	var stats := slime_sim.get_stats()
	label.text = "FPS: %d\nSlime cells: %d\nConsumed: %d" % [
		fps, stats["cells"], stats["consumed"]
	]

	# Update growth velocity bar
	if grid:
		var gv := grid.growth_velocity
		bar_label.text = "Growth: %.1fx" % gv
		var fill_ratio := clampf((gv - 1.0) / 2.0, 0.0, 1.0)  # 1.0=empty, 3.0=full
		bar_fill.size.x = fill_ratio * BAR_WIDTH
		# Color: green at low, yellow at high
		bar_fill.color = Color(0.3 + fill_ratio * 0.7, 0.9 - fill_ratio * 0.3, 0.2)
