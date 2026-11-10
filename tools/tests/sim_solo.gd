extends SceneTree
# Headless solo-vs-bot run. The Tubig stands still at its start spot;
# questions are answered automatically (correct). Prints what happens.
var game
var frames := 0
var last_state := -1
var log_t := 0.0
var round_no := int(OS.get_environment("SIM_ROUND")) if OS.get_environment("SIM_ROUND") != "" else 4

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var net = root.get_node_or_null("Network")
	print("autoload Network: ", net != null)
	net.play_solo(true, round_no)
	change_scene_to_file("res://scenes/maze_game.tscn")

func _process(delta: float) -> bool:
	frames += 1
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		if game:
			print("players: ", root.get_node("Network").players)
		return false
	var gs = root.get_node("GameState")
	if frames == 30:
		print("maze ", game.maze[0].length(), "x", game.maze.size(), " origin ", game.maze_origin)
		for st in game.stations:
			print("station ", st["kind"], " ", st["name"], " cell ", st["cell"], " approach ", st["approach"])
		print("silis ", game.silis.size(), " tubigs ", game.tubigs.size(), " bots ", game._bots.size())
	if game.my_question >= 0 and game.quiz_panel.visible and game.quiz_panel.can_answer:
		var q = game.questions[game.my_question]
		var right: int = q["order"].find(game._pool(q["pool"])[q["index"]]["answer"])
		print("  answering ", q["kind"], " ", q["extra"], " -> correct")
		game.quiz_panel._pick(right)
	if gs.round_state != last_state:
		print("t=%.1f state %s" % [frames / 60.0, gs.round_state])
		last_state = gs.round_state
	log_t += delta
	if log_t > 2.0:
		log_t = 0.0
		var t = game.tubigs[0] if not game.tubigs.is_empty() else null
		var s = ""
		for b in game.silis:
			s += " %s(%d,%d) d=%d" % [b.name, b.global_position.x, b.global_position.y, b.global_position.distance_to(t.global_position) if t else -1]
		for b in game.silis: print("   ", b.name, " ans=", b.answering, " turbo=", b.turbo_time, " move=", b.bot_move, " qs=", game._questions, " now=", Time.get_ticks_msec(), " intel=", game.bot_intel)
		print("t=%.1f tubig frozen=%s ans=%s | %s | msg: %s" % [frames / 60.0, t.frozen if t else null, t.answering if t else null, s, game.message_label.text])
	if gs.round_state == 4:
		print("END: ", game.get_node("HUD/EndPanel/Margin/VBox/ResultLabel").text, " | ", game.get_node("HUD/EndPanel/Margin/VBox/StatsLabel").text.replace("\n", " / "))
		print("button: ", game.play_again_button.text)
		return true
	return frames > 60 * 40
