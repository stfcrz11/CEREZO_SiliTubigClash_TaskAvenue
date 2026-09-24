extends Control
## Host / Join window that opens on top of the title screen (a "modal").
## Host: shows this device's IP, the 6 player slots and START GAME.
## Join: lists games found on the network, has an IP box as a fallback,
## and after connecting shows the player slots while waiting for the host.
## The look comes from assets/ui/ (panel.png, card.png, button PNGs).

const CARD := preload("res://assets/ui/card.png")
const JOIN_PNG := preload("res://assets/ui/button_join_small.png")
const PngButton := preload("res://scenes/png_button.gd")
const SLOT_COLORS := [Color(0.98, 0.82, 0.3), Color(0.35, 0.75, 1.0), Color(0.5, 0.9, 0.55),
	Color(0.9, 0.55, 1.0), Color(1.0, 0.6, 0.4), Color(0.6, 0.95, 0.95)]
const SILI_RED := Color(0.86, 0.24, 0.2)
const TUBIG_BLUE := Color(0.2, 0.5, 0.9)
const HINT := Color(0.7, 0.74, 0.82)
const ERROR := Color(1.0, 0.5, 0.45)
const OK_GREEN := Color(0.5, 0.95, 0.55)
const YELLOW := Color(1.0, 0.85, 0.4)

var hosting: bool = false
var connected: bool = false
var _dots_time: float = 0.0

@onready var title: Label = $Center/Panel/VBox/Header/Title
@onready var host_card: Control = $Center/Panel/VBox/HostCard
@onready var ip_label: Label = $Center/Panel/VBox/HostCard/VBox/IpLabel
@onready var ip_hint: Label = $Center/Panel/VBox/HostCard/VBox/Hint
@onready var find_card: Control = $Center/Panel/VBox/FindCard
@onready var searching: Label = $Center/Panel/VBox/FindCard/VBox/Header/Searching
@onready var found_list: VBoxContainer = $Center/Panel/VBox/FindCard/VBox/FoundList
@onready var ip_card: Control = $Center/Panel/VBox/IpCard
@onready var ip_edit: LineEdit = $Center/Panel/VBox/IpCard/VBox/IpRow/IpEdit
@onready var players_card: Control = $Center/Panel/VBox/PlayersCard
@onready var players_step: Label = $Center/Panel/VBox/PlayersCard/VBox/Header/Label
@onready var count_label: Label = $Center/Panel/VBox/PlayersCard/VBox/Header/Count
@onready var sili_chip: Label = $Center/Panel/VBox/PlayersCard/VBox/Header/SiliChip
@onready var tubig_chip: Label = $Center/Panel/VBox/PlayersCard/VBox/Header/TubigChip
@onready var slots: GridContainer = $Center/Panel/VBox/PlayersCard/VBox/Slots
@onready var status: Label = $Center/Panel/VBox/Status
@onready var start_button: TextureButton = $Center/Panel/VBox/Buttons/StartButton


