extends SceneTree
var game
var frames := 0
var shots := 0
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	root.get_node("Network").play_solo(true, 2)
	change_scene_to_file("res://scenes/maze_game.tscn")
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + n + ".png")
func _process(_d: float) -> bool:
	frames += 1
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		return false
	var me = game.tubigs[0] if not game.tubigs.is_empty() else null
	if me == null: return false
	var bot = game.silis[0]
	if frames == 40:
		game.get_node("BotSili_%d" % bot.peer_id).set_physics_process(false)
		var st = game.stations[0]
		me.force_position(game.cell_to_world(st["approach"][0]) + Vector2(0, 6))
		bot.force_position(me.global_position + Vector2(50, 0))
		bot.bot_move = Vector2(-1, 0)
		me.apply_effect("shield", 8.0)
		bot.apply_effect("turbo", 8.0)
	if frames == 70:
		_shot("game_stall")
	if frames == 90:
		var g = null
		for st in game.stations:
			if st["kind"] == "gate": g = st
		me.force_position(game.cell_to_world(g["approach"][0]))
		bot.force_position(me.global_position + Vector2(0, 600))
		game._tubig_caught(me.peer_id)
	if frames == 110:
		_shot("game_frozen")
	if frames == 130:
		game._host_end(true, "TUBIG TEAM WINS!")
	if frames == 150:
		_shot("game_end")
		print("button: ", game.play_again_button.text)
	return frames > 160
