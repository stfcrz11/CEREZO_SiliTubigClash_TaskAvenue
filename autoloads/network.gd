extends Node
## LAN networking (Godot ENet). The host is the server and also plays as
## P1. Clients join by picking a discovered host or typing its IP.
## The host is authoritative for Silis, scrolls, questions, timer and
## catches; every device moves only its own Tubig.

signal players_changed
signal connected_to_host
signal connection_failed(reason: String)
signal hosts_found_changed

const GAME_PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 6
const MIN_PLAYERS := 2
const BEACON := "SILITUBIG_TASKAVENUE"

var players: Dictionary = {}        # peer_id -> slot (0..5)
var player_names: Dictionary = {}   # peer_id -> chosen display name
var online: bool = false
var game_started: bool = false
var last_error: String = ""
var found_hosts: Dictionary = {}    # host id -> {"ip", "ips", "players", "name", "seen"}
var host_id: int = 0                # random id of the game this device hosts
var ready_peers: Dictionary = {}    # host: peers whose maze scene has loaded
var round_number: int = 0           # host: used to rotate the Sili role

signal peer_ready(id: int)

var _beacon_udp: PacketPeerUDP
var _listen_udp: PacketPeerUDP
var _beacon_timer: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ------------------------------------------------------------ modes
func play_solo() -> void:
	leave()
	players = {1: 0}
	player_names = {1: GameState.player_name}
	online = false


func host_game() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "Could not host (port %d busy?)" % GAME_PORT
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: 0}
	player_names = {1: GameState.player_name}
	online = true
	host_id = randi()
	round_number = randi() % MAX_PLAYERS   # random first Sili
	_start_beacon()
	players_changed.emit()
	return OK


func join_game(ip: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), GAME_PORT)
	if err != OK:
		last_error = "Invalid address."
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	return OK


func leave() -> void:
	_stop_beacon()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	player_names.clear()
	online = false
	game_started = false


func is_connected_ok() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func slot_of(peer_id: int) -> int:
	return players.get(peer_id, 0)


func player_name_of(peer_id: int) -> String:
	return player_names.get(peer_id, "Player")


## 2-4 players: 1 Sili.  5-6 players: 2 Silis.  Everyone else is Tubig.
static func sili_count_for(player_count: int) -> int:
	return 2 if player_count >= 5 else 1


## Host only. Picks who is Sili this round; the role moves down the
## player list every round so everyone gets a turn.
func assign_roles() -> Dictionary:
	var ids := sorted_ids()
	var roles := {}
	for id in ids:
		roles[id] = "tubig"
	if ids.size() >= MIN_PLAYERS:
		var n := sili_count_for(ids.size())
		for i in n:
			roles[ids[(round_number * n + i) % ids.size()]] = "sili"
	round_number += 1
	return roles


func sorted_ids() -> Array:
	var ids := players.keys()
	ids.sort_custom(func(a, b): return players[a] < players[b])
	return ids


func local_ips() -> Array:
	# real Wi-Fi / LAN / hotspot addresses first; virtual adapters (VirtualBox
	# 192.168.56.x, Hyper-V / WSL / Docker 172.16-31.x) last
	var real := []
	var virtual := []
	for ip in IP.get_local_addresses():
		if ip.count(".") != 3 or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		var parts: PackedStringArray = ip.split(".")
		var is_virtual := ip.begins_with("192.168.56.") 			or (parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31)
		if is_virtual:
			virtual.append(ip)
		else:
			real.append(ip)
	return real + virtual


# ------------------------------------------------------ connections
func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	if game_started or players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)   # full / already playing
		return
	var used := players.values()
	for s in MAX_PLAYERS:
		if not s in used:
			players[id] = s
			player_names[id] = "Player"
			break
	_sync_players.rpc(players)
	_sync_player_names.rpc(player_names)
	players_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	players.erase(id)
	player_names.erase(id)
	_sync_players.rpc(players)
	_sync_player_names.rpc(player_names)
	players_changed.emit()


func _on_connected_to_server() -> void:
	_register_player_name.rpc_id(1, GameState.player_name)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	last_error = "Could not connect. Check the IP and that you are on the same Wi-Fi/hotspot."
	leave()
	connection_failed.emit(last_error)


func _on_server_disconnected() -> void:
	# never got the player list = the host turned us away
	last_error = "Could not join: the game is full or already started." if players.is_empty() \
		else "The host left the game."
	leave()
	get_tree().change_scene_to_file(GameState.TITLE_SCENE)


