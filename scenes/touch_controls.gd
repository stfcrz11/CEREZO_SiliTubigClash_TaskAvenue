extends Control
## On-screen controls for phones and tablets (shown when "Touch controls"
## is on in Settings; on by default on touch screens).
##  - Joystick: touch anywhere on the RIGHT half of the screen and drag.
##  - RUN button (bottom left): hold to sprint.
## They press the same input actions as the keyboard (move_left/right/up/
## down, sprint), so player.gd needs no changes.
## They only work while you can move (round playing, no window open).

@export var joystick_radius: float = 70.0
@export var knob_radius: float = 30.0
@export var run_radius: float = 46.0
@export var base_color: Color = Color(1, 1, 1, 0.16)
@export var knob_color: Color = Color(1, 1, 1, 0.45)
@export var run_color: Color = Color(0.29, 0.64, 0.91, 0.55)

## Set by maze_game.gd: returns true while a window covers the game.
var is_blocked: Callable = func(): return false
## Set by maze_game.gd: screen areas the joystick must leave alone
## (e.g. the help alert's YES / NO buttons).
var excluded_rects: Callable = func(): return []

var _stick_touch := -1          # finger index on the joystick (-1 = none)
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _run_touch := -1            # finger index on RUN
var _blocked_until := 0         # msec: ignore new touches until then


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = GameState.touch_controls
	GameState.touch_controls_changed.connect(func():
		visible = GameState.touch_controls
		if not visible:
			_release_all())


func _stick_home() -> Vector2:
	return Vector2(size.x - 130, size.y - 130)


func _run_center() -> Vector2:
	return Vector2(110, size.y - 120)


func _is_excluded(pos: Vector2) -> bool:
	for r in excluded_rects.call():
		if r.has_point(pos):
			return true
	return false


func _active() -> bool:
	return visible and GameState.round_state == GameState.RoundState.PLAYING and not is_blocked.call()


func _process(_delta: float) -> void:
	if not _active():
		# the tap that closes a window must not also start walking
		_blocked_until = Time.get_ticks_msec() + 150
		if _stick_touch != -1 or _run_touch != -1:
			_release_all()   # e.g. a question opened while holding the joystick
	if visible:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		if event.pressed and Time.get_ticks_msec() < _blocked_until:
			return
		if event.pressed:
			if _run_touch == -1 and event.position.distance_to(_run_center()) <= run_radius * 1.4:
				_run_touch = event.index
				Input.action_press("sprint")
				get_viewport().set_input_as_handled()
			elif _stick_touch == -1 and event.position.x > size.x * 0.5 and event.position.y > 50 					and not _is_excluded(event.position):
				_stick_touch = event.index
				_stick_center = event.position     # the joystick appears under your thumb
				_move_stick(event.position)
				get_viewport().set_input_as_handled()
		else:
			if event.index == _stick_touch:
				_release_stick()
			if event.index == _run_touch:
				_run_touch = -1
				Input.action_release("sprint")
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()


func _move_stick(pos: Vector2) -> void:
	_stick_vec = (pos - _stick_center) / joystick_radius
	if _stick_vec.length() > 1.0:
		_stick_vec = _stick_vec.normalized()
	_set_action("move_left", -_stick_vec.x)
	_set_action("move_right", _stick_vec.x)
	_set_action("move_up", -_stick_vec.y)
	_set_action("move_down", _stick_vec.y)


func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_stick() -> void:
	_stick_touch = -1
	_stick_vec = Vector2.ZERO
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _release_all() -> void:
	_release_stick()
	if _run_touch != -1:
		Input.action_release("sprint")
	_run_touch = -1


func _draw() -> void:
	if not _active():
		return
	var c := _stick_center if _stick_touch != -1 else _stick_home()
	draw_circle(c, joystick_radius, base_color)
	draw_arc(c, joystick_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(c + _stick_vec * joystick_radius, knob_radius, knob_color)
	var r := _run_center()
	var col := run_color.lightened(0.3) if _run_touch != -1 else run_color
	draw_circle(r, run_radius, col)
	draw_arc(r, run_radius, 0, TAU, 48, Color(1, 1, 1, 0.6), 3.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, r + Vector2(-w / 2.0, 7), "RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
