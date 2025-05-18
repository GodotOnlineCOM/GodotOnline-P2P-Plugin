class_name AdvancedInterpolation
extends RefCounted

# Ayarlar
var interpolation_speed: float = 8.0
var max_history_size: int = 5
var extrapolation_factor: float = 0.6
var use_velocity: bool = true

# Durum
var _position_history: Array = []
var _target_position: Vector2 = Vector2.ZERO
var _current_position: Vector2 = Vector2.ZERO
var _last_velocity: Vector2 = Vector2.ZERO
var _last_update_time: int = 0

func update_target(new_position: Vector2, new_velocity: Vector2 = Vector2.ZERO, latency: float = 0.0):
	_position_history.append({
		"position": new_position,
		"velocity": new_velocity,
		"time": Time.get_ticks_msec(),
		"latency": latency
	})
	
	if _position_history.size() > max_history_size:
		_position_history.pop_front()
	
	_last_velocity = new_velocity
	_target_position = _calculate_smoothed_position()
	
	if use_velocity && latency > 0:
		_target_position += _last_velocity * latency * extrapolation_factor
	
	_last_update_time = Time.get_ticks_msec()

func interpolate(delta: float) -> Vector2:
	if _position_history.is_empty():
		return _current_position
	
	var time_since_update = (Time.get_ticks_msec() - _last_update_time) / 1000.0
	if time_since_update > 0.3:
		_current_position = _target_position
	else:
		var speed_multiplier = clamp(time_since_update * 5.0, 0.5, 2.0)
		_current_position = _current_position.lerp(
			_target_position, 
			interpolation_speed * delta * speed_multiplier
		)
	
	return _current_position

func _calculate_smoothed_position() -> Vector2:
	var total_weight = 0.0
	var weighted_sum = Vector2.ZERO
	
	for i in range(_position_history.size()):
		var entry = _position_history[i]
		var weight = 1.0 - (0.2 * i)
		weighted_sum += entry.position * weight
		total_weight += weight
	
	return weighted_sum / total_weight if total_weight > 0 else _position_history.back().position

func reset():
	_position_history.clear()
	_current_position = _target_position
	_last_velocity = Vector2.ZERO

func get_current() -> Vector2:
	return _current_position

func set_immediate(value: Vector2):
	_target_position = value
	_current_position = value
	_position_history = [{
		"position": value,
		"velocity": Vector2.ZERO,
		"time": Time.get_ticks_msec(),
		"latency": 0.0
	}]
