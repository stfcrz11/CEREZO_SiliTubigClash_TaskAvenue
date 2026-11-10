extends Node
## A computer Sili for SOLO VS BOT (maze_game.gd adds one per bot).
## Based on the BotBrain of the godot-sili-tubig-clash project, adapted to
## this maze. It "presses keys" for its Sili: it sets bot_move / bot_sprint
## on the Sili character, and player.gd moves it with the normal speed and
## stamina rules, so a bot can't do anything a person couldn't.
##
## Deliberately imperfect, like a person:
##   - it only sees a Tubig within its sight range AND with no building in
##     the way (or very close, where it can "hear" them)
##   - it remembers where it last saw someone for a few seconds
##   - it waits a short human-like moment before tagging (bot_tag_ready)
##   - harder bots lead a running Tubig to cut them off
## Team play (Round 3-4): bots share what they see; bot 0 chases, bot 1
## flanks (heads for where the Tubig is going), bot 2 guards a "?" scroll.
## Medium+ bots also visit Bicol Express peppers for a speed boost.

const TUNING := {
	"easy": {"speed": 0.9, "sight": 210.0, "hear": 60.0, "memory": 2.5, "sprint_range": 110.0,
		"react_min": 0.35, "react_max": 0.65, "lead": 0.0, "repath": 0.5, "pepper": 0.0, "accuracy": 0.5, "team": false, "lurk": 120.0},
	"medium": {"speed": 0.95, "sight": 260.0, "hear": 80.0, "memory": 4.0, "sprint_range": 150.0,
		"react_min": 0.15, "react_max": 0.35, "lead": 0.25, "repath": 0.35, "pepper": 0.35, "accuracy": 0.7, "team": false, "lurk": 100.0},
	"hard": {"speed": 1.0, "sight": 320.0, "hear": 100.0, "memory": 6.0, "sprint_range": 200.0,
		"react_min": 0.06, "react_max": 0.16, "lead": 0.45, "repath": 0.25, "pepper": 0.6, "accuracy": 0.85, "team": true, "lurk": 85.0},
	"labuyo": {"speed": 1.0, "sight": 360.0, "hear": 120.0, "memory": 7.0, "sprint_range": 220.0,
		"react_min": 0.04, "react_max": 0.12, "lead": 0.5, "repath": 0.2, "pepper": 0.7, "accuracy": 0.9, "team": true, "lurk": 75.0},
}
const ROLE_NAMES := ["chaser", "flanker", "guard"]
const ARRIVE := 4.0            # px from a road tile's center = reached it
const STUCK_CHECK := 0.5
const STUCK_MIN_MOVE := 3.0

var game: Node2D       # maze_game.gd
var sili: Node2D       # the bot's player.gd character
var difficulty: String = "medium"
var team_role: String = "chaser"
var tune: Dictionary = TUNING["medium"]
var lurk_distance: float = 100.0   # how far it waits from a Tubig it can't tag yet

var _astar := AStarGrid2D.new()
var _path: Array[Vector2i] = []
var _goal_cell := Vector2i(-1, -1)
var _repath: float = 0.0
var _decide: float = 0.0
var _patrol := Vector2.INF
var _last_seen := Vector2.INF
var _last_seen_age: float = 99.0
var _chase_target: Node2D = null
var _target_prev := {}          # tubig -> last position, to guess their velocity
var _target_vel := {}
var _reach_timer: float = -1.0
var _pepper_id: int = -1        # the pepper station this bot is walking to
var _stuck_timer: float = 0.0
var _stuck_from := Vector2.ZERO
var _unstick_timer: float = 0.0
var _unstick_dir := Vector2.ZERO


