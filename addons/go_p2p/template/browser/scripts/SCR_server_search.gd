extends Control

@onready var inv_code: LineEdit = $VBoxContainer/INVBOX/inv_code


signal quick_search(code)

func _on_inv_code_text_changed(new_text: String) -> void:
	var caret_pos = inv_code.caret_column
	inv_code.text = new_text.to_upper()
	inv_code.caret_column = caret_pos



func _on_join_btn_pressed() -> void:
	print(inv_code.text)
	if inv_code.text != "":
		quick_search.emit(inv_code.text)
