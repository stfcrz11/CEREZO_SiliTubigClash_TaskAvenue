extends Node2D
## Sili-Tubig: Task Avenue — the maze round (solo or LAN).
## 2-6 players over LAN. Silis (1 for 2-4 players, 2 for 5-6) chase; the
## Tubig team picks up "?" scrolls and must answer 10 Filipino-culture
## questions correctly before time runs out.
## SOLO VS BOT: you are the only Tubig and 1-3 computer Silis (bot_sili.gd)
## chase you, over 4 rounds from easy to difficult (Network.SOLO_ROUNDS).
## Bot rounds don't go on the leaderboard.
## Round states: READY -> PLAYING <-> PAUSED, PLAYING <-> QUESTION, -> ENDED.
##
## Quizzes control freezing, rescuing and power-ups (every one of them is a
## "question" with a kind — see KINDS):
##   scroll  "?" scroll: a correct answer counts toward the Tubig goal
##   rescue  Buhos-Tubig: touch a frozen teammate and answer 1 question to
##           splash them free
##   thaw    Huling Hirit: a frozen Tubig with no teammate to save them can
##           thaw themselves with 2 harder questions in a row
##   shield  Halo-Halo cooler (4 corner stalls): Yelo Shield for 10 s. A Sili
##           who tags a shielded Tubig is extinguished for 5 s instead
##   turbo   Bicol Express pepper (center, Sili only): solve a bugtong for
##           Extra Anghang — faster and a wider tag reach for 6 s
##   gate    Kalamansi gate (thin walls): answer to squeeze through; a wrong
##           answer sprays sour kalamansi and slows you for 3 s
## Stations are placed at random each round; press E (USE on phones) at one.
##
## Networking rule: the HOST decides everything that matters (roles, tags,
## rescues, scroll pickups, questions, answers, timer, win/lose) and tells
## every device with an RPC. Functions starting with _host_ only run on the
## host. Each device only moves its own character.

const QuestionBank := preload("res://data/questions.gd")
const Leaderboard := preload("res://data/leaderboard.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SCROLL_SCENE := preload("res://scenes/question_scroll.tscn")
const ButtonStyle := preload("res://scenes/ui_button_style.gd")
const BotSili := preload("res://scenes/bot_sili.gd")
const COOLER_TEXTURE := preload("res://assets/props/cooler_stalls.png")
const PEPPER_TEXTURE := preload("res://assets/props/bicol_pepper.png")

## The maze is NOT written here any more: open scenes/city_map.tscn and
## paint it on the "Maze" TileMapLayer (tiles come from
## assets/walls/city_tileset.tres). Any tile with a collision shape is a
## wall, every other tile is road. Start spots are the Marker2D nodes under
## "Starts" (TubigStart1-4, SiliStart1-2) — drag them in the editor.
const TILE := 40                  # one maze cell in world pixels (32 px tiles, layer scale 1.25)
const CAMERA_MARGIN := 3          # tiles of city the camera may show past the maze edge

## Question kinds: which question list they use and how long you have.
const KINDS := {
	"scroll": {"pool": "normal", "time": 15.0},
	"rescue": {"pool": "normal", "time": 12.0},
	"thaw": {"pool": "hard", "time": 12.0},
	"shield": {"pool": "normal", "time": 10.0},
	"turbo": {"pool": "bugtong", "time": 12.0},
	"gate": {"pool": "normal", "time": 10.0},
}
const STALL_NAMES := ["Halo-Halo", "Mais Con Yelo", "Sago't Gulaman", "Buko Pandan"]

@export var questions_to_win: int = 10
@export var round_time: float = 180.0          # round length with 1 Tubig (3:00)
@export var less_time_per_extra_tubig: float = 20.0   # more Tubigs answer at once, so less time
@export var min_round_time: float = 90.0
@export var scrolls_on_map: int = 3
@export var pickup_distance: float = 24.0
@export var tag_distance: float = 24.0        # Sili touching Tubig
@export var warn_distance: float = 170.0     # "SILI NEARBY!"
@export var danger_distance: float = 90.0    # "RUN!"
@export var rescue_distance: float = 26.0
@export var min_frozen_time: float = 1.0
@export var grace_after_question: float = 1.0
@export var feedback_time: float = 1.5        # how long the TAMA!/MALI! popup stays (the answerer waits this long)
@export var camera_zoom: float = 2.5          # higher = closer; 2.5 shows about 10 x 6 tiles
@export_group("Quiz stations")
@export var shield_time: float = 10.0          # Halo-Halo cooler: Yelo Shield
@export var sili_stun_time: float = 5.0        # Sili who tags a shielded Tubig
@export var turbo_time: float = 6.0            # Bicol Express: Extra Anghang
@export var turbo_tag_scale: float = 1.6       # wider tag reach while Extra Anghang
@export var slow_time: float = 3.0             # wrong answer at a Kalamansi gate
@export var stall_cooldown: float = 20.0       # a cooler rests after giving a shield
@export var pepper_cooldown: float = 15.0
@export var retry_cooldown: float = 6.0        # after a wrong answer at a station
@export var gates_on_map: int = 4
@export_group("Self-thaw (Huling Hirit)")
@export var solo_self_thaws: int = 2           # when you are the only Tubig
@export var team_self_thaws: int = 1           # per Tubig, when teammates are too far
@export var self_thaw_wait: float = 5.0        # frozen this long with no teammate near
@export var self_thaw_far: float = 240.0       # "no teammate near" = none within 6 tiles

@onready var maze_layer: TileMapLayer = $Map/Maze
@onready var starts_root: Node2D = $Map/Starts
@onready var camera: Camera2D = $Camera
@onready var scrolls_root: Node2D = $Scrolls
@onready var actors_root: Node2D = $Actors
@onready var round_timer: Timer = $RoundTimer
@onready var score_label: Label = $HUD/TopBar/ScoreLabel
@onready var timer_label: Label = $HUD/TopBar/TimerLabel
@onready var frozen_label: Label = $HUD/TopBar/FrozenLabel   # Sili goal: freeze them ALL
@onready var mode_label: Label = $HUD/TopBar/ModeLabel
@onready var warning_label: Label = $HUD/WarningLabel
@onready var warning_glow: Control = $HUD/WarningGlow
@onready var message_label: Label = $HUD/MessageLabel
@onready var pause_label: Label = $HUD/PauseLabel
@onready var minimap: Control = $HUD/Minimap
@onready var quiz_panel: Control = $HUD/QuizPanel
@onready var answer_popup: Control = $HUD/AnswerPopup
@onready var help_alert: Control = $HUD/HelpAlert
@onready var answering_notice: Control = $HUD/AnsweringNotice
@onready var end_panel: Control = $HUD/EndPanel
@onready var play_again_button: Button = $HUD/EndPanel/Margin/VBox/Buttons/PlayAgainButton
@onready var menu_button: Button = $HUD/EndPanel/Margin/VBox/Buttons/MenuButton

var maze: Array[String] = []       # read from the Maze TileMapLayer: # wall, . road, P / S start
var maze_origin := Vector2.ZERO     # world position of the maze's top-left corner
var floor_cells: Array[Vector2i] = []
var tubigs: Array = []
var silis: Array = []
var player_by_id: Dictionary = {}
var scrolls: Dictionary = {}        # scroll id -> node
var stations: Array = []            # quiz stations: {id, kind, cell, approach, name, node, label, cooldown}
var bot_intel: Dictionary = {}      # SOLO team bots: where a Tubig was last seen {pos, time}
var correct_answers: int = 0
var questions_asked: int = 0
var time_left: float = 0.0
var message_time: float = 0.0
var _last_warn_level: int = 0        # for the "Sili nearby" sound
var _last_warn_sound: int = -100000
var local_player: Node2D             # the camera follows only this device's player
var questions: Dictionary = {}       # open questions (every device): qid -> info
var my_question: int = -1            # the question THIS device is answering (-1 = none)
var popup_question: int = -1         # the question the TAMA!/MALI! popup is about
var _help_queue: Array = []          # help requests waiting to be shown to me
var _help_showing: int = -1          # the help request in the alert right now
var help_locked_by: int = 0          # the answerer who is asking for help now (0 = nobody)
var _maze_cell_offset := Vector2i.ZERO   # maze grid (0,0) = this Maze layer cell
var _interact_cooldown: float = 0.0  # local: don't send a station request every frame
var _effect_label: Label
var _fps_label: Label
var _leave_armed_until: int = 0   # msec: a 2nd tap on LEAVE before this leaves
var _fps_timer: float = 0.0
var _solo_won: bool = false

# host-only bookkeeping
var _begun: bool = false
var _next_scroll_id: int = 0
var _decks: Dictionary = {}         # question list name -> shuffled indexes left
var _questions: Dictionary = {}     # open questions (host): qid -> info
var _help_active: int = -1          # host: the ONE question with an open help request
var _stats: Dictionary = {}         # host: peer id -> {correct, tags, rescues} this round
var _next_question_id: int = 0
var _rescuing: Dictionary = {}      # host: frozen Tubig id -> rescue question id
var _thawing: Dictionary = {}       # host: frozen Tubig id -> self-thaw question id
var _thaw_uses: Dictionary = {}     # host: Tubig id -> self-thaws used this round
var _retry_at: Dictionary = {}      # host: "peer:what" -> msec when they may try again
var _bots: Dictionary = {}          # host: bot peer id -> bot_sili.gd controller


func _ready() -> void:
	randomize()
	Sound.stop_music()
	# The HUD is hidden in the editor so it doesn't cover the map while you
	# edit (click the eye next to "HUD" to see it); the game shows it here.
	$HUD.visible = true
	if Network.players.is_empty():
		Network.play_solo()   # scene started directly (e.g. from the editor)
	if Network.solo_bot:
		questions_to_win = Network.solo_round_info()["questions"]
	_build_maze()
	GameState.round_state = GameState.RoundState.READY
	quiz_panel.choice_made.connect(_on_local_choice)
	quiz_panel.help_requested.connect(_on_help_pressed)
	$HUD/TopBar/SettingsButton.pressed.connect(func(): $HUD/SettingsPanel.open())
	$HUD/TopBar/PauseButton.pressed.connect(_toggle_pause)
	$HUD/TopBar/LeaveButton.pressed.connect(_on_leave_pressed)
	# phone joystick + RUN button: off while a window covers the game
	$HUD/TouchControls.is_blocked = func(): return quiz_panel.visible or answer_popup.visible \
		or end_panel.visible or pause_label.visible or $HUD/SettingsPanel.visible
	$HUD/TouchControls.excluded_rects = func():
		return [$HUD/HelpAlert/Panel.get_global_rect()] if help_alert.visible else []
	help_alert.answered.connect(_on_help_answer)
	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_leave)
	ButtonStyle.style_primary(play_again_button, Color(0.21, 0.69, 0.9))
	ButtonStyle.style_secondary(menu_button, Color(0.38, 0.38, 0.46))
	end_panel.visible = false
	pause_label.visible = false
	warning_label.text = ""
	warning_glow.modulate.a = 0.0
	minimap.set_maze(maze, maze_origin, TILE)
	minimap.set_camera(camera)
	minimap.set_scrolls(scrolls)   # yellow scroll dots for Tubig players
	minimap.set_stations(stations)
	_setup_camera()
	_add_vignette()
	_add_effect_label()
	_add_fps_label()
	if not Network.online:
		mode_label.text = "Solo"
	else:
		mode_label.text = "Host (LAN)" if Network.is_host() else "LAN"
	_update_hud()
	_show_message("Waiting for players...", 30.0)

	Network.host_left.connect(_on_host_left)
	if multiplayer.is_server():
		Network.peer_ready.connect(_on_peer_ready)
		multiplayer.peer_disconnected.connect(_host_on_peer_left)
		round_timer.wait_time = 1.0
		round_timer.timeout.connect(_host_tick)
	Network.report_ready()
	if multiplayer.is_server():
		_host_try_begin()


