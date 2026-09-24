extends Control
## Title screen: Host Game / Join Game (LAN), How to Play, Quit.


func _ready() -> void:
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


func _open_lobby(mode: String) -> void:
	GameState.lobby_mode = mode
	get_tree().change_scene_to_file(GameState.LOBBY_SCENE)