@rpc("authority", "call_remote", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	players = new_players
	players_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _register_player_name(value: String) -> void:
	if not is_host():
		return
	var name := value.strip_edges()
	player_names[multiplayer.get_remote_sender_id()] = name if not name.is_empty() else "Player"
	_sync_player_names.rpc(player_names)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync_player_names(new_names: Dictionary) -> void:
	player_names = new_names
	players_changed.emit()


# ------------------------------------------------------- start game
func start_game() -> void:
	if is_host():
		game_started = true
		_stop_beacon()
		ready_peers.clear()
		_start_game.rpc()


func restart_game() -> void:
	if is_host():
		ready_peers.clear()
		_start_game.rpc()


## Every device calls this once its maze scene has loaded. The host waits
## for everyone before spawning, so no RPC reaches a scene that isn't ready.
func report_ready() -> void:
	if is_host():
		_mark_ready(1)
	else:
		_client_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
	_mark_ready(multiplayer.get_remote_sender_id())


func _mark_ready(id: int) -> void:
	ready_peers[id] = true
	peer_ready.emit(id)


func everyone_ready() -> bool:
	for id in players:
		if not ready_peers.has(id):
			return false
	return true


@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	game_started = true
	get_tree().change_scene_to_file(GameState.GAME_SCENE)


# ------------------------------------------------ LAN discovery
# The JOINER asks and the HOST answers:
#   joiner: every second broadcasts "SILITUBIG_FIND" from its own random port
#   host:   listens on DISCOVERY_PORT and answers each FIND directly with
#           "SILITUBIG_TASKAVENUE|<host id>|<players>|<host name>"
# Why this way round:
#   - any number of joiners work, even several on one PC (each has its own port)
#   - the joiner's firewall lets the answer in (it is a reply to its question)
#   - a host with two network adapters (e.g. Wi-Fi + VirtualBox) answers
#     from both, but has ONE id, so it is listed once, with the IP that is
#     on the same network as the joiner
const FIND := "SILITUBIG_FIND"


func _start_beacon() -> void:
	# host: start answering FIND messages
	_stop_beacon()
	_beacon_udp = PacketPeerUDP.new()
	if _beacon_udp.bind(DISCOVERY_PORT) != OK:
		# another game on this PC is already answering; players can still type the IP
		_beacon_udp = null


func _stop_beacon() -> void:
	if _beacon_udp:
		_beacon_udp.close()
	_beacon_udp = null


func start_listening() -> void:
	# joiner: start asking "who is hosting?"
	stop_listening()
	found_hosts.clear()
	_listen_udp = PacketPeerUDP.new()
	_listen_udp.set_broadcast_enabled(true)
	if _listen_udp.bind(0) != OK:   # 0 = any free port
		_listen_udp = null
	_beacon_timer = 0.0


func stop_listening() -> void:
	if _listen_udp:
		_listen_udp.close()
	_listen_udp = null


func _process(delta: float) -> void:
	if _beacon_udp:
		_answer_finds()
	if _listen_udp:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = 1.0
			_send_find()
		_read_answers()


func _answer_finds() -> void:
	while _beacon_udp.get_available_packet_count() > 0:
		var text := _beacon_udp.get_packet().get_string_from_utf8()
		if text != FIND or game_started:
			continue
		var host_name := player_name_of(1).replace("|", "/")
		var reply := ("%s|%d|%d|%s" % [BEACON, host_id, players.size(), host_name]).to_utf8_buffer()
		_beacon_udp.set_dest_address(_beacon_udp.get_packet_ip(), _beacon_udp.get_packet_port())
		_beacon_udp.put_packet(reply)


func _send_find() -> void:
	# global broadcast + each network's x.y.z.255 (covers phone and Windows
	# hotspots, and PCs with more than one network adapter)
	var targets := ["255.255.255.255"]
	for ip in local_ips():
		var parts: PackedStringArray = ip.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	var msg := FIND.to_utf8_buffer()
	for t in targets:
		_listen_udp.set_dest_address(t, DISCOVERY_PORT)
		_listen_udp.put_packet(msg)


func _read_answers() -> void:
	var changed := false
	var now := Time.get_ticks_msec()
	while _listen_udp.get_available_packet_count() > 0:
		var text := _listen_udp.get_packet().get_string_from_utf8()
		var ip := _listen_udp.get_packet_ip()
		var parts := text.split("|")
		if parts.size() < 4 or parts[0] != BEACON:
			continue
		var id := parts[1]
		var info: Dictionary = found_hosts.get(id, {"ips": {}})
		info["ips"][ip] = now
		var best := _best_ip(info["ips"].keys())
		changed = changed or not found_hosts.has(id) or info.get("players", -1) != int(parts[2]) 			or info.get("ip", "") != best
		info["ip"] = best
		info["players"] = int(parts[2])
		info["name"] = parts[3]
		info["seen"] = now
		found_hosts[id] = info
	for id in found_hosts.keys():
		if now - found_hosts[id]["seen"] > 4000:
			found_hosts.erase(id)
			changed = true
	if changed:
		hosts_found_changed.emit()


func _best_ip(ips: Array) -> String:
	# prefer the host IP that is on the same network (same x.y.z) as this device
	for mine in local_ips():
		var prefix: String = mine.substr(0, mine.rfind(".") + 1)
		for ip in ips:
			if ip.begins_with(prefix):
				return ip
	return ips[0]
