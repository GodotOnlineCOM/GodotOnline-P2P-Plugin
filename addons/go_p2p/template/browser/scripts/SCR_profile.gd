extends Control
@onready var username: LineEdit = $Panel/VBOX/username
@onready var usercolor: ColorPickerButton = $Panel/VBOX/usercolor

func _ready() -> void:
	username.text = GoData.MYusername
	usercolor.color = GoData.MYcolor


func _on_usercolor_color_changed(color: Color) -> void:
	GoData.MYcolor = color
	pass # Replace with function body.


func _on_username_text_submitted(new_text: String) -> void:
	GoData.MYusername = new_text
	pass # Replace with function body.
