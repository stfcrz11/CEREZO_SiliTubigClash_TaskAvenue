extends Node2D
## A "?" question scroll. Just a visual: the host checks when a Tubig
## touches it (maze_game.gd) so every device agrees on who picked it.

var scroll_id: int = 0


func _process(_delta: float) -> void:
	# gentle pulse so scrolls are easy to spot
	scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 200.0))
