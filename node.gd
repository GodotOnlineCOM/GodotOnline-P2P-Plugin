extends Node

func _ready() -> void:
	GoClient.connected.connect(self._connected)
	GoClient.disconnected.connect(self._disconnected)
	GoClient.lobby_joined.connect(self._lobby_joined)
	
	await get_tree().create_timer(1).timeout
	#GoClient.join_lobby()
	pass

func _connected(id,data):
	PrintHelper.info("Server connected with ID: %d" % id)
func _disconnected():
	PrintHelper.info("Server disconnected: %d - %s" % [GoClient.code, GoClient.reason])
func _lobby_joined(lobby):
	PrintHelper.info("Joined lobby %s" % lobby)


func _on_server_browser_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/go_p2p/template/browser/server_browser.tscn")
	pass # Replace with function body.


func _on_pen_test_pressed() -> void:
	for i in range(50):
		GoClient.join_lobby()
		await get_tree().create_timer(0.1).timeout
		GoClient.stop()