# ================================================================ maze
func _build_maze() -> void:
	# Turn the painted TileMapLayer into a simple grid the game rules use.
	var used := maze_layer.get_used_rect()
	_maze_cell_offset = used.position
	maze_origin = maze_layer.to_global(maze_layer.map_to_local(used.position)) - Vector2(TILE, TILE) / 2.0
	for y in used.size.y:
		var row := ""
		for x in used.size.x:
			var data := maze_layer.get_cell_tile_data(used.position + Vector2i(x, y))
			var is_wall := data != null and data.get_collision_polygons_count(0) > 0
			row += "#" if is_wall else "."
		maze.append(row)
	# start spots come from the Marker2D nodes under Map/Starts
	for marker in starts_root.get_children():
		var cell := world_to_cell(marker.global_position)
		var mark := "P" if marker.name.begins_with("Tubig") else "S"
		maze[cell.y] = maze[cell.y].substr(0, cell.x) + mark + maze[cell.y].substr(cell.x + 1)
	for y in maze.size():
		for x in maze[y].length():
			if maze[y][x] != "#":
				floor_cells.append(Vector2i(x, y))


# ============================================================== camera
func _setup_camera() -> void:
	# A close-up camera: you only see the streets around you, the minimap
	# shows the whole maze. Every device follows its own player only.
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	var top_left := maze_origin - Vector2.ONE * CAMERA_MARGIN * TILE
	var bottom_right := maze_origin + Vector2(maze[0].length(), maze.size()) * TILE + Vector2.ONE * CAMERA_MARGIN * TILE
	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
	camera.global_position = cell_to_world(Vector2i(maze[0].length() / 2, maze.size() / 2))
	camera.make_current()


func _follow_local_player() -> void:
	if is_instance_valid(local_player):
		camera.global_position = local_player.global_position


func _add_vignette() -> void:
	# darker screen edges so the street around you feels closer
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.6))
	gradient.add_point(0.6, Color(0, 0, 0, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = texture
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(vignette)
	$HUD.move_child(vignette, 0)   # under the minimap and the rest of the HUD


func _add_effect_label() -> void:
	# your power-ups / penalties, under the top bar (e.g. "YELO SHIELD 7s")
	_effect_label = Label.new()
	_effect_label.name = "EffectLabel"
	_effect_label.position = Vector2(16, 44)
	_effect_label.add_theme_font_size_override("font_size", 16)
	_effect_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_effect_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_effect_label.add_theme_constant_override("outline_size", 6)
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_effect_label)
	$HUD.move_child(_effect_label, $HUD/MessageLabel.get_index())


func _add_fps_label() -> void:
	# Settings -> Show FPS: live numbers for performance testing
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.position = Vector2(12, -60)
	_fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_fps_label)
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_top = -70.0
	_fps_label.offset_bottom = -52.0


func _update_fps_label(delta: float) -> void:
	_fps_label.visible = GameState.show_fps
	if not GameState.show_fps:
		return
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.25
	_fps_label.text = "FPS %d  |  %.1f ms  |  mem %.0f MB  |  draws %d  |  nodes %d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]


func world_to_cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(((pos - maze_origin) / TILE).floor())
	return c.clamp(Vector2i.ZERO, Vector2i(maze[0].length() - 1, maze.size() - 1))


func cell_to_world(cell: Vector2i) -> Vector2:
	return maze_origin + Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0


func random_floor_cell() -> Vector2i:
	return floor_cells.pick_random()


