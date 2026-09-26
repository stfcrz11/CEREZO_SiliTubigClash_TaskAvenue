extends Control
## Multiple-choice question window, shown only to the Tubig who is
## answering (click/tap a choice or press 1-4). The host decides if the
## answer is right and tells every device (maze_game.gd).
## With teammates in the game, the answerer can press ASK A TEAMMATE FOR
## HELP (or H) once: the first teammate who says YES gets the question.

signal choice_made(position: int)   # -1 = ran out of time
signal help_requested

const ButtonStyle := preload("res://scenes/ui_button_style.gd")

@export var answer_time: float = 15.0

@onready var header_label: Label = $Panel/Margin/VBox/HeaderLabel
@onready var time_label: Label = $Panel/Margin/VBox/TimeLabel
@onready var question_label: Label = $Panel/Margin/VBox/QuestionLabel
@onready var choice_buttons: Array = [
	$Panel/Margin/VBox/Choices/Choice1, $Panel/Margin/VBox/Choices/Choice2,
	$Panel/Margin/VBox/Choices/Choice3, $Panel/Margin/VBox/Choices/Choice4]
@onready var feedback_label: Label = $Panel/Margin/VBox/FeedbackLabel
@onready var help_button: Button = $Panel/Margin/VBox/HelpButton

var entry: Dictionary
var order: Array = []          # order[i] = index into entry.choices shown at button i
var can_answer: bool = false
var waiting: bool = false
var time_left: float = 0.0
var _help_used: bool = false   # this question already asked for help (or got told no one can)


func _ready() -> void:
	visible = false
	for i in choice_buttons.size():
		ButtonStyle.style_choice(choice_buttons[i], Color(0.23, 0.69, 0.96))
		choice_buttons[i].pressed.connect(_pick.bind(i))
	ButtonStyle.style_secondary(help_button, Color(0.85, 0.5, 0.15))
	help_button.pressed.connect(_ask_help)


func show_question(q: Dictionary, shown_order: Array, header: String, answerer_is_me: bool,
		answerer_name: String, can_ask_help: bool = false) -> void:
	entry = q
	order = shown_order
	header_label.text = header
	question_label.text = q["q"]
	for i in choice_buttons.size():
		var b: Button = choice_buttons[i]
		b.text = "%d.  %s" % [i + 1, q["choices"][order[i]]]
		b.disabled = not answerer_is_me
		b.modulate = Color.WHITE
	can_answer = answerer_is_me
	feedback_label.text = "" if answerer_is_me else "%s is answering..." % answerer_name
	help_button.visible = answerer_is_me and can_ask_help
	help_button.disabled = false
	help_button.text = "ASK A TEAMMATE FOR HELP (H)"
	_help_used = false
	time_left = answer_time
	waiting = true
	visible = answerer_is_me


func _process(delta: float) -> void:
	if not waiting or GameState.round_state == GameState.RoundState.PAUSED:
		return
	time_left -= delta
	time_label.text = "Time to answer: %d" % ceili(max(time_left, 0.0))
	if time_left <= 0.0 and can_answer:
		_pick(-1)


func _unhandled_input(event: InputEvent) -> void:
	if not (waiting and can_answer and event is InputEventKey and event.pressed):
		return
	var k: int = event.physical_keycode
	if k >= KEY_1 and k <= KEY_4:
		_pick(k - KEY_1)
		get_viewport().set_input_as_handled()
	elif k == KEY_H and help_button.visible and not help_button.disabled:
		_ask_help()
		get_viewport().set_input_as_handled()


func _ask_help() -> void:
	if not (waiting and can_answer) or help_button.disabled:
		return
	_help_used = true
	help_button.disabled = true
	help_button.text = "Asking your teammates..."
	help_requested.emit()


## Called when the host says nobody can help right now.
func help_unavailable() -> void:
	help_button.text = "No teammate can help right now"


## Only one Tubig can ask for help at a time: while someone else is asking,
## this button waits (it comes back when their request is over).
func set_help_locked(locked: bool, asker_name: String) -> void:
	if _help_used or not can_answer:
		return
	help_button.disabled = locked
	help_button.text = ("%s is already asking for help..." % asker_name) if locked else "ASK A TEAMMATE FOR HELP (H)"


## Pressed at the same instant as someone else: wait for their request to end.
func help_rejected(asker_name: String) -> void:
	_help_used = false
	set_help_locked(true, asker_name)


func _pick(position: int) -> void:
	if not (waiting and can_answer):
		return
	can_answer = false
	help_button.disabled = true
	for b in choice_buttons:
		b.disabled = true
	feedback_label.text = "Checking..."
	choice_made.emit(position)


## Called on every device with the host's verdict.
func show_result(chosen: int, correct: bool) -> void:
	waiting = false
	var correct_pos: int = order.find(entry["answer"])
	for i in choice_buttons.size():
		choice_buttons[i].disabled = true
		if i == correct_pos:
			choice_buttons[i].modulate = Color(0.5, 1.0, 0.5)
		elif i == chosen:
			choice_buttons[i].modulate = Color(1.0, 0.5, 0.5)
	var answer_text: String = entry["choices"][entry["answer"]]
	var fact: String = entry.get("fact", "")
	if correct:
		feedback_label.text = "Tama! Correct.  " + fact
	elif chosen < 0:
		feedback_label.text = "Time's up! Answer: %s.  %s" % [answer_text, fact]
	else:
		feedback_label.text = "Mali! Answer: %s.  %s" % [answer_text, fact]


func close() -> void:
	waiting = false
	visible = false
