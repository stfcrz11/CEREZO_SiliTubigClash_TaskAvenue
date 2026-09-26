extends Control
## Shown to the Sili when the ONLY Tubig in the game is answering a
## question: the chase stops until the answer is in.
## To customize: open scenes/answering_notice.tscn and click
## "AnsweringNotice" to change the text in the Inspector.

@export var notice_text: String = "Tubig is answering, cannot be tagged"

@onready var label: Label = $Center/Panel/Margin/Label


func _ready() -> void:
	visible = false


func open() -> void:
	label.text = notice_text
	visible = true


func close() -> void:
	visible = false
