extends Node
## Global singleton: current round state and scene paths. Also registers
## the movement keys (WASD or arrow keys, Space or Shift to sprint) so
## no manual Input Map setup is needed. Every player uses the same keys
## on their own device.

enum RoundState { READY, PLAYING, QUESTION, PAUSED, ENDED }

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const GAME_SCENE := "res://scenes/maze_game.tscn"
const SETTINGS_PATH := "user://player_settings.cfg"

var round_state: RoundState = RoundState.READY
var player_name: String = "Player"


func _ready() -> void:
	_load_settings()
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT, KEY_SPACE])


func set_player_name(value: String) -> void:
	var cleaned := value.strip_edges()
	player_name = cleaned if not cleaned.is_empty() else "Player"
	var settings := ConfigFile.new()
	settings.set_value("player", "name", player_name)
	settings.save(SETTINGS_PATH)


func _load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	var saved_name = settings.get_value("player", "name", "Player")
	if saved_name is String and not saved_name.strip_edges().is_empty():
		player_name = saved_name.strip_edges()


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
