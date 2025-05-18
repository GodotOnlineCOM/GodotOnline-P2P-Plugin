extends Node

# Message types
enum Message {
	JOIN, ID, PEER_CONNECT, PEER_DISCONNECT, OFFER, ANSWER, CANDIDATE, 
	SEAL, PEERS, LOBBY_LIST, CONNECT, PING, ERROR, KICK
}

# Configuration constants
const TIMEOUT: int = 60000  # Unresponsive clients timeout after 60 seconds
const SEAL_TIME: int = 10000  # Sealed room timeout
const INV_CODE_LENGTH: int = 5
const DEFAULT_PORT: int = 9080
const LOBBY_CHECK_INTERVAL: float = 10.0
const IP_CHECK_INTERVAL: float = 10.0   # Seconds
const MAX_IP_LIFETIME: float = 30.0
const MAX_LOBBY_COUNT: int = 1000  # Maximum concurrent lobbies
const MAX_PEER_COUNT: int = 5000   # Maximum concurrent peers
const MAX_LOBBY_PER_IP: int = 2
const MAX_CONNECTION_PER_IP: int = 80
const MAX_PACKET_SIZE = 1024 # Maximum packet size server can accept

# Server state
var SERVER_START_TIME: String
var rand: RandomNumberGenerator = RandomNumberGenerator.new()
var lobbies: Dictionary = {}
var public_lobbies: Dictionary = {}
var tcp_server := TCPServer.new()
var peers: Dictionary = {}  # peer_id: Peer
var peers_IP: Dictionary = {}  # peer_id: IP
var overall_IP: Dictionary = {} # example {"IP":{"lobby_count":0, "connection_count":0, "last_activity": Timestamp}
var timer: Timer
var ip_timer: Timer
var is_shutting_down: bool = false

class Peer extends RefCounted:
	var id = -1
	var lobby = ""
	var apikey = ""
	var time = Time.get_ticks_msec()
	var ws = WebSocketPeer.new()
	var connection_time: String

	func _init(peer_id: int, tcp: StreamPeer):
		id = peer_id
		connection_time = TimeHelper.get_iso_timestamp()
		var err = ws.accept_stream(tcp)
		if err != OK:
			LoggingHelper.error("Failed to accept WebSocket connection", {
				"peer_id": peer_id,
				"error": error_string(err)
			})

	func is_ws_open() -> bool:
		return ws.get_ready_state() == WebSocketPeer.STATE_OPEN

	func send(type: int, id: int, data = "") -> bool:
		if not is_ws_open():
			return false
			
		var message = {
			"type": type,
			"id": id,
			"data": data
		}
		
		var json = JSON.stringify(message)
		if json.is_empty():
			LoggingHelper.error("Failed to stringify message", {
				"peer_id": id,
				"message": message
			})
			return false
			
		var err = ws.send_text(json)
		if err != OK:
			LoggingHelper.error("Failed to send message to peer", {
				"peer_id": id,
				"error": error_string(err),
				"message_type": Message.keys()[type] if type < Message.size() else "UNKNOWN"
			})
			return false
			
		return true

