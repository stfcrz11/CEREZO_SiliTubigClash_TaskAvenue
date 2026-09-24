extends Control
## LAN lobby. Host view: shows this device's IP and who has joined, with a
## Start button. Join view: lists games found on the network (auto
## discovery) and has an IP box as a fallback.

@onready var header: Label = $VBox/Header
@onready var info_label: Label = $VBox/InfoLabel
@onready var join_box: Control = $VBox/JoinBox
@onready var found_list: VBoxContainer = $VBox/JoinBox/FoundList
@onready var ip_edit: LineEdit = $VBox/JoinBox/IpRow/IpEdit
@onready var players_label: Label = $VBox/PlayersLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var start_button: Button = $VBox/Buttons/StartButton

var hosting: bool = false


const ButtonStyle := preload("res://scenes/ui_button_style.gd")

func _ready() -> void:
	hosting = GameState.lobby_mode == "host"
	ButtonStyle.style_primary(start_button, Color(0.2, 0.72, 0.9))
	ButtonStyle.style_secondary($VBox/Buttons/BackButton, Color(0.38, 0.38, 0.46))
	ButtonStyle.style_secondary($VBox/JoinBox/IpRow/ConnectButton, Color(0.15, 0.47, 0.75))
	$VBox/Buttons/BackButton.pressed.connect(_on_back)
	start_button.pressed.connect(func(): Network.start_game())
	$VBox/JoinBox/IpRow/ConnectButton.pressed.connect(func(): _connect_to(ip_edit.text))
	ip_edit.text_submitted.connect(_connect_to)
	Network.players_changed.connect(_refresh_players)
	Network.connected_to_host.connect(_on_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.hosts_found_changed.connect(_refresh_found)

	if hosting:
		header.text = "Host Game"
		join_box.visible = false
		if Network.host_game() != OK:
			status_label.text = Network.last_error
			start_button.disabled = true
			return
		var ips := Network.local_ips()
		info_label.text = "Other players: choose Join Game on the same Wi-Fi / hotspot.\nYour IP: %s" % \
			(", ".join(ips) if not ips.is_empty() else "(not on a network)")
		status_label.text = "Waiting for players... (need at least %d)" % Network.MIN_PLAYERS
	else:
		header.text = "Join Game"
		start_button.visible = false
		info_label.text = "Looking for games on this network..."
		Network.leave()
		Network.start_listening()
		_refresh_found()
	_refresh_players()


func _connect_to(ip: String) -> void:
	if ip.strip_edges().is_empty():
		status_label.text = "Type the host's IP first."
		return
	status_label.text = "Connecting to %s ..." % ip
	if Network.join_game(ip) != OK:
		status_label.text = Network.last_error


func _on_connection_failed(reason: String) -> void:
	status_label.text = reason


func _on_connected() -> void:
	Network.stop_listening()
	join_box.visible = false
	info_label.text = "Connected!"
	status_label.text = "Waiting for the host to start..."


func _refresh_found() -> void:
	for c in found_list.get_children():
		c.queue_free()
	if Network.found_hosts.is_empty():
		var l := Label.new()
		l.text = "(no games found yet — you can type the IP below)"
		l.modulate = Color(1, 1, 1, 0.6)
		found_list.add_child(l)
		return
	for ip in Network.found_hosts:
		var b := Button.new()
		b.text = "Join %s   (%d/%d players)" % [ip, Network.found_hosts[ip]["players"], Network.MAX_PLAYERS]
		b.custom_minimum_size = Vector2(0, 40)
		ButtonStyle.style_secondary(b, Color(0.18, 0.52, 0.78))
		b.pressed.connect(_connect_to.bind(ip))
		found_list.add_child(b)


func _refresh_players() -> void:
	var lines := []
	for id in Network.sorted_ids():
		var tag := ""
		if id == 1:
			tag += " (Host)"
		if id == multiplayer.get_unique_id():
			tag += " (You)"
		lines.append("%s%s" % [Network.player_name_of(id), tag])
	var n := Network.players.size()
	var silis := Network.sili_count_for(max(n, Network.MIN_PLAYERS))
	players_label.text = "Players (%d/%d):\n%s\n\nRoles: 2-4 players = 1 Sili, 5-6 players = 2 Silis.\nThis game: %d Sili, %d Tubig. The Sili role rotates every round." % \
		[n, Network.MAX_PLAYERS, "\n".join(lines), silis, max(n - silis, 0)]
	if hosting:
		start_button.disabled = n < Network.MIN_PLAYERS
		status_label.text = "Press Start when everyone has joined." if n >= Network.MIN_PLAYERS \
			else "Waiting for players... (need at least %d)" % Network.MIN_PLAYERS


func _on_back() -> void:
	Network.stop_listening()
	Network.leave()
	get_tree().change_scene_to_file(GameState.TITLE_SCENE)
