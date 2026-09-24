extends Node
## Global singleton: current round state and scene paths. Also registers
## the movement keys (WASD or arrow keys, Space or Shift to sprint) so
## no manual Input Map setup is needed. Every player uses the same keys
## on their own device.

enum RoundState { READY, PLAYING, QUESTION, PAUSED, ENDED }

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const GAME_SCENE := "res://scenes/maze_game.tscn"

var round_state: RoundState = RoundState.READY
var lobby_mode: String = "host"   # "host" or "join" when opening the lobby


func _ready() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT, KEY_SPACE])


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
