# StringHelper - Utility functions for string operations
class_name StringHelper

# Generates a random string of specified length
static func random_string(length: int, chars: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") -> String:
	var result = ""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(length):
		result += chars[rng.randi() % chars.length()]
	
	return result

# Checks if string is a valid JSON
static func is_valid_json(json_string: String) -> bool:
	var test_json_conv = JSON.new()
	return test_json_conv.parse(json_string) == OK

# Truncates string with ellipsis if too long
static func truncate(text: String, max_length: int, ellipsis: String = "...") -> String:
	if text.length() <= max_length:
		return text
	return text.left(max_length - ellipsis.length()) + ellipsis

# Converts string to bool (handles various true/false representations)
static func to_bool(s: String) -> bool:
	return s.strip_edges().to_lower() in ["true", "1", "yes", "y", "on"]

# Sanitizes input string for logging/output
static func sanitize(input: String) -> String:
	return input.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
