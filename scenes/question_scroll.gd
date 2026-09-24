extends Node2D
## A "?" question scroll. Just a visual: the host checks when a Tubig
## touches it (maze_game.gd) so every device agrees on who picked it.
## The picture is assets/ui/scroll.png — replace that file (any size) to
## change how scrolls look.

@export var icon_size: float = 24.0   # how big the scroll is in the world (a maze tile is 40)

var scroll_id: int = 0

@onready var icon: Sprite2D = $Icon


func _ready() -> void:
	var picture := icon.texture.get_size()
	icon.scale = Vector2.ONE * icon_size / max(picture.x, picture.y)


func _process(_delta: float) -> void:
	# gentle pulse so scrolls are easy to spot
	scale = Vector2.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() / 200.0))
