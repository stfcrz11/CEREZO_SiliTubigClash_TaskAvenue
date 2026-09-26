extends Control
## Bottom-right alert a Tubig sees when a teammate asks for help with a
## question: "<name> needs help with the question! Do you want to help?"
## YES / NO (or keys Y / N). The game keeps running while it is shown.
## maze_game.gd opens and closes it; only the first YES from any teammate
## gets the question (the host decides).
## To customize: open scenes/help_alert.tscn and click "HelpAlert" for the
## texts in the Inspector, or click a node to change its look.

signal answered(yes: bool)

@export var message_text: String = "%s needs help with the question!\nDo you want to help?"   # %s = name

@onready var message: Label = $Panel/Margin/VBox/Message
@onready var yes_button: Button = $Panel/Margin/VBox/Buttons/YesButton
@onready var no_button: Button = $Panel/Margin/VBox/Buttons/NoButton

const ButtonStyle := preload("res://scenes/ui_button_style.gd")


func _ready() -> void:
	visible = false
	ButtonStyle.style_primary(yes_button, Color(0.25, 0.72, 0.4), Color(1, 1, 1))
	ButtonStyle.style_secondary(no_button, Color(0.4, 0.4, 0.48))
	yes_button.pressed.connect(_answer.bind(true))
	no_button.pressed.connect(_answer.bind(false))


func open(asker_name: String) -> void:
	message.text = message_text % asker_name
	visible = true


func close() -> void:
	visible = false


func _answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	answered.emit(yes)


func _unhandled_input(event: InputEvent) -> void:
	if not (visible and event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_Y:
		_answer(true)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_N:
		_answer(false)
		get_viewport().set_input_as_handled()
