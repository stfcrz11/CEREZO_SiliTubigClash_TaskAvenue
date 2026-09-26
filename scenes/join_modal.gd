extends "res://scenes/store_modal.gd"
## JOIN A GAME window (scenes/join_modal.tscn): games found nearby, the
## type-an-IP box, and after connecting the player slots.
## To customize: open join_modal.tscn, click "JoinModal" for the texts and
## colors in the Inspector, or click any node to change its look.
## FoundList/GameTemplate is ONE found game: the game copies it.

@export_group("Texts")
@export var join_hint_text: String = "Pick a game or type an IP"
@export var connecting_text: String = "Connecting..."
@export var connected_text: String = "Connected! Waiting for host..."
@export var type_ip_text: String = "Type an IP first"
@export var no_games_text: String = "No games yet"
@export var game_name_text: String = "%s's game"              # %s = host's name

var connected: bool = false
var _dots_time: float = 0.0

@onready var find_card: Control = $Center/Store/Body/VBox/FindCard
@onready var searching: Label = $Center/Store/Body/VBox/FindCard/VBox/Header/Searching
@onready var found_list: VBoxContainer = $Center/Store/Body/VBox/FindCard/VBox/FoundList
@onready var game_template: Control = $Center/Store/Body/VBox/FindCard/VBox/FoundList/GameTemplate
@onready var ip_card: Control = $Center/Store/Body/VBox/IpCard
@onready var ip_edit: LineEdit = $Center/Store/Body/VBox/IpCard/VBox/IpRow/IpEdit


func _ready() -> void:
	super()
	game_template.visible = false   # the template is copied, never shown
	$Center/Store/Body/VBox/IpCard/VBox/IpRow/ConnectButton.pressed.connect(func(): _connect_to(ip_edit.text))
	ip_edit.text_submitted.connect(_connect_to)
	Network.connected_to_host.connect(_on_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.hosts_found_changed.connect(_refresh_found)


func open() -> void:
	connected = false
	Network.leave()
	Network.start_listening()
	_show_parts()
	_set_status(join_hint_text, hint_color)
	_refresh_found()


func _show_parts() -> void:
	# before connecting: games list + IP box. After: the player slots.
	find_card.visible = not connected
	ip_card.visible = not connected
	players_card.visible = connected
	visible = true


func _process(delta: float) -> void:
	if visible and find_card.visible:
		_dots_time += delta
		searching.text = "Searching" + ".".repeat(1 + int(_dots_time * 2.0) % 3)


func _connect_to(ip: String) -> void:
	ip = ip.strip_edges()
	if ip.is_empty():
		_set_status(type_ip_text, error_color)
		return
	_set_status(connecting_text, waiting_color)
	if Network.join_game(ip) != OK:
		_set_status(Network.last_error, error_color)


func _on_connection_failed(reason: String) -> void:
	if visible:
		_set_status(reason, error_color)


func _on_connected() -> void:
	if not visible:
		return
	Network.stop_listening()
	connected = true
	_show_parts()
	_set_status(connected_text, good_color)
	_refresh_players()


func _refresh_found() -> void:
	if not visible or connected:
		return
	_clear(found_list, game_template)
	if Network.found_hosts.is_empty():
		var empty := Label.new()
		empty.text = no_games_text
		empty.add_theme_color_override("font_color", hint_color)
		empty.add_theme_font_size_override("font_size", 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		found_list.add_child(empty)
	else:
		for id in Network.found_hosts:
			var info: Dictionary = Network.found_hosts[id]
			found_list.add_child(_game_row(info["ip"], info))


func _game_row(ip: String, info: Dictionary) -> Control:
	# a copy of FoundList/GameTemplate filled in for one found game
	var row := game_template.duplicate()
	row.visible = true
	var host_name: String = info.get("name", "")
	var full: bool = info["players"] >= Network.MAX_PLAYERS
	row.get_node("HBox/Texts/Name").text = (game_name_text % host_name) if not host_name.is_empty() else ip
	row.get_node("HBox/Texts/Info").text = "%d/%d%s" % [info["players"], Network.MAX_PLAYERS, "  FULL" if full else ""]
	var join: TextureButton = row.get_node("HBox/JoinButton")
	join.disabled = full
	join.pressed.connect(_connect_to.bind(ip))
	return row
