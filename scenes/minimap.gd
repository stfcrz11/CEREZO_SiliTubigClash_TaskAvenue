extends Control
## The whole maze in the corner. The camera only shows the streets around
## you, so this is the only place you can see the full map. The white box
## is what your camera is showing right now. Other players are not shown.

var maze: Array = []
var maze_origin := Vector2(20, 40)
var tile := 40.0
var local_player: Node2D
var camera: Camera2D

const BUILDING_COLOR := Color(0.62, 0.3, 0.24)
const ROAD_COLOR := Color(0.3, 0.31, 0.34)
const PANEL_COLOR := Color(0.05, 0.07, 0.1, 0.94)
const BORDER_COLOR := Color(0.98, 0.82, 0.3)
const TUBIG_DOT := Color(0.3, 0.7, 1.0)
const SILI_DOT := Color(1.0, 0.35, 0.3)


func set_maze(layout: Array, origin: Vector2, tile_size: float) -> void:
	maze = layout
	maze_origin = origin
	tile = tile_size
	queue_redraw()


func set_local_player(player: Node2D) -> void:
	local_player = player
	queue_redraw()


func set_camera(view_camera: Camera2D) -> void:
	camera = view_camera


func _process(_delta: float) -> void:
	if is_instance_valid(local_player) or is_instance_valid(camera):
		queue_redraw()


func _draw() -> void:
	if maze.is_empty():
		return
	var rows: int = maze.size()
	var columns: int = maze[0].length()
	var cell_size: float = min((size.x - 12.0) / columns, (size.y - 24.0) / rows)
	var map_size: Vector2 = Vector2(columns, rows) * cell_size
	var origin: Vector2 = Vector2((size.x - map_size.x) / 2.0, 18.0)
	var map_rect := Rect2(origin, map_size)

	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 13.0), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.9, 0.55))
	for y in rows:
		for x in columns:
			var cell_rect: Rect2 = Rect2(origin + Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
			draw_rect(cell_rect, BUILDING_COLOR if maze[y][x] == "#" else ROAD_COLOR)

	if is_instance_valid(camera):
		# what the camera sees, clipped to the map
		var half_view: Vector2 = get_viewport_rect().size / camera.zoom / 2.0
		var center: Vector2 = camera.get_screen_center_position()
		var view := Rect2(_to_map(center - half_view, origin, cell_size), half_view * 2.0 / tile * cell_size)
		view = view.intersection(map_rect)
		if view.has_area():
			draw_rect(view, Color(1, 1, 1, 0.12))
			draw_rect(view, Color(1, 1, 1, 0.85), false, 1.0)

	if is_instance_valid(local_player):
		var marker_center: Vector2 = _to_map(local_player.global_position, origin, cell_size)
		var dot_color := TUBIG_DOT if local_player.is_tubig() else SILI_DOT
		draw_circle(marker_center, max(2.5, cell_size * 0.36), dot_color)
		draw_circle(marker_center, max(2.5, cell_size * 0.36), Color.WHITE, false, 1.0)


func _to_map(world_pos: Vector2, origin: Vector2, cell_size: float) -> Vector2:
	return origin + (world_pos - maze_origin) / tile * cell_size


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
