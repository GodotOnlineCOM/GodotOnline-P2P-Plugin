@tool
extends EditorPlugin


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/GoServer"):
		add_autoload_singleton("GoServer", "res://addons/go_p2p/server/ws_webrtc_server.gd")
	if not ProjectSettings.has_setting("autoload/GoSettings"):
		add_autoload_singleton("GoSettings", "res://addons/go_p2p/go_settings.gd")
	if not ProjectSettings.has_setting("autoload/GoClient"):
		add_autoload_singleton("GoClient", "res://addons/go_p2p/client/multiplayer_client.gd")
	if not ProjectSettings.has_setting("autoload/GoData"):
		add_autoload_singleton("GoData", "res://addons/go_p2p/go_data.gd")
func _exit_tree() -> void:
	remove_autoload_singleton("GoSettings")
	remove_autoload_singleton("GoClient")
	remove_autoload_singleton("GoServer")
	remove_autoload_singleton("GoData")