class Lobby extends RefCounted:
	var peers: Dictionary = {}  # peer_id: Peer
	var host: int = -1
	var ip: String = ""
	var sealed: bool = false
	var time: int = 0
	var mesh: bool = true
	var created_time: String

	func _init(host_id: int, use_mesh: bool,host_ip: String):
		host = host_id
		mesh = use_mesh
		ip = host_ip
		created_time = TimeHelper.get_iso_timestamp()

	func join(peer: Peer) -> bool:
		if sealed: 
			return false
		if not peer.is_ws_open(): 
			return false
			
		# Send ID message to new peer
		var success = peer.send(
			Message.ID, 
			(1 if peer.id == host else peer.id), 
			"true" if mesh else ""
		)
		if not success:
			return false

		# Notify other peers about new connection
		for p in peers.values():
			if not p.is_ws_open():
				continue
			if not mesh and p.id != host:
				continue  # Only host is visible in client-server mode
				
			p.send(Message.PEER_CONNECT, peer.id)
			peer.send(Message.PEER_CONNECT, (1 if p.id == host else p.id))

		peers[peer.id] = peer
		return true

	func leave(peer: Peer) -> bool:
		if not peers.has(peer.id): 
			return false
			
		peers.erase(peer.id)
		var should_close = false
		
		if peer.id == host:
			should_close = true  # Host disconnected, close lobby
			
		if sealed: 
			return should_close
			
		# Notify other peers about disconnection
		for p in peers.values():
			if not p.is_ws_open():
				continue
				
			if should_close:
				p.ws.close()
			else:
				p.send(Message.PEER_DISCONNECT, peer.id)
				
		return should_close

	func seal(peer_id: int) -> bool:
		if host != peer_id: 
			return false  # Only host can seal the room
			
		sealed = true
		for p in peers.values():
			if p.is_ws_open():
				p.send(Message.SEAL, 0)
				
		time = Time.get_ticks_msec()
		peers.clear()
		return true

func _ready() -> void:
	if GoSettings.SERVER_MODE:
		# Initialize random number generator
		rand.seed = Time.get_unix_time_from_system()
		SERVER_START_TIME = TimeHelper.get_iso_timestamp()

		
		# Set up lobby cleanup timer
		timer = Timer.new();timer.timeout.connect(_lobby_cleanup_check)
		timer.wait_time = LOBBY_CHECK_INTERVAL
		add_child(timer);timer.start()
		# Set up ip cleanup timer
		ip_timer = Timer.new();ip_timer.timeout.connect(_ip_table_timeout)
		ip_timer.wait_time = IP_CHECK_INTERVAL
		add_child(ip_timer);ip_timer.start()
		
		# Start server
		if not listen(DEFAULT_PORT):
			LoggingHelper.critical("Failed to start server", {
				"port": DEFAULT_PORT,
				"error": error_string(ERR_BUG)
			})
			await get_tree().create_timer(0.1).timeout # Don't touch for now.
			#get_tree().quit()
		
		LoggingHelper.info("Server started successfully", {
			"start_time": SERVER_START_TIME,
			"port": DEFAULT_PORT,
			"max_lobbies": MAX_LOBBY_COUNT,
			"max_peers": MAX_PEER_COUNT
		})

func _exit_tree() -> void:
	if GoSettings.SERVER_MODE:
		is_shutting_down = true
		graceful_shutdown()

func graceful_shutdown() -> void:
	LoggingHelper.info("Initiating graceful shutdown", {
		"active_lobbies": lobbies.size(),
		"active_peers": peers.size()
	})
	
	# Disconnect all peers
	for peer in peers.values():
		if peer.is_ws_open():
			peer.ws.close()
	
	# Clear all lobbies
	lobbies.clear()
	public_lobbies.clear()
	peers.clear()
	peers_IP.clear()
	overall_IP.clear()
	# Stop the server
	if tcp_server.is_listening():
		tcp_server.stop()
	
	LoggingHelper.info("Server shutdown completed", {
		"uptime": TimeHelper.calculate_uptime(SERVER_START_TIME)
	})

func listen(port: int) -> bool:
	if tcp_server.is_listening():
		tcp_server.stop()
	
	var err = tcp_server.listen(port)
	if err != OK:
		LoggingHelper.error("Failed to listen on port", {
			"port": port,
			"error": error_string(err)
		})
		return false
	
	LoggingHelper.info("Server listening on port", {"port": port})
	return true

func stop() -> void:
	if tcp_server.is_listening():
		tcp_server.stop()
	peers.clear()
	peers_IP.clear()
	overall_IP.clear()
	LoggingHelper.info("Server stopped")

func _process(_delta: float) -> void:
	if not is_shutting_down:
		poll()

