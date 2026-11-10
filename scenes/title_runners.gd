extends Control
## Title-screen animation: Sili kids chase Tubig kids along the streets of
## the pixel city background (assets/backgrounds/title_city_pixel.png).
## Drawn with the same cover-fit as the Background TextureRect, so the kids
## stay on the roads at any screen shape.

const SILI := preload("res://assets/characters/sili_sheet.png")
const TUBIG := preload("res://assets/characters/tubig_sheet.png")
const BG_SIZE := Vector2(960, 640)   # the background picture's size
const CELL := 32
const RUN_ROW := 12                  # run animation, facing right (see player.gd)

## Each lane: road y in background pixels, direction, speed (px/s), start offset.
var lanes := [
	{"y": 560.0, "dir": 1, "speed": 120.0, "offset": 0.0},
	{"y": 176.0, "dir": -1, "speed": 95.0, "offset": 400.0},
	{"y": 368.0, "dir": 1, "speed": 105.0, "offset": 700.0},
]
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# same math as TextureRect STRETCH_KEEP_ASPECT_COVERED
	var s := maxf(size.x / BG_SIZE.x, size.y / BG_SIZE.y)
	var origin := (size - BG_SIZE * s) / 2.0
	var span := BG_SIZE.x + 260.0
	var frame := int(_t * 12.0) % 6
	for lane in lanes:
		# the Tubig runs ahead, the Sili chases 70 px behind
		var x: float = fposmod(lane["offset"] + _t * lane["speed"], span) - 130.0
		if lane["dir"] < 0:
			x = BG_SIZE.x - x
		var tubig_x: float = x
		var sili_x: float = x - 70.0 * lane["dir"]
		_draw_kid(TUBIG, origin, s, Vector2(tubig_x, lane["y"]), frame, lane["dir"] < 0)
		_draw_kid(SILI, origin, s, Vector2(sili_x, lane["y"]), (frame + 3) % 6, lane["dir"] < 0)


func _draw_kid(sheet: Texture2D, origin: Vector2, s: float, feet: Vector2, frame: int, flip: bool) -> void:
	var src := Rect2(frame * CELL, RUN_ROW * CELL, CELL, CELL)
	var w := CELL * s
	var pos := origin + (feet - Vector2(CELL / 2.0, CELL - 2.0)) * s
	var dst := Rect2(pos, Vector2(w, w))
	if flip:
		dst = Rect2(pos + Vector2(w, 0), Vector2(-w, w))
	draw_texture_rect_region(sheet, dst, src)
