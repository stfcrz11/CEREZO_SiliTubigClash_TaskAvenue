extends Node2D
## Sili-Tubig: Task Avenue — the maze round (solo or LAN).
## 2-6 players over LAN. Silis (1 for 2-4 players, 2 for 5-6) chase; the
## Tubig team picks up "?" scrolls and must answer 10 Filipino-culture
## questions correctly before time runs out.
## Round states: READY -> PLAYING <-> PAUSED, PLAYING <-> QUESTION, -> ENDED.
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

## The maze is NOT written here any more: open scenes/city_map.tscn and
## paint it on the "Maze" TileMapLayer (tiles come from
## assets/walls/city_tileset.tres). Any tile with a collision shape is a
## wall, every other tile is road. Start spots are the Marker2D nodes under
## "Starts" (TubigStart1-4, SiliStart1-2) — drag them in the editor.
const TILE := 40                  # must match the TileSet's tile size (40 x 40 px)
const CAMERA_MARGIN := 3          # tiles of city the camera may show past the maze edge

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
@export var feedback_time: float = 3.5        # how long the TAMA!/MALI! popup stays
@export var camera_zoom: float = 2.5          # higher = closer; 2.5 shows about 10 x 6 tiles

@onready var maze_layer: TileMapLayer = $Map/Maze
@onready var starts_root: Node2D = $Map/Starts
@onready var camera: Camera2D = $Camera
@onready var scrolls_root: Node2D = $Scrolls
@onready var actors_root: Node2D = $Actors
@onready var round_timer: Timer = $RoundTimer
@onready var score_label: Label = $HUD/TopBar/ScoreLabel
@onready var timer_label: Label = $HUD/TopBar/TimerLabel
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
var correct_answers: int = 0
var questions_asked: int = 0
var time_left: float = 0.0
var message_time: float = 0.0
var local_player: Node2D             # the camera follows only this device's player
var questions: Dictionary = {}       # open questions (every device): qid -> info
var my_question: int = -1            # the question THIS device is answering (-1 = none)
var popup_question: int = -1         # the question the TAMA!/MALI! popup is about
var _help_queue: Array = []          # help requests waiting to be shown to me
var _help_showing: int = -1          # the help request in the alert right now
var help_locked_by: int = 0          # the answerer who is asking for help now (0 = nobody)

# host-only bookkeeping
var _begun: bool = false
var _next_scroll_id: int = 0
var _question_deck: Array = []
var _questions: Dictionary = {}     # open questions (host): qid -> info
var _help_active: int = -1          # host: the ONE question with an open help request
var _stats: Dictionary = {}         # host: peer id -> {correct, tags, rescues} this round
var _next_question_id: int = 0


func _ready() -> void:
	randomize()
	# The HUD is hidden in the editor so it doesn't cover the map while you
	# edit (click the eye next to "HUD" to see it); the game shows it here.
	$HUD.visible = true
	if Network.players.is_empty():
		Network.play_solo()   # scene started directly (e.g. from the editor)
	_build_maze()
	GameState.round_state = GameState.RoundState.READY
	quiz_panel.choice_made.connect(_on_local_choice)
	quiz_panel.help_requested.connect(_on_help_pressed)
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
	_setup_camera()
	_add_vignette()
	mode_label.text = "Host (LAN)" if Network.is_host() else "LAN"
	_update_hud()
	_show_message("Waiting for players...", 30.0)

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
	maze_origin = maze_layer.global_position + Vector2(used.position * TILE)
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


func world_to_cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(((pos - maze_origin) / TILE).floor())
	return c.clamp(Vector2i.ZERO, Vector2i(maze[0].length() - 1, maze.size() - 1))


func cell_to_world(cell: Vector2i) -> Vector2:
	return maze_origin + Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0


func random_floor_cell() -> Vector2i:
	return floor_cells.pick_random()