func poll() -> void:
	if not tcp_server.is_listening():
		return

	# Handle new connections
	if tcp_server.is_connection_available():
		_handle_new_connection()

	# Poll existing peers
	_poll_existing_peers()

	# Clean up sealed lobbies
	_cleanup_sealed_lobbies()

enum MAN {CREATE,LOBBY,CONNECTION,LEAVE_LOBBY,CREATE_LOBBY,RESET}
func _ip_management(TYPE : MAN, ip):
	if DictionaryHelper.get_safe(overall_IP,ip,false):
		if DictionaryHelper.get_safe(overall_IP[ip],"last_activity",false):
			overall_IP[ip]["last_activity"] = TimeHelper.get_iso_timestamp()
			
	match TYPE:
		MAN.CREATE:
			if not DictionaryHelper.get_safe(overall_IP,ip,false):
				overall_IP[ip] = {"lobby_count":1, "connection_count":1, "last_activity": TimeHelper.get_iso_timestamp()}
				return true
		MAN.LOBBY:
			if DictionaryHelper.get_safe(overall_IP[ip],"lobby_count",false):
				if overall_IP[ip]["lobby_count"] < MAX_LOBBY_PER_IP:
					return true
		MAN.CREATE_LOBBY:
			if DictionaryHelper.get_safe(overall_IP[ip],"lobby_count",false):
				if overall_IP[ip]["lobby_count"] < MAX_LOBBY_PER_IP:
					overall_IP[ip]["lobby_count"] += 1
					return true
		MAN.LEAVE_LOBBY:
			if DictionaryHelper.get_safe(overall_IP[ip],"lobby_count",false):
				if overall_IP[ip]["lobby_count"] > 1:
					overall_IP[ip]["lobby_count"] -= 1
					return true
		MAN.CONNECTION:
			if DictionaryHelper.get_safe(overall_IP[ip],"connection_count",false):
				if overall_IP[ip]["connection_count"] < MAX_CONNECTION_PER_IP:
					overall_IP[ip]["connection_count"] += 1
					return true
		MAN.RESET:
			if not DictionaryHelper.get_safe(overall_IP,ip,false):
				overall_IP[ip] = {"lobby_count":overall_IP[ip]["lobby_count"], "connection_count":1, "last_activity": TimeHelper.get_iso_timestamp()}
				return true
	return false

func _ip_table_timeout():
	if overall_IP.is_empty():
		return
	var erased_ip_count: int
	for i in overall_IP:
		if DictionaryHelper.get_safe(overall_IP[i],"last_activity",false):
			var life = float(TimeHelper.calculate_uptime(overall_IP[i]["last_activity"]))
			if life > MAX_IP_LIFETIME and not peers_IP.values().has(i):
				overall_IP.erase(i)
				erased_ip_count += 1
			elif life > MAX_IP_LIFETIME:
				_ip_management(MAN.RESET,i)
	if erased_ip_count > 1:
		LoggingHelper.debug("%s IP adress erased from memory." % erased_ip_count)
	pass

func _handle_new_connection() -> void:
	if peers.size() >= MAX_PEER_COUNT:
		LoggingHelper.warning("Rejected new connection - maximum peer count reached", {
			"current_peers": peers.size(),
			"max_peers": MAX_PEER_COUNT
		})
		var temp_conn = tcp_server.take_connection()
		temp_conn.disconnect_from_host()
		return
	
	var conn = tcp_server.take_connection()
	var ip = conn.get_connected_host()
	
	_ip_management(MAN.CREATE,ip)
	if not _ip_management(MAN.CONNECTION,ip):
		conn.disconnect_from_host()
		return
		
	var id = rand.randi() % (1 << 31)
	while peers.has(id):  # Ensure unique ID
		id = rand.randi() % (1 << 31)
	peers[id] = Peer.new(id, conn)
	ip = NetworkHelper.get_client_ip(peers[id].ws)
	peers_IP[id] = ip
	
	LoggingHelper.debug("New connection", {
		"peer_id": id,
		"ip": peers_IP[id],
		"total_connections": peers.size()
	})

