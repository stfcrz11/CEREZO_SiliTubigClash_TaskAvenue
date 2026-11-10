extends CharacterBody2D
## One player (Tubig or Sili). Movement + sprint/stamina come from the
## original prototype's player.gd. Over LAN, only the device that owns
## this character (its multiplayer authority) reads the keyboard and moves
## it; it sends its position to everyone else, who smoothly follow it.
## Catches, rescues, quiz stations and power-ups are decided by the host
## (maze_game.gd), never by this script; it only shows them and applies
## their speed changes.
## SOLO VS BOT: a computer Sili is a normal player whose keys come from
## scenes/bot_sili.gd (bot_move / bot_sprint) instead of the keyboard.

# light tints so teammates using the same picture still look a bit different
const TUBIG_TINTS := [Color(1, 1, 1), Color(0.85, 1.0, 1.0), Color(0.92, 0.88, 1.0), Color(1.0, 1.0, 0.85)]
const SILI_TINTS := [Color(1, 1, 1), Color(1.0, 0.9, 0.78), Color(1.0, 0.82, 0.9)]
const CAUGHT_TINT := Color(0.62, 0.78, 1.0)

## Character sheets made from Eris Esra's 16x32 character template (see
## README credits). 32x32 cells, 6 columns. Rows, 5 directions each
## (down, down-right, right, up-right, up; left = right flipped):
##   0-4 idle (4 frames), 5-9 walk (4), 10-14 run (6), 15-19 answering (4).
@export var tubig_texture: Texture2D = preload("res://assets/characters/tubig_sheet.png")
@export var sili_texture: Texture2D = preload("res://assets/characters/sili_sheet.png")
@export var ice_texture: Texture2D = preload("res://assets/props/ice_block.png")
@export var sprite_scale: float = 1.25          # 1.25 = same pixel size as the city tiles
@export var walk_fps: float = 8.0
@export var run_fps: float = 12.0

@export var tubig_speed: float = 140.0
@export var sili_speed: float = 150.0          # Sili is a bit faster...
@export var tubig_sprint: float = 1.6           # ...but Tubig sprints harder
@export var sili_sprint: float = 1.35
@export var max_stamina: float = 3.0
@export var rescue_immunity_time: float = 1.5   # from the group game
@export var rescue_speed_bonus: float = 1.3
@export var turbo_speed_bonus: float = 1.35     # Bicol Express "Extra Anghang"
@export var slow_speed_scale: float = 0.55      # sprayed by a Kalamansi gate
@export var send_rate: float = 30.0             # position updates per second

const SHEET_COLUMNS := 6
const SHEET_ROWS := 20
const ANIMS := {"idle": [0, 4], "walk": [5, 4], "run": [10, 6], "interact": [15, 4]}

var peer_id: int = 1
var slot: int = 0
var role: String = "tubig"          # "tubig" or "sili"
var stamina: float = max_stamina
var frozen: bool = false            # caught by a Sili
var answering: bool = false         # answering a question: can't move, can't be tagged
var frozen_time: float = 0.0
var immune_time: float = 0.0
# power-ups and penalties (set on every device by the host's RPCs)
var shield_time: float = 0.0        # Tubig: Yelo Shield from a Halo-Halo cooler
var turbo_time: float = 0.0         # Sili: Extra Anghang from a Bicol Express pepper
var slow_time: float = 0.0          # anyone: sprayed by a Kalamansi gate
var stun_time: float = 0.0          # Sili: extinguished by a Yelo Shield
var base_color: Color
var _net_target: Vector2
var _send_timer: float = 0.0
var _last_position: Vector2
var _anim_time: float = 0.0
var _dir_row: int = 0               # 0 down, 1 down-right, 2 right, 3 up-right, 4 up
var _flip: bool = false
var is_bot: bool = false            # driven by bot_sili.gd, not the keyboard
var bot_move: Vector2 = Vector2.ZERO
var bot_sprint: bool = false
var bot_tag_ready: bool = true      # bots wait a human-like moment before tagging
var bot_interact: int = -1          # quiz station a bot is pushing into (-1 = none)

var _ice: Sprite2D
var _aura: Aura
var _trail: CPUParticles2D

@onready var body: Sprite2D = $Body
@onready var name_label: Label = $NameLabel
@onready var alert_label: Label = $AlertLabel


