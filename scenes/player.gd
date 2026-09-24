extends CharacterBody2D
## One player (Tubig or Sili). Movement + sprint/stamina come from the
## original prototype's player.gd. Over LAN, only the device that owns
## this character (its multiplayer authority) reads the keyboard and moves
## it; it sends its position to everyone else, who smoothly follow it.
## Catches, rescues and scroll pickups are decided by the host
## (maze_game.gd), never by this script.

const TUBIG_COLORS := [Color(0.2, 0.6, 1.0), Color(0.2, 0.9, 0.85), Color(0.75, 0.55, 1.0), Color(1.0, 1.0, 1.0)]
const SILI_COLORS := [Color(0.9, 0.2, 0.15), Color(1.0, 0.55, 0.1)]

@export var tubig_speed: float = 140.0
@export var sili_speed: float = 150.0          # Sili is a bit faster...
@export var tubig_sprint: float = 1.6           # ...but Tubig sprints harder
@export var sili_sprint: float = 1.35
@export var max_stamina: float = 3.0
@export var rescue_immunity_time: float = 1.5   # from the group game
@export var rescue_speed_bonus: float = 1.3
@export var send_rate: float = 30.0             # position updates per second

var peer_id: int = 1
var slot: int = 0
var role: String = "tubig"          # "tubig" or "sili"
var stamina: float = max_stamina
var frozen: bool = false
var frozen_time: float = 0.0
var immune_time: float = 0.0
var base_color: Color
var _net_target: Vector2
var _send_timer: float = 0.0

@onready var body_rect: ColorRect = $Body
@onready var name_label: Label = $NameLabel
@onready var alert_label: Label = $AlertLabel


func setup(id: int, player_slot: int, player_role: String, color_index: int, start: Vector2) -> void:
	peer_id = id
	slot = player_slot
	role = player_role
	set_multiplayer_authority(id)
	# Tubig and Sili pass through each other (tag = touch); both hit walls
	collision_layer = 2 if is_tubig() else 4
	collision_mask = 1
	global_position = start
	_net_target = start
	var palette := TUBIG_COLORS if is_tubig() else SILI_COLORS
	base_color = palette[color_index % palette.size()]
	body_rect.color = base_color
	if not is_tubig():
		# Sili is drawn slightly bigger so it is easy to spot
		body_rect.offset_left = -13; body_rect.offset_top = -13
		body_rect.offset_right = 13; body_rect.offset_bottom = 13
	name_label.text = _label()
	alert_label.visible = false


func is_tubig() -> bool:
	return role == "tubig"


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _label() -> String:
	var you := " (You)" if is_local() else ""
	return "%s P%d%s" % ["TUBIG" if is_tubig() else "SILI", slot + 1, you]


func _physics_process(delta: float) -> void:
	var playing := GameState.round_state == GameState.RoundState.PLAYING
	if playing:
		if frozen:
			frozen_time += delta
		if immune_time > 0.0:
			immune_time -= delta
	body_rect.modulate.a = 0.35 if immune_time > 0.0 and int(immune_time * 10) % 2 == 0 else 1.0

	if not is_multiplayer_authority():
		# someone else's character: glide toward the last position received
		global_position = global_position.lerp(_net_target, min(1.0, delta * 15.0))
		return

	if not playing or frozen:
		velocity = Vector2.ZERO
	else:
		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var sprinting := Input.is_action_pressed("sprint") and stamina > 0.0 and input_vector != Vector2.ZERO
		var current_speed := tubig_speed if is_tubig() else sili_speed
		if sprinting:
			current_speed *= tubig_sprint if is_tubig() else sili_sprint
			stamina = max(0.0, stamina - delta)
		else:
			stamina = min(max_stamina, stamina + delta * 0.5)
		if immune_time > 0.0:
			current_speed *= rescue_speed_bonus
		velocity = input_vector * current_speed
		move_and_slide()

	_send_timer -= delta
	if _send_timer <= 0.0 and GameState.round_state != GameState.RoundState.READY and Network.is_connected_ok():
		_send_timer = 1.0 / send_rate
		_net_position.rpc(global_position)


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_position(pos: Vector2) -> void:
	_net_target = pos


func can_be_tagged() -> bool:
	return is_tubig() and not frozen and immune_time <= 0.0


func can_be_rescued(min_frozen_time: float) -> bool:
	# a caught Tubig must stay frozen a moment, so a teammate standing
	# right beside them cannot undo the tag in the same instant
	return frozen and frozen_time >= min_frozen_time


func get_stamina_ratio() -> float:
	return stamina / max_stamina


# ---- called on every device by the host's RPCs ----
func set_caught() -> void:
	frozen = true
	frozen_time = 0.0
	body_rect.color = Color(0.55, 0.55, 0.6)
	name_label.text = "SAVE P%d!" % (slot + 1)
	alert_label.visible = false


func set_rescued() -> void:
	frozen = false
	body_rect.color = base_color
	name_label.text = _label()
	immune_time = rescue_immunity_time


func give_grace(seconds: float) -> void:
	# short protection after a question closes, so a Sili standing next
	# to the scroll cannot tag the moment play resumes
	immune_time = max(immune_time, seconds)


func set_alert(level: int) -> void:
	# 0 = safe, 1 = Sili nearby, 2 = Sili very close
	alert_label.visible = level > 0 and not frozen
	alert_label.text = "!!" if level == 2 else "!"
