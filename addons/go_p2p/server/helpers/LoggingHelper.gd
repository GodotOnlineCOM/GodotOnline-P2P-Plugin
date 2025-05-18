# LoggingHelper - Production-ready logging utilities
class_name LoggingHelper
## Comprehensive logging system with file rotation, log levels, and structured logging

# Configuration - Adjust these constants as needed for your project
const MAX_LOG_FILE_SIZE := 10 * 1024 * 1024  # 10MB max log file size
const MAX_LOG_FILES_TO_KEEP := 10
const ENABLE_CONSOLE_OUTPUT := true
const ENABLE_FILE_LOGGING := true
const COMPRESS_OLD_LOGS := false  # Not implemented in this version
const DEFAULT_LOG_LEVEL := LogLevel.DEBUG

# Log levels with severity ordering
enum LogLevel {
	DEBUG,    # 0 - Detailed debug information
	INFO,     # 1 - Routine operational messages
	WARNING,  # 2 - Unexpected but handled situations
	ERROR,    # 3 - Failed operations that affect functionality
	CRITICAL  # 4 - Critical failures that may crash the application
}

# Static variables
static var _log_file_path := ""
static var _log_level := DEFAULT_LOG_LEVEL
static var _initialized := false
static var _startup_time := Time.get_datetime_string_from_system().replace(":", "-")

# Initialize the logging system once
static func _initialize() -> void:
	if _initialized:
		return
	
	if ENABLE_FILE_LOGGING:
		_setup_log_file()
	
	_initialized = true

# Configure the log file path and directory
static func _setup_log_file() -> void:
	var exe_path := OS.get_executable_path()
	var exe_dir := exe_path.get_base_dir()
	var log_dir := exe_dir.path_join("logs")
	
	# Ensure logs directory exists
	if not DirAccess.dir_exists_absolute(log_dir):
		var err := DirAccess.make_dir_recursive_absolute(log_dir)
		if err != OK:
			push_error("Failed to create logs directory: %s" % error_string(err))
			return
	
	_log_file_path = log_dir.path_join("log_%s.txt" % _startup_time)

# Main logging function
static func Log(level: LogLevel, message: String, context: Dictionary = {}) -> void:
	if not _initialized:
		_initialize()
		
	if not GoSettings.DEBUGGER:
		return
	# Skip if message level is below configured threshold
	if level < _log_level:
		return
	
	var level_str = LogLevel.keys()[level] if level < LogLevel.size() else "UNKNOWN"
	var timestamp := Time.get_datetime_string_from_system()
	
	var log_entry := {
		"timestamp": timestamp,
		"level": level_str,
		"message": message,
		"context": context
	}
	var ip = ""
	if context.has("ip"):
		ip = context["ip"]
	var log_line := "[%s] %s: %s %s" % [timestamp, level_str, message, ip]
	
	# Output to console if enabled
	if ENABLE_CONSOLE_OUTPUT:
		_print_to_console(level, log_line)
	
	# Write to log file if enabled
	if ENABLE_FILE_LOGGING and not _log_file_path.is_empty():
		_write_to_log_file(log_line)

# Console output with appropriate formatting
static func _print_to_console(level: LogLevel, message: String) -> void:
	var color := ""
	match level:
		LogLevel.DEBUG: color = Color.CYAN.to_html()    # Cyan
		LogLevel.INFO: color = Color.GREEN.to_html()      # Green
		LogLevel.WARNING: color = Color.YELLOW.to_html()  # Yellow
		LogLevel.ERROR: color = Color.DARK_RED.to_html()     # Red
		LogLevel.CRITICAL: color = Color.RED.to_html() # Bright red
	
	print_rich("[color=%s]%s[/color]" % [color, message])

# Write to log file with rotation check
static func _write_to_log_file(log_entry: String) -> void:
	var file := FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
	
	if not file:
		var err := FileAccess.get_open_error()
		if err == ERR_FILE_NOT_FOUND:
			file = FileAccess.open(_log_file_path, FileAccess.WRITE)
		else:
			push_error("Failed to open log file: %s" % error_string(err))
			return
	
	# Check if we need to rotate logs
	if file.get_length() > MAX_LOG_FILE_SIZE:
		file.close()
		_rotate_log_files()
		file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	
	if file:
		file.seek_end()
		file.store_string(log_entry + "\n")
		file.close()

# Rotate log files when they get too large
static func _rotate_log_files() -> void:
	var log_dir := _log_file_path.get_base_dir()
	var files := []
	
	var dir := DirAccess.open(log_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("log_"):
				files.append(file_name)
			file_name = dir.get_next()
	
	# Sort files by modification time (oldest first)
	files.sort_custom(func(a, b): 
		return FileAccess.get_modified_time(log_dir.path_join(a)) < FileAccess.get_modified_time(log_dir.path_join(b))
	)
	
	# Remove oldest files if we have too many
	if files.size() >= MAX_LOG_FILES_TO_KEEP:
		for i in range(files.size() - MAX_LOG_FILES_TO_KEEP + 1):
			var file_path := log_dir.path_join(files[i])
			var err := DirAccess.remove_absolute(file_path)
			if err != OK:
				push_error("Failed to remove old log file %s: %s" % [files[i], error_string(err)])

# Set the minimum log level (filters out lower priority messages)
static func set_log_level(level: LogLevel) -> void:
	_log_level = level

# Convenience methods for each log level
static func debug(message: String, context: Dictionary = {}) -> void:
	Log(LogLevel.DEBUG, message, context)

static func info(message: String, context: Dictionary = {}) -> void:
	Log(LogLevel.INFO, message, context)

static func warning(message: String, context: Dictionary = {}) -> void:
	Log(LogLevel.WARNING, message, context)

static func error(message: String, context: Dictionary = {}) -> void:
	Log(LogLevel.ERROR, message, context)

static func critical(message: String, context: Dictionary = {}) -> void:
	Log(LogLevel.CRITICAL, message, context)
	
	# For critical errors, consider additional actions
	if OS.has_feature("standalone"):
		# In production, you might want to write to a separate crash log
		var crash_log_path := _log_file_path.get_base_dir().path_join("crash_%s.log" % _startup_time)
		var file := FileAccess.open(crash_log_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({
				"timestamp": Time.get_datetime_string_from_system(),
				"level": "CRITICAL",
				"message": message,
				"context": context,
				"stack_trace": get_stack()
			}))
			file.close()
