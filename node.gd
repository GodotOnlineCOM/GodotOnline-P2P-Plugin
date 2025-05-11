extends Node

func _ready() -> void:
	GoClient.connected.connect(self._connected)
	GoClient.disconnected.connect(self._disconnected)
	GoClient.lobby_joined.connect(self._lobby_joined)
	
	await get_tree().create_timer(1).timeout
	GoClient.join_lobby()
	pass

func _connected(id,data):
	PrintHelper.info("Server connected with ID: %d" % id)
func _disconnected():
	PrintHelper.info("Server disconnected: %d - %s" % [GoClient.code, GoClient.reason])
func _lobby_joined(lobby):
	PrintHelper.info("Joined lobby %s" % lobby)
