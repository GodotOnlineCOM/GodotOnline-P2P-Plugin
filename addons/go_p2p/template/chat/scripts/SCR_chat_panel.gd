extends Panel

@onready var chat: RichTextLabel = $VBoxContainer/chat
@onready var type_text: LineEdit = $VBoxContainer/typeText

@rpc("any_peer", "call_local")
func _chat_message(nick, message, color):
	chat.append_text("[color=%s]%s[/color]: %s\n" % [ str(color), nick, message])

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_ENTER):
		if type_text.text != "" and not multiplayer.get_peers().is_empty():
			_chat_message.rpc(GoData.MYusername,type_text.text,GoData.MYcolor.to_html())
			type_text.text = ""