func _cells_with(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in maze.size():
		for x in maze[y].length():
			if maze[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


# ========================================================= round start
func _on_peer_ready(_id: int) -> void:
	_host_try_begin()


func _host_try_begin() -> void:
	if _begun or not Network.everyone_ready():
		return
	_begun = true
	var roles := Network.assign_roles()   # 2-4 players: 1 Sili, 5-6: 2 Silis
	var roster := []
	for id in Network.sorted_ids():
		roster.append([id, Network.slot_of(id), roles[id]])
		_stats[id] = {"correct": 0, "tags": 0, "rescues": 0}
	_spawn_all.rpc(roster)
	for i in scrolls_on_map:
		_host_spawn_scroll()
	var tubig_count := 0
	for id in roles:
		if roles[id] == "tubig":
			tubig_count += 1
	_start_round.rpc(_round_seconds(tubig_count))
	round_timer.start()


func _round_seconds(tubig_count: int) -> float:
	# 1 Tubig: 3:00. Each extra Tubig can answer at the same time as the
	# others, so the round gets 20 s shorter per extra Tubig (never below 1:30).
	return max(min_round_time, round_time - less_time_per_extra_tubig * max(0, tubig_count - 1))


@rpc("authority", "call_local", "reliable")
func _spawn_all(roster: Array) -> void:
	var tubig_starts := _cells_with("P")
	var sili_starts := _cells_with("S")
	for entry in roster:
		var id: int = entry[0]
		var slot: int = entry[1]
		var role: String = entry[2]
		var p := PLAYER_SCENE.instantiate()
		p.name = "Player_%d" % id          # identical node path on every device
		actors_root.add_child(p)
		if role == "tubig":
			p.setup(id, slot, role, tubigs.size(), cell_to_world(tubig_starts[tubigs.size()]))
			tubigs.append(p)
		else:
			p.setup(id, slot, role, silis.size(), cell_to_world(sili_starts[silis.size()]))
			silis.append(p)
		player_by_id[id] = p
	var me = player_by_id.get(multiplayer.get_unique_id())
	if me:
		mode_label.text = "You: %s (%s)" % ["TUBIG" if me.is_tubig() else "SILI", Network.player_name_of(me.peer_id)]
		minimap.set_local_player(me)
		local_player = me
		_follow_local_player()
		camera.reset_smoothing()   # jump straight to your start spot


@rpc("authority", "call_local", "reliable")
func _start_round(seconds: float) -> void:
	time_left = seconds
	correct_answers = 0
	GameState.round_state = GameState.RoundState.PLAYING
	_update_hud()
	var me = player_by_id.get(multiplayer.get_unique_id())
	var clock := "  (%s for %d Tubig%s)" % [_format_time(seconds), tubigs.size(), "" if tubigs.size() == 1 else "s"]
	if silis.is_empty():
		_show_message("Test mode: no Sili (needs 2+ players over LAN).", 4.0)
	elif me and not me.is_tubig():
		_show_message("You are SILI! Tag every Tubig before they answer %d questions!%s" % [questions_to_win, clock], 5.0)
	else:
		_show_message("You are TUBIG! Find ? scrolls and answer %d questions!%s" % [questions_to_win, clock], 5.0)


# ============================================================= scrolls
func _host_spawn_scroll() -> void:
	# an open cell away from every Tubig and from the other scrolls
	var taken: Array[Vector2i] = []
	for s in scrolls.values():
		taken.append(world_to_cell(s.position))
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


# =========================================================== questions
func _host_next_question_index() -> int:
	if _question_deck.is_empty():
		_question_deck = range(QuestionBank.QUESTIONS.size())
		_question_deck.shuffle()
	return _question_deck.pop_back()


# Several Tubigs can answer at the same time: every open question has its
# own id, answerer, timer and (at most one) helper.
#   host:     _questions[qid] = {picker, asker, index, order, answered,
#             help_asked, passed, full_stop, deadline, result_timer}
#   everyone: questions[qid]  = {picker, asker, index, order, asked, full_stop}
func _host_open_question(scroll_id: int, picker_id: int) -> void:
	questions_asked += 1
	var qid := _next_question_id
	_next_question_id += 1
	var order := [0, 1, 2, 3]
	order.shuffle()
	# Only one Tubig in the game: nobody else can play, so the whole chase
	# stops (the Sili sees "Tubig is answering"). Otherwise only the
	# answerer stops and everyone else keeps playing.
	var full_stop := tubigs.size() <= 1
	var index := _host_next_question_index()
	_questions[qid] = {"picker": picker_id, "asker": picker_id, "index": index, "order": order,
		"answered": false, "help_asked": false, "passed": false, "full_stop": full_stop,
		"deadline": _question_deadline(), "result_timer": -1.0}
	_open_question.rpc(qid, scroll_id, picker_id, index, order, questions_asked, full_stop)


func _question_deadline() -> int:
	# the host's own time limit: the answer time plus a little network slack
	return Time.get_ticks_msec() + int((quiz_panel.answer_time + 2.0) * 1000)


@rpc("authority", "call_local", "reliable")
func _open_question(qid: int, scroll_id: int, picker_id: int, q_index: int, order: Array, asked: int, full_stop: bool) -> void:
	if scrolls.has(scroll_id):
		scrolls[scroll_id].queue_free()
		scrolls.erase(scroll_id)
	questions_asked = asked
	questions[qid] = {"picker": picker_id, "asker": picker_id, "index": q_index, "order": order,
		"asked": asked, "full_stop": full_stop}
	if full_stop:
		GameState.round_state = GameState.RoundState.QUESTION   # everyone stops, clock stops
	var picker = player_by_id.get(picker_id)
	if picker:
		picker.set_answering(true)
	var picker_name := Network.player_name_of(picker_id)
	if picker_id == multiplayer.get_unique_id():
		my_question = qid
		_help_queue.clear()   # busy answering: no help alerts for me now
		_help_showing = -1
		help_alert.close()
		quiz_panel.show_question(QuestionBank.QUESTIONS[q_index], order,
			"Scroll #%d  —  picked by %s  —  Correct: %d / %d" % [asked, picker_name, correct_answers, questions_to_win],
			true, picker_name, not full_stop)
		if help_locked_by != 0:
			quiz_panel.set_help_locked(true, Network.player_name_of(help_locked_by))
		return
	var me = player_by_id.get(multiplayer.get_unique_id())
	if full_stop:
		if me and not me.is_tubig():
			answering_notice.open()
	else:
		_show_message("%s is answering a question — can't be tagged!" % picker_name, 3.0)


func _on_local_choice(position: int) -> void:
	if my_question < 0:
		return
	if multiplayer.is_server():
		_host_receive_answer(1, my_question, position)
	else:
		_submit_answer.rpc_id(1, my_question, position)


@rpc("any_peer", "call_remote", "reliable")
func _submit_answer(qid: int, position: int) -> void:
	_host_receive_answer(multiplayer.get_remote_sender_id(), qid, position)


func _host_receive_answer(sender: int, qid: int, position: int) -> void:
	var q: Dictionary = _questions.get(qid, {})
	if q.is_empty() or q["answered"] or sender != q["picker"]:
		return   # only the Tubig who has this question may answer it
	_host_resolve(qid, position)


func _host_resolve(qid: int, position: int) -> void:
	var q: Dictionary = _questions[qid]
	q["answered"] = true
	if _help_active == qid:
		_host_release_help()   # the question is over, so its help request is too
	var entry: Dictionary = QuestionBank.QUESTIONS[q["index"]]
	var correct: bool = position >= 0 and q["order"][position] == entry["answer"]
	if correct:
		_count(q["picker"], "correct")   # whoever answered (the helper, if it was passed)
	var total := correct_answers + (1 if correct else 0)
	_question_result.rpc(qid, position, correct, total)
	q["result_timer"] = feedback_time


@rpc("authority", "call_local", "reliable")
func _question_result(qid: int, position: int, correct: bool, total: int) -> void:
	correct_answers = total
	var q: Dictionary = questions.get(qid, {})
	if q.is_empty():
		return
	_forget_help_request(qid)
	var entry: Dictionary = QuestionBank.QUESTIONS[q["index"]]
	var picker_name := Network.player_name_of(q["picker"])
	var mine: bool = q["picker"] == multiplayer.get_unique_id()
	if mine:
		quiz_panel.show_result(position, correct)
		quiz_panel.close()
		my_question = -1
	if q["full_stop"]:
		answering_notice.close()
	if mine:
		# the big TAMA! / MALI! popup is only for the player who answered
		popup_question = qid
		answer_popup.open(correct, position < 0, picker_name,
			entry["choices"][entry["answer"]], entry.get("fact", ""), total, questions_to_win)
	else:
		# everyone else (other Tubigs and the Sili) just gets a short line
		var what := "answered correctly" if correct else ("ran out of time" if position < 0 else "answered wrong")
		_show_message("%s %s  (%d / %d)" % [picker_name, what, total, questions_to_win], 3.5)
	_update_hud()


func _host_after_question(qid: int) -> void:
	_questions.erase(qid)
	if GameState.round_state == GameState.RoundState.ENDED:
		return
	if correct_answers >= questions_to_win:
		_host_end(true, "TUBIG TEAM WINS!")
		return
	_host_spawn_scroll()
	_resume_after_question.rpc(qid)


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
		picker.give_grace(grace_after_question)   # a waiting Sili can't tag them at once
	if q["full_stop"]:
		for t in tubigs:
			if not t.frozen:
				t.give_grace(grace_after_question)
		GameState.round_state = GameState.RoundState.PLAYING


# ============================================================ asking for help
# The answerer presses ASK A TEAMMATE FOR HELP (once per question). Every
# free teammate gets a bottom-right alert; the FIRST one who says YES gets
# the question with a fresh timer, and the asker goes back to the chase.
# If several teammates ask at the same time, the alerts wait in a queue.
func _on_help_pressed() -> void:
	if my_question < 0:
		return
	if multiplayer.is_server():
		_host_help_request(1, my_question)
	else:
		_request_help.rpc_id(1, my_question)


@rpc("any_peer", "call_remote", "reliable")
func _request_help(qid: int) -> void:
	_host_help_request(multiplayer.get_remote_sender_id(), qid)


func _host_help_request(sender: int, qid: int) -> void:
	var q: Dictionary = _questions.get(qid, {})
	if q.is_empty() or q["answered"] or q["full_stop"] or q["help_asked"] or sender != q["picker"]:
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
	if my_question >= 0 and asker_id != multiplayer.get_unique_id():
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
			_host_help_offer(1, qid)
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
	q["deadline"] = _question_deadline()   # the helper gets a fresh timer
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
		quiz_panel.show_question(QuestionBank.QUESTIONS[q["index"]], q["order"],
			"Helping %s  —  Scroll #%d  —  Correct: %d / %d" % [asker_name, q["asked"], correct_answers, questions_to_win],
			true, helper_name, false)
	elif asker_id == multiplayer.get_unique_id():
		my_question = -1
		quiz_panel.close()
	_show_message("%s is helping %s with the question!" % [helper_name, asker_name], 3.0)


# ====================================================== catch / rescue
func _host_check_tags() -> void:
	for s in silis:
		for t in tubigs:
			if t.can_be_tagged() and s.global_position.distance_to(t.global_position) <= tag_distance:
				_count(s.peer_id, "tags")
				_tubig_caught.rpc(t.peer_id)
	_host_check_team_out()


@rpc("authority", "call_local", "reliable")
func _tubig_caught(id: int) -> void:
	if not player_by_id.has(id):
		return
	var t = player_by_id[id]
	t.set_caught()
	if t.is_local():
		help_alert.close()
	_show_message("%s was caught! Tubig team, touch them to save them!" % Network.player_name_of(t.peer_id), 3.0)


@rpc("authority", "call_local", "reliable")
func _tubig_rescued(id: int) -> void:
	if not player_by_id.has(id):
		return
	var t = player_by_id[id]
	t.set_rescued()
	_show_message("Tubig! %s is saved!" % Network.player_name_of(t.peer_id), 2.0)


func _host_check_team_out() -> void:
	if GameState.round_state != GameState.RoundState.PLAYING or silis.is_empty():
		return
	for t in tubigs:
		if not t.frozen:
			return
	_host_end(false, "SILI WINS!")


func _host_check_rescues() -> void:
	for frozen_t in tubigs:
		if not frozen_t.can_be_rescued(min_frozen_time):
			continue
		for helper in tubigs:
			if helper != frozen_t and not helper.frozen and not helper.answering \
					and helper.global_position.distance_to(frozen_t.global_position) <= rescue_distance:
				_count(helper.peer_id, "rescues")
				_tubig_rescued.rpc(frozen_t.peer_id)
				break


func _host_check_pickups() -> void:
	# any free Tubig can open a scroll, even while teammates are answering
	for id in scrolls:
		for t in tubigs:   # only Tubigs can open scrolls
			if not t.frozen and not t.answering \
					and t.global_position.distance_to(scrolls[id].position) <= pickup_distance:
				_host_open_question(id, t.peer_id)
				return   # the scroll list just changed; the next frame checks the rest


func _host_on_peer_left(id: int) -> void:
	if player_by_id.has(id):
		_remove_player.rpc(id)
		for qid in _questions.keys():
			if _questions[qid]["picker"] == id and not _questions[qid]["answered"]:
				_host_resolve(qid, -1)
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


# ============================================================ per frame
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
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
		elif Time.get_ticks_msec() > q["deadline"]:
			_host_resolve(qid, -1)   # answerer never answered (e.g. disconnected)
	if GameState.round_state == GameState.RoundState.PLAYING:
		_host_check_tags()
		_host_check_rescues()
		_host_check_pickups()


func _process(delta: float) -> void:
	_follow_local_player()
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
	# leaderboard results for everyone still in the game (not for solo test rounds)
	var results := []
	if not silis.is_empty():
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
	if not results.is_empty():
		Leaderboard.record(results)   # saved on this device; shown on the title screen
		for r in results:
			if r["id"] == multiplayer.get_unique_id():
				$HUD/EndPanel/Margin/VBox/StatsLabel.text += "\n\nYou earned +%d points (see TOP PLAYERS)" % Leaderboard.points_for(r)
	play_again_button.visible = multiplayer.is_server()
	play_again_button.text = "Play Again (next Sili)" if Network.online else "Play Again"
	menu_button.text = "Main Menu" if not Network.online else "Leave"
	if not multiplayer.is_server():
		$HUD/EndPanel/Margin/VBox/StatsLabel.text += "\n\nWaiting for the host to play again..."
	end_panel.visible = true


func _on_play_again() -> void:
	if not multiplayer.is_server():
		return
	if Network.online:
		Network.restart_game()        # every device reloads the maze
	else:
		get_tree().reload_current_scene()


func _on_leave() -> void:
	Network.leave()
	get_tree().change_scene_to_file(GameState.TITLE_SCENE)


func _show_message(text: String, seconds: float) -> void:
	message_label.text = text
	message_time = seconds


func _update_hud() -> void:
	score_label.text = "Questions: %d / %d" % [correct_answers, questions_to_win]
	timer_label.text = "Time: %s" % _format_time(time_left)


# ================================================================ pause
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
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
