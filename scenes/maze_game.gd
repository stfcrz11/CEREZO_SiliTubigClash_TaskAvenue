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
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SCROLL_SCENE := preload("res://scenes/question_scroll.tscn")
const ButtonStyle := preload("res://scenes/ui_button_style.gd")

## Maze layout. # = wall, . = floor, P = Tubig starts (up to 4), S = Sili starts (up to 2).
## Edit this to change the maze (keep it 23 x 15 to fit the screen).
const MAZE := [
	"#######################",
	"#S#.............#....S#",
	"#.###.#.###.###.#.#.#.#",
	"#.....#.......#...#.#.#",
	"###...#####.###..##.#.#",
	"#...#.#...#.......#.#.#",
	"#.#.#.#.#.#.##..#.#.###",
	"#.#.........#.....#...#",
	"#.###..###.##.#######.#",
	"#...........#...#.....#",
	"#.##..###.###.#.#.###.#",
	"#.....#.......#...#...#",
	"##.##.#.#####.##..#.#.#",
	"#PPPP.......#.........#",
	"#######################",
]
const TILE := 40
const ORIGIN := Vector2(20, 40)   # the HUD top bar sits above the maze

@export var questions_to_win: int = 10
@export var round_time: float = 180.0
@export var scrolls_on_map: int = 3
@export var pickup_distance: float = 24.0
@export var tag_distance: float = 24.0        # Sili touching Tubig
@export var warn_distance: float = 170.0     # "SILI NEARBY!"
@export var danger_distance: float = 90.0    # "RUN!"
@export var rescue_distance: float = 26.0
@export var min_frozen_time: float = 1.0
@export var grace_after_question: float = 1.0
@export var feedback_time: float = 2.0

@onready var walls_root: Node2D = $Walls
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
@onready var end_panel: Control = $HUD/EndPanel
@onready var play_again_button: Button = $HUD/EndPanel/Margin/VBox/Buttons/PlayAgainButton
@onready var menu_button: Button = $HUD/EndPanel/Margin/VBox/Buttons/MenuButton

var floor_cells: Array[Vector2i] = []
var tubigs: Array = []
var silis: Array = []
var player_by_id: Dictionary = {}
var scrolls: Dictionary = {}        # scroll id -> node
var correct_answers: int = 0
var questions_asked: int = 0
var time_left: float = 0.0
var message_time: float = 0.0

# host-only bookkeeping
var _begun: bool = false
var _next_scroll_id: int = 0
var _question_deck: Array = []
var _q: Dictionary = {}             # the open question
var _result_timer: float = -1.0


func _ready() -> void:
	randomize()
	if Network.players.is_empty():
		Network.play_solo()   # scene started directly (e.g. from the editor)
	_build_maze()
	GameState.round_state = GameState.RoundState.READY
	quiz_panel.choice_made.connect(_on_local_choice)
	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_leave)
	ButtonStyle.style_primary(play_again_button, Color(0.21, 0.69, 0.9))
	ButtonStyle.style_secondary(menu_button, Color(0.38, 0.38, 0.46))
	end_panel.visible = false
	pause_label.visible = false
	warning_label.text = ""
	warning_glow.modulate.a = 0.0
	minimap.set_maze(MAZE)
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
	var w: int = MAZE[0].length()
	var h: int = MAZE.size()
	for y in h:
		var run_start := -1
		for x in w + 1:
			var is_wall: bool = x < w and MAZE[y][x] == "#"
			if x < w and not is_wall:
				floor_cells.append(Vector2i(x, y))
			# merge each horizontal run of wall tiles into one body
			if is_wall and run_start < 0:
				run_start = x
			elif not is_wall and run_start >= 0:
				_add_wall(run_start, y, x - run_start)
				run_start = -1


