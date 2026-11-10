extends RefCounted
## Leaderboard saved on this device (user://leaderboard.cfg). Every device
## records every LAN round it plays, for all players in that round, so
## each device ranks everyone it has played with. Players are matched by
## name (same name = same player).
##
## Points per round:  team wins = 3, correct answer = 1, tag = 1, rescue = 1
## (edit the numbers below to change the scoring).

const PATH := "user://leaderboard.cfg"
const META := "_check"     # section holding the file's checksum

## Set when the saved file was damaged or edited and had to be reset.
static var last_problem: String = ""
const WIN_POINTS := 3
const CORRECT_POINTS := 1
const TAG_POINTS := 1
const RESCUE_POINTS := 1


static func points_for(result: Dictionary) -> int:
	return (WIN_POINTS if result["won"] else 0) + result["correct"] * CORRECT_POINTS \
		+ result["tags"] * TAG_POINTS + result["rescues"] * RESCUE_POINTS


## results: one Dictionary per player: {name, won, correct, tags, rescues}
static func record(results: Array) -> void:
	var cfg := _load()
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
	cfg.set_value(META, "sum", _checksum(cfg))
	if cfg.save(PATH) != OK:
		last_problem = "Could not save the leaderboard on this device."


## The saved file, checked. A file that can't be read, or whose numbers were
## changed outside the game (checksum mismatch), is moved to
## leaderboard.cfg.bad and the leaderboard starts fresh. This is a tamper
## check, not encryption: nothing secret is stored here.
static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(PATH):
		return cfg
	var ok := cfg.load(PATH) == OK
	if ok and cfg.has_section(META) and cfg.get_value(META, "sum", "") != _checksum(cfg):
		ok = false
	if ok:
		return cfg
	last_problem = "The leaderboard file was damaged or edited, so it was reset."
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bad"))
	return ConfigFile.new()


static func _checksum(cfg: ConfigFile) -> String:
	var text := ""
	var sections := cfg.get_sections()
	sections.sort()
	for sec in sections:
		if sec == META:
			continue
		for key in ["name", "games", "wins", "correct", "tags", "rescues", "points"]:
			text += "%s|%s|%s;" % [sec, key, str(cfg.get_value(sec, key, ""))]
	return text.sha256_text()


## All players, best first (points, then wins, then fewer games).
static func rankings() -> Array:
	var cfg := _load()
	var out := []
	for key in cfg.get_sections():
		if key == META:
			continue
		out.append({"name": cfg.get_value(key, "name", key), "games": cfg.get_value(key, "games", 0),
			"wins": cfg.get_value(key, "wins", 0), "points": cfg.get_value(key, "points", 0)})
	out.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["wins"] != b["wins"]:
			return a["wins"] > b["wins"]
		return a["games"] < b["games"])
	return out