func _poll_existing_peers() -> void:
	var to_remove := []
	
	for peer_id in peers:
		var peer = peers[peer_id]
		
		# Handle peer timeout
		if peer.lobby == "" and Time.get_ticks_msec() - peer.time > TIMEOUT:
			LoggingHelper.info("Peer timed out", {
				"peer_id": peer_id,
				"ip": peers_IP.get(peer_id, "unknown"),
				"inactive_time": TimeHelper.format_duration_ms(Time.get_ticks_msec() - peer.time)
			})
			peer.ws.close()
		
		peer.ws.poll()
		
		# Process incoming messages
		while peer.is_ws_open() and peer.ws.get_available_packet_count() > 0:
			if not _parse_msg(peer):
				LoggingHelper.warning("Parse message failed", {
					"peer_id": peer_id,
					"ip": peers_IP.get(peer_id, "unknown")
				})
				to_remove.append(peer_id)
				await get_tree().create_timer(0.05).timeout
				peer.ws.close()
				break
		
		# Handle closed connections
		if peer.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_handle_peer_disconnection(peer_id, peer)
			to_remove.append(peer_id)
			
	
	# Remove disconnected peers
	for peer_id in to_remove:
		peers.erase(peer_id)
		peers_IP.erase(peer_id)



func _handle_peer_disconnection(peer_id: int, peer: Peer) -> void:
	LoggingHelper.info("Peer disconnected", {
		"peer_id": peer_id,
		"ip": peers_IP.get(peer_id, "unknown"),
		"lobby": peer.lobby,
		"connection_duration": TimeHelper.format_duration_ms(Time.get_ticks_msec() - peer.time)
	})
	
	if lobbies.has(peer.lobby):
		var lobby = lobbies[peer.lobby]["HOST"]
		if lobby.leave(peer):
			_ip_management(MAN.LEAVE_LOBBY,lobby.ip)
			LoggingHelper.info("Deleted lobby (host disconnected)", {
				"lobby_id": peer.lobby,
				"remaining_lobbies": lobbies.size() - 1
			})
			if lobby.peers.is_empty():
				if DictionaryHelper.get_safe(lobbies[peer.lobby]["DATA"], "visible", false):
					public_lobbies.erase(peer.lobby)
				lobbies.erase(peer.lobby)

func _cleanup_sealed_lobbies() -> void:
	var to_remove := []
	var current_time = Time.get_ticks_msec()
	
	for lobby_id in lobbies:
		var lobby = lobbies[lobby_id]["HOST"]
		if not lobby.sealed:
			continue
			
		if lobby.time + SEAL_TIME < current_time:
			# Close sealed lobby
			for peer in lobby.peers.values():
				if peer.is_ws_open():
					peer.ws.close()
			to_remove.append(lobby_id)
	
	for lobby_id in to_remove:
		if DictionaryHelper.get_safe(lobbies[lobby_id]["DATA"], "visible", false):
			public_lobbies.erase(lobby_id)
		lobbies.erase(lobby_id)
		LoggingHelper.debug("Cleaned up sealed lobby", {"lobby_id": lobby_id})

func _lobby_cleanup_check() -> void:
	if lobbies.is_empty():
		return
	
	var to_remove := []
	
	for lobby_id in lobbies:
		lobbies[lobby_id]["DATA"]["current_peer"] = lobbies[lobby_id]["HOST"].peers.size()
		
		if public_lobbies.has(lobby_id):
			for i in lobbies[lobby_id]["HOST"].peers:
				if !peers.has(i):
					to_remove.append(lobby_id)
			public_lobbies[lobby_id]["DATA"]["current_peer"] = lobbies[lobby_id]["DATA"]["current_peer"]
		
		if lobbies[lobby_id]["HOST"].peers.is_empty():
			to_remove.append(lobby_id)
	
	for lobby_id in to_remove:
		_ip_management(MAN.LEAVE_LOBBY,lobbies[lobby_id]["HOST"].ip)
		lobbies.erase(lobby_id)
		if public_lobbies.has(lobby_id):
			public_lobbies.erase(lobby_id)
		LoggingHelper.debug("Cleaned up empty lobby", {"lobby_id": lobby_id})

