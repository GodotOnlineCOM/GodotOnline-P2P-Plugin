class_name PrintHelper

enum LogLevel {
	DEBUG,    # 0 - Detailed debug information
	INFO,     # 1 - Routine operational messages
	WARNING,  # 2 - Unexpected but handled situations
	ERROR,    # 3 - Failed operations that affect functionality
	CRITICAL  # 4 - Critical failures that may crash the application
}

# Configuration - Adjust these constants as needed for your project
const DEFAULT_LOG_LEVEL := LogLevel.DEBUG

# Static variables
static var _log_level = DEFAULT_LOG_LEVEL

static func Log(Level : LogLevel ,Content : String):
	if not GoSettings.DEBUGGER:
		return
	
	if Level < _log_level:
		return

	var color := ""
	match Level:
		LogLevel.DEBUG: color = Color.CYAN.to_html()    # Cyan
		LogLevel.INFO: color = Color.GREEN.to_html()      # Green
		LogLevel.WARNING: color = Color.YELLOW.to_html()  # Yellow
		LogLevel.ERROR: color = Color.DARK_RED.to_html()     # Red
		LogLevel.CRITICAL: color = Color.RED.to_html() # Bright red
	
	print_rich("[color=%s]%s[/color]" % [color, Content])



# Convenience methods for each log level
static func debug(message: String) -> void:
	Log(LogLevel.DEBUG, "[DEBUG] %s" % message)

static func info(message: String,) -> void:
	Log(LogLevel.INFO, "[INFO] %s" % message)

static func warning(message: String) -> void:
	Log(LogLevel.WARNING, "[WARNING] %s" % message)

static func error(message: String,) -> void:
	Log(LogLevel.ERROR, "[ERROR] %s" % message)

static func critical(message: String) -> void:
	Log(LogLevel.CRITICAL, "[CRITICAL] %s" % message)
