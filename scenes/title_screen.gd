extends Control
## Title screen: Play, How to Play, Leaderboard, Quit.
## PLAY opens the PLAY window (close: X, Esc, or click outside) with:
##   SOLO VS BOT  -> starts a round right away: you (Tubig) vs a Bot Sili
##   HOST GAME    -> opens HostModal (host_modal.tscn)
##   JOIN GAME    -> opens JoinModal (join_modal.tscn)
## The title and the buttons are PNG pictures in assets/ui/ — replace those
## files (or drag new ones into the Inspector) to change how they look.
## LEADERBOARD opens the TOP PLAYERS window (close: X, Esc, or click outside).
## It shows the leaderboard saved on this device
## (data/leaderboard.gd). Leaderboard/.../Rows/RowTemplate is ONE row: the
## script copies it for every player, so edit it to change every row.

const Leaderboard := preload("res://data/leaderboard.gd")
const MAX_ROWS := 20
const RANK_COLORS := [Color(1, 0.82, 0.3), Color(0.8, 0.84, 0.9), Color(0.85, 0.55, 0.3)]   # gold, silver, bronze


func _ready() -> void:
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name
	$Menu/PlayerNameRow/PlayerNameInput.text_changed.connect(_on_player_name_changed)
	$Menu/PlayerNameRow/PlayerNameInput.focus_exited.connect(_normalize_player_name)
	$Menu/PlayButton.pressed.connect(_show_play.bind(true))
	$PlayPanel/Margin/VBox/Header/CloseButton.pressed.connect(_show_play.bind(false))
	$PlayDim.gui_input.connect(_on_play_dim_input)
	$PlayPanel/Margin/VBox/SoloButton.pressed.connect(_start_solo)
	$PlayPanel/Margin/VBox/HostButton.pressed.connect(_open_lan_window.bind($HostModal))
	$PlayPanel/Margin/VBox/JoinButton.pressed.connect(_open_lan_window.bind($JoinModal))
	$Menu/HowToButton.pressed.connect(_show_how_to.bind(true))
	$Menu/QuitButton.pressed.connect(func(): get_tree().quit())
	$HowToPanel/Margin/VBox/CloseButton.pressed.connect(_show_how_to.bind(false))
	$Menu/LeaderboardButton.pressed.connect(_show_leaderboard.bind(true))
	$Leaderboard/Margin/VBox/Header/CloseButton.pressed.connect(_show_leaderboard.bind(false))
	$LeaderboardDim.gui_input.connect(_on_leaderboard_dim_input)
	$SettingsButton.pressed.connect(func(): $SettingsPanel.open())
	_show_how_to(false)
	_show_leaderboard(false)
	_show_play(false)
	Sound.play_music("title")   # keeps playing if it already is
	get_tree().paused = false
	# show why we came back here (e.g. the host left)
	$Menu/ErrorLabel.text = Network.last_error
	Network.last_error = ""


func _on_player_name_changed(value: String) -> void:
	if not value.strip_edges().is_empty():
		GameState.set_player_name(value)


func _normalize_player_name() -> void:
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name


func _show_play(open: bool) -> void:
	$PlayPanel.visible = open
	$PlayDim.visible = open


func _on_play_dim_input(event: InputEvent) -> void:
	# a click outside the window closes it
	if event is InputEventMouseButton and event.pressed:
		_show_play(false)


func _start_solo() -> void:
	Network.play_solo(true)   # you (Tubig) vs the Bot Sili
	get_tree().change_scene_to_file(GameState.GAME_SCENE)


func _open_lan_window(window: Control) -> void:
	_show_play(false)
	window.open()


func _show_leaderboard(open: bool) -> void:
	if open:
		_fill_leaderboard()   # always show the latest results
	$Leaderboard.visible = open
	$LeaderboardDim.visible = open


func _on_leaderboard_dim_input(event: InputEvent) -> void:
	# a click outside the window closes it
	if event is InputEventMouseButton and event.pressed:
		_show_leaderboard(false)


func _fill_leaderboard() -> void:
	var rows: VBoxContainer = $Leaderboard/Margin/VBox/Scroll/Rows
	var template: Control = rows.get_node("RowTemplate")
	template.visible = false   # the template is copied, never shown
	for old in rows.get_children():
		if old != template:
			old.queue_free()
	var ranking := Leaderboard.rankings()
	$Leaderboard/Margin/VBox/Empty.visible = ranking.is_empty()
	for i in min(ranking.size(), MAX_ROWS):
		var r: Dictionary = ranking[i]
		var row := template.duplicate()
		row.visible = true
		row.get_node("HBox/Rank").text = str(i + 1)
		row.get_node("HBox/Name").text = r["name"]
		row.get_node("HBox/Wins").text = str(r["wins"])
		row.get_node("HBox/Points").text = str(r["points"])
		var rank_color: Color = RANK_COLORS[i] if i < RANK_COLORS.size() else Color(0.62, 0.66, 0.76)
		row.get_node("HBox/Rank").add_theme_color_override("font_color", rank_color)
		if r["name"].to_lower() == GameState.player_name.to_lower():
			row.get_node("HBox/Name").add_theme_color_override("font_color", Color(1, 0.88, 0.35))   # you
		row.tooltip_text = "%s — %d games, %d wins, %d points" % [r["name"], r["games"], r["wins"], r["points"]]
		rows.add_child(row)


func _show_how_to(open: bool) -> void:
	$HowToPanel.visible = open
	$HowToDim.visible = open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if $PlayPanel.visible:
		_show_play(false)
		get_viewport().set_input_as_handled()
	elif $HowToPanel.visible:
		_show_how_to(false)
		get_viewport().set_input_as_handled()
	elif $Leaderboard.visible:
		_show_leaderboard(false)
		get_viewport().set_input_as_handled()