func _join_lobby(peer: Peer, lobby_data: String, mesh: bool) -> bool:
	if lobbies.size() >= MAX_LOBBY_COUNT:
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(503, "Server has reached maximum lobby count")
		))
		return false
	
	var parsed = JSON.parse_string(lobby_data)
	if typeof(parsed) != TYPE_DICTIONARY:
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Invalid lobby data format")
		))
		return false
	
	if not DictionaryHelper.has_all_keys(parsed, ["INV_CODE", "DATA"]):
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Missing required lobby fields")
		))
		return false
	
	var inv_code = parsed["INV_CODE"]
	var data = parsed["DATA"]
	
	if typeof(data) != TYPE_DICTIONARY:
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Invalid DATA format")
		))
		return false
	
	# Generate new lobby if no invitation code provided
	if inv_code.is_empty():
		if not _ip_management(MAN.LOBBY,peers_IP[peer.id]):
			peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(401, "This IP address already has an active lobby")
			))
			return false

		inv_code = StringHelper.random_string(INV_CODE_LENGTH, "ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789")
		lobbies[inv_code] = {
			"HOST": Lobby.new(peer.id, mesh, peers_IP[peer.id]),
			"DATA": data
		}
		
		if data.get("visible", false):
			_add_to_public_lobbies(inv_code, data)
		
		LoggingHelper.info("Created new lobby", {
			"lobby_id": inv_code,
			"peer_id": peer.id,
			"mesh": mesh,
			"public": data.get("visible", false)
		})
		_ip_management(MAN.CREATE_LOBBY,peers_IP[peer.id])
	else:
		# Validate existing lobby
		if not lobbies.has(inv_code):
			peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(404, "Lobby not found")
			))
			return false
			
		if lobbies[inv_code]["DATA"].get("password", "") != data.get("password", ""):
			peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(403, "Invalid password")
			))
			return false
			
		if int(lobbies[inv_code]["DATA"].get("current_peer", 0)) >= int(lobbies[inv_code]["DATA"].get("max_peer", 1)):
			peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(403, "Lobby is full")
			))
			return false
	
	# Join the lobby
	if not lobbies[inv_code]["HOST"].join(peer):
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(500, "Failed to join lobby")
		))
		return false
	
	peer.lobby = inv_code
	peer.send(Message.JOIN, 0, inv_code)
	
	# Update lobby stats
	lobbies[inv_code]["DATA"]["current_peer"] = lobbies[inv_code]["HOST"].peers.size()
	if lobbies[inv_code]["DATA"].get("visible", false):
		public_lobbies[inv_code]["DATA"]["current_peer"] = lobbies[inv_code]["DATA"]["current_peer"]
	
	LoggingHelper.info("Peer joined lobby", {
		"peer_id": peer.id,
		"lobby_id": inv_code,
		"current_peers": lobbies[inv_code]["DATA"]["current_peer"]
	})
	
	
	return true

func _add_to_public_lobbies(inv_code: String, data: Dictionary) -> void:
	var has_password = not data.get("password", "").is_empty()
	public_lobbies[inv_code] = {
		"DATA": {
			"apikey": data.get("apikey", ""),
			"name": data.get("name", ""),
			"max_peer": data.get("max_peer", 1),
			"current_peer": 1,
			"password": has_password
		}
	}

func _kick_client(id,inv_code,target_id) -> bool:
	if not DictionaryHelper.get_safe(lobbies,inv_code):
		return false
	var lobby = lobbies[inv_code]["HOST"]
	if not id == lobby.host:
		return false
	if not DictionaryHelper.get_safe(lobby.peers,int(target_id)):
		return false
		
	
	var peer = lobby.peers[int(target_id)]
	peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(600, "Kicked from server")
		))

	lobby.leave(peer)
	LoggingHelper.debug("%s kicked by %s from %s" % [int(target_id),id,inv_code])
	return true

