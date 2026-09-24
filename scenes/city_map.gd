extends Node2D
## Draws the maze as a Philippine city street seen from above: "#" cells
## become buildings (GI-sheet roofs, painted front walls, sari-sari store
## awnings, small parks) and floor cells become roads with sidewalks and
## lane lines. Extra city blocks are drawn around the maze so the edge of
## the camera never shows empty space. Drawing only — the walls that block
## players are still the StaticBody2Ds made in maze_game.gd.

const OUTSKIRTS := 8        # extra cells of city drawn around the maze

const ASPHALT := Color(0.22, 0.23, 0.25)
const ASPHALT_DARK := Color(0.21, 0.22, 0.24)
const SIDEWALK := Color(0.63, 0.61, 0.56)
const CURB := Color(0.45, 0.43, 0.4)
const LANE := Color(0.95, 0.82, 0.3)
const SHADOW := Color(0, 0, 0, 0.28)
const ROOFS := [Color(0.62, 0.22, 0.18), Color(0.2, 0.45, 0.5), Color(0.55, 0.57, 0.6),
	Color(0.24, 0.36, 0.62), Color(0.3, 0.5, 0.3), Color(0.7, 0.42, 0.2)]
const FACADES := [Color(0.95, 0.9, 0.78), Color(0.95, 0.75, 0.75), Color(0.72, 0.9, 0.8),
	Color(0.75, 0.85, 0.97), Color(0.98, 0.88, 0.55), Color(0.85, 0.85, 0.85)]
const WINDOW := Color(0.18, 0.28, 0.4)
const GRASS := Color(0.3, 0.55, 0.28)

var maze: Array = []
var origin := Vector2.ZERO
var tile := 40.0


func setup(layout: Array, maze_origin: Vector2, tile_size: float) -> void:
	maze = layout
	origin = maze_origin
	tile = tile_size
	queue_redraw()


# ------------------------------------------------------------ the grid
func _columns() -> int:
	return maze[0].length()


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _columns() and y < maze.size()


func _is_building(x: int, y: int) -> bool:
	if _inside(x, y):
		return maze[y][x] == "#"
	# outside the maze: city blocks of 3x3 buildings split by roads
	return posmod(x, 4) != 1 and posmod(y, 4) != 1


func _rand(x: int, y: int, salt: int) -> int:
	return posmod(hash(Vector3i(x, y, salt)), 1000)


func _building_id(x: int, y: int) -> int:
	# neighbouring wall cells in a row share one building (2-3 cells wide)
	return _rand(floori(x / 3.0), y, 7)


func _is_park(x: int, y: int) -> bool:
	return _rand(floori(x / 3.0), y, 11) < 90


func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(origin + Vector2(x, y) * tile, Vector2(tile, tile))


# ------------------------------------------------------------- drawing
func _draw() -> void:
	if maze.is_empty():
		return
	var cells := []
	for y in range(-OUTSKIRTS, maze.size() + OUTSKIRTS):
		for x in range(-OUTSKIRTS, _columns() + OUTSKIRTS):
			cells.append(Vector2i(x, y))
	for c in cells:
		if not _is_building(c.x, c.y):
			_draw_road(c.x, c.y)
	for c in cells:
		if _is_building(c.x, c.y):
			_draw_building(c.x, c.y)
	for c in cells:
		if not _is_building(c.x, c.y):
			_draw_street_props(c.x, c.y)


