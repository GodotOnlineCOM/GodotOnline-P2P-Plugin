extends  Node

enum Message {
	JOIN, ID, PEER_CONNECT, PEER_DISCONNECT, OFFER, ANSWER, CANDIDATE, 
	SEAL, PEERS, LOBBY_LIST, CONNECT, PING, ERROR, KICK
}

@export var autojoin := true
@export var lobby := "" # Will create a new lobby if empty.
@export var mesh := true # Will use the lobby host as relay otherwise.

var ws: WebSocketPeer = WebSocketPeer.new()
var code : int = 1000
var reason : String = "Unknown"
var old_state = WebSocketPeer.STATE_CLOSED
var avaible_servers : Array = []
var current_server : String = ""

signal lobby_joined(lobby)
signal connected(id, use_mesh)
signal disconnected()
signal peer_connected(id)
signal peer_disconnected(id)
signal offer_received(id, offer)
signal answer_received(id, answer)
signal candidate_received(id, mid, index, sdp)
signal lobby_sealed()
signal lobby_list(list)
signal error_occurred(message)


var ping_timer = Timer.new()

var version : String
var prefix : String
var full_URL: String = ""
var version_order: int = 0

var timer = Timer.new()
const max_attempt: int = 5
var current_attempt: int = 0


var _server_name: String = "Default Server Name"
var _max_peer: int = 5
var _current_peer: int = 1
var _password: String = ""
var _inv_code: String = ""
var _visible: bool = true

@onready var _template = {
	"INV_CODE":_inv_code,
	"DATA":{"apikey":GoSettings.API_KEY,
	"name":_server_name,
	"max_peer":_max_peer,
	"password":_password,
	"visible":_visible}
}

func _ready() -> void:
	version = GoSettings.VERSION
	prefix = GoSettings.PREFIX
	if GoSettings.AUTO_CONNECT:
		_initial()

func _initial() -> void: # Creating a new http_request to fetch valid servers.
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_request_completed)
	var error = http_request.request(GoSettings.VERSION_CONTROL_URL)
	if error != OK:
		PrintHelper.error("An error occurred in the HTTP request.")

func _on_request_completed(result, response_code, headers, body) -> void:
	# Convert the ascii code to string.
	var utf = body.get_string_from_ascii()
	# String to valid variable.
	var all_versions = str_to_var(utf)
	if all_versions == null:
		PrintHelper.critical("No server available. Check VERSION_CONTROL_URL")
		return
	# Take our current version between all versions.
	if not all_versions.has(version):
		PrintHelper.critical("Incompatible Version. Check VERSION")
		return
	avaible_servers = all_versions[version]
	full_URL = prefix + avaible_servers[version_order]
	connect_to_url(full_URL)
	# Create a timer that will check if the server is available. 
	timer.timeout.connect(self._timeout);timer.wait_time = 1.0;
	add_child(timer);timer.start();


func _timeout() -> void: # SEARCH VALID SERVER
	if current_attempt < max_attempt:
		# If it connects to the server we will use it for the whole process
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ping_timer.timeout.connect(self._ping_timeout);ping_timer.wait_time = 60.0;
			add_child(ping_timer);ping_timer.start();
			timer.stop()
		current_attempt += 1
	else:
		# if it does not connect, try using alternative servers.
		timer.stop()
		if version_order < avaible_servers.size()-1:
			current_attempt = 0
			version_order += 1
			full_URL = prefix + avaible_servers[version_order]
			connect_to_url(full_URL)
			timer.start()
		else:
			
			PrintHelper.critical("No valid server.")


func _ping_timeout(): # ESTABLISH SERVER CONNECTION. PREVENT GETTING KICKED
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_msg(Message.PING,0 if mesh else 1)
	pass

func connect_to_url(url): # CONNECT SERVER USING URL
	close()
	code = 1000
	reason = "Unknown"
	if url != "":
		ws.connect_to_url(url)

func close(): # CLOSE CONNECTION
	ws.close()

func _process(delta: float) -> void:
	ws.poll()
	var state = ws.get_ready_state()
	if state != old_state and state == WebSocketPeer.STATE_OPEN and autojoin:
		connect_server()
	while state == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count():
		if not _parse_msg():
			PrintHelper.debug("Error parsing message from server.")
	if state != old_state and state == WebSocketPeer.STATE_CLOSED:
		disconnected.emit()
	old_state = state


func _parse_msg():
	var parsed = JSON.parse_string(ws.get_packet().get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type") or not parsed.has("id") or \
		typeof(parsed.get("data")) != TYPE_STRING:
		return false

	var msg := parsed as Dictionary
	if not str(int(msg.type)).is_valid_int() or not str(int(msg.id)).is_valid_int(): # OH GOD PLEASE FORGIVE ME.
		return false

	var type := str(msg.type).to_int()
	var src_id := str(msg.id).to_int()

	match type:
		Message.ID:
			connected.emit(src_id, msg.data == "true")
		Message.ERROR:
			error_occurred.emit(msg.data)
			var jsData = JSON.parse_string(msg.data)
			if DictionaryHelper.has_all_keys(jsData["error"],["code","message"]):
				code = jsData["error"]["code"]
				reason = jsData["error"]["message"]
		Message.LOBBY_LIST:
			lobby_list.emit(msg.data)
		Message.JOIN:
			lobby_joined.emit(msg.data)
		Message.SEAL:
			lobby_sealed.emit()
		Message.PEER_CONNECT:
			peer_connected.emit(src_id)
		Message.PEER_DISCONNECT:
			peer_connected.emit(src_id)
		Message.OFFER:
			offer_received.emit(src_id, msg.data)
		Message.ANSWER:
			answer_received.emit(src_id, msg.data)
		Message.CANDIDATE:
			var candidate: PackedStringArray = msg.data.split("\n", false)
			if candidate.size() != 3:
				return false
			if not candidate[1].is_valid_int():
				return false
			candidate_received.emit(src_id, candidate[0], candidate[1].to_int(), candidate[2])
		_:
			return false
	return true # Parsed

func _get_lobby_list():
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_to_url(full_URL);await get_tree().create_timer(0.5).timeout # gives enough connection time
	return _send_msg(Message.LOBBY_LIST, 0 if mesh else 1, GoSettings.API_KEY)

func connect_server():
	return _send_msg(Message.CONNECT, 0 if mesh else 1, GoSettings.API_KEY)

func join_lobby(lobby: String = "", password: String = _password, server_name: String = _server_name, max_peer: int = _max_peer, visible: bool = _visible ):
	if lobby == "" or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_to_url(full_URL);await get_tree().create_timer(0.5).timeout # gives enough connection time
	
	_template = {
		"INV_CODE":lobby,
		"DATA":{
			"apikey":GoSettings.API_KEY,
			"name":server_name,
			"max_peer":max_peer,
			"password":password,
			"visible":visible}
	}
	return _send_msg(Message.JOIN, 0 if mesh else 1, JSON.stringify(_template))


func seal_lobby():
	return _send_msg(Message.SEAL, 0)
func send_candidate(id, mid, index, sdp) -> int:
	return _send_msg(Message.CANDIDATE, id, "\n%s\n%d\n%s" % [mid, index, sdp])
func send_offer(id, offer) -> int:
	return _send_msg(Message.OFFER, id, offer)
func send_answer(id, answer) -> int:
	return _send_msg(Message.ANSWER, id, answer)

func _send_msg(type: int, id: int, data:="") -> int:
	var msg = JSON.stringify({
		"type": type,
		"id": id,
		"data": data
	})
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return 0
	else:
		return ws.send_text(msg)
