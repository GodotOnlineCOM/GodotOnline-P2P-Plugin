extends Node

# This Scripts contains common variables for templates.

var MYusername: String
var MYcolor: Color
var peers : Dictionary = {}

func _ready() -> void:
	MYusername = _get_os_username()
	MYcolor = _random_color_generator()

func _get_os_username() -> String:
	if OS.has_environment("USERNAME"):
		return OS.get_environment("USERNAME")
	else:
		return "User %s" % multiplayer.get_unique_id()

func _random_color_generator():
	return Color(randf_range(0.1,1),randf_range(0.1,1),randf_range(0.1,1))
