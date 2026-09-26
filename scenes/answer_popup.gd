extends Control
## Big "TAMA!" / "MALI!" / "TIME'S UP!" popup shown on EVERY device after a
## question is answered: who answered, the right answer, the fact and the
## score. maze_game.gd opens it and closes it when play resumes.
## To customize: open scenes/answer_popup.tscn — click "AnswerPopup" for the
## words and colors in the Inspector, or click a label to change its font size.

@export_group("Texts")
@export var correct_word: String = "TAMA!"
@export var wrong_word: String = "MALI!"
@export var timeout_word: String = "TIME'S UP!"
@export var answered_text: String = "%s answered"            # %s = player name
@export var timeout_text: String = "%s ran out of time"
@export var answer_text: String = "Answer: %s"
@export var score_text: String = "Correct answers: %d / %d"

@export_group("Colors")
@export var correct_color: Color = Color(0.35, 0.9, 0.45)
@export var wrong_color: Color = Color(1.0, 0.4, 0.35)
@export var timeout_color: Color = Color(1.0, 0.7, 0.25)

@onready var panel: PanelContainer = $Center/Panel
@onready var big_word: Label = $Center/Panel/Margin/VBox/BigWord
@onready var who_label: Label = $Center/Panel/Margin/VBox/Who
@onready var answer_label: Label = $Center/Panel/Margin/VBox/Answer
@onready var fact_label: Label = $Center/Panel/Margin/VBox/Fact
@onready var score_label: Label = $Center/Panel/Margin/VBox/Score


func _ready() -> void:
	visible = false


func open(correct: bool, timed_out: bool, picker_name: String, right_answer: String,
		fact: String, score: int, goal: int) -> void:
	var color := correct_color if correct else (timeout_color if timed_out else wrong_color)
	big_word.text = correct_word if correct else (timeout_word if timed_out else wrong_word)
	big_word.add_theme_color_override("font_color", color)
	who_label.text = (timeout_text if timed_out else answered_text) % picker_name
	answer_label.text = answer_text % right_answer
	fact_label.text = fact
	fact_label.visible = not fact.is_empty()
	score_label.text = score_text % [score, goal]
	# border takes the result color
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.border_color = color
		panel.add_theme_stylebox_override("panel", style)
	visible = true
	# small "pop" so it catches the eye
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false
