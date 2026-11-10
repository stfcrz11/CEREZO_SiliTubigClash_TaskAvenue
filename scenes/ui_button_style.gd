extends RefCounted
## Code-drawn buttons (end-of-round, answers, help, help alert) in the same
## chunky pixel style as the PNG buttons: square corners, dark outline, a
## thick darker bottom edge that "presses in" when clicked.

const OUTLINE := Color(0.13, 0.1, 0.08)


static func _box(face: Color, bottom: int, top: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.anti_aliasing = false
	box.set_corner_radius_all(0)
	box.border_color = OUTLINE
	box.border_width_left = 3
	box.border_width_right = 3
	box.border_width_top = 3 + top
	box.border_width_bottom = 3 + bottom
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	# the darker 3D lip is drawn as an expanded margin of the face color
	box.shadow_color = face.darkened(0.4)
	box.shadow_size = 0
	return box


static func style_primary(button: Button, accent: Color = Color(0.93, 0.7, 0.2), text_color: Color = Color(0.16, 0.11, 0.09)) -> void:
	var normal := _box(accent, 4, 0)
	var hover := _box(accent.lightened(0.15), 4, 0)
	var pressed := _box(accent.darkened(0.15), 1, 3)   # pushed down
	var disabled := _box(Color(0.42, 0.43, 0.48), 4, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color(0.8, 0.82, 0.86))
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, maxf(button.custom_minimum_size.y, 44.0))
	button.flat = false


static func style_secondary(button: Button, accent: Color = Color(0.59, 0.38, 0.21), text_color: Color = Color(0.98, 0.97, 0.94)) -> void:
	style_primary(button, accent, text_color)


static func style_choice(button: Button, accent: Color = Color(0.28, 0.66, 0.93)) -> void:
	style_primary(button, accent, Color(0.05, 0.08, 0.12))
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 42.0)
