extends SceneTree
func _initialize() -> void:
	var bad := 0
	for path in ["res://scenes/player.gd", "res://scenes/bot_sili.gd", "res://scenes/maze_game.gd", "res://autoloads/network.gd",
			"res://data/questions.gd", "res://scenes/quiz_panel.gd", "res://scenes/answer_popup.gd", "res://scenes/minimap.gd",
			"res://scenes/title_screen.gd", "res://scenes/title_runners.gd", "res://scenes/touch_controls.gd", "res://scenes/settings_panel.gd", "res://autoloads/game_state.gd", "res://data/leaderboard.gd", "res://scenes/ui_button_style.gd"]:
		var s = load(path)
		if s == null or not s.can_instantiate():
			print("FAILED: ", path)
			bad += 1
	var q = load("res://data/questions.gd")
	for list_name in ["QUESTIONS", "HARD", "BUGTONG"]:
		var list: Array = q.get(list_name) if q.get(list_name) != null else q.new().get(list_name)
		for e in list:
			if e["choices"].size() != 4 or e["answer"] < 0 or e["answer"] > 3:
				print("bad entry ", e["q"])
				bad += 1
		print(list_name, " ", list.size())
	print("script check done, problems: ", bad)
	quit()
