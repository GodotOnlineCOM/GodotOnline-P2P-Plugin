extends CharacterBody2D

# Hareket Ayarları
@export var speed: float = 300.0
@export var acceleration: float = 15.0
@export var deceleration: float = 20.0
@export var is_local_player: bool = false

# Ağ Ayarları
@export var position_update_threshold: float = 10.0
@export var position_update_interval: float = 0.1
@export var max_extrapolation_time: float = 0.2  # Maksimum ileri tahmin süresi (saniye)

# Referanslar
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera_2d: Camera2D = $Camera2D

# Durumlar
var current_velocity: Vector2 = Vector2.ZERO
var input_direction: Vector2 = Vector2.ZERO
var last_movement_direction: Vector2 = Vector2.RIGHT
var last_sent_position: Vector2 = Vector2.ZERO
var time_since_last_update: float = 0.0
var _last_ping_time: int = 0
var _current_latency: float = 0.1
var _position_history: Array = []

# Interpolation Fonksiyonları
func update_interpolation_target(new_position: Vector2, new_velocity: Vector2, latency: float):
	_position_history.append({
		"position": new_position,
		"velocity": new_velocity,
		"time": Time.get_ticks_msec(),
		"latency": latency
	})
	
	# Tarihçeyi temizle
	if _position_history.size() > 5:
		_position_history.pop_front()

func get_interpolated_position(delta: float) -> Vector2:
	if _position_history.is_empty():
		return global_position
	
	# Ortalama pozisyon ve hız hesapla
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
	
	# Extrapolation (ileri tahmin)
	var extrapolated_pos = avg_pos + avg_vel * min(avg_latency, max_extrapolation_time)
	
	# Yumuşak geçiş
	return global_position.lerp(extrapolated_pos, delta * 10.0)

# Ağ Fonksiyonları
func send_ping():
	if is_local_player:
		_last_ping_time = Time.get_ticks_msec()
		rpc("_receive_ping", _last_ping_time)

@rpc("any_peer", "reliable")
func _receive_ping(sender_time: int):
	rpc_id(multiplayer.get_remote_sender_id(), "_return_pong", sender_time)

@rpc("any_peer", "reliable")
func _return_pong(original_time: int):
	if is_local_player:
		_current_latency = (Time.get_ticks_msec() - original_time) / 2000.0

func estimate_network_latency() -> float:
	# Her 2 saniyede bir ping güncelle
	if Time.get_ticks_msec() - _last_ping_time > 2000:
		send_ping()
	return _current_latency

# Temel Fonksiyonlar
func _ready():
	if is_local_player:
		multiplayer.peer_connected.connect(_on_peer_connected)
		send_ping()  # İlk pingi gönder
		camera_2d.enabled = true

func _physics_process(delta):
	if is_local_player:
		process_local_input(delta)
		update_network_sync(delta)
	else:
		process_remote_movement(delta)
	
	#update_animations()

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

func update_animations():
	if current_velocity.length() > 5.0:
		animation_player.play("walk")
	else:
		animation_player.play("idle")
	
	sprite.flip_h = last_movement_direction.x < 0 if last_movement_direction.x != 0 else sprite.flip_h

# RPC Fonksiyonları
@rpc("any_peer", "unreliable")
func send_position_update():
	if not is_local_player: return
	
	rpc("receive_position_update", 
		global_position, 
		current_velocity, 
		estimate_network_latency()
	)

@rpc("any_peer", "unreliable")
func receive_position_update(pos: Vector2, vel: Vector2, latency: float):
	if is_local_player or not is_inside_tree(): return
	update_interpolation_target(pos, vel, latency)

# Sinyal Handler'ları
func _on_peer_connected(id: int):
	if is_local_player:
		rpc_id(id, "receive_position_update", 
			global_position, 
			current_velocity, 
			estimate_network_latency()
		)

func _exit_tree():
	_position_history.clear()
