extends Node
## Global singleton: current round state and scene paths. Also registers
## the movement keys (WASD or arrow keys, Space or Shift to sprint) so
## no manual Input Map setup is needed. Every player uses the same keys
## on their own device. On phones, the on-screen joystick and RUN button
## (scenes/touch_controls.gd) press these same actions.

signal touch_controls_changed

enum RoundState { READY, PLAYING, QUESTION, PAUSED, ENDED }

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const GAME_SCENE := "res://scenes/maze_game.tscn"
const SETTINGS_PATH := "user://player_settings.cfg"

var round_state: RoundState = RoundState.READY
var player_name: String = "Player"
## On-screen joystick + RUN button. On by default on phones / touch screens.
var touch_controls: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _ready() -> void:
	_load_settings()
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT, KEY_SPACE])
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		InputMap.action_set_deadzone(a, 0.15)   # small joystick tilts still move


func set_player_name(value: String) -> void:
	var cleaned := value.strip_edges()
	player_name = cleaned if not cleaned.is_empty() else "Player"
	_save("player", "name", player_name)


func set_touch_controls(on: bool) -> void:
	touch_controls = on
	_save("controls", "touch", on)
	touch_controls_changed.emit()


func _save(section: String, key: String, value) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)   # keep the other saved settings (e.g. audio)
	settings.set_value(section, key, value)
	settings.save(SETTINGS_PATH)


func _load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	var saved_name = settings.get_value("player", "name", "Player")
	if saved_name is String and not saved_name.strip_edges().is_empty():
		player_name = saved_name.strip_edges()
	touch_controls = settings.get_value("controls", "touch", touch_controls)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _notification(what: int) -> void:
	# Android back button = Esc: closes windows, and the host can pause.
	# (project.godot has quit_on_go_back off, so it doesn't quit the app.)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed in [true, false]:
			var e := InputEventAction.new()
			e.action = "ui_cancel"
			e.pressed = pressed
			Input.parse_input_event(e)