func setup(game_node: Node2D, sili_node: Node2D, level: String, team_index: int) -> void:
	game = game_node
	sili = sili_node
	difficulty = level if TUNING.has(level) else "medium"
	tune = TUNING[difficulty]
	lurk_distance = tune["lurk"]
	team_role = ROLE_NAMES[team_index % ROLE_NAMES.size()] if tune["team"] else "chaser"
	sili.sili_speed *= tune["speed"]
	var maze: Array = game.maze
	_astar.region = Rect2i(0, 0, maze[0].length(), maze.size())
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in maze.size():
		for x in maze[y].length():
			if maze[y][x] == "#":
				_astar.set_point_solid(Vector2i(x, y))
	_stuck_from = sili.global_position
	_decide = randf_range(0.0, 1.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(sili):
		return
	sili.bot_move = Vector2.ZERO
	sili.bot_sprint = false
	if GameState.round_state != GameState.RoundState.PLAYING or sili.answering or sili.stun_time > 0.0:
		_path.clear()
		_reach_timer = -1.0
		return
	_repath -= delta
	_decide -= delta
	_track_velocities(delta)
	_update_tag_reaction(delta)
	_think(delta)
	_apply_unstick(delta)


# ---------------------------------------------------------------- tagging
## In reach is in reach, but a person needs a moment to react: the host
## only lets this bot tag once bot_tag_ready is true.
func _update_tag_reaction(delta: float) -> void:
	var reach: float = game.tag_radius_of(sili) + 2.0
	var in_reach := false
	for t in game.tubigs:
		if t.can_be_tagged() and sili.global_position.distance_to(t.global_position) <= reach:
			in_reach = true
			break
	if in_reach:
		if _reach_timer < 0.0:
			_reach_timer = randf_range(tune["react_min"], tune["react_max"])
		_reach_timer -= delta
		sili.bot_tag_ready = _reach_timer <= 0.0
	else:
		_reach_timer = -1.0
		sili.bot_tag_ready = false


# ---------------------------------------------------------------- deciding
func _think(delta: float) -> void:
	var target := _visible_tubig()
	if target:
		_chase_target = target
		_last_seen = target.global_position
		_last_seen_age = 0.0
		_pepper_id = -1
		if tune["team"]:
			game.bot_intel = {"pos": target.global_position, "time": Time.get_ticks_msec()}
		_chase(target)
		return

	_last_seen_age += delta
	# a frozen / answering / protected Tubig can't be tagged: don't stand on
	# top of them (that isn't fair play), wait a few steps away instead
	for t in game.tubigs:
		if t.can_be_tagged():
			continue
		if _last_seen != Vector2.INF and _last_seen.distance_to(t.global_position) < 50.0:
			_last_seen = Vector2.INF
		if sili.global_position.distance_to(t.global_position) < lurk_distance:
			if _patrol == Vector2.INF or _patrol.distance_to(t.global_position) < lurk_distance:
				_patrol = _floor_point_away(t.global_position)
				_decide = randf_range(2.0, 3.0)
			_go_to(_patrol)
			return
	# team bots also use what their teammates saw
	if tune["team"] and not game.bot_intel.is_empty():
		var age: float = (Time.get_ticks_msec() - int(game.bot_intel["time"])) / 1000.0
		if age < _last_seen_age:
			_last_seen = game.bot_intel["pos"]
			_last_seen_age = age
	if _last_seen != Vector2.INF and _last_seen_age < tune["memory"]:
		if sili.global_position.distance_to(_last_seen) > 12.0:
			_go_to(_last_seen)
			sili.bot_sprint = _can_sprint() and sili.stamina > sili.max_stamina * 0.6
			return
		_last_seen = Vector2.INF

	_patrol_step()


func _chase(target: Node2D) -> void:
	var here: Vector2 = sili.global_position
	var vel: Vector2 = _target_vel.get(target, Vector2.ZERO)
	var dist := here.distance_to(target.global_position)
	var aim: Vector2 = target.global_position + vel * tune["lead"]
	if team_role == "flanker" and dist > 90.0:
		# head for where the Tubig is going, to cut them off
		aim = target.global_position + vel * (tune["lead"] * 2.5 + 0.6)
	elif team_role == "guard" and dist > 200.0:
		_guard_scroll(target.global_position)
		return
	_go_to(aim)
	sili.bot_sprint = dist < tune["sprint_range"] and _can_sprint()


## Nobody in sight: wait near a frozen or answering Tubig (they have to move
## sooner or later), visit a pepper, guard a scroll, or sweep the streets.
func _patrol_step() -> void:
	if _pepper_id >= 0:
		if _walk_to_pepper():
			return
	if _decide <= 0.0 or _patrol == Vector2.INF or _reached(_patrol, 14.0):
		_decide = randf_range(4.0, 7.0)
		_patrol = _pick_patrol()
	_go_to(_patrol)


func _pick_patrol() -> Vector2:
	for t in game.tubigs:
		if (t.frozen or t.answering) and randf() < 0.7:
			return _floor_point_away(t.global_position)
	if tune["pepper"] > 0.0 and sili.turbo_time <= 0.0 and randf() < tune["pepper"]:
		var p: int = game.nearest_ready_station(sili, "pepper")
		if p >= 0:
			_pepper_id = p
			return game.station_approach_point(p)
	if team_role == "guard":
		var s := _scroll_near(sili.global_position)
		if s != Vector2.INF:
			return s
	if randf() < 0.5:
		var s2 := _scroll_near(sili.global_position)
		if s2 != Vector2.INF:
			return s2
	return game.cell_to_world(game.random_floor_cell())


func _guard_scroll(near: Vector2) -> void:
	var spot := _scroll_near(near)
	if spot == Vector2.INF:
		spot = near
	if sili.global_position.distance_to(spot) > 40.0:
		_go_to(spot)


func _walk_to_pepper() -> bool:
	if not game.station_ready(_pepper_id, sili):
		_pepper_id = -1
		return false
	var spot: Vector2 = game.station_approach_point(_pepper_id)
	if game.world_to_cell(sili.global_position) == game.world_to_cell(spot) \
			and sili.global_position.distance_to(spot) < 10.0:
		# push into the stall like a player would
		sili.bot_move = (game.station_world_pos(_pepper_id) - sili.global_position).normalized()
		sili.bot_interact = _pepper_id
		_pepper_id = -1
		return true
	_go_to(spot)
	return true


## Host only: did this bot answer the pepper's bugtong correctly?
func answers_correctly() -> bool:
	return randf() < tune["accuracy"]


# ---------------------------------------------------------------- seeing
## Closest Tubig this bot could plausibly see from here.
func _visible_tubig() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in game.tubigs:
		if not t.can_be_tagged():
			continue    # frozen, answering or protected: not worth chasing
		var d: float = sili.global_position.distance_to(t.global_position)
		if d > tune["sight"]:
			continue
		if d > tune["hear"] and not _line_clear(sili.global_position, t.global_position):
			continue
		if t == _chase_target:
			d *= 0.7    # stick with the current target instead of dithering
		if d < best_d:
			best_d = d
			best = t
	return best


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 8.0)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		var c: Vector2i = game.world_to_cell(p)
		if game.maze[c.y][c.x] == "#":
			return false
	return true


