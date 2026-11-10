extends SceneTree
# Repeatable perf scenario: Solo Round 4 (3 bots), Tubig idle at start,
# 60 s of play, window 1280x720. Prints one sample per second + averages.
var game
var t := 0.0
var samples := []
var load_ms := 0
var t0 := 0
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	root.get_node("Network").play_solo(true, 4)
	t0 = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/maze_game.tscn")
func _process(d: float) -> bool:
	if game == null:
		game = current_scene if current_scene and current_scene.name == "MazeGame" else null
		if game: load_ms = Time.get_ticks_msec() - t0
		return false
	# keep the round going: the Tubig can't be frozen for good
	for tb in game.tubigs: tb.immune_time = 5.0
	var off := OS.get_environment("OFF")
	if off == "minimap": game.minimap.visible = false; game.minimap.set_process(false)
	if off == "bots":
		for b in game._bots.values(): b.set_physics_process(false)
	if off == "hud": game.get_node("HUD").visible = false
	if off == "trails":
		for p in game.player_by_id.values(): p._trail.emitting = false; p._trail.visible = false; p.set_process(false)
	t += d
	if t >= 1.0 and samples.size() < 60:
		t = 0.0
		samples.append([Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if samples.size() >= 60:
		var n := float(samples.size())
		var sums := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var mins := 1e9
		for s in samples:
			for i in 7: sums[i] += s[i]
			mins = min(mins, s[0])
		print("scene load ms: ", load_ms)
		print("avg fps %.1f (min %d) | process %.2f ms | physics %.2f ms | static mem %.1f MB | draw calls %.0f | video mem %.1f MB | nodes %.0f" % [
			sums[0]/n, mins, sums[1]/n, sums[2]/n, sums[3]/n, sums[4]/n, sums[5]/n, sums[6]/n])
		print("adapter: ", RenderingServer.get_video_adapter_name(), " | ", OS.get_name(), " | ", DisplayServer.window_get_size())
		return true
	return false
