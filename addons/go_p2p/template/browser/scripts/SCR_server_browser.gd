extends Control
@onready var tab_bar: TabBar = $main_container/TabBar
@onready var altmain_container: HBoxContainer = $main_container/browser_container
@onready var create_container: HBoxContainer = $main_container/create_container
@onready var server_search: Control = $main_container/browser_container/search_panel/server_search
@onready var create_lobby: Control = $main_container/create_container/create_panel/create_lobby
@onready var server_container: VBoxContainer = $main_container/browser_container/server_panel/ScrollContainer/server_container
@onready var window_pass: Window = $WindowPass
@onready var profile: Control = $main_container/Profile


@onready var pass_btn: TextureButton = $WindowPass/HBox/pass_btn
@onready var password: LineEdit = $WindowPass/HBox/password

@export var SERVER_ITEM: PackedScene
var last_inv_code: String

func _ready() -> void:
	server_search.quick_search.connect(self._quick_search)
	create_lobby.create_lobby.connect(self._create_lobby)
	
	GoClient.lobby_joined.connect(self._lobby_joined)
	GoClient.lobby_sealed.connect(self._lobby_sealed)
	GoClient.connected.connect(self._connected)
	GoClient.disconnected.connect(self._disconnected)
	GoClient.lobby_list.connect(self._lobby_list)
	multiplayer.connected_to_server.connect(self._mp_server_connected)
	multiplayer.connection_failed.connect(self._mp_server_disconnect)
	multiplayer.server_disconnected.connect(self._mp_server_disconnect)
	multiplayer.peer_connected.connect(self._mp_peer_connected)
	multiplayer.peer_disconnected.connect(self._mp_peer_disconnected)
	
	altmain_container.show()
	create_container.hide()
	profile.hide()
	window_pass.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			GoClient.get_lobby_list()

func _on_tab_bar_tab_changed(tab: int) -> void:
	match tab:
		0:
			altmain_container.show()
			create_container.hide()
			profile.hide()
		1:
			altmain_container.hide()
			create_container.show()
			profile.hide()
		2:
			altmain_container.hide()
			create_container.hide()
			profile.show()

func _create_lobby(lobby_name,lobby_pass,max_peer,status):
	GoClient.join_lobby("",lobby_pass,lobby_name,max_peer,status)


func _quick_search(code,pw):
	GoClient.join_lobby(code,pw)


func _mp_server_connected():
	_log("[Multiplayer] Server connected (I am %d)" % GoClient.rtc_mp.get_unique_id())
func _mp_server_disconnect():
	_log("[Multiplayer] Server disconnected (I am %d)" % GoClient.rtc_mp.get_unique_id())
func _mp_peer_connected(id: int):
	_log("[Multiplayer] Peer %d connected" % id)
func _mp_peer_disconnected(id: int):
	_log("[Multiplayer] Peer %d disconnected" % id)
func _connected(id,data):
	_log("[Signaling] Server connected with ID: %d" % id)
func _disconnected():
	_log("[Signaling] Server disconnected: %d - %s" % [GoClient.code, GoClient.reason])
func _lobby_joined(lobby):
	_log("[Signaling] Joined lobby %s" % lobby)
	altmain_container.hide()
	create_container.show()
	window_pass.hide()


func _lobby_sealed():
	_log("[Signaling] Lobby has been sealed")

func _lobby_list(list):
	var new_list : Dictionary = JSON.parse_string(list)
	
	if server_container.get_child_count() > 0:
		for i in server_container.get_children():
			i.queue_free()
	if !new_list.is_empty():
		for i2 in new_list:
			var item = SERVER_ITEM.instantiate()
			server_container.add_child(item)
			item._initial(new_list[i2]["DATA"]["password"],new_list[i2]["DATA"]["name"],new_list[i2]["DATA"]["current_peer"],new_list[i2]["DATA"]["max_peer"],i2)
			item.join_lobby.connect(self._lobby_item_join)

func _log(msg):
	PrintHelper.info(msg)

func _lobby_item_join(code,pw):
	last_inv_code = code
	if pw:
		window_pass.show()
	else:
		GoClient.join_lobby(code)
	pass


func _on_pass_btn_pressed() -> void:
	GoClient.join_lobby(last_inv_code,password.text)
	password.text = ""
	pass # Replace with function body.


func _on_window_pass_close_requested() -> void:
	window_pass.hide()
	pass # Replace with function body.
