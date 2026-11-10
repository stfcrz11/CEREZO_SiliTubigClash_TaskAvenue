extends SceneTree
# Player-data tests: name rules, leaderboard tamper check, reset. Backs up
# and restores the real save files so the user's data is untouched.
const LB := "user://leaderboard.cfg"
const ST := "user://player_settings.cfg"
func _initialize() -> void:
	_go.call_deferred()
func _backup(p: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else PackedByteArray()
func _restore(p: String, data: PackedByteArray) -> void:
	if data.is_empty():
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	else:
		var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(data); f.close()
func _check(id: String, what: String, got, want) -> void:
	print("%s  %s  %s   (got %s, want %s)" % [id, "PASS" if str(got) == str(want) else "FAIL", what, got, want])
func _go() -> void:
	var lb_bak := _backup(LB)
	var st_bak := _backup(ST)
	var bad_bak := _backup(LB + ".bad")
	var GS = root.get_node("GameState")
	var L = load("res://data/leaderboard.gd")
	_check("DT-01", "valid name accepted", GS.name_problem("Stef Cerezo"), "")
	_check("DT-02", "empty name rejected", GS.name_problem("   ") != "", true)
	_check("DT-03", "17-letter name rejected", GS.name_problem("ABCDEFGHIJKLMNOPQ") != "", true)
	_check("DT-04", "symbols rejected", GS.name_problem("Ana|<b>") != "", true)
	_check("DT-05", "LAN name cleaned", GS.clean_name("  Ben|x[b]  "), "Benxb")
	_check("DT-06", "LAN empty name -> Player", GS.clean_name("|||"), "Player")
	# leaderboard save + checksum
	if FileAccess.file_exists(LB): DirAccess.remove_absolute(ProjectSettings.globalize_path(LB))
	L.record([{"name": "Ana", "won": true, "correct": 2, "tags": 0, "rescues": 1}])
	var r: Array = L.rankings()
	_check("DT-07", "round saved and ranked (Ana points)", r[0]["points"] if r.size() > 0 else -1, 6)
	# edit the file by hand: points 6 -> 999
	var txt := FileAccess.get_file_as_string(LB).replace("points=6", "points=999")
	var f := FileAccess.open(LB, FileAccess.WRITE); f.store_string(txt); f.close()
	L.last_problem = ""
	r = L.rankings()
	_check("DT-08", "edited file detected and reset", [r.size(), L.last_problem != "", FileAccess.file_exists(LB + ".bad")], [0, true, true])
	# corrupt file
	f = FileAccess.open(LB, FileAccess.WRITE); f.store_string("[[[ not a config"); f.close()
	L.last_problem = ""
	r = L.rankings()
	_check("DT-09", "unreadable file -> empty board, no crash", [r.size(), L.last_problem != ""], [0, true])
	# reset my data
	GS.set_player_name("Tester")
	GS.record_solo_clear(3)
	L.record([{"name": "Ana", "won": true, "correct": 0, "tags": 0, "rescues": 0}])
	GS.reset_all_data()
	_check("DT-10", "reset clears name, progress, leaderboard", [GS.player_name, GS.best_solo_round, L.rankings().size()], ["Player", 0, 0])
	_restore(LB, lb_bak)
	_restore(ST, st_bak)
	_restore(LB + ".bad", bad_bak)
	print("restored user files")
	quit()