## Rings drawn around the player for the shield / turbo / stun effects.
class Aura extends Node2D:
	var player: Node

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if player == null:
			return
		var t := Time.get_ticks_msec() / 1000.0
		if player.shield_time > 0.0:
			var a := 0.55 if player.shield_time > 2.0 or int(t * 8.0) % 2 == 0 else 0.15
			draw_circle(Vector2(0, -6), 19.0, Color(0.55, 0.85, 1.0, a * 0.35))
			draw_arc(Vector2(0, -6), 19.0, 0, TAU, 32, Color(0.85, 0.97, 1.0, a), 1.5)
		if player.turbo_time > 0.0:
			var r := 15.0 + sin(t * 18.0) * 1.5
			draw_arc(Vector2(0, 8), r, 0, TAU, 24, Color(1.0, 0.45, 0.1, 0.8), 2.0)
		if player.stun_time > 0.0:
			for i in 3:
				var ang := t * 3.0 + TAU * i / 3.0
				draw_circle(Vector2(cos(ang) * 10.0, -22.0 + sin(ang) * 3.0), 2.0, Color(0.75, 0.8, 0.85, 0.9))
		if player.slow_time > 0.0:
			for i in 4:
				var ang2 := t * 2.0 + TAU * i / 4.0
				draw_circle(Vector2(cos(ang2) * 12.0, 4.0 + sin(ang2) * 4.0), 1.6, Color(0.75, 0.95, 0.3, 0.9))


func setup(id: int, player_slot: int, player_role: String, color_index: int, start: Vector2) -> void:
	peer_id = id
	slot = player_slot
	role = player_role
	is_bot = Network.is_bot(id)
	set_multiplayer_authority(1 if is_bot else id)   # the host runs the bots
	# Tubig and Sili pass through each other (tag = touch); both hit walls
	collision_layer = 2 if is_tubig() else 4
	collision_mask = 1
	global_position = start
	_net_target = start
	_last_position = start
	body.texture = tubig_texture if is_tubig() else sili_texture
	body.hframes = SHEET_COLUMNS
	body.vframes = SHEET_ROWS
	body.scale = Vector2.ONE * sprite_scale
	body.offset = Vector2(0, -6)          # feet sit at the bottom of the collision circle
	var tints := TUBIG_TINTS if is_tubig() else SILI_TINTS
	base_color = tints[color_index % tints.size()]
	body.self_modulate = base_color
	name_label.text = _label()
	if is_local():
		name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))   # your own name in yellow
	alert_label.visible = false
	_make_effects()
	_show_frame()


func _make_effects() -> void:
	_ice = Sprite2D.new()
	_ice.texture = ice_texture
	_ice.scale = Vector2.ONE * sprite_scale
	_ice.position = Vector2(0, -7)
	_ice.visible = false
	add_child(_ice)
	_aura = Aura.new()
	_aura.player = self
	add_child(_aura)
	# Sili leave glowing red embers, Tubig leave blue water drops
	_trail = CPUParticles2D.new()
	_trail.amount = 14
	_trail.lifetime = 0.6
	_trail.local_coords = false
	_trail.position = Vector2(0, 8)
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 3.0
	_trail.direction = Vector2(0, -1)
	_trail.spread = 60.0
	_trail.gravity = Vector2(0, -12) if not is_tubig() else Vector2(0, 30)
	_trail.initial_velocity_min = 4.0
	_trail.initial_velocity_max = 12.0
	_trail.scale_amount_min = 1.2
	_trail.scale_amount_max = 2.2
	var ramp := Gradient.new()
	if is_tubig():
		ramp.set_color(0, Color(0.55, 0.85, 1.0, 0.85))
		ramp.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
	else:
		ramp.set_color(0, Color(1.0, 0.75, 0.2, 0.9))
		ramp.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	_trail.color_ramp = ramp
	_trail.emitting = false
	add_child(_trail)
	move_child(_trail, 0)   # behind the body


func is_tubig() -> bool:
	return role == "tubig"


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _label() -> String:
	return Network.player_name_of(peer_id)   # just the name, shown above the head


func _physics_process(delta: float) -> void:
	var playing := GameState.round_state == GameState.RoundState.PLAYING
	if playing:
		if frozen:
			frozen_time += delta
		immune_time = max(0.0, immune_time - delta)
		shield_time = max(0.0, shield_time - delta)
		turbo_time = max(0.0, turbo_time - delta)
		slow_time = max(0.0, slow_time - delta)
		stun_time = max(0.0, stun_time - delta)
	body.modulate.a = 0.35 if immune_time > 0.0 and int(immune_time * 10) % 2 == 0 else 1.0

	if not is_multiplayer_authority():
		# someone else's character: glide toward the last position received
		global_position = global_position.lerp(_net_target, min(1.0, delta * 15.0))
		return

	if not playing or frozen or answering or stun_time > 0.0:
		velocity = Vector2.ZERO
	else:
		var input_vector := bot_move if is_bot else Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var wants_sprint := bot_sprint if is_bot else Input.is_action_pressed("sprint")
		var sprinting := wants_sprint and stamina > 0.0 and input_vector != Vector2.ZERO
		var current_speed := tubig_speed if is_tubig() else sili_speed
		if sprinting:
			current_speed *= tubig_sprint if is_tubig() else sili_sprint
			stamina = max(0.0, stamina - delta)
		else:
			stamina = min(max_stamina, stamina + delta * 0.5)
		if immune_time > 0.0:
			current_speed *= rescue_speed_bonus
		if turbo_time > 0.0:
			current_speed *= turbo_speed_bonus
		if slow_time > 0.0:
			current_speed *= slow_speed_scale
		velocity = input_vector * current_speed
		move_and_slide()

	_send_timer -= delta
	if _send_timer <= 0.0 and GameState.round_state != GameState.RoundState.READY and Network.is_connected_ok():
		_send_timer = 1.0 / send_rate
		_net_position.rpc(global_position)


