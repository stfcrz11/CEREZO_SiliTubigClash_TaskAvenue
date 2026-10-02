extends Node
## The computer Sili for SOLO VS BOT (maze_game.gd adds it to the round).
## It "presses keys" for its Sili: it sets bot_move / bot_sprint on the Sili
## character, and player.gd moves it with the normal speed and stamina
## rules. Paths follow the maze roads (AStarGrid2D on maze_game's grid).
##   - Tubig within sight_distance -> chase it (sprint when close)
##   - lost sight -> run to where the Tubig was last seen
##   - nothing to chase -> walk to a "?" scroll and wait for the Tubig there
## Change the numbers below (or in the Inspector while the game runs) to
## make the bot easier or harder.

@export var speed_scale: float = 0.95        # x the normal Sili speed (150 px/s); a Tubig walks 140
@export var sight_distance: float = 260.0    # px the bot "sees" the Tubig through the streets
@export var sprint_distance: float = 130.0   # starts sprinting when this close
@export var repath_time: float = 0.3         # seconds between new paths
@export var arrive_distance: float = 4.0     # px from a road tile's center = reached it

var game: Node2D       # maze_game.gd
var sili: Node2D       # the bot's player.gd character
var _astar := AStarGrid2D.new()
var _path: Array[Vector2i] = []
var _goal_cell := Vector2i(-1, -1)
var _repath: float = 0.0
var _last_seen := Vector2.ZERO
var _has_last_seen: bool = false
var _patrol := Vector2.ZERO
var _has_patrol: bool = false


func setup(game_node: Node2D, sili_node: Node2D) -> void:
	game = game_node
	sili = sili_node
	sili.sili_speed *= speed_scale
	var maze: Array = game.maze
	_astar.region = Rect2i(0, 0, maze[0].length(), maze.size())
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in maze.size():
		for x in maze[y].length():
			if maze[y][x] == "#":
				_astar.set_point_solid(Vector2i(x, y))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(sili):
		return
	if GameState.round_state != GameState.RoundState.PLAYING:
		sili.bot_move = Vector2.ZERO
		sili.bot_sprint = false
		return
	var target := _visible_tubig()
	var goal: Vector2
	if target:
		_last_seen = target.global_position
		_has_last_seen = true
		goal = target.global_position
	elif _has_last_seen:
		goal = _last_seen
		if _reached(goal):
			_has_last_seen = false   # nobody here: go patrol
	else:
		if not _has_patrol or _reached(_patrol):
			_pick_patrol()
		goal = _patrol
	_steer(goal, delta)
	sili.bot_sprint = target != null and sili.global_position.distance_to(goal) <= sprint_distance


func _reached(spot: Vector2) -> bool:
	return game.world_to_cell(sili.global_position) == game.world_to_cell(spot)


## The nearest Tubig the bot can tag, if it is close enough to "see".
func _visible_tubig() -> Node2D:
	var best: Node2D = null
	var best_d := sight_distance
	for t in game.tubigs:
		if t.frozen or t.answering:
			continue
		var d: float = sili.global_position.distance_to(t.global_position)
		if d <= best_d:
			best = t
			best_d = d
	return best


func _pick_patrol() -> void:
	# a scroll is where the Tubig has to go sooner or later
	var spots: Array = []
	for s in game.scrolls.values():
		if is_instance_valid(s):
			spots.append(s.position)
	_patrol = spots.pick_random() if not spots.is_empty() else game.cell_to_world(game.random_floor_cell())
	_has_patrol = true


func _steer(goal: Vector2, delta: float) -> void:
	var goal_cell: Vector2i = game.world_to_cell(goal)
	_repath -= delta
	if _repath <= 0.0 or goal_cell != _goal_cell:
		_repath = repath_time
		_goal_cell = goal_cell
		_find_path(goal_cell)
	# drop road tiles already reached
	while not _path.is_empty() and sili.global_position.distance_to(game.cell_to_world(_path[0])) <= arrive_distance:
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