func _ready() -> void:
	visible = false
	_chip(sili_chip, SILI_RED)
	_chip(tubig_chip, TUBIG_BLUE)
	$Center/Panel/VBox/Header/CloseButton.pressed.connect(close)
	$Center/Panel/VBox/Buttons/CancelButton.pressed.connect(close)
	start_button.pressed.connect(func(): Network.start_game())
	$Center/Panel/VBox/IpCard/VBox/IpRow/ConnectButton.pressed.connect(func(): _connect_to(ip_edit.text))
	ip_edit.text_submitted.connect(_connect_to)
	Network.players_changed.connect(_refresh_players)
	Network.connected_to_host.connect(_on_connected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.hosts_found_changed.connect(_refresh_found)


# ---------------------------------------------------------- open / close
func open_host() -> void:
	hosting = true
	connected = false
	title.text = "HOST A GAME"
	players_step.text = "STEP 2  ·  PLAYERS"
	_show_parts()
	if Network.host_game() != OK:
		ip_label.text = "Can't host"
		_set_status(Network.last_error, ERROR)
		start_button.disabled = true
		return
	var ips := Network.local_ips()
	ip_label.text = ips[0] if not ips.is_empty() else "No network"
	ip_hint.text = "Everyone must be on the same Wi-Fi or phone hotspot."
	if ips.size() > 1:
		ip_hint.text += "  (Other IPs: %s)" % ", ".join(ips.slice(1))
	_refresh_players()


func open_join() -> void:
	hosting = false
	connected = false
	title.text = "JOIN A GAME"
	players_step.text = "PLAYERS"
	Network.leave()
	Network.start_listening()
	_show_parts()
	_set_status("Pick a game from the list, or type the host's IP.", HINT)
	_refresh_found()
	_refresh_players()


func close() -> void:
	Network.stop_listening()
	Network.leave()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _show_parts() -> void:
	# which cards are shown depends on host / join / joined
	host_card.visible = hosting
	find_card.visible = not hosting and not connected
	ip_card.visible = not hosting and not connected
	players_card.visible = hosting or connected
	start_button.visible = hosting
	visible = true


func _process(delta: float) -> void:
	if visible and find_card.visible:
		_dots_time += delta
		searching.text = "Searching" + ".".repeat(1 + int(_dots_time * 2.0) % 3)


# -------------------------------------------------------------- joining
func _connect_to(ip: String) -> void:
	ip = ip.strip_edges()
	if ip.is_empty():
		_set_status("Type the host's IP first.", ERROR)
		return
	_set_status("Connecting to %s ..." % ip, YELLOW)
	if Network.join_game(ip) != OK:
		_set_status(Network.last_error, ERROR)


func _on_connection_failed(reason: String) -> void:
	if visible:
		_set_status(reason, ERROR)


func _on_connected() -> void:
	Network.stop_listening()
	connected = true
	_show_parts()
	_set_status("Connected! Waiting for the host to press START GAME.", OK_GREEN)
	_refresh_players()


func _refresh_found() -> void:
	if not visible or hosting:
		return
	for c in found_list.get_children():
		c.queue_free()
	if Network.found_hosts.is_empty():
		var empty := Label.new()
		empty.text = "No games found yet. Ask your friend to press HOST GAME."
		empty.add_theme_color_override("font_color", HINT)
		empty.add_theme_font_size_override("font_size", 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		found_list.add_child(empty)
	else:
		for ip in Network.found_hosts:
			found_list.add_child(_game_row(ip, Network.found_hosts[ip]))


func _game_row(ip: String, info: Dictionary) -> Control:
	# one found game: "Stef's game  ·  192.168.1.5  ·  2/6 players   [JOIN]"
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _card_style(Color(0.8, 0.85, 1.0)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var name_label := Label.new()
	var host_name: String = info.get("name", "")
	name_label.text = ("%s's game" % host_name) if not host_name.is_empty() else "LAN game"
	name_label.add_theme_font_size_override("font_size", 17)
	texts.add_child(name_label)
	var sub := Label.new()
	var full: bool = info["players"] >= Network.MAX_PLAYERS
	sub.text = "%s   ·   %d / %d players%s" % [ip, info["players"], Network.MAX_PLAYERS, "  (FULL)" if full else ""]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", HINT)
	texts.add_child(sub)
	var join := TextureButton.new()
	join.set_script(PngButton)
	join.texture_normal = JOIN_PNG
	join.custom_minimum_size = Vector2(96, 38)
	join.disabled = full
	join.pressed.connect(_connect_to.bind(ip))
	h.add_child(join)
	return row


# -------------------------------------------------------------- players
func _refresh_players() -> void:
	if not visible:
		return
	for c in slots.get_children():
		c.queue_free()
	var ids := Network.sorted_ids()
	for i in Network.MAX_PLAYERS:
		slots.add_child(_slot(i, ids[i] if i < ids.size() else -1))
	var n := ids.size()
	var silis := Network.sili_count_for(max(n, Network.MIN_PLAYERS))
	count_label.text = "%d / %d" % [n, Network.MAX_PLAYERS]
	sili_chip.text = "%d SILI" % silis
	tubig_chip.text = "%d TUBIG" % max(n - silis, 0)
	if hosting:
		start_button.disabled = n < Network.MIN_PLAYERS
		if n < Network.MIN_PLAYERS:
			_set_status("Waiting for players... (at least %d needed)" % Network.MIN_PLAYERS, YELLOW)
		else:
			_set_status("Ready! Press START GAME when everyone has joined.", OK_GREEN)


func _slot(index: int, peer_id: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 34)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(Color.WHITE))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 16)
	h.add_child(name_label)
	if peer_id == -1:
		card.modulate.a = 0.45
		dot.color = Color(0.5, 0.5, 0.55)
		name_label.text = "Open slot"
		name_label.add_theme_color_override("font_color", HINT)
		return card
	dot.color = SLOT_COLORS[index % SLOT_COLORS.size()]
	name_label.text = Network.player_name_of(peer_id)
	if peer_id == 1:
		h.add_child(_tag("HOST", Color(0.75, 0.55, 0.1)))
	if peer_id == multiplayer.get_unique_id():
		h.add_child(_tag("YOU", Color(0.2, 0.6, 0.35)))
	return card


# -------------------------------------------------------------- helpers
func _set_status(text: String, color: Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)


func _card_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = CARD
	style.set_texture_margin_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.modulate_color = tint
	return style


func _tag(text: String, color: Color) -> Label:
	var tag := Label.new()
	tag.text = text
	tag.add_theme_font_size_override("font_size", 11)
	_chip(tag, color)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tag


func _chip(label: Label, color: Color) -> void:
	# small rounded colored badge behind the text
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_color_override("font_color", Color.WHITE)