func _track_velocities(delta: float) -> void:
	for t in game.tubigs:
		var prev: Vector2 = _target_prev.get(t, t.global_position)
		var v: Vector2 = (t.global_position - prev) / max(delta, 0.001)
		_target_vel[t] = _target_vel.get(t, Vector2.ZERO).lerp(v, 0.2)
		_target_prev[t] = t.global_position


# ---------------------------------------------------------------- moving
func _can_sprint() -> bool:
	return sili.stamina > sili.max_stamina * 0.2


func _reached(spot: Vector2, tolerance: float) -> bool:
	return sili.global_position.distance_to(spot) <= tolerance


func _scroll_near(pos: Vector2) -> Vector2:
	var best := Vector2.INF
	for s in game.scrolls.values():
		if is_instance_valid(s) and (best == Vector2.INF or pos.distance_to(s.position) < pos.distance_to(best)):
			best = s.position
	return best


func _floor_point_near(center: Vector2, radius: float) -> Vector2:
	for i in 12:
		var p := center + Vector2.from_angle(randf() * TAU) * randf_range(radius * 0.6, radius)
		var c: Vector2i = game.world_to_cell(p)
		if game.maze[c.y][c.x] != "#":
			return game.cell_to_world(c)
	return center


## A road cell lurk_distance+ away from `from` (the farther the better).
func _floor_point_away(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := -1.0
	for i in 16:
		var p := from + Vector2.from_angle(randf() * TAU) * randf_range(lurk_distance + 20.0, lurk_distance + 70.0)
		var c: Vector2i = game.world_to_cell(p)
		if game.maze[c.y][c.x] == "#":
			continue
		var d: float = game.cell_to_world(c).distance_to(from)
		if d > best_d:
			best_d = d
			best = game.cell_to_world(c)
	return best if best != Vector2.INF else game.cell_to_world(game.random_floor_cell())


func _go_to(goal: Vector2) -> void:
	var goal_cell: Vector2i = game.nearest_floor_cell(game.world_to_cell(goal))
	if _repath <= 0.0 or goal_cell != _goal_cell:
		_repath = tune["repath"]
		_goal_cell = goal_cell
		_find_path(goal_cell)
	# drop road tiles already reached
	while not _path.is_empty() and sili.global_position.distance_to(game.cell_to_world(_path[0])) <= ARRIVE:
		_path.pop_front()
	var aim: Vector2 = goal if _path.is_empty() else game.cell_to_world(_path[0])
	var to_aim := aim - sili.global_position
	sili.bot_move = to_aim.normalized() if to_aim.length() > 1.0 else Vector2.ZERO


func _find_path(goal_cell: Vector2i) -> void:
	var from: Vector2i = game.world_to_cell(sili.global_position)
	if _astar.is_point_solid(from) or _astar.is_point_solid(goal_cell):
		_path.clear()
		return
	_path.assign(_astar.get_id_path(from, goal_cell))
	if _path.size() >= 2:
		# already on the way to the next tile: don't turn back to this tile's center
		var here: Vector2 = game.cell_to_world(_path[0])
		var next: Vector2 = game.cell_to_world(_path[1])
		if (sili.global_position - here).dot(next - here) > 0.0:
			_path.pop_front()
	if not _path.is_empty() and _path.back() == goal_cell:
		_path.pop_back()   # last stretch: head straight for the goal itself


## A bot that wants to move but hasn't for a while is caught on a corner.
## Sidestep briefly and force a fresh path.
func _apply_unstick(delta: float) -> void:
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		sili.bot_move = _unstick_dir
		return
	if sili.bot_move == Vector2.ZERO:
		_stuck_timer = 0.0
		_stuck_from = sili.global_position
		return
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK:
		return
	if sili.global_position.distance_to(_stuck_from) < STUCK_MIN_MOVE and sili.bot_interact < 0:
		_unstick_dir = sili.bot_move.rotated(PI * 0.5 * (1 if randf() < 0.5 else -1))
		_unstick_timer = 0.25
		_path.clear()
		_repath = 0.0
	_stuck_timer = 0.0
	_stuck_from = sili.global_position
