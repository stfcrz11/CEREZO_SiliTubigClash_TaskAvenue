extends TextureButton
## A button that is just a PNG picture. To change it, replace the PNG file
## or drag a new one into "Texture Normal" in the Inspector. The picture is
## fitted inside the button's size, keeping its shape.
## If you don't give it "Texture Hover" / "Texture Pressed" pictures, it
## glows when the mouse is over it and shrinks a little when clicked.
## When "Disabled" is on (and there is no "Texture Disabled") it turns grey.

@export var hover_glow: float = 1.2
@export var pressed_shrink: float = 0.95


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	mouse_entered.connect(_glow.bind(true))
	mouse_exited.connect(_glow.bind(false))
	button_down.connect(_shrink.bind(true))
	button_up.connect(_shrink.bind(false))


func _process(_delta: float) -> void:
	if texture_disabled == null:
		self_modulate = Color(0.55, 0.55, 0.6, 0.7) if disabled else Color.WHITE


func _glow(on: bool) -> void:
	if disabled:
		on = false
	if texture_hover == null:
		modulate = Color(hover_glow, hover_glow, hover_glow) if on else Color.WHITE


func _shrink(on: bool) -> void:
	if texture_pressed == null:
		scale = Vector2.ONE * (pressed_shrink if on else 1.0)