func _draw_road(x: int, y: int) -> void:
	var r := _cell_rect(x, y)
	draw_rect(r, ASPHALT if (x + y) % 2 == 0 else ASPHALT_DARK)
	var up := _is_building(x, y - 1)
	var down := _is_building(x, y + 1)
	var left := _is_building(x - 1, y)
	var right := _is_building(x + 1, y)
	var walk := tile * 0.16
	# sidewalks along every building edge
	if up:
		draw_rect(Rect2(r.position, Vector2(tile, walk)), SIDEWALK)
		draw_rect(Rect2(r.position + Vector2(0, walk - 1), Vector2(tile, 1)), CURB)
		draw_rect(Rect2(r.position + Vector2(0, walk), Vector2(tile, tile * 0.12)), SHADOW)
	if down:
		draw_rect(Rect2(r.position + Vector2(0, tile - walk), Vector2(tile, walk)), SIDEWALK)
		draw_rect(Rect2(r.position + Vector2(0, tile - walk), Vector2(tile, 1)), CURB)
	if left:
		draw_rect(Rect2(r.position, Vector2(walk, tile)), SIDEWALK)
		draw_rect(Rect2(r.position + Vector2(walk - 1, 0), Vector2(1, tile)), CURB)
	if right:
		draw_rect(Rect2(r.position + Vector2(tile - walk, 0), Vector2(walk, tile)), SIDEWALK)
		draw_rect(Rect2(r.position + Vector2(tile - walk, 0), Vector2(1, tile)), CURB)
	# dashed centre line on straight streets
	var mid := r.get_center()
	if up and down and not left and not right:
		draw_rect(Rect2(mid + Vector2(-tile * 0.3, -1), Vector2(tile * 0.25, 2)), LANE)
		draw_rect(Rect2(mid + Vector2(tile * 0.1, -1), Vector2(tile * 0.25, 2)), LANE)
	elif left and right and not up and not down:
		draw_rect(Rect2(mid + Vector2(-1, -tile * 0.3), Vector2(2, tile * 0.25)), LANE)
		draw_rect(Rect2(mid + Vector2(-1, tile * 0.1), Vector2(2, tile * 0.25)), LANE)
	elif not up and not down and not left and not right:
		# crossing: zebra stripes
		for i in 4:
			draw_rect(Rect2(r.position + Vector2(tile * (0.2 + i * 0.17), tile * 0.42), Vector2(tile * 0.09, tile * 0.16)),
				Color(0.9, 0.9, 0.9, 0.55))


func _draw_building(x: int, y: int) -> void:
	var r := _cell_rect(x, y)
	if _is_park(x, y):
		_draw_park(x, y, r)
		return
	var id := _building_id(x, y)
	var roof: Color = ROOFS[id % ROOFS.size()]
	draw_rect(r, roof)
	# corrugated GI sheet lines
	var step := tile / 8.0
	for i in 8:
		draw_rect(Rect2(r.position + Vector2(i * step, 0), Vector2(1, tile)), roof.darkened(0.18))
	# outline where this building meets a different one
	if not _is_building(x - 1, y) or _building_id(x - 1, y) != id or _is_park(x - 1, y):
		draw_rect(Rect2(r.position, Vector2(2, tile)), roof.darkened(0.45))
	if not _is_building(x + 1, y) or _building_id(x + 1, y) != id or _is_park(x + 1, y):
		draw_rect(Rect2(r.position + Vector2(tile - 2, 0), Vector2(2, tile)), roof.darkened(0.45))
	if not _is_building(x, y - 1):
		draw_rect(Rect2(r.position, Vector2(tile, 2)), roof.darkened(0.45))
	# roof extras: water tank or aircon
	var extra := _rand(x, y, 3)
	if extra < 120:
		draw_circle(r.position + Vector2(tile * 0.35, tile * 0.3), tile * 0.13, Color(0.2, 0.4, 0.8))
		draw_circle(r.position + Vector2(tile * 0.35, tile * 0.3), tile * 0.07, Color(0.35, 0.55, 0.9))
	elif extra < 220:
		draw_rect(Rect2(r.position + Vector2(tile * 0.55, tile * 0.18), Vector2(tile * 0.25, tile * 0.18)), Color(0.85, 0.85, 0.85))
	# front wall facing the street below (top-down with a little tilt)
	if not _is_building(x, y + 1):
		_draw_facade(x, y, r, id)


func _draw_facade(x: int, y: int, r: Rect2, id: int) -> void:
	var h := tile * 0.42
	var wall := Rect2(r.position + Vector2(0, tile - h), Vector2(tile, h))
	var paint: Color = FACADES[_rand(floori(x / 3.0), y, 5) % FACADES.size()]
	draw_rect(wall, paint)
	draw_rect(Rect2(wall.position, Vector2(tile, 2)), paint.darkened(0.35))   # roof edge
	var kind := _rand(x, y, 9)
	if kind < 220:
		# sari-sari store: striped awning and a wire-mesh counter
		for i in 5:
			var c := Color(0.85, 0.15, 0.15) if i % 2 == 0 else Color(0.97, 0.97, 0.95)
			draw_rect(Rect2(wall.position + Vector2(i * tile / 5.0, 2), Vector2(tile / 5.0, h * 0.3)), c)
		var counter := Rect2(wall.position + Vector2(tile * 0.15, h * 0.42), Vector2(tile * 0.7, h * 0.5))
		draw_rect(counter, Color(0.3, 0.22, 0.14))
		for i in 6:
			draw_rect(Rect2(counter.position + Vector2(i * counter.size.x / 6.0, 0), Vector2(1, counter.size.y)), Color(0.7, 0.7, 0.7))
	elif kind < 450:
		# door
		draw_rect(Rect2(wall.position + Vector2(tile * 0.36, h * 0.3), Vector2(tile * 0.28, h * 0.7)), Color(0.42, 0.26, 0.14))
	else:
		# two windows (capiz-style panes)
		for wx in [0.14, 0.58]:
			var win := Rect2(wall.position + Vector2(tile * wx, h * 0.3), Vector2(tile * 0.28, h * 0.42))
			draw_rect(win, WINDOW if kind < 750 else Color(0.93, 0.88, 0.72))
			draw_rect(Rect2(win.position + Vector2(win.size.x / 2.0, 0), Vector2(1, win.size.y)), paint.darkened(0.3))


