extends Control
## Title screen: Host Game / Join Game (LAN), How to Play, Quit.


const ButtonStyle := preload("res://scenes/ui_button_style.gd")

func _ready() -> void:
	ButtonStyle.style_primary($Menu/HostButton, Color(0.18, 0.72, 0.9))
	ButtonStyle.style_secondary($Menu/JoinButton, Color(0.12, 0.38, 0.66))
	ButtonStyle.style_secondary($Menu/HowToButton, Color(0.3, 0.52, 0.3))
	ButtonStyle.style_secondary($Menu/QuitButton, Color(0.7, 0.22, 0.24))
	ButtonStyle.style_secondary($HowToPanel/Margin/VBox/CloseButton, Color(0.38, 0.38, 0.46))
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name
	$Menu/PlayerNameRow/PlayerNameInput.text_changed.connect(_on_player_name_changed)
	$Menu/PlayerNameRow/PlayerNameInput.focus_exited.connect(_normalize_player_name)
	$Menu/HostButton.pressed.connect(_open_lobby.bind("host"))
	$Menu/JoinButton.pressed.connect(_open_lobby.bind("join"))
	$Menu/HowToButton.pressed.connect(func(): $HowToPanel.visible = true)
	$Menu/QuitButton.pressed.connect(func(): get_tree().quit())
	$HowToPanel/Margin/VBox/CloseButton.pressed.connect(func(): $HowToPanel.visible = false)
	$HowToPanel.visible = false
	get_tree().paused = false
	# show why we came back here (e.g. the host left)
	$Menu/ErrorLabel.text = Network.last_error
	Network.last_error = ""


func _on_player_name_changed(value: String) -> void:
	if not value.strip_edges().is_empty():
		GameState.set_player_name(value)


func _normalize_player_name() -> void:
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name


func _open_lobby(mode: String) -> void:
	GameState.lobby_mode = mode
	get_tree().change_scene_to_file(GameState.LOBBY_SCENE)
