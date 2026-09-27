extends Control
## SETTINGS window, opened by the gear button (title screen and in game).
## Music / Sound effects: on-off switch + volume slider (saved on this
## device by the Sound autoload). CONTROLS: the list of keys.
## Close with the X, Esc, or a click outside. It does NOT pause a LAN game.
## To customize: open scenes/settings_panel.tscn and click any node.

@onready var music_on: CheckButton = $Center/Panel/Margin/VBox/MusicRow/On
@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/MusicRow/Slider
@onready var music_value: Label = $Center/Panel/Margin/VBox/MusicRow/Value
@onready var sfx_on: CheckButton = $Center/Panel/Margin/VBox/SfxRow/On
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxRow/Slider
@onready var sfx_value: Label = $Center/Panel/Margin/VBox/SfxRow/Value
@onready var touch_on: CheckButton = $Center/Panel/Margin/VBox/TouchRow/On


func _ready() -> void:
	visible = false
	$Center/Panel/Margin/VBox/Header/CloseButton.pressed.connect(close)
	$Dim.gui_input.connect(_on_dim_input)
	music_on.toggled.connect(func(_on): _music_changed())
	music_slider.value_changed.connect(func(_v): _music_changed())
	sfx_on.toggled.connect(func(_on): _sfx_changed())
	sfx_slider.value_changed.connect(func(_v): _sfx_changed())
	touch_on.toggled.connect(func(on): GameState.set_touch_controls(on))


func open() -> void:
	# show the saved values (set_*_no_signal so this doesn't save again)
	music_on.set_pressed_no_signal(Sound.music_on)
	music_slider.set_value_no_signal(Sound.music_percent)
	sfx_on.set_pressed_no_signal(Sound.sfx_on)
	sfx_slider.set_value_no_signal(Sound.sfx_percent)
	touch_on.set_pressed_no_signal(GameState.touch_controls)
	_update_labels()
	visible = true


func close() -> void:
	visible = false


func _music_changed() -> void:
	Sound.set_music(music_on.button_pressed, int(music_slider.value))
	_update_labels()


func _sfx_changed() -> void:
	Sound.set_sfx(sfx_on.button_pressed, int(sfx_slider.value))
	_update_labels()


func _update_labels() -> void:
	music_value.text = "%d%%" % music_slider.value
	sfx_value.text = "%d%%" % sfx_slider.value
	music_slider.editable = music_on.button_pressed
	sfx_slider.editable = sfx_on.button_pressed
	music_slider.modulate.a = 1.0 if music_on.button_pressed else 0.4
	sfx_slider.modulate.a = 1.0 if sfx_on.button_pressed else 0.4


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()   # a click outside the window closes it


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()   # so Esc doesn't also pause the game
