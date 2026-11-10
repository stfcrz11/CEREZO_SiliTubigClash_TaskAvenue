extends SceneTree
var game
var frames := 0
var step := 0
var wait := 0
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	root.get_node("Network").play_solo(true, 1)
	change_scene_to_file("res://scenes/maze_game.tscn")
func _process(_d: float) -> bool:
	frames += 1
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		return false
	if frames < 20: return false
	var me = game.tubigs[0]
	var bot = game.silis[0]
	if game.my_question >= 0 and game.quiz_panel.visible and game.quiz_panel.can_answer:
		var q = game.questions[game.my_question]
		var right: int = q["order"].find(game._pool(q["pool"])[q["index"]]["answer"])
		print("  quiz ", q["kind"])
		game.quiz_panel._pick(right)
	if wait > 0:
		wait -= 1
		return false
	var stall = null
	var gate = null
	for st in game.stations:
		if st["kind"] == "stall" and stall == null: stall = st
		if st["kind"] == "gate" and gate == null: gate = st
	match step:
		0:
			var w = game.maze[0].length(); var h = game.maze.size()
			for st in game.stations:
				var c: Vector2i = st["cell"]
				var inside: bool = c.x >= 2 and c.y >= 2 and c.x < w - 2 and c.y < h - 2
				var on_road: bool = game.maze[c.y][c.x] != "#"
				print("STATION ", st["kind"], " ", c, " inside=", inside, " road=", on_road)
			var scroll_cells := []
			for sc in game.scrolls.values(): scroll_cells.append(game.world_to_cell(sc.position))
			print("scrolls ", scroll_cells)
			game.get_node("BotSili_%d" % bot.peer_id).set_physics_process(false)
			bot.force_position(game.cell_to_world(Vector2i(20, 7)))
			me.force_position(game.cell_to_world(stall["cell"]) + Vector2(5, 0))
			step = 1; wait = 3
		1:
			print("label: ", stall["label"].text, " visible=", stall["label"].visible, " touch use=", game.get_node("HUD/TouchControls").use_available)
			print("walking over the cooler without E -> question? ", game.my_question >= 0)
			Input.action_press("interact")
			step = 2; wait = 2
		2:
			Input.action_release("interact")
			step = 3; wait = 150
		3:
			print("shield=%.1f cooldown=%.1f" % [me.shield_time, stall["cooldown"]])
			me.immune_time = 0
			if gate:
				me.force_position(game.cell_to_world(gate["approach"][0]))
				step = 4; wait = 3
			else:
				return true
		4:
			print("gate label: ", gate["label"].text)
			Input.action_press("interact")
			step = 5; wait = 2
		5:
			Input.action_release("interact")
			step = 6; wait = 150
		6:
			print("after gate cell ", game.world_to_cell(me.global_position), " want ", gate["approach"][1])
			return true
	return frames > 3000
