extends "res://scenes/store_modal.gd"
## HOST A GAME window (scenes/host_modal.tscn): the IP on the chalkboard,
## the player slots and START GAME.
## To customize: open host_modal.tscn, click "HostModal" for the texts and
## colors in the Inspector, or click any node to change its look.

@export_group("Texts")
@export var ip_hint_text: String = "Everyone must be on the same Wi-Fi or phone hotspot."
@export var need_players_text: String = "Need %d+ players"     # %d = minimum players
@export var ready_text: String = "Ready!"

@onready var ip_label: Label = $Center/Store/Body/VBox/HostCard/VBox/IpLabel
@onready var ip_hint: Label = $Center/Store/Body/VBox/HostCard/VBox/Hint
@onready var start_button: TextureButton = $Center/Store/Counter/VBox/Buttons/StartButton


func _ready() -> void:
	super()
	start_button.pressed.connect(func(): Network.start_game())


func open() -> void:
	visible = true
	if Network.host_game() != OK:
		ip_label.text = "Can't host"
		_set_status(Network.last_error, error_color)
		start_button.disabled = true
		return
	var ips := Network.local_ips()
	ip_label.text = ips[0] if not ips.is_empty() else "No network"
	ip_hint.text = ip_hint_text
	_refresh_players()


func _players_updated(count: int) -> void:
	start_button.disabled = count < Network.MIN_PLAYERS
	if count < Network.MIN_PLAYERS:
		_set_status(need_players_text % Network.MIN_PLAYERS, waiting_color)
	else:
		_set_status(ready_text, good_color)