func _process(delta: float) -> void:
	# animation: works for every player, because it only looks at how far
	# the character moved since the last frame
	var moved := global_position - _last_position
	_last_position = global_position
	var speed := moved.length() / maxf(delta, 0.0001)
	if moved.length() > 0.3 and not frozen:
		_face(moved)
		_anim_time += delta
	else:
		_anim_time = 0.0 if not answering else _anim_time + delta
	if _trail:
		_trail.emitting = speed > 20.0 and not frozen
	_show_frame(speed)


func _face(dir: Vector2) -> void:
	# 8 directions; left-facing ones use the right-facing rows flipped
	var ang := fposmod(rad_to_deg(dir.angle()), 360.0)   # 0 = right, 90 = down
	var octant := int(round(ang / 45.0)) % 8
	var rows := [2, 1, 0, 1, 2, 3, 4, 3]        # right, down-right, down, down-left, left, up-left, up, up-right
	_dir_row = rows[octant]
	_flip = octant in [3, 4, 5]


func _show_frame(speed: float = 0.0) -> void:
	var anim := "idle"
	var fps := 4.0
	if answering:
		anim = "interact"
		fps = 6.0
	elif frozen:
		anim = "idle"
		fps = 0.0
	elif speed > 175.0:
		anim = "run"
		fps = run_fps
	elif speed > 15.0:
		anim = "walk"
		fps = walk_fps
	var info: Array = ANIMS[anim]
	var row: int = info[0] + (0 if answering else _dir_row)
	var frame := int(_anim_time * fps) % int(info[1]) if fps > 0.0 else 0
	if anim == "idle" and not frozen:
		frame = int(Time.get_ticks_msec() / 250.0) % int(info[1])   # gentle breathing
	body.frame = row * SHEET_COLUMNS + frame
	body.flip_h = _flip and not answering


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_position(pos: Vector2) -> void:
	_net_target = pos


## Moves the character at once (e.g. through a Kalamansi gate). Called on
## every device by the host, so nobody glides through the wall.
func force_position(pos: Vector2) -> void:
	global_position = pos
	_net_target = pos
	_last_position = pos


func can_be_tagged() -> bool:
	return is_tubig() and not frozen and not answering and immune_time <= 0.0


func can_tag() -> bool:
	return not is_tubig() and not answering and stun_time <= 0.0 and (bot_tag_ready or not is_bot)


func can_be_rescued(min_frozen_time: float) -> bool:
	# a caught Tubig must stay frozen a moment, so a teammate standing
	# right beside them cannot undo the tag in the same instant
	return frozen and frozen_time >= min_frozen_time


func get_stamina_ratio() -> float:
	return stamina / max_stamina


## Short text for the HUD about this player's power-ups and penalties.
func effect_text() -> String:
	var parts: PackedStringArray = []
	if shield_time > 0.0:
		parts.append("YELO SHIELD %ds" % ceili(shield_time))
	if turbo_time > 0.0:
		parts.append("EXTRA ANGHANG %ds" % ceili(turbo_time))
	if slow_time > 0.0:
		parts.append("MAASIM! slowed %ds" % ceili(slow_time))
	if stun_time > 0.0:
		parts.append("EXTINGUISHED %ds" % ceili(stun_time))
	return "   ".join(parts)


# ---- called on every device by the host's RPCs ----
func set_caught() -> void:
	frozen = true
	frozen_time = 0.0
	shield_time = 0.0
	body.self_modulate = CAUGHT_TINT
	_ice.visible = true
	name_label.text = "SAVE %s!" % Network.player_name_of(peer_id)
	alert_label.visible = false


func set_rescued() -> void:
	frozen = false
	body.self_modulate = base_color
	_ice.visible = false
	name_label.text = _label()
	immune_time = rescue_immunity_time


func set_answering(on: bool) -> void:
	answering = on
	if on:
		name_label.text = "%s  ANSWERING..." % Network.player_name_of(peer_id)
		alert_label.visible = false
	else:
		name_label.text = ("SAVE %s!" % Network.player_name_of(peer_id)) if frozen else _label()


func give_grace(seconds: float) -> void:
	# short protection after a question closes, so a Sili standing next
	# to the scroll cannot tag the moment play resumes
	immune_time = max(immune_time, seconds)


func apply_effect(effect: String, seconds: float) -> void:
	match effect:
		"shield":
			shield_time = seconds
		"turbo":
			turbo_time = seconds
		"slow":
			slow_time = seconds
		"stun":
			stun_time = seconds
			turbo_time = 0.0


func set_alert(level: int) -> void:
	# 0 = safe, 1 = Sili nearby, 2 = Sili very close
	alert_label.visible = level > 0 and not frozen and not answering and is_local()
	alert_label.text = "!!" if level == 2 else "!"
