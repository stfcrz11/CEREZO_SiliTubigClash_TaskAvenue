extends Control
## Shared parts of the two sari-sari store windows (host_modal.tscn and
## join_modal.tscn): the player slots, the status line on the counter, and
## closing with the ✕ / CANCEL / Esc. Each window adds its own parts in
## host_modal.gd / join_modal.gd.
## Slots/SlotTemplate in each scene is ONE player slot: the game copies it,
## so edit it in the editor to change how every slot looks.

@export_group("Texts")
@export var open_slot_text: String = "Open slot"

@export_group("Colors")
@export var slot_colors: Array[Color] = [Color(0.98, 0.82, 0.3), Color(0.35, 0.75, 1.0), Color(0.5, 0.9, 0.55),
	Color(0.9, 0.55, 1.0), Color(1.0, 0.6, 0.4), Color(0.6, 0.95, 0.95)]
@export var hint_color: Color = Color(0.7, 0.74, 0.82)
@export var error_color: Color = Color(1.0, 0.5, 0.45)
@export var good_color: Color = Color(0.5, 0.95, 0.55)
@export var waiting_color: Color = Color(1.0, 0.85, 0.4)

@onready var players_card: Control = $Center/Store/Body/VBox/PlayersCard
@onready var count_label: Label = $Center/Store/Body/VBox/PlayersCard/VBox/Header/Count
@onready var sili_chip: Label = $Center/Store/Body/VBox/PlayersCard/VBox/Header/SiliChip
@onready var tubig_chip: Label = $Center/Store/Body/VBox/PlayersCard/VBox/Header/TubigChip
@onready var slots: GridContainer = $Center/Store/Body/VBox/PlayersCard/VBox/Slots
@onready var slot_template: Control = $Center/Store/Body/VBox/PlayersCard/VBox/Slots/SlotTemplate
@onready var status: Label = $Center/Store/Counter/VBox/Status


func _ready() -> void:
	visible = false
	slot_template.visible = false   # the template is copied, never shown
	$Center/Store/Top/CloseButton.pressed.connect(close)
	$Center/Store/Counter/VBox/Buttons/CancelButton.pressed.connect(close)
	Network.players_changed.connect(_refresh_players)


func close() -> void:
	Network.stop_listening()
	Network.leave()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# -------------------------------------------------------------- players
func _refresh_players() -> void:
	if not visible or not players_card.visible:
		return
	_clear(slots, slot_template)
	var ids := Network.sorted_ids()
	for i in Network.MAX_PLAYERS:
		slots.add_child(_slot(i, ids[i] if i < ids.size() else -1))
	var n := ids.size()
	var silis := Network.sili_count_for(max(n, Network.MIN_PLAYERS))
	count_label.text = "%d / %d" % [n, Network.MAX_PLAYERS]
	sili_chip.text = "%d SILI" % silis
	tubig_chip.text = "%d TUBIG" % max(n - silis, 0)
	_players_updated(n)


func _players_updated(_count: int) -> void:
	pass   # host_modal.gd uses this to turn START GAME on / off


func _slot(index: int, peer_id: int) -> Control:
	# a copy of Slots/SlotTemplate filled in for one player (or an open slot)
	var card := slot_template.duplicate()
	card.visible = true
	var dot: ColorRect = card.get_node("HBox/Dot")
	var name_label: Label = card.get_node("HBox/Name")
	card.get_node("HBox/HostTag").visible = peer_id == 1
	card.get_node("HBox/YouTag").visible = peer_id != -1 and peer_id == multiplayer.get_unique_id()
	if peer_id == -1:
		card.modulate.a = 0.45
		dot.color = Color(0.5, 0.5, 0.55)
		name_label.text = open_slot_text
		name_label.add_theme_color_override("font_color", hint_color)
		return card
	dot.color = slot_colors[index % slot_colors.size()]
	name_label.text = Network.player_name_of(peer_id)
	return card


# -------------------------------------------------------------- helpers
func _set_status(text: String, color: Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)


func _clear(box: Node, keep: Node) -> void:
	# remove the copies made last time, but keep the template
	for c in box.get_children():
		if c != keep:
			c.queue_free()
