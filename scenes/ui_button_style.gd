extends RefCounted

static func style_primary(button: Button, accent: Color = Color(0.18, 0.68, 0.9), text_color: Color = Color(0.07, 0.1, 0.15)) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.2)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := StyleBoxFlat.new()
	hover.bg_color = accent.lightened(0.18)
	hover.border_color = accent.lightened(0.32)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(12)
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent.darkened(0.2)
	pressed.border_color = accent.darkened(0.12)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(12)
	pressed.content_margin_left = 18
	pressed.content_margin_right = 18
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 8

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.34, 0.37, 0.42)
	disabled.border_color = Color(0.45, 0.48, 0.53)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(12)
	disabled.content_margin_left = 18
	disabled.content_margin_right = 18
	disabled.content_margin_top = 8
	disabled.content_margin_bottom = 8

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color(0.8, 0.82, 0.86))
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, maxf(button.custom_minimum_size.y, 42.0))
	button.flat = false


static func style_secondary(button: Button, accent: Color = Color(0.12, 0.39, 0.64), text_color: Color = Color(0.95, 0.96, 0.99)) -> void:
	style_primary(button, accent, text_color)


static func style_choice(button: Button, accent: Color = Color(0.22, 0.62, 0.95)) -> void:
	style_primary(button, accent, Color(0.05, 0.08, 0.12))
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 40.0)
