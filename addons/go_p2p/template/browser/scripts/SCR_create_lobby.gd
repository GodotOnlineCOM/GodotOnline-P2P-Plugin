extends Control
const PEER_ITEM = preload("res://addons/go_p2p/template/browser/peer_item.tscn")

@onready var vbox_2: VBoxContainer = $MainContainer/VBOX2
@onready var inv_code: LineEdit = $MainContainer/VBOX2/InviteContainer/InvCode
@onready var inv_btn: TextureButton = $MainContainer/VBOX2/InviteContainer/InvBtn
@onready var peers_container: VBoxContainer = $MainContainer/VBOX2/peer_panel/ScrollContainer/PeersContainer

@onready var start_container: HBoxContainer = $MainContainer/VBOX2/StartContainer
@onready var quit_btn: Button = $MainContainer/VBOX2/quit_btn

@export var next_scene: String = "res://addons/go_p2p/template/3D/world_3d.tscn"

@onready var lobby_name: LineEdit = $MainContainer/VBOX/lobby_name
@onready var eye: TextureButton = $MainContainer/VBOX/BOXPASS/eye
@onready var lobby_password: LineEdit = $MainContainer/VBOX/BOXPASS/lobby_password
@onready var check_box: CheckBox = $MainContainer/VBOX/BOXVISIBLE/CheckBox
@onready var spin_box: SpinBox = $MainContainer/VBOX/SpinBox
@onready var chat_panel: Panel = $MainContainer/VBOX2/chat_panel

@export var EYE_VISIBLE : CompressedTexture2D
@export var EYE_HIDDEN : CompressedTexture2D
var eye_status = true
var peers = {}
signal create_lobby(lobby_name,lobby_pass,max_peer,status)

func _ready() -> void:
	GoClient.lobby_joined.connect(self._lobby_joined)
	GoClient.disconnected.connect(self._lobby_disconnected)
	multiplayer.peer_connected.connect(self._mp_peer_connected)
	multiplayer.peer_disconnected.connect(self._mp_peer_disconnected)
	start_container.hide()
	vbox_2.hide()
	lobby_name.text = "%s' Lobby" % GoData.MYusername


@rpc("any_peer", "call_local")
func _register_peer(id,nick,color):
	GoData.peers[id] = {"nickname":nick,"color":color.to_html(),"is_server":false}
	if id == multiplayer.get_unique_id():
		GoData.peers[id]["is_server"] = true
	pass

func _mp_peer_connected(id: int):
	_register_peer.rpc(multiplayer.get_unique_id(),GoData.MYusername,GoData.MYcolor)
	_add_peers()

func _mp_peer_disconnected(id: int):
	if GoData.peers.has(id):
		GoData.peers.erase(id)
	_add_peers()

func _add_peers():
	await get_tree().create_timer(0.1).timeout
	for node in peers_container.get_children():
		node.queue_free()
	for peer in GoData.peers:
		var item = PEER_ITEM.instantiate()
		peers_container.add_child(item)
		item._initial(peer,
			GoData.peers[peer]["nickname"],
			GoData.peers[peer]["color"],
			GoData.peers[peer]["is_server"])
		
		if multiplayer.is_server():
			item.kick_peer.connect(self._kick_peer)
	pass

func _kick_peer(id):
	GoClient._kick_peer(id)
	_mp_peer_disconnected(id)


func _lobby_joined(lobby):
	vbox_2.show()
	inv_code.text = lobby

func _lobby_disconnected():
	GoData.peers.clear()
	for node in peers_container.get_children():
		node.queue_free()
		

func _on_eye_pressed() -> void:
	if eye_status:
		eye.texture_normal = EYE_HIDDEN
	else:
		eye.texture_normal = EYE_VISIBLE
	eye_status = !eye_status
	lobby_password.secret = !lobby_password.secret


func _on_host_btn_pressed() -> void:
	create_lobby.emit(lobby_name.text,lobby_password.text,spin_box.value,check_box.button_pressed)
	start_container.show()
	pass


func _on_start_btn_pressed(path : String) -> void:
	_start_lobby.rpc(path)
	GoClient.seal_lobby()
	pass 

@rpc("any_peer","call_local")
func _start_lobby(path : String):
	get_tree().change_scene_to_file(path)
	pass

func _on_inv_btn_pressed() -> void:
	inv_code.secret = !inv_code.secret
	if inv_code.secret:
		inv_btn.texture_normal = EYE_VISIBLE
	else:
		inv_btn.texture_normal = EYE_HIDDEN


func _on_quit_btn_pressed() -> void:
	vbox_2.hide()
	GoClient.stop()
	pass
