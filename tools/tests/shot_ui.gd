extends SceneTree
# Screenshots of the title screen and every window on it.
var t
var frames := 0
var out := OS.get_environment("OUT")
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	change_scene_to_file("res://scenes/title_screen.tscn")
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
func _close_all() -> void:
	for n in ["PlayPanel", "PlayDim", "HowToPanel", "HowToDim", "Leaderboard", "LeaderboardDim"]:
		var node = t.get_node_or_null(n)
		if node: node.visible = false
	for n in ["HostModal", "JoinModal", "SettingsPanel", "CreditsPanel"]:
		var m = t.get_node_or_null(n)
		if m and m.visible:
			if m.has_method("close"): m.close()
			else: m.visible = false
func _process(_d: float) -> bool:
	frames += 1
	if t == null:
		t = current_scene
		return false
	match frames:
		20: _shot("title")
		25: t._show_play(true)
		35: _shot("play")
		40: _close_all(); t._show_how_to(true)
		50: _shot("howto")
		55: _close_all(); t._show_leaderboard(true)
		65: _shot("leaderboard")
		70: _close_all(); t.get_node("HostModal").open()
		85: _shot("host")
		90: _close_all(); t.get_node("JoinModal").open()
		105: _shot("join")
		110: _close_all(); t.get_node("SettingsPanel").open()
		120: _shot("settings")
		125:
			_close_all()
			if t.get_node_or_null("CreditsPanel"): t._show_credits(true)
		135: _shot("credits")
	return frames > 140
