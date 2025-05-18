extends Control

@onready var inv_code: LineEdit = $VBoxContainer/INVBOX/inv_code
@onready var password_line: LineEdit = $VBoxContainer/password_line


signal quick_search(code,pw)

func _on_inv_code_text_changed(new_text: String) -> void:
	var caret_pos = inv_code.caret_column
	inv_code.text = new_text.to_upper()
	inv_code.caret_column = caret_pos



func _on_join_btn_pressed() -> void:
	if inv_code.text != "":
		quick_search.emit(inv_code.text,password_line.text)
		inv_code.text = "";password_line.text = ""
		
