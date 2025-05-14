extends Panel

@onready var chat: RichTextLabel = $VBoxContainer/chat
@onready var type_text: LineEdit = $VBoxContainer/typeText


var self_color : Color
var peers
var nickname

signal self_color_identified(cl)
signal nickname_identified(nick)

func _ready() -> void:
	self_color = Color(randf_range(0,1),randf_range(0,1),randf_range(0,1))
	
	await  get_tree().create_timer(0.1).timeout
	self_color_identified.emit(self_color)
	nickname = _get_os_username()
	nickname_identified.emit(nickname)


@rpc("any_peer", "call_local")
func _chat_message(nick, message, color):
	chat.append_text("[color=%s]%s[/color]: %s\n" % [ str(color), nick, message])

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_ENTER):
		if type_text.text != "" and multiplayer.get_peers().size() > 0:
			_chat_message.rpc(nickname,type_text.text,self_color.to_html())
			type_text.text = ""


func _get_os_username() -> String:
	if OS.has_environment("USERNAME"):
		return OS.get_environment("USERNAME")
	else:
		return "User %s" % multiplayer.get_unique_id()