func _parse_msg(peer: Peer) -> bool:
	var pkt = peer.ws.get_packet()
	if pkt.is_empty():
		
		return false
	
	if pkt.size() > MAX_PACKET_SIZE:
		peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(400, "Max packet size reached")
			))
		return false
	
	var pkt_str: String
	if pkt is PackedByteArray:
		pkt_str = pkt.get_string_from_utf8()
		if pkt_str.is_empty():
			peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(400, "Failed to decode UTF-8 packet")
			))
			return false
	else:
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Invalid packet type")
		))
		return false
	
	var parsed = JSON.parse_string(pkt_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Invalid JSON format")
		))
		return false
	
	if not DictionaryHelper.has_all_keys(parsed, ["type", "id"]):
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Missing required message fields")
		))
		return false
	
	var msg := {
		"type": int(parsed.get("type", -1)),
		"id": int(parsed.get("id", -1)),
		"data": parsed.get("data", "")
	}
	
	# Validate message type
	if msg.type < 0 or msg.type >= Message.size():
		peer.send(Message.ERROR, 0, JSON.stringify(
			NetworkHelper.create_error_response(400, "Invalid message type")
		))
		return false
	
	# Handle different message types
	match msg.type:
		Message.CONNECT:
			peer.apikey = str(msg.data)
			peer.time = Time.get_ticks_msec()
			return true
			
		Message.PING:
			peer.time = Time.get_ticks_msec()
			return true
		
		Message.KICK:
			if not StringHelper.is_valid_json(msg.data):
				return false
			var parsed_data = JSON.parse_string(msg.data)
			if not DictionaryHelper.has_all_keys(parsed_data,["inv_code","target"]):
				return false
			return _kick_client(peer.id,parsed_data["inv_code"],parsed_data["target"])
		
		Message.JOIN:
			if not peer.lobby.is_empty():
				peer.send(Message.ERROR, 0, JSON.stringify(
					NetworkHelper.create_error_response(400, "Already in a lobby")
				))
				return false
			return _join_lobby(peer, str(msg.data), msg.id == 0)
			
		Message.LOBBY_LIST:
			var valid_lobbies = {}
			for lobby_id in public_lobbies:
				if public_lobbies[lobby_id]["DATA"]["apikey"] == peer.apikey:
					valid_lobbies[lobby_id] = public_lobbies[lobby_id]
			peer.send(Message.LOBBY_LIST, 0, JSON.stringify(valid_lobbies))
			return true
			
		Message.SEAL:
			if not lobbies.has(peer.lobby):
				peer.send(Message.ERROR, 0, JSON.stringify(
					NetworkHelper.create_error_response(404, "Lobby not found")
				))
				return false
			return lobbies[peer.lobby]["HOST"].seal(peer.id)
			
		Message.OFFER, Message.ANSWER, Message.CANDIDATE:
			return _handle_webrtc_message(peer, msg)
			
		_:
			peer.send(Message.ERROR, 0, JSON.stringify(
				NetworkHelper.create_error_response(400, "Unsupported message type")
			))
			return false

func _handle_webrtc_message(peer: Peer, msg: Dictionary) -> bool:
	if not lobbies.has(peer.lobby):
		return false
		
	var lobby = lobbies[peer.lobby]["HOST"]
	var dest_id: int = msg.id
	
	if dest_id == MultiplayerPeer.TARGET_PEER_SERVER:
		dest_id = lobby.host
		
	if not peers.has(dest_id):
		return false
		
	if peers[dest_id].lobby != peer.lobby:
		return false
		
	var source = MultiplayerPeer.TARGET_PEER_SERVER if peer.id == lobby.host else peer.id
	return peers[dest_id].send(msg.type, source, str(msg.data))
