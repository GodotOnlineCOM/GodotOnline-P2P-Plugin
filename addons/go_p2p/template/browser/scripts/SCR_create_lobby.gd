extends Control
const PEER_ITEM = preload("res://addons/go_p2p/template/browser/peer_item.tscn")

@onready var vbox_2: VBoxContainer = $MainContainer/VBOX2
@onready var inv_code: LineEdit = $MainContainer/VBOX2/InviteContainer/InvCode
@onready var inv_btn: TextureButton = $MainContainer/VBOX2/InviteContainer/InvBtn
@onready var peers_container: VBoxContainer = $MainContainer/VBOX2/peer_panel/ScrollContainer/PeersContainer

@onready var chat: RichTextLabel = $MainContainer/VBOX2/chat_panel/VBoxContainer/chat
@onready var type_text: LineEdit = $MainContainer/VBOX2/chat_panel/VBoxContainer/typeText


@onready var lobby_name: LineEdit = $MainContainer/VBOX/lobby_name
@onready var eye: TextureButton = $MainContainer/VBOX/BOXPASS/eye
@onready var lobby_password: LineEdit = $MainContainer/VBOX/BOXPASS/lobby_password
@onready var check_box: CheckBox = $MainContainer/VBOX/BOXVISIBLE/CheckBox
@onready var spin_box: SpinBox = $MainContainer/VBOX/SpinBox

@export var EYE_VISIBLE : CompressedTexture2D
@export var EYE_HIDDEN : CompressedTexture2D
var eye_status = true
var nickname = ""
var peers = {}
var self_color = Color(0,0,0)
signal create_lobby(lobby_name,lobby_pass,max_peer,status)

func _ready() -> void:
	GoClient.lobby_joined.connect(self._lobby_joined)
	GoClient.disconnected.connect(self._lobby_disconnected)
	multiplayer.peer_connected.connect(self._mp_peer_connected)
	multiplayer.peer_disconnected.connect(self._mp_peer_disconnected)
	self_color = Color(randf_range(0,1),randf_range(0,1),randf_range(0,1))
	
	if OS.has_environment("USERNAME"):
		lobby_name.text = OS.get_environment("USERNAME") + "'s Lobby"
		nickname = OS.get_environment("USERNAME")
	else:
		lobby_name.text = "My Lobby"
		nickname = "User"
	vbox_2.hide()
	
@rpc("any_peer", "call_local")
func _register_peer(id,nick,color):
	peers[id] = {"nickname":nick,"color":color.to_html(),"is_server":false}
	if id == multiplayer.get_unique_id():
		peers[id]["is_server"] = true
	pass

@rpc("any_peer", "call_local")
func _chat_message(nick, message, color):
	chat.append_text("[color=%s]%s[/color]: %s\n" % [ str(color), nick, message])

func _mp_peer_connected(id: int):
	_register_peer.rpc(multiplayer.get_unique_id(),nickname,self_color)
	_add_peers()

func _mp_peer_disconnected(id: int):
	if peers.has(id):
		peers.erase(id)
	_add_peers()

func _add_peers():
	await get_tree().create_timer(0.1).timeout
	for i in peers_container.get_children():
		i.queue_free()
	for i2 in peers:
		var item = PEER_ITEM.instantiate()
		peers_container.add_child(item)
		item._initial(i2,peers[i2]["nickname"],peers[i2]["color"],peers[i2]["is_server"])
		if multiplayer.is_server():
			item.kick_peer.connect(self._kick_peer)
	pass

func _kick_peer(id):
	GoClient.rmv_peer(id)


func _lobby_joined(lobby):
	vbox_2.show()
	inv_code.text = lobby

func _lobby_disconnected():
	peers.clear()
	for i in peers_container.get_children():
		i.queue_free()


func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_ENTER):
		if type_text.text != "" and multiplayer.get_peers().size() > 0:
			_chat_message.rpc(nickname,type_text.text,self_color.to_html())
			type_text.text = ""
		pass

func _on_eye_pressed() -> void:
	if eye_status:
		eye.texture_normal = EYE_HIDDEN
	else:
		eye.texture_normal = EYE_VISIBLE
	eye_status = !eye_status
	lobby_password.secret = !lobby_password.secret


func _on_host_btn_pressed() -> void:
	create_lobby.emit(lobby_name.text,lobby_password.text,spin_box.value,check_box.button_pressed)
	pass


func _on_start_btn_pressed() -> void:
	_start_lobby.rpc()
	pass 

@rpc("any_peer","call_local")
func _start_lobby():
	get_tree().change_scene_to_file("res://addons/go_p2p/template/2D/world.tscn")
	pass

func _on_inv_btn_pressed() -> void:
	inv_code.secret = !inv_code.secret
	if inv_code.secret:
		inv_btn.texture_normal = EYE_VISIBLE
	else:
		inv_btn.texture_normal = EYE_HIDDEN