func _draw_park(x: int, y: int, r: Rect2) -> void:
	draw_rect(r, GRASS)
	draw_rect(Rect2(r.position, Vector2(tile, 2)), GRASS.darkened(0.3))
	var off := Vector2(_rand(x, y, 1) % 10 - 5, _rand(x, y, 2) % 10 - 5)
	var c := r.get_center() + off
	draw_circle(c + Vector2(2, 3), tile * 0.34, Color(0, 0, 0, 0.25))
	draw_circle(c, tile * 0.34, Color(0.16, 0.42, 0.18))
	draw_circle(c - Vector2(tile * 0.08, tile * 0.08), tile * 0.2, Color(0.24, 0.55, 0.24))


func _draw_street_props(x: int, y: int) -> void:
	var r := _cell_rect(x, y)
	# electric posts on the sidewalk, with a sagging wire to the next post
	if _is_building(x, y - 1) and posmod(x, 3) == 0 and _rand(x, y, 13) < 700:
		var post := r.position + Vector2(tile * 0.5, tile * 0.08)
		var next := post + Vector2(tile * 3, 0)
		if not _is_building(x + 3, y) and _is_building(x + 3, y - 1):
			var sag := post.lerp(next, 0.5) + Vector2(0, tile * 0.18)
			draw_polyline([post, sag, next], Color(0.05, 0.05, 0.05, 0.7), 1.0)
		draw_circle(post, tile * 0.08, Color(0.45, 0.35, 0.25))
		draw_rect(Rect2(post - Vector2(tile * 0.18, 1), Vector2(tile * 0.36, 2)), Color(0.3, 0.24, 0.18))
	# parked jeepneys and tricycles on the streets outside the maze
	if not _inside(x, y) and _rand(x, y, 17) < 70:
		var horizontal := _is_building(x, y - 1) and _is_building(x, y + 1)
		if horizontal:
			_draw_jeepney(r.get_center(), _rand(x, y, 19))
		elif _is_building(x - 1, y) and _is_building(x + 1, y):
			_draw_tricycle(r.get_center(), _rand(x, y, 19))


func _draw_jeepney(center: Vector2, variant: int) -> void:
	var body := Rect2(center - Vector2(tile * 0.45, tile * 0.2), Vector2(tile * 0.9, tile * 0.4))
	var paint: Color = [Color(0.95, 0.95, 0.9), Color(0.2, 0.55, 0.85), Color(0.9, 0.3, 0.2)][variant % 3]
	draw_rect(Rect2(body.position + Vector2(2, 3), body.size), Color(0, 0, 0, 0.3))
	draw_rect(body, paint)
	draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.4), Vector2(body.size.x, 3)), Color(0.95, 0.75, 0.1))
	draw_rect(Rect2(body.position + Vector2(body.size.x * 0.78, 1), Vector2(body.size.x * 0.2, body.size.y - 2)), Color(0.55, 0.6, 0.65))
	draw_circle(body.position + Vector2(body.size.x * 0.93, body.size.y * 0.5), 2.0, Color(0.85, 0.85, 0.85))


func _draw_tricycle(center: Vector2, variant: int) -> void:
	var paint: Color = [Color(0.85, 0.15, 0.15), Color(0.15, 0.4, 0.8), Color(0.95, 0.7, 0.1)][variant % 3]
	draw_rect(Rect2(center - Vector2(tile * 0.14, tile * 0.22), Vector2(tile * 0.28, tile * 0.44)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(center - Vector2(tile * 0.16, tile * 0.24), Vector2(tile * 0.24, tile * 0.3)), paint)
	draw_rect(Rect2(center + Vector2(-tile * 0.04, tile * 0.04), Vector2(tile * 0.08, tile * 0.18)), Color(0.15, 0.15, 0.15))
