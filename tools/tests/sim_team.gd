extends SceneTree
# 3 players on one device (2 are fake): checks the rescue quiz and, with
# MODE=sili, the Bicol Express pepper for a human Sili.
var game
var frames := 0
var step := 0
var wait := 0
var mode := OS.get_environment("MODE")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var net = root.get_node("Network")
	net.leave()
	net.players = {1: 0, 5: 1, 6: 2}
	net.player_names = {1: "Me", 5: "Ana", 6: "Ben"}
	net.ready_peers = {5: true, 6: true}
	net.round_number = 0 if mode == "sili" else 2
	change_scene_to_file("res://scenes/maze_game.tscn")

func _press(dir: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x < 0: Input.action_press("move_left")
	if dir.x > 0: Input.action_press("move_right")
	if dir.y < 0: Input.action_press("move_up")
	if dir.y > 0: Input.action_press("move_down")

func _process(_d: float) -> bool:
	frames += 1
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		return false
	if frames < 20 or game.player_by_id.size() < 3:
		return false
	if game.my_question >= 0 and game.quiz_panel.visible and game.quiz_panel.can_answer:
		var q = game.questions[game.my_question]
		var right: int = q["order"].find(game._pool(q["pool"])[q["index"]]["answer"])
		print("  quiz ", q["kind"], ": ", game.quiz_panel.header_label.text, " | Q: ", game.quiz_panel.question_label.text.left(60))
		game.quiz_panel._pick(right)
	if wait > 0:
		wait -= 1
		return false
	var me = game.player_by_id[1]
	if mode == "sili":
		var pepper = null
		for st in game.stations:
			if st["kind"] == "pepper": pepper = st
		match step:
			0:
				print("me role: ", me.role)
				me.force_position(game.cell_to_world(pepper["approach"][0]))
				_press(Vector2(pepper["cell"] - pepper["approach"][0]))
				step = 1
				wait = 20
			1:
				_press(Vector2.ZERO)
				if me.turbo_time > 0.0:
					print("turbo=%.1f tag radius=%.1f effect: %s" % [me.turbo_time, game.tag_radius_of(me), me.effect_text()])
					return true
		return frames > 60 * 30
	var ana = game.player_by_id[5]
	match step:
		0:
			print("roles: me=", me.role, " ana=", ana.role, " ben=", game.player_by_id[6].role)
			game.player_by_id[6].force_position(game.cell_to_world(Vector2i(20, 7)))
			game._tubig_caught.rpc(5)
			me.force_position(ana.global_position + Vector2(40, 0))
			step = 1
			wait = 90
		1:
			print("ana frozen=", ana.frozen, " frozen_time=%.1f" % ana.frozen_time)
			me.force_position(ana.global_position + Vector2(12, 0))
			step = 2
			wait = 200
		2:
			print("after rescue quiz: ana frozen=", ana.frozen, "  msg=", game.message_label.text, "  stats=", game._stats[1])
			return true
	return frames > 60 * 30