func _add_wall(cell_x: int, cell_y: int, length: int) -> void:
	var size := Vector2(length * TILE, TILE)
	var body := StaticBody2D.new()
	body.position = ORIGIN + Vector2(cell_x * TILE, cell_y * TILE) + size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	var look := ColorRect.new()
	look.color = Color(0.36, 0.25, 0.16)
	look.position = -size / 2.0
	look.size = size
	look.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(look)
	body.add_child(shape)
	walls_root.add_child(body)


func world_to_cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(((pos - ORIGIN) / TILE).floor())
	return c.clamp(Vector2i.ZERO, Vector2i(MAZE[0].length() - 1, MAZE.size() - 1))


func cell_to_world(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0


func random_floor_cell() -> Vector2i:
	return floor_cells.pick_random()


func _cells_with(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in MAZE.size():
		for x in MAZE[y].length():
			if MAZE[y][x] == ch:
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
	_spawn_all.rpc(roster)
	for i in scrolls_on_map:
		_host_spawn_scroll()
	_start_round.rpc(round_time)
	round_timer.start()


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
		mode_label.text = "You: %s (P%d)" % ["TUBIG" if me.is_tubig() else "SILI", me.slot + 1]
		minimap.set_local_player(me)


@rpc("authority", "call_local", "reliable")
func _start_round(seconds: float) -> void:
	time_left = seconds
	correct_answers = 0
	GameState.round_state = GameState.RoundState.PLAYING
	_update_hud()
	var me = player_by_id.get(multiplayer.get_unique_id())
	if silis.is_empty():
		_show_message("Test mode: no Sili (needs 2+ players over LAN).", 4.0)
	elif me and not me.is_tubig():
		_show_message("You are SILI! Tag every Tubig before they answer %d questions!" % questions_to_win, 4.0)
	else:
		_show_message("You are TUBIG! Find ? scrolls and answer %d questions!" % questions_to_win, 4.0)


# ============================================================= scrolls
func _host_spawn_scroll() -> void:
	# an open cell away from every Tubig and from the other scrolls
	var taken: Array[Vector2i] = []
	for s in scrolls.values():
		taken.append(world_to_cell(s.position))
	var candidates: Array[Vector2i] = []
	for cell in floor_cells:
		if cell in taken or MAZE[cell.y][cell.x] != ".":
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


func _host_open_question(scroll_id: int, picker_id: int) -> void:
	questions_asked += 1
	var order := [0, 1, 2, 3]
	order.shuffle()
	_q = {"picker": picker_id, "index": _host_next_question_index(), "order": order,
		"answered": false, "deadline": Time.get_ticks_msec() + int((quiz_panel.answer_time + 2.0) * 1000)}
	_open_question.rpc(scroll_id, picker_id, _q["index"], order, questions_asked)


@rpc("authority", "call_local", "reliable")
func _open_question(scroll_id: int, picker_id: int, q_index: int, order: Array, asked: int) -> void:
	if scrolls.has(scroll_id):
		scrolls[scroll_id].queue_free()
		scrolls.erase(scroll_id)
	questions_asked = asked
	GameState.round_state = GameState.RoundState.QUESTION
	var picker_name := "P%d" % (Network.slot_of(picker_id) + 1)
	quiz_panel.show_question(QuestionBank.QUESTIONS[q_index], order,
		"Scroll #%d  —  picked by %s  —  Correct: %d / %d" % [asked, picker_name, correct_answers, questions_to_win],
		picker_id == multiplayer.get_unique_id(), picker_name)


func _on_local_choice(position: int) -> void:
	if multiplayer.is_server():
		_host_receive_answer(1, position)
	else:
		_submit_answer.rpc_id(1, position)


@rpc("any_peer", "call_remote", "reliable")
func _submit_answer(position: int) -> void:
	_host_receive_answer(multiplayer.get_remote_sender_id(), position)


func _host_receive_answer(sender: int, position: int) -> void:
	if _q.is_empty() or _q["answered"] or sender != _q["picker"]:
		return   # only the Tubig who picked the scroll may answer
	_host_resolve(position)


func _host_resolve(position: int) -> void:
	_q["answered"] = true
	var entry: Dictionary = QuestionBank.QUESTIONS[_q["index"]]
	var correct: bool = position >= 0 and _q["order"][position] == entry["answer"]
	var total := correct_answers + (1 if correct else 0)
	_question_result.rpc(position, correct, total)
	_result_timer = feedback_time


@rpc("authority", "call_local", "reliable")
func _question_result(position: int, correct: bool, total: int) -> void:
	correct_answers = total
	quiz_panel.show_result(position, correct)
	_show_message(("Tama! %d / %d" % [total, questions_to_win]) if correct else "Mali! Find another scroll.", 2.5)
	_update_hud()


func _host_after_question() -> void:
	_q = {}
	if correct_answers >= questions_to_win:
		_host_end(true, "TUBIG TEAM WINS!")
		return
	_host_spawn_scroll()
	_resume_after_question.rpc()


@rpc("authority", "call_local", "reliable")
func _resume_after_question() -> void:
	quiz_panel.close()
	for t in tubigs:
		if not t.frozen:
			t.give_grace(grace_after_question)
	GameState.round_state = GameState.RoundState.PLAYING


# ====================================================== catch / rescue
func _host_check_tags() -> void:
	for s in silis:
		for t in tubigs:
			if t.can_be_tagged() and s.global_position.distance_to(t.global_position) <= tag_distance:
				_tubig_caught.rpc(t.peer_id)
	_host_check_team_out()


@rpc("authority", "call_local", "reliable")
func _tubig_caught(id: int) -> void:
	if not player_by_id.has(id):
		return
	var t = player_by_id[id]
	t.set_caught()
	_show_message("P%d was caught! Tubig team, touch them to save them!" % (t.slot + 1), 3.0)


@rpc("authority", "call_local", "reliable")
func _tubig_rescued(id: int) -> void:
	if not player_by_id.has(id):
		return
	var t = player_by_id[id]
	t.set_rescued()
	_show_message("Tubig! P%d is saved!" % (t.slot + 1), 2.0)


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
			if helper != frozen_t and not helper.frozen \
					and helper.global_position.distance_to(frozen_t.global_position) <= rescue_distance:
				_tubig_rescued.rpc(frozen_t.peer_id)
				break


func _host_check_pickups() -> void:
	for id in scrolls:
		for t in tubigs:   # only Tubigs can open scrolls
			if not t.frozen and t.global_position.distance_to(scrolls[id].position) <= pickup_distance:
				_host_open_question(id, t.peer_id)
				return   # one question at a time


func _host_on_peer_left(id: int) -> void:
	if player_by_id.has(id):
		_remove_player.rpc(id)
		if not _q.is_empty() and _q["picker"] == id and not _q["answered"]:
			_host_resolve(-1)
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
		_show_message("P%d left the game." % (p.slot + 1), 2.5)


# ============================================================ per frame
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_host_after_question()
	if GameState.round_state == GameState.RoundState.QUESTION and not _q.is_empty() \
			and not _q["answered"] and Time.get_ticks_msec() > _q["deadline"]:
		_host_resolve(-1)   # picker never answered (e.g. disconnected)
	if GameState.round_state == GameState.RoundState.PLAYING:
		_host_check_tags()
		_host_check_rescues()
		_host_check_pickups()


func _process(delta: float) -> void:
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
		if not t.frozen:
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


func _host_end(team_won: bool, title: String) -> void:
	round_timer.stop()
	var stats := "Correct answers: %d / %d\nScrolls opened: %d\nTime left: %s" % \
		[correct_answers, questions_to_win, questions_asked, _format_time(time_left)]
	_end_round.rpc(team_won, title, stats)


@rpc("authority", "call_local", "reliable")
func _end_round(team_won: bool, title: String, stats: String) -> void:
	GameState.round_state = GameState.RoundState.ENDED
	quiz_panel.close()
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
