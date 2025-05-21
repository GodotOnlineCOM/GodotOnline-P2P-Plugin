extends CharacterBody2D

# Movement settings
@export var speed: float = 150.0
@export var acceleration: float = 15.0
@export var deceleration: float = 20.0
@export var is_local_player: bool = false

# Network settings
@export var position_update_threshold: float = 10.0
@export var position_update_interval: float = 0.1
@export var max_extrapolation_time: float = 0.2 

# References
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = $Camera2D

# Variables
var current_velocity: Vector2 = Vector2.ZERO
var input_direction: Vector2 = Vector2.ZERO
var last_movement_direction: Vector2 = Vector2.RIGHT
var last_sent_position: Vector2 = Vector2.ZERO
var time_since_last_update: float = 0.0
var _last_ping_time: int = 0
var _current_latency: float = 0.1
var _position_history: Array = []


# Signals
signal place_bomb(pos)

# Interpolation
func update_interpolation_target(new_position: Vector2, new_velocity: Vector2, latency: float):
	_position_history.append({
		"position": new_position,
		"velocity": new_velocity,
		"time": Time.get_ticks_msec(),
		"latency": latency
	})
	
	if _position_history.size() > 5:
		_position_history.pop_front()

func get_interpolated_position(delta: float) -> Vector2:
	if _position_history.is_empty():
		return global_position
	
	# Average Pos calculation
	var avg_pos = Vector2.ZERO
	var avg_vel = Vector2.ZERO
	var total_latency = 0.0
	
	for entry in _position_history:
		avg_pos += entry.position
		avg_vel += entry.velocity
		total_latency += entry.latency
	
	avg_pos /= _position_history.size()
	avg_vel /= _position_history.size()
	var avg_latency = total_latency / _position_history.size()
	
	# Extrapolation 
	var extrapolated_pos = avg_pos + avg_vel * min(avg_latency, max_extrapolation_time)
	
	# Smooth Transation
	return global_position.lerp(extrapolated_pos, delta * 10.0)

# Network functions
func send_ping():
	if is_local_player:
		_last_ping_time = Time.get_ticks_msec()
		_receive_ping.rpc(_last_ping_time)

@rpc("any_peer", "reliable")
func _receive_ping(sender_time: int):
	
	_return_pong.rpc_id(multiplayer.get_remote_sender_id(),sender_time)

@rpc("any_peer", "reliable")
func _return_pong(original_time: int):
	if is_local_player:
		_current_latency = (Time.get_ticks_msec() - original_time) / 2000.0

func estimate_network_latency() -> float:
	# Ping every 2 second
	if Time.get_ticks_msec() - _last_ping_time > 2000:
		send_ping()
	return _current_latency

# Basic Functions
func _ready():
	await get_tree().create_timer(1).timeout # Don't delete; required for error handling
	if is_local_player:
		multiplayer.peer_connected.connect(self._on_peer_connected)
		send_ping()  # First Ping
		camera_2d.enabled = true

func _physics_process(delta):
	if is_local_player:
		process_local_input(delta)
		update_network_sync(delta)
		update_animations()
		if Input.is_action_just_pressed("ui_accept"):
			place_bomb.emit(self.position)
	else:
		process_remote_movement(delta)
	
	

func process_local_input(delta):
	input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction.length() > 0:
		last_movement_direction = input_direction.normalized()
	
	var target_velocity = input_direction.normalized() * speed
	current_velocity = current_velocity.move_toward(
		target_velocity, 
		acceleration if input_direction.length() > 0 else deceleration * delta * 60.0
	)
	
	velocity = current_velocity
	move_and_slide()

func process_remote_movement(delta):
	global_position = get_interpolated_position(delta)

func update_network_sync(delta):
	time_since_last_update += delta
	
	if (global_position.distance_to(last_sent_position) > position_update_threshold or 
		time_since_last_update >= position_update_interval):
		
		send_position_update()
		last_sent_position = global_position
		time_since_last_update = 0.0

@rpc("any_peer")
func rpc_update_animations(is_walking: bool, flip_h: bool) -> void:
	# Update Animation at all clients
	if is_walking:
		animated_sprite_2d.play("walk")
	else:
		animated_sprite_2d.play("idle")
	
	animated_sprite_2d.flip_h = flip_h


func update_animations():
	var is_walking = current_velocity.length() > 5.0
	var flip_h = last_movement_direction.x > 0 if last_movement_direction.x != 0 else animated_sprite_2d.flip_h

	if is_walking:
		animated_sprite_2d.play("walk")
	else:
		animated_sprite_2d.play("idle")
	animated_sprite_2d.flip_h = flip_h
	rpc_update_animations.rpc(is_walking, flip_h)

# RPC Functions
@rpc("any_peer", "unreliable")
func send_position_update():
	if not is_local_player: return
	
	receive_position_update.rpc(
		global_position, 
		current_velocity, 
		estimate_network_latency()
		)

@rpc("any_peer", "unreliable")
func receive_position_update(pos: Vector2, vel: Vector2, latency: float):
	if is_local_player or not is_inside_tree(): return
	update_interpolation_target(pos, vel, latency)

# Singnal handlers
func _on_peer_connected(id: int):
	if is_local_player:
		receive_position_update.rpc_id(id,
			global_position, 
			current_velocity, 
			estimate_network_latency()
			)


func _exit_tree():
	_position_history.clear()