func is_floor(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.y < maze.size() and cell.x < maze[0].length() \
		and maze[cell.y][cell.x] != "#"


## The road cell closest to `cell` (itself if it is road).
func nearest_floor_cell(cell: Vector2i) -> Vector2i:
	if is_floor(cell):
		return cell
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(absi(dx), absi(dy)) == r and is_floor(cell + Vector2i(dx, dy)):
					return cell + Vector2i(dx, dy)
	return cell


func _cells_with(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in maze.size():
		for x in maze[y].length():
			if maze[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


## How far a Sili can tag from (wider with Extra Anghang).
func tag_radius_of(sili: Node2D) -> float:
	return tag_distance * (turbo_tag_scale if sili.turbo_time > 0.0 else 1.0)


# ========================================================= round start
func _on_peer_ready(_id: int) -> void:
	_host_try_begin()


func _host_try_begin() -> void:
	if _begun or not Network.everyone_ready():
		return
	_begun = true
	var roles := Network.assign_roles()   # 2-4 players: 1 Sili, 5-6: 2 Silis; solo: 1-3 bots
	var tubig_starts := _cells_with("P")
	var sili_starts := _cells_with("S")
	var roster := []
	var tubig_n := 0
	var sili_n := 0
	for id in Network.sorted_ids():
		var start: Vector2i
		if roles[id] == "tubig":
			start = tubig_starts[tubig_n % tubig_starts.size()]
			tubig_n += 1
		else:
			start = sili_starts[sili_n] if sili_n < sili_starts.size() else _far_cell_from(tubig_starts[0])
			sili_n += 1
		roster.append([id, Network.slot_of(id), roles[id], start])
		_stats[id] = {"correct": 0, "tags": 0, "rescues": 0}
	_spawn_all.rpc(roster)
	_setup_stations.rpc(_host_place_stations())
	for i in scrolls_on_map:
		_host_spawn_scroll()
	_start_round.rpc(_round_seconds(tubig_n))
	round_timer.start()


func _far_cell_from(from: Vector2i) -> Vector2i:
	# a road cell far from the Tubig start, for a 3rd bot with no start marker
	var best := floor_cells[0]
	var best_d := -1.0
	for i in 40:
		var c: Vector2i = floor_cells.pick_random()
		var d := Vector2(c - from).length()
		if d > best_d and maze[c.y][c.x] == ".":
			best = c
			best_d = d
	return best


func _round_seconds(tubig_count: int) -> float:
	# 1 Tubig: 3:00. Each extra Tubig can answer at the same time as the
	# others, so the round gets 20 s shorter per extra Tubig (never below 1:30).
	return max(min_round_time, round_time - less_time_per_extra_tubig * max(0, tubig_count - 1))


@rpc("authority", "call_local", "reliable")
func _spawn_all(roster: Array) -> void:
	var bot_index := 0
	for entry in roster:
		var id: int = entry[0]
		var slot: int = entry[1]
		var role: String = entry[2]
		var start: Vector2i = entry[3]
		var p := PLAYER_SCENE.instantiate()
		p.name = "Player_%d" % id          # identical node path on every device
		actors_root.add_child(p)
		if role == "tubig":
			p.setup(id, slot, role, tubigs.size(), cell_to_world(start))
			tubigs.append(p)
		else:
			p.setup(id, slot, role, silis.size(), cell_to_world(start))
			silis.append(p)
		player_by_id[id] = p
		if p.is_bot and multiplayer.is_server():
			var bot := BotSili.new()
			bot.name = "BotSili_%d" % id
			add_child(bot)
			bot.setup(self, p, Network.solo_round_info()["difficulty"], bot_index)
			_bots[id] = bot
			bot_index += 1
	var me = player_by_id.get(multiplayer.get_unique_id())
	if me:
		mode_label.text = "You: %s (%s)" % ["TUBIG" if me.is_tubig() else "SILI", Network.player_name_of(me.peer_id)]
		if Network.solo_bot:
			var info := Network.solo_round_info()
			mode_label.text = "%s  vs  %d bot%s" % [info["name"], info["bots"], "" if info["bots"] == 1 else "s"]
		minimap.set_local_player(me)
		local_player = me
		_follow_local_player()
		camera.reset_smoothing()   # jump straight to your start spot


@rpc("authority", "call_local", "reliable")
func _start_round(seconds: float) -> void:
	Sound.play("start")
	time_left = seconds
	correct_answers = 0
	GameState.round_state = GameState.RoundState.PLAYING
	_update_hud()
	var me = player_by_id.get(multiplayer.get_unique_id())
	var clock := "  (%s for %d Tubig%s)" % [_format_time(seconds), tubigs.size(), "" if tubigs.size() == 1 else "s"]
	if silis.is_empty():
		_show_message("Test mode: no Sili (needs 2+ players over LAN).", 4.0)
	elif Network.solo_bot:
		var info := Network.solo_round_info()
		_show_message("%s: run from %d Siling Labuyo bot%s! Answer %d questions!%s" % [info["name"].to_upper(),
			info["bots"], "" if info["bots"] == 1 else "s", questions_to_win, clock], 6.0)
	elif me and not me.is_tubig():
		_show_message("You are SILI! Freeze ALL Tubig before they answer %d questions! Bicol Express peppers = turbo.%s" % [questions_to_win, clock], 6.0)
	else:
		_show_message("You are TUBIG! Find ? scrolls and answer %d questions! Coolers = Yelo Shield.%s" % [questions_to_win, clock], 6.0)


# ============================================================= scrolls
func _host_spawn_scroll() -> void:
	# an open cell away from every Tubig and from the other scrolls
	var taken: Array[Vector2i] = []
	for s in scrolls.values():
		taken.append(world_to_cell(s.position))
	for st in stations:
		taken.append(st["cell"])   # never on top of a power-up
	var candidates: Array[Vector2i] = []
	for cell in floor_cells:
		if cell in taken or maze[cell.y][cell.x] != ".":
			continue
		var far_enough := true
		for t in tubigs:
			if cell_to_world(cell).distance_to(t.global_position) < 5 * TILE:
				far_enough = false
		if far_enough:
			candidates.append(cell)
	if candidates.is_empty():
		candidates = floor_cells
	_spawn_scroll.rpc(_next_scroll_id, candidates.pick_random())
	_next_scroll_id += 1


@rpc("authority", "call_local", "reliable")
func _spawn_scroll(id: int, cell: Vector2i) -> void:
	var scroll := SCROLL_SCENE.instantiate()
	scroll.name = "Scroll_%d" % id
	scroll.scroll_id = id
	scroll.position = cell_to_world(cell)
	scrolls_root.add_child(scroll)
	scrolls[id] = scroll


# ======================================================== quiz stations
# Power-up stations are placed at random every round, always inside the
# maze (never on its outer edge) and away from the start spots:
#   stall  - Halo-Halo coolers, one in each quarter of the maze (Tubig only)
#   pepper - Bicol Express peppers near the middle (Sili only)
#   gate   - Kalamansi gates on thin walls between two streets (anyone)
# Coolers and peppers stand on the road; walk up to one and press E (or
# tap USE on a phone) to answer its question. Gates: stand next to one.
const STATION_EDGE := 2          # cells kept free along the maze's outer edge
const STATION_SPACING := 4.0     # min cells between two stations


func _host_place_stations() -> Array:
	var w: int = maze[0].length()
	var h: int = maze.size()
	var chosen: Array[Vector2i] = []
	var out := []
	# --- coolers: a random road cell in each quarter of the maze
	var mid := Vector2i(w / 2, h / 2)
	var quarters := [Rect2i(0, 0, mid.x, mid.y), Rect2i(mid.x, 0, w - mid.x, mid.y),
		Rect2i(0, mid.y, mid.x, h - mid.y), Rect2i(mid.x, mid.y, w - mid.x, h - mid.y)]
	var flavors := [0, 1, 2, 3]
	flavors.shuffle()
	for i in quarters.size():
		var c := _random_station_cell(quarters[i], chosen)
		if c.x >= 0:
			chosen.append(c)
			out.append(["stall", c, [c], flavors[i]])
	# --- peppers: random road cells in the middle half of the maze
	var middle := Rect2i(w / 4, h / 4, w / 2, h / 2)
	for i in 2:
		var c := _random_station_cell(middle, chosen)
		if c.x < 0:
			c = _random_station_cell(Rect2i(0, 0, w, h), chosen)
		if c.x >= 0:
			chosen.append(c)
			out.append(["pepper", c, [c], i])
	# --- gates: thin walls whose detour is long, spread over the map
	var gate_cells := _gate_candidates(chosen)
	gate_cells.shuffle()
	var gates: Array[Vector2i] = []
	for c in gate_cells:
		if gates.size() >= gates_on_map:
			break
		var ok := true
		for g in gates:
			if Vector2(c - g).length() < 5.0:
				ok = false
		if ok:
			gates.append(c)
	for g in gates:
		var sides: Array = [g + Vector2i.LEFT, g + Vector2i.RIGHT] if is_floor(g + Vector2i.LEFT) and is_floor(g + Vector2i.RIGHT) \
			else [g + Vector2i.UP, g + Vector2i.DOWN]
		out.append(["gate", g, sides, 0])
	return out


## Inside the maze (not on its outer edge), not near a start spot.
func _inside_maze(c: Vector2i) -> bool:
	if c.x < STATION_EDGE or c.y < STATION_EDGE or c.x >= maze[0].length() - STATION_EDGE \
			or c.y >= maze.size() - STATION_EDGE:
		return false
	for start in _cells_with("P") + _cells_with("S"):
		if Vector2(c - start).length() < 3.0:
			return false
	return true


## A random plain road cell inside `area` that is far enough from `taken`.
func _random_station_cell(area: Rect2i, taken: Array[Vector2i]) -> Vector2i:
	var options: Array[Vector2i] = []
	for c in floor_cells:
		if not area.has_point(c) or maze[c.y][c.x] != "." or not _inside_maze(c):
			continue
		var ok := true
		for t in taken:
			if Vector2(c - t).length() < STATION_SPACING:
				ok = false
		if ok:
			options.append(c)
	return options.pick_random() if not options.is_empty() else Vector2i(-1, -1)


func _gate_candidates(taken: Array[Vector2i]) -> Array[Vector2i]:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, maze[0].length(), maze.size())
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in maze.size():
		for x in maze[y].length():
			if maze[y][x] == "#":
				astar.set_point_solid(Vector2i(x, y))
	var out: Array[Vector2i] = []
	for y in range(1, maze.size() - 1):
		for x in range(1, maze[0].length() - 1):
			var c := Vector2i(x, y)
			if maze[y][x] != "#":
				continue
			var a: Vector2i
			var b: Vector2i
			if is_floor(c + Vector2i.LEFT) and is_floor(c + Vector2i.RIGHT) and not is_floor(c + Vector2i.UP) and not is_floor(c + Vector2i.DOWN):
				a = c + Vector2i.LEFT
				b = c + Vector2i.RIGHT
			elif is_floor(c + Vector2i.UP) and is_floor(c + Vector2i.DOWN) and not is_floor(c + Vector2i.LEFT) and not is_floor(c + Vector2i.RIGHT):
				a = c + Vector2i.UP
				b = c + Vector2i.DOWN
			else:
				continue
			var near_taken := not _inside_maze(c)
			for t in taken:
				if Vector2(c - t).length() < 3.0:
					near_taken = true
			# a real shortcut: walking around is at least 10 cells
			if not near_taken and astar.get_id_path(a, b).size() >= 11:
				out.append(c)
	return out


@rpc("authority", "call_local", "reliable")
func _setup_stations(data: Array) -> void:
	var gate_coords := _gate_atlas_coords()
	for i in data.size():
		var entry: Array = data[i]
		var kind: String = entry[0]
		var cell: Vector2i = entry[1]
		var approach: Array = entry[2]
		var variant: int = entry[3]
		var st := {"id": i, "kind": kind, "cell": cell, "approach": approach, "cooldown": 0.0, "busy": false,
			"name": "", "node": null, "label": null}
		var node: Node2D
		match kind:
			"stall":
				st["name"] = STALL_NAMES[variant % STALL_NAMES.size()] + " cooler"
				var spr := Sprite2D.new()
				spr.texture = COOLER_TEXTURE
				spr.hframes = 4
				spr.frame = variant % 4
				node = spr
				node.position = cell_to_world(cell)
			"pepper":
				st["name"] = "Bicol Express pepper"
				var spr2 := Sprite2D.new()
				spr2.texture = PEPPER_TEXTURE
				node = spr2
				node.position = cell_to_world(cell)
			"gate":
				st["name"] = "Kalamansi gate"
				if gate_coords.x >= 0:
					maze_layer.set_cell(cell + _maze_cell_offset, 0, gate_coords)
				node = Node2D.new()
				node.position = cell_to_world(cell)
		node.name = "Station_%d" % i
		node.z_index = 1
		$Scrolls.add_child(node)
		var label := Label.new()
		label.text = st["name"]
		label.scale = Vector2(0.4, 0.4)
		label.size = Vector2(300, 30)
		label.position = Vector2(-60, -44)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		label.visible = false
		node.add_child(label)
		st["node"] = node
		st["label"] = label
		stations.append(st)


func _gate_atlas_coords() -> Vector2i:
	# the Kalamansi gate tile in city_tileset.tres (custom data "kind" = "gate")
	var ts := maze_layer.tile_set
	if ts == null or ts.get_source_count() == 0:
		return Vector2i(-1, -1)
	var src := ts.get_source(ts.get_source_id(0)) as TileSetAtlasSource
	for i in src.get_tiles_count():
		var coords := src.get_tile_id(i)
		var data := src.get_tile_data(coords, 0)
		if data and ts.get_custom_data_layers_count() > 0 and data.get_custom_data("kind") == "gate":
			return coords
	return Vector2i(-1, -1)


func _can_use_station(st: Dictionary, p: Node2D) -> bool:
	match st["kind"]:
		"stall":
			return p.is_tubig()
		"pepper":
			return not p.is_tubig()
	return true


## The station the local player could use right now (-1 = none):
## standing on a cooler / pepper, or right next to a gate.
func _station_in_reach(p: Node2D) -> int:
	var here := world_to_cell(p.global_position)
	var best := -1
	var best_d := INF
	for st in stations:
		if not _can_use_station(st, p):
			continue
		var d: float = p.global_position.distance_to(cell_to_world(st["cell"]))
		var in_reach: bool = (d <= 44.0 and here in st["approach"]) if st["kind"] == "gate" else d <= 30.0
		if in_reach and d < best_d:
			best_d = d
			best = st["id"]
	return best


## Local player: E (or USE on a phone) at a station asks the host for its quiz.
func _check_local_interact(delta: float) -> void:
	_interact_cooldown -= delta
	var me = local_player
	var touch: Control = $HUD/TouchControls
	if not is_instance_valid(me) or GameState.round_state != GameState.RoundState.PLAYING:
		touch.use_available = false
		return
	var key := "tap USE" if GameState.touch_controls else "press E"
	var reach := _station_in_reach(me) if not (me.frozen or me.answering or me.stun_time > 0.0) else -1
	for st in stations:
		var near: bool = me.global_position.distance_to(cell_to_world(st["cell"])) < 75.0
		st["label"].visible = near and _can_use_station(st, me)
		if near:
			if st["cooldown"] > 0.0:
				st["label"].text = "%s  (rest %ds)" % [st["name"], ceili(st["cooldown"])]
			elif st["id"] == reach:
				st["label"].text = "%s - %s!" % [st["name"], key]
			else:
				st["label"].text = st["name"]
	touch.use_available = reach >= 0 and stations[reach]["cooldown"] <= 0.0
	if reach < 0 or _interact_cooldown > 0.0 or stations[reach]["cooldown"] > 0.0:
		return
	if Input.is_action_just_pressed("interact"):
		_interact_cooldown = 0.5
		if multiplayer.is_server():
			_host_try_interact(multiplayer.get_unique_id(), reach)
		else:
			_request_interact.rpc_id(1, reach)


@rpc("any_peer", "call_remote", "reliable")
func _request_interact(station_id: int) -> void:
	_host_try_interact(multiplayer.get_remote_sender_id(), station_id)


func _host_try_interact(peer: int, station_id: int) -> void:
	if station_id < 0 or station_id >= stations.size() or not player_by_id.has(peer):
		return
	if GameState.round_state != GameState.RoundState.PLAYING:
		return
	var st: Dictionary = stations[station_id]
	var p = player_by_id[peer]
	if not station_ready(station_id, p) or p.frozen or p.answering or p.stun_time > 0.0:
		return
	var d: float = p.global_position.distance_to(cell_to_world(st["cell"]))
	if d > (52.0 if st["kind"] == "gate" else 36.0):
		return   # too far (a little slack for network delay)
	st["busy"] = true
	match st["kind"]:
		"stall":
			_host_open_question("shield", peer, {"station": station_id})
		"pepper":
			_host_open_question("turbo", peer, {"station": station_id})
		"gate":
			var from := world_to_cell(p.global_position)
			var to: Vector2i = st["approach"][1] if from == st["approach"][0] else st["approach"][0]
			_host_open_question("gate", peer, {"station": station_id, "to": to})


func station_ready(station_id: int, p: Node2D) -> bool:
	var st: Dictionary = stations[station_id]
	return st["cooldown"] <= 0.0 and not st["busy"] and _can_use_station(st, p) \
		and Time.get_ticks_msec() >= int(_retry_at.get("%d:st%d" % [p.peer_id, station_id], 0))


## For bots: the closest usable station of a kind (-1 = none).
func nearest_ready_station(p: Node2D, kind: String) -> int:
	var best := -1
	var best_d := INF
	for st in stations:
		if st["kind"] == kind and station_ready(st["id"], p):
			var d: float = p.global_position.distance_to(cell_to_world(st["cell"]))
			if d < best_d:
				best_d = d
				best = st["id"]
	return best


func station_approach_point(station_id: int) -> Vector2:
	return cell_to_world(stations[station_id]["approach"][0])


func station_world_pos(station_id: int) -> Vector2:
	return cell_to_world(stations[station_id]["cell"])


@rpc("authority", "call_local", "reliable")
func _station_cooldown(station_id: int, seconds: float) -> void:
	if station_id >= 0 and station_id < stations.size():
		stations[station_id]["cooldown"] = seconds


func _update_stations(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for st in stations:
		if GameState.round_state == GameState.RoundState.PLAYING:
			st["cooldown"] = max(0.0, st["cooldown"] - delta)
		var node: Node2D = st["node"]
		if st["kind"] != "gate":
			node.modulate = Color(0.45, 0.45, 0.5, 0.75) if st["cooldown"] > 0.0 else Color.WHITE
			(node as Sprite2D).offset = Vector2(0, -1.5 + sin(t * 3.0 + st["id"]) * 1.5) if st["cooldown"] <= 0.0 else Vector2.ZERO


# =========================================================== questions
func _pool(name: String) -> Array:
	match name:
		"hard":
			return QuestionBank.HARD
		"bugtong":
			return QuestionBank.BUGTONG
	return QuestionBank.QUESTIONS


func _host_next_question_index(pool: String) -> int:
	var deck: Array = _decks.get(pool, [])
	if deck.is_empty():
		deck = range(_pool(pool).size())
		deck.shuffle()
		_decks[pool] = deck
	return deck.pop_back()


func _kind_time(kind: String) -> float:
	return quiz_panel.answer_time if kind == "scroll" else KINDS[kind]["time"]


# Several players can answer at the same time: every open question has its
# own id, kind, answerer, timer and (scrolls only, at most one) helper.
#   host:     _questions[qid] = {kind, picker, asker, pool, index, order, answered,
#             help_asked, passed, full_stop, deadline, result_timer, correct, extra}
#   everyone: questions[qid]  = {kind, picker, asker, pool, index, order, asked, full_stop, extra}
func _host_open_question(kind: String, picker_id: int, extra: Dictionary = {}, scroll_id: int = -1) -> void:
	if kind == "scroll":
		questions_asked += 1
	var qid := _next_question_id
	_next_question_id += 1
	var order := [0, 1, 2, 3]
	order.shuffle()
	# Only one Tubig in the game and a scroll: nobody else can play, so the
	# whole chase stops (the Sili sees "Tubig is answering"). Otherwise only
	# the answerer stops and everyone else keeps playing.
	var full_stop := kind == "scroll" and tubigs.size() <= 1
	var pool: String = KINDS[kind]["pool"]
	var index := _host_next_question_index(pool)
	var q := {"kind": kind, "picker": picker_id, "asker": picker_id, "pool": pool, "index": index, "order": order,
		"answered": false, "help_asked": false, "passed": false, "full_stop": full_stop,
		"deadline": _question_deadline(kind), "result_timer": -1.0, "correct": false, "extra": extra}
	if _bots.has(picker_id):
		# a bot "thinks" for a few seconds, then answers (right or wrong by difficulty)
		q["bot_at"] = Time.get_ticks_msec() + int(randf_range(2.0, 4.0) * 1000.0)
		q["bot_correct"] = _bots[picker_id].answers_correctly()
	_questions[qid] = q
	_open_question.rpc(qid, kind, scroll_id, picker_id, pool, index, order, questions_asked, full_stop, extra)


func _question_deadline(kind: String) -> int:
	# the host's own time limit: the answer time plus a little network slack
	return Time.get_ticks_msec() + int((_kind_time(kind) + 2.0) * 1000)


@rpc("authority", "call_local", "reliable")
func _open_question(qid: int, kind: String, scroll_id: int, picker_id: int, pool: String, q_index: int,
		order: Array, asked: int, full_stop: bool, extra: Dictionary) -> void:
	if scrolls.has(scroll_id):
		scrolls[scroll_id].queue_free()
		scrolls.erase(scroll_id)
	questions_asked = asked
	questions[qid] = {"kind": kind, "picker": picker_id, "asker": picker_id, "pool": pool, "index": q_index,
		"order": order, "asked": asked, "full_stop": full_stop, "extra": extra}
	if full_stop:
		GameState.round_state = GameState.RoundState.QUESTION   # everyone stops, clock stops
	var picker = player_by_id.get(picker_id)
	if picker:
		picker.set_answering(true)
	var picker_name := Network.player_name_of(picker_id)
	var entry: Dictionary = _pool(pool)[q_index]
	if picker_id == multiplayer.get_unique_id():
		my_question = qid
		_help_queue.clear()   # busy answering: no help alerts for me now
		_help_showing = -1
		help_alert.close()
		quiz_panel.show_question(entry, order, _question_header(kind, picker_name, asked, extra),
			true, picker_name, kind == "scroll" and not full_stop, _kind_time(kind))
		if help_locked_by != 0 and kind == "scroll":
			quiz_panel.set_help_locked(true, Network.player_name_of(help_locked_by))
		return
	var me = player_by_id.get(multiplayer.get_unique_id())
	if full_stop:
		if me and not me.is_tubig():
			answering_notice.open()
		return
	match kind:
		"scroll":
			_show_message("%s is answering a question — can't be tagged!" % picker_name, 3.0)
		"rescue":
			_show_message("%s is splashing %s free — Buhos-Tubig!" % [picker_name, Network.player_name_of(extra.get("target", 0))], 3.0)
		"thaw":
			_show_message("%s is trying to thaw out — Huling Hirit!" % picker_name, 3.0)
		"turbo":
			_show_message("%s is solving a bugtong for EXTRA ANGHANG!" % picker_name, 3.0)


func _question_header(kind: String, picker_name: String, asked: int, extra: Dictionary) -> String:
	match kind:
		"rescue":
			return "BUHOS-TUBIG!  Answer to splash %s free" % Network.player_name_of(extra.get("target", 0))
		"thaw":
			return "HULING HIRIT  %d / 2  —  answer 2 in a row to thaw yourself!" % extra.get("step", 1)
		"shield":
			return "%s  —  answer for a %d s YELO SHIELD!" % [stations[extra["station"]]["name"].to_upper(), int(shield_time)]
		"turbo":
			return "BICOL EXPRESS  —  solve the bugtong for EXTRA ANGHANG!"
		"gate":
			return "KALAMANSI GATE  —  answer to squeeze through (wrong = sour spray!)"
	return "Scroll #%d  —  picked by %s  —  Correct: %d / %d" % [asked, picker_name, correct_answers, questions_to_win]


func _on_local_choice(position: int) -> void:
	if my_question < 0:
		return
	if multiplayer.is_server():
		_host_receive_answer(multiplayer.get_unique_id(), my_question, position)
	else:
		_submit_answer.rpc_id(1, my_question, position)


@rpc("any_peer", "call_remote", "reliable")
func _submit_answer(qid: int, position: int) -> void:
	_host_receive_answer(multiplayer.get_remote_sender_id(), qid, position)


func _host_receive_answer(sender: int, qid: int, position: int) -> void:
	var q: Dictionary = _questions.get(qid, {})
	if q.is_empty() or q["answered"] or sender != q["picker"]:
		return   # only the player who has this question may answer it
	_host_resolve(qid, position)


func _host_resolve(qid: int, position: int) -> void:
	var q: Dictionary = _questions[qid]
	q["answered"] = true
	if _help_active == qid:
		_host_release_help()   # the question is over, so its help request is too
	var entry: Dictionary = _pool(q["pool"])[q["index"]]
	var correct: bool = position >= 0 and q["order"][position] == entry["answer"]
	q["correct"] = correct
	var total := correct_answers
	if q["kind"] == "scroll" and correct:
		_count(q["picker"], "correct")   # whoever answered (the helper, if it was passed)
		total += 1
	_question_result.rpc(qid, position, correct, total)
	q["result_timer"] = feedback_time
	if total >= questions_to_win:
		# the last correct answer wins at once: don't wait for the popup,
		# or the round clock could run out first and give the Sili the win
		_host_end(true, "TUBIG TEAM WINS!")


@rpc("authority", "call_local", "reliable")
func _question_result(qid: int, position: int, correct: bool, total: int) -> void:
	correct_answers = total
	var q: Dictionary = questions.get(qid, {})
	if q.is_empty():
		return
	_forget_help_request(qid)
	var entry: Dictionary = _pool(q["pool"])[q["index"]]
	var picker_name := Network.player_name_of(q["picker"])
	var mine: bool = q["picker"] == multiplayer.get_unique_id()
	if mine:
		quiz_panel.show_result(position, correct)
		quiz_panel.close()
		my_question = -1
		Sound.play("correct" if correct else "wrong")
		GameState.buzz(40 if correct else 140)
	if q["full_stop"]:
		answering_notice.close()
	if mine:
		# the big TAMA! / MALI! popup is only for the player who answered
		popup_question = qid
		answer_popup.open(correct, position < 0, picker_name, entry["choices"][entry["answer"]],
			entry.get("fact", ""), total, questions_to_win, _result_line(q, correct))
	elif q["kind"] == "scroll":
		# everyone else (other Tubigs and the Sili) just gets a short line
		var what := "answered correctly" if correct else ("ran out of time" if position < 0 else "answered wrong")
		_show_message("%s %s  (%d / %d)" % [picker_name, what, total, questions_to_win], 3.5)
	_update_hud()


func _result_line(q: Dictionary, correct: bool) -> String:
	var extra: Dictionary = q["extra"]
	match q["kind"]:
		"rescue":
			var who := Network.player_name_of(extra.get("target", 0))
			return ("%s is splashed free!" % who) if correct else ("%s stays frozen... try again!" % who)
		"thaw":
			if not correct:
				return "You stay frozen..."
			return "1 of 2 — one more!" if extra.get("step", 1) == 1 else "You thawed yourself!"
		"shield":
			return ("YELO SHIELD for %d s!" % int(shield_time)) if correct else "No shield this time."
		"turbo":
			return ("EXTRA ANGHANG for %d s!" % int(turbo_time)) if correct else "Too mild... no turbo."
		"gate":
			return "You squeeze through the gate!" if correct else ("Sour spray! Slowed for %d s" % int(slow_time))
	return ""


func _host_after_question(qid: int) -> void:
	var q: Dictionary = _questions[qid]
	_questions.erase(qid)
	if GameState.round_state == GameState.RoundState.ENDED:
		return
	if correct_answers >= questions_to_win:
		_host_end(true, "TUBIG TEAM WINS!")
		return
	var picker_id: int = q["picker"]
	var correct: bool = q["correct"]
	var extra: Dictionary = q["extra"]
	if extra.has("station"):
		stations[extra["station"]]["busy"] = false
	_resume_after_question.rpc(qid)
	match q["kind"]:
		"scroll":
			_host_spawn_scroll()
		"rescue":
			var target: int = extra.get("target", 0)
			_rescuing.erase(target)
			var t = player_by_id.get(target)
			if correct and t and t.frozen:
				_count(picker_id, "rescues")
				_tubig_rescued.rpc(target, false)
			else:
				_retry_at["%d:rescue%d" % [picker_id, target]] = Time.get_ticks_msec() + 2500
		"thaw":
			_thawing.erase(picker_id)
			var me = player_by_id.get(picker_id)
			if me == null or not me.frozen:
				pass
			elif correct and extra.get("step", 1) == 1:
				_host_start_thaw(picker_id, 2)   # one more in a row
			elif correct:
				_tubig_rescued.rpc(picker_id, true)
			else:
				_host_check_team_out(true)
		"shield":
			if correct:
				_apply_effect.rpc(picker_id, "shield", shield_time)
				_station_cooldown.rpc(extra["station"], stall_cooldown)
			else:
				_retry_at["%d:st%d" % [picker_id, extra["station"]]] = Time.get_ticks_msec() + int(retry_cooldown * 1000)
		"turbo":
			if correct:
				_apply_effect.rpc(picker_id, "turbo", turbo_time)
				_station_cooldown.rpc(extra["station"], pepper_cooldown)
			else:
				_retry_at["%d:st%d" % [picker_id, extra["station"]]] = Time.get_ticks_msec() + int(retry_cooldown * 1000)
		"gate":
			if correct:
				_move_player.rpc(picker_id, cell_to_world(extra["to"]))
			else:
				_apply_effect.rpc(picker_id, "slow", slow_time)
				_retry_at["%d:st%d" % [picker_id, extra["station"]]] = Time.get_ticks_msec() + int(retry_cooldown * 1000)


@rpc("authority", "call_local", "reliable")
func _resume_after_question(qid: int) -> void:
	var q: Dictionary = questions.get(qid, {})
	questions.erase(qid)
	if popup_question == qid:
		answer_popup.close()
		popup_question = -1
	if q.is_empty():
		return
	var picker = player_by_id.get(q["picker"])
	if picker:
		picker.set_answering(false)
		if not picker.frozen:
			picker.give_grace(grace_after_question)   # a waiting Sili can't tag them at once
	if q["full_stop"]:
		for t in tubigs:
			if not t.frozen:
				t.give_grace(grace_after_question)
		GameState.round_state = GameState.RoundState.PLAYING


@rpc("authority", "call_local", "reliable")
func _apply_effect(peer: int, effect: String, seconds: float) -> void:
	var p = player_by_id.get(peer)
	if p == null:
		return
	p.apply_effect(effect, seconds)
	var who := Network.player_name_of(peer)
	match effect:
		"shield":
			_show_message("%s has a YELO SHIELD! A Sili who tags them gets extinguished." % who, 3.0)
		"turbo":
			_show_message("%s got EXTRA ANGHANG! Faster, with a wider reach!" % who, 3.0)
		"slow":
			if p.is_local():
				_show_message("Maasim! Kalamansi spray — slowed for %d s" % int(seconds), 2.5)


@rpc("authority", "call_local", "reliable")
func _move_player(peer: int, pos: Vector2) -> void:
	var p = player_by_id.get(peer)
	if p:
		p.force_position(pos)
		p.give_grace(grace_after_question)
		if p.is_local():
			_show_message("You squeezed through the Kalamansi gate!", 2.0)


# ============================================================ asking for help
# The answerer presses ASK A TEAMMATE FOR HELP (once per scroll question).
# Every free teammate gets a bottom-right alert; the FIRST one who says YES
# gets the question with a fresh timer, and the asker goes back to the chase.
# If several teammates ask at the same time, the alerts wait in a queue.
func _on_help_pressed() -> void:
	if my_question < 0:
		return
	if multiplayer.is_server():
		_host_help_request(multiplayer.get_unique_id(), my_question)
	else:
		_request_help.rpc_id(1, my_question)


@rpc("any_peer", "call_remote", "reliable")
func _request_help(qid: int) -> void:
	_host_help_request(multiplayer.get_remote_sender_id(), qid)


func _host_help_request(sender: int, qid: int) -> void:
	var q: Dictionary = _questions.get(qid, {})
	if q.is_empty() or q["kind"] != "scroll" or q["answered"] or q["full_stop"] or q["help_asked"] or sender != q["picker"]:
		return
	if _help_active >= 0:
		# someone else pressed first (same instant): this button waits too
		var locker: int = _questions[_help_active]["picker"]
		if sender == 1:
			_help_rejected(locker)
		else:
			_help_rejected.rpc_id(sender, locker)
		return
	q["help_asked"] = true
	var helpers := 0
	for t in tubigs:
		if t.peer_id != sender and not t.frozen and not t.answering:
			helpers += 1
	if helpers == 0:
		if sender == 1:
			_help_unavailable()
		else:
			_help_unavailable.rpc_id(sender)
		return
	_help_active = qid
	_help_lock.rpc(sender)    # lock everyone else's help button
	_help_asked.rpc(qid, sender)


func _host_release_help() -> void:
	_help_active = -1
	_help_lock.rpc(0)


@rpc("authority", "call_local", "reliable")
func _help_lock(asker_id: int) -> void:
	# only ONE Tubig can ask for help at a time; the others' buttons wait
	help_locked_by = asker_id
	if my_question >= 0 and asker_id != multiplayer.get_unique_id() \
			and questions.get(my_question, {}).get("kind", "") == "scroll":
		quiz_panel.set_help_locked(asker_id != 0, Network.player_name_of(asker_id))


@rpc("authority", "call_remote", "reliable")
func _help_rejected(locker_id: int) -> void:
	quiz_panel.help_rejected(Network.player_name_of(locker_id))


@rpc("authority", "call_remote", "reliable")
func _help_unavailable() -> void:
	quiz_panel.help_unavailable()


@rpc("authority", "call_local", "reliable")
func _help_asked(qid: int, asker_id: int) -> void:
	var me = player_by_id.get(multiplayer.get_unique_id())
	if me and me.is_tubig() and me.peer_id != asker_id:
		_help_queue.append(qid)
		_show_next_help_request()


func _show_next_help_request() -> void:
	# one alert at a time; skip requests that are over or that I can't take
	var me = player_by_id.get(multiplayer.get_unique_id())
	while not _help_queue.is_empty():
		if help_alert.visible and _help_showing == _help_queue[0]:
			return
		var qid: int = _help_queue[0]
		var q: Dictionary = questions.get(qid, {})
		if q.is_empty() or q["picker"] != q["asker"] or not me or me.frozen or me.answering:
			_help_queue.pop_front()
			continue
		if not help_alert.visible or _help_showing != qid:
			Sound.play("help")
		_help_showing = qid
		help_alert.open(Network.player_name_of(q["asker"]))
		return
	_help_showing = -1
	help_alert.close()


func _forget_help_request(qid: int) -> void:
	_help_queue.erase(qid)
	if _help_showing == qid:
		_help_showing = -1
		help_alert.close()
	_show_next_help_request()


func _on_help_answer(yes: bool) -> void:
	var qid := _help_showing
	_help_queue.erase(qid)
	_help_showing = -1
	if yes and qid >= 0:
		if multiplayer.is_server():
			_host_help_offer(multiplayer.get_unique_id(), qid)
		else:
			_offer_help.rpc_id(1, qid)
	_show_next_help_request()


@rpc("any_peer", "call_remote", "reliable")
func _offer_help(qid: int) -> void:
	_host_help_offer(multiplayer.get_remote_sender_id(), qid)


func _host_help_offer(helper_id: int, qid: int) -> void:
	# only the first YES counts, and only from a free teammate
	var q: Dictionary = _questions.get(qid, {})
	if q.is_empty() or q["answered"] or q["passed"] or not player_by_id.has(helper_id):
		return
	var helper = player_by_id[helper_id]
	if not helper.is_tubig() or helper.frozen or helper.answering or helper_id == q["picker"]:
		return
	q["passed"] = true
	q["picker"] = helper_id
	q["deadline"] = _question_deadline(q["kind"])   # the helper gets a fresh timer
	_question_passed.rpc(qid, helper_id)
	if _help_active == qid:
		_host_release_help()   # the request was answered: others may ask now


@rpc("authority", "call_local", "reliable")
func _question_passed(qid: int, helper_id: int) -> void:
	var q: Dictionary = questions.get(qid, {})
	if q.is_empty():
		return
	var asker_id: int = q["picker"]
	q["picker"] = helper_id
	_forget_help_request(qid)
	var asker = player_by_id.get(asker_id)
	var helper = player_by_id.get(helper_id)
	var asker_name := Network.player_name_of(asker_id)
	var helper_name := Network.player_name_of(helper_id)
	if asker:
		asker.set_answering(false)
		asker.give_grace(grace_after_question)
	if helper:
		helper.set_answering(true)
	if helper_id == multiplayer.get_unique_id():
		my_question = qid
		help_alert.close()
		_help_queue.clear()   # busy answering now
		quiz_panel.show_question(_pool(q["pool"])[q["index"]], q["order"],
			"Helping %s  —  Scroll #%d  —  Correct: %d / %d" % [asker_name, q["asked"], correct_answers, questions_to_win],
			true, helper_name, false)
	elif asker_id == multiplayer.get_unique_id():
		my_question = -1
		quiz_panel.close()
	_show_message("%s is helping %s with the question!" % [helper_name, asker_name], 3.0)


# ====================================================== catch / rescue
func _host_check_tags() -> void:
	for s in silis:
		if not s.can_tag():
			continue
		var reach := tag_radius_of(s)
		for t in tubigs:
			if t.can_be_tagged() and s.global_position.distance_to(t.global_position) <= reach:
				if t.shield_time > 0.0:
					_shield_block.rpc(t.peer_id, s.peer_id)   # Yelo Shield: the Sili gets extinguished
				else:
					_count(s.peer_id, "tags")
					_tubig_caught.rpc(t.peer_id)
				break
	_host_check_team_out()


@rpc("authority", "call_local", "reliable")
func _shield_block(tubig_id: int, sili_id: int) -> void:
	var t = player_by_id.get(tubig_id)
	var s = player_by_id.get(sili_id)
	if t:
		t.shield_time = 0.0
		t.give_grace(1.0)
	if s:
		s.apply_effect("stun", sili_stun_time)
	Sound.play("correct")
	if (t and t.is_local()) or (s and s.is_local()):
		GameState.buzz(80)
	_show_message("YELO SHIELD! %s's tag was blocked — %s is extinguished for %d s!" % [
		Network.player_name_of(tubig_id), Network.player_name_of(sili_id), int(sili_stun_time)], 3.0)


@rpc("authority", "call_local", "reliable")
func _tubig_caught(id: int) -> void:
	if not player_by_id.has(id):
		return
	var t = player_by_id[id]
	t.set_caught()
	if t.is_local():
		help_alert.close()
		GameState.buzz(250)
	var free := _free_tubig_count()
	if free > 0:
		_show_message("%s was caught! %d Tubig still free — touch them and answer to splash them free!" % [Network.player_name_of(t.peer_id), free], 3.0)
	_update_hud()


@rpc("authority", "call_local", "reliable")
func _tubig_rescued(id: int, self_thaw: bool) -> void:
	if not player_by_id.has(id):
		return
	var t = player_by_id[id]
	t.set_rescued()
	if self_thaw:
		t.give_grace(2.0)
		_show_message("%s thawed out with a Huling Hirit!" % Network.player_name_of(t.peer_id), 2.5)
	else:
		_show_message("Buhos-Tubig! %s is saved!" % Network.player_name_of(t.peer_id), 2.0)
	_update_hud()


# The Sili team wins only when EVERY Tubig is frozen at the same time
# (with many Tubigs, catching one is not enough: teammates can save them).
func _free_tubig_count() -> int:
	var free := 0
	for t in tubigs:
		if not t.frozen:
			free += 1
	return free


func _thaws_left(t: Node2D) -> int:
	var allowed := solo_self_thaws if tubigs.size() == 1 else team_self_thaws
	return allowed - int(_thaw_uses.get(t.peer_id, 0))


## after_failed_thaw: a Huling Hirit just failed, so don't wait for another.
func _host_check_team_out(after_failed_thaw: bool = false) -> void:
	if GameState.round_state != GameState.RoundState.PLAYING or silis.is_empty():
		return
	if _free_tubig_count() > 0:
		return
	# the only Tubig in the game still has a Huling Hirit (self-thaw) left
	if tubigs.size() == 1 and not after_failed_thaw:
		var t = tubigs[0]
		if _thawing.has(t.peer_id) or _thaws_left(t) > 0:
			return
	var title := "SILI WINS! ALL TUBIG FROZEN"
	if tubigs.size() == 1:
		title = "SILI WINS! %s STAYED FROZEN" % Network.player_name_of(tubigs[0].peer_id).to_upper()
	_host_end(false, title)


func _host_check_rescues() -> void:
	# Buhos-Tubig: touching a frozen teammate opens a question for the helper;
	# a correct answer splashes them free
	for frozen_t in tubigs:
		if not frozen_t.can_be_rescued(min_frozen_time) or frozen_t.answering or _rescuing.has(frozen_t.peer_id):
			continue
		for helper in tubigs:
			if helper == frozen_t or helper.frozen or helper.answering:
				continue
			if helper.global_position.distance_to(frozen_t.global_position) > rescue_distance:
				continue
			if Time.get_ticks_msec() < int(_retry_at.get("%d:rescue%d" % [helper.peer_id, frozen_t.peer_id], 0)):
				continue
			_rescuing[frozen_t.peer_id] = _next_question_id
			_host_open_question("rescue", helper.peer_id, {"target": frozen_t.peer_id})
			break


func _host_check_self_thaw() -> void:
	# Huling Hirit: the only Tubig (solo), or a Tubig with no teammate near
	# for a while, can thaw themselves by answering 2 hard questions in a row
	for t in tubigs:
		if not t.frozen or t.answering or _thawing.has(t.peer_id) or _rescuing.has(t.peer_id) or _thaws_left(t) <= 0:
			continue
		if tubigs.size() == 1:
			if t.frozen_time >= min_frozen_time:
				_thaw_uses[t.peer_id] = int(_thaw_uses.get(t.peer_id, 0)) + 1
				_host_start_thaw(t.peer_id, 1)
			continue
		if t.frozen_time < self_thaw_wait or _free_tubig_count() == 0:
			continue
		var helper_near := false
		for other in tubigs:
			if other != t and not other.frozen and other.global_position.distance_to(t.global_position) <= self_thaw_far:
				helper_near = true
		if not helper_near:
			_thaw_uses[t.peer_id] = int(_thaw_uses.get(t.peer_id, 0)) + 1
			_host_start_thaw(t.peer_id, 1)


func _host_start_thaw(peer: int, step: int) -> void:
	_thawing[peer] = _next_question_id
	_host_open_question("thaw", peer, {"step": step})


func _host_check_pickups() -> void:
	# any free Tubig can open a scroll, even while teammates are answering
	for id in scrolls:
		for t in tubigs:   # only Tubigs can open scrolls
			if not t.frozen and not t.answering \
					and t.global_position.distance_to(scrolls[id].position) <= pickup_distance:
				_host_open_question("scroll", t.peer_id, {}, id)
				return   # the scroll list just changed; the next frame checks the rest


func _host_on_peer_left(id: int) -> void:
	if player_by_id.has(id):
		_remove_player.rpc(id)
		for qid in _questions.keys():
			if _questions[qid]["picker"] == id and not _questions[qid]["answered"]:
				_host_resolve(qid, -1)
		_rescuing.erase(id)
		_thawing.erase(id)
		if GameState.round_state in [GameState.RoundState.PLAYING, GameState.RoundState.QUESTION, GameState.RoundState.PAUSED]:
			if silis.is_empty():
				_host_end(true, "THE SILI LEFT — TUBIG WINS!")
			elif tubigs.is_empty():
				_host_end(false, "ALL TUBIG LEFT — SILI WINS!")
			else:
				_host_check_team_out()
	_host_try_begin()   # in case we were waiting for the player who left


@rpc("authority", "call_local", "reliable")
func _remove_player(id: int) -> void:
	if player_by_id.has(id):
		var p = player_by_id[id]
		tubigs.erase(p)
		silis.erase(p)
		player_by_id.erase(id)
		p.queue_free()
		_show_message("%s left the game." % Network.player_name_of(p.peer_id), 2.5)
		_update_hud()   # the Frozen: X / Y count changes


# ============================================================ per frame
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	for qid in _questions.keys():
		if not _questions.has(qid):
			continue   # already closed this frame (e.g. the round ended)
		var q: Dictionary = _questions[qid]
		if q["answered"]:
			q["result_timer"] -= delta
			if q["result_timer"] <= 0.0:
				_host_after_question(qid)
		elif GameState.round_state == GameState.RoundState.PAUSED:
			q["deadline"] += int(delta * 1000.0)   # the answer clock waits while paused
			if q.has("bot_at"):
				q["bot_at"] += int(delta * 1000.0)
		elif q.has("bot_at") and now >= q["bot_at"]:
			var right: int = q["order"].find(_pool(q["pool"])[q["index"]]["answer"])
			_host_resolve(qid, right if q["bot_correct"] else (right + 1) % 4)
		elif now > q["deadline"]:
			_host_resolve(qid, -1)   # answerer never answered (e.g. disconnected)
	if GameState.round_state == GameState.RoundState.PLAYING:
		for s in silis:
			if s.is_bot and s.bot_interact >= 0:
				_host_try_interact(s.peer_id, s.bot_interact)
				s.bot_interact = -1
		_host_check_tags()
		_host_check_rescues()
		_host_check_self_thaw()
		_host_check_pickups()


func _process(delta: float) -> void:
	_follow_local_player()
	_update_stations(delta)
	_check_local_interact(delta)
	_update_fps_label(delta)
	_update_leave_button()
	if is_instance_valid(local_player):
		_effect_label.text = local_player.effect_text()
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.text = ""
	if GameState.round_state != GameState.RoundState.PLAYING:
		warning_glow.modulate.a = 0.0
		warning_label.text = ""
		return
	_update_warning()


func _update_warning() -> void:
	# "!" over every Tubig near a Sili; the big banner is for YOUR Tubig.
	# The warning uses only the Sili players' positions.
	var my_level := 0
	for t in tubigs:
		var nearest := INF
		for s in silis:
			nearest = min(nearest, t.global_position.distance_to(s.global_position))
		var level := 0
		if not t.frozen and not t.answering:
			if nearest <= danger_distance:
				level = 2
			elif nearest <= warn_distance:
				level = 1
		t.set_alert(level)
		if t.is_local():
			my_level = level
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
	var me = player_by_id.get(multiplayer.get_unique_id())
	# warning sound when the danger level goes up (at most every 3 s)
	if me and me.is_tubig() and my_level > _last_warn_level and Time.get_ticks_msec() - _last_warn_sound > 3000:
		Sound.play("sili_near")
		_last_warn_sound = Time.get_ticks_msec()
	_last_warn_level = my_level
	if me and not me.is_tubig():
		warning_label.text = ""        # Silis don't get the warning
		warning_glow.modulate.a = 0.0
		return
	match my_level:
		2:
			warning_label.text = "RUN! SILI IS RIGHT THERE!"
			warning_glow.modulate.a = 0.55 + 0.45 * pulse
		1:
			warning_label.text = "!! SILI NEARBY !!"
			warning_glow.modulate.a = 0.25 + 0.25 * pulse
		_:
			warning_label.text = ""
			warning_glow.modulate.a = 0.0
	warning_label.modulate.a = 0.6 + 0.4 * pulse


# ========================================================== round flow
func _host_tick() -> void:
	if GameState.round_state != GameState.RoundState.PLAYING:
		return
	time_left -= 1.0
	_sync_time.rpc(time_left)
	if time_left <= 0:
		_host_end(false, "TIME'S UP — SILI WINS!")


@rpc("authority", "call_local", "unreliable_ordered")
func _sync_time(t: float) -> void:
	time_left = t
	_update_hud()


func _format_time(seconds: float) -> String:
	var total_seconds := int(max(seconds, 0.0))
	var minutes := total_seconds / 60
	var secs := total_seconds % 60
	return "%d:%02d" % [minutes, secs]


func _count(peer_id: int, what: String) -> void:
	if _stats.has(peer_id):
		_stats[peer_id][what] += 1


func _host_end(team_won: bool, title: String) -> void:
	if GameState.round_state == GameState.RoundState.ENDED:
		return
	round_timer.stop()
	_questions.clear()     # open questions end with the round
	_help_active = -1
	var stats := "Correct answers: %d / %d\nScrolls opened: %d\nTime left: %s" % \
		[correct_answers, questions_to_win, questions_asked, _format_time(time_left)]
	# leaderboard results for everyone still in the game (not for solo rounds)
	var results := []
	if not silis.is_empty() and not Network.solo_bot:
		for id in player_by_id:
			var s: Dictionary = _stats.get(id, {"correct": 0, "tags": 0, "rescues": 0})
			results.append({"id": id, "name": Network.player_name_of(id), "won": player_by_id[id].is_tubig() == team_won,
				"correct": s["correct"], "tags": s["tags"], "rescues": s["rescues"]})
	_end_round.rpc(team_won, title, stats, results)


@rpc("authority", "call_local", "reliable")
func _end_round(team_won: bool, title: String, stats: String, results: Array) -> void:
	GameState.round_state = GameState.RoundState.ENDED
	quiz_panel.close()
	answer_popup.close()
	help_alert.close()
	answering_notice.close()
	questions.clear()
	my_question = -1
	popup_question = -1
	_help_queue.clear()
	_help_showing = -1
	help_locked_by = 0
	warning_label.text = ""
	warning_glow.modulate.a = 0.0
	var result: Label = $HUD/EndPanel/Margin/VBox/ResultLabel
	result.text = title
	result.modulate = Color(0.5, 0.85, 1.0) if team_won else Color(1.0, 0.45, 0.4)
	var me = player_by_id.get(multiplayer.get_unique_id())
	var verdict := ""
	if me:
		verdict = "You win!" if me.is_tubig() == team_won else "You lose!"
	$HUD/EndPanel/Margin/VBox/StatsLabel.text = verdict + "\n" + stats
	# "game over" for everyone, then win or lose for this player
	var over_len := Sound.play("game_over")
	if me:
		var result_sound := "win" if me.is_tubig() == team_won else "lose"
		get_tree().create_timer(over_len).timeout.connect(func(): Sound.play(result_sound))
	if not results.is_empty():
		Leaderboard.record(results)   # saved on this device; shown on the title screen
		for r in results:
			if r["id"] == multiplayer.get_unique_id():
				$HUD/EndPanel/Margin/VBox/StatsLabel.text += "\n\nYou earned +%d points (see TOP PLAYERS)" % Leaderboard.points_for(r)
	play_again_button.visible = multiplayer.is_server()
	play_again_button.text = "Play Again (next Sili)" if Network.online else "Play Again"
	menu_button.text = "Main Menu" if not Network.online else "Leave"
	if Network.solo_bot:
		_solo_won = team_won
		if team_won:
			GameState.record_solo_clear(Network.solo_round)
		var info := Network.solo_round_info()
		if team_won and Network.is_last_solo_round():
			$HUD/EndPanel/Margin/VBox/StatsLabel.text += "\n\nALL %d ROUNDS CLEARED! Kampeon ka!" % Network.SOLO_ROUNDS.size()
			play_again_button.text = "Play from Round 1"
		elif team_won:
			var next: Dictionary = Network.SOLO_ROUNDS[Network.solo_round]
			$HUD/EndPanel/Margin/VBox/StatsLabel.text += "\n\n%s cleared! Next: %s (%d bot%s)" % [
				info["name"], next["name"], next["bots"], "" if next["bots"] == 1 else "s"]
			play_again_button.text = "Next Round"
		else:
			play_again_button.text = "Retry %s" % info["name"].get_slice(" - ", 0)
	if not multiplayer.is_server():
		$HUD/EndPanel/Margin/VBox/StatsLabel.text += "\n\nWaiting for the host to play again..."
	end_panel.visible = true


func _on_play_again() -> void:
	if not multiplayer.is_server():
		return
	if Network.online:
		Network.restart_game()        # every device reloads the maze
	elif Network.solo_bot:
		var next_round := Network.solo_round
		if _solo_won:
			next_round = 1 if Network.is_last_solo_round() else Network.solo_round + 1
		Network.play_solo(true, next_round)
		get_tree().reload_current_scene()
	else:
		get_tree().reload_current_scene()


func _on_leave() -> void:
	Network.leave()
	get_tree().change_scene_to_file(GameState.TITLE_SCENE)


## Clients: the host pressed LEAVE mid-round, so the game is over.
@rpc("authority", "call_remote", "reliable")
func _round_ended_by_host() -> void:
	GameState.round_state = GameState.RoundState.ENDED
	quiz_panel.close()
	answer_popup.close()
	help_alert.close()
	answering_notice.close()
	pause_label.visible = false
	var result: Label = $HUD/EndPanel/Margin/VBox/ResultLabel
	result.text = "GAME OVER — THE HOST LEFT"
	result.modulate = Color(1.0, 0.75, 0.35)
	$HUD/EndPanel/Margin/VBox/StatsLabel.text = "No winner this round.\nCorrect answers: %d / %d" % [correct_answers, questions_to_win]
	play_again_button.visible = false
	menu_button.text = "Main Menu"
	end_panel.visible = true


## Clients: the connection to the host is gone (it may come after the end screen).
func _on_host_left() -> void:
	if not end_panel.visible:
		return   # Network sends us to the title screen
	play_again_button.visible = false
	menu_button.text = "Main Menu"
	var stats: Label = $HUD/EndPanel/Margin/VBox/StatsLabel
	stats.text = stats.text.replace("\n\nWaiting for the host to play again...", "")
	if not stats.text.ends_with("The host left the game."):
		stats.text += "\n\nThe host left the game."


## LEAVE button (top bar). Who may leave during a round:
##   solo / test mode  - any time
##   LAN host          - any time, but it ends the game for everyone (the
##                       host runs the rules), so it asks first
##   LAN player        - only when the round is over (the end screen)
## Leaving always takes two taps, so nobody quits by accident.
func _can_leave_now() -> bool:
	return not Network.online or multiplayer.is_server() \
		or GameState.round_state == GameState.RoundState.ENDED


func _update_leave_button() -> void:
	var button: TextureButton = $HUD/TopBar/LeaveButton
	button.disabled = not _can_leave_now()
	button.tooltip_text = "Leave the game" if _can_leave_now() \
		else "You can leave when the round is over"


func _on_leave_pressed() -> void:
	if not _can_leave_now():
		_show_message("You can leave when the round is over.", 2.0)
		return
	if Time.get_ticks_msec() < _leave_armed_until:
		if Network.online and multiplayer.is_server() and GameState.round_state != GameState.RoundState.ENDED:
			# tell everyone the game is over before closing the connection
			_round_ended_by_host.rpc()
			get_tree().create_timer(0.4).timeout.connect(_on_leave)
			$HUD/TopBar/LeaveButton.disabled = true
		else:
			_on_leave()
		return
	_leave_armed_until = Time.get_ticks_msec() + 3000
	if Network.online and multiplayer.is_server() and GameState.round_state != GameState.RoundState.ENDED:
		_show_message("Tap LEAVE again to quit — this ENDS the game for everyone.", 3.0)
	else:
		_show_message("Tap LEAVE again to quit to the title screen.", 3.0)


func _show_message(text: String, seconds: float) -> void:
	message_label.text = text
	message_time = seconds


func _update_hud() -> void:
	score_label.text = "Questions: %d / %d" % [correct_answers, questions_to_win]
	timer_label.text = "Time: %s" % _format_time(time_left)
	frozen_label.visible = not silis.is_empty() and not tubigs.is_empty()
	frozen_label.text = "Frozen: %d / %d" % [tubigs.size() - _free_tubig_count(), tubigs.size()]


# ================================================================ pause
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _notification(what: int) -> void:
	# the phone went to the home screen / another app: pause the round so
	# the player doesn't get caught while away (host decides, as always)
	if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if is_inside_tree() and multiplayer.is_server() and GameState.round_state == GameState.RoundState.PLAYING:
			_set_paused.rpc(true)


func _toggle_pause() -> void:
	if not multiplayer.is_server():
		_show_message("Only the host can pause.", 1.5)
		return
	# Pause through the round state (get_tree().paused would also freeze
	# this node, so Esc could never resume — bug fixed earlier).
	if GameState.round_state == GameState.RoundState.PLAYING:
		_set_paused.rpc(true)
	elif GameState.round_state == GameState.RoundState.PAUSED:
		_set_paused.rpc(false)


@rpc("authority", "call_local", "reliable")
func _set_paused(paused: bool) -> void:
	GameState.round_state = GameState.RoundState.PAUSED if paused else GameState.RoundState.PLAYING
	pause_label.visible = paused
