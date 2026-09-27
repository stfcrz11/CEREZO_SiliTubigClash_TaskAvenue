extends Node
## Global sound manager (autoload "Sound"). Plays the music and sound
## effects in assets/audio/. To change a sound, replace the MP3 with one of
## the same name, or point a name below to another file.
##
##   Sound.play("correct")        one-shot effect
##   Sound.play_music("title")    looping music (title screen)
##   Sound.start_loop("answering") / Sound.stop_loop()   looping effect
##
## Every button in the game plays "click" automatically.
##
## Volumes: music (title music + answering loop) and sound effects each go
## through their own audio bus ("Music" / "SFX"), so the Settings window can
## turn them off or down. The choice is saved in user://player_settings.cfg.

const FILES := {
	"title": "res://assets/audio/title_screen_music.mp3",
	"click": "res://assets/audio/button_click.mp3",
	"start": "res://assets/audio/game_start.mp3",
	"answering": "res://assets/audio/question_answering_sfx.mp3",
	"correct": "res://assets/audio/correct_sfx.mp3",
	"wrong": "res://assets/audio/wrong_sfx.mp3",
	"help": "res://assets/audio/ask_for_help_notif.mp3",
	"sili_near": "res://assets/audio/sili_nearby_alert_sfx.mp3",
	"game_over": "res://assets/audio/game_over.mp3",
	"win": "res://assets/audio/win_sfx.mp3",
	"lose": "res://assets/audio/lose_sfx.mp3",
}

@export var music_volume_db: float = -8.0    # title music
@export var loop_volume_db: float = -10.0    # "answering" loop
@export var sfx_volume_db: float = 0.0       # everything else

const SETTINGS_PATH := "user://player_settings.cfg"

# the player's settings (changed from the Settings window)
var music_on: bool = true
var sfx_on: bool = true
var music_percent: int = 80
var sfx_percent: int = 100

var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []   # a few players so effects can overlap


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in FILES:
		if ResourceLoader.exists(FILES[key]):
			_streams[key] = load(FILES[key])
	_make_bus("Music")
	_make_bus("SFX")
	_music = _new_player(music_volume_db, "Music")
	_loop = _new_player(loop_volume_db, "Music")
	for i in 6:
		_sfx.append(_new_player(sfx_volume_db, "SFX"))
	_load_settings()
	_apply()
	# every button, in every scene, clicks
	get_tree().node_added.connect(_on_node_added)


func _new_player(volume: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = volume
	p.bus = bus
	add_child(p)
	return p


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


# ------------------------------------------------------------ settings
func set_music(on: bool, percent: int) -> void:
	music_on = on
	music_percent = clampi(percent, 0, 100)
	_apply()
	_save_settings()


func set_sfx(on: bool, percent: int) -> void:
	sfx_on = on
	sfx_percent = clampi(percent, 0, 100)
	_apply()
	_save_settings()


func _apply() -> void:
	_apply_bus("Music", music_on, music_percent)
	_apply_bus("SFX", sfx_on, sfx_percent)


func _apply_bus(bus_name: String, on: bool, percent: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(i, not on or percent <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(max(percent, 1) / 100.0))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_on = cfg.get_value("audio", "music_on", music_on)
	sfx_on = cfg.get_value("audio", "sfx_on", sfx_on)
	music_percent = cfg.get_value("audio", "music_percent", music_percent)
	sfx_percent = cfg.get_value("audio", "sfx_percent", sfx_percent)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep the other saved settings (e.g. the player name)
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "music_percent", music_percent)
	cfg.set_value("audio", "sfx_percent", sfx_percent)
	cfg.save(SETTINGS_PATH)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_click):
		node.pressed.connect(_click)


func _click() -> void:
	play("click")


## One-shot sound effect. Returns its length in seconds (0 if missing).
func play(key: String) -> float:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return 0.0
	var player: AudioStreamPlayer = _sfx[0]
	for p in _sfx:
		if not p.playing:
			player = p
			break
	player.stream = stream
	player.play()
	return stream.get_length()


## Looping background music; does nothing if that track is already playing.
func play_music(key: String) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null or (_music.playing and _music.stream == stream):
		return
	_set_loop(stream)
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


## Looping sound effect (e.g. while answering a question).
func start_loop(key: String) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null or (_loop.playing and _loop.stream == stream):
		return
	_set_loop(stream)
	_loop.stream = stream
	_loop.play()


func stop_loop() -> void:
	_loop.stop()


func _set_loop(stream: AudioStream) -> void:
	if "loop" in stream:
		stream.loop = true
