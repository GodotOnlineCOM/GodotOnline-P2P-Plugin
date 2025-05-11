# DictionaryHelper - Utility functions for working with dictionaries
class_name DictionaryHelper

# Safely gets a value from a dictionary with optional default value
static func get_safe(dict: Dictionary, key, default_value = null):
	return dict.get(key, default_value) if dict.has(key) else default_value

static func has_all_keys(dict: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not dict.has(key):
			return false
	return true

# Merges two dictionaries (modifies the first dictionary)
static func merge(target: Dictionary, source: Dictionary) -> Dictionary:
	for key in source:
		target[key] = source[key]
	return target

# Deep copies a dictionary (handles nested dictionaries)
static func deep_copy(dict: Dictionary) -> Dictionary:
	var result = {}
	for key in dict:
		var value = dict[key]
		if value is Dictionary:
			result[key] = deep_copy(value)
		else:
			result[key] = value
	return result

# Checks if two dictionaries are equal (deep comparison)
static func equals(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	
	for key in a:
		if not b.has(key):
			return false
		
		var val_a = a[key]
		var val_b = b[key]
		
		if val_a is Dictionary and val_b is Dictionary:
			if not equals(val_a, val_b):
				return false
		elif val_a != val_b:
			return false
	
	return true

# Filters a dictionary by keys
static func filter_by_keys(dict: Dictionary, keys: Array) -> Dictionary:
	var result = {}
	for key in keys:
		if dict.has(key):
			result[key] = dict[key]
	return result

# Converts dictionary to query string
static func to_query_string(dict: Dictionary) -> String:
	var parts = []
	for key in dict:
		parts.append("%s=%s" % [key, str(dict[key]).uri_encode()])
	return "&".join(parts)
