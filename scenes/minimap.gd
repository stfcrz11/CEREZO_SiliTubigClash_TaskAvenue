extends Control

var maze: Array = []
var local_player: Node2D

const WALL_COLOR := Color(0.36, 0.25, 0.16)
const FLOOR_COLOR := Color(0.42, 0.58, 0.32)
const PANEL_COLOR := Color(0.05, 0.07, 0.1, 0.94)
const BORDER_COLOR := Color(0.98, 0.82, 0.3)


func set_maze(layout: Array) -> void:
	maze = layout
	queue_redraw()


func set_local_player(player: Node2D) -> void:
	local_player = player
	queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(local_player):
		queue_redraw()


func _draw() -> void:
	if maze.is_empty():
		return
	var rows: int = maze.size()
	var columns: int = maze[0].length()
	var cell_size: float = min((size.x - 12.0) / columns, (size.y - 24.0) / rows)
	var map_size: Vector2 = Vector2(columns, rows) * cell_size
	var origin: Vector2 = Vector2((size.x - map_size.x) / 2.0, 18.0)

	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 13.0), "MINIMAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.9, 0.55))
	for y in rows:
		for x in columns:
			var cell_rect: Rect2 = Rect2(origin + Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
			var color: Color = WALL_COLOR if maze[y][x] == "#" else FLOOR_COLOR
			draw_rect(cell_rect, color)

	if is_instance_valid(local_player):
		var cell: Vector2 = Vector2(((local_player.global_position - Vector2(20.0, 40.0)) / 40.0).floor())
		var marker_center: Vector2 = origin + (cell + Vector2(0.5, 0.5)) * cell_size
		draw_circle(marker_center, max(2.5, cell_size * 0.32), Color(0.3, 0.85, 1.0))
		draw_circle(marker_center, max(2.5, cell_size * 0.32), Color.WHITE, false, 1.0)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
