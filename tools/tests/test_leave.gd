extends SceneTree
# Leave button test. ROLE=solo | host | client  (run host and client together)
#   solo:   two taps on LEAVE -> title screen
#   client: LEAVE locked during the round; after the host leaves mid-round,
#           the client stays on the end screen "GAME OVER — THE HOST LEFT"
#   host:   starts a 2-player LAN game, then leaves mid-round (two taps)
var role := OS.get_environment("ROLE")
var frames := 0
var game
var done_tap := false
var t_round := -1

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var net = root.get_node("Network")
	root.get_node("GameState").player_name = role.capitalize()
	match role:
		"solo":
			net.play_solo(true, 1)
			change_scene_to_file("res://scenes/maze_game.tscn")
		"host":
			print("host_game: ", net.host_game())
		"client":
			print("join_game: ", net.join_game("127.0.0.1"))

func _process(_d: float) -> bool:
	frames += 1
	var net = root.get_node("Network")
	var gs = root.get_node("GameState")
	if role == "host" and (current_scene == null or current_scene.name != "MazeGame") and net.players.size() >= 2 and not net.game_started:
		print("host: 2 players, starting")
		net.start_game()
	if current_scene and current_scene.name == "MazeGame":
		game = current_scene
	if game == null or not is_instance_valid(game):
		if role in ["solo", "client"] and t_round >= 0 and current_scene and current_scene.name == "TitleScreen":
			print(role, ": back on the title screen, message: '", current_scene.get_node("Menu/ErrorLabel").text, "'")
			return true
		return frames > 60 * 40
	if gs.round_state == gs.RoundState.PLAYING and t_round < 0:
		t_round = frames
	if t_round < 0:
		return frames > 60 * 40
	var leave_btn = game.get_node("HUD/TopBar/LeaveButton")
	match role:
		"solo":
			if frames == t_round + 30:
				game._on_leave_pressed()
				print("solo: after 1st tap still in game: ", current_scene.name, " msg: ", game.message_label.text)
			if frames == t_round + 40:
				game._on_leave_pressed()
		"client":
			if frames == t_round + 30:
				print("client: leave disabled during round = ", leave_btn.disabled)
				game._on_leave_pressed()
				print("client: pressed anyway -> still in game: ", current_scene.name == "MazeGame", " msg: ", game.message_label.text)
			if game.end_panel.visible and not done_tap:
				done_tap = true
				t_round = frames
			if done_tap and frames == t_round + 90:
				print("client END: ", game.get_node("HUD/EndPanel/Margin/VBox/ResultLabel").text, " | ",
					game.get_node("HUD/EndPanel/Margin/VBox/StatsLabel").text.replace("\n", " / "),
					" | menu button: ", game.menu_button.text, " | leave disabled: ", leave_btn.disabled,
					" | still in game scene: ", current_scene.name == "MazeGame")
				return true
		"host":
			if frames == t_round + 180:
				game._on_leave_pressed()
				print("host: 1st tap msg: ", game.message_label.text)
			if frames == t_round + 190:
				game._on_leave_pressed()
				print("host: 2nd tap")
			if frames > t_round + 260:
				return true
	return frames > 60 * 60
