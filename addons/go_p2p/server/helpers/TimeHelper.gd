# TimeHelper - Time-related utilities
class_name TimeHelper

# Gets current timestamp in ISO 8601 format
static func get_iso_timestamp() -> String:
	return Time.get_datetime_string_from_system(true)

# Formats a duration in milliseconds to human-readable format
static func format_duration_ms(ms: int) -> String:
	var seconds = ms / 1000
	var minutes = seconds / 60
	var hours = minutes / 60
	
	seconds = seconds % 60
	minutes = minutes % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	elif minutes > 0:
		return "%02d:%02d" % [minutes, seconds]
	else:
		return "%d.%03ds" % [seconds, ms % 1000]

# Calculates uptime from server start time
static func calculate_uptime(start_time: String) -> String:
	var start_dict = Time.get_datetime_dict_from_datetime_string(start_time,true)
	var start_unix = Time.get_unix_time_from_datetime_dict(start_dict)
	var now_unix = Time.get_unix_time_from_system()
	return format_duration_ms((now_unix - start_unix) * 1000)
