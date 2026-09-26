extends RefCounted
## Leaderboard saved on this device (user://leaderboard.cfg). Every device
## records every LAN round it plays, for all players in that round, so
## each device ranks everyone it has played with. Players are matched by
## name (same name = same player).
##
## Points per round:  team wins = 3, correct answer = 1, tag = 1, rescue = 1
## (edit the numbers below to change the scoring).

const PATH := "user://leaderboard.cfg"
const WIN_POINTS := 3
const CORRECT_POINTS := 1
const TAG_POINTS := 1
const RESCUE_POINTS := 1


static func points_for(result: Dictionary) -> int:
	return (WIN_POINTS if result["won"] else 0) + result["correct"] * CORRECT_POINTS \
		+ result["tags"] * TAG_POINTS + result["rescues"] * RESCUE_POINTS


## results: one Dictionary per player: {name, won, correct, tags, rescues}
static func record(results: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # a missing file just means an empty leaderboard
	for r in results:
		var key: String = r["name"].strip_edges().to_lower()
		if key.is_empty():
			continue
		cfg.set_value(key, "name", r["name"])
		cfg.set_value(key, "games", cfg.get_value(key, "games", 0) + 1)
		cfg.set_value(key, "wins", cfg.get_value(key, "wins", 0) + (1 if r["won"] else 0))
		cfg.set_value(key, "correct", cfg.get_value(key, "correct", 0) + r["correct"])
		cfg.set_value(key, "tags", cfg.get_value(key, "tags", 0) + r["tags"])
		cfg.set_value(key, "rescues", cfg.get_value(key, "rescues", 0) + r["rescues"])
		cfg.set_value(key, "points", cfg.get_value(key, "points", 0) + points_for(r))
	cfg.save(PATH)


## All players, best first (points, then wins, then fewer games).
static func rankings() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return []
	var out := []
	for key in cfg.get_sections():
		out.append({"name": cfg.get_value(key, "name", key), "games": cfg.get_value(key, "games", 0),
			"wins": cfg.get_value(key, "wins", 0), "points": cfg.get_value(key, "points", 0)})
	out.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["wins"] != b["wins"]:
			return a["wins"] > b["wins"]
		return a["games"] < b["games"])
	return out
