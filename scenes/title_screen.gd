extends Control
## Title screen: Host Game / Join Game (LAN), How to Play, Quit.
## Host Game and Join Game open the LobbyModal window on top of this screen.
## The title and the buttons are PNG pictures in assets/ui/ — replace those
## files (or drag new ones into the Inspector) to change how they look.


func _ready() -> void:
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name
	$Menu/PlayerNameRow/PlayerNameInput.text_changed.connect(_on_player_name_changed)
	$Menu/PlayerNameRow/PlayerNameInput.focus_exited.connect(_normalize_player_name)
	$Menu/HostButton.pressed.connect(func(): $LobbyModal.open_host())
	$Menu/JoinButton.pressed.connect(func(): $LobbyModal.open_join())
	$Menu/HowToButton.pressed.connect(_show_how_to.bind(true))
	$Menu/QuitButton.pressed.connect(func(): get_tree().quit())
	$HowToPanel/Margin/VBox/CloseButton.pressed.connect(_show_how_to.bind(false))
	_show_how_to(false)
	get_tree().paused = false
	# show why we came back here (e.g. the host left)
	$Menu/ErrorLabel.text = Network.last_error
	Network.last_error = ""


func _on_player_name_changed(value: String) -> void:
	if not value.strip_edges().is_empty():
		GameState.set_player_name(value)


func _normalize_player_name() -> void:
	$Menu/PlayerNameRow/PlayerNameInput.text = GameState.player_name


func _show_how_to(open: bool) -> void:
	$HowToPanel.visible = open
	$HowToDim.visible = open


func _unhandled_input(event: InputEvent) -> void:
	if $HowToPanel.visible and event.is_action_pressed("ui_cancel"):
		_show_how_to(false)
		get_viewport().set_input_as_handled()
