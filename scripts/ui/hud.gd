extends CanvasLayer

var label: Label
var slime_sim: SlimeSim
var update_timer: int = 0

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

	label = Label.new()
	label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
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
