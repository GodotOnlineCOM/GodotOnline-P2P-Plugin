# NetworkHelper - Network-related utility functions
class_name NetworkHelper

# Validates an IP address
static func is_valid_ip(ip: String) -> bool:
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	
	for part in parts:
		if not part.is_valid_int():
			return false
		var num = part.to_int()
		if num < 0 or num > 255:
			return false
	
	return true

# Gets client IP from WebSocketPeer
static func get_client_ip(ws: WebSocketPeer) -> String:
	return ws.get_connected_host() if ws else "unknown"

# Validates a port number
static func is_valid_port(port: int) -> bool:
	return port > 0 and port <= 65535

# Creates a standardized error response dictionary
static func create_error_response(code: int, message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"error": {
			"code": code,
			"message": message,
			"details": details,
			"timestamp": Time.get_datetime_string_from_system()
		}
	}
