extends Control
var peer_id
var peer_name
var peer_color 
var peer_is_server
@onready var peername: RichTextLabel = $HBox/name_panel/PEERNAME
@onready var button_panel: PanelContainer = $HBox/button_panel

signal kick_peer(id)
func _initial(pid,pname,pcolor,pserver):
	
	if pserver or !multiplayer.is_server():
		button_panel.hide()
	peer_id = pid
	peername.append_text("%s [color=%s]%s[/color]" % ["(YOU)" if pserver else "",str(pcolor), pname])


func _on_button_pressed() -> void:
	kick_peer.emit(peer_id)
	pass # Replace with function body.
