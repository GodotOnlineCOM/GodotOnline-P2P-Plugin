extends Control
@onready var item_name: Label = $main_container/name_panel/NAME
@onready var item_peer: Label = $main_container/peer_panel/PEER
@onready var item_icon: TextureRect = $main_container/icon_panel/ICON

const PRIVATE = preload("res://addons/go_p2p/assets/private.png")
const PUBLIC = preload("res://addons/go_p2p/assets/public.png")
var inv_code = ""
var status = false

signal join_lobby(code,pw)

func _initial(_status,_name,_current_peer,_max_peer,_code):
	item_name.text = _name
	item_peer.text = str(int(_current_peer)) + "/" + str(int(_max_peer))
	inv_code = _code
	status = _status
	if _status:
		item_icon.texture = PRIVATE
	else:
		item_icon.texture = PUBLIC


func _on_button_pressed() -> void:
	join_lobby.emit(inv_code,status)
